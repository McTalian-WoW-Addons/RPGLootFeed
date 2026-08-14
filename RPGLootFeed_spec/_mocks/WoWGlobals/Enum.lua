local enums = {}

_G.Enum = {
	ItemArmorSubclass = {
		Cloth = 1,
		Leather = 2,
		Mail = 3,
		Plate = 4,
	},
	ItemClass = { Armor = 4, Questitem = 12, Miscellaneous = 15 },
	ItemMiscellaneousSubclass = { Mount = 5 },
	ItemQuality = {
		Poor = 0,
		Common = 1,
		Uncommon = 2,
		Rare = 3,
		Epic = 4,
		Legendary = 5,
		Artifact = 6,
		Heirloom = 7,
		WoWToken = 8,
	},
	-- Values match SimpleStatusBarConstantsDocumentation.lua; identical on live,
	-- classic, classic_era and classic_anniversary.
	StatusBarFillStyle = {
		Standard = 0,
		StandardNoRangeFill = 1,
		Center = 2,
		Reverse = 3,
	},
	StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
	StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
}

return enums
