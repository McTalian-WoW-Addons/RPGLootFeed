local addonName, ns = ...
local G_RLF = ns

G_RLF.FeatureRegistry:Register({
	module = G_RLF.TravelPoints,
	key = "travelPoints",
	order = 8,
	logColorARGB = "FF8A2BE2",
	logAbbrev = "TRVL",
})
