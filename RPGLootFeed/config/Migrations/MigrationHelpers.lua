---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--------------------------------------------------
-- Private helpers shared across migration scripts.
-- All implementation details remain local to this chunk.
-- Only the six functions that v8.lua's migration:run() calls directly are
-- exposed via G_RLF._migHelpers at the bottom of this file.
-- BuildV8RecoverySnapshot (added in Step 2) is placed on G_RLF directly
-- because v9.lua calls it by name.
--------------------------------------------------

--- Safe copy of a color array { r, g, b, a }.  Reads each index explicitly
--- so that AceDB proxy tables (which serve defaults via __index) are handled
--- correctly — unpack() uses rawget and would miss metatable-provided values.
local function copyColor(t)
	if t == nil then
		return nil
	end
	return { t[1], t[2], t[3], t[4] }
end

--- Safe copy of sub-table fields (e.g. backdropInsets, fontFlags).
--- Returns a plain table copy if source is a table, nil otherwise.
local function copyFields(t)
	if type(t) ~= "table" then
		return nil
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

--- Pick the primary value if it's explicitly set (including false), otherwise fallback.
local function pick(primary, fallback)
	if primary ~= nil then
		return primary
	end
	return fallback
end

--------------------------------------------------
-- Legacy AceDB defaults (hardcoded raw values)
--
-- Migration v8 must be self-contained: when a user jumps across several
-- versions (e.g. v6 → v10), the old AceDB defaults may no longer be
-- registered.  Without those defaults, __index returns nil and the copy
-- helpers would silently write nil for every field.  This table provides the
-- historical defaults as a final fallback tier.
--------------------------------------------------
local LEGACY_DEFAULTS = {
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
		},
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
	},
	item = {
		enabled = true,
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
		enableIcon = true,
	},
	partyLoot = {
		enabled = false,
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
		currencyTotalTextEnabled = true,
		currencyTotalTextColor = { 0.737, 0.737, 0.737, 1 },
		currencyTotalTextWrapChar = 2, -- PARENTHESIS
		lowerThreshold = 0.7,
		upperThreshold = 0.9,
		lowestColor = { 1, 1, 1, 1 },
		midColor = { 1, 0.608, 0, 1 },
		upperColor = { 1, 0, 0, 1 },
		enableIcon = true,
	},
	money = {
		enabled = true,
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
	xp = {
		enabled = true,
		experienceTextColor = { 1, 0, 1, 0.8 },
		showCurrentLevel = true,
		currentLevelColor = { 0.749, 0.737, 0.012, 1 },
		currentLevelTextWrapChar = 5, -- ANGLE
		enableIcon = true,
	},
	rep = {
		enabled = true,
		defaultRepColor = { 0.5, 0.5, 1 },
		secondaryTextAlpha = 0.7,
		enableRepLevel = true,
		repLevelColor = { 0.5, 0.5, 1, 1 },
		repLevelTextWrapChar = 5, -- ANGLE
		enableIcon = true,
		repIconTexture = "",
	},
	prof = {
		enabled = true,
		showSkillChange = true,
		skillColor = { 0.333, 0.333, 1.0, 1.0 },
		skillTextWrapChar = 3, -- BRACKET
		enableIcon = true,
	},
	travelPoints = {
		enabled = true,
		textColor = { 1, 0.988, 0.498, 1 },
		enableIcon = true,
	},
	transmog = {
		enabled = true,
		enableTransmogEffect = true,
		enableBlizzardTransmogSound = true,
		enableIcon = true,
	},
}

--------------------------------------------------
-- Appearance copy helpers (with LEGACY_DEFAULTS fallback)
--------------------------------------------------

--- Copy positioning values from a source table with legacy defaults fallback.
--- @param source table? AceDB positioning table (e.g. global.positioning)
--- @return RLF_ConfigPositioning
local function copyPositioning(source)
	source = source or {}
	local d = LEGACY_DEFAULTS.positioning
	return {
		relativePoint = pick(source.relativePoint, d.relativePoint),
		anchorPoint = pick(source.anchorPoint, d.anchorPoint),
		xOffset = pick(source.xOffset, d.xOffset),
		yOffset = pick(source.yOffset, d.yOffset),
		frameStrata = pick(source.frameStrata, d.frameStrata),
	}
end

