---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local setPath = G_RLF.ConfigCommon.DbUtils.setPath
local getPath = G_RLF.ConfigCommon.DbUtils.getPath

---Check if a string starts with another string
---@param str string
---@param start string
---@return boolean
local function startswith(str, start)
	return string.sub(str, 1, #start) == start
end

local lsm = G_RLF.lsm

---@class RLF_StylingBase
local StylingBase = {}

---@class RLF_ConfigStyling
StylingBase.defaultDb = {
	enabledSecondaryRowText = false,
	textAlignment = "LEFT",
	growUp = true,
	rowBackgroundType = G_RLF.RowBackground.GRADIENT,
	rowBackgroundTexture = "Solid",
	rowBackgroundTextureColor = { 0, 0, 0, 1 },
	rowBackgroundGradientStart = { 0.1, 0.1, 0.1, 0.8 },
	rowBackgroundGradientEnd = { 0.1, 0.1, 0.1, 0 },
	backdropInsets = {
		left = 0,
		right = 0,
		top = 0,
		bottom = 0,
	},
	enableRowBorder = false,
	rowBorderSize = 1,
	rowBorderColor = { 0, 0, 0, 1 },
	rowBorderClassColors = false,
	rowBorderTexture = "None",
	iconSkin = G_RLF.IconSkin.AUTO,
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
		[G_RLF.FontFlags.NONE] = true,
		[G_RLF.FontFlags.OUTLINE] = false,
		[G_RLF.FontFlags.THICKOUTLINE] = false,
		[G_RLF.FontFlags.MONOCHROME] = false,
	},
	fontShadowColor = { 0, 0, 0, 1 },
	fontShadowOffsetX = 1,
	fontShadowOffsetY = -1,
	-- Pixel gap between PrimaryLineLayout/SecondaryLineLayout children and between
	-- the icon and the layout container.  0 = auto (iconSize / 4, scales with icon).
	rowTextSpacing = 0,
}

---@param destDbPath string
---@return RLF_ConfigStyling
function StylingBase.CloneDefaultDb(destDbPath)
	setPath(G_RLF.defaults, destDbPath, StylingBase.defaultDb)
	return getPath(G_RLF.defaults, destDbPath)
end

