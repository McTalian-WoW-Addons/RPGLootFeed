local addonName, ns = ...
local G_RLF = ns

G_RLF.FeatureRegistry:Register({
	module = G_RLF.ItemLoot,
	key = "itemLoot",
	order = 1,
	logColorARGB = "FF00FF00",
	logAbbrev = "ITEM",
})