--- @param source table? AceDB sizing table
--- @return RLF_ConfigSizing
local function copySizing(source)
	source = source or {}
	local d = LEGACY_DEFAULTS.sizing
	return {
		feedWidth = pick(source.feedWidth, d.feedWidth),
		maxRows = pick(source.maxRows, d.maxRows),
		rowHeight = pick(source.rowHeight, d.rowHeight),
		padding = pick(source.padding, d.padding),
		iconSize = pick(source.iconSize, d.iconSize),
	}
end

--- @param source table? AceDB styling table
--- @return RLF_ConfigStyling
local function copyStyling(source)
	source = source or {}
	local d = LEGACY_DEFAULTS.styling
	return {
		enabledSecondaryRowText = pick(source.enabledSecondaryRowText, d.enabledSecondaryRowText),
		textAlignment = pick(source.textAlignment, d.textAlignment),
		growUp = pick(source.growUp, d.growUp),
		rowBackgroundType = pick(source.rowBackgroundType, d.rowBackgroundType),
		rowBackgroundTexture = pick(source.rowBackgroundTexture, d.rowBackgroundTexture),
		rowBackgroundTextureColor = copyColor(source.rowBackgroundTextureColor or d.rowBackgroundTextureColor),
		rowBackgroundGradientStart = copyColor(source.rowBackgroundGradientStart or d.rowBackgroundGradientStart),
		rowBackgroundGradientEnd = copyColor(source.rowBackgroundGradientEnd or d.rowBackgroundGradientEnd),
		backdropInsets = copyFields(source.backdropInsets or d.backdropInsets),
		enableRowBorder = pick(source.enableRowBorder, d.enableRowBorder),
		rowBorderSize = pick(source.rowBorderSize, d.rowBorderSize),
		rowBorderColor = copyColor(source.rowBorderColor or d.rowBorderColor),
		rowBorderClassColors = pick(source.rowBorderClassColors, d.rowBorderClassColors),
		rowBorderTexture = pick(source.rowBorderTexture, d.rowBorderTexture),
		useFontObjects = pick(source.useFontObjects, d.useFontObjects),
		font = pick(source.font, d.font),
		fontFace = pick(source.fontFace, d.fontFace),
		fontSize = pick(source.fontSize, d.fontSize),
		secondaryFontSize = pick(source.secondaryFontSize, d.secondaryFontSize),
		enableTopLeftIconText = pick(source.enableTopLeftIconText, d.enableTopLeftIconText),
		topLeftIconFontSize = pick(source.topLeftIconFontSize, d.topLeftIconFontSize),
		topLeftIconTextColor = copyColor(source.topLeftIconTextColor or d.topLeftIconTextColor),
		topLeftIconTextUseQualityColor = pick(source.topLeftIconTextUseQualityColor, d.topLeftIconTextUseQualityColor),
		fontFlags = copyFields(source.fontFlags or d.fontFlags),
		fontShadowColor = copyColor(source.fontShadowColor or d.fontShadowColor),
		fontShadowOffsetX = pick(source.fontShadowOffsetX, d.fontShadowOffsetX),
		fontShadowOffsetY = pick(source.fontShadowOffsetY, d.fontShadowOffsetY),
		rowTextSpacing = pick(source.rowTextSpacing, d.rowTextSpacing),
	}
end

--- @param source table? AceDB animations table
--- @return RLF_ConfigAnimations
local function copyAnimations(source)
	source = source or {}
	local d = LEGACY_DEFAULTS.animations
	local enter = source.enter or {}
	local exit = source.exit or {}
	local hover = source.hover or {}
	local update = source.update or {}
	local reposition = source.reposition or {}
	local slide = enter.slide or {}
	local de = d.enter
	local dx = d.exit
	local dh = d.hover
	local du = d.update
	local dr = d.reposition
	local ds = de.slide
	return {
		enter = {
			type = pick(enter.type, de.type),
			duration = pick(enter.duration, de.duration),
			slide = {
				direction = pick(slide.direction, ds.direction),
			},
		},
		exit = {
			disable = pick(exit.disable, dx.disable),
			type = pick(exit.type, dx.type),
			duration = pick(exit.duration, dx.duration),
			fadeOutDelay = pick(exit.fadeOutDelay, dx.fadeOutDelay),
		},
		hover = {
			enabled = pick(hover.enabled, dh.enabled),
			alpha = pick(hover.alpha, dh.alpha),
			baseDuration = pick(hover.baseDuration, dh.baseDuration),
		},
		update = {
			disableHighlight = pick(update.disableHighlight, du.disableHighlight),
			duration = pick(update.duration, du.duration),
			loop = pick(update.loop, du.loop),
		},
		reposition = {
			duration = pick(reposition.duration, dr.duration),
		},
	}
