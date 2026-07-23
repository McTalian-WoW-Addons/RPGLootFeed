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
	self:ReleaseRollRows(rollID)
	self:_UntrackRoll(rollID)
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

	for rollID, info in pairs(self._activeRolls) do
		if info.itemID == wonItemID then
			local rows = self:FindRollRows(rollID)
			for _, entry in ipairs(rows) do
				entry.row:OnRollWon(rollType, roll, upgraded)
			end
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

-- ── Classic Era: CHAT_MSG_LOOT Parsing ────────────────────────────────────
-- Classic Era has no C_LootHistory API. Roll results are parsed from chat.
-- Each entry tracks per-item roll state as EncounterLootDropInfo-like data.

--- Pattern cache for converting GlobalString format strings to Lua match patterns.
---@type table<string, string>
local _classicPatterns = nil

--- Convert a printf-style GlobalString like "%s rolls a %d on: %s" to a Lua pattern.
--- Replaces %d with (%d+), %s with (.+), and escapes Lua pattern magic chars.
---@param fmt string
---@return string
local function fmtToPattern(fmt)
	-- Escape Lua pattern magic characters first (except % which we handle next)
	local p = fmt:gsub("([%.%[%]%(%)%^%$%*%+%-%?])", "%%%1")
	-- Convert format specifiers: %d → capture digits, %s → capture anything, %% → literal %
	p = p:gsub("%%d", "(%d+)")
	p = p:gsub("%%s", "(.+)")
	p = p:gsub("%%%%", "%%")
	return p
end

--- Build a pseudo-dropInfo-like table from classic roll data for SetRollResults.
---@param itemLink string
---@return table?
function LootRolls:_BuildClassicDropInfo(itemLink)
	if not self._classicRollData or not self._classicRollData[itemLink] then
		return nil
	end
	local data = self._classicRollData[itemLink]
	if not data.players or not next(data.players) then
		return nil
	end

	local rollInfos = {}
	local waitingCount = 0
	local allPassed = true
	for name, info in pairs(data.players) do
		local ri = {
			playerName = name,
			playerClass = info.playerClass or "UNKNOWN",
			state = info.state,
			roll = info.roll,
			isWinner = info.isWinner or false,
			isSelf = info.isSelf or false,
		}
		table.insert(rollInfos, ri)
		if info.state ~= 5 and info.state ~= 4 then
			allPassed = false
		end
		if info.state == 4 then
			waitingCount = waitingCount + 1
		end
	end

	return {
		lootListID = 0,
		itemHyperlink = itemLink,
		rollInfos = rollInfos,
		winner = data.winner,
		currentLeader = data.currentLeader,
		allPassed = allPassed or data.allPassed,
		startTime = data.startTime or 0,
		duration = data.duration or 60,
	}
end

--- Push classic roll data to matching rows.
---@param itemLink string
function LootRolls:_PushClassicRollUpdate(itemLink)
	if not self._activeRolls then
		return
	end
	local dropInfo = self:_BuildClassicDropInfo(itemLink)
	if not dropInfo then
		return
	end
	for rollID, info in pairs(self._activeRolls) do
		if info.itemLink == itemLink or info.itemID == self._adapter.GetItemInfoInstant(itemLink) then
			local rows = self:FindRollRows(rollID)
			for _, entry in ipairs(rows) do
				entry.row:SetRollResults(dropInfo)
			end
		end
	end
end

