---@diagnostic disable: inject-field
---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- CheckForHiddenRenownFactions and its state moved to ReputationDelversJourney.lua

---@class RLF_Reputation: RLF_Module, AceEvent-3.0, AceTimer-3.0, AceBucket-3.0
local Rep = G_RLF.FeatureBase:new("Reputation", {
	di = {
		lootElementBase = "LootElementBase",
		itemQualEnum = "ItemQualEnum",
		reputationApi = "WoWAPI.Reputation",
		textTemplateEngine = "TextTemplateEngine",
		isRetail = "IsRetail",
	},
	logging = true,
}, "AceEvent-3.0", "AceTimer-3.0", "AceBucket-3.0")

-- ── Faction data helpers ──────────────────────────────────────────────────────

local function buildCachedFactionDetails()
	if not Rep.reputationApi.HasRetailReputationAPIAvailable() then
		return
	end

	local numCachedFactions = G_RLF.RepUtils.GetCount()
	local numFactions = Rep.reputationApi.GetNumFactions()
	local hasMoreFactions = numFactions > numCachedFactions
	if not hasMoreFactions then
		return
	end

	for i = 1, numFactions do
		local factionData = Rep.reputationApi.GetFactionDataByIndex(i)
		if factionData and factionData.name then
			local repType = G_RLF.RepUtils.DetermineRepType(factionData.factionID)
			local detailedFactionData = G_RLF.RepUtils.GetFactionData(factionData.factionID, repType)
			if detailedFactionData then
				---@type CachedFactionDetails
				local cachedDetails = {
					repType = repType,
					rank = detailedFactionData.rank,
					standing = detailedFactionData.standing,
					rankStandingMin = detailedFactionData.rankStandingMin,
					rankStandingMax = detailedFactionData.rankStandingMax,
				}
				G_RLF.RepUtils.UpdateCacheEntry(factionData.factionID, cachedDetails, repType)
			end
		end
	end
end

-- ── Context provider ──────────────────────────────────────────────────────────

local function createReputationContextProvider()
	return function(context, data)
		context.name = data.factionName or ""
		context.contextInfo = data.contextInfo or ""
		-- If no context info or no factionId, the row spacing should collapse
		if not data.factionId or not data.contextInfo then
			context.contextInfo = ""
		end
	end
end

-- ── Text elements ─────────────────────────────────────────────────────────────

--- Generate text elements for Reputation type.
---@param primaryColor table {r, g, b, a} for primary row
---@param secondaryColor table {r, g, b, a} for secondary row
function Rep:GenerateTextElements(primaryColor, secondaryColor)
	local elements = {}

	elements[1] = {}
	elements[1].primary = {
		type = "primary",
		template = "{sign}{absAmount} {name}",
		order = 1,
		color = primaryColor,
	}

	elements[2] = {}
	elements[2].contextSpacer = {
		type = "spacer",
		spacerCount = 4,
		order = 1,
	}
	elements[2].context = {
		type = "context",
		template = "{contextInfo}",
		order = 2,
		color = secondaryColor,
	}

	return elements
end

-- ── BuildPayload ──────────────────────────────────────────────────────────────

---@param unifiedFactionData UnifiedFactionData
---@return RLF_ElementPayload|nil
function Rep:BuildPayload(unifiedFactionData)
	if not unifiedFactionData or not unifiedFactionData.delta then
		return nil
	end

	local r, g, b, a
	if unifiedFactionData.color and unifiedFactionData.color.GetRGBA then
		r, g, b, a = unifiedFactionData.color:GetRGBA()
	else
		local repConfig = G_RLF.DbAccessor:AnyFeatureConfig("reputation") or {}
		r, g, b = unpack(repConfig.defaultRepColor or { 0.5, 0.5, 1 })
		a = 1
	end

	local repCfg = G_RLF.DbAccessor:AnyFeatureConfig("reputation") or {}
	local secondaryAlpha = repCfg.secondaryTextAlpha or 0.7
	local primaryColor = { r, g, b, a }
	local secondaryColor = { r, g, b, secondaryAlpha }

	local factionId = unifiedFactionData.factionId
	local delta = unifiedFactionData.delta
	local name = unifiedFactionData.name

	local textElements = self:GenerateTextElements(primaryColor, secondaryColor)

	---@type RLF_LootElementData
	local elementData = {
		key = "REP_" .. factionId,
		type = "Reputation",
		textElements = textElements,
		quantity = delta,
		icon = unifiedFactionData.icon,
		quality = unifiedFactionData.quality,
		-- Extra fields for context provider
		factionName = name,
		contextInfo = unifiedFactionData.contextInfo,
		factionId = factionId,
	}

	---@type RLF_ElementPayload
	local payload = {
		key = "REP_" .. factionId,
		type = G_RLF.FeatureModule.Reputation,
		icon = (G_RLF.DbAccessor:AnyFeatureConfig("reputation") or {}).enableIcon
				and not G_RLF.db.global.misc.hideAllIcons
				and unifiedFactionData.icon
			or nil,
		quality = unifiedFactionData.quality,
		quantity = delta,

		textFn = function(existingRep)
			return self.textTemplateEngine:ProcessRowElements(1, elementData, existingRep)
		end,

		itemCountFn = function()
			local repCfg = G_RLF.DbAccessor:AnyFeatureConfig("reputation") or {}
			if not repCfg.enableRepLevel then
				return nil
			end
			return unifiedFactionData.rank,
				{
					color = G_RLF:RGBAToHexFormat(unpack(repCfg.repLevelColor or { 0.5, 0.5, 1, 1 })),
					wrapChar = repCfg.repLevelTextWrapChar,
				}
		end,

		secondaryTextFn = function()
			return self.textTemplateEngine:ProcessRowElements(2, elementData)
		end,

		-- Paragon reward bag icon as real Texture via SecondaryCoinDisplay
		secondaryCoinDataFn = unifiedFactionData.paragonIconAtlas and function()
			return 0, 0, 0, unifiedFactionData.paragonIconAtlas, unifiedFactionData.paragonIconSize
		end or nil,

		r = r,
		g = g,
		b = b,
		a = a,
		moduleRef = Rep,
	}

	return payload