end

--- Like copyStyling but falls back per-key to a secondary source, then to
--- LEGACY_DEFAULTS.  Used for the party frame where partyLoot.styling may
--- have nil keys after Phase 4 removed those AceDB defaults.
--- @param primary table?
--- @param fallback table?
--- @return RLF_ConfigStyling
local function copyStylingWithFallback(primary, fallback)
	primary = primary or {}
	fallback = fallback or {}
	local d = LEGACY_DEFAULTS.styling
	return {
		enabledSecondaryRowText = pick(
			primary.enabledSecondaryRowText,
			pick(fallback.enabledSecondaryRowText, d.enabledSecondaryRowText)
		),
		textAlignment = pick(primary.textAlignment, pick(fallback.textAlignment, d.textAlignment)),
		growUp = pick(primary.growUp, pick(fallback.growUp, d.growUp)),
		rowBackgroundType = pick(primary.rowBackgroundType, pick(fallback.rowBackgroundType, d.rowBackgroundType)),
		rowBackgroundTexture = pick(
			primary.rowBackgroundTexture,
			pick(fallback.rowBackgroundTexture, d.rowBackgroundTexture)
		),
		rowBackgroundTextureColor = copyColor(
			primary.rowBackgroundTextureColor or fallback.rowBackgroundTextureColor or d.rowBackgroundTextureColor
		),
		rowBackgroundGradientStart = copyColor(
			primary.rowBackgroundGradientStart or fallback.rowBackgroundGradientStart or d.rowBackgroundGradientStart
		),
		rowBackgroundGradientEnd = copyColor(
			primary.rowBackgroundGradientEnd or fallback.rowBackgroundGradientEnd or d.rowBackgroundGradientEnd
		),
		backdropInsets = copyFields(primary.backdropInsets or fallback.backdropInsets or d.backdropInsets),
		enableRowBorder = pick(primary.enableRowBorder, pick(fallback.enableRowBorder, d.enableRowBorder)),
		rowBorderSize = pick(primary.rowBorderSize, pick(fallback.rowBorderSize, d.rowBorderSize)),
		rowBorderColor = copyColor(primary.rowBorderColor or fallback.rowBorderColor or d.rowBorderColor),
		rowBorderClassColors = pick(
			primary.rowBorderClassColors,
			pick(fallback.rowBorderClassColors, d.rowBorderClassColors)
		),
		rowBorderTexture = pick(primary.rowBorderTexture, pick(fallback.rowBorderTexture, d.rowBorderTexture)),
		useFontObjects = pick(primary.useFontObjects, pick(fallback.useFontObjects, d.useFontObjects)),
		font = pick(primary.font, pick(fallback.font, d.font)),
		fontFace = pick(primary.fontFace, pick(fallback.fontFace, d.fontFace)),
		fontSize = pick(primary.fontSize, pick(fallback.fontSize, d.fontSize)),
		secondaryFontSize = pick(primary.secondaryFontSize, pick(fallback.secondaryFontSize, d.secondaryFontSize)),
		enableTopLeftIconText = pick(
			primary.enableTopLeftIconText,
			pick(fallback.enableTopLeftIconText, d.enableTopLeftIconText)
		),
		topLeftIconFontSize = pick(
			primary.topLeftIconFontSize,
			pick(fallback.topLeftIconFontSize, d.topLeftIconFontSize)
		),
		topLeftIconTextColor = copyColor(
			primary.topLeftIconTextColor or fallback.topLeftIconTextColor or d.topLeftIconTextColor
		),
		topLeftIconTextUseQualityColor = pick(
			primary.topLeftIconTextUseQualityColor,
			pick(fallback.topLeftIconTextUseQualityColor, d.topLeftIconTextUseQualityColor)
		),
		fontFlags = copyFields(primary.fontFlags or fallback.fontFlags or d.fontFlags),
		fontShadowColor = copyColor(primary.fontShadowColor or fallback.fontShadowColor or d.fontShadowColor),
		fontShadowOffsetX = pick(primary.fontShadowOffsetX, pick(fallback.fontShadowOffsetX, d.fontShadowOffsetX)),
		fontShadowOffsetY = pick(primary.fontShadowOffsetY, pick(fallback.fontShadowOffsetY, d.fontShadowOffsetY)),
		rowTextSpacing = pick(primary.rowTextSpacing, pick(fallback.rowTextSpacing, d.rowTextSpacing)),
	}