---@class RLF_StylingConfigHandlerBase
---@field GetTextAlignment fun(): string
---@field SetTextAlignment fun(info: any, value: string)
---@field GetGrowUp fun(): boolean
---@field SetGrowUp fun(info: any, value: boolean)
---@field GetBackgroundType fun(): number
---@field SetBackgroundType fun(info: any, value: number)
---@field IsGradientHidden fun(): boolean
---@field GetGradientStartColor fun(): table
---@field SetGradientStartColor fun(info: any, value: table)
---@field GetGradientEndColor fun(): table
---@field SetGradientEndColor fun(info: any, value: table)
---@field IsBackgroundTextureHidden fun(): boolean
---@field GetBackgroundTexture fun(): string
---@field SetBackgroundTexture fun(info: any, value: string)
---@field GetBackgroundTextureColor fun(): number, number, number, number
---@field SetBackgroundTextureColor fun(info: any, r: number, g: number, b: number, a: number)
---@field GetTopInset fun(): number
---@field SetTopInset fun(info: any, value: number)
---@field GetBottomInset fun(): number
---@field SetBottomInset fun(info: any, value: number)
---@field GetRightInset fun(): number
---@field SetRightInset fun(info: any, value: number)
---@field GetLeftInset fun(): number
---@field SetLeftInset fun(info: any, value: number)
---@field GetRowBordersEnabled fun(): boolean
---@field SetRowBordersEnabled fun(info: any, value: boolean)
---@field IsRowBorderDisabled fun(): boolean
---@field GetRowBorderTexture fun(): string
---@field SetRowBorderTexture fun(info: any, value: string)
---@field GetRowBorderThickness fun(): number
---@field SetRowBorderThickness fun(info: any, value: number)
---@field GetRowBorderColor fun(): number, number, number, number
---@field SetRowBorderColor fun(info: any, r: number, g: number, b: number, a: number)
---@field GetRowBorderClassColors fun(): boolean
---@field SetRowBorderClassColors fun(info: any, value: boolean)
---@field GetIconSkin fun(): string
---@field SetIconSkin fun(info: any, value: string)
---@field GetEnabledSecondaryRowText fun(): boolean
---@field SetEnabledSecondaryRowText fun(info: any, value: boolean)
---@field GetEnableTopLeftIconText fun(): boolean
---@field SetEnableTopLeftIconText fun(info: any, value: boolean)
---@field IsTopLeftIconTextDisabled fun(): boolean
---@field IsTopLeftIconTextColorDisabled fun(): boolean
---@field GetTopLeftIconFontSize fun(): number
---@field SetTopLeftIconFontSize fun(info: any, value: number)
---@field GetTopLeftIconTextUseQualityColor fun(): boolean
---@field SetTopLeftIconTextUseQualityColor fun(info: any, value: boolean)
---@field GetTopLeftIconTextColor fun(): number, number, number, number
---@field SetTopLeftIconTextColor fun(info: any, r: number, g: number, b: number, a: number)
---@field GetUseFontObjects fun(): boolean
---@field SetUseFontObjects fun(info: any, value: boolean)
---@field IsFontObjectsDisabled fun(): boolean
---@field GetFontObject fun(): string
---@field SetFontObject fun(info: any, value: string)
---@field GetFontFace fun(): string
---@field SetFontFace fun(info: any, value: string)
---@field GetFontSize fun(): number
---@field SetFontSize fun(info: any, value: number)
---@field IsSecondaryFontSizeDisabled fun(): boolean
---@field GetSecondaryFontSize fun(): number
---@field SetSecondaryFontSize fun(info: any, value: number)
---@field GetFontFlags fun(_: any, key: string): boolean
---@field SetFontFlags fun(info: any, key: string, value: boolean)
---@field GetShadowColor fun(): number, number, number, number
---@field SetShadowColor fun(info: any, r: number, g: number, b: number, a: number)
---@field GetShadowOffsetX fun(): number
---@field SetShadowOffsetX fun(info: any, value: number)
---@field GetShadowOffsetY fun(): number
---@field SetShadowOffsetY fun(info: any, value: number)
---@field IsCustomFontsDisabled fun(): boolean
---@field GetRowTextSpacing fun(): number
---@field SetRowTextSpacing fun(info: any, value: number)

---@private
function StylingBase.CreateTextAlignmentSelect(handler)
	return G_RLF.ConfigCommon.CreateSelect({
		name = G_RLF.L["Text Alignment"],
		desc = G_RLF.L["TextAlignmentDesc"],
		handler = handler,
		get = "GetTextAlignment",
		set = "SetTextAlignment",
		width = "double",
		order = 2,
		values = {
			[G_RLF.TextAlignment.LEFT] = G_RLF.L["Left"],
			-- [G_RLF.TextAlignment.CENTER] = G_RLF.L["Center"],
			[G_RLF.TextAlignment.RIGHT] = G_RLF.L["Right"],
		},
		sorting = {
			G_RLF.TextAlignment.LEFT,
			-- G_RLF.TextAlignment.CENTER,
			G_RLF.TextAlignment.RIGHT,
		},
	})
end

---@private
function StylingBase.CreateGrowUpToggle()
	return G_RLF.ConfigCommon.CreateToggle({
		name = G_RLF.L["Grow Up"],
		desc = G_RLF.L["GrowUpDesc"],
		get = "GetGrowUp",
		set = "SetGrowUp",
		width = "double",
		order = 1,
	})
end

---@private
function StylingBase.CreateFlowGroup(handler)
	local group = G_RLF.ConfigCommon.CreateGroup({
		name = G_RLF.L["Flow"],
		inline = true,
		order = 1,
	})
	group.args.textAlignment = StylingBase.CreateTextAlignmentSelect(handler)
	group.args.growUp = StylingBase.CreateGrowUpToggle()

	return group
end

