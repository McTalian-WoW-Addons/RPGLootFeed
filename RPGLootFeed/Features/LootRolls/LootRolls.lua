---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local FeatureBase = G_RLF.FeatureBase
local FeatureModule = G_RLF.FeatureModule
local DbAccessor = G_RLF.DbAccessor

local LogDebug = function(...)
	G_RLF:LogDebug(...)
end
local LogInfo = function(...)
	G_RLF:LogInfo(...)
end
local LogWarn = function(...)
	G_RLF:LogWarn(...)
end

-- ── WoW API / Global abstraction adapters ────────────────────────────────────
-- Captured here at module-load time so tests can override _adapter without
-- patching _G directly.

---@class RLF_LootRolls: RLF_Module, AceEvent-3.0, AceBucket-3.0
local LootRolls = FeatureBase:new(FeatureModule.LootRolls, "AceEvent-3.0", "AceBucket-3.0")

LootRolls._adapter = G_RLF.WoWAPI.LootRolls

-- rollID → { key, lootHandle, itemLink, itemID } — tracks active roll rows
LootRolls._activeRolls = nil
-- lootHandle → { [rollID] = true } — groups rollIDs by lootHandle for LOOT_ROLLS_COMPLETE
LootRolls._lootHandleMap = nil
-- encounterID → { lootListID → rollID } — matched loot history drops for live updates
LootRolls._historyMatchMap = nil
-- Periodic poll ticker for loot history coalescing
LootRolls._pollTicker = nil

local KEY_PREFIX = "LootRoll_"

--- Build the row key for a given rollID.
---@param rollID number
---@return string
local function rollKey(rollID)
	return KEY_PREFIX .. rollID
end

--- Find all rows matching a rollID across all live frames.
---@param rollID number
---@return {row: RLF_LootDisplayRow, frame: RLF_LootDisplayFrame}[]
function LootRolls:FindRollRows(rollID)
	local key = rollKey(rollID)
	local results = {}
	for _, frame in G_RLF.LootDisplay:GetAllFrames() do
		local row = frame:GetRow(key)
		if row then
			table.insert(results, { row = row, frame = frame })
		end
	end
	return results
end

--- Release loot roll rows for given rollID from all frames.
---@param rollID number
function LootRolls:ReleaseRollRows(rollID)
	local rows = self:FindRollRows(rollID)
	for _, entry in ipairs(rows) do
		entry.row:OnCancelRoll()
		entry.frame:ReleaseRow(entry.row)
	end
end

--- Clean up an active roll from all tracking tables.
---@param rollID number
function LootRolls:_UntrackRoll(rollID)
	if self._activeRolls then
		self._activeRolls[rollID] = nil
	end
	if self._lootHandleMap then
		for handle, rollSet in pairs(self._lootHandleMap) do
			rollSet[rollID] = nil
			if not next(rollSet) then
				self._lootHandleMap[handle] = nil
			end
		end
	end
	if self._historyMatchMap then
		for encID, dropMap in pairs(self._historyMatchMap) do
			for lootListID, rid in pairs(dropMap) do
				if rid == rollID then
					dropMap[lootListID] = nil
				end
			end
			if not next(dropMap) then
				self._historyMatchMap[encID] = nil
			end
		end
	end
	-- Stop poll ticker if no more active rolls
	if self._activeRolls and not next(self._activeRolls) and self._pollTicker then
		self._pollTicker:Cancel()
		self._pollTicker = nil
	end
end

-- ── Event Handlers ───────────────────────────────────────────────────────────

