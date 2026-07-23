local addonName, ns = ...
local G_RLF = ns

G_RLF.FeatureRegistry:Register({
	module = G_RLF.Professions,
	key = "profession",
	order = 7,
	logColorARGB = "FF8B4513",
	logAbbrev = "PROF",
})
