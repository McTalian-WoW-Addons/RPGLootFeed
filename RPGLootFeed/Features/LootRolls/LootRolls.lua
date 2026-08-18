---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- logging injected via FeatureBase DI

-- ── WoW API / Global abstraction adapters ────────────────────────────────────
-- Captured here at module-load time so tests can override _adapter without
-- patching _G directly.

---@class RLF_LootRolls: RLF_Module, AceEvent-3.0, AceBucket-3.0
local LootRolls = G_RLF.FeatureBase:new("LootRolls", { logging = true }, "AceEvent-3.0", "AceBucket-3.0")

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

---@param eventName string
---@param rollID number
---@param rollTime number  Duration in seconds
---@param lootHandle number|nil
function LootRolls:START_LOOT_ROLL(eventName, rollID, rollTime, lootHandle)
	self:LogDebug(eventName, G_RLF.LogEventSource.WOWEVENT, self.moduleName, rollID, nil, rollTime)

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
		type = G_RLF.FeatureModule.LootRolls,
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
		moduleRef = LootRolls,
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

---@param eventName string
---@param rollID number
function LootRolls:CANCEL_LOOT_ROLL(eventName, rollID)
	self:LogDebug(eventName, G_RLF.LogEventSource.WOWEVENT, self.moduleName, rollID)

	-- Stop timer polling. Row stays as unresolved results row until
	-- SetRollResults or LOOT_ROLLS_COMPLETE triggers OnRollResolved.
	local rows = self:FindRollRows(rollID)
	for _, entry in ipairs(rows) do
		entry.row:OnCancelRoll()
	end
end

function LootRolls:CANCEL_ALL_LOOT_ROLLS(eventName)
	self:LogDebug(eventName, G_RLF.LogEventSource.WOWEVENT, self.moduleName)
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

---@param eventName string
---@param rollID number
---@param roll number
---@param isWinning boolean
function LootRolls:MAIN_SPEC_NEED_ROLL(eventName, rollID, roll, isWinning)
	self:LogDebug(eventName, G_RLF.LogEventSource.WOWEVENT, self.moduleName, rollID, nil, roll, isWinning)
	local rows = self:FindRollRows(rollID)
	for _, entry in ipairs(rows) do
		entry.row:OnMainSpecNeedRoll(roll, isWinning)
	end
end

