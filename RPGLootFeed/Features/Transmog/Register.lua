---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- Transmog module was created by Transmog.lua and is accessible
-- as G_RLF.Transmog (stored automatically by FeatureBase:new()).
-- Config builder and sample rows are detected as methods on the module
-- (BuildConfigArgs, GetSampleRows) by FeatureRegistry:Register().

G_RLF.FeatureRegistry:Register({
	module = G_RLF.Transmog,
	key = "transmog",
	order = 9,
	logColorARGB = "FFFF69B4",
	logAbbrev = "TMOG",
})
