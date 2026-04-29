---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_LootDisplayRow: BackdropTemplate, RLF_RowAnimationMixin, RLF_RowTooltipMixin, RLF_RowTextMixin, RLF_RowBackdropMixin, RLF_RowScriptedEffectsMixin, RLF_RowIconMixin, RLF_RowUnitPortraitMixin
---@field key string
---@field frameType G_RLF.Frames
---@field amount number
---@field icon string
---@field link string
---@field secondaryText string
---@field unit string
---@field type string
---@field highlight boolean
---@field isHistoryMode boolean
---@field pendingElement table
---@field updatePending boolean
---@field waiting boolean
---@field isClickThrough boolean
---@field isPinned boolean
---@field pinnedFrameOffset number
---@field ShiftAnimation RLF_RowShiftAnimationGroup
---@field _next RLF_LootDisplayRow
---@field _prev RLF_LootDisplayRow
---@field Background Texture
---@field HighlightBGOverlay Texture
---@field UnitPortrait RLF_RowTexture
---@field RLFUser RLF_RowTexture
---@field PrimaryText RLF_RowFontString
---@field SecondaryText RLF_RowFontString
---@field ItemCountText RLF_RowFontString
---@field TopBorder RLF_RowBorderTexture
---@field RightBorder RLF_RowBorderTexture
---@field BottomBorder RLF_RowBorderTexture
---@field LeftBorder RLF_RowBorderTexture
---@field ClickableButton Button
---@field Icon RLF_RowItemButton
---@field glowTexture table
---@field EnterAnimation RLF_RowEnterAnimationGroup
---@field ExitAnimation RLF_RowExitAnimationGroup
LootDisplayRowMixin = {}

local function enqueuePendingElement(self, element)
	if not self.pendingElements then
		self.pendingElements = {}
	end
	table.insert(self.pendingElements, element)
	self.pendingElement = self.pendingElements[1]
	self.updatePending = true
end

local defaultColor = { 1, 1, 1, 1 }
function LootDisplayRowMixin:Init()
	self.waiting = false
	if self:IsStaggeredEnter() then
		self.waiting = true
	end
	self.updatePending = false
	self.pendingElements = nil
	self.pendingElement = nil
	self.quality = nil

	self.ClickableButton:Hide()
	---@type ScriptRegion[]
	local textures = {
		self.ClickableButton:GetRegions() --[[@as ScriptRegion[] ]],
	}
	for _, region in ipairs(textures) do
		if region:GetObjectType() == "Texture" then
			region:Hide()
		end
	end

	self.ClickableButton:SetScript("OnEnter", nil)
	self.ClickableButton:SetScript("OnLeave", nil)
	self.ClickableButton:SetScript("OnMouseUp", nil)
	self.ClickableButton:SetScript("OnEvent", nil)
	self.PrimaryText:SetTextColor(unpack(defaultColor))
	self.SecondaryText:SetTextColor(unpack(defaultColor))

	-- Sample rows should never fade out
	if self.isSampleRow then
		self.showForSeconds = math.pow(2, 19) -- Never fade out
	else
		self.showForSeconds = G_RLF.DbAccessor:Animations(self.frameType).exit.fadeOutDelay
	end

	local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)

	self:SetSize(sizingDb.feedWidth, sizingDb.rowHeight)
	self.RLFUser:SetTexture("Interface/AddOns/RPGLootFeed/Icons/logo.blp")
	self.RLFUser:SetDrawLayer("OVERLAY")
	self.RLFUser:Hide()
	self:CreateTopLeftText()
	self.Icon.topLeftText:Hide()
	self.Icon.IconBorder:SetVertexColor(G_RLF.noQualColor.r, G_RLF.noQualColor.g, G_RLF.noQualColor.b, 1)
	self:CreatePrimaryLineLayout()
	self:CreateSecondaryLineLayout()
	self:StyleBackground()
	self:StyleRowBackdrop()
	self:StyleExitAnimation()
	self:StyleEnterAnimation()
	self:StyleElementFadeIn()
	self:StyleHighlightBorder()
	self:StyleTimerBar()
	RunNextFrame(function()
		self:SetUpHoverEffect()
	end)