end

--------------------------------------------------
-- Feature configuration copy helpers
--------------------------------------------------

--- Copy item quality settings (keyed by quality enum 0–8).
--- @param source table?
--- @param fallback table? Legacy defaults for quality settings
--- @return table
local function copyQualitySettings(source, fallback)
	source = source or {}
	fallback = fallback or {}
	local out = {}
	for q = 0, 8 do
		local src = source[q]
		local fb = fallback[q]
		if src or fb then
			src = src or {}
			fb = fb or {}
			out[q] = {
				enabled = pick(src.enabled, fb.enabled),
				duration = pick(src.duration, fb.duration),
			}
		end
	end
	return out
end

--- Copy item quality filter (keyed by quality enum 0–7).
--- @param source table?
--- @param fallback table? Legacy defaults for quality filter
--- @return table
local function copyQualityFilter(source, fallback)
	source = source or {}
	fallback = fallback or {}
	local out = {}
	for q = 0, 7 do
		out[q] = pick(source[q], fallback[q])
	end
	return out
end

--- Copy item highlight booleans.
--- @param source table?
--- @param fallback table? Legacy defaults for highlights
--- @return table
local function copyItemHighlights(source, fallback)
	source = source or {}
	fallback = fallback or {}
	return {
		boe = pick(source.boe, fallback.boe),
		bop = pick(source.bop, fallback.bop),
		quest = pick(source.quest, fallback.quest),
		transmog = pick(source.transmog, fallback.transmog),
		mounts = pick(source.mounts, fallback.mounts),
		legendary = pick(source.legendary, fallback.legendary),
		betterThanEquipped = pick(source.betterThanEquipped, fallback.betterThanEquipped),
		hasTertiaryOrSocket = pick(source.hasTertiaryOrSocket, fallback.hasTertiaryOrSocket),
	}
end

--- Copy sounds table (keyed trigger → { enabled, sound }).
--- @param source table?
--- @param fallback table? Legacy defaults for sounds
--- @return table
local function copySounds(source, fallback)
	source = source or {}
	fallback = fallback or {}
	local out = {}
	for _, key in ipairs({ "mounts", "legendary", "betterThanEquipped", "transmog" }) do
		local s = source[key]
		local f = fallback[key]
		if s or f then
			s = s or {}
			f = f or {}
			out[key] = {
				enabled = pick(s.enabled, f.enabled),
				sound = pick(s.sound, f.sound),
			}
		end
	end
	return out
end

--- Copy textStyleOverrides.
--- @param source table?
--- @param fallback table? Legacy defaults for text style overrides
--- @return table
local function copyTextStyleOverrides(source, fallback)
	source = source or {}
	fallback = fallback or {}
	local out = {}
	local questSrc = source.quest or {}
	local questFb = fallback.quest or {}
	if source.quest or fallback.quest then
		out.quest = {
			enabled = pick(questSrc.enabled, questFb.enabled),
			color = copyColor(questSrc.color or questFb.color),
		}
	end
	return out
end

--- @param source table? AceDB item config (db.global.item)
--- @return RLF_FeatureConfig_ItemLoot
local function copyItemLootFeature(source)
	source = source or {}
	local d = LEGACY_DEFAULTS.item
	return {
		enabled = pick(source.enabled, d.enabled),
		itemCountTextEnabled = pick(source.itemCountTextEnabled, d.itemCountTextEnabled),
		itemCountTextColor = copyColor(source.itemCountTextColor or d.itemCountTextColor),
		itemCountTextWrapChar = pick(source.itemCountTextWrapChar, d.itemCountTextWrapChar),
		itemQualitySettings = copyQualitySettings(source.itemQualitySettings, d.itemQualitySettings),
		itemHighlights = copyItemHighlights(source.itemHighlights, d.itemHighlights),
		auctionHouseSource = pick(source.auctionHouseSource, d.auctionHouseSource),
		pricesForSellableItems = pick(source.pricesForSellableItems, d.pricesForSellableItems),
		vendorIconTexture = pick(source.vendorIconTexture, d.vendorIconTexture),
		auctionHouseIconTexture = pick(source.auctionHouseIconTexture, d.auctionHouseIconTexture),
		sounds = copySounds(source.sounds, d.sounds),
		textStyleOverrides = copyTextStyleOverrides(source.textStyleOverrides, d.textStyleOverrides),
		enableIcon = pick(source.enableIcon, d.enableIcon),
	}
