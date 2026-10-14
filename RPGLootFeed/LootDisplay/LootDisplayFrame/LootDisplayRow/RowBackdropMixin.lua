---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_RowBackdropMixin: BackdropTemplateMixin
RLF_RowBackdropMixin = {}

local FALLBACK_BACKGROUND_TEXTURE = "Interface/Buttons/WHITE8X8"

local featureKeyForType = {
	[G_RLF.FeatureModule.ItemLoot] = "itemLoot",
	[G_RLF.FeatureModule.PartyLoot] = "partyLoot",
	[G_RLF.FeatureModule.Currency] = "currency",
	[G_RLF.FeatureModule.Money] = "money",
	[G_RLF.FeatureModule.Experience] = "experience",
	[G_RLF.FeatureModule.Reputation] = "reputation",
	[G_RLF.FeatureModule.Profession] = "profession",
	[G_RLF.FeatureModule.TravelPoints] = "travelPoints",
	[G_RLF.FeatureModule.Transmog] = "transmog",
}

--- Resolve the row's effective background colors.
--- Uses frame styling as the baseline, then applies per-feature override
--- colors when enabled for the row's feature type.
---@param row RLF_LootDisplayRow
---@param stylingDb RLF_ConfigStyling
---@return number[] gradientStart
---@return number[] gradientEnd
---@return number[] textureColor
---@return string|nil featureKey
local function resolveBackgroundColors(row, stylingDb)
	local gradientStart = stylingDb.rowBackgroundGradientStart
	local gradientEnd = stylingDb.rowBackgroundGradientEnd
	local textureColor = stylingDb.rowBackgroundTextureColor

	local featureKey = featureKeyForType[row.type]
	if not featureKey then
		return gradientStart, gradientEnd, textureColor, nil
	end

	local featureCfg = G_RLF.DbAccessor:Feature(row.frameType, featureKey)
	local backgroundOverride = featureCfg and featureCfg.backgroundOverride
	if not backgroundOverride or not backgroundOverride.enabled then
		return gradientStart, gradientEnd, textureColor, featureKey
	end

	if backgroundOverride.gradientStart then
		gradientStart = backgroundOverride.gradientStart
	end
	if backgroundOverride.gradientEnd then
		gradientEnd = backgroundOverride.gradientEnd
	end
	if backgroundOverride.textureColor then
		textureColor = backgroundOverride.textureColor
	end

	return gradientStart, gradientEnd, textureColor, featureKey
end

function RLF_RowBackdropMixin:StyleBackground()
	local stylingDb = G_RLF.DbAccessor:Styling(self.frameType)

	if stylingDb.rowBackgroundType ~= G_RLF.RowBackground.GRADIENT then
		self.Background:Hide()
		-- Invalidate gradient cache so a future switch back to GRADIENT
		-- re-applies the gradient colors instead of hitting the cache.
		self.cachedGradientStart = nil
		self.cachedGradientEnd = nil
		self.cachedBackgroundFeatureKey = nil
		return
	else
		self.Background:Show()
		if self.Center then
			self.Center:Hide()
		end
	end

	local changed = false

	local insets = stylingDb.backdropInsets
	local topInset = insets.top or 0
	local rightInset = insets.right or 0
	local bottomInset = insets.bottom or 0
	local leftInset = insets.left or 0
	local gradientStart, gradientEnd, _, featureKey = resolveBackgroundColors(self, stylingDb)
	local textAlignment = stylingDb.textAlignment
	local iconOnLeft = textAlignment ~= G_RLF.TextAlignment.RIGHT

	if
		self.cachedGradientStart ~= gradientStart
		or self.cachedGradientEnd ~= gradientEnd
		or self.cachedBackgroundFeatureKey ~= featureKey
		or self.cachedBackgroundTextAlignment ~= textAlignment
		or self.cachedTopInset ~= topInset
		or self.cachedRightInset ~= rightInset
		or self.cachedBottomInset ~= bottomInset
		or self.cachedLeftInset ~= leftInset
	then
		self.cachedGradientStart = gradientStart
		self.cachedGradientEnd = gradientEnd
		self.cachedBackgroundFeatureKey = featureKey
		self.cachedBackgroundTextAlignment = textAlignment
		self.cachedTopInset = topInset
		self.cachedRightInset = rightInset
		self.cachedBottomInset = bottomInset
		self.cachedLeftInset = leftInset
		changed = true
	end

	if changed then
		local leftColor = CreateColor(unpack(gradientStart))
		local rightColor = CreateColor(unpack(gradientEnd))
		if not iconOnLeft then
			leftColor, rightColor = rightColor, leftColor
		end
		self.Background:SetGradient("HORIZONTAL", leftColor, rightColor)

		if topInset ~= 0 or rightInset ~= 0 or bottomInset ~= 0 or leftInset ~= 0 then
			self.Background:ClearAllPoints()
			self.Background:SetPoint("TOPLEFT", self, "TOPLEFT", leftInset, -topInset)
			self.Background:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -rightInset, bottomInset)
		end
	end
end

