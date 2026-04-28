---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class LootDisplay: RLF_Module, AceBucket-3.0, AceEvent-3.0, AceHook-3.0
local LootDisplay = G_RLF.RLF:NewModule(G_RLF.SupportModule.LootDisplay, "AceBucket-3.0", "AceEvent-3.0", "AceHook-3.0")

local lsm = G_RLF.lsm

-- Private variable declaration
---@type table<integer, RLF_LootDisplayFrame | nil>
local lootFrames = {}
---@type table<integer, Queue>
local lootQueues = {}
--- Tracks whether sample rows are currently displayed (set by ShowSampleRows/HideSampleRows)
local sampleRowsVisible = false
--- Handle for the pending debounced UpdateSampleRows timer (cancelled on each new call)
local updateSampleRowsTimer = nil

-- Function to update queue labels for all active frames
local function updateQueueLabels()
	for id, frame in pairs(lootFrames) do
		if frame ~= nil then
			frame:UpdateQueueLabel(lootQueues[id]:size())
		end
	end
end
-- Wrapper function to update queue labels after calling the original function
local function updateQueueLabelsWrapper(func)
	return function(...)
		local result = { func(...) }
		updateQueueLabels()
		return unpack(result)
	end
end

--- Initialise a queue for the given frame ID and wrap enqueue/dequeue with the
--- label-update callback.
local function initQueueForFrame(id)
	local q = G_RLF.Queue:new()
	q.enqueue = updateQueueLabelsWrapper(q.enqueue)
	q.dequeue = updateQueueLabelsWrapper(q.dequeue)
	lootQueues[id] = q
end

-- Public methods

--- Create and register a single loot display WoW frame for the given DB frame ID.
--- Safe to call multiple times — returns early if the frame already exists.
--- @param id integer Frame ID (integer key into db.global.frames)
function LootDisplay:InitFrame(id)
	if lootFrames[id] ~= nil then
		return
	end

	initQueueForFrame(id)

	---@type RLF_LootDisplayFrame
	local frame
	if id == G_RLF.Frames.MAIN then
		frame = CreateFrame("Frame", "RLF_MainLootFrame", UIParent, "RLF_LootDisplayFrameTemplate") --[[@as RLF_LootDisplayFrame]]
		G_RLF.RLF_MainLootFrame = frame
	else
		frame = CreateFrame("Frame", nil, UIParent, "RLF_LootDisplayFrameTemplate") --[[@as RLF_LootDisplayFrame]]
	end

	lootFrames[id] = frame
	frame:Load(id)

	-- If the options panel is already open when this frame is created, show the test area immediately.
	local mainFrame = lootFrames[G_RLF.Frames.MAIN]
	if id ~= G_RLF.Frames.MAIN and mainFrame and mainFrame.BoundingBox and mainFrame.BoundingBox:IsVisible() then
		frame:ShowTestArea()
	end
end

--- Re-initialise an existing feed frame from the current DB state.
--- If the frame does not yet exist, delegates to InitFrame.
--- Clears live rows and flushes the queue before reloading, so the frame
--- immediately reflects the restored settings without a /reload.
--- @param id integer Frame ID
function LootDisplay:RefreshFrame(id)
	local frame = lootFrames[id]
	if not frame then
		self:InitFrame(id)
		return
	end
	frame:ClearFeed()
	-- Flush any queued items so they are not processed under stale config.
	if lootQueues[id] then
		while not lootQueues[id]:isEmpty() do
			lootQueues[id]:dequeue()
		end
	end
	frame:Load(id)
end

function LootDisplay:OnInitialize()
	-- Create a WoW frame for every entry already stored in db.global.frames.
	-- Migration v8 (Phase 1) ensures these exist for all existing users.
	for id in pairs(G_RLF.db.global.frames) do
		self:InitFrame(id)
	end
end