---@param eventName string
---@param lootHandle number
function LootRolls:LOOT_ROLLS_COMPLETE(eventName, lootHandle)
	self:LogDebug(eventName, G_RLF.LogEventSource.WOWEVENT, self.moduleName, nil, nil, lootHandle)
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

	-- Stop timer polling and extend row lifetime for result display
	-- Tracking stays alive so pending HandleHistoryDropUpdate events can still
	-- reach the row during the exit animation fade window. _UntrackRoll runs
	-- when the row is released (CleanupLootRoll).
	for _, rollID in ipairs(ids) do
		local rows = self:FindRollRows(rollID)
		for _, entry in ipairs(rows) do
			entry.row:OnCancelRoll()
			entry.row:OnRollResolved()
		end
	end

	self:LogDebug("LOOT_ROLLS_COMPLETE_resolved", addonName, self.moduleName, nil, nil, #ids)
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
				self:LogDebug("PollLootHistory_match", addonName, self.moduleName, rollID, nil, claimed.encounterID)
				for _, entry in ipairs(rows) do
					entry.row:SetRollResults(claimed.dropInfo)
				end
			end
		end
	end
end

--- Map a Retail EncounterLootDropRollState (dropInfo.winner.state: 0/1=need,
--- 2=transmog, 3=greed) to the LOOT_ROLL_TYPE_*-shaped numbering
--- RLF_LootRollRowMixin:OnRollWon expects (matching the real
--- LOOT_ITEM_ROLL_WON event's rollType argument: 1=need, 2=greed,
--- 3=disenchant, 4=transmog). These are different enums — passing .state
--- straight through mislabels wins (a Greed win renders as "Disenchant Won!").
---@param state number
---@return number?
local function encounterLootStateToRollType(state)
	if state == 0 or state == 1 then
		return 1 -- NEED
	elseif state == 2 then
		return 4 -- TRANSMOGRIFICATION
	elseif state == 3 then
		return 2 -- GREED
	end
	return nil
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
	self:LogDebug("HandleHistoryDropUpdate_push", addonName, self.moduleName, rollID, nil, encounterID)
	for _, entry in ipairs(rows) do
		entry.row:SetRollResults(dropInfo)
		-- If there's a winner and the local player won, also update result text
		if dropInfo.winner and dropInfo.winner.isSelf then
			local rollType = encounterLootStateToRollType(dropInfo.winner.state)
			local roll = dropInfo.winner.roll
			entry.row:OnRollWon(rollType, roll, false)
		end
	end
end

-- ── Additional Event Handlers ────────────────────────────────────────────────

---@param eventName string
---@param itemLink string
---@param quantity number
---@param rollType number
---@param roll number
---@param upgraded boolean
function LootRolls:LOOT_ITEM_ROLL_WON(eventName, itemLink, quantity, rollType, roll, upgraded)
	self:LogDebug(eventName, G_RLF.LogEventSource.WOWEVENT, self.moduleName, nil, nil, rollType)
	if not self._activeRolls then
		return
	end

	-- Find matching roll by itemID comparison
	local wonItemID = self._adapter.GetItemInfoInstant(itemLink)
	if not wonItemID then
		return
	end

	-- Blizzard's LOOT_ITEM_ROLL_WON payload carries no rollID (verified
	-- against wow-ui-source), so when two concurrent rolls share the same
	-- itemID we can't perfectly tell which one this event resolved. Mark
	-- only the first not-yet-resolved match and stop — marking every
	-- match would falsely flag still-active rolls as won.
	for rollID, info in pairs(self._activeRolls) do
		if info.itemID == wonItemID and not info.resolved then
			info.resolved = true
			local rows = self:FindRollRows(rollID)
			for _, entry in ipairs(rows) do
				entry.row:OnRollWon(rollType, roll, upgraded)
			end
			break
		end
	end
end

---@param eventName string
---@param encounterID number
---@param lootListID number
function LootRolls:LOOT_HISTORY_UPDATE_DROP(eventName, encounterID, lootListID)
	self:LogDebug(eventName, G_RLF.LogEventSource.WOWEVENT, self.moduleName, encounterID, nil, lootListID)
	self:HandleHistoryDropUpdate(encounterID, lootListID)
end

---@param eventName string
---@param encounterID number
function LootRolls:LOOT_HISTORY_UPDATE_ENCOUNTER(eventName, encounterID)
	self:LogDebug(eventName, G_RLF.LogEventSource.WOWEVENT, self.moduleName, encounterID)
	-- Full re-poll for this encounter to catch any unmatched drops
	if not self._historyMatchMap or not self._historyMatchMap[encounterID] then
		return
	end
	-- Trigger a full poll on next tick
	self:PollLootHistory()
end

-- ── Classic Era / TBC Anniversary / MoP Classic: C_LootHistory Polling ───────
-- All three ship the same older, index-based C_LootHistory shape
-- (GetNumItems/GetItem/GetPlayerInfo) that Blizzard's own Classic loot
-- history frame calls directly — verified against wow-ui-source's
-- classic_era, classic_anniversary, and classic branches, and against
-- wago.tools' GlobalStrings export per flavor. Not a chat-parsing problem.
--
-- GetItem(itemIdx) returns rollID as its first value — the same rollID
-- space START_LOOT_ROLL/CANCEL_LOOT_ROLL/LOOT_ROLLS_COMPLETE already use —
-- so active rolls correlate directly, unlike Retail's GetAllEncounterInfos
-- API, which requires matching drops to rolls by itemLink/itemID.