function RLF_RowBackdropMixin:StyleRowBackdrop()
	---@type RLF_ConfigStyling
	local stylingDb = G_RLF.DbAccessor:Styling(self.frameType)
	local enableRowBorder = stylingDb.enableRowBorder
	local enableTexturedBackground = stylingDb.rowBackgroundType == G_RLF.RowBackground.TEXTURED
	if
		(not enableRowBorder or stylingDb.rowBorderTexture == "None")
		and (not enableTexturedBackground or stylingDb.rowBackgroundTexture == "None")
	then
		self:ClearBackdrop()
		-- Invalidate backdrop cache so a future switch back to TEXTURED
		-- re-applies the backdrop instead of hitting stale cache.
		self.cachedBackdropTexture = nil
		self.cachedBorderTexture = nil
		self.cachedBackdropFeatureKey = nil
		return
	end

	local borderSize = stylingDb.rowBorderSize
	local classColors = stylingDb.rowBorderClassColors
	local borderColor = stylingDb.rowBorderColor
	local borderTexture = enableRowBorder and stylingDb.rowBorderTexture or "None"
	local backdropTexture = enableTexturedBackground and stylingDb.rowBackgroundTexture or "None"
	local _, _, textureColor, featureKey = resolveBackgroundColors(self, stylingDb)
	local backdropColorR = textureColor[1]
	local backdropColorG = textureColor[2]
	local backdropColorB = textureColor[3]
	local backdropColorA = textureColor[4] or 1
	local topInset = stylingDb.backdropInsets.top or 0
	local rightInset = stylingDb.backdropInsets.right or 0
	local bottomInset = stylingDb.backdropInsets.bottom or 0
	local leftInset = stylingDb.backdropInsets.left or 0
	local needsUpdate = false

	if
		self.cachedBorderSize ~= borderSize
		or self.cacheBorderColor ~= borderColor
		or self.cacheClassColors ~= classColors
		or self.cachedBorderTexture ~= borderTexture
		or self.cachedBackdropTexture ~= backdropTexture
		or self.cachedBackdropFeatureKey ~= featureKey
		or self.cachedBackdropColorR ~= backdropColorR
		or self.cachedBackdropColorG ~= backdropColorG
		or self.cachedBackdropColorB ~= backdropColorB
		or self.cachedBackdropColorA ~= backdropColorA
		or self.cachedBackdropTopInset ~= topInset
		or self.cachedBackdropRightInset ~= rightInset
		or self.cachedBackdropBottomInset ~= bottomInset
		or self.cachedBackdropLeftInset ~= leftInset
	then
		self.cachedBorderSize = borderSize
		self.cacheBorderColor = borderColor
		self.cacheClassColors = classColors
		self.cachedBorderTexture = borderTexture
		self.cachedBackdropTexture = backdropTexture
		self.cachedBackdropFeatureKey = featureKey
		self.cachedBackdropColorR = backdropColorR
		self.cachedBackdropColorG = backdropColorG
		self.cachedBackdropColorB = backdropColorB
		self.cachedBackdropColorA = backdropColorA
		self.cachedBackdropTopInset = topInset
		self.cachedBackdropRightInset = rightInset
		self.cachedBackdropBottomInset = bottomInset
		self.cachedBackdropLeftInset = leftInset
		borderSize = G_RLF.PerfPixel.PScale(borderSize)
		topInset = G_RLF.PerfPixel.PScale(topInset)
		rightInset = G_RLF.PerfPixel.PScale(rightInset)
		bottomInset = G_RLF.PerfPixel.PScale(bottomInset)
		leftInset = G_RLF.PerfPixel.PScale(leftInset)
		needsUpdate = true
	end

	if not needsUpdate then
		return
	end

	-- Use textured borders via backdrop
	local lsm = G_RLF.lsm

	---@type backdropInfo
	local backdrop = {}

	if borderTexture ~= "None" then
		local texturePath = lsm:Fetch(lsm.MediaType.BORDER, borderTexture)

		if texturePath == nil or texturePath == "" then
			G_RLF:LogWarn("Could not find a texture path in LSM for border texture: %s", borderTexture)
		else
			backdrop.edgeFile = texturePath
			backdrop.edgeSize = borderSize
		end
	end

	if backdropTexture ~= "None" then
		local texturePath = lsm:Fetch(lsm.MediaType.BACKGROUND, backdropTexture)

		if texturePath == nil or texturePath == "" then
			G_RLF:LogWarn("Could not find a texture path in LSM for backdrop texture: %s", backdropTexture)
		else
			backdrop.bgFile = texturePath
			backdrop.insets = {
				left = leftInset,
				right = rightInset,
				top = topInset,
				bottom = bottomInset,
			}
		end
	else
		backdrop.bgFile = FALLBACK_BACKGROUND_TEXTURE
	end

	self:SetBackdrop(backdrop)

	if backdropTexture ~= "None" then
		self:SetBackdropColor(backdropColorR or 0, backdropColorG or 0, backdropColorB or 0, backdropColorA or 1)
		-- Re-show the Center piece in case it was hidden by a previous ClearBackdrop
		-- cycle (we explicitly Hide() it in GRADIENT mode).
		if self.Center then
			self.Center:Show()
		end
	else
		self:SetBackdropColor(0, 0, 0, 0) -- Transparent background
		-- Keep the gradient texture visible when gradient mode is active.
		-- This branch also runs for border-only backdrops where bgFile is the
		-- transparent fallback, and hiding Background there would remove the row
		-- background entirely.
		if self.Background and stylingDb.rowBackgroundType ~= G_RLF.RowBackground.GRADIENT then
			self.Background:Hide()
		end
	end

	-- Apply coloring to textured border
	if classColors then
		local classColor
		local a = 1
		local _, classFile = UnitClass(self.unit or "player")
		if GetExpansionLevel() >= G_RLF.Expansion.BFA then
			classColor = C_ClassColor.GetClassColor(classFile)
		else
			classColor = RAID_CLASS_COLORS[classFile]
		end
		if classColor == nil then
			G_RLF:LogWarn("Could not find a class color for unit: %s", self.unit or "player")
			-- Fallback to transparent black
			classColor = { r = 0, g = 0, b = 0 }
			a = 0
		end
		self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, a)
	else
		local r, g, b, a = unpack(borderColor)
		self:SetBackdropBorderColor(r, g, b, a or 1)
	end
end

G_RLF.RLF_RowBackdropMixin = RLF_RowBackdropMixin