end

--- @param source table? AceDB party loot config (db.global.partyLoot)
--- @return RLF_FeatureConfig_PartyLoot
local function copyPartyLootFeature(source)
	source = source or {}
	local d = LEGACY_DEFAULTS.partyLoot
	return {
		enabled = pick(source.enabled, d.enabled),
		itemQualityFilter = copyQualityFilter(source.itemQualityFilter, d.itemQualityFilter),
		hideServerNames = pick(source.hideServerNames, d.hideServerNames),
		onlyEpicAndAboveInRaid = pick(source.onlyEpicAndAboveInRaid, d.onlyEpicAndAboveInRaid),
		onlyEpicAndAboveInInstance = pick(source.onlyEpicAndAboveInInstance, d.onlyEpicAndAboveInInstance),
		ignoreItemIds = copyFields(source.ignoreItemIds or d.ignoreItemIds),
		enableIcon = pick(source.enableIcon, d.enableIcon),
		enablePartyAvatar = pick(source.enablePartyAvatar, d.enablePartyAvatar),
	}
end

--- @param source table? AceDB currency config (db.global.currency)
--- @return RLF_FeatureConfig_Currency
local function copyCurrencyFeature(source)
	source = source or {}
	local d = LEGACY_DEFAULTS.currency
	return {
		enabled = pick(source.enabled, d.enabled),
		currencyTotalTextEnabled = pick(source.currencyTotalTextEnabled, d.currencyTotalTextEnabled),
		currencyTotalTextColor = copyColor(source.currencyTotalTextColor or d.currencyTotalTextColor),
		currencyTotalTextWrapChar = pick(source.currencyTotalTextWrapChar, d.currencyTotalTextWrapChar),
		lowerThreshold = pick(source.lowerThreshold, d.lowerThreshold),
		upperThreshold = pick(source.upperThreshold, d.upperThreshold),
		lowestColor = copyColor(source.lowestColor or d.lowestColor),
		midColor = copyColor(source.midColor or d.midColor),
		upperColor = copyColor(source.upperColor or d.upperColor),
		enableIcon = pick(source.enableIcon, d.enableIcon),
	}
end

--- @param source table? AceDB money config (db.global.money)
--- @return RLF_FeatureConfig_Money
local function copyMoneyFeature(source)
	source = source or {}
	local d = LEGACY_DEFAULTS.money
	return {
		enabled = pick(source.enabled, d.enabled),
		showMoneyTotal = pick(source.showMoneyTotal, d.showMoneyTotal),
		moneyTotalColor = copyColor(source.moneyTotalColor or d.moneyTotalColor),
		moneyTextWrapChar = pick(source.moneyTextWrapChar, d.moneyTextWrapChar),
		abbreviateTotal = pick(source.abbreviateTotal, d.abbreviateTotal),
		accountantMode = pick(source.accountantMode, d.accountantMode),
		onlyIncome = pick(source.onlyIncome, d.onlyIncome),
		overrideMoneyLootSound = pick(source.overrideMoneyLootSound, d.overrideMoneyLootSound),
		moneyLootSound = pick(source.moneyLootSound, d.moneyLootSound),
		enableIcon = pick(source.enableIcon, d.enableIcon),
	}
end

--- @param source table? AceDB experience config (db.global.xp)
--- @return RLF_FeatureConfig_Experience
local function copyExperienceFeature(source)
	source = source or {}
	local d = LEGACY_DEFAULTS.xp
	return {
		enabled = pick(source.enabled, d.enabled),
		experienceTextColor = copyColor(source.experienceTextColor or d.experienceTextColor),
		showCurrentLevel = pick(source.showCurrentLevel, d.showCurrentLevel),
		currentLevelColor = copyColor(source.currentLevelColor or d.currentLevelColor),
		currentLevelTextWrapChar = pick(source.currentLevelTextWrapChar, d.currentLevelTextWrapChar),
		enableIcon = pick(source.enableIcon, d.enableIcon),
	}
end