---@param rollID number
---@param rollTime number  Duration in seconds
---@param lootHandle number|nil
function LootRolls:START_LOOT_ROLL(rollID, rollTime, lootHandle)
	LogDebug("START_LOOT_ROLL", addonName, rollID, rollTime, lootHandle)

	-- Fetch item info via adapter
	local texture, name, count, quality = self._adapter.GetLootRollItemInfo(rollID)
	if not name then
		return
	end

	local itemLink = self._adapter.GetLootRollItemLink(rollID)
	if not itemLink then
		return
	end

	-- Build payload
	local payload = {
		key = rollKey(rollID),
		type = FeatureModule.LootRolls,
		icon = texture,
		quality = quality,
		isLink = true,
		textFn = function()
			return itemLink
		end,
		quantity = count or 1,
		showForSeconds = math.pow(2, 19), -- Never auto-fade; dismissed by events
		rollID = rollID,
		rollDuration = rollTime,
		IsEnabled = function()
			return LootRolls:IsEnabled()
		end,
	}
	local itemID = self._adapter.GetItemInfoInstant(itemLink)
	payload.filterItemId = itemID
	payload.filterItemQuality = quality
	-- Pass itemLink to the mixin for loot history matching
	payload.itemLink = itemLink

	-- Track the active roll
	if not self._activeRolls then
		self._activeRolls = {}
	end
	self._activeRolls[rollID] = { key = payload.key, lootHandle = lootHandle, itemLink = itemLink, itemID = itemID }

	-- Track lootHandle grouping
	if lootHandle then
		if not self._lootHandleMap then
			self._lootHandleMap = {}
		end
		if not self._lootHandleMap[lootHandle] then
			self._lootHandleMap[lootHandle] = {}
		end
		self._lootHandleMap[lootHandle][rollID] = true
	end

	-- Send through standard pipeline
	local element = G_RLF.LootElementBase:fromPayload(payload)
	element:Show(name, quality)
end

---@param rollID number
function LootRolls:CANCEL_LOOT_ROLL(rollID)
	LogDebug("CANCEL_LOOT_ROLL", addonName, rollID)
	self:ReleaseRollRows(rollID)
	self:_UntrackRoll(rollID)
end

function LootRolls:CANCEL_ALL_LOOT_ROLLS()
	LogDebug("CANCEL_ALL_LOOT_ROLLS", addonName)
	if not self._activeRolls then
		return
	end
	-- Snapshot rollIDs to avoid mutation during iteration
	local rollIDs = {}
	for rollID in pairs(self._activeRolls) do
		table.insert(rollIDs, rollID)
	end
	for _, rollID in ipairs(rollIDs) do
		self:ReleaseRollRows(rollID)
	end
	self._activeRolls = {}
	self._lootHandleMap = {}
end

---@param rollID number
---@param roll number
---@param isWinning boolean
function LootRolls:MAIN_SPEC_NEED_ROLL(rollID, roll, isWinning)
	LogDebug("MAIN_SPEC_NEED_ROLL", addonName, rollID, roll, isWinning)
	local rows = self:FindRollRows(rollID)
	for _, entry in ipairs(rows) do
		entry.row:OnMainSpecNeedRoll(roll, isWinning)
	end
end

---@param lootHandle number
function LootRolls:LOOT_ROLLS_COMPLETE(lootHandle)
	LogDebug("LOOT_ROLLS_COMPLETE", addonName, lootHandle)
	if not self._lootHandleMap then
		return
	end
	local rollIDs = self._lootHandleMap[lootHandle]
	if not rollIDs then
		return
	end
	-- Snapshot to avoid mutation
	local ids = {}
	for rollID in pairs(rollIDs) do
		table.insert(ids, rollID)
	end
	for _, rollID in ipairs(ids) do
		self:ReleaseRollRows(rollID)
		self:_UntrackRoll(rollID)
	end
end

-- ── Loot History Polling ─────────────────────────────────────────────────────

