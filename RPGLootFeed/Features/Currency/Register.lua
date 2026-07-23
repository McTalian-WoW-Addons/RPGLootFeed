local addonName, ns = ...
local G_RLF = ns

G_RLF.FeatureRegistry:Register({
	module = G_RLF.Currency,
	key = "currency",
	order = 3,
	logColorARGB = "FFFFD700",
	logAbbrev = "CURR",
})