---@param eventName string
---@param msg string  The formatted chat message
---@param playerName string  Sender name
---@param ... string  Additional args per CHAT_MSG_LOOT signature
function LootRolls:CHAT_MSG_LOOT(eventName, msg, playerName, _, _, playerName2, _, _, _, _, _, guid)
	-- Only used on Classic Era (no C_LootHistory)
	if G_RLF:IsRetail() then
		return
	end
	if not self._activeRolls or not next(self._activeRolls) then
		return
	end

	-- Build pattern cache on first use
	if not _classicPatterns then
		_classicPatterns = {}
		local globalStrings = {
			{ key = "ROLLED_NEED_SELF", fmt = LOOT_ROLL_ROLLED_NEED_SELF, state = 0 },
			{ key = "ROLLED_GREED_SELF", fmt = LOOT_ROLL_ROLLED_GREED_SELF, state = 3 },
			{ key = "ROLLED_NEED", fmt = LOOT_ROLL_ROLLED_NEED, state = 0 },
			{ key = "ROLLED_GREED", fmt = LOOT_ROLL_ROLLED_GREED, state = 3 },
			{ key = "ROLLED_SELF", fmt = LOOT_ROLL_ROLLED_SELF, state = -1 },
			{ key = "ROLLED", fmt = LOOT_ROLL_ROLLED, state = -1 },
			{ key = "PASSED_SELF", fmt = LOOT_ROLL_PASSED_SELF, state = 5 },
			{ key = "PASSED", fmt = LOOT_ROLL_PASSED, state = 5 },
			{ key = "WON", fmt = LOOT_ROLL_WON, state = -2 },
			{ key = "YOU_WON", fmt = LOOT_ROLL_YOU_WON, state = -2 },
			{ key = "ALL_PASSED", fmt = LOOT_ROLL_ALL_PASSED, state = -3 },
		}
		for _, gs in ipairs(globalStrings) do
			_classicPatterns[gs.key] = {
				pattern = fmtToPattern(gs.fmt),
				state = gs.state,
			}
		end
	end

	-- Try to match against each known roll pattern
	for key, cp in pairs(_classicPatterns) do
		local captures = { msg:match(cp.pattern) }
		if #captures > 0 then
			self:LogDebug(eventName, G_RLF.LogEventSource.WOWEVENT, self.moduleName, nil, key .. ": " .. msg)

			if key == "ROLLED_NEED_SELF" then
				-- captures: rollValue, itemLinkRest...
				local rollValue = tonumber(captures[1])
				-- Extract item link from the message fragment
				local itemLink = msg:match("|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[(.-)%]|h")
				if itemLink then
					self:_RecordClassicRoll(UnitName("player"), 0, rollValue, true, itemLink)
				end
			elseif key == "ROLLED_GREED_SELF" then
				local rollValue = tonumber(captures[1])
				local itemLink = msg:match("|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[(.-)%]|h")
				if itemLink then
					self:_RecordClassicRoll(UnitName("player"), 3, rollValue, true, itemLink)
				end
			elseif key == "ROLLED_NEED" then
				-- captures: lootHistoryID, rollValue, itemName, rollerName (from "Need Roll - %d for %s by %s")
				local rollValue = tonumber(captures[2])
				local rollerName = captures[4]
				local itemLink = msg:match("|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[(.-)%]|h")
				if itemLink and rollerName then
					self:_RecordClassicRoll(rollerName, 0, rollValue, false, itemLink)
				end
			elseif key == "ROLLED_GREED" then
				local rollValue = tonumber(captures[2])
				local rollerName = captures[4]
				local itemLink = msg:match("|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[(.-)%]|h")
				if itemLink and rollerName then
					self:_RecordClassicRoll(rollerName, 3, rollValue, false, itemLink)
				end
			elseif key == "PASSED_SELF" then
				-- captures: lootHistoryID, itemName
				local itemLink = msg:match("|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[(.-)%]|h")
				if itemLink then
					self:_RecordClassicRoll(UnitName("player"), 5, nil, true, itemLink)
				end
			elseif key == "PASSED" then
				-- captures: lootHistoryID, playerName, itemName
				local passedName = captures[2]
				local itemLink = msg:match("|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[(.-)%]|h")
				if itemLink and passedName then
					self:_RecordClassicRoll(passedName, 5, nil, false, itemLink)
				end
			elseif key == "YOU_WON" then
				local itemLink = msg:match("|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[(.-)%]|h")
				if itemLink then
					self:_RecordClassicWinner(UnitName("player"), true, itemLink)
				end
			elseif key == "WON" then
				-- captures: lootHistoryID, winnerName, itemName
				local winnerName = captures[2]
				local itemLink = msg:match("|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[(.-)%]|h")
				if itemLink and winnerName then
					self:_RecordClassicWinner(winnerName, false, itemLink)
				end
			elseif key == "ALL_PASSED" then
				local itemLink = msg:match("|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[(.-)%]|h")
				if itemLink then
					self:_RecordClassicAllPassed(itemLink)
				end
			end
			break
		end
	end
