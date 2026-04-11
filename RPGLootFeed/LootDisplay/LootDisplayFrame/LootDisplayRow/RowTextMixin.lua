---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_RowFontString: FontString
---@field elementFadeIn Alpha

--- Describes a real Texture child to be shown alongside secondary text.
--- Used by feature modules to avoid |T|/|A| markup in FontStrings, which
--- does not receive Translation offsets and causes animation jank.
---@class RLF_SecondaryInlineTexture
---@field atlas string          Atlas name (e.g. "coin-gold", "reputation-paragon")
---@field size number           Square pixel size
---@field placement "prefix"   Where to place it relative to the coin display or text

---@class RLF_RowTextMixin
RLF_RowTextMixin = {}

local defaultColor = { 1, 1, 1, 1 }

-- Atlas names for coin denominations (confirmed from Blizzard's MoneyFrame)
local COIN_ATLAS = {
	gold = "coin-gold",
	silver = "coin-silver",
	copper = "coin-copper",
}
local DENOM_ORDER = { "gold", "silver", "copper" }

--- Create the PrimaryLineLayout horizontal layout container that holds
--- PrimaryText and ItemCountText as layout children.
--- Must be called once during row frame initialisation (from Init()).
function RLF_RowTextMixin:CreatePrimaryLineLayout()
	-- Guard: the layout frame and its children persist on the pooled frame across
	-- Acquire/Release cycles, exactly like the XML-defined PrimaryText/ItemCountText.
	-- Only create once per physical frame object.
	if self.PrimaryLineLayout then
		return
	end

	local layout = CreateFrame("Frame", nil, self)
	-- Both mixins are required:
	--   LayoutMixin        → provides Layout(), GetLayoutChildren(), CalculateFrameSize()
	--   HorizontalLayoutMixin → provides LayoutChildren() (horizontal positioning)
	-- This mirrors the XML template: mixin="LayoutMixin, HorizontalLayoutMixin"
	Mixin(layout, LayoutMixin, HorizontalLayoutMixin)
	layout.spacing = 0 -- updated in StyleText() once iconSize is known

	-- PrimaryText is re-parented from the row into the layout container.
	self.PrimaryText:SetParent(layout)
	self.PrimaryText.layoutIndex = 1
	-- SetWordWrap(false) once here so the engine truncates with "..." rather than
	-- wrapping.  Not repeated in the hot-path LayoutPrimaryLine().
	self.PrimaryText:SetWordWrap(false)

	-- CoinDisplay sits at layoutIndex=2.  It contains denomination sub-frames
	-- (gold, silver, copper), each with a real Texture icon and a FontString amount.
	-- Real Texture children travel correctly with Translation animations, unlike
	-- |T|/|A| markup baked into a FontString.  Hidden by default; only money rows
	-- call UpdateCoinDisplay() to populate and show it.
	-- NOTE: CreateCoinDisplay() is called lazily from UpdateCoinDisplay().

	-- AmountText holds the quantity suffix (e.g. "x2") as a separate non-truncatable
	-- FontString at layoutIndex=3 (was 2; shifted up to make room for CoinDisplay).
	-- Hidden by default; shown by ShowAmountText().
	-- Inherits "GameFontNormal" so the engine never throws "Font not set" when
	-- SetText/Hide are called before StyleText() runs (e.g. in Reset()).
	local amountText = layout:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	amountText.layoutIndex = 3
	amountText:SetWordWrap(false)
	amountText:Hide()
	self.AmountText = amountText

	-- ItemCountText at layoutIndex=4 (was 3; shifted up to make room for CoinDisplay).
	self.ItemCountText:SetParent(layout)
	self.ItemCountText.layoutIndex = 4

	self.PrimaryLineLayout = layout
end

--- Create the SecondaryLineLayout horizontal layout container that holds
--- SecondaryText (and future secondary-line children) as layout children.
--- Must be called once during row frame initialisation (from Init()).
function RLF_RowTextMixin:CreateSecondaryLineLayout()
	-- Guard: same pool-idempotency pattern as CreatePrimaryLineLayout().
	if self.SecondaryLineLayout then
		return
	end

	local layout = CreateFrame("Frame", nil, self)
	Mixin(layout, LayoutMixin, HorizontalLayoutMixin)
	layout.spacing = 0 -- updated in StyleText() once iconSize is known

	-- SecondaryText is re-parented from the row into the layout container.
	-- SetWordWrap(false) so the engine truncates with "..." rather than wrapping.
	self.SecondaryText:SetParent(layout)
	self.SecondaryText.layoutIndex = 1
	self.SecondaryText:SetWordWrap(false)

	layout:Hide()
	self.SecondaryLineLayout = layout
end

local function ApplyFontStyle(
	fontString,
	fontPath,
	fontSize,
	fontFlagsString,
	fontShadowColor,
	fontShadowOffsetX,
	fontShadowOffsetY
)
	fontString:SetFont(fontPath, fontSize, fontFlagsString)
	fontString:SetShadowColor(
		fontShadowColor[1] or 0,
		fontShadowColor[2] or 0,
		fontShadowColor[3] or 0,
		fontShadowColor[4] or 1
	)
	fontString:SetShadowOffset(fontShadowOffsetX or 1, fontShadowOffsetY or -1)
end

--- Setup font styling for top left text
--- @param stylingDb? RLF_ConfigStyling
function RLF_RowTextMixin:StyleTopLeftText(stylingDb)
	---@type RLF_ConfigStyling
	local stylingDb = stylingDb or G_RLF.DbAccessor:Styling(self.frameType)
	local fontFace = stylingDb.fontFace
	local useFontObjects = stylingDb.useFontObjects
	local font = stylingDb.font
	local fontFlagsString = G_RLF:FontFlagsToString()
	local fontShadowColor = stylingDb.fontShadowColor
	local fontShadowOffsetX = stylingDb.fontShadowOffsetX
	local fontShadowOffsetY = stylingDb.fontShadowOffsetY
	local topLeftIconFontSize = stylingDb.topLeftIconFontSize

	if useFontObjects then
		self.Icon.topLeftText:SetFontObject(font)
	else
		local fontPath = G_RLF.lsm:Fetch(G_RLF.lsm.MediaType.FONT, fontFace)
		ApplyFontStyle(
			self.Icon.topLeftText,
			fontPath,
			topLeftIconFontSize,
			fontFlagsString,
			fontShadowColor,
			fontShadowOffsetX,
			fontShadowOffsetY
		)
	end
end

function RLF_RowTextMixin:StyleText()
	local fontChanged = false

	---@type RLF_ConfigStyling
	local stylingDb = G_RLF.DbAccessor:Styling(self.frameType)
	local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)
	local fontFace = stylingDb.fontFace
	local useFontObjects = stylingDb.useFontObjects
	local font = stylingDb.font
	local fontSize = stylingDb.fontSize
	local fontFlagsString = G_RLF:FontFlagsToString()
	local fontShadowColor = stylingDb.fontShadowColor
	local fontShadowOffsetX = stylingDb.fontShadowOffsetX
	local fontShadowOffsetY = stylingDb.fontShadowOffsetY
	local secondaryFontSize = stylingDb.secondaryFontSize
	local topLeftIconFontSize = stylingDb.topLeftIconFontSize

	if
		self.cachedFontFace ~= fontFace
		or self.cachedFontSize ~= fontSize
		or self.cachedSecondaryFontSize ~= secondaryFontSize
		or self.cachedTopLeftIconFontSize ~= topLeftIconFontSize
		or self.cachedFontFlags ~= fontFlagsString
		or self.cachedUseFontObject ~= useFontObjects
		or self.cachedFontShadowColor ~= fontShadowColor
		or self.cachedFontShadowOffsetX ~= fontShadowOffsetX
		or self.cachedFontShadowOffsetY ~= fontShadowOffsetY
	then
		self.cachedUseFontObject = useFontObjects
		self.cachedFontFace = fontFace
		self.cachedFontSize = fontSize
		self.cachedSecondaryFontSize = secondaryFontSize
		self.cachedTopLeftIconFontSize = topLeftIconFontSize
		self.cachedFontFlags = fontFlagsString
		self.cachedFontShadowColor = fontShadowColor
		self.cachedFontShadowOffsetX = fontShadowOffsetX
		self.cachedFontShadowOffsetY = fontShadowOffsetY
		fontChanged = true
	end

	if fontChanged then
		if useFontObjects or not fontFace then
			self.PrimaryText:SetFontObject(font)
			self.AmountText:SetFontObject(font)
			self.ItemCountText:SetFontObject(font)
			self.SecondaryText:SetFontObject(font)
			self.Icon.topLeftText:SetFontObject(font)
		else
			local fontPath = G_RLF.lsm:Fetch(G_RLF.lsm.MediaType.FONT, fontFace)
			ApplyFontStyle(
				self.PrimaryText,
				fontPath,
				fontSize,
				fontFlagsString,
				fontShadowColor,
				fontShadowOffsetX,
				fontShadowOffsetY
			)
			ApplyFontStyle(
				self.AmountText,
				fontPath,
				fontSize,
				fontFlagsString,
				fontShadowColor,
				fontShadowOffsetX,
				fontShadowOffsetY
			)
			ApplyFontStyle(
				self.ItemCountText,
				fontPath,
				fontSize,
				fontFlagsString,
				fontShadowColor,
				fontShadowOffsetX,
				fontShadowOffsetY
			)
			ApplyFontStyle(
				self.SecondaryText,
				fontPath,
				secondaryFontSize,
				fontFlagsString,
				fontShadowColor,
				fontShadowOffsetX,
				fontShadowOffsetY
			)
			self:CreateTopLeftText()
		end
	end

	local textAlignment = stylingDb.textAlignment
	local iconOnLeft = textAlignment ~= G_RLF.TextAlignment.RIGHT
	local padding = sizingDb.padding
	local iconSize = sizingDb.iconSize
	local enabledSecondaryRowText = stylingDb.enabledSecondaryRowText

	-- Compute inter-child spacing before the cache block so the check can compare
	-- against the new value. 0 = auto (scales with icon size: iconSize/4).
	local rowTextSpacingCfg = stylingDb.rowTextSpacing or 0
	local spacing = (rowTextSpacingCfg == 0) and (iconSize / 4) or rowTextSpacingCfg

	if
		self.cachedRowTextAlignment ~= textAlignment
		or self.cachedRowTextXOffset ~= spacing
		or self.cachedRowTextIcon ~= self.icon
		or self.cachedEnabledSecondaryText ~= enabledSecondaryRowText
		or self.cachedSecondaryText ~= self.secondaryText
		or self.cachedUnitText ~= self.unit
		or self.cachedPaddingText ~= padding
	then
		self.cachedRowTextAlignment = textAlignment
		self.cachedRowTextXOffset = spacing
		self.cachedRowTextIcon = self.icon
		self.cachedEnabledSecondaryText = enabledSecondaryRowText
		self.cachedSecondaryText = self.secondaryText
		self.cachedUnitText = self.unit
		self.cachedPaddingText = padding

		local anchor = "LEFT"
		local iconAnchor = "RIGHT"
		local xOffset = spacing
		if not iconOnLeft then
			anchor = "RIGHT"
			iconAnchor = "LEFT"
			xOffset = xOffset * -1
		end
		-- PrimaryLineLayout owns the anchor to Icon; its children (PrimaryText,
		-- AmountText, ItemCountText) are positioned by Layout(). The spacing is
		-- user-configurable via rowTextSpacing (0 = auto = iconSize/4).
		-- childLayoutDirection reverses child order for right-align (icon on right)
		-- without changing layoutIndex values.
		self.PrimaryLineLayout.spacing = spacing
		self.SecondaryLineLayout.spacing = spacing
		if iconOnLeft then
			self.PrimaryLineLayout.childLayoutDirection = nil
			self.SecondaryLineLayout.childLayoutDirection = nil
		else
			self.PrimaryLineLayout.childLayoutDirection = "rightToLeft"
			self.SecondaryLineLayout.childLayoutDirection = "rightToLeft"
		end
		self.PrimaryLineLayout:ClearAllPoints()
		self.PrimaryText:SetJustifyH(anchor)
		if self.icon then
			local partyConfig = G_RLF.DbAccessor:Feature(self.frameType, "partyLoot") or {}
			if self.unit and partyConfig.enablePartyAvatar then
				self.PrimaryLineLayout:SetPoint(anchor, self.UnitPortrait, iconAnchor, xOffset, 0)
			else
				self.PrimaryLineLayout:SetPoint(anchor, self.Icon, iconAnchor, xOffset, 0)
			end
		else
			self.PrimaryLineLayout:SetPoint(anchor, self.Icon, anchor, 0, 0)
		end

		if enabledSecondaryRowText and self.secondaryText ~= nil and self.secondaryText ~= "" then
			self.SecondaryLineLayout:ClearAllPoints()
			self.SecondaryText:SetJustifyH(anchor)
			if self.icon then
				if self.unit then
					local partyConfig = G_RLF.DbAccessor:Feature(self.frameType, "partyLoot") or {}
					if partyConfig.enablePartyAvatar then
						self.SecondaryLineLayout:SetPoint(anchor, self.UnitPortrait, iconAnchor, xOffset, 0)
					else
						self.SecondaryLineLayout:SetPoint(anchor, self.Icon, iconAnchor, xOffset, 0)
					end
					if self.elementSecondaryTextColor then
						self.SecondaryText:SetTextColor(
							self.elementSecondaryTextColor.r,
							self.elementSecondaryTextColor.g,
							self.elementSecondaryTextColor.b,
							1
						)
					end
				else
					self.SecondaryLineLayout:SetPoint(anchor, self.Icon, iconAnchor, xOffset, 0)
				end
			else
				self.SecondaryLineLayout:SetPoint(anchor, self.Icon, anchor, 0, 0)
			end
			-- Vertical split: PrimaryLineLayout takes the top slot;
			-- SecondaryLineLayout takes the bottom slot.
			self.PrimaryLineLayout:SetPoint("BOTTOM", self, "CENTER", 0, padding)
			self.SecondaryLineLayout:SetPoint("TOP", self, "CENTER", 0, -padding)
			self.SecondaryLineLayout:SetShown(true)
		end
	end
	-- Keep coin display denomination FontStrings in sync with the main font
	-- pipeline so that a font-settings change is reflected on both sides.
	self:StyleCoinDisplay()
	self:StyleSecondaryCoinDisplay()
