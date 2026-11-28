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

--- A logger that prints a line and keeps it with the named suite's saved results, so each
--- button's output is saved on its own and read back after a reload.
---@param suite string
---@return fun(text: string)
local function emitter(suite)
	return function(text)
		TestMode:LogDiagnostic(suite, text)
	end
end

local probeEmit = emitter("Debug Probe")
local rowsEmit = emitter("Debug Rows")
local edgesEmit = emitter("Debug Edges")

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
	probeEmit("Equipped items (all should be typeUnusable=false)") -- nocheck
	for slot = 1, 19 do
		local link = GetInventoryItemLink("player", slot)
		if link then
			local unusable = G_RLF.WoWAPI.ItemLoot.ItemTypeUnusable(link)
			local _, _, subType, equipLoc = C_Item.GetItemInfoInstant(link)
			probeEmit(
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
	probeEmit("Debug probe (" .. #PROBE_ITEM_IDS .. " items)") -- nocheck
	for _, itemId in ipairs(PROBE_ITEM_IDS) do
		-- Ask for the item every time; click the button again once they have loaded.
		C_Item.RequestLoadItemDataByID(itemId)
		local _, _, subType, equipLoc = C_Item.GetItemInfoInstant(itemId)
		local canUse = C_PlayerInfo and C_PlayerInfo.CanUseItem and C_PlayerInfo.CanUseItem(itemId)
		local red = redTooltipLines(itemId)
		local unusable = G_RLF.WoWAPI.ItemLoot.ItemTypeUnusable("item:" .. itemId)
		probeEmit(
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
		rowsEmit("Test rows done") -- nocheck
		return
	end
	local link = row.item and ("item:" .. row.item) or GetInventoryItemLink("player", row.equippedSlot)
	if not link then
		rowsEmit(index .. ". skipped, nothing available: " .. row.label)
		return fireTestRow(index + 1)
	end
	local itemApi = G_RLF.WoWAPI.ItemLoot
	local itemModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.ItemLoot) --[[@as RLF_ItemLoot]]
	local itemId = itemApi.GetItemIDForItemInfo(link)
	Item:CreateFromItemID(itemId):ContinueOnItemLoad(function()
		local info = G_RLF.ItemInfo:new(itemId, itemApi.GetItemInfo(link))
		if not info then
			rowsEmit(index .. ". could not load item for: " .. row.label)
		else
			if row.quality then
				info.itemQuality = row.quality
			end
			local payload = itemModule:BuildPayload(info, 1)
			if payload then
				rowsEmit(index .. ". " .. row.label)
				-- The feed merges rows that share a key, and several test rows are the same
				-- item; give each its own.
				payload.key = tostring(payload.key) .. "#debugrow" .. index
				G_RLF.LootElementBase:fromPayload(payload):Show(info.itemName, info.itemQuality)
			else
				rowsEmit(index .. ". no row built (Item Loot disabled or filtered): " .. row.label)
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
	rowsEmit("Firing " .. #TEST_ROWS .. " test rows") -- nocheck
	fireTestRow(1)
end

--- How many local units one physical pixel is for a region. Coordinates and sizes are in
--- the region's own scaled units, so the global pixel-to-UI-unit factor has to be divided
--- by the region's effective scale.
---@param region table
---@return number
local function unitsPerPixelFor(region)
	return PixelUtil.GetPixelToUIUnitFactor() / region:GetEffectiveScale()
end

--- Describe one coordinate or size in whole physical pixels, marking it OFF-GRID when it
--- falls between pixels.
local function describeEdge(label, value, unitsPerPixel)
	if value == nil then
		return label .. "=?"
	end
	local pixels = value / unitsPerPixel
	local nearest = math.floor(pixels + 0.5)
	if math.abs(pixels - nearest) > 0.02 then
		return string.format("%s=%.2fpx OFF-GRID", label, pixels)
	end
	return string.format("%s=%d", label, nearest)
end

--- Report where each active row's edges fall in physical pixels. A 1px border side
--- disappears when its edge sits between two pixels, so anything marked OFF-GRID here is a
--- candidate. Run it while the rows you are looking at are still on screen.
function TestMode:AuditRowEdges()
	TestMode:BeginTestRun("Debug Edges")
	edgesEmit(
		string.format(
			"UIParent scale %.4f, pixel factor %.5f, row border size %s",
			UIParent:GetEffectiveScale(),
			PixelUtil.GetPixelToUIUnitFactor(),
			tostring(G_RLF.DbAccessor:Styling(G_RLF.Frames.MAIN).rowBorderSize)
		)
	) -- nocheck
	for id in pairs(G_RLF.db.global.frames) do
		local frame = G_RLF.LootDisplay:GetFrame(id)
		if frame then
			local unitsPerPixel = unitsPerPixelFor(frame)
			edgesEmit(
				string.format(
					"frame %s (1px = %.4f units): %s %s %s %s",
					tostring(id),
					unitsPerPixel,
					describeEdge("left", frame:GetLeft(), unitsPerPixel),
					describeEdge("bottom", frame:GetBottom(), unitsPerPixel),
					describeEdge("width", frame:GetWidth(), unitsPerPixel),
					describeEdge("height", frame:GetHeight(), unitsPerPixel)
				)
			) -- nocheck
			-- Number rows by where they sit, starting at the edge the feed grows from, so
			-- "row 5" means the fifth on screen and not the fifth the code walks.
			local shown, iteration = {}, 0
			for row in frame.rows:iterate() do
				iteration = iteration + 1
				if row:IsShown() and row:GetBottom() then
					table.insert(shown, { row = row, iteration = iteration })
				end
			end
			local growsUp = frame.vertDir == "BOTTOM"
			table.sort(shown, function(x, y)
				if growsUp then
					return x.row:GetBottom() < y.row:GetBottom()
				end
				return x.row:GetBottom() > y.row:GetBottom()
			end)
			for rank, entry in ipairs(shown) do
				local row = entry.row
				local unitsPerRowPixel = unitsPerPixelFor(row)
				edgesEmit(
					string.format(
						"  row %d (walk %d): %s %s %s %s",
						rank,
						entry.iteration,
						describeEdge("L", row:GetLeft(), unitsPerRowPixel),
						describeEdge("R", row:GetRight(), unitsPerRowPixel),
						describeEdge("T", row:GetTop(), unitsPerRowPixel),
						describeEdge("B", row:GetBottom(), unitsPerRowPixel)
					)
				) -- nocheck
				-- The border is drawn as four edge pieces. A side goes missing when its piece
				-- collapses to 0px, is hidden, or sits between pixels.
				local pieces = {}
				for _, spec in ipairs({
					{ "TopEdge", "h", "GetHeight", "GetTop" },
					{ "BottomEdge", "h", "GetHeight", "GetBottom" },
					{ "LeftEdge", "w", "GetWidth", "GetLeft" },
					{ "RightEdge", "w", "GetWidth", "GetRight" },
				}) do
					local piece = row[spec[1]]
					if piece then
						local size = piece[spec[3]](piece)
						local at = piece[spec[4]](piece)
						local perPixel = unitsPerPixelFor(piece)
						table.insert(
							pieces,
							spec[1]:gsub("Edge", "")
								.. (piece:IsShown() and "" or " HIDDEN")
								.. " "
								.. describeEdge(spec[2], size, perPixel)
								.. " "
								.. describeEdge("at", at, perPixel)
						)
					else
						table.insert(pieces, spec[1]:gsub("Edge", "") .. " none")
					end
				end
				edgesEmit("      border: " .. table.concat(pieces, " | ")) -- nocheck
			end
		end
	end
	edgesEmit("Edge audit done") -- nocheck
end

local buttons
local autoShown = false

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
		button:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	end
	button:Hide()
	return button
end

--- Build the stack of buttons once, top to bottom. Add new buttons above "Reload UI",
--- which stays last.
local function ensureButtons()
	if buttons then
		return
	end
	local specs = {
		{
			"RLF Integration",
			function()
				TestMode:IntegrationTest()
			end,
		},
		{
			"RLF Debug",
			function()
				TestMode:DebugProbe()
			end,
		},
		{
			"RLF Rows",
			function()
				TestMode:FireTestRows()
			end,
		},
		{
			"RLF Edges",
			function()
				TestMode:AuditRowEdges()
			end,
		},
		{
			"Reload UI",
			function()
				ReloadUI()
			end,
		},
	}
	buttons = {}
	for _, spec in ipairs(specs) do
		table.insert(buttons, makeButton(spec[1], buttons[#buttons], spec[2]))
	end
end

local function setButtonsShown(show)
	ensureButtons()
	for _, button in ipairs(buttons) do
		button:SetShown(show)
	end
end

--- Show or hide the debug buttons in the middle of the screen, so scripts do not have to
--- fit in the chat box: "RLF Integration" runs the integration test, "RLF Debug" the item
--- probe, "RLF Rows" fires test rows into the feed, "RLF Edges" reports where the rows'
--- edges fall on the pixel grid and "Reload UI" reloads the interface (saving the
--- results). Right-drag a button to move it.
function TestMode:ToggleDebugButton()
	ensureButtons()
	autoShown = false
	setButtonsShown(not buttons[1]:IsShown())
end

-- After a /reload the buttons come up on their own, so the next test run does not need the
-- keyboard; moving the character puts them away again. Showing them by hand with
-- /rlf debug leaves them up until toggled off.
local function hideAutoShownButtons()
	if autoShown then
		autoShown = false
		setButtonsShown(false)
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- Clients without the movement event fall back to watching the character's speed.
local hasMovementEvent = pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_STARTED_MOVING")
eventFrame:SetScript("OnEvent", function(_, event, _, isReloadingUi)
	if event == "PLAYER_ENTERING_WORLD" then
		if isReloadingUi then
			setButtonsShown(true)
			autoShown = true
		end
	elseif event == "PLAYER_STARTED_MOVING" then
		hideAutoShownButtons()
	end
end)
if not hasMovementEvent then
	eventFrame:SetScript("OnUpdate", function()
		if autoShown and GetUnitSpeed and GetUnitSpeed("player") > 0 then
			hideAutoShownButtons()
		end
	end)
end
--@end-alpha@