function LootDisplay:OnEnable()
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnPlayerCombatChange")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnPlayerCombatChange")
	self:RegisterBucketEvent("BAG_UPDATE_DELAYED", 0.5, "BAG_UPDATE_DELAYED")
	self:RegisterMessage("RLF_NEW_LOOT", "OnLootReady")
	self:RegisterBucketMessage("RLF_ROW_RETURNED", 0.3, "OnRowReturn")

	RunNextFrame(function()
		---@type RLF_TestMode
		local TestModeModule = G_RLF.RLF:GetModule(G_RLF.SupportModule.TestMode) --[[@as RLF_TestMode]]
		TestModeModule:OnLootDisplayReady()
	end)

	RunNextFrame(function()
		self:OnPlayerCombatChange()
	end)

	-- So far up through MoP Classic, some/all of these methods are not defined
	if not G_RLF:IsRetail() then
		if not ItemButtonMixin.SetItemButtonTexture then
			ItemButtonMixin.SetItemButtonTexture = function(self, texture) end
		end

		self:RawHook(ItemButtonMixin, "SetItemButtonTexture", function(self, texture)
			if SetItemButtonTexture_Base then
				SetItemButtonTexture_Base(texture)
			else
				-- Handle the case where SetItemButtonTexture_Base doesn't exist
				self.icon:SetTexture(texture)
			end
		end, true)

		if not ItemButtonMixin.SetItemButtonQuality then
			ItemButtonMixin.SetItemButtonQuality = function(self, quality, itemIDOrLink) end
		end

		self:RawHook(ItemButtonMixin, "SetItemButtonQuality", function(self, quality, itemIDOrLink)
			if SetItemButtonQuality_Base then
				SetItemButtonQuality_Base(quality, itemIDOrLink)
			else
				if quality then
					-- Handle the case where SetItemButtonQuality_Base doesn't exist
					local r, g, b = C_Item.GetItemQualityColor(quality)
					self.IconBorder:SetVertexColor(r, g, b)
				end
			end
		end, true)
	end
end

function LootDisplay:OnPlayerCombatChange()
	local inCombat = UnitAffectingCombat("player")
	for _, frame in pairs(lootFrames) do
		if frame then
			frame:UpdateTabVisibility()
			frame:SetCombatClickThrough(inCombat)
			-- Clear any in-progress scroll sequence on combat entry to avoid
			-- accidentally activating history while the player is fighting.
			if inCombat and frame.wheelState then
				G_RLF.HistoryService:ResetWheelState(frame.wheelState)
			end
		end
	end
end

--- Destroy the WoW frame for `id`, clear its queue, and remove it from the DB.
--- Frame ID 1 (Main) cannot be destroyed.
--- @param id integer
function LootDisplay:DestroyFrame(id)
	if id == G_RLF.Frames.MAIN then
		return
	end

	if lootFrames[id] then
		lootFrames[id]:Hide()
		lootFrames[id]:ClearFeed()
		lootFrames[id]:HideTestArea()
		lootFrames[id] = nil
	end

	if lootQueues[id] then
		while not lootQueues[id]:isEmpty() do
			lootQueues[id]:dequeue()
		end
		lootQueues[id] = nil
	end

	G_RLF.db.global.frames[id] = nil
end

function LootDisplay:SetBoundingBoxVisibility(show)
	for _, frame in pairs(lootFrames) do
		if frame then
			if show then
				frame:ShowTestArea()
			else
				frame:HideTestArea()
			end
		end
	end
end

function LootDisplay:ToggleBoundingBox()
	if lootFrames[G_RLF.Frames.MAIN] == nil then
		return
	end
	self:SetBoundingBoxVisibility(not lootFrames[G_RLF.Frames.MAIN].BoundingBox:IsVisible())
end

--- update the position of the frame
--- @param frame? G_RLF.Frames
function LootDisplay:UpdatePosition(frame)
	frame = frame or G_RLF.Frames.MAIN
	if lootFrames[frame] == nil then
		return
	end
	local positioningDb = G_RLF.DbAccessor:Positioning(frame)
	lootFrames[frame]:ClearAllPoints()
	lootFrames[frame]:SetPoint(
		positioningDb.anchorPoint,
		_G[positioningDb.relativePoint],
		positioningDb.xOffset,
		positioningDb.yOffset
	)
end

--- Update row positions for the frame
--- @param frame? G_RLF.Frames
function LootDisplay:UpdateRowPositions(frame)
	frame = frame or G_RLF.Frames.MAIN
	if lootFrames[frame] == nil then
		return
	end

	lootFrames[frame]:UpdateRowPositions()
end

--- Update the strata of the frame
--- @param frame? G_RLF.Frames
function LootDisplay:UpdateStrata(frame)
	frame = frame or G_RLF.Frames.MAIN
	if lootFrames[frame] then
		local positioningDb = G_RLF.DbAccessor:Positioning(frame)
		lootFrames[frame]:SetFrameStrata(positioningDb.frameStrata)
		lootFrames[frame]:UpdateOverlayFrameDepth()
	end
