---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- ── Delver's Journey state ────────────────────────────────────────────────────
-- Loaded after Reputation.lua.  Overrides the no-op stub in the core module.

local CURRENT_SEASON_DELVE_JOURNEY = 0
local DELVER_JOURNEY_LABEL = nil

---@class UpdateFactionEventPayload
---@field eventName string

---@class MajorFactionRenownLevelChangedEventPayload
---@field eventName string
---@field majorFactionID number
---@field newRenownLevel number
---@field oldRenownLevel number

---@type RLF_Reputation
local Rep = G_RLF.Reputation

--- Initialize Delver's Journey state on PLAYER_ENTERING_WORLD.
function Rep:InitDelversJourney()
	if CURRENT_SEASON_DELVE_JOURNEY == 0 then
		CURRENT_SEASON_DELVE_JOURNEY = self.reputationApi.GetDelvesFactionForSeason()
	end
	if CURRENT_SEASON_DELVE_JOURNEY ~= 0 then
		self.delversJourney = self.reputationApi.GetMajorFactionRenownInfo(CURRENT_SEASON_DELVE_JOURNEY)
	end
end

--- Poll hidden renown factions (Delver's Journey) and push updates.
--- Registered as a bucket event handler in Reputation:OnEnable.
---@param events table<number | nil, number>
function Rep:CheckForHiddenRenownFactions(events)
	for k, v in pairs(events) do
		if k then
			self:LogDebug("Processing MAJOR_FACTION_RENOWN_LEVEL_CHANGED event for factionID " .. tostring(k))
		end
	end
	if
		CURRENT_SEASON_DELVE_JOURNEY == 0
		and (self.isRetail() or self.reputationApi.GetExpansionLevel() >= G_RLF.Expansion.TWW)
	then
		CURRENT_SEASON_DELVE_JOURNEY = self.reputationApi.GetDelvesFactionForSeason()
	end

	if CURRENT_SEASON_DELVE_JOURNEY == 0 then
		self:LogDebug("No current season delve journey faction")
		return
	end

	if not DELVER_JOURNEY_LABEL then
		local localeGlobalString = self.reputationApi.GetDelveReputationBarTitle()
		if not localeGlobalString or type(localeGlobalString) ~= "string" then
			self:LogDebug("No DJ locale string found")
			return
		end
		local trimIndex = localeGlobalString:find("%(")
		if not trimIndex then
			self:LogDebug("No trim index found for DJ locale string")
			return
		end
		DELVER_JOURNEY_LABEL = self.reputationApi.Strtrim(localeGlobalString:sub(1, trimIndex - 1))
		if not DELVER_JOURNEY_LABEL or DELVER_JOURNEY_LABEL == "" then
			self:LogDebug("No DJ label after trim")
			return
		end
	end

	local faction = DELVER_JOURNEY_LABEL

	---@type UnifiedFactionData
	local factionData = {
		factionId = CURRENT_SEASON_DELVE_JOURNEY,
		name = faction,
		standing = 0,
		icon = 6025441,
		quality = self.itemQualEnum.Rare,
		color = self.reputationApi.GetAccountWideFontColor(),
		contextInfo = "",
	}

	local updated = self.reputationApi.GetMajorFactionRenownInfo(CURRENT_SEASON_DELVE_JOURNEY)
	if not updated then
		self:LogDebug("No updated DJ info")
		return
	end

	---@param renownInfo MajorFactionRenownInfo
	---@return CachedFactionDetails
	local function MajorFactionRenownInfoToCachedDetails(renownInfo)
		return {
			repType = bit.bor(G_RLF.RepUtils.RepType.Warband, G_RLF.RepUtils.RepType.MajorFaction),
			rank = renownInfo.renownLevel,
			standing = renownInfo.renownReputationEarned,
			rankStandingMin = 0,
			rankStandingMax = renownInfo.renownLevelThreshold,
		}
	end

	local cacheDetails =
		G_RLF.RepUtils.GetCachedFactionDetails(CURRENT_SEASON_DELVE_JOURNEY, G_RLF.RepUtils.RepType.Warband)
	if not cacheDetails then
		self:LogDebug("No cached DJ info, updating")
		cacheDetails = MajorFactionRenownInfoToCachedDetails(updated)
		G_RLF.RepUtils.InsertNewCacheEntry(CURRENT_SEASON_DELVE_JOURNEY, cacheDetails, G_RLF.RepUtils.RepType.Warband)
		return
	end

	local newFactionDetails = MajorFactionRenownInfoToCachedDetails(updated)
	local repChange = G_RLF.RepUtils.GetDeltaAndUpdateCache(
		CURRENT_SEASON_DELVE_JOURNEY,
		newFactionDetails.standing,
		newFactionDetails,
		newFactionDetails.repType
	)

	factionData.rank = newFactionDetails.rank
	if newFactionDetails.standing then
		factionData.contextInfo = tostring(newFactionDetails.standing)
		if newFactionDetails.rankStandingMax then
			factionData.contextInfo = factionData.contextInfo .. " / " .. tostring(newFactionDetails.rankStandingMax)
		end
	end

	if repChange and repChange > 0 then
		factionData.delta = repChange
		local payload = self:BuildPayload(factionData)
		if payload then
			local e = self.lootElementBase:fromPayload(payload)
			e:Show()
		end
	end
end

return {}