end

function LootDisplayRowMixin:Reset()
	self:Hide()
	self:SetAlpha(1)
	self:ClearAllPoints()

	-- Reset row-specific data
	self.key = nil
	self.amount = nil
	self.quality = nil
	self.icon = nil
	self.link = nil
	self.secondaryText = nil
	self.unit = nil
	self.type = nil
	self.highlight = nil
	self.isHistoryMode = false
	self.isSampleRow = false
	self.hasElementFadeOverride = false
	self.sampleTooltipText = nil
	self.pendingElement = nil
	self.pendingElements = nil
	self.updatePending = false
	self.waiting = false
	self.isCustomLink = false
	self.customBehavior = nil
	self.amountTextFn = nil
	self.itemCountFn = nil
	self.logFn = nil
	self.onReleased = nil
	self.isPinned = false
	self.pinnedFrameOffset = nil
	self.hasMouseOver = false

	-- Reset UI elements that were part of the template
	self.TopBorder:SetAlpha(0)
	self.RightBorder:SetAlpha(0)
	self.BottomBorder:SetAlpha(0)
	self.LeftBorder:SetAlpha(0)

	self:CreateTopLeftText()
	self.Icon:Reset()
	self.Icon.IconBorder:SetVertexColor(G_RLF.noQualColor.r, G_RLF.noQualColor.g, G_RLF.noQualColor.b, 1)
	self.Icon.NormalTexture:SetTexture(nil)
	self.Icon.HighlightTexture:SetTexture(nil)
	self.Icon.PushedTexture:SetTexture(nil)
	self.Icon.topLeftText:Hide()
	self.Icon:SetScript("OnEnter", nil)
	self.Icon:SetScript("OnLeave", nil)
	self.Icon:SetScript("OnMouseUp", nil)
	self.Icon:SetScript("OnEvent", nil)

	self:StopAllAnimations()

	self:HideCoinDisplay()
	self:HideSecondaryCoinDisplay()
	self._coinData = nil
	self._secondaryCoinData = nil

	if self.glowTexture then
		self.glowTexture:Hide()
		self.glowTexture:SetScale(1)
		self.glowTexture:SetAlpha(0.75)
	end
	self._glowWasPlaying = false
	if self.HighlightBGOverlay then
		self.HighlightBGOverlay:SetAlpha(0)
	end
	if self.leftSideTexture then
		self.leftSideTexture:Hide()
	end
	if self.rightSideTexture then
		self.rightSideTexture:Hide()
	end

	self.UnitPortrait:SetTexture(nil)
	self.PrimaryText:SetText(nil)
	self.PrimaryText:SetTextColor(unpack(defaultColor))
	self._primaryR, self._primaryG, self._primaryB, self._primaryA = nil, nil, nil, nil
	self.SecondaryText:SetText(nil)
	self.SecondaryText:SetTextColor(unpack(defaultColor))
	self._secondaryR, self._secondaryG, self._secondaryB, self._secondaryA = nil, nil, nil, nil
	self.SecondaryText:Hide()
	self.SecondaryLineLayout:Hide()
	self.AmountText:SetText(nil)
	self.AmountText:Hide()
	self.ItemCountText:SetText(nil)
	self.ItemCountText:Hide()
	self.ClickableButton:Hide()
	---@type ScriptRegion[]
	local textures = {
		self.ClickableButton:GetRegions() --[[@as ScriptRegion[] ]],
	}
	for _, region in ipairs(textures) do
		if region:GetObjectType() == "Texture" then
			region:Hide()
		end
	end

	self.ClickableButton:SetScript("OnEnter", nil)
	self.ClickableButton:SetScript("OnLeave", nil)
	self.ClickableButton:SetScript("OnMouseUp", nil)
	self.ClickableButton:SetScript("OnEvent", nil)
end