---@private
function StylingBase.CreateBackgroundTypeSelect()
	return G_RLF.ConfigCommon.CreateSelect({
		name = G_RLF.L["Background Type"],
		desc = G_RLF.L["BackgroundTypeDesc"],
		values = {
			-- May add this in at some point if requested
			-- [G_RLF.RowBackground.NONE] = G_RLF.L["None"]
			[G_RLF.RowBackground.GRADIENT] = G_RLF.L["Gradient"],
			[G_RLF.RowBackground.TEXTURED] = G_RLF.L["Textured"],
		},
		get = "GetBackgroundType",
		set = "SetBackgroundType",
		width = "double",
		order = 1,
	})
end

---@private
function StylingBase.CreateGradientStartColor()
	return G_RLF.ConfigCommon.CreateColor({
		name = G_RLF.L["Background Gradient Start"],
		desc = G_RLF.L["GradientStartDesc"],
		hidden = "IsGradientHidden",
		get = "GetGradientStartColor",
		set = "SetGradientStartColor",
		hasAlpha = true,
		width = "double",
		order = 2.1,
	})
end

---@private
function StylingBase.CreateGradientEndColor()
	return G_RLF.ConfigCommon.CreateColor({
		name = G_RLF.L["Background Gradient End"],
		desc = G_RLF.L["GradientEndDesc"],
		hidden = "IsGradientHidden",
		get = "GetGradientEndColor",
		set = "SetGradientEndColor",
		hasAlpha = true,
		order = 2.2,
	})
end

---@private
function StylingBase.CreateBackgroundTextureSelect()
	return G_RLF.ConfigCommon.CreateSelect({
		name = G_RLF.L["Background Texture"],
		desc = G_RLF.L["BackgroundTextureDesc"],
		dialogControl = "LSM30_Background",
		values = function()
			return lsm:HashTable(lsm.MediaType.BACKGROUND)
		end,
		hidden = "IsBackgroundTextureHidden",
		get = "GetBackgroundTexture",
		set = "SetBackgroundTexture",
		width = "double",
		order = 2.1,
	})
end

---@private
function StylingBase.CreateBackgroundTextureColor()
	return G_RLF.ConfigCommon.CreateColor({
		name = G_RLF.L["Background Texture Color"],
		desc = G_RLF.L["BackgroundTextureColorDesc"],
		hidden = "IsBackgroundTextureHidden",
		get = "GetBackgroundTextureColor",
		set = "SetBackgroundTextureColor",
		hasAlpha = true,
		width = "double",
		order = 2.2,
	})
end

---@private
function StylingBase.CreateInsetDescription()
	return G_RLF.ConfigCommon.CreateDescription({
		name = string.format("\n%s", G_RLF.L["BackdropInsetsDesc"]),
		order = 3,
	})
end

---@private
function StylingBase.CreateInsetRange(name, desc, get, set, order)
	return G_RLF.ConfigCommon.CreateRange({
		name = name,
		desc = desc,
		get = get,
		set = set,
		min = 0,
		max = 20,
		bigStep = 1,
		width = "double",
		order = order,
	})
end

---@private
function StylingBase.CreateTopInsetRange()
	return StylingBase.CreateInsetRange(G_RLF.L["Top Inset"], G_RLF.L["TopInsetDesc"], "GetTopInset", "SetTopInset", 4)
end

---@private
function StylingBase.CreateRightInsetRange()
	return StylingBase.CreateInsetRange(
		G_RLF.L["Right Inset"],
		G_RLF.L["RightInsetDesc"],
		"GetRightInset",
		"SetRightInset",
		5
	)
end

---@private
function StylingBase.CreateBottomInsetRange()
	return StylingBase.CreateInsetRange(
		G_RLF.L["Bottom Inset"],
		G_RLF.L["BottomInsetDesc"],
		"GetBottomInset",
		"SetBottomInset",
		6
	)
end

---@private
function StylingBase.CreateLeftInsetRange()
	return StylingBase.CreateInsetRange(
		G_RLF.L["Left Inset"],
		G_RLF.L["LeftInsetDesc"],
		"GetLeftInset",
		"SetLeftInset",
		7
	)
end

