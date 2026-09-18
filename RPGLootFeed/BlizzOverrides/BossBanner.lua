---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class BossBannerOverride: RLF_Module, AceEvent-3.0, AceHook-3.0, AceTimer-3.0
local BossBannerOverride =
	G_RLF.RLF:NewModule(G_RLF.BlizzModule.BossBanner, "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")

function BossBannerOverride:OnInitialize()
	-- WoW Forever reports expansion 0 but loads the Mainline BossBannerToast.
	if GetExpansionLevel() >= G_RLF.Expansion.WOD or G_RLF:IsForever() then
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "BossBannerHook")
	end
end

local bossBannerAttempts = 0
function BossBannerOverride:BossBannerHook()
	if self:IsHooked(BossBanner, "OnEvent") then
		return
	end
	if BossBanner then
		self:RawHookScript(BossBanner, "OnEvent", "InterceptBossBannerAlert")
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	else
		-- "Use" the locale key so it doesn't get flagged as unused. We use it dynamically in the retryHook
		local _ = G_RLF.L["BossBannerAlertUnavailable"]
		bossBannerAttempts = G_RLF.retryHook(self, bossBannerAttempts, "BossBannerHook", "BossBannerAlertUnavailable")
	end
end

function BossBannerOverride:InterceptBossBannerAlert(s, event, ...)
	local config = G_RLF.db.global.blizzOverrides.bossBannerConfig
	if config == G_RLF.DisableBossBanner.FULLY_DISABLE then
		return
	end

	if config == G_RLF.DisableBossBanner.DISABLE_LOOT and event == "ENCOUNTER_LOOT_RECEIVED" then
		return
	end

	local _, _, _, _, playerName, _ = ...
	local myGuid = GetPlayerGuid()
	local myName, _ = GetNameAndServerNameFromGUID(myGuid)
	if
		config == G_RLF.DisableBossBanner.DISABLE_MY_LOOT
		and event == "ENCOUNTER_LOOT_RECEIVED"
		and playerName == myName
	then
		return
	end

	if
		config == G_RLF.DisableBossBanner.DISABLE_GROUP_LOOT
		and event == "ENCOUNTER_LOOT_RECEIVED"
		and playerName ~= myName
	then
		return
	end
	-- Call the original AddAlert function if not blocked
	self.hooks[BossBanner].OnEvent(s, event, ...)
end

return BossBannerOverride
