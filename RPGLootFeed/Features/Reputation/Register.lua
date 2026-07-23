local addonName, ns = ...
local G_RLF = ns

G_RLF.FeatureRegistry:Register({
	module = G_RLF.Reputation,
	key = "reputation",
	order = 6,
	logColorARGB = "FF1E90FF",
	logAbbrev = "REPU",
})
