---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Central registry for feature modules.
---
--- Each feature calls Register() at the bottom of its module file to
--- self-register into FeatureModule, mainFeatureOrder, Logger metadata,
--- config table references, and sample row factories — eliminating the
--- need to edit Enums.lua, config/Features/Features.lua, Logger.lua,
--- or SampleRows.lua when adding a new feature.
---
---@class RLF_FeatureRegistry
G_RLF.FeatureLogMetadata = {}
G_RLF.mainFeatureOrder = G_RLF.mainFeatureOrder or {}

G_RLF.FeatureRegistry = {
	---@type table<string, RLF_FeatureRegistration>
	features = {},
}

---@class RLF_FeatureRegistration
---@field module RLF_Module The AceModule instance
---@field key string Config key used by DbAccessor:AnyFeatureConfig (e.g. "itemLoot")
---@field order number Position in mainFeatureOrder
---@field logColorARGB string ARGB hex for Logger type tag (combined with logAbbrev to form "|cARGB[ABBREV]|r")
---@field logAbbrev string Short abbreviation for Logger (e.g. "ITEM")
---@field config? table AceConfig options table
---@field sampleRows? fun(): table[] Sample row factory for options preview

--- Register a feature module with the addon infrastructure.
--- Must be called after the module is created but before AceAddon enable.
---@param opts RLF_FeatureRegistration
function G_RLF.FeatureRegistry:Register(opts)
	if not opts or not opts.module then
		return
	end

	local name = opts.module.moduleName
	if not name then
		return
	end

	-- ── FeatureModule enum ─────────────────────────────────────────────────
	G_RLF.FeatureModule[name] = name

	-- ── mainFeatureOrder ───────────────────────────────────────────────────
	if opts.order then
		G_RLF.mainFeatureOrder[name] = opts.order
	end

	-- ── Logger metadata ────────────────────────────────────────────────────
	if opts.logColorARGB and opts.logAbbrev then
		G_RLF.FeatureLogMetadata[name] = {
			color = "|c" .. opts.logColorARGB .. "[" .. opts.logAbbrev .. "]|r",
			abbrev = opts.logAbbrev,
		}
	end

	-- ── Config table (explicit or auto-detected from module) ──────────────
	local featureModule = opts.module
	local configFn = opts.config
	if not configFn and featureModule.BuildConfigArgs then
		configFn = function(frameId, order)
			return featureModule:BuildConfigArgs(frameId, order)
		end
	end
	if configFn then
		G_RLF._featureConfigs = G_RLF._featureConfigs or {}
		G_RLF._featureConfigs[opts.key] = configFn
	end

	-- ── Sample rows (explicit or auto-detected from module) ───────────────
	local sampleFn = opts.sampleRows
	if not sampleFn and featureModule.GetSampleRows then
		sampleFn = function(frame, features)
			return featureModule:GetSampleRows(frame, features)
		end
	end
	if sampleFn then
		G_RLF._featureSampleRows = G_RLF._featureSampleRows or {}
		G_RLF._featureSampleRows[name] = sampleFn
	end

	-- Store full metadata
	self.features[opts.key] = opts
end

return {}
