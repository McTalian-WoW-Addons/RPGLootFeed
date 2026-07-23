local addonName, ns = ...
local G_RLF = ns

G_RLF.FeatureRegistry:Register({
	module = G_RLF.LootRolls,
	key = "lootRolls",
	order = 10,
	logColorARGB = "FFFF8C00",
	logAbbrev = "ROLL",
})