---@private
function StylingBase.CreateBackgroundGroup()
	local group = G_RLF.ConfigCommon.CreateGroup({
		name = G_RLF.L["Background"],
		inline = true,
		order = 3,
	})
	group.args.backgroundType = StylingBase.CreateBackgroundTypeSelect()
	group.args.gradientStart = StylingBase.CreateGradientStartColor()
	group.args.gradientEnd = StylingBase.CreateGradientEndColor()
	group.args.backgroundTexture = StylingBase.CreateBackgroundTextureSelect()
	group.args.backgroundTextureColor = StylingBase.CreateBackgroundTextureColor()
	group.args.insetDesc = StylingBase.CreateInsetDescription()
	group.args.topInset = StylingBase.CreateTopInsetRange()
	group.args.rightInset = StylingBase.CreateRightInsetRange()
	group.args.bottomInset = StylingBase.CreateBottomInsetRange()
	group.args.leftInset = StylingBase.CreateLeftInsetRange()

	return group
end

---@private
function StylingBase.CreateBorderEnableToggle()
	return G_RLF.ConfigCommon.CreateToggle({
		name = G_RLF.L["Enable Row Borders"],
		desc = G_RLF.L["EnableRowBordersDesc"],
		get = "GetRowBordersEnabled",
		set = "SetRowBordersEnabled",
		width = "double",
		order = 1,
	})
end

---@private
function StylingBase.CreateBorderTextureSelect()
	return G_RLF.ConfigCommon.CreateSelect({
		name = G_RLF.L["Border Texture"],
		desc = G_RLF.L["BorderTextureDesc"],
		dialogControl = "LSM30_Border",
		values = function()
			return lsm:HashTable(lsm.MediaType.BORDER)
		end,
		disabled = "IsRowBorderDisabled",
		get = "GetRowBorderTexture",
		set = "SetRowBorderTexture",
		width = "double",
		order = 2,
	})
end

---@private
function StylingBase.CreateBorderThicknessRange()
	return G_RLF.ConfigCommon.CreateRange({
		name = G_RLF.L["Row Border Thickness"],
		desc = G_RLF.L["RowBorderThicknessDesc"],
		disabled = "IsRowBorderDisabled",
		get = "GetRowBorderThickness",
		set = "SetRowBorderThickness",
		min = 0.5,
		softMin = 1,
		max = 24,
		bigStep = 1,
		width = "double",
		order = 3,
	})
end

---@private
function StylingBase.CreateBorderColor()
	return G_RLF.ConfigCommon.CreateColor({
		name = G_RLF.L["Row Border Color"],
		desc = G_RLF.L["RowBorderColorDesc"],
		disabled = "IsRowBorderDisabled",
		get = "GetRowBorderColor",
		set = "SetRowBorderColor",
		hasAlpha = true,
		order = 4,
	})
end

---@private
function StylingBase.CreateBorderClassColorToggle()
	return G_RLF.ConfigCommon.CreateToggle({
		name = G_RLF.L["Use Class Colors for Borders"],
		desc = G_RLF.L["UseClassColorsForBordersDesc"],
		disabled = "IsRowBorderDisabled",
		get = "GetRowBorderClassColors",
		set = "SetRowBorderClassColors",
		width = 1.5,
		order = 5,
	})
end

---@private
function StylingBase.CreateRowBordersGroup()
	local group = G_RLF.ConfigCommon.CreateGroup({
		name = G_RLF.L["Row Borders"],
		desc = G_RLF.L["RowBordersDesc"],
		inline = true,
		order = 4,
	})
	group.args.rowBordersEnabled = StylingBase.CreateBorderEnableToggle()
	group.args.rowBorderTexture = StylingBase.CreateBorderTextureSelect()
	group.args.rowBorderThickness = StylingBase.CreateBorderThicknessRange()
	group.args.rowBorderColor = StylingBase.CreateBorderColor()
	group.args.rowBorderClassColors = StylingBase.CreateBorderClassColorToggle()

	return group
end

