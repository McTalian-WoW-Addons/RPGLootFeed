---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class Styling : RLF_StylingConfigHandlerBase
local Styling = {}

function Styling:GetTextAlignment()
	return G_RLF.DbAccessor:Styling(self.frameId).textAlignment
end

function Styling:SetTextAlignment(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).textAlignment = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
	G_RLF.LootDisplay:ReInitQueueLabel(self.frameId)
end

function Styling:GetGrowUp()
	return G_RLF.DbAccessor:Styling(self.frameId).growUp
end

function Styling:SetGrowUp(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).growUp = value
	G_RLF.LootDisplay:UpdateRowPositions(self.frameId)
	G_RLF.LootDisplay:ReInitQueueLabel(self.frameId)
	G_RLF.LootDisplay:UpdateTabAppearance(self.frameId)
end

function Styling:GetBackgroundType()
	return G_RLF.DbAccessor:Styling(self.frameId).rowBackgroundType
end

function Styling:SetBackgroundType(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).rowBackgroundType = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:IsGradientHidden()
	return G_RLF.DbAccessor:Styling(self.frameId).rowBackgroundType ~= G_RLF.RowBackground.GRADIENT
end

function Styling:GetGradientStartColor()
	local r, g, b, a = unpack(G_RLF.DbAccessor:Styling(self.frameId).rowBackgroundGradientStart)
	return r, g, b, a
end

function Styling:SetGradientStartColor(_, r, g, b, a)
	G_RLF.DbAccessor:Styling(self.frameId).rowBackgroundGradientStart = { r, g, b, a }
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetGradientEndColor()
	local r, g, b, a = unpack(G_RLF.DbAccessor:Styling(self.frameId).rowBackgroundGradientEnd)
	return r, g, b, a
end

function Styling:SetGradientEndColor(_, r, g, b, a)
	G_RLF.DbAccessor:Styling(self.frameId).rowBackgroundGradientEnd = { r, g, b, a }
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:IsBackgroundTextureHidden()
	return G_RLF.DbAccessor:Styling(self.frameId).rowBackgroundType ~= G_RLF.RowBackground.TEXTURED
end

function Styling:GetBackgroundTexture()
	return G_RLF.DbAccessor:Styling(self.frameId).rowBackgroundTexture
end

function Styling:SetBackgroundTexture(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).rowBackgroundTexture = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetBackgroundTextureColor()
	local r, g, b, a = unpack(G_RLF.DbAccessor:Styling(self.frameId).rowBackgroundTextureColor)
	return r, g, b, a
end

function Styling:SetBackgroundTextureColor(_, r, g, b, a)
	G_RLF.DbAccessor:Styling(self.frameId).rowBackgroundTextureColor = { r, g, b, a }
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetTopInset()
	return G_RLF.DbAccessor:Styling(self.frameId).backdropInsets.top
end

function Styling:SetTopInset(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).backdropInsets.top = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetRightInset()
	return G_RLF.DbAccessor:Styling(self.frameId).backdropInsets.right
end

function Styling:SetRightInset(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).backdropInsets.right = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetBottomInset()
	return G_RLF.DbAccessor:Styling(self.frameId).backdropInsets.bottom
end

function Styling:SetBottomInset(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).backdropInsets.bottom = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetLeftInset()
	return G_RLF.DbAccessor:Styling(self.frameId).backdropInsets.left
end

function Styling:SetLeftInset(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).backdropInsets.left = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetRowBordersEnabled()
	return G_RLF.DbAccessor:Styling(self.frameId).enableRowBorder
end

function Styling:SetRowBordersEnabled(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).enableRowBorder = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:IsRowBorderDisabled()
	return not G_RLF.DbAccessor:Styling(self.frameId).enableRowBorder
end

function Styling:GetRowBorderTexture()
	return G_RLF.DbAccessor:Styling(self.frameId).rowBorderTexture
end

function Styling:SetRowBorderTexture(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).rowBorderTexture = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetRowBorderThickness()
	return G_RLF.DbAccessor:Styling(self.frameId).rowBorderSize
end

function Styling:SetRowBorderThickness(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).rowBorderSize = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetRowBorderColor()
	local r, g, b, a = unpack(G_RLF.DbAccessor:Styling(self.frameId).rowBorderColor)
	return r, g, b, a
end

function Styling:SetRowBorderColor(_, r, g, b, a)
	G_RLF.DbAccessor:Styling(self.frameId).rowBorderColor = { r, g, b, a }
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetRowBorderClassColors()
	return G_RLF.DbAccessor:Styling(self.frameId).rowBorderClassColors
end

function Styling:SetRowBorderClassColors(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).rowBorderClassColors = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetEnabledSecondaryRowText()
	return G_RLF.DbAccessor:Styling(self.frameId).enabledSecondaryRowText
end

function Styling:SetEnabledSecondaryRowText(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).enabledSecondaryRowText = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetEnableTopLeftIconText()
	return G_RLF.DbAccessor:Styling(self.frameId).enableTopLeftIconText
end

function Styling:SetEnableTopLeftIconText(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).enableTopLeftIconText = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:IsTopLeftIconTextDisabled()
	return not G_RLF.DbAccessor:Styling(self.frameId).enableTopLeftIconText
end

function Styling:IsTopLeftIconTextColorDisabled()
	return not G_RLF.DbAccessor:Styling(self.frameId).enableTopLeftIconText
		or G_RLF.DbAccessor:Styling(self.frameId).topLeftIconTextUseQualityColor
end

function Styling:GetTopLeftIconFontSize()
	return G_RLF.DbAccessor:Styling(self.frameId).topLeftIconFontSize
