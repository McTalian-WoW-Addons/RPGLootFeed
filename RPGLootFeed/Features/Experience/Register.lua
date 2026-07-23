local addonName, ns = ...
local G_RLF = ns

G_RLF.FeatureRegistry:Register({
	module = G_RLF.Experience,
	key = "experience",
	order = 5,
	logColorARGB = "FF9932CC",
	logAbbrev = "EXPR",
})