--- Enable or disable mouse interaction on this row and its interactive children.
--- @param enabled boolean true = click-through (mouse disabled), false = interactive
function LootDisplayRowMixin:SetClickThrough(enabled)
	self.isClickThrough = enabled
	self:EnableMouse(not enabled)
	self.ClickableButton:EnableMouse(not enabled)
	if self.Icon then
		self.Icon:EnableMouse(not enabled)
	end
	if enabled then
		-- Unpin before the hasMouseOver cleanup.  OnLeave will not fire
		-- when EnableMouse is toggled, so we must unpin explicitly.
		if self.isPinned then
			local frame = self:GetParent() --[[@as RLF_LootDisplayFrame]]
			if frame then
				frame:ReleasePin(self)
			end
		end
		-- Clean up hover state so ExitAnimation isn't left paused and
		-- tooltips don't stay visible after we disable the mouse.
		if self.hasMouseOver then
			self.hasMouseOver = false
			if self.HighlightFadeIn and self.HighlightFadeIn:IsPlaying() then
				self.HighlightFadeIn:Stop()
			end
			if self.HighlightFadeOut then
				self.HighlightFadeOut:Play()
			end
			if not self.isHistoryMode then
				self.ExitAnimation:Play()
				self:StartTimerBar()
			end
			GameTooltip:Hide()
		end
	end
end

--- Lock this row at its current visual position so it is not moved by
--- Phase 2's FLIP repositioning when nearby rows exit.
--- @param frame RLF_LootDisplayFrame
function LootDisplayRowMixin:PinPosition(frame)
	G_RLF:LogDebug(
		"[PIN] PinPosition: key="
			.. tostring(self.key)
			.. " isPinned="
			.. tostring(self.isPinned)
			.. " pinOnHover="
			.. tostring(G_RLF.db.global.interactions.pinOnHover),
		addonName
	)
	if self.isPinned then
		return
	end
	if not G_RLF.db.global.interactions.pinOnHover then
		return
	end

	local frameEdgeY = (frame.vertDir == "BOTTOM") and frame:GetBottom() or frame:GetTop()
	local edgeY = (frame.vertDir == "BOTTOM") and self:GetBottom() or self:GetTop()

	self.pinnedFrameOffset = edgeY - frameEdgeY
	self:ClearAllPoints()
	self:SetPoint(frame.vertDir, frame, frame.vertDir, 0, self.pinnedFrameOffset)

	self.isPinned = true
	frame.hasPinnedRow = true
	G_RLF:LogDebug(
		"[PIN] PinPosition: PINNED key=" .. tostring(self.key) .. " offset=" .. tostring(self.pinnedFrameOffset),
		addonName
	)
end

function LootDisplayRowMixin:Styles()
	self:StyleBackground()
	self:StyleRowBackdrop()
	self:StyleIcon()
	RunNextFrame(function()
		self:StyleIconHighlight()
	end)
	self:StyleUnitPortrait()
	self:StyleText()
	self:HandlerOnRightClick()
end

