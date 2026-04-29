---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

G_RLF.ConfigHandlers = {}

local ConfigOptions = {}

---@class CachedFactionDetails
---@field repType RepType
---@field rank integer|string|nil
---@field standing integer
---@field rankStandingMin integer?
---@field rankStandingMax integer?

---@class RLF_DB
G_RLF.defaults = {
	---@class RLF_DBProfile
	profile = {},
	---@class RLF_DBLocale
	locale = {
		factionMap = {},
		accountWideFactionMap = {},
	},
	---@class RLF_DBChar
	char = {
		migrationVersion = 0,
		repFactions = {
			count = 0,
			---@type table<number, CachedFactionDetails>
			cachedFactionDetailsById = {},
		},
	},
	---@class RLF_DBGlobal
	global = {
		lastVersionLoaded = "v1.0.0",
		logger = {},
		migrationVersion = 0,
		notifications = {},
		guid = nil,
		warbandFactions = {
			count = 0,
			---@type table<number, CachedFactionDetails>
			cachedFactionDetailsById = {},
		},
		--- Per-frame configuration table. Keyed by integer frame ID.
		--- Populated at startup by migration v8; see docs/multi-frame-design.md.
		--- The "**" wildcard provides inherited defaults for ALL frame IDs
		--- (including explicitly-written ones like frame 1). This ensures
		--- that new config keys added in future versions are automatically
		--- available without a migration. New frames default to all features
		--- disabled per Q13 in the design doc.
		---@type table<integer, RLF_FrameConfig>
		frames = {
			[G_RLF.Frames.MAIN] = {
				name = G_RLF.L["Main"],
				positioning = {
					relativePoint = "UIParent",
					anchorPoint = "BOTTOMLEFT",
					xOffset = 720,
					yOffset = 375,
					frameStrata = "MEDIUM",
				},
				sizing = {
					feedWidth = 330,
					maxRows = 10,
					rowHeight = 22,
					padding = 2,
					iconSize = 18,
				},
				styling = {
					enabledSecondaryRowText = false,
					textAlignment = "LEFT",
					growUp = true,
					rowBackgroundType = 1, -- GRADIENT
					rowBackgroundTexture = "Solid",
					rowBackgroundTextureColor = { 0, 0, 0, 1 },
					rowBackgroundGradientStart = { 0.1, 0.1, 0.1, 0.8 },
					rowBackgroundGradientEnd = { 0.1, 0.1, 0.1, 0 },
					backdropInsets = { left = 0, right = 0, top = 0, bottom = 0 },
					enableRowBorder = false,
					rowBorderSize = 1,
					rowBorderColor = { 0, 0, 0, 1 },
					rowBorderClassColors = false,
					rowBorderTexture = "None",
					iconSkin = "AUTO",
					useFontObjects = false,
					font = "GameFontNormalSmall",
					fontFace = "Friz Quadrata TT",
					fontSize = 10,
					secondaryFontSize = 8,
					enableTopLeftIconText = true,
					topLeftIconFontSize = 6,
					topLeftIconTextColor = { 1, 1, 1, 1 },
					topLeftIconTextUseQualityColor = true,
					fontFlags = {
						[""] = true, -- NONE
						["OUTLINE"] = false,
						["THICKOUTLINE"] = false,
						["MONOCHROME"] = false,
						-- No SLUG entry: G_RLF:FontFlagsToString derives it from
						-- the outline flags and disableSlug.
					},
					disableSlug = false,
					fontShadowColor = { 0, 0, 0, 1 },
					fontShadowOffsetX = 1,
					fontShadowOffsetY = -1,
					rowTextSpacing = 0,
				},
				animations = {
					enter = {
						type = "fade",
						duration = 0.3,
						slide = {
							direction = "left",
						},
					},
					exit = {
						disable = false,
						type = "fade",
						duration = 1,
						fadeOutDelay = 5,
					},
					hover = {
						enabled = true,
						alpha = 0.25,
						baseDuration = 0.3,
					},
					update = {
						disableHighlight = false,
						duration = 0.2,
						loop = false,
					},
					reposition = {
						duration = 0.2,
					},
					timerBar = {
						enabled = false,
						height = 2,
						yOffset = 0,
						color = { 0.5, 0.5, 0.5 },
						alpha = 0.7,
						drainDirection = "REVERSE",
					},
				},
				features = {
					itemLoot = {
						enabled = true,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						itemCountTextEnabled = true,
						itemCountTextColor = { 0.737, 0.737, 0.737, 1 },
						itemCountTextWrapChar = 2, -- PARENTHESIS
						itemQualitySettings = {
							[0] = { enabled = true, duration = 0 },
							[1] = { enabled = true, duration = 0 },
							[2] = { enabled = true, duration = 0 },
							[3] = { enabled = true, duration = 0 },
							[4] = { enabled = true, duration = 0 },
							[5] = { enabled = true, duration = 0 },
							[6] = { enabled = true, duration = 0 },
							[7] = { enabled = true, duration = 0 },
							[8] = { enabled = true, duration = 0 },
						},
						itemHighlights = {
							boe = false,
							bop = false,
							quest = false,
							transmog = false,
							mounts = true,
							legendary = true,
							betterThanEquipped = true,
							hasTertiaryOrSocket = true,
						},
						auctionHouseSource = "None",
						pricesForSellableItems = "vendor",
						vendorIconTexture = "spellicon-256x256-selljunk",
						auctionHouseIconTexture = "auctioneer",
						sounds = {
							mounts = { enabled = false, sound = "" },
							legendary = { enabled = false, sound = "" },
							betterThanEquipped = { enabled = false, sound = "" },
							transmog = { enabled = false, sound = "" },
						},
						textStyleOverrides = {
							quest = { enabled = false, color = { 1, 1, 0, 1 } },
						},
						ignoreItemIds = {},
						enableIcon = true,
					},
					partyLoot = {
						enabled = false,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						itemQualityFilter = {
							[0] = true,
							[1] = true,
							[2] = true,
							[3] = true,
							[4] = true,
							[5] = true,
							[6] = true,
							[7] = true,
						},
						hideServerNames = false,
						onlyEpicAndAboveInRaid = true,
						onlyEpicAndAboveInInstance = true,
						ignoreItemIds = {},
						enableIcon = true,
						enablePartyAvatar = true,
					},
					currency = {
						enabled = true,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						currencyTotalTextEnabled = true,
						currencyTotalTextColor = { 0.737, 0.737, 0.737, 1 },
						currencyTotalTextWrapChar = 2, -- PARENTHESIS
						lowerThreshold = 0.7,
						upperThreshold = 0.9,
						lowestColor = { 1, 1, 1, 1 },
						midColor = { 1, 0.608, 0, 1 },
						upperColor = { 1, 0, 0, 1 },
						ignoreCurrencyIds = {},
						enableIcon = true,
					},
					money = {
						enabled = true,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						showMoneyTotal = true,
						moneyTotalColor = { 0.333, 0.333, 1.0, 1.0 },
						moneyTextWrapChar = 6, -- BAR
						abbreviateTotal = true,
						accountantMode = false,
						onlyIncome = false,
						overrideMoneyLootSound = false,
						moneyLootSound = "",
						enableIcon = true,
					},
					experience = {
						enabled = true,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						experienceTextColor = { 1, 0, 1, 0.8 },
						showCurrentLevel = true,
						currentLevelColor = { 0.749, 0.737, 0.012, 1 },
						currentLevelTextWrapChar = 5, -- ANGLE
						enableIcon = true,
					},
					reputation = {
						enabled = true,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						defaultRepColor = { 0.5, 0.5, 1 },
						secondaryTextAlpha = 0.7,
						enableRepLevel = true,
						repLevelColor = { 0.5, 0.5, 1, 1 },
						repLevelTextWrapChar = 5, -- ANGLE
						enableIcon = true,
					},
					profession = {
						enabled = true,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						showSkillChange = true,
						skillColor = { 0.333, 0.333, 1.0, 1.0 },
						skillTextWrapChar = 3, -- BRACKET
						enableIcon = true,
					},
					travelPoints = {
						enabled = true,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						textColor = { 1, 0.988, 0.498, 1 },
						enableIcon = true,
					},
					transmog = {
						enabled = true,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						enableTransmogEffect = true,
						enableBlizzardTransmogSound = true,
						enableIcon = true,
					},
				},
			},
			["**"] = {
				name = "",
				positioning = {
					relativePoint = "UIParent",
					anchorPoint = "BOTTOMLEFT",
					xOffset = 720,
					yOffset = 375,
					frameStrata = "MEDIUM",
				},
				sizing = {
					feedWidth = 330,
					maxRows = 10,
					rowHeight = 22,
					padding = 2,
					iconSize = 18,
				},
				styling = {
					enabledSecondaryRowText = false,
					textAlignment = "LEFT",
					growUp = true,
					rowBackgroundType = 1, -- GRADIENT
					rowBackgroundTexture = "Solid",
					rowBackgroundTextureColor = { 0, 0, 0, 1 },
					rowBackgroundGradientStart = { 0.1, 0.1, 0.1, 0.8 },
					rowBackgroundGradientEnd = { 0.1, 0.1, 0.1, 0 },
					backdropInsets = { left = 0, right = 0, top = 0, bottom = 0 },
					enableRowBorder = false,
					rowBorderSize = 1,
					rowBorderColor = { 0, 0, 0, 1 },
					rowBorderClassColors = false,
					rowBorderTexture = "None",
					iconSkin = "AUTO",
					useFontObjects = false,
					font = "GameFontNormalSmall",
					fontFace = "Friz Quadrata TT",
					fontSize = 10,
					secondaryFontSize = 8,
					enableTopLeftIconText = true,
					topLeftIconFontSize = 6,
					topLeftIconTextColor = { 1, 1, 1, 1 },
					topLeftIconTextUseQualityColor = true,
					fontFlags = {
						[""] = true, -- NONE
						["OUTLINE"] = false,
						["THICKOUTLINE"] = false,
						["MONOCHROME"] = false,
						-- No SLUG entry: G_RLF:FontFlagsToString derives it from
						-- the outline flags and disableSlug.
					},
					disableSlug = false,
					fontShadowColor = { 0, 0, 0, 1 },
					fontShadowOffsetX = 1,
					fontShadowOffsetY = -1,
					rowTextSpacing = 0,
				},
				animations = {
					enter = {
						type = "fade",
						duration = 0.3,
						slide = {
							direction = "left",
						},
					},
					exit = {
						disable = false,
						type = "fade",
						duration = 1,
						fadeOutDelay = 5,
					},
					hover = {
						enabled = true,
						alpha = 0.25,
						baseDuration = 0.3,
					},
					update = {
						disableHighlight = false,
						duration = 0.2,
						loop = false,
					},
					reposition = {
						duration = 0.2,
					},
					timerBar = {
						enabled = false,
						height = 2,
						yOffset = 0,
						color = { 0.5, 0.5, 0.5 },
						alpha = 0.7,
						drainDirection = "REVERSE",
					},
				},
				features = {
					itemLoot = {
						enabled = false,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						itemCountTextEnabled = true,
						itemCountTextColor = { 0.737, 0.737, 0.737, 1 },
						itemCountTextWrapChar = 2, -- PARENTHESIS
						itemQualitySettings = {
							[0] = { enabled = true, duration = 0 },
							[1] = { enabled = true, duration = 0 },
							[2] = { enabled = true, duration = 0 },
							[3] = { enabled = true, duration = 0 },
							[4] = { enabled = true, duration = 0 },
							[5] = { enabled = true, duration = 0 },
							[6] = { enabled = true, duration = 0 },
							[7] = { enabled = true, duration = 0 },
							[8] = { enabled = true, duration = 0 },
						},
						itemHighlights = {
							boe = false,
							bop = false,
							quest = false,
							transmog = false,
							mounts = true,
							legendary = true,
							betterThanEquipped = true,
							hasTertiaryOrSocket = true,
						},
						auctionHouseSource = "None",
						pricesForSellableItems = "vendor",
						vendorIconTexture = "spellicon-256x256-selljunk",
						auctionHouseIconTexture = "auctioneer",
						sounds = {
							mounts = { enabled = false, sound = "" },
							legendary = { enabled = false, sound = "" },
							betterThanEquipped = { enabled = false, sound = "" },
							transmog = { enabled = false, sound = "" },
						},
						textStyleOverrides = {
							quest = { enabled = false, color = { 1, 1, 0, 1 } },
						},
						ignoreItemIds = {},
						enableIcon = true,
					},
					partyLoot = {
						enabled = false,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						itemQualityFilter = {
							[0] = true,
							[1] = true,
							[2] = true,
							[3] = true,
							[4] = true,
							[5] = true,
							[6] = true,
							[7] = true,
						},
						hideServerNames = false,
						onlyEpicAndAboveInRaid = true,
						onlyEpicAndAboveInInstance = true,
						ignoreItemIds = {},
						enableIcon = true,
						enablePartyAvatar = true,
					},
					currency = {
						enabled = false,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						currencyTotalTextEnabled = true,
						currencyTotalTextColor = { 0.737, 0.737, 0.737, 1 },
						currencyTotalTextWrapChar = 2, -- PARENTHESIS
						lowerThreshold = 0.7,
						upperThreshold = 0.9,
						lowestColor = { 1, 1, 1, 1 },
						midColor = { 1, 0.608, 0, 1 },
						upperColor = { 1, 0, 0, 1 },
						ignoreCurrencyIds = {},
						enableIcon = true,
					},
					money = {
						enabled = false,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						showMoneyTotal = true,
						moneyTotalColor = { 0.333, 0.333, 1.0, 1.0 },
						moneyTextWrapChar = 6, -- BAR
						abbreviateTotal = true,
						accountantMode = false,
						onlyIncome = false,
						overrideMoneyLootSound = false,
						moneyLootSound = "",
						enableIcon = true,
					},
					experience = {
						enabled = false,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						experienceTextColor = { 1, 0, 1, 0.8 },
						showCurrentLevel = true,
						currentLevelColor = { 0.749, 0.737, 0.012, 1 },
						currentLevelTextWrapChar = 5, -- ANGLE
						enableIcon = true,
					},
					reputation = {
						enabled = false,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						defaultRepColor = { 0.5, 0.5, 1 },
						secondaryTextAlpha = 0.7,
						enableRepLevel = true,
						repLevelColor = { 0.5, 0.5, 1, 1 },
						repLevelTextWrapChar = 5, -- ANGLE
						enableIcon = true,
					},
					profession = {
						enabled = false,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						showSkillChange = true,
						skillColor = { 0.333, 0.333, 1.0, 1.0 },
						skillTextWrapChar = 3, -- BRACKET
						enableIcon = true,
					},
					travelPoints = {
						enabled = false,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						textColor = { 1, 0.988, 0.498, 1 },
						enableIcon = true,
					},
					transmog = {
						enabled = false,
						backgroundOverride = {
							enabled = false,
							gradientStart = { 0.1, 0.1, 0.1, 0.8 },
							gradientEnd = { 0.1, 0.1, 0.1, 0 },
							textureColor = { 0, 0, 0, 1 },
						},
						enableTransmogEffect = true,
						enableBlizzardTransmogSound = true,
						enableIcon = true,
					},
				},
			},
		},
		--- Monotonically increasing counter for the next frame ID.
		--- Never decremented or reused after a frame is deleted.
		nextFrameId = 2,
	},
}

G_RLF.options = {
	name = addonName,
	handler = ConfigOptions,
	type = "group",
	childGroups = "tree",
	args = {},
}