end

--- Update loot history tab appearance for the frame.
--- @param frame? G_RLF.Frames
function LootDisplay:UpdateTabAppearance(frame)
	frame = frame or G_RLF.Frames.MAIN
	if lootFrames[frame] == nil then
		return
	end

	lootFrames[frame]:UpdateTabAppearance()
end

--- Update the size of the frame
--- @param frame? G_RLF.Frames
function LootDisplay:UpdateSize(frame)
	frame = frame or G_RLF.Frames.MAIN
	if lootFrames[frame] == nil then
		return
	end

	lootFrames[frame]:UpdateSize()

	-- Update sample rows if they're currently shown
	self:RefreshSampleRowsIfShown()
end

--- Update row styles for the frame
--- @param frame? G_RLF.Frames
function LootDisplay:UpdateRowStyles(frame)
	frame = frame or G_RLF.Frames.MAIN
	if lootFrames[frame] == nil then
		return
	end

	lootFrames[frame]:UpdateStyles()

	-- Update sample rows if they're currently shown
	self:RefreshSampleRowsIfShown()
end

--- Update enter animation for the frame
--- @param frame? G_RLF.Frames
function LootDisplay:UpdateEnterAnimation(frame)
	frame = frame or G_RLF.Frames.MAIN
	if lootFrames[frame] == nil then
		return
	end

	lootFrames[frame]:UpdateEnterAnimationType()

	-- Update sample rows if they're currently shown
	self:RefreshSampleRowsIfShown()
end

--- Update fade delay for the frame
--- @param frame? G_RLF.Frames
function LootDisplay:UpdateFadeDelay(frame)
	frame = frame or G_RLF.Frames.MAIN
	if lootFrames[frame] == nil then
		return
	end

	lootFrames[frame]:UpdateFadeDelay()

	-- Update sample rows if they're currently shown
	self:RefreshSampleRowsIfShown()
end

function LootDisplay:ReInitQueueLabel(frame)
	frame = frame or G_RLF.Frames.MAIN
	if lootFrames[frame] == nil then
		return
	end

	lootFrames[frame]:InitQueueLabel()
end

--- Handle the BAG_UPDATE_DELAYED event
function LootDisplay:BAG_UPDATE_DELAYED()
	G_RLF:LogInfo("BAG_UPDATE_DELAYED", "WOWEVENT", self.moduleName, nil, "BAG_UPDATE_DELAYED")

	for _, frame in pairs(lootFrames) do
		if frame then
			frame:UpdateRowItemCounts()
		end
	end
end

--- process the row for the proper frame
--- @param element RLF_LootElement
--- @param frame? G_RLF.Frames
local function processRow(element, frame)
	frame = frame or G_RLF.Frames.MAIN
	if lootFrames[frame] == nil then
		return
	end

	if not element:IsEnabled() then
		return
	end

	local key = element.key
	local unit = element.unit

	if unit then
		key = unit .. "_" .. key
	end

	---@type RLF_LootDisplayRow | nil
	local row = lootFrames[frame]:GetRow(key)
	if row then
		RunNextFrame(function()
			row:UpdateQuantity(element)
		end)
	else
		-- New row
		-- Apply the same blocking rule as processFromQueue: if a row is pinned
		-- or shift animations are running, enqueue rather than adding rows that
		-- would displace the layout or pile on top of the pinned row.
		-- (When processFromQueue calls processRow these conditions are always
		-- false, so this gate is a no-op for queue-drain paths.)
		local lootFrame = lootFrames[frame]
		if lootFrame and ((lootFrame.shiftingRowCount or 0) > 0 or lootFrame.hasPinnedRow) then
			lootQueues[frame]:enqueue(element)
			return
		end
		row = lootFrames[frame]:LeaseRow(key)
		if row == nil then
			lootQueues[frame]:enqueue(element)
			return
		end

		RunNextFrame(function()
			row:BootstrapFromElement(element)
			-- Sample rows re-enqueue themselves on dismiss so the user can cycle
			-- through all preview rows when maxRows < total sample count
			if element.isSampleRow then
				row.onReleased = function()
					if sampleRowsVisible then
						lootQueues[frame]:enqueue(element)
					end
				end
			end
		end)
	end
end