--- Find all loot history drops matching the itemID. Returns list of {encounterID, lootListID, dropInfo}.
---@param itemLink string
---@return table
function LootRolls:_FindMatchingHistoryDrops(itemLink)
	local itemID = self._adapter.GetItemInfoInstant(itemLink)
	if not itemID then
		return {}
	end

	local encounters = self._adapter.GetAllEncounterInfos()
	if not encounters then
		return {}
	end

	local matches = {}
	for _, encInfo in ipairs(encounters) do
		local drops = self._adapter.GetSortedDropsForEncounter(encInfo.encounterID)
		if drops then
			for _, dropInfo in ipairs(drops) do
				local dropItemID = self._adapter.GetItemInfoInstant(dropInfo.itemHyperlink)
				if dropItemID == itemID then
					table.insert(matches, {
						encounterID = encInfo.encounterID,
						lootListID = dropInfo.lootListID,
						dropInfo = dropInfo,
					})
				end
			end
		end
	end
	return matches
end

--- Check if a specific encounterID + lootListID pair is already claimed in historyMatchMap.
---@param encounterID number
---@param lootListID number
---@return boolean
function LootRolls:_IsDropClaimed(encounterID, lootListID)
	if not self._historyMatchMap then
		return false
	end
	local encMap = self._historyMatchMap[encounterID]
	if not encMap then
		return false
	end
	return encMap[lootListID] ~= nil
end

--- Poll loot history for all active rolls and push updates to rows.
function LootRolls:PollLootHistory()
	if not self._activeRolls or not next(self._activeRolls) then
		return
	end
	if not self._adapter.GetAllEncounterInfos then
		return
	end

	for rollID, info in pairs(self._activeRolls) do
		-- Skip already-matched rolls (live updates via LOOT_HISTORY_UPDATE_DROP)
		local alreadyMatched = false
		if self._historyMatchMap then
			for _, dropMap in pairs(self._historyMatchMap) do
				for _, rid in pairs(dropMap) do
					if rid == rollID then
						alreadyMatched = true
						break
					end
				end
				if alreadyMatched then
					break
				end
			end
		end
		if not alreadyMatched then
			local matches = self:_FindMatchingHistoryDrops(info.itemLink)
			-- Pick the first unclaimed drop (handles duplicate items from same boss)
			local claimed
			for _, match in ipairs(matches) do
				if not self:_IsDropClaimed(match.encounterID, match.lootListID) then
					claimed = match
					break
				end
			end
			if claimed then
				-- Store match for live updates
				if not self._historyMatchMap then
					self._historyMatchMap = {}
				end
				if not self._historyMatchMap[claimed.encounterID] then
					self._historyMatchMap[claimed.encounterID] = {}
				end
				self._historyMatchMap[claimed.encounterID][claimed.lootListID] = rollID

				-- Push results to row
				local rows = self:FindRollRows(rollID)
				for _, entry in ipairs(rows) do
					entry.row:SetRollResults(claimed.dropInfo)
				end
			end
		end
	end
end

--- Update a specific drop when LOOT_HISTORY_UPDATE_DROP fires.
---@param encounterID number
---@param lootListID number
function LootRolls:HandleHistoryDropUpdate(encounterID, lootListID)
	if not self._historyMatchMap then
		return
	end
	local encMap = self._historyMatchMap[encounterID]
	if not encMap then
		return
	end
	local rollID = encMap[lootListID]
	if not rollID then
		return
	end

	local dropInfo = self._adapter.GetSortedInfoForDrop(encounterID, lootListID)
	if not dropInfo then
		return
	end

	local rows = self:FindRollRows(rollID)
	for _, entry in ipairs(rows) do
		entry.row:SetRollResults(dropInfo)
		-- If there's a winner and the local player won, also update result text
		if dropInfo.winner and dropInfo.winner.isSelf then
			local rollType = dropInfo.winner.state
			local roll = dropInfo.winner.roll
			entry.row:OnRollWon(rollType, roll, false)
		end
	end
end

-- ── Additional Event Handlers ────────────────────────────────────────────────