end

function RLF_RowTextMixin:CreateTopLeftText()
	if not self.Icon.topLeftText then
		self.Icon.topLeftText = self.Icon:CreateFontString(nil, "OVERLAY") --[[@as RLF_RowFontString]]
		self.Icon.topLeftText:SetPoint("TOPLEFT", self.Icon, "TOPLEFT", 2, -2)
	end
	self:StyleTopLeftText()
	self.Icon.topLeftText:Hide()
end

function RLF_RowTextMixin:UpdateSecondaryText(secondaryTextFn)
	local stylingDb = G_RLF.DbAccessor:Styling(self.frameType)
	if not stylingDb.enabledSecondaryRowText then
		self.secondaryText = nil
		return
	end

	if self.elementSecondaryText then
		self.secondaryText = self.elementSecondaryText
		return
	end

	if
		type(secondaryTextFn) == "function"
		and secondaryTextFn(self.amount) ~= ""
		and secondaryTextFn(self.amount) ~= nil
	then
		self.secondaryText = secondaryTextFn(self.amount)
	else
		self.secondaryText = nil
	end
end

--- Update the total item count for the row
function RLF_RowTextMixin:UpdateItemCount()
	-- Migrated modules provide itemCountFn on the payload
	if self.itemCountFn then
		RunNextFrame(function()
			-- Re-check: the row may have been reset/reused before this callback fires
			if not self.itemCountFn then
				return
			end
			local value, options = self.itemCountFn()
			if value then
				self:ShowItemCountText(value, options)
			end
		end)
		return
	end
