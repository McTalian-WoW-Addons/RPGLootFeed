local addonName, ns = ...
local G_RLF = ns

G_RLF.FeatureRegistry:Register({
	module = G_RLF.Money,
	key = "money",
	order = 4,
	logColorARGB = "FFC0C0C0",
	logAbbrev = "GOLD",
})
