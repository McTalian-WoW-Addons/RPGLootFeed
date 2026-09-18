---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- ── External dependency locals ────────────────────────────────────────────────
-- Every reference to the addon namespace is captured here so the module's full
-- dependency surface on G_RLF / ns is visible in one place.  Tests pass a
-- minimal mock ns to loadfile("TravelPoints.lua") to control these at
-- injection time without the full nsMocks framework.
-- NOTE: G_RLF.db is intentionally absent – AceDB populates it in
-- OnInitialize, so it must remain a runtime lookup inside function bodies.
local LootElementBase = G_RLF.LootElementBase
local DefaultIcons = G_RLF.DefaultIcons
local ItemQualEnum = G_RLF.ItemQualEnum
local FeatureBase = G_RLF.FeatureBase
local FeatureModule = G_RLF.FeatureModule
local LogDebug = function(...)
	G_RLF:LogDebug(...)
end
local LogInfo = function(...)
	G_RLF:LogInfo(...)
end
local LogWarn = function(...)
	G_RLF:LogWarn(...)
end
-- Traveler's Log / Trading Post (Blizzard_PerksProgram, Blizzard_EncounterJournal)
-- do not load on WoW Forever, which otherwise reports as Retail.
local HasTravelersLog = function()
	return G_RLF:IsRetail() and not G_RLF:IsForever()
end
local RGBAToHexFormat = function(...)
	return G_RLF:RGBAToHexFormat(...)
end

-- ── WoW API / Global abstraction adapters ────────────────────────────────────
-- Shared adapter from G_RLF.WoWAPI; tests override TravelPoints._travelPointsAdapter after load.
local TravelPointsAdapter = G_RLF.WoWAPI.TravelPoints

---@class RLF_TravelPoints: RLF_Module, AceEvent-3.0
local TravelPoints = FeatureBase:new(FeatureModule.TravelPoints, "AceEvent-3.0")
local currentTravelersJourney, maxTravelersJourney

TravelPoints._travelPointsAdapter = TravelPointsAdapter

--- Build a uniform payload for a travel points discovery event.
---@param quantity number The point amount earned
---@return RLF_ElementPayload
function TravelPoints:BuildPayload(quantity)
	local tpConfig = G_RLF.DbAccessor:AnyFeatureConfig("travelPoints") or {}
	local r, g, b, a = unpack(tpConfig.textColor or { 1, 0.988, 0.498, 1 })

	local icon = DefaultIcons.TRAVELPOINTS
	if not tpConfig.enableIcon or G_RLF.db.global.misc.hideAllIcons then
		icon = nil
	end

	---@type RLF_ElementPayload
	local payload = {
		type = FeatureModule.TravelPoints,
		key = "TRAVELPOINTS",
		quantity = quantity,
		r = r,
		g = g,
		b = b,
		a = a,
		icon = icon,
		quality = ItemQualEnum.Common,
		textFn = function(existingAmount)
			return TravelPoints._travelPointsAdapter.GetMonthlyActivitiesPointsLabel()
				.. " + "
				.. ((existingAmount or 0) + quantity)
		end,
		secondaryTextFn = function()
			if not currentTravelersJourney then
				return ""
			end
			if not maxTravelersJourney then
				return ""
			end
			local color = RGBAToHexFormat(r, g, b, a)
			return "    " .. color .. currentTravelersJourney .. "/" .. maxTravelersJourney .. "|r"
		end,
		IsEnabled = function()
			return TravelPoints:IsEnabled()
		end,
	}

	return payload
end

--- Calculate the current and max values for the Travelers Journey
--- @param activityID? number
local function calcTravelersJourneyVal(activityID)
	local allInfo = TravelPoints._travelPointsAdapter.GetPerksActivitiesInfo()
	if allInfo == nil then
		LogWarn("Could not get all activity info", addonName, TravelPoints.moduleName)
		return
	end

	local progress = 0
	for i, v in ipairs(allInfo.activities) do
		if v.completed then
			progress = progress + v.thresholdContributionAmount
		elseif v.ID == activityID then
			progress = progress + v.thresholdContributionAmount
		end
	end

	local max = 0
	for i, v in ipairs(allInfo.thresholds) do
		max = math.max(max, v.requiredContributionAmount)
	end

	currentTravelersJourney = progress
	maxTravelersJourney = max
	LogDebug(
		"Current Travelers Journey " .. tostring(currentTravelersJourney) .. " / " .. tostring(maxTravelersJourney),
		addonName,
		TravelPoints.moduleName
	)
end

function TravelPoints:OnInitialize()
	if HasTravelersLog() and G_RLF.DbAccessor:IsFeatureNeededByAnyFrame("travelPoints") then
		self:Enable()
	else
		self:Disable()
	end
end

function TravelPoints:OnDisable()
	if not HasTravelersLog() then
		return
	end
	self:UnregisterEvent("PERKS_ACTIVITY_COMPLETED")
end

function TravelPoints:OnEnable()
	if not HasTravelersLog() then
		return
	end

	LogDebug("OnEnable", addonName, self.moduleName)
	self:RegisterEvent("PERKS_ACTIVITY_COMPLETED")
end

function TravelPoints:PERKS_ACTIVITY_COMPLETED(eventName, activityID)
	LogInfo(eventName, "WOWEVENT", self.moduleName, activityID)

	local info = TravelPoints._travelPointsAdapter.GetPerksActivityInfo(activityID)
	if info == nil then
		LogWarn("Could not get activity info", addonName, self.moduleName)
		return
	end
	local amount = info.thresholdContributionAmount
	calcTravelersJourneyVal(activityID)

	if amount > 0 then
		LootElementBase:fromPayload(self:BuildPayload(amount)):Show()
	else
		LogWarn(eventName .. " fired but amount was not positive", addonName, self.moduleName)
	end
end

return TravelPoints