--- Map a Classic LOOT_ROLL_TYPE_* roll type (nil meaning "hasn't rolled
--- yet") to the addon's internal rollInfo state convention used throughout
--- LootRollRowMixin.lua (see the comment above the state ladder in
--- _BuildRollTooltipLines): 0/1=need, 2=transmog, 3=greed, 4=waiting,
--- 5=pass, 6=disenchant. 6 is an addon-internal extension — Retail's real
--- Enum.EncounterLootDropRollState only defines 0-5 and has no Disenchant
--- roll option, but Classic does.
---@param rollType number?
---@return number
local function classicRollTypeToState(rollType)
	if rollType == nil then
		return 4
	elseif rollType == LOOT_ROLL_TYPE_NEED then
		return 0
	elseif rollType == LOOT_ROLL_TYPE_GREED then
		return 3
	elseif rollType == LOOT_ROLL_TYPE_DISENCHANT then
		return 6
	end
	return 5 -- LOOT_ROLL_TYPE_PASS
end

--- Build an EncounterLootDropInfo-shaped table for SetRollResults from the
--- Classic-shape C_LootHistory API.
---@param itemIdx number
---@return number? rollID
---@return table? dropInfo
function LootRolls:_BuildClassicDropInfoFromHistory(itemIdx)
	local rollID, itemLink, numPlayers, isDone, winnerIdx = self._adapter.GetItem(itemIdx)
	if not rollID then
		return nil, nil
	end

	local rollInfos = {}
	local bestRoll, bestPlayerIdx = nil, nil
	for i = 1, numPlayers or 0 do
		local name, class, rollType, roll, isWinner, isMe = self._adapter.GetPlayerInfo(itemIdx, i)
		table.insert(rollInfos, {
			playerName = name,
			playerClass = class or "UNKNOWN",
			state = classicRollTypeToState(rollType),
			roll = roll,
			isWinner = isWinner or false,
			isSelf = isMe or false,
		})
		if roll and (bestRoll == nil or roll > bestRoll) then
			bestRoll = roll
			bestPlayerIdx = i
		end
	end

	local winner = nil
	if winnerIdx then
		local name, class, rollType, roll, _, isMe = self._adapter.GetPlayerInfo(itemIdx, winnerIdx)
		winner = {
			playerName = name,
			playerClass = class or "UNKNOWN",
			roll = roll,
			isSelf = isMe or false,
			state = classicRollTypeToState(rollType),
			-- Raw LOOT_ROLL_TYPE_* value for OnRollWon, which uses that
			-- numbering, not the `state` convention above.
			rollType = rollType,
		}
	end

	local currentLeader = nil
	if not isDone and bestPlayerIdx then
		local name, class = self._adapter.GetPlayerInfo(itemIdx, bestPlayerIdx)
		currentLeader = { playerName = name, playerClass = class or "UNKNOWN", roll = bestRoll }
	end

	return rollID,
		{
			lootListID = itemIdx,
			itemHyperlink = itemLink,
			rollInfos = rollInfos,
			winner = winner,
			currentLeader = currentLeader,
		}
end

--- Poll C_LootHistory for all active rolls and push updates to rows.
--- No claim-tracking needed here, unlike PollLootHistory: GetItem(itemIdx)
--- returns the exact rollID directly, so there's no itemLink-matching
--- ambiguity to resolve.
function LootRolls:PollClassicLootHistory()
	if not self._activeRolls or not next(self._activeRolls) then
		return
	end
	local numItems = self._adapter.GetNumItems()
	for itemIdx = 1, numItems do
		local rollID, dropInfo = self:_BuildClassicDropInfoFromHistory(itemIdx)
		if rollID and self._activeRolls[rollID] then
			local rows = self:FindRollRows(rollID)
			self:LogDebug("PollClassicLootHistory_match", addonName, self.moduleName, rollID, nil, itemIdx)
			for _, entry in ipairs(rows) do
				entry.row:SetRollResults(dropInfo)
			end
		end
	end
end

---@param eventName string
---@param itemIdx number
---@param playerIdx number
function LootRolls:LOOT_HISTORY_ROLL_CHANGED(eventName, itemIdx, playerIdx)
	self:LogDebug(eventName, G_RLF.LogEventSource.WOWEVENT, self.moduleName, itemIdx, nil, playerIdx)
	if not self._activeRolls or not next(self._activeRolls) then
		return
	end

	local rollID, dropInfo = self:_BuildClassicDropInfoFromHistory(itemIdx)
	if not rollID or not self._activeRolls[rollID] then
		return
	end

	local rows = self:FindRollRows(rollID)
	for _, entry in ipairs(rows) do
		entry.row:SetRollResults(dropInfo)
		if dropInfo.winner and dropInfo.winner.isSelf then
			entry.row:OnRollWon(dropInfo.winner.rollType, dropInfo.winner.roll, false)
		end
	end
end

---@param eventName string
function LootRolls:LOOT_HISTORY_ROLL_COMPLETE(eventName)
	self:LogDebug(eventName, G_RLF.LogEventSource.WOWEVENT, self.moduleName)
	-- Full re-poll to catch any rolls whose final LOOT_HISTORY_ROLL_CHANGED
	-- landed before this handler ran.
	self:PollClassicLootHistory()
end

-- ── Module Lifecycle ─────────────────────────────────────────────────────────

function LootRolls:OnInitialize()
	self:LogDebug("LootRolls:OnInitialize()", addonName, self.moduleName)
	if G_RLF.DbAccessor:IsFeatureNeededByAnyFrame("lootRolls") then
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
	if not G_RLF:IsRetail() then
		self:UnregisterEvent("LOOT_HISTORY_ROLL_CHANGED")
		self:UnregisterEvent("LOOT_HISTORY_ROLL_COMPLETE")
	end

	-- Stop poll ticker
	if self._pollTicker then
		self._pollTicker:Cancel()
		self._pollTicker = nil
	end

	-- Release any active roll rows
	self:CANCEL_ALL_LOOT_ROLLS()
end

function LootRolls:OnEnable()
	self:LogDebug("OnEnable", addonName, self.moduleName)

	self:RegisterEvent("START_LOOT_ROLL")
	self:RegisterEvent("CANCEL_LOOT_ROLL")
	self:RegisterEvent("CANCEL_ALL_LOOT_ROLLS")
	self:RegisterEvent("MAIN_SPEC_NEED_ROLL")
	self:RegisterEvent("LOOT_ROLLS_COMPLETE")
	self:RegisterEvent("LOOT_ITEM_ROLL_WON")

	local pollFn
	if not G_RLF:IsRetail() then
		-- Classic Era, TBC Anniversary, MoP Classic: same older, index-based
		-- C_LootHistory shape (GetNumItems/GetItem/GetPlayerInfo).
		self:RegisterEvent("LOOT_HISTORY_ROLL_CHANGED")
		self:RegisterEvent("LOOT_HISTORY_ROLL_COMPLETE")
		pollFn = self.PollClassicLootHistory
	else
		-- Retail: live updates via loot history events
		self:RegisterEvent("LOOT_HISTORY_UPDATE_DROP")
		self:RegisterEvent("LOOT_HISTORY_UPDATE_ENCOUNTER")
		pollFn = self.PollLootHistory
	end

	-- Start periodic poll for loot history coalescing (1s interval)
	if not self._pollTicker then
		self._pollTicker = C_Timer.NewTicker(1, function()
			pollFn(self)
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

	self:LogDebug("ReplayActiveRolls", addonName, #pendingRollIDs)
	for _, rollID in ipairs(pendingRollIDs) do
		local duration = self._adapter.GetLootRollDuration(rollID)
		self:START_LOOT_ROLL("START_LOOT_ROLL", rollID, duration)
	end
end

return LootRolls