--- Bootstrap a row from an RLF_LootElement
--- @param element RLF_LootElement
function LootDisplayRowMixin:BootstrapFromElement(element)
	local key = element.key
	local textFn = element.textFn
	local secondaryTextFn = element.secondaryTextFn or function()
		return ""
	end
	local icon = element.icon
	local quantity = element.quantity
	local quality = element.quality
	local r, g, b, a = element.r, element.g, element.b, element.a
	self.logFn = element.logFn
	local isLink = element.isLink
	local unit = element.unit
	local highlight = element.highlight
	self.isSampleRow = element.isSampleRow or false
	self.sampleTooltipText = element.sampleTooltipText or nil
	self.itemCount = element.itemCount
	self.itemCountFn = element.itemCountFn
	self.elementSecondaryText = element.secondaryText or nil
	---@type ColorMixin|nil
	self.elementSecondaryTextColor = element.secondaryTextColor or nil
	self.isCustomLink = element.isCustomLink or false
	self.customBehavior = element.customBehavior
	self.amountTextFn = element.amountTextFn
	local text
	-- Resolve the effective display duration for this element on this specific frame.
	-- element.showForSeconds (if set) takes highest priority; otherwise check the
	-- frame's per-quality duration override for itemLoot rows.
	local effectiveShowForSeconds = element.showForSeconds
	if not effectiveShowForSeconds and element.filterItemQuality ~= nil then
		local frameConfig = G_RLF.db.global.frames[self.frameType]
		local featureCfg = frameConfig and frameConfig.features and frameConfig.features.itemLoot
		local qualSettings = featureCfg and (featureCfg.itemQualitySettings or {})[element.filterItemQuality]
		if qualSettings and qualSettings.duration > 0 then
			effectiveShowForSeconds = qualSettings.duration
		end
	end
	if element.isSampleRow or (effectiveShowForSeconds ~= nil and effectiveShowForSeconds ~= self.showForSeconds) then
		self.showForSeconds = effectiveShowForSeconds
		self.hasElementFadeOverride = not element.isSampleRow
		self:StyleExitAnimation()
	end

	if unit then
		key = unit .. "_" .. key
		self.unit = unit
	end

	self.key = key
	self.amount = quantity
	self.type = element.type
	self.quality = quality
	self.topLeftText = element.topLeftText
	self.topLeftColor = element.topLeftColor

	if isLink then
		-- Store the full untruncated link.  LayoutPrimaryLine() handles display
		-- truncation natively via PrimaryText:SetWidth() + SetWordWrap(false).
		self.link = textFn()
		text = textFn(0, self.link)
		self:SetupTooltip()
	else
		text = textFn()
	end

	if icon then
		self:StyleText()
		self:UpdateIcon(key, icon, quality)
	end

	-- Negative amounts always shown in red
	if self.amount ~= nil and self.amount < 0 then
		r, g, b, a = 1, 0, 0, 0.8
	end

	self:UpdateSecondaryText(secondaryTextFn)
	self:UpdateStyles()
	self:ShowText(text, r, g, b, a)
	local amountText = self.amountTextFn and self.amountTextFn(0) or ""
	self:ShowAmountText(amountText, r or 1, g or 1, b or 1, a or 1)

	-- Primary coin display (real Textures replacing |T| markup — no animation jank)
	if element.coinDataFn then
		local cg, cs, cc = element.coinDataFn(0)
		if cg or cs or cc then
			self:UpdateCoinDisplay(cg or 0, cs or 0, cc or 0)
			self:LayoutPrimaryLine()
		else
			self:HideCoinDisplay()
		end
	else
		self:HideCoinDisplay()
	end

	-- Secondary coin display (vendor/AH price or money total — real Textures)
	if element.secondaryCoinDataFn then
		local sg, ss, sc, satl, ssz, sgt = element.secondaryCoinDataFn(0)
		if sg or ss or sc or satl then
			self:UpdateSecondaryCoinDisplay(sg or 0, ss or 0, sc or 0, satl, ssz, sgt)
		else
			self:HideSecondaryCoinDisplay()
		end
	else
		self:HideSecondaryCoinDisplay()
	end

	self.highlight = highlight
	RunNextFrame(function()
		self:Enter()
		self:UpdateItemCount()
	end)
	self:LogRow(self.logFn, text, true)
end

function LootDisplayRowMixin:LogRow(logFn, text, new)
	if logFn then
		RunNextFrame(function()
			logFn(text, self.amount, new)
		end)
	end
end

function LootDisplayRowMixin:UpdateStyles()
	self:Styles()
	if self.icon and G_RLF.iconGroup then
		G_RLF.iconGroup:ReSkin(self.Icon)
	end
end

