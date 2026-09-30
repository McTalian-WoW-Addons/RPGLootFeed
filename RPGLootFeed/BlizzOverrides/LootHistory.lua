---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class LootHistoryOverride: RLF_Module, AceEvent-3.0
---@field _autoShowSuppressed boolean
local LootHistoryOverride = G_RLF.RLF:NewModule(G_RLF.BlizzModule.LootHistory, "AceEvent-3.0")

--- The Blizzard loot history frame and the event that pops it open on its own.
--- Mainline (Retail, WoW Forever) opens GroupLootHistoryFrame on
--- LOOT_HISTORY_GO_TO_ENCOUNTER; Classic flavors open LootHistoryFrame on
--- LOOT_HISTORY_AUTO_SHOW. /loot calls ToggleLootHistoryFrame directly, so it
--- keeps working while the event is unregistered.
---@return Frame?, string?
local function autoShowTarget()
	if GroupLootHistoryFrame then
		return GroupLootHistoryFrame, "LOOT_HISTORY_GO_TO_ENCOUNTER"
	end
	if LootHistoryFrame then
		return LootHistoryFrame, "LOOT_HISTORY_AUTO_SHOW"
	end
	return nil, nil
end

function LootHistoryOverride:OnInitialize()
	self._autoShowSuppressed = false
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "ApplyAutoShowSetting")
end

--- Unregister (or restore) the Blizzard frame's auto-show event to match the
--- disableBlizzLootHistoryAutoShow setting. Called on login and from config.
function LootHistoryOverride:ApplyAutoShowSetting()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	local frame, event = autoShowTarget()
	if not frame then
		return
	end

	local suppress = G_RLF.db.global.blizzOverrides.disableBlizzLootHistoryAutoShow
	if suppress and not self._autoShowSuppressed then
		frame:UnregisterEvent(event)
		self._autoShowSuppressed = true
	elseif not suppress and self._autoShowSuppressed then
		-- Only re-register what we removed; never touch a frame left at defaults.
		frame:RegisterEvent(event)
		self._autoShowSuppressed = false
	end
end

return LootHistoryOverride