end

--- Show or hide the AmountText (quantity suffix) FontString.
--- Calls LayoutPrimaryLine() at the end so the updated visibility is reflected
--- in PrimaryText's budget — mirrors ShowItemCountText's pattern exactly.
--- @param amountText string|nil  Formatted suffix e.g. "x2", or "" / nil to hide.
--- @param r number Red channel — matches PrimaryText color.
--- @param g number Green channel.
--- @param b number Blue channel.
--- @param a number Alpha channel.
function RLF_RowTextMixin:ShowAmountText(amountText, r, g, b, a)
	if amountText and amountText ~= "" then
		self.AmountText:SetText(amountText)
		self.AmountText:SetTextColor(r, g, b, a)
		self.AmountText:Show()
	else
		self.AmountText:Hide()
	end
	self:LayoutPrimaryLine()
end

--- Re-anchor SecondaryCoinDisplay after a deferred layout element (e.g. ItemCountText)
--- has changed visibility.  Only acts when SCD is shown and not on the secondary row.
function RLF_RowTextMixin:RecheckSecondaryCoinDisplayAnchor()
	if not self.SecondaryCoinDisplay or not self.SecondaryCoinDisplay:IsShown() then
		return
	end
	local onSecondaryRow = self.SecondaryLineLayout and self.SecondaryLineLayout:IsShown()
	if onSecondaryRow then
		return
	end
	local spacing = self.PrimaryLineLayout and self.PrimaryLineLayout.spacing or 2
	local anchorFrame = self.PrimaryText
	if self.ItemCountText and self.ItemCountText:IsShown() then
		anchorFrame = self.ItemCountText
	elseif self.AmountText and self.AmountText:IsShown() then
		anchorFrame = self.AmountText
	elseif self.CoinDisplay and self.CoinDisplay:IsShown() then
		anchorFrame = self.CoinDisplay
	end
	self.SecondaryCoinDisplay:ClearAllPoints()
	self.SecondaryCoinDisplay:SetPoint("LEFT", anchorFrame, "RIGHT", spacing, 0)