function LootDisplayRowMixin:UpdateQuantity(element)
	local isProcessingPendingHead = self.pendingElements and self.pendingElements[1] == element
	if isProcessingPendingHead then
		table.remove(self.pendingElements, 1)
		self.pendingElement = self.pendingElements[1]
		self.updatePending = self.pendingElement ~= nil
	end

	local shouldDefer = false
	if self.amount == nil then
		shouldDefer = true
	elseif self.updatePending and not isProcessingPendingHead then
		shouldDefer = true
	elseif self.PrimaryText:GetAlpha() < 1 then
		shouldDefer = true
	elseif self.EnterAnimation and self.EnterAnimation:IsPlaying() then
		shouldDefer = true
	elseif self.ElementFadeInAnimation and self.ElementFadeInAnimation:IsPlaying() then
		shouldDefer = true
	end
	if shouldDefer then
		enqueuePendingElement(self, element)
		return
	end

	self.logFn = element.logFn
	-- Update existing entry
	local oldAmount = self.amount
	local text = element.textFn(oldAmount, self.link)
	self.itemCount = element.itemCount
	local netAmount = oldAmount + element.quantity
	-- Wrap the incoming itemCountFn so it receives the *accumulated* netAmount
	-- rather than just the per-element delta captured in its closure.
	if element.itemCountFn then
		local baseFn = element.itemCountFn
		local net = netAmount
		self.itemCountFn = function()
			return baseFn(net)
		end
	else
		self.itemCountFn = self.itemCountFn
	end
	local r, g, b, a = element.r, element.g, element.b, element.a
	-- Allow the element to recompute color based on the net accumulated quantity
	if element.colorFn then
		r, g, b, a = element.colorFn(netAmount)
	end
	-- Negative net amounts always shown in red
	if netAmount < 0 then
		r, g, b, a = 1, 0, 0, 0.8
	end
	self.amount = netAmount

	self:UpdateSecondaryText(element.secondaryTextFn)
	self:UpdateItemCount()
	self:ShowText(text, r, g, b, a)
	local amountText = element.amountTextFn and element.amountTextFn(oldAmount) or ""
	self:ShowAmountText(amountText, r or 1, g or 1, b or 1, a or 1)

	-- Primary coin display
	if element.coinDataFn then
		local cg, cs, cc = element.coinDataFn(oldAmount)
		if cg or cs or cc then
			self:UpdateCoinDisplay(cg or 0, cs or 0, cc or 0)
			self:LayoutPrimaryLine()
		else
			self:HideCoinDisplay()
		end
	else
		self:HideCoinDisplay()
	end

	-- Secondary coin display
	if element.secondaryCoinDataFn then
		local sg, ss, sc, satl, ssz, sgt = element.secondaryCoinDataFn(oldAmount)
		if sg or ss or sc or satl then
			self:UpdateSecondaryCoinDisplay(sg or 0, ss or 0, sc or 0, satl, ssz, sgt)
		else
			self:HideSecondaryCoinDisplay()
		end
	else
		self:HideSecondaryCoinDisplay()
	end

	if not G_RLF.DbAccessor:Animations(self.frameType).update.disableHighlight then
		self.HighlightAnimation:Stop()
		self.HighlightAnimation:Play()
	end
	-- Do not restart the exit animation while the row is pinned (user hovering).
	-- PinPosition stops the animation; it will be resumed when the mouse leaves.
	if not self.isPinned and self.ExitAnimation:IsPlaying() then
		self.ExitAnimation:Stop()
		self.ExitAnimation:Play()
		self:StartTimerBar()
	end

	self:LogRow(self.logFn, text, false)

	if self.pendingElement ~= nil then
		self:UpdateQuantity(self.pendingElement)
	end
end

function LootDisplayRowMixin:UpdatePosition(frame)
	-- Position the new row at the bottom (or top if growing down)
	local vertDir, opposite, yOffset = frame.vertDir, frame.opposite, frame.yOffset
	self:ClearAllPoints()
	if self._prev then
		self:SetPoint(vertDir, self._prev, opposite, 0, yOffset)
		self.anchorPoint = vertDir
		self.opposite = opposite
		self.yOffset = yOffset
		self.anchorTo = self._prev
		-- Use a gap of 10 levels per row so that a row's child frames
		-- (ItemButton, PrimaryLineLayout, etc.) never collide with an
		-- adjacent row's base level.  WoW auto-raises child frames
		-- above their parent, so with a gap of 1 the children of row N
		-- can overlap with row N-1's backdrop-border level.
		self:SetFrameLevel(self._prev:GetFrameLevel() - 10)
	else
		self:SetPoint(vertDir, frame, vertDir)
		self.anchorPoint = vertDir
		self.opposite = nil
		self.yOffset = nil
		self.anchorTo = frame
		self:SetFrameLevel(500)
	end