end

-- ── Module lifecycle ──────────────────────────────────────────────────────────

function Rep:OnInitialize()
	if not self.isRetail() then
		G_RLF.LegacyRepParsing.InitializeLegacyReputationChatParsing()
	end

	if G_RLF.DbAccessor:IsFeatureNeededByAnyFrame("reputation") then
		self:Enable()
	else
		self:Disable()
	end
end

function Rep:OnDisable()
	self.textTemplateEngine.contextProviders["Reputation"] = nil
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	if self.reputationApi.GetExpansionLevel() >= G_RLF.Expansion.TWW then
		self:UnregisterAllBuckets()
	end
	if self.reputationApi.IsEventValid("FACTION_STANDING_CHANGED") then
		self:UnregisterAllBuckets()
	else
		self:UnregisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
	end
end

function Rep:OnEnable()
	self.textTemplateEngine:RegisterContextProvider("Reputation", createReputationContextProvider())
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	if self.reputationApi.IsEventValid("FACTION_STANDING_CHANGED") then
		self:RegisterBucketEvent("FACTION_STANDING_CHANGED", 0.2)
	else
		self:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
	end
	if self.reputationApi.GetExpansionLevel() >= G_RLF.Expansion.TWW then
		--- @type FrameEvent[]
		local delversJourneyPollEvents = {
			"UPDATE_FACTION",
			"MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
		}
		---@diagnostic disable-next-line: param-type-mismatch
		self:RegisterBucketEvent(delversJourneyPollEvents, 0.5, "CheckForHiddenRenownFactions")
	end
	self:LogDebug("OnEnable")
end

-- ── Event handlers ────────────────────────────────────────────────────────────

function Rep:ParseFactionChangeMessage(message)
	return G_RLF.LegacyRepParsing.ParseFactionChangeMessage(message, self.companionFactionName)
end

function Rep:PLAYER_ENTERING_WORLD(eventName, isLogin, isReload)
	if self.reputationApi.GetExpansionLevel() >= G_RLF.Expansion.TWW then
		if not self.companionFactionId or not self.companionFactionName then
			self.companionFactionId = self.reputationApi.GetFactionForCompanion()
			local factionData = self.reputationApi.GetFactionDataByID(self.companionFactionId)
			if factionData then
				self.companionFactionName = factionData.name
			end
		end
		self:InitDelversJourney()
		self.reputationApi.RunNextFrame(function()
			buildCachedFactionDetails()
		end)
	end
end

function Rep:FACTION_STANDING_CHANGED(factionEvents)
	for factionId, cnt in pairs(factionEvents) do
		self:LogInfo(cnt .. "x FACTION_STANDING_CHANGED for factionID " .. tostring(factionId))
		self:UpdateReputationForFaction(factionId)
	end
end

function Rep:UpdateReputationForFaction(factionID)
	local repType = G_RLF.RepUtils.DetermineRepType(factionID)
	local factionData = G_RLF.RepUtils.GetFactionData(factionID, repType)
	if not factionData then
		self:LogWarn(
			"Could not retrieve faction data for ID " .. tostring(factionID) .. " repType:" .. tostring(repType)
		)
		return
	end

	local repChange = G_RLF.RepUtils.GetDeltaAndUpdateCache(factionID, factionData.standing, factionData, repType)
	factionData.delta = repChange

	if repChange and repChange ~= 0 then
		local payload = self:BuildPayload(factionData)
		if payload then
			local e = self.lootElementBase:fromPayload(payload)
			e:Show()
		end
	end
end

function Rep:CHAT_MSG_COMBAT_FACTION_CHANGE(eventName, message)
	if self.reputationApi.IssecretValue(message) then
		self:LogWarn("(" .. eventName .. ") Secret value detected, ignoring chat message", "WOWEVENT")
		return
	end

	self:LogInfo(eventName .. " " .. message, "WOWEVENT")

	local faction, repChange, isDelveCompanion, isAccountWide = self:ParseFactionChangeMessage(message)

	if not faction or not repChange then
		self:LogError("Could not determine faction and/or rep change from message", nil, nil, faction, nil, repChange)
		return
	end

	local factionMapEntry = G_RLF.LegacyRepParsing.GetLocaleFactionMapData(faction, isAccountWide)
	local repType, fId, factionData
	if factionMapEntry then
		fId = factionMapEntry
		repType = G_RLF.RepUtils.DetermineRepType(fId)
		factionData = G_RLF.RepUtils.GetFactionData(fId, repType)
		if not factionData then
			self:LogWarn("Could not retrieve faction data for ID " .. tostring(fId) .. " repType:" .. tostring(repType))
			return
		end
		if factionData.name ~= faction then
			factionData.name = faction
		end
		factionData.delta = repChange
	end

	if factionData == nil then
		self:LogWarn(faction .. " faction data could not be retrieved by ID")
		return
	end

	local payload = self:BuildPayload(factionData)
	if payload then
		local e = self.lootElementBase:fromPayload(payload)
		e:Show()
	end
end

-- CheckForHiddenRenownFactions defined in ReputationDelversJourney.lua
-- InitDelversJourney defined in ReputationDelversJourney.lua

G_RLF.Reputation = Rep

return Rep