end

function RLF_RowTextMixin:ShowItemCountText(itemCount, options)
	local WrapChar = G_RLF.WrapCharEnum
	options = options or {}
	local color = options.color or G_RLF:RGBAToHexFormat(unpack({ 0.737, 0.737, 0.737, 1 }))
	local showSign = options.showSign or false
	local wrapChar = options.wrapChar

	local sChar, eChar = G_RLF:GetWrapChars(wrapChar)

	if itemCount then
		local itemCountType = type(itemCount)
		if itemCountType == "number" and (itemCount > 1 or (showSign and itemCount >= 1)) then
			local sign = ""
			if showSign then
				sign = "+"
			end
			self.ItemCountText:SetText(color .. sChar .. sign .. itemCount .. eChar .. "|r")
			self.ItemCountText:Show()
		elseif itemCountType == "string" and itemCount ~= "" then
			self.ItemCountText:SetText(color .. sChar .. itemCount .. eChar .. "|r")
			self.ItemCountText:Show()
		end
	else
		self.ItemCountText:Hide()
	end

	-- Second layout pass: now that the count string is set (or hidden), the
	-- accurate ItemCountText width is measured and PrimaryText is resized to
	-- fit within the remaining budget.
	self:LayoutPrimaryLine()
	-- Re-anchor SecondaryCoinDisplay now that ItemCountText visibility is final.
	-- (SecondaryCoinDisplay was anchored before the deferred ShowItemCountText ran.)
	self:RecheckSecondaryCoinDisplayAnchor()
end

--- Compute the available text width, apply it to PrimaryText, and call Layout()
--- on PrimaryLineLayout.  Also sizes ClickableButton once Layout() has applied
--- engine truncation so GetStringWidth() reflects the visible display width.
--- Called from ShowText() for all rows, and again from ShowItemCountText() for
--- rows that display a count (Items, Currency, Reputation, XP, Professions).
function RLF_RowTextMixin:LayoutPrimaryLine()
	local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)
	local iconSize = sizingDb.iconSize
	local feedWidth = sizingDb.feedWidth

	local portraitOffset = 0
	local partyConfig = G_RLF.DbAccessor:Feature(self.frameType, "partyLoot") or {}
	if self.unit and partyConfig.enablePartyAvatar then
		-- UnitPortrait is anchored at Icon.RIGHT + iconSize/4 (gap) with width portraitSize.
		-- PrimaryLineLayout is then anchored at UnitPortrait.RIGHT + iconSize/4 (gap).
		-- Extra width consumed beyond iconOffset: portraitSize + gap between icon and portrait.
		local portraitSize = iconSize * 0.8
		portraitOffset = portraitSize + (iconSize / 4)
	end

	-- Space occupied by the icon column:
	--   iconSize/4  (gap from row left edge to icon — icon is anchored at xOffset=iconSize/4)
	--   iconSize    (the icon itself)
	--   iconSize/4  (gap between icon right edge and the start of PrimaryLineLayout)
	-- This matches the original TruncateItemLink formula: feedWidth - (iconSize/4) - iconSize - (iconSize/4)
	local iconOffset = iconSize + 2 * (iconSize / 4)
	local availableWidth = feedWidth - iconOffset - portraitOffset

	-- When AmountText (quantity suffix) is visible its width (plus spacing) is
	-- subtracted from the budget first.
	local amountTextWidth = 0
	if self.AmountText:IsShown() then
		amountTextWidth = self.AmountText:GetUnboundedStringWidth() + self.PrimaryLineLayout.spacing
	end

	-- When ItemCountText is visible its width (plus the layout spacing gap) is
	-- subtracted from the budget so PrimaryText knows how much room it has.
	local itemCountWidth = 0
	if self.ItemCountText:IsShown() then
		itemCountWidth = self.ItemCountText:GetUnboundedStringWidth() + self.PrimaryLineLayout.spacing
	end

	-- PrimaryText takes only the space it naturally needs, truncating only when
	-- its intrinsic width would push CoinDisplay, AmountText, or ItemCountText off-row.
	local coinDisplayWidth = 0
	if self.CoinDisplay and self.CoinDisplay:IsShown() then
		coinDisplayWidth = self.CoinDisplay:GetWidth()
		if coinDisplayWidth > 0 then
			coinDisplayWidth = coinDisplayWidth + self.PrimaryLineLayout.spacing
		end
	end

	-- When SecondaryCoinDisplay (vendor/AH price) is visible but the secondary row
	-- is not active, it falls back to the primary line. Deduct its width here so
	-- PrimaryText is truncated before the price display rather than overlapping it.
	local secondaryCoinOnPrimaryWidth = 0
	if self.SecondaryCoinDisplay and self.SecondaryCoinDisplay:IsShown() then
		if not (self.SecondaryLineLayout and self.SecondaryLineLayout:IsShown()) then
			secondaryCoinOnPrimaryWidth = self.SecondaryCoinDisplay:GetWidth()
			if secondaryCoinOnPrimaryWidth > 0 then
				secondaryCoinOnPrimaryWidth = secondaryCoinOnPrimaryWidth + self.PrimaryLineLayout.spacing
			end
		end
	end

	local maxPrimaryWidth =
		math.max(1, availableWidth - amountTextWidth - itemCountWidth - coinDisplayWidth - secondaryCoinOnPrimaryWidth)
	local naturalWidth = self.PrimaryText:GetUnboundedStringWidth()
	local primaryTextWidth = math.min(naturalWidth, maxPrimaryWidth)
	self.PrimaryText:SetWidth(primaryTextWidth)
	-- Re-set the stored raw text so GetText() always returns the full original
	-- string (engine truncation only affects display rendering, not GetText()).
	self.PrimaryText:SetText(self.rawPrimaryText)
	-- SetWordWrap(false) was already called once in CreatePrimaryLineLayout().

	self.PrimaryLineLayout.fixedWidth = availableWidth
	self.PrimaryLineLayout:Layout()

	-- ClickableButton geometry is owned exclusively here (not in ShowText or
	-- SetupTooltip) so it reflects the post-truncation display width.
	if self.link then
		self.ClickableButton:ClearAllPoints()
		self.ClickableButton:SetPoint("LEFT", self.PrimaryText, "LEFT")
		self.ClickableButton:SetSize(self.PrimaryText:GetStringWidth(), self.PrimaryText:GetStringHeight())
	end