--- Labels for the icon skin dropdown.  Addon names are proper nouns and stay
--- untranslated; only the built-in modes and the unavailable suffix are
--- localized.
---@private
function StylingBase.IconSkinLabels()
	return {
		[G_RLF.IconSkin.AUTO] = G_RLF.L["Automatic"],
		[G_RLF.IconSkin.NONE] = G_RLF.L["None"],
		[G_RLF.IconSkin.SQUARE] = G_RLF.L["Square"],
		[G_RLF.IconSkin.MASQUE] = "Masque",
		[G_RLF.IconSkin.ELVUI] = "ElvUI",
		[G_RLF.IconSkin.ELLESMERE] = "EllesmereUI",
	}
end

---@private
function StylingBase.CreateIconSkinSelect()
	return G_RLF.ConfigCommon.CreateSelect({
		name = G_RLF.L["Icon Skin"],
		desc = G_RLF.L["IconSkinDesc"],
		-- Every skinner is listed whether or not it is installed, so the
		-- feature is discoverable.  AceConfigDialog has no per-item disable
		-- for selects, so unavailable entries are labeled and refused by
		-- SetIconSkin instead of being grayed out.
		values = function()
			local available = G_RLF.IconSkinResolver:Available()
			local values = {}
			for key, label in pairs(StylingBase.IconSkinLabels()) do
				values[key] = available[key] and label or (label .. G_RLF.L["NotInstalledSuffix"])
			end
			return values
		end,
		sorting = function()
			return {
				G_RLF.IconSkin.AUTO,
				G_RLF.IconSkin.NONE,
				G_RLF.IconSkin.SQUARE,
				G_RLF.IconSkin.MASQUE,
				G_RLF.IconSkin.ELVUI,
				G_RLF.IconSkin.ELLESMERE,
			}
		end,
		get = "GetIconSkin",
		set = "SetIconSkin",
		width = "double",
		order = 4.5,
	})
end

---@private
function StylingBase.CreateEnableSecondaryRowTextToggle()
	return G_RLF.ConfigCommon.CreateToggle({
		name = G_RLF.L["Enable Secondary Row Text"],
		desc = G_RLF.L["EnableSecondaryRowTextDesc"],
		get = "GetEnabledSecondaryRowText",
		set = "SetEnabledSecondaryRowText",
		width = "double",
		order = 2.5,
	})
end

---@private
function StylingBase.CreateEnableTopLeftIconTextToggle()
	return G_RLF.ConfigCommon.CreateToggle({
		name = G_RLF.L["Enable Top Left Icon Text"],
		desc = G_RLF.L["EnableTopLeftIconTextDesc"],
		get = "GetEnableTopLeftIconText",
		set = "SetEnableTopLeftIconText",
		width = "double",
		order = 0.1,
	})
end

---@private
function StylingBase.CreateTopLeftIconFontSizeRange()
	return G_RLF.ConfigCommon.CreateRange({
		name = G_RLF.L["Top Left Icon Font Size"],
		desc = G_RLF.L["TopLeftIconFontSizeDesc"],
		disabled = "IsTopLeftIconTextDisabled",
		get = "GetTopLeftIconFontSize",
		set = "SetTopLeftIconFontSize",
		min = 1,
		softMin = 6,
		softMax = 24,
		max = 72,
		bigStep = 1,
		width = "double",
		order = 1,
	})
end

---@private
function StylingBase.CreateTopLeftIconTextUseQualityColorToggle()
	return G_RLF.ConfigCommon.CreateToggle({
		name = G_RLF.L["Use Quality Color"],
		desc = G_RLF.L["UseQualityColorDesc"],
		disabled = "IsTopLeftIconTextDisabled",
		get = "GetTopLeftIconTextUseQualityColor",
		set = "SetTopLeftIconTextUseQualityColor",
		width = 1.75,
		order = 2,
	})
end

---@private
function StylingBase.CreateTopLeftIconTextColor()
	return G_RLF.ConfigCommon.CreateColor({
		name = G_RLF.L["Top Left Icon Text Color"],
		desc = G_RLF.L["TopLeftIconTextColorDesc"],
		disabled = "IsTopLeftIconTextColorDisabled",
		get = "GetTopLeftIconTextColor",
		set = "SetTopLeftIconTextColor",
		hasAlpha = true,
		width = 1.75,
		order = 3,
	})
end

