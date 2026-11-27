---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--@alpha@
---@type RLF_TestMode
local TestMode = G_RLF.RLF:GetModule(G_RLF.SupportModule.TestMode) --[[@as RLF_TestMode]]

--- Item IDs the probe looks at. Edit this list for whatever is being investigated; the
--- current set checks how usability shows up for a cloth-only class (a mage).
local PROBE_ITEM_IDS = { 25, 35, 2092, 36, 37, 16799, 16795, 16720, 16667, 16866, 14551, 1168, 23201 }

local function emit(text)
	TestMode:LogDiagnostic("Debug Probe", text)
end

local function isRed(color)
	return color ~= nil and (color.r or 0) > 0.9 and (color.g or 1) < 0.2
end

--- The tooltip lines of an item that are drawn in red, as "<line>L:<left text>" or
--- "<line>R:<right text>" (L and R are the left and right columns).
---@param itemId number
---@return string?
local function redTooltipLines(itemId)
	if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then
		return nil
	end
	local data = C_TooltipInfo.GetItemByID(itemId)
	if not data or not data.lines then
		return nil
	end
	-- An item the client has not loaded yet shows a red "Retrieving item information"
	-- line in place of its real tooltip; that is not a result.
	local placeholder = _G["RETRIEVING_ITEM_INFO"]
	if placeholder and data.lines[1] and data.lines[1].leftText == placeholder then
		return nil
	end
	local out = {}
	for n, line in ipairs(data.lines) do
		if isRed(line.leftColor) then
			table.insert(out, n .. "L:" .. tostring(line.leftText))
		end
		if isRed(line.rightColor) then
			table.insert(out, n .. "R:" .. tostring(line.rightText))
		end
	end
	return table.concat(out, "; ")
end

--- Everything the character is wearing should be usable by them, so a type flagged as
--- unusable on one of these is a false positive.
local function probeEquippedItems()
	emit("Equipped items (all should be typeUnusable=false)") -- nocheck
	for slot = 1, 19 do
		local link = GetInventoryItemLink("player", slot)
		if link then
			local unusable = G_RLF.WoWAPI.ItemLoot.ItemTypeUnusable(link)
			local _, _, subType, equipLoc = C_Item.GetItemInfoInstant(link)
			emit(
				string.format(
					"slot %d %s %s %s typeUnusable=%s",
					slot,
					link,
					tostring(subType),
					tostring(equipLoc),
					tostring(unusable)
				)
			)
		end
	end
end

--- Prints, for each probe item: its type, whether C_PlayerInfo.CanUseItem says the
--- character can use it, and which tooltip lines are red.
function TestMode:DebugProbe()
	TestMode:BeginTestRun("Debug Probe")
	emit("Debug probe (" .. #PROBE_ITEM_IDS .. " items)") -- nocheck
	for _, itemId in ipairs(PROBE_ITEM_IDS) do
		-- Ask for the item every time; click the button again once they have loaded.
		C_Item.RequestLoadItemDataByID(itemId)
		local _, _, subType, equipLoc = C_Item.GetItemInfoInstant(itemId)
		local canUse = C_PlayerInfo and C_PlayerInfo.CanUseItem and C_PlayerInfo.CanUseItem(itemId)
		local red = redTooltipLines(itemId)
		local unusable = G_RLF.WoWAPI.ItemLoot.ItemTypeUnusable("item:" .. itemId)
		emit(
			string.format(
				"%d %s %s canUse=%s typeUnusable=%s red=%s",
				itemId,
				tostring(subType),
				tostring(equipLoc),
				tostring(canUse),
				tostring(unusable),
				red == nil and "(not loaded yet, click again)" or (red == "" and "-" or red)
			)
		)
	end
	probeEquippedItems()
end

local debugButton

--- Show or hide a button in the middle of the screen that runs the probe, so a
--- longer script does not have to fit in the chat box. Drag it to move it.
function TestMode:ToggleDebugButton()
	if not debugButton then
		debugButton = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
		debugButton:SetSize(140, 32)
		debugButton:SetPoint("CENTER")
		debugButton:SetText("RLF Debug")
		debugButton:SetFrameStrata("DIALOG")
		debugButton:SetMovable(true)
		debugButton:EnableMouse(true)
		debugButton:RegisterForDrag("RightButton")
		debugButton:SetScript("OnDragStart", debugButton.StartMoving)
		debugButton:SetScript("OnDragStop", debugButton.StopMovingOrSizing)
		debugButton:SetScript("OnClick", function()
			TestMode:DebugProbe()
		end)
		debugButton:Hide()
	end
	debugButton:SetShown(not debugButton:IsShown())
end
--@end-alpha@
