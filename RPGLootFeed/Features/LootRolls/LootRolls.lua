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

-- rollID → { key, lootHandle } — tracks active roll rows across all frames
LootRolls._activeRolls = nil
-- lootHandle → { [rollID] = true } — groups rollIDs by lootHandle for LOOT_ROLLS_COMPLETE
LootRolls._lootHandleMap = nil

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

--- Clean up an active roll from tracking tables.
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
	payload.filterItemId = self._adapter.GetItemInfoInstant(itemLink)
	payload.filterItemQuality = quality

	-- Track the active roll
	if not self._activeRolls then
		self._activeRolls = {}
	end
	self._activeRolls[rollID] = { key = payload.key, lootHandle = lootHandle }

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
