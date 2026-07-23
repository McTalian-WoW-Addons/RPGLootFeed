local addonName, ns = ...
local G_RLF = ns

G_RLF.FeatureRegistry:Register({
	module = G_RLF.PartyLoot,
	key = "partyLoot",
	order = 2,
	logColorARGB = "FF00FFFF",
	logAbbrev = "PRTY",
})