end

function LootDisplayRowMixin:UpdateNeighborPositions(frame)
	local vertDir, opposite, yOffset = frame.vertDir, frame.opposite, frame.yOffset
	local _next = self._next
	local _prev = self._prev

	-- Do not disturb a pinned row's anchor.  It is visually fixed; it will
	-- re-anchor itself in ReleasePin → UpdatePosition when the hover ends.
	if _next and not _next.isPinned then
		_next:ClearAllPoints()
		if _prev then
			_next:SetPoint(vertDir, _prev, opposite, 0, yOffset)
			_next.anchorPoint = vertDir
			_next.opposite = opposite
			_next.yOffset = yOffset
			_next.anchorTo = _prev
			_next:SetFrameLevel(_prev:GetFrameLevel() - 10)
		else
			_next:SetPoint(vertDir, frame, vertDir)
			_next.anchorPoint = vertDir
			_next.opposite = nil
			_next.yOffset = nil
			_next.anchorTo = frame
			_next:SetFrameLevel(500)
		end
	end
end

function LootDisplayRowMixin:IsFading()
	return self.ExitAnimation:IsPlaying() and not self.ExitAnimation.fadeOut:IsDelaying()
end

function LootDisplayRowMixin:Dump()
	local prevKey, nextKey
	if self._prev then
		prevKey = self._prev.key or "NONE"
	else
		prevKey = "prev nil"
	end

	if self._next then
		nextKey = self._next.key or "NONE"
	else
		nextKey = "next nil"
	end

	return format(
		"{name=%s, key=%s, amount=%s, PrimaryText=%s, _prev.key=%s, _next.key=%s}",
		self:GetDebugName(),
		self.key or "NONE",
		self.amount or "NONE",
		self.PrimaryText:GetText() or "NONE",
		prevKey,
		nextKey
	)
end

function LootDisplayRowMixin:UpdateWithHistoryData(data)
	self:Reset()
	self.isHistoryMode = true
	self.key = data.key
	self.amount = data.amount
	self.link = data.link
	self.quality = data.quality
	self.unit = data.unit

	-- Set secondary text before StyleText/ShowText so layout considers it
	---@type RLF_ConfigStyling
	local stylingDb = G_RLF.DbAccessor:Styling(self.frameType)
	if data.unit and data.secondaryText and stylingDb.enabledSecondaryRowText then
		self.secondaryText = data.secondaryText
	end

	-- Setup tooltip for linkable items (must happen before LayoutPrimaryLine
	-- sizes the ClickableButton, but after self.link is set)
	if data.link then
		self:SetupTooltip(true)
	end

	-- UpdateIcon sets self.icon, which StyleText needs for text positioning
	if data.icon then
		self:UpdateIcon(self.key, data.icon, self.quality)
	end

	self:UpdateStyles()

	-- ShowText sets rawPrimaryText, triggers LayoutPrimaryLine (which positions
	-- the ClickableButton over the text for tooltip interaction), and handles
	-- secondary text layout.
	self:ShowText(data.rowText, unpack(data.textColor))

	-- Restore coin display for money rows (primary coin textures).
	if data.coinData then
		self:UpdateCoinDisplay(data.coinData[1], data.coinData[2], data.coinData[3])
		self:LayoutPrimaryLine()
	end

	-- Restore secondary coin display (vendor/AH price, money total, paragon icon).
	if data.secondaryCoinData then
		self:UpdateSecondaryCoinDisplay(
			data.secondaryCoinData[1],
			data.secondaryCoinData[2],
			data.secondaryCoinData[3],
			data.secondaryCoinData[4],
			data.secondaryCoinData[5],
			data.secondaryCoinData[6]
		)
	end

	-- Apply secondary text color after ShowText (ShowText only shows/hides it)
	if data.unit and data.secondaryText and stylingDb.enabledSecondaryRowText then
		self.SecondaryText:SetTextColor(unpack(data.secondaryTextColor))
	end
end