---@private
function StylingBase.CreateTopLeftIconTextOptionsGroup()
	local group = G_RLF.ConfigCommon.CreateGroup({
		name = G_RLF.L["Top Left Icon Text Options"],
		inline = true,
		order = 6,
	})
	group.args.enableTopLeftIconText = StylingBase.CreateEnableTopLeftIconTextToggle()
	group.args.topLeftIconFontSize = StylingBase.CreateTopLeftIconFontSizeRange()
	group.args.topLeftIconTextUseQualityColor = StylingBase.CreateTopLeftIconTextUseQualityColorToggle()
	group.args.topLeftIconTextColor = StylingBase.CreateTopLeftIconTextColor()

	return group
end

---@private
function StylingBase.CreateUseFontObjectsToggle()
	return G_RLF.ConfigCommon.CreateToggle({
		name = G_RLF.L["Use Font Objects"],
		desc = G_RLF.L["UseFontObjectsDesc"],
		get = "GetUseFontObjects",
		set = "SetUseFontObjects",
		width = "double",
		order = 7,
	})
end

---@private
function StylingBase.CreateFontObjectSelect()
	return G_RLF.ConfigCommon.CreateSelect({
		name = G_RLF.L["Font"],
		desc = G_RLF.L["FontDesc"],
		values = function()
			local fonts = _G.GetFonts()
			local allFonts = {}
			for k, v in pairs(fonts) do
				if type(v) == "string" then
					if startswith(v, "table") then
					-- Skip
					else
						allFonts[v] = v
					end
				end
			end
			return allFonts
		end,
		disabled = "IsFontObjectsDisabled",
		get = "GetFontObject",
		set = "SetFontObject",
		width = "double",
		order = 8,
	})
end

---@private
function StylingBase.CreateFontFaceSelect()
	return G_RLF.ConfigCommon.CreateSelect({
		name = G_RLF.L["Font Face"],
		desc = G_RLF.L["FontFaceDesc"],
		dialogControl = "LSM30_Font",
		values = function()
			return lsm:HashTable(lsm.MediaType.FONT)
		end,
		get = "GetFontFace",
		set = "SetFontFace",
		width = "double",
		order = 1,
	})
end

---@private
function StylingBase.CreateFontSizeRange(name, desc, get, set, order)
	return G_RLF.ConfigCommon.CreateRange({
		name = name,
		desc = desc,
		get = get,
		set = set,
		min = 1,
		softMin = 6,
		softMax = 24,
		max = 72,
		bigStep = 1,
		width = 1.5,
		order = order,
	})
end

---@private
function StylingBase.CreatePrimaryFontSizeRange()
	return StylingBase.CreateFontSizeRange(
		G_RLF.L["Font Size"],
		G_RLF.L["FontSizeDesc"],
		"GetFontSize",
		"SetFontSize",
		2
	)
end

---@private
function StylingBase.CreateSecondaryFontSizeRange()
	local secondaryFontSizeRange = StylingBase.CreateFontSizeRange(
		G_RLF.L["Secondary Font Size"],
		G_RLF.L["SecondaryFontSizeDesc"],
		"GetSecondaryFontSize",
		"SetSecondaryFontSize",
		3
	)
	secondaryFontSizeRange.disabled = "IsSecondaryFontSizeDisabled"

	return secondaryFontSizeRange
end

---@private
function StylingBase.CreateFontFlagsMultiSelect()
	return G_RLF.ConfigCommon.CreateMultiSelect({
		name = G_RLF.L["Font Flags"],
		desc = G_RLF.L["FontFlagsDesc"],
		values = {
			[G_RLF.FontFlags.NONE] = G_RLF.L["None"],
			[G_RLF.FontFlags.OUTLINE] = G_RLF.L["Outline"],
			[G_RLF.FontFlags.THICKOUTLINE] = G_RLF.L["Thick Outline"],
			[G_RLF.FontFlags.MONOCHROME] = G_RLF.L["Monochrome"],
		},
		get = "GetFontFlags",
		set = "SetFontFlags",
		width = "double",
		order = 4,
	})
end