end

--- Compute the available text width for SecondaryText, apply it, and call Layout()
--- on SecondaryLineLayout. Called from ShowText() whenever secondary text is shown.
function RLF_RowTextMixin:LayoutSecondaryLine()
	local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)
	local iconSize = sizingDb.iconSize
	local feedWidth = sizingDb.feedWidth

	local portraitOffset = 0
	local partyConfig = G_RLF.DbAccessor:Feature(self.frameType, "partyLoot") or {}
	if self.unit and partyConfig.enablePartyAvatar then
		-- Mirrors the corrected portrait offset logic in LayoutPrimaryLine().
		local portraitSize = iconSize * 0.8
		portraitOffset = portraitSize + (iconSize / 4)
	end

	local iconOffset = iconSize + 2 * (iconSize / 4)
	local availableWidth = feedWidth - iconOffset - portraitOffset

	-- When SecondaryCoinDisplay is visible on the secondary line, deduct its width
	-- so SecondaryText truncates before the coin display instead of overflowing.
	local secondaryCoinWidth = 0
	if self.SecondaryCoinDisplay and self.SecondaryCoinDisplay:IsShown() then
		if self.SecondaryLineLayout and self.SecondaryLineLayout:IsShown() then
			secondaryCoinWidth = self.SecondaryCoinDisplay:GetWidth()
			if secondaryCoinWidth > 0 then
				secondaryCoinWidth = secondaryCoinWidth + (self.SecondaryLineLayout.spacing or 2)
			end
		end
	end

	-- Constrain SecondaryText to availableWidth, then re-set its text so the
	-- engine renders the "." ellipsis against the original (untruncated) string.
	local naturalWidth = self.SecondaryText:GetUnboundedStringWidth()
	self.SecondaryText:SetWidth(math.max(1, math.min(naturalWidth, availableWidth - secondaryCoinWidth)))
	self.SecondaryText:SetText(self.secondaryText or "")

	self.SecondaryLineLayout.fixedWidth = availableWidth
	self.SecondaryLineLayout:Layout()
end

function RLF_RowTextMixin:ShowText(rawText, r, g, b, a)
	if a == nil then
		a = 1
	end

	-- Store the raw (untruncated) text; LayoutPrimaryLine() will re-apply it
	-- after computing the correct width budget.
	self.rawPrimaryText = rawText
	self.PrimaryText:SetText(rawText)

	if r == nil or g == nil or b == nil then
		r, g, b, a = unpack(defaultColor)
	end

	-- Store the element's primary colour.  StyleCoinDisplay() reads these so
	-- that denomination FontStrings always match PrimaryText regardless of
	-- whether the call originates from ShowText or a config-panel restyle.
	self._primaryR, self._primaryG, self._primaryB, self._primaryA = r, g, b, a
	self.PrimaryText:SetTextColor(r, g, b, a)
	-- Propagate the new colour into the CoinDisplay immediately.
	self:StyleCoinDisplay()

	---@type RLF_ConfigStyling
	local stylingDb = G_RLF.DbAccessor:Styling(self.frameType)
	if stylingDb.enabledSecondaryRowText and self.secondaryText ~= nil and self.secondaryText ~= "" then
		self.SecondaryText:SetText(self.secondaryText)
		self.SecondaryText:Show()
		self.SecondaryLineLayout:Show()
		self:LayoutSecondaryLine()
		-- Mirror the secondary text colour into the SecondaryCoinDisplay.
		local sr, sg, sb, sa = self.SecondaryText:GetTextColor()
		self._secondaryR, self._secondaryG, self._secondaryB, self._secondaryA = sr, sg, sb, sa
	else
		self.SecondaryText:Hide()
		self.SecondaryLineLayout:Hide()
	end
	self:StyleSecondaryCoinDisplay()

	-- Initial layout pass with ItemCountText hidden (count text is set later via
	-- a deferred UpdateItemCount → ShowItemCountText call).  PrimaryText gets
	-- the full available width on this pass.
	self:LayoutPrimaryLine()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- CoinDisplay — real-texture denomination display for primary money rows.
