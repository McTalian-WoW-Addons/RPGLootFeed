---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_RowItemButton: ItemButton
---@field elementFadeIn RLF_RowItemButtonElementFadeIn
---@field topLeftText RLF_RowFontString
---@field SquareBorderTop Texture
---@field SquareBorderRight Texture
---@field SquareBorderBottom Texture
---@field SquareBorderLeft Texture

--- The skins that square the icon themselves and therefore need our square
--- quality border in place of Blizzard's rounded IconBorder.
local SQUARE_BORDER_SKINS = {
	[G_RLF.IconSkin.SQUARE] = true,
	[G_RLF.IconSkin.ELLESMERE] = true,
}

---@class RLF_RowIconMixin
RLF_RowIconMixin = {}

--- The four edges of the square quality border, in a fixed order.
---@return Texture[]
function RLF_RowIconMixin:GetSquareBorderEdges()
	return {
		self.Icon.SquareBorderTop,
		self.Icon.SquareBorderRight,
		self.Icon.SquareBorderBottom,
		self.Icon.SquareBorderLeft,
	}
end

--- Swap Blizzard's rounded IconBorder for a 1px square border in the item
--- quality color.
---
--- Must run after SetItemButtonQuality/SetItem: those write the quality color
--- onto IconBorder and re-show it, so IconBorder is the authoritative source
--- for both the color and whether a border belongs here at all (Blizzard hides
--- it outright for quality-less items).  EllesmereUI's SquareIcon draws a flat
--- black border and has no quality-aware primitive, so this replaces it rather
--- than stacking on top of it.
function RLF_RowIconMixin:ApplyQualityBorder()
	local iconBorder = self.Icon.IconBorder
	if not iconBorder then
		return
	end

	local edges = self:GetSquareBorderEdges()
	if not iconBorder:IsShown() then
		-- Quality-less item: Blizzard drew no border, so neither do we.  There
		-- is also nothing left to restore, so drop the flag.
		for _, edge in ipairs(edges) do
			edge:Hide()
		end
		self.qualityBorderApplied = false
		return
	end

	local r, g, b = iconBorder:GetVertexColor()
	iconBorder:Hide()
	for _, edge in ipairs(edges) do
		edge:SetColorTexture(r or 1, g or 1, b or 1, 1)
		edge:Show()
	end
	self.qualityBorderApplied = true
end

--- Undo ApplyQualityBorder.  Rows are pooled, so the swap has to be reversible
--- when the active skin changes to one that manages the border itself (Masque,
--- ElvUI) or to none at all.
---
--- restoreIconBorder must only be set by callers that have NOT just run
--- SetItemButtonQuality.  That call decides IconBorder's visibility from the
--- new item's quality, so re-showing it afterwards would resurrect the previous
--- item's border color on a quality-less item.  StyleIcon runs without it and
--- does need the restore; UpdateIcon runs after it and must not.
---@param restoreIconBorder? boolean
function RLF_RowIconMixin:ClearQualityBorder(restoreIconBorder)
	if not self.qualityBorderApplied then
		return
	end

	for _, edge in ipairs(self:GetSquareBorderEdges()) do
		edge:Hide()
	end
	-- Only ever set when the border was shown, so restoring means showing.
	if restoreIconBorder and self.Icon.IconBorder then
		self.Icon.IconBorder:Show()
	end
	self.qualityBorderApplied = false
end

function RLF_RowIconMixin:StyleIcon()
	local changed = false

	local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)
	---@type RLF_ConfigStyling
	local stylingDb = G_RLF.DbAccessor:Styling(self.frameType)
	local iconSize = sizingDb.iconSize
	local textAlignment = stylingDb.textAlignment
	local iconOnLeft = textAlignment ~= G_RLF.TextAlignment.RIGHT
	local iconSkin = G_RLF.IconSkinResolver:Resolve(stylingDb.iconSkin)

	if self.cachedIconSize ~= iconSize then
		self.cachedIconSize = iconSize
		changed = true
	end

	if self.cachedIconTextAlignment ~= textAlignment then
		self.cachedIconTextAlignment = textAlignment
		changed = true
	end

	if self.cachedIconSkin ~= iconSkin then
		self.cachedIconSkin = iconSkin
		changed = true
	end

	if changed then
		self.Icon:ClearAllPoints()
		iconSize = G_RLF.PerfPixel.PScale(iconSize)
		self.Icon:SetSize(iconSize, iconSize)
		self.Icon.IconBorder:SetSize(iconSize, iconSize)
		local anchor, xOffset = "LEFT", iconSize / 4
		if not iconOnLeft then
			anchor, xOffset = "RIGHT", -xOffset
		end
		-- Masque group membership is sticky -- a button cannot cleanly leave a
		-- group mid-session -- so only enroll when Masque is the active skin.
		-- Rows are pooled and created lazily, so switching to Masque later
		-- still enrolls newly created rows.
		if iconSkin == G_RLF.IconSkin.MASQUE then
			G_RLF.iconGroup:AddButton(self.Icon)
		end
		self.Icon:SetPoint(anchor, xOffset, 0)

		-- One physical pixel regardless of UI scale, same as the row highlight
		-- borders.  The edges are anchored to the button, so they follow icon
		-- size changes without re-anchoring.
		local borderSize = G_RLF.PerfPixel.PScale(1)
		self.Icon.SquareBorderTop:SetHeight(borderSize)
		self.Icon.SquareBorderBottom:SetHeight(borderSize)
		self.Icon.SquareBorderLeft:SetWidth(borderSize)
		self.Icon.SquareBorderRight:SetWidth(borderSize)

		-- A skin change reaches an on-screen row through here, not UpdateIcon,
		-- so hand the Blizzard border back rather than leaving the icon bare
		-- until the row is recycled.
		if not SQUARE_BORDER_SKINS[iconSkin] then
			self:ClearQualityBorder(true)
		end
	end
	self.Icon:SetShown(self.icon ~= nil)
