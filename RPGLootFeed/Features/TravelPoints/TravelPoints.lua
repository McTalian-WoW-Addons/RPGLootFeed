---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- ── Feature module ────────────────────────────────────────────────────────────

---@class RLF_TravelPoints: RLF_Module, AceEvent-3.0
local TravelPoints = G_RLF.FeatureBase:new("TravelPoints", {
	di = {
		lootElementBase = "LootElementBase",
		defaultIcons = "DefaultIcons",
		itemQualEnum = "ItemQualEnum",
		travelPointsApi = "WoWAPI.TravelPoints",
		isRetail = "IsRetail",
	},
	logging = true,
}, "AceEvent-3.0")
local currentTravelersJourney, maxTravelersJourney

--- Build a uniform payload for a travel points discovery event.
---@param quantity number The point amount earned
---@return RLF_ElementPayload
function TravelPoints:BuildPayload(quantity)
	local tpConfig = G_RLF.DbAccessor:AnyFeatureConfig("travelPoints") or {}
	local r, g, b, a = unpack(tpConfig.textColor or { 1, 0.988, 0.498, 1 })

	local icon = self.defaultIcons.TRAVELPOINTS
	if not tpConfig.enableIcon or G_RLF.db.global.misc.hideAllIcons then
		icon = nil
	end

	---@type RLF_ElementPayload
	local payload = {
		type = G_RLF.FeatureModule.TravelPoints,
		key = "TRAVELPOINTS",
		quantity = quantity,
		r = r,
		g = g,
		b = b,
		a = a,
		icon = icon,
		quality = self.itemQualEnum.Common,
		textFn = function(existingAmount)
			return self.travelPointsApi.GetMonthlyActivitiesPointsLabel() .. " + " .. ((existingAmount or 0) + quantity)
		end,
		secondaryTextFn = function()
			if not currentTravelersJourney then
				return ""
			end
			if not maxTravelersJourney then
				return ""
			end
			local color = G_RLF:RGBAToHexFormat(r, g, b, a)
			return "    " .. color .. currentTravelersJourney .. "/" .. maxTravelersJourney .. "|r"
		end,
		moduleRef = TravelPoints,
	}

	return payload
end

--- Calculate the current and max values for the Travelers Journey
--- @param activityID? number
local function calcTravelersJourneyVal(activityID)
	local allInfo = TravelPoints.travelPointsApi.GetPerksActivitiesInfo()
	if allInfo == nil then
		G_RLF:LogWarn("Could not get all activity info", addonName, TravelPoints.moduleName)
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
	G_RLF:LogDebug(
		"Current Travelers Journey " .. tostring(currentTravelersJourney) .. " / " .. tostring(maxTravelersJourney),
		addonName,
		TravelPoints.moduleName
	)
end

function TravelPoints:OnInitialize()
	if self.isRetail() and G_RLF.DbAccessor:IsFeatureNeededByAnyFrame("travelPoints") then
		self:Enable()
	else
		self:Disable()
	end
end

function TravelPoints:OnDisable()
	if not self.isRetail() then
		return
	end
	self:UnregisterEvent("PERKS_ACTIVITY_COMPLETED")
end

function TravelPoints:OnEnable()
	if not self.isRetail() then
		return
	end

	self:LogDebug("OnEnable")
	self:RegisterEvent("PERKS_ACTIVITY_COMPLETED")
end

function TravelPoints:PERKS_ACTIVITY_COMPLETED(eventName, activityID)
	self:LogInfo(eventName, "WOWEVENT", nil, activityID)

	local info = self.travelPointsApi.GetPerksActivityInfo(activityID)
	if info == nil then
		self:LogWarn("Could not get activity info")
		return
	end
	local amount = info.thresholdContributionAmount
	calcTravelersJourneyVal(activityID)

	if amount > 0 then
		self.lootElementBase:fromPayload(self:BuildPayload(amount)):Show()
	else
		self:LogWarn(eventName .. " fired but amount was not positive")
	end
end

return TravelPoints