--- process the row from the queue for the proper frame
--- @param frame? G_RLF.Frames
local function processFromQueue(frame)
	frame = frame or G_RLF.Frames.MAIN
	local queue = lootQueues[frame]
	if not queue then
		return
	end
	-- Block queue drain while rows are animating to their new positions OR
	-- while a row is pinned (to prevent layout conflicts with the detached row).
	-- ShiftAnimation:OnFinished sends RLF_ROW_RETURNED once shiftingRowCount
	-- reaches 0, which re-triggers this function via the AceBucket.
	local lootFrame = lootFrames[frame]
	if lootFrame and ((lootFrame.shiftingRowCount or 0) > 0 or lootFrame.hasPinnedRow) then
		return
	end
	local snapshotQueueSize = queue:size()
	if snapshotQueueSize > 0 then
		-- In my testing this was fine, but it's possible it could cause performance issues
		-- if the queue is large. This is what to revert if performance issues arise.
		-- local sizingDb = G_RLF.DbAccessor:Sizing(frame)
		local rowsToProcess = snapshotQueueSize -- math.min(snapshotQueueSize, sizingDb.maxRows)
		G_RLF:LogDebug("Processing " .. rowsToProcess .. " items from element queue")
		for i = 1, rowsToProcess do
			if queue:isEmpty() then
				return
			end
			local e = queue:dequeue()
			if e then
				processRow(e, frame)
			end
		end
	end
end

function LootDisplay:OnLootReady(_, element)
	for id, frame in pairs(lootFrames) do
		if frame and frame:IsFeatureEnabled(element) and frame:PassesPerFrameFilters(element) then
			frame._testAcceptCount = (frame._testAcceptCount or 0) + 1
			-- New loot resets any in-progress scroll sequence to avoid accidental
			-- history activation while new items are arriving.
			if frame.wheelState then
				G_RLF.HistoryService:ResetWheelState(frame.wheelState)
			end
			processRow(element, id)
		end
	end
end

--- Return the live frame widget for the given ID, or nil.
--- Intended for integration tests that need to read per-frame counters.
--- @param id integer
--- @return RLF_LootDisplayFrame|nil
function LootDisplay:GetFrame(id)
	return lootFrames[id]
end

--- Return an iterator over all live (id, frame) pairs.
--- @return fun(): integer?, RLF_LootDisplayFrame?
function LootDisplay:GetAllFrames()
	return pairs(lootFrames)
end

--- Called by the AceBucket when one or more rows have been released.
--- @param frames table<integer, integer> Table whose keys are the frame IDs
---   that returned rows during the bucket window.
function LootDisplay:OnRowReturn(frames)
	for id in pairs(frames) do
		processFromQueue(id)
	end
end

local function emptyQueues()
	for _, q in pairs(lootQueues) do
		while not q:isEmpty() do
			q:dequeue()
		end
	end
end

function LootDisplay:HideLoot()
	if lootFrames[G_RLF.Frames.MAIN] == nil then
		return
	end

	emptyQueues()
	for _, frame in pairs(lootFrames) do
		if frame then
			frame:ClearFeed()
		end
	end
end

--- Show sample rows in existing frames for options preview
function LootDisplay:ShowSampleRows()
	sampleRowsVisible = true
	for id, frame in pairs(lootFrames) do
		if frame then
			self:CreateSampleRows(id)
		end
	end
end

--- Hide sample rows from existing frames
function LootDisplay:HideSampleRows()
	sampleRowsVisible = false
	self:HideLoot()
end

--- Update sample rows when settings change.
--- Debounced: rapid calls (e.g. from a color picker) are coalesced so only
--- one hide+show cycle runs after a short delay.
function LootDisplay:UpdateSampleRows()
	if updateSampleRowsTimer then
		updateSampleRowsTimer:Cancel()
		updateSampleRowsTimer = nil
	end

	-- Remove existing sample rows immediately so the user sees the feed clear
	self:HideSampleRows()

	-- Re-show after a short delay; any new call within that window resets the timer
	updateSampleRowsTimer = C_Timer.NewTimer(0.1, function()
		updateSampleRowsTimer = nil
		self:ShowSampleRows()
	end)
end

--- Check if sample rows are currently shown and refresh them
function LootDisplay:RefreshSampleRowsIfShown()
	if sampleRowsVisible then
		self:UpdateSampleRows()
	end
end

G_RLF.LootDisplay = LootDisplay

return LootDisplay