--
-- StyleCoinDisplay() is part of the normal styling pipeline.  It is called:
--   • from StyleText()       — whenever font settings (face/size/flags) change
--   • from ShowText()        — whenever the element colour changes
--   • from CreateCoinDisplay() — immediately after the frames are built
-- This means UpdateCoinDisplay() never needs to apply styling itself; font
-- metrics are always correct before GetUnboundedStringWidth() is called.
--
-- Instead of baking |T…|t coin icon markup into PrimaryText (which stays put
-- while the Translation animation plays), we create real Texture children.
-- These Textures are proper region-hierarchy members and receive the
-- Translation offset automatically.
--
-- The CoinDisplay frame is a layout child of PrimaryLineLayout (layoutIndex=2).
-- It contains three denomination sub-frames (gold, silver, copper); each has
-- an amount FontString and a coin Texture anchored RIGHT of the text.
-- ─────────────────────────────────────────────────────────────────────────────

--- Apply the styled font (face, size, flags, shadow) and synchronise text
--- colour across all denomination FontStrings in CoinDisplay.
--- Colour is read from the stored _primaryR/G/B/A fields (set by ShowText)
--- so this method is safe to call from StyleText() before ShowText() has
--- run — it will use the last-known element colour, or white for new rows.
--- Safe to call before CreateCoinDisplay() — returns immediately when absent.
function RLF_RowTextMixin:StyleCoinDisplay()
	if not self.CoinDisplay then
		return
	end
	local cr = self._primaryR or 1
	local cg = self._primaryG or 1
	local cb = self._primaryB or 1
	local ca = self._primaryA or 1
	for _, denom in ipairs(DENOM_ORDER) do
		local group = self.CoinDisplay[denom .. "Group"]
		if group then
			if self.cachedUseFontObject then
				local fontObj = self.PrimaryText:GetFontObject()
				if fontObj then
					group.amountText:SetFontObject(fontObj)
				end
			elseif self.cachedFontFace and G_RLF.lsm then
				local fontPath = G_RLF.lsm:Fetch(G_RLF.lsm.MediaType.FONT, self.cachedFontFace)
				ApplyFontStyle(
					group.amountText,
					fontPath,
					self.cachedFontSize,
					self.cachedFontFlags or "",
					self.cachedFontShadowColor,
					self.cachedFontShadowOffsetX,
					self.cachedFontShadowOffsetY
				)
			end
			group.amountText:SetTextColor(cr, cg, cb, ca)
		end
	end
end

--- Create the CoinDisplay frame as a layout child of PrimaryLineLayout.
--- Called lazily the first time coin data is set on this row.
function RLF_RowTextMixin:CreateCoinDisplay()
	if self.CoinDisplay then
		return
	end
	local coinDisplay = CreateFrame("Frame", nil, self.PrimaryLineLayout)
	coinDisplay.layoutIndex = 2
	coinDisplay:SetSize(0, 0)
	coinDisplay:Hide()

	for _, denom in ipairs(DENOM_ORDER) do
		local group = CreateFrame("Frame", nil, coinDisplay)
		group:SetSize(0, 0)
		group:Hide()

		local amountText = group:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		amountText:SetWordWrap(false)
		group.amountText = amountText

		local icon = group:CreateTexture(nil, "ARTWORK")
		icon:SetAtlas(COIN_ATLAS[denom])
		icon:Hide()
		group.icon = icon

		coinDisplay[denom .. "Group"] = group
	end

	self.CoinDisplay = coinDisplay
	-- Apply current font and colour immediately so UpdateCoinDisplay can
	-- measure widths correctly on the very first call.
	self:StyleCoinDisplay()

	-- Register with the element fade-in animation group (created during Init()).
	-- This ensures the CoinDisplay fades in along with the other row elements
	-- during the SLIDE enter animation instead of popping in at full alpha.
	if self.ElementFadeInAnimation then
		local anim = self.ElementFadeInAnimation:CreateAnimation("Alpha")
		anim:SetTarget(coinDisplay)
		anim:SetFromAlpha(0)
		anim:SetToAlpha(1)
		anim:SetSmoothing("IN_OUT")
		anim:SetDuration(0.2)
		coinDisplay.elementFadeIn = anim
	end
end