---@param itemLink string
---@param quantity number
---@param rollType number
---@param roll number
---@param upgraded boolean
function LootRolls:LOOT_ITEM_ROLL_WON(itemLink, quantity, rollType, roll, upgraded)
	LogDebug("LOOT_ITEM_ROLL_WON", addonName, itemLink, rollType, roll)
	if not self._activeRolls then
		return
	end

	-- Find matching roll by itemID comparison
	local wonItemID = self._adapter.GetItemInfoInstant(itemLink)
	if not wonItemID then
		return
	end

	for rollID, info in pairs(self._activeRolls) do
		if info.itemID == wonItemID then
			local rows = self:FindRollRows(rollID)
			for _, entry in ipairs(rows) do
				entry.row:OnRollWon(rollType, roll, upgraded)
			end
		end
	end
end

---@param encounterID number
---@param lootListID number
function LootRolls:LOOT_HISTORY_UPDATE_DROP(encounterID, lootListID)
	self:HandleHistoryDropUpdate(encounterID, lootListID)
end

---@param encounterID number
function LootRolls:LOOT_HISTORY_UPDATE_ENCOUNTER(encounterID)
	-- Full re-poll for this encounter to catch any unmatched drops
	if not self._historyMatchMap or not self._historyMatchMap[encounterID] then
		return
	end
	-- Trigger a full poll on next tick
	self:PollLootHistory()
end

-- ── Module Lifecycle ─────────────────────────────────────────────────────────

function LootRolls:OnInitialize()
	LogDebug("LootRolls:OnInitialize()", addonName, self.moduleName)
	if DbAccessor:IsFeatureNeededByAnyFrame("lootRolls") then
		self:Enable()
	else
		self:Disable()
	end
end

function LootRolls:OnDisable()
	self:UnregisterEvent("START_LOOT_ROLL")
	self:UnregisterEvent("CANCEL_LOOT_ROLL")
	self:UnregisterEvent("CANCEL_ALL_LOOT_ROLLS")
	self:UnregisterEvent("MAIN_SPEC_NEED_ROLL")
	self:UnregisterEvent("LOOT_ROLLS_COMPLETE")
	self:UnregisterEvent("LOOT_ITEM_ROLL_WON")
	self:UnregisterEvent("LOOT_HISTORY_UPDATE_DROP")
	self:UnregisterEvent("LOOT_HISTORY_UPDATE_ENCOUNTER")

	-- Stop poll ticker
	if self._pollTicker then
		self._pollTicker:Cancel()
		self._pollTicker = nil
	end

	-- Release any active roll rows
	self:CANCEL_ALL_LOOT_ROLLS()
end

function LootRolls:OnEnable()
	LogDebug("OnEnable", addonName, self.moduleName)

	self:RegisterEvent("START_LOOT_ROLL")
	self:RegisterEvent("CANCEL_LOOT_ROLL")
	self:RegisterEvent("CANCEL_ALL_LOOT_ROLLS")
	self:RegisterEvent("MAIN_SPEC_NEED_ROLL")
	self:RegisterEvent("LOOT_ROLLS_COMPLETE")
	self:RegisterEvent("LOOT_ITEM_ROLL_WON")
	self:RegisterEvent("LOOT_HISTORY_UPDATE_DROP")
	self:RegisterEvent("LOOT_HISTORY_UPDATE_ENCOUNTER")

	-- Start periodic poll for loot history coalescing (1s interval)
	if not self._pollTicker then
		self._pollTicker = C_Timer.NewTicker(1, function()
			self:PollLootHistory()
		end)
	end

	-- Replay any active rolls that exist from before (UI reload, etc.)
	C_Timer.After(0, function()
		self:ReplayActiveRolls()
	end)
end

function LootRolls:ReplayActiveRolls()
	local pendingRollIDs = self._adapter.GetActiveLootRollIDs()
	if not pendingRollIDs or #pendingRollIDs == 0 then
		return
	end

	LogDebug("ReplayActiveRolls", addonName, #pendingRollIDs)
	for _, rollID in ipairs(pendingRollIDs) do
		local duration = self._adapter.GetLootRollDuration(rollID)
		self:START_LOOT_ROLL(rollID, duration)
	end
end
