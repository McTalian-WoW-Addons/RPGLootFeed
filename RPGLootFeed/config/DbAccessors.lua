---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local DbAccessor = {}

--- Get the frame's sizing config from the db
--- @param frame G_RLF.Frames
--- @return RLF_ConfigSizing
function DbAccessor:Sizing(frame)
	return G_RLF.db.global.frames[frame].sizing
end

--- Get the frame's positioning config from the db
--- @param frame G_RLF.Frames
--- @return RLF_ConfigPositioning
function DbAccessor:Positioning(frame)
	return G_RLF.db.global.frames[frame].positioning
end

--- Get the frame's styling config from the db
--- @param frame G_RLF.Frames
--- @return RLF_ConfigStyling
function DbAccessor:Styling(frame)
	return G_RLF.db.global.frames[frame].styling
end

--- Get the frame's animations config from the per-frame db schema.
--- @param frameId G_RLF.Frames
--- @return RLF_ConfigAnimations
function DbAccessor:Animations(frameId)
	return G_RLF.db.global.frames[frameId].animations
end

--- Get a feature's per-frame configuration.
--- Returns the feature config table (e.g. { enabled = true, enableIcon = true, … })
--- for the given frame and feature key, or nil if not found.
--- @param frameId integer
--- @param featureKey string  One of: itemLoot, partyLoot, currency, money, experience, reputation, profession, travelPoints, transmog
--- @return RLF_FeatureConfig?
function DbAccessor:Feature(frameId, featureKey)
	local frames = G_RLF.db.global.frames
	if frames and frames[frameId] and frames[frameId].features then
		return frames[frameId].features[featureKey]
	end
	return nil
end

--- Get a feature's configuration from any frame that has the feature enabled.
--- Returns the first match's config table, falling back to frame 1.
--- This is a transitional helper for code that builds frame-agnostic payloads
--- (feature modules) and cannot receive a frame ID.
--- @param featureKey string  One of: itemLoot, partyLoot, currency, money, experience, reputation, profession, travelPoints, transmog
--- @return RLF_FeatureConfig?
function DbAccessor:AnyFeatureConfig(featureKey)
	local frames = G_RLF.db.global.frames
	if not frames then
		return nil
	end
	local sortedKeys = {}
	for k in pairs(frames) do
		if type(k) == "number" then
			sortedKeys[#sortedKeys + 1] = k
		end
	end
	table.sort(sortedKeys)
	for _, id in ipairs(sortedKeys) do
		local frameConfig = frames[id]
		if frameConfig.features and frameConfig.features[featureKey] and frameConfig.features[featureKey].enabled then
			return frameConfig.features[featureKey]
		end
	end
	-- Fallback to frame 1 even if disabled
	if frames[1] and frames[1].features then
		return frames[1].features[featureKey]
	end
	return nil
end

--- Maps feature DB keys to their FeatureModule enum values.
local featureKeyToModule = {
	itemLoot = "ItemLoot",
	partyLoot = "PartyLoot",
	currency = "Currency",
	money = "Money",
	experience = "Experience",
	reputation = "Reputation",
	profession = "Professions",
	travelPoints = "TravelPoints",
	transmog = "Transmog",
	lootRolls = "LootRolls",
}

--- Check whether at least one frame has the given feature enabled.
--- @param featureKey string  One of: itemLoot, partyLoot, currency, money, experience, reputation, profession, travelPoints, transmog, lootRolls
--- @return boolean
function DbAccessor:IsFeatureNeededByAnyFrame(featureKey)
	local frames = G_RLF.db.global.frames
	if not frames then
		return false
	end
	for _, frameConfig in pairs(frames) do
		if frameConfig.features and frameConfig.features[featureKey] and frameConfig.features[featureKey].enabled then
			return true
		end
	end
	return false
end

--- Enable or disable a feature module based on whether any frame needs it.
--- Call this from config enable toggles after changing a per-frame feature flag.
--- @param featureKey string  One of: itemLoot, partyLoot, currency, money, experience, reputation, profession, travelPoints, transmog, lootRolls
function DbAccessor:UpdateFeatureModuleState(featureKey)
	local moduleName = featureKeyToModule[featureKey]
	if not moduleName then
		return
	end
	if self:IsFeatureNeededByAnyFrame(featureKey) then
		G_RLF.RLF:EnableModule(moduleName)
	else
		G_RLF.RLF:DisableModule(moduleName)
	end
end

G_RLF.DbAccessor = DbAccessor

return DbAccessor
