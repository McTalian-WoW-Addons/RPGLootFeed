---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_RowItemButton: ItemButton
---@field elementFadeIn RLF_RowItemButtonElementFadeIn
---@field topLeftText RLF_RowFontString

---@class RLF_RowIconMixin
RLF_RowIconMixin = {}

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
		-- pool.  Undo it when Square is no longer active -- but only ever undo
		-- our own crop; Masque and ElvUI manage their texcoords themselves.
		if iconSkin ~= G_RLF.IconSkin.SQUARE and self.squareCropApplied then
			self.Icon.icon:SetTexCoord(0, 1, 0, 1)
			self.squareCropApplied = false
		end

		if iconSkin == G_RLF.IconSkin.MASQUE then
			-- Masque reskinning (may be costly, consider reducing frequency)
			G_RLF.iconGroup:ReSkin(self.Icon)
		elseif iconSkin == G_RLF.IconSkin.ELVUI then
			G_RLF.ElvSkins:HandleItemButton(self.Icon, true)
			G_RLF.ElvSkins:HandleIconBorder(self.Icon.IconBorder)
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
	end)
end

G_RLF.RLF_RowIconMixin = RLF_RowIconMixin