end

function RLF_RowIconMixin:UpdateIcon(key, icon, quality)
	self.icon = icon

	RunNextFrame(function()
		---@type RLF_ConfigSizing
		local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)
		local stylingDb = G_RLF.DbAccessor:Styling(self.frameType)
		local iconSize = G_RLF.PerfPixel.PScale(sizingDb.iconSize)

		if not quality then
			self.Icon:SetItem(self.link)
		else
			self.Icon:SetItemButtonTexture(icon)
			self.Icon:SetItemButtonQuality(quality, self.link)
		end

		if self.Icon.IconOverlay then
			self.Icon.IconOverlay:SetSize(iconSize, iconSize)
		end
		if self.Icon.ProfessionQualityOverlay then
			self.Icon.ProfessionQualityOverlay:SetSize(iconSize, iconSize)
		end

		if stylingDb.enableTopLeftIconText and self.topLeftText and self.topLeftColor then
			self.Icon.topLeftText:SetText(self.topLeftText)
			if stylingDb.topLeftIconTextUseQualityColor then
				self.Icon.topLeftText:SetTextColor(unpack(self.topLeftColor))
			else
				self.Icon.topLeftText:SetTextColor(unpack(stylingDb.topLeftIconTextColor))
			end
			self.Icon.topLeftText:Show()
		else
			self.Icon.topLeftText:Hide()
		end

		self.Icon:ClearDisabledTexture()
		self.Icon:ClearNormalTexture()
		self.Icon:ClearPushedTexture()
		self.Icon:ClearHighlightTexture()

		-- Exactly one skinner runs.  Resolve guarantees the branch's dependency
		-- is loaded, so no re-guarding is needed here.
		local iconSkin = G_RLF.IconSkinResolver:Resolve(stylingDb.iconSkin)

		-- Rows are pooled and SetTexture does not reset texture coordinates, so
		-- a crop outlives both the loot event and the row's trip through the
		-- pool.  Undo it when neither cropping skin is active -- but only ever
		-- undo our own crop; Masque and ElvUI manage their texcoords themselves.
		if not SQUARE_BORDER_SKINS[iconSkin] and self.squareCropApplied then
			self.Icon.icon:SetTexCoord(0, 1, 0, 1)
			self.squareCropApplied = false
		end

		if iconSkin == G_RLF.IconSkin.MASQUE then
			-- Masque reskinning (may be costly, consider reducing frequency)
			G_RLF.iconGroup:ReSkin(self.Icon)
		elseif iconSkin == G_RLF.IconSkin.ELVUI then
			G_RLF.ElvSkins:HandleItemButton(self.Icon, true)
			G_RLF.ElvSkins:HandleIconBorder(self.Icon.IconBorder)
		elseif iconSkin == G_RLF.IconSkin.ELLESMERE then
			-- Resolve only returns ELLESMERE once the facade has arrived, so
			-- the handle needs no guard here.  Dot call -- the facade is a
			-- plain table of functions.  Idempotent, and it no-ops on masked
			-- icons, so it is safe to re-run every update.
			--
			-- Deliberately no parent argument: passing one makes EUI draw a
			-- flat black 1px border, which it has no way to tint by item
			-- quality.  ApplyQualityBorder below draws that border instead.
			G_RLF.EUISkin.SquareIcon(self.Icon.icon)
			-- SquareIcon skips masked icons, and we never mask row icons, so
			-- treat the crop as applied and let the undo above reverse it.
			self.squareCropApplied = true
		elseif iconSkin == G_RLF.IconSkin.SQUARE then
			-- Crop the baked bevel.  A masked texture rejects SetTexCoord
			-- outright (hard Lua error), so leave those native -- we do not
			-- mask row icons today, but the guard is one call.
			local icon = self.Icon.icon
			if icon and not (icon.GetNumMaskTextures and icon:GetNumMaskTextures() > 0) then
				icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				self.squareCropApplied = true
			end
		end

		-- Runs last: the skinners above leave Blizzard's rounded IconBorder in
		-- place, and Masque/ElvUI own the border on their own branches.
		-- Keyed off the crop rather than the skin so a square border is never
		-- drawn around a still-round icon -- ELLESMERE resolves even when the
		-- EUI facade never arrives, and SQUARE bails on masked icons.
		if self.squareCropApplied then
			self:ApplyQualityBorder()
		else
			self:ClearQualityBorder()
		end
	end)
end

G_RLF.RLF_RowIconMixin = RLF_RowIconMixin