--- @param source table? AceDB reputation config (db.global.rep)
--- @return RLF_FeatureConfig_Reputation
local function copyReputationFeature(source)
	source = source or {}
	local d = LEGACY_DEFAULTS.rep
	return {
		enabled = pick(source.enabled, d.enabled),
		defaultRepColor = copyColor(source.defaultRepColor or d.defaultRepColor),
		secondaryTextAlpha = pick(source.secondaryTextAlpha, d.secondaryTextAlpha),
		enableRepLevel = pick(source.enableRepLevel, d.enableRepLevel),
		repLevelColor = copyColor(source.repLevelColor or d.repLevelColor),
		repLevelTextWrapChar = pick(source.repLevelTextWrapChar, d.repLevelTextWrapChar),
		enableIcon = pick(source.enableIcon, d.enableIcon),
		repIconTexture = pick(source.repIconTexture, d.repIconTexture),
	}
end

--- @param source table? AceDB profession config (db.global.prof)
--- @return RLF_FeatureConfig_Profession
local function copyProfessionFeature(source)
	source = source or {}
	local d = LEGACY_DEFAULTS.prof
	return {
		enabled = pick(source.enabled, d.enabled),
		showSkillChange = pick(source.showSkillChange, d.showSkillChange),
		skillColor = copyColor(source.skillColor or d.skillColor),
		skillTextWrapChar = pick(source.skillTextWrapChar, d.skillTextWrapChar),
		enableIcon = pick(source.enableIcon, d.enableIcon),
	}
end

--- @param source table? AceDB travelPoints config (db.global.travelPoints)
--- @return RLF_FeatureConfig_TravelPoints
local function copyTravelPointsFeature(source)
	source = source or {}
	local d = LEGACY_DEFAULTS.travelPoints
	return {
		enabled = pick(source.enabled, d.enabled),
		textColor = copyColor(source.textColor or d.textColor),
		enableIcon = pick(source.enableIcon, d.enableIcon),
	}
end

--- @param source table? AceDB transmog config (db.global.transmog)
--- @return RLF_FeatureConfig_Transmog
local function copyTransmogFeature(source)
	source = source or {}
	local d = LEGACY_DEFAULTS.transmog
	return {
		enabled = pick(source.enabled, d.enabled),
		enableTransmogEffect = pick(source.enableTransmogEffect, d.enableTransmogEffect),
		enableBlizzardTransmogSound = pick(source.enableBlizzardTransmogSound, d.enableBlizzardTransmogSound),
		enableIcon = pick(source.enableIcon, d.enableIcon),
	}
end

--- Build the full features table for a frame, copying all feature configs
--- from the current top-level DB tables.
--- @param global table  The db.global table containing old feature configs
--- @param enabledOverrides table<string, boolean>?  Per-feature enabled overrides
--- @return RLF_FrameFeatures
local function buildFeatures(global, enabledOverrides)
	local features = {
		itemLoot = copyItemLootFeature(global.item),
		partyLoot = copyPartyLootFeature(global.partyLoot),
		currency = copyCurrencyFeature(global.currency),
		money = copyMoneyFeature(global.money),
		experience = copyExperienceFeature(global.xp),
		reputation = copyReputationFeature(global.rep),
		profession = copyProfessionFeature(global.prof),
		travelPoints = copyTravelPointsFeature(global.travelPoints),
		transmog = copyTransmogFeature(global.transmog),
	}
	if enabledOverrides then
		for key, enabled in pairs(enabledOverrides) do
			if features[key] then
				features[key].enabled = enabled
			end
		end
	end
	return features
end

--------------------------------------------------
-- Public surface: expose only what migration scripts call directly.
-- All other helpers remain local (captured by closure in buildFeatures etc.).
--------------------------------------------------
G_RLF._migHelpers = {
	copyPositioning = copyPositioning,
	copySizing = copySizing,
	copyStyling = copyStyling,
	copyAnimations = copyAnimations,
	copyStylingWithFallback = copyStylingWithFallback,
	buildFeatures = buildFeatures,
}