end

--- Record a player's roll selection on Classic.
function LootRolls:_RecordClassicRoll(playerName, state, rollValue, isSelf, itemLink)
	if not self._classicRollData then
		self._classicRollData = {}
	end
	if not self._classicRollData[itemLink] then
		self._classicRollData[itemLink] = {
			players = {},
			startTime = time(),
			duration = 60,
		}
	end
	local data = self._classicRollData[itemLink]
	local _, classFile = UnitClass(playerName)
	data.players[playerName] = {
		state = state,
		roll = rollValue,
		isSelf = isSelf,
		playerClass = classFile or "UNKNOWN",
		isWinner = false,
	}
	self:_UpdateClassicLeader(itemLink)
	self:_PushClassicRollUpdate(itemLink)
end

--- Update the current leader for a classic roll.
function LootRolls:_UpdateClassicLeader(itemLink)
	local data = self._classicRollData and self._classicRollData[itemLink]
	if not data then
		return
	end
	local bestRoll, bestPlayer = nil, nil
	for name, info in pairs(data.players) do
		if info.roll and (bestRoll == nil or info.roll > bestRoll) then
			bestRoll = info.roll
			bestPlayer = name
		end
	end
	if bestPlayer then
		data.currentLeader = {
			playerName = bestPlayer,
			playerClass = data.players[bestPlayer].playerClass,
			roll = bestRoll,
		}
	end
end

function LootRolls:_RecordClassicWinner(winnerName, isSelf, itemLink)
	local data = self._classicRollData and self._classicRollData[itemLink]
	if not data then
		return
	end
	for name, info in pairs(data.players) do
		info.isWinner = name == winnerName
	end
	-- Also add winner to players table if not already there
	if not data.players[winnerName] then
		local _, classFile = UnitClass(winnerName)
		data.players[winnerName] = {
			state = 0,
			roll = 100,
			isSelf = isSelf,
			playerClass = classFile or "UNKNOWN",
			isWinner = true,
		}
	end
	data.winner = {
		playerName = winnerName,
		playerClass = data.players[winnerName].playerClass,
		roll = data.players[winnerName].roll or 100,
		isSelf = isSelf,
		state = data.players[winnerName].state or 0,
	}
	self:_PushClassicRollUpdate(itemLink)
end

function LootRolls:_RecordClassicAllPassed(itemLink)
	local data = self._classicRollData and self._classicRollData[itemLink]
	if not data then
		return
	end
	data.allPassed = true
	self:_PushClassicRollUpdate(itemLink)
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
		self:UnregisterEvent("CHAT_MSG_LOOT")
	end

	-- Stop poll ticker
	if self._pollTicker then
		self._pollTicker:Cancel()
		self._pollTicker = nil
	end

	-- Release any active roll rows
	self:CANCEL_ALL_LOOT_ROLLS()
	self._classicRollData = nil
end

function LootRolls:OnEnable()
	self:LogDebug("OnEnable", addonName, self.moduleName)

	self:RegisterEvent("START_LOOT_ROLL")
	self:RegisterEvent("CANCEL_LOOT_ROLL")
	self:RegisterEvent("CANCEL_ALL_LOOT_ROLLS")
	self:RegisterEvent("MAIN_SPEC_NEED_ROLL")
	self:RegisterEvent("LOOT_ROLLS_COMPLETE")
	self:RegisterEvent("LOOT_ITEM_ROLL_WON")
	if not G_RLF:IsRetail() then
		-- Classic Era: parse roll results from chat (no C_LootHistory)
		self:RegisterEvent("CHAT_MSG_LOOT")
	else
		-- Retail: live updates via loot history events
		self:RegisterEvent("LOOT_HISTORY_UPDATE_DROP")
		self:RegisterEvent("LOOT_HISTORY_UPDATE_ENCOUNTER")

		-- Start periodic poll for loot history coalescing (1s interval)
		if not self._pollTicker then
			self._pollTicker = C_Timer.NewTicker(1, function()
				self:PollLootHistory()
			end)
		end
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
		self:START_LOOT_ROLL(rollID, duration)
	end
end