--- Populate and show the CoinDisplay with denomination amounts.
---@param gold number
---@param silver number
---@param copper number
function RLF_RowTextMixin:UpdateCoinDisplay(gold, silver, copper)
	-- Cache raw values so StoreRowHistory can snapshot them for loot history.
	self._coinData = { gold, silver, copper }
	if not self.CoinDisplay then
		self:CreateCoinDisplay()
		-- CreateCoinDisplay calls StyleCoinDisplay internally; font and colour
		-- are guaranteed correct before we measure any widths below.
	end

	local iconSize = math.max(8, self.cachedFontSize or 14)
	local iconGap = 2
	local groupSpacing = math.max(2, iconSize / 4)

	local amounts = { gold = gold, silver = silver, copper = copper }
	local prevGroup = nil
	local totalWidth = 0

	for _, denom in ipairs(DENOM_ORDER) do
		local group = self.CoinDisplay[denom .. "Group"]
		local amount = amounts[denom]
		if amount and amount > 0 then
			group.amountText:SetText(tostring(amount))
			local textWidth = group.amountText:GetUnboundedStringWidth()

			group.icon:SetSize(iconSize, iconSize)
			group.icon:Show()

			local groupWidth = textWidth + iconGap + iconSize
			group:SetSize(groupWidth, iconSize)

			group.amountText:ClearAllPoints()
			group.amountText:SetPoint("LEFT", group, "LEFT", 0, 0)
			group.icon:ClearAllPoints()
			group.icon:SetPoint("LEFT", group.amountText, "RIGHT", iconGap, 0)

			if prevGroup then
				group:ClearAllPoints()
				group:SetPoint("LEFT", prevGroup, "RIGHT", groupSpacing, 0)
				totalWidth = totalWidth + groupSpacing
			else
				group:ClearAllPoints()
				group:SetPoint("LEFT", self.CoinDisplay, "LEFT", 0, 0)
			end
			group:Show()
			prevGroup = group
			totalWidth = totalWidth + groupWidth
		else
			group:ClearAllPoints()
			group:Hide()
			group.icon:Hide()
		end
	end

	if totalWidth > 0 then
		self.CoinDisplay:SetSize(totalWidth, iconSize)
		self.CoinDisplay:Show()
	else
		self.CoinDisplay:SetSize(0, 0)
		self.CoinDisplay:Hide()
	end
end

--- Hide the CoinDisplay and all denomination groups.
--- Called in Reset() so the frame is clean when a non-money row reuses this slot.
function RLF_RowTextMixin:HideCoinDisplay()
	if not self.CoinDisplay then
		return
	end
	for _, denom in ipairs(DENOM_ORDER) do
		local group = self.CoinDisplay[denom .. "Group"]
		if group then
			group:Hide()
			if group.icon then
				group.icon:Hide()
			end
		end
	end
	self.CoinDisplay:SetSize(0, 0)
	self.CoinDisplay:Hide()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SecondaryCoinDisplay — real-texture denomination display for secondary lines
-- (money total, vendor / AH price).
--
-- NOT a layout child — positioned by SetPoint() after SecondaryLineLayout
-- has been laid out.  Optionally includes a prefix Texture (vendor / AH icon).
-- StyleSecondaryCoinDisplay() mirrors the primary pipeline:
--   • StyleText()                  — font face/size/flags changes
--   • ShowText()                   — secondary text colour changes
--   • CreateSecondaryCoinDisplay() — immediately after frames are built
-- ─────────────────────────────────────────────────────────────────────────────

--- Apply the styled secondary font and synchronise text colour across all
--- denomination FontStrings in SecondaryCoinDisplay.
--- Colour is read from the stored _secondaryR/G/B/A fields (set by ShowText).
--- Safe to call before CreateSecondaryCoinDisplay() — returns immediately when absent.
function RLF_RowTextMixin:StyleSecondaryCoinDisplay()
	if not self.SecondaryCoinDisplay then
		return
	end
	local sr = self._secondaryR or 1
	local sg = self._secondaryG or 1
	local sb = self._secondaryB or 1
	local sa = self._secondaryA or 1
	local scd = self.SecondaryCoinDisplay
	for _, denom in ipairs(DENOM_ORDER) do
		local group = scd[denom .. "Group"]
		if group then
			if self.cachedUseFontObject then
				local fontObj = self.SecondaryText:GetFontObject()
				if fontObj then
					group.amountText:SetFontObject(fontObj)
				end
			elseif self.cachedFontFace and G_RLF.lsm then
				local fontPath = G_RLF.lsm:Fetch(G_RLF.lsm.MediaType.FONT, self.cachedFontFace)
				ApplyFontStyle(
					group.amountText,
					fontPath,
					self.cachedSecondaryFontSize,
					self.cachedFontFlags or "",
					self.cachedFontShadowColor,
					self.cachedFontShadowOffsetX,
					self.cachedFontShadowOffsetY
				)
			end
			group.amountText:SetTextColor(sr, sg, sb, sa)
		end
	end
end

--- Create the SecondaryCoinDisplay frame as a direct child of the row.
--- Called lazily when secondary coin data is first needed.
function RLF_RowTextMixin:CreateSecondaryCoinDisplay()
	if self.SecondaryCoinDisplay then
		return
	end
	-- Parent is the row itself so Translation moves it along with everything else.
	local scd = CreateFrame("Frame", nil, self)
	scd:SetSize(0, 0)
	scd:Hide()

	-- Optional prefix icon (vendor / AH icon) that appears before the coin amounts
	local prefixIcon = scd:CreateTexture(nil, "ARTWORK")
	prefixIcon:Hide()
	scd.prefixIcon = prefixIcon

	for _, denom in ipairs(DENOM_ORDER) do
		local group = CreateFrame("Frame", nil, scd)
		group:SetSize(0, 0)
		group:Hide()

		local amountText = group:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		amountText:SetWordWrap(false)
		group.amountText = amountText

		local icon = group:CreateTexture(nil, "ARTWORK")
		icon:SetAtlas(COIN_ATLAS[denom])
		icon:Hide()
		group.icon = icon

		scd[denom .. "Group"] = group
	end

	self.SecondaryCoinDisplay = scd
	-- Apply current font and colour immediately.
	self:StyleSecondaryCoinDisplay()

	-- Register with the element fade-in animation group (created during Init()).
	-- This ensures SecondaryCoinDisplay fades in with the other row elements
	-- during the SLIDE enter animation instead of popping in at full alpha.
	if self.ElementFadeInAnimation then
		local anim = self.ElementFadeInAnimation:CreateAnimation("Alpha")
		anim:SetTarget(scd)
		anim:SetFromAlpha(0)
		anim:SetToAlpha(1)
		anim:SetSmoothing("IN_OUT")
		anim:SetDuration(0.2)
		scd.elementFadeIn = anim
	end
