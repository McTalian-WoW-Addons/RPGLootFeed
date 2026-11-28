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

--- Rows the "RLF Rows" button fires into the feed, in order, so item rendering can be
--- checked without typing item links. `quality` overrides the item's quality (0 makes a
--- grey copy), and `equippedSlot` uses whatever the character wears in that slot.
local TEST_ROWS = {
	{ label = "red type text: a mace a mage cannot use", item = 36 },
	{ label = "red type text: a shield a mage cannot use", item = 1168 },
	{ label = "white type text: your own chest piece", equippedSlot = 5 },
	{ label = "quest start highlight: Head of Onyxia", item = 18423 },
	{ label = "grey, cannot wear it: shows vendor value", item = 36, quality = 0 },
	{ label = "grey, slot already worn: shows vendor value", equippedSlot = 5, quality = 0 },
}

--- Fire one test row, then the next, once each item has loaded.
---@param index number
local function fireTestRow(index)
	local row = TEST_ROWS[index]
	if not row then
		emit("Test rows done") -- nocheck
		return
	end
	local link = row.item and ("item:" .. row.item) or GetInventoryItemLink("player", row.equippedSlot)
	if not link then
		emit(index .. ". skipped, nothing available: " .. row.label)
		return fireTestRow(index + 1)
	end
	local itemApi = G_RLF.WoWAPI.ItemLoot
	local itemModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.ItemLoot) --[[@as RLF_ItemLoot]]
	local itemId = itemApi.GetItemIDForItemInfo(link)
	Item:CreateFromItemID(itemId):ContinueOnItemLoad(function()
		local info = G_RLF.ItemInfo:new(itemId, itemApi.GetItemInfo(link))
		if not info then
			emit(index .. ". could not load item for: " .. row.label)
		else
			if row.quality then
				info.itemQuality = row.quality
			end
			local payload = itemModule:BuildPayload(info, 1)
			if payload then
				emit(index .. ". " .. row.label)
				-- The feed merges rows that share a key, and several test rows are the same
				-- item; give each its own.
				payload.key = tostring(payload.key) .. "#debugrow" .. index
				G_RLF.LootElementBase:fromPayload(payload):Show(info.itemName, info.itemQuality)
			else
				emit(index .. ". no row built (Item Loot disabled or filtered): " .. row.label)
			end
		end
		C_Timer.After(0.4, function()
			fireTestRow(index + 1)
		end)
	end)
end

--- Fire the TEST_ROWS into the feed; the chat lists them in the order they appear.
function TestMode:FireTestRows()
	TestMode:BeginTestRun("Debug Rows")
	emit("Firing " .. #TEST_ROWS .. " test rows") -- nocheck
	fireTestRow(1)
end

--- How far a position is from the nearest physical pixel, as a fraction of a pixel.
local function pixelFraction(value, unitsPerPixel)
	local pixels = value / unitsPerPixel
	return pixels - math.floor(pixels + 0.5)
end

local function describeEdge(label, value, unitsPerPixel)
	if value == nil then
		return label .. "=?"
	end
	local off = pixelFraction(value, unitsPerPixel)
	if math.abs(off) > 0.02 then
		return string.format("%s=%.2fpx OFF-GRID", label, value / unitsPerPixel)
	end
	return string.format("%s=%d", label, math.floor(value / unitsPerPixel + 0.5))
end

--- Report where each active row's edges fall in physical pixels. A 1px border side
--- disappears when its edge sits between two pixels, so anything marked OFF-GRID here is a
--- candidate. Run it while the rows you are looking at are still on screen.
function TestMode:AuditRowEdges()
	TestMode:BeginTestRun("Debug Edges")
	local unitsPerPixel = PixelUtil.GetPixelToUIUnitFactor()
	emit(
		string.format(
			"UIParent scale %.4f, 1 pixel = %.5f UI units, row border size %s",
			UIParent:GetEffectiveScale(),
			unitsPerPixel,
			tostring(G_RLF.DbAccessor:Styling(G_RLF.Frames.MAIN).rowBorderSize)
		)
	) -- nocheck
	for id in pairs(G_RLF.db.global.frames) do
		local frame = G_RLF.LootDisplay:GetFrame(id)
		if frame then
			emit(
				string.format(
					"frame %s: %s %s %s %s",
					tostring(id),
					describeEdge("left", frame:GetLeft(), unitsPerPixel),
					describeEdge("bottom", frame:GetBottom(), unitsPerPixel),
					describeEdge("width", frame:GetWidth(), unitsPerPixel),
					describeEdge("height", frame:GetHeight(), unitsPerPixel)
				)
			) -- nocheck
			local index = 0
			for row in frame.rows:iterate() do
				index = index + 1
				if row:IsShown() then
					emit(
						string.format(
							"  row %d: %s %s %s %s",
							index,
							describeEdge("L", row:GetLeft(), unitsPerPixel),
							describeEdge("R", row:GetRight(), unitsPerPixel),
							describeEdge("T", row:GetTop(), unitsPerPixel),
							describeEdge("B", row:GetBottom(), unitsPerPixel)
						)
					) -- nocheck
				end
			end
		end
	end
	emit("Edge audit done") -- nocheck
end

local debugButton, rowsButton, edgesButton

local function makeButton(label, anchorTo, onClick)
	local button = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
	button:SetSize(140, 32)
	button:SetText(label)
	button:SetFrameStrata("DIALOG")
	button:SetMovable(true)
	button:EnableMouse(true)
	button:RegisterForDrag("RightButton")
	button:SetScript("OnDragStart", button.StartMoving)
	button:SetScript("OnDragStop", button.StopMovingOrSizing)
	button:SetScript("OnClick", onClick)
	if anchorTo then
		button:SetPoint("TOP", anchorTo, "BOTTOM", 0, -4)
	else
		button:SetPoint("CENTER")
	end
	button:Hide()
	return button
end

--- Show or hide three buttons in the middle of the screen so scripts do not have to fit
--- in the chat box: "RLF Debug" runs the item probe, "RLF Rows" fires test rows into
--- the feed and "RLF Edges" reports where the rows' edges fall on the pixel grid.
--- Right-drag a button to move it.
function TestMode:ToggleDebugButton()
	if not debugButton then
		debugButton = makeButton("RLF Debug", nil, function()
			TestMode:DebugProbe()
		end)
		rowsButton = makeButton("RLF Rows", debugButton, function()
			TestMode:FireTestRows()
		end)
		edgesButton = makeButton("RLF Edges", rowsButton, function()
			TestMode:AuditRowEdges()
		end)
	end
	local show = not debugButton:IsShown()
	debugButton:SetShown(show)
	rowsButton:SetShown(show)
	edgesButton:SetShown(show)
end
--@end-alpha@