end

function Styling:SetTopLeftIconFontSize(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).topLeftIconFontSize = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetTopLeftIconTextUseQualityColor()
	return G_RLF.DbAccessor:Styling(self.frameId).topLeftIconTextUseQualityColor
end

function Styling:SetTopLeftIconTextUseQualityColor(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).topLeftIconTextUseQualityColor = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetTopLeftIconTextColor()
	local r, g, b, a = unpack(G_RLF.DbAccessor:Styling(self.frameId).topLeftIconTextColor)
	return r, g, b, a
end

function Styling:SetTopLeftIconTextColor(_, r, g, b, a)
	G_RLF.DbAccessor:Styling(self.frameId).topLeftIconTextColor = { r, g, b, a }
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetIconSkin()
	return G_RLF.DbAccessor:Styling(self.frameId).iconSkin
end

function Styling:SetIconSkin(_, value)
	-- The dropdown lists every skinner, including ones that are not installed,
	-- so the write has to be refused here rather than by the widget.
	if not G_RLF.IconSkinResolver:Available()[value] then
		G_RLF:LogWarn(G_RLF.L["IconSkinUnavailableWarning"], addonName)
		return
	end
	G_RLF.DbAccessor:Styling(self.frameId).iconSkin = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

function Styling:GetUseFontObjects()
	return G_RLF.DbAccessor:Styling(self.frameId).useFontObjects
end

function Styling:SetUseFontObjects(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).useFontObjects = value
	G_RLF.LootDisplay:ReInitQueueLabel(self.frameId)
end

function Styling:IsFontObjectsDisabled()
	return not G_RLF.DbAccessor:Styling(self.frameId).useFontObjects
end

function Styling:GetFontObject()
	return G_RLF.DbAccessor:Styling(self.frameId).font
end

function Styling:SetFontObject(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).font = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
	G_RLF.LootDisplay:ReInitQueueLabel(self.frameId)
end

function Styling:IsCustomFontsDisabled()
	return G_RLF.DbAccessor:Styling(self.frameId).useFontObjects == true
end

function Styling:GetFontFace()
	return G_RLF.DbAccessor:Styling(self.frameId).fontFace
end

function Styling:SetFontFace(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).fontFace = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
	G_RLF.LootDisplay:ReInitQueueLabel(self.frameId)
end

function Styling:GetFontSize()
	return G_RLF.DbAccessor:Styling(self.frameId).fontSize
end

function Styling:SetFontSize(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).fontSize = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
	G_RLF.LootDisplay:ReInitQueueLabel(self.frameId)
end

function Styling:IsSecondaryFontSizeDisabled()
	return not G_RLF.DbAccessor:Styling(self.frameId).enabledSecondaryRowText
		or (G_RLF.DbAccessor:Styling(self.frameId).useFontObjects == true)
end

function Styling:GetSecondaryFontSize()
	return G_RLF.DbAccessor:Styling(self.frameId).secondaryFontSize
end

function Styling:SetSecondaryFontSize(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).secondaryFontSize = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
	G_RLF.LootDisplay:ReInitQueueLabel(self.frameId)
end

function Styling:GetFontFlags(_, key)
	return G_RLF.DbAccessor:Styling(self.frameId).fontFlags[key]
end

function Styling:SetFontFlags(_, key, value)
	G_RLF.DbAccessor:Styling(self.frameId).fontFlags[key] = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
	G_RLF.LootDisplay:ReInitQueueLabel(self.frameId)
end

function Styling:GetDisableSlug()
	return G_RLF.DbAccessor:Styling(self.frameId).disableSlug
end

function Styling:SetDisableSlug(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).disableSlug = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
	G_RLF.LootDisplay:ReInitQueueLabel(self.frameId)
end

function Styling:GetShadowColor()
	local r, g, b, a = unpack(G_RLF.DbAccessor:Styling(self.frameId).fontShadowColor)
	return r, g, b, a
end

function Styling:SetShadowColor(_, r, g, b, a)
	G_RLF.DbAccessor:Styling(self.frameId).fontShadowColor = { r, g, b, a }
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
	G_RLF.LootDisplay:ReInitQueueLabel(self.frameId)
end

function Styling:GetShadowOffsetX()
	return G_RLF.DbAccessor:Styling(self.frameId).fontShadowOffsetX
end

function Styling:SetShadowOffsetX(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).fontShadowOffsetX = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
	G_RLF.LootDisplay:ReInitQueueLabel(self.frameId)
end

function Styling:GetShadowOffsetY()
	return G_RLF.DbAccessor:Styling(self.frameId).fontShadowOffsetY
end

function Styling:SetShadowOffsetY(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).fontShadowOffsetY = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
	G_RLF.LootDisplay:ReInitQueueLabel(self.frameId)
end

function Styling:GetRowTextSpacing()
	return G_RLF.DbAccessor:Styling(self.frameId).rowTextSpacing
end

function Styling:SetRowTextSpacing(_, value)
	G_RLF.DbAccessor:Styling(self.frameId).rowTextSpacing = value
	G_RLF.LootDisplay:UpdateRowStyles(self.frameId)
end

--- Creates a per-frame styling config handler bound to the given frame ID.
--- All handler methods route through DbAccessor:Styling(frameId), so the
--- correct per-frame (or legacy-fallback) DB path is always used.
--- @param frameId integer
--- @return RLF_StylingConfigHandlerBase
function Styling.MakeHandler(frameId)
	return setmetatable({ frameId = frameId }, { __index = Styling })
end

G_RLF.Styling = Styling