end

--- Populate, size, and anchor the SecondaryCoinDisplay.
--- Must be called AFTER ShowText() so SecondaryText has its final position.
---@param gold number
---@param silver number
---@param copper number
---@param prefixAtlas? string  Atlas name for an icon shown BEFORE the coin amounts (vendor/AH icon)
---@param prefixSize?  number  Square pixel size for the prefix icon
---@param goldText?    string  Pre-formatted gold amount string (e.g. "2.50K" for abbreviated display)
function RLF_RowTextMixin:UpdateSecondaryCoinDisplay(gold, silver, copper, prefixAtlas, prefixSize, goldText)
	-- Cache raw values so StoreRowHistory can snapshot them for loot history.
	self._secondaryCoinData = { gold, silver, copper, prefixAtlas, prefixSize, goldText }
	if not self.SecondaryCoinDisplay then
		self:CreateSecondaryCoinDisplay()
		-- CreateSecondaryCoinDisplay calls StyleSecondaryCoinDisplay internally;
		-- font and colour are guaranteed correct before measuring widths below.
	end
	local scd = self.SecondaryCoinDisplay

	local iconSize = math.max(8, self.cachedSecondaryFontSize or 12)
	local iconGap = 2
	local groupSpacing = math.max(2, iconSize / 4)

	-- ── Prefix icon (vendor / AH / paragon) ─────────────────────────────────
	local prefixWidth = 0
	if prefixAtlas and prefixAtlas ~= "" then
		local ps = prefixSize or iconSize
		scd.prefixIcon:SetAtlas(prefixAtlas)
		scd.prefixIcon:SetSize(ps, ps)
		scd.prefixIcon:ClearAllPoints()
		scd.prefixIcon:SetPoint("LEFT", scd, "LEFT", 0, 0)
		scd.prefixIcon:Show()
		prefixWidth = ps + iconGap
	else
		scd.prefixIcon:Hide()
	end

	-- ── Denomination groups ──────────────────────────────────────────────────
	local amounts = { gold = gold, silver = silver, copper = copper }
	local prevAnchor = scd.prefixIcon -- chain starts after prefix icon
	local prevAnchorIsFrame = (prefixWidth > 0)
	local totalWidth = prefixWidth

	for _, denom in ipairs(DENOM_ORDER) do
		local group = scd[denom .. "Group"]
		local amount = amounts[denom]
		if amount and amount > 0 then
			-- Gold denomination may use a pre-formatted abbreviated string (e.g. "2.50K")
			local displayText = (denom == "gold" and goldText) and goldText or tostring(amount)
			group.amountText:SetText(displayText)
			local textWidth = group.amountText:GetUnboundedStringWidth()

			group.icon:SetSize(iconSize, iconSize)
			group.icon:Show()

			local groupWidth = textWidth + iconGap + iconSize
			group:SetSize(groupWidth, iconSize)

			group.amountText:ClearAllPoints()
			group.amountText:SetPoint("LEFT", group, "LEFT", 0, 0)
			group.icon:ClearAllPoints()
			group.icon:SetPoint("LEFT", group.amountText, "RIGHT", iconGap, 0)

			group:ClearAllPoints()
			if prevAnchorIsFrame then
				group:SetPoint("LEFT", prevAnchor, "RIGHT", groupSpacing, 0)
				totalWidth = totalWidth + groupSpacing
			else
				group:SetPoint("LEFT", scd, "LEFT", totalWidth, 0)
			end
			group:Show()
			prevAnchor = group
			prevAnchorIsFrame = true
			totalWidth = totalWidth + groupWidth
		else
			group:ClearAllPoints()
			group:Hide()
			group.icon:Hide()
		end
	end

	if totalWidth > 0 then
		scd:SetSize(totalWidth, iconSize)
		scd:Show()
		scd:ClearAllPoints()

		local onSecondaryRow = self.SecondaryLineLayout and self.SecondaryLineLayout:IsShown()
		if onSecondaryRow then
			-- Secondary row is active: re-layout the secondary line so SecondaryText
			-- budget accounts for the coin display width, then anchor after it.
			self:LayoutSecondaryLine()
			local spacing = self.SecondaryLineLayout.spacing or 2
			scd:SetPoint("LEFT", self.SecondaryText, "RIGHT", spacing, 0)
		else
			-- Secondary row is not active: fall back to the primary line.
			-- Re-layout the primary line so PrimaryText budget accounts for the coin
			-- display width, then anchor just after the last visible primary element.
			-- Priority: ItemCountText (layoutIndex=4) → AmountText (layoutIndex=3)
			--           → CoinDisplay (layoutIndex=2, money rows) → PrimaryText.
			self:LayoutPrimaryLine()
			self:RecheckSecondaryCoinDisplayAnchor()
		end
	else
		scd:SetSize(0, 0)
		scd:Hide()
	end
end

--- Hide the SecondaryCoinDisplay and all its children.
--- Called in Reset() for clean row reuse.
function RLF_RowTextMixin:HideSecondaryCoinDisplay()
	if not self.SecondaryCoinDisplay then
		return
	end
	local scd = self.SecondaryCoinDisplay
	if scd.prefixIcon then
		scd.prefixIcon:Hide()
	end
	for _, denom in ipairs(DENOM_ORDER) do
		local group = scd[denom .. "Group"]
		if group then
			group:Hide()
			if group.icon then
				group.icon:Hide()
			end
		end
	end
	scd:SetSize(0, 0)
	scd:Hide()
end

G_RLF.RLF_RowTextMixin = RLF_RowTextMixin