--- Returns a recovery snapshot built from old flat keys, or nil if there
--- are no old flat keys (fresh install).
---
--- Previous versions used rawget to detect whether v8 wrote frames[1], but
--- AceDB caches child proxy tables at explicitly-defaulted keys, making
--- rawget unreliable.  This function now always builds the snapshot when
--- old flat keys exist.  The caller (v9) compares the snapshot against
--- the current frames[1] to decide if recovery is needed.
--- @param global table  db.global
--- @return table|nil  snapshot built from old flat keys, or nil
function G_RLF:BuildV8RecoverySnapshot(global)
	-- Check if ANY old flat key exists.  These keys are only present in
	-- SavedVariables if the user explicitly changed a setting pre-v8 or
	-- an earlier migration wrote them.  AceDB defaults for these keys
	-- were removed in the multi-frame migration, so nil means fresh install.
	local hasOldData = global.positioning ~= nil
		or global.sizing ~= nil
		or global.styling ~= nil
		or global.animations ~= nil
		or global.item ~= nil
		or global.currency ~= nil
		or global.money ~= nil
		or global.xp ~= nil
		or global.rep ~= nil
		or global.prof ~= nil
		or global.travelPoints ~= nil
		or global.transmog ~= nil
		or global.partyLoot ~= nil
	if not hasOldData then
		return nil -- fresh install, nothing to recover
	end
	-- Mirror v8's behavior: if the user had a separate party frame,
	-- partyLoot was disabled on the Main frame.
	local partyLoot = global.partyLoot
	local partyLootSeparate = partyLoot and partyLoot.separateFrame == true

	return {
		name = G_RLF.L["Main"],
		positioning = copyPositioning(global.positioning),
		sizing = copySizing(global.sizing),
		styling = copyStyling(global.styling),
		animations = copyAnimations(global.animations),
		features = buildFeatures(global, partyLootSeparate and { partyLoot = false } or nil),
	}
end

--- Recursively compare two values for equality.
--- Tables are compared by key; non-table values use ==.
--- Ignores the "name" key at the top level of snapshots (it's cosmetic).
--- @param a any
--- @param b any
--- @return boolean  true if a and b are deeply equal
local function deepEqual(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	-- Check all keys in a
	for k, v in pairs(a) do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	-- Check for keys in b that are not in a
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

--- Collect all leaf-level differences between two tables.
--- Returns an array of { path = "dotted.path", old = snapshotVal, new = currentVal }.
--- "old" means the snapshot (legacy) value; "new" means the current frames[1] value.
--- @param a table  snapshot table
--- @param b table  current config table
--- @param prefix string  dotted path prefix (pass "" for root)
--- @param diffs table  accumulator array (pass {} for root)
--- @return table  array of diff entries
local function collectDiffs(a, b, prefix, diffs)
	a = a or {}
	b = b or {}
	-- Iterate only snapshot (a) keys.
	-- Keys present only in b are new features at their default values — not
	-- user data that was lost — so we intentionally skip them.
	for k in pairs(a) do
		local fullKey = prefix ~= "" and (prefix .. "." .. tostring(k)) or tostring(k)
		local va, vb = a[k], b[k]
		if type(va) == "table" or type(vb) == "table" then
			collectDiffs(type(va) == "table" and va or {}, type(vb) == "table" and vb or {}, fullKey, diffs)
		elseif va ~= vb then
			diffs[#diffs + 1] = { path = fullKey, old = va, new = vb }
		end
	end
	return diffs
end

--- Compare a recovery snapshot against the current frame config.
--- Returns true if any meaningful difference is found, indicating
--- that the snapshot has settings worth recovering.
--- Skips the cosmetic "name" key since it's always "Main".
--- @param snapshot table  The snapshot built from old flat keys
--- @param currentFrame table  The current frames[1] (may be AceDB proxy)
--- @return boolean  true if the snapshot differs from currentFrame
function G_RLF:SnapshotDiffersFromFrame(snapshot, currentFrame)
	if not snapshot or not currentFrame then
		return snapshot ~= nil
	end

	-- Compare each section recursively (skip "name" — cosmetic only)
	local sections = { "positioning", "sizing", "styling", "animations", "features" }
	for _, section in ipairs(sections) do
		if not deepEqual(snapshot[section], currentFrame[section]) then
			return true
		end
	end

	return false
end

--- Build an array of diff entries between the snapshot and current frame,
--- suitable for display in the Settings Recovery UI.
--- @param snapshot table  The snapshot built from old flat keys
--- @param currentFrame table  The current frames[1]
--- @return table  array of { path, old, new }
function G_RLF:ComputeSnapshotDiff(snapshot, currentFrame)
	if not snapshot or not currentFrame then
		return {}
	end
	local diffs = {}
	local sections = { "positioning", "sizing", "styling", "animations", "features" }
	for _, section in ipairs(sections) do
		collectDiffs(snapshot[section], currentFrame[section], section, diffs)
	end
	return diffs
end