---@private
function StylingBase.CreateFontShadowColor()
	return G_RLF.ConfigCommon.CreateColor({
		name = G_RLF.L["Shadow Color"],
		desc = G_RLF.L["ShadowColorDesc"],
		get = "GetShadowColor",
		set = "SetShadowColor",
		hasAlpha = true,
		width = "double",
		order = 5,
	})
end

---@private
function StylingBase.CreateShadowHelpDescription()
	return G_RLF.ConfigCommon.CreateDescription({
		name = G_RLF.L["ShadowOffsetHelp"],
		width = "full",
		order = 5.1,
	})
end

---@private
function StylingBase.CreateShadowOffset(name, desc, get, set, order)
	return G_RLF.ConfigCommon.CreateRange({
		name = name,
		desc = desc,
		get = get,
		set = set,
		min = -10,
		max = 10,
		bigStep = 1,
		width = 1.75,
		order = order,
	})
end

---@private
function StylingBase.CreateFontShadowOffsetXRange()
	return StylingBase.CreateShadowOffset(
		G_RLF.L["Shadow Offset X"],
		G_RLF.L["ShadowOffsetXDesc"],
		"GetShadowOffsetX",
		"SetShadowOffsetX",
		6
	)
end

---@private
function StylingBase.CreateFontShadowOffsetYRange()
	return StylingBase.CreateShadowOffset(
		G_RLF.L["Shadow Offset Y"],
		G_RLF.L["ShadowOffsetYDesc"],
		"GetShadowOffsetY",
		"SetShadowOffsetY",
		7
	)
end

---@private
function StylingBase.CreateRowTextSpacingRange()
	return G_RLF.ConfigCommon.CreateRange({
		name = G_RLF.L["Row Text Spacing"],
		desc = G_RLF.L["RowTextSpacingDesc"],
		get = "GetRowTextSpacing",
		set = "SetRowTextSpacing",
		min = 0,
		softMax = 20,
		max = 40,
		bigStep = 1,
		width = "double",
		order = 0,
	})
end

---@private
function StylingBase.CreateCustomFontsGroup()
	local group = G_RLF.ConfigCommon.CreateGroup({
		name = G_RLF.L["Custom Fonts"],
		desc = G_RLF.L["CustomFontsDesc"],
		disabled = "IsCustomFontsDisabled",
		inline = true,
		order = 9,
	})
	group.args.font = StylingBase.CreateFontFaceSelect()
	group.args.fontSize = StylingBase.CreatePrimaryFontSizeRange()
	group.args.enableSecondaryRowText = StylingBase.CreateEnableSecondaryRowTextToggle()
	group.args.secondaryFontSize = StylingBase.CreateSecondaryFontSizeRange()
	group.args.fontFlags = StylingBase.CreateFontFlagsMultiSelect()
	group.args.shadowColor = StylingBase.CreateFontShadowColor()
	group.args.shadowHelp = StylingBase.CreateShadowHelpDescription()
	group.args.shadowOffsetX = StylingBase.CreateFontShadowOffsetXRange()
	group.args.shadowOffsetY = StylingBase.CreateFontShadowOffsetYRange()
	group.args.rowTextSpacing = StylingBase.CreateRowTextSpacingRange()

	return group
end

---@param handler RLF_StylingConfigHandlerBase
---@param order number
function StylingBase.CreateStylingGroup(handler, order)
	local group = G_RLF.ConfigCommon.CreateGroup({
		name = G_RLF.L["Styling"],
		desc = G_RLF.L["StylingDesc"],
		handler = handler,
		order = order,
	})
	group.args.flow = StylingBase.CreateFlowGroup(handler)
	group.args.background = StylingBase.CreateBackgroundGroup()
	group.args.rowBorders = StylingBase.CreateRowBordersGroup()
	group.args.iconSkin = StylingBase.CreateIconSkinSelect()
	group.args.topLeftIconTextOptions = StylingBase.CreateTopLeftIconTextOptionsGroup()
	group.args.useFontObjects = StylingBase.CreateUseFontObjectsToggle()
	group.args.font = StylingBase.CreateFontObjectSelect()
	group.args.customFonts = StylingBase.CreateCustomFontsGroup()
	return group
end

G_RLF.ConfigCommon.StylingBase = StylingBase

return StylingBase
