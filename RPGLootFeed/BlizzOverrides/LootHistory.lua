---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class LootHistoryOverride: RLF_Module, AceEvent-3.0
---@field _autoShowSuppressed boolean
local LootHistoryOverride = G_RLF.RLF:NewModule(G_RLF.BlizzModule.LootHistory, "AceEvent-3.0")

local AUTO_OPEN_CVAR = "autoOpenLootHistory"

--- Mainline (Retail, WoW Forever) opens GroupLootHistoryFrame on
--- LOOT_HISTORY_GO_TO_ENCOUNTER, so its auto-open is suppressed by
--- unregistering that event. Returns nil when there is no frame or its
--- ShouldAutoOpen() says false (Forever's Camelot override).
---@return Frame?
local function mainlineFrame()
	local frame = GroupLootHistoryFrame
	if frame and not (frame.ShouldAutoOpen and not frame:ShouldAutoOpen()) then
		return frame
	end
end

--- Classic flavors open LootHistoryFrame on LOOT_HISTORY_AUTO_SHOW when the
--- autoOpenLootHistory CVar is set, or when the player is the master looter.
--- Unregistering the event would also block the master-looter path, which RLF
--- doesn't replace, so only the CVar is changed.
---@return boolean
local function classicCVarAvailable()
	return LootHistoryFrame ~= nil and G_RLF.WoWAPI.LootHistory.GetCVar(AUTO_OPEN_CVAR) ~= nil
end

function LootHistoryOverride:OnInitialize()
	self._autoShowSuppressed = false
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "ApplyAutoShowSetting")
end

--- Whether this client has an auto-open the option can suppress. Drives the
--- config toggle's disabled state.
---@return boolean
function LootHistoryOverride:IsAutoShowSupported()
	return mainlineFrame() ~= nil or classicCVarAvailable()
end

--- Match Blizzard's auto-open to the disableBlizzLootHistoryAutoShow setting.
--- Called on login and from config. Mainline: unregister/restore the frame's
--- event. Classic: set the CVar to 0, remembering the player's value so turning
--- the option off restores it (persisted, since the CVar outlives the session).
function LootHistoryOverride:ApplyAutoShowSetting()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	local suppress = G_RLF.db.global.blizzOverrides.disableBlizzLootHistoryAutoShow

	local frame = mainlineFrame()
	if frame then
		if suppress and not self._autoShowSuppressed then
			frame:UnregisterEvent("LOOT_HISTORY_GO_TO_ENCOUNTER")
			self._autoShowSuppressed = true
		elseif not suppress and self._autoShowSuppressed then
			-- Only re-register what we removed; never touch a frame left at defaults.
			frame:RegisterEvent("LOOT_HISTORY_GO_TO_ENCOUNTER")
			self._autoShowSuppressed = false
		end
		return
	end

	if not classicCVarAvailable() then
		return
	end
	local api = G_RLF.WoWAPI.LootHistory
	local overrides = G_RLF.db.global.blizzOverrides
	if suppress then
		if overrides.lootHistoryCVarBackup == nil then
			overrides.lootHistoryCVarBackup = api.GetCVar(AUTO_OPEN_CVAR)
		end
		api.SetCVar(AUTO_OPEN_CVAR, "0")
	elseif overrides.lootHistoryCVarBackup ~= nil then
		api.SetCVar(AUTO_OPEN_CVAR, overrides.lootHistoryCVarBackup)
		overrides.lootHistoryCVarBackup = nil
	end
end

return LootHistoryOverride
