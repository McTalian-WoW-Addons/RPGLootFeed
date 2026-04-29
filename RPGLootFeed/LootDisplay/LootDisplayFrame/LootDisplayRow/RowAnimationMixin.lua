---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_RowItemButtonElementFadeIn
---@field icon Alpha
---@field IconBorder Alpha
---@field IconOverlay Alpha
---@field Stock Alpha
---@field Count Alpha
---@field TopLeftText Alpha

---@class RLF_RowTexture: Texture
---@field elementFadeIn Alpha

---@class RLF_RowBorderTexture: Texture
---@field fadeIn Alpha
---@field fadeOut Alpha

---@class RLF_RowExitAnimationGroup: AnimationGroup
---@field noop Animation
---@field fadeOut Alpha

---@class RLF_RowEnterAnimationGroup: AnimationGroup
---@field noop Animation
---@field fadeIn Alpha
---@field slideIn Translation

---@class RLF_RowShiftAnimationGroup: AnimationGroup
---@field translation Translation

---@class RLF_RowAnimationMixin
---@field ShiftAnimation RLF_RowShiftAnimationGroup
---@field _shiftFinalFrameOffset number
---@field _shiftFinalFrameLevel number
RLF_RowAnimationMixin = {}

function RLF_RowAnimationMixin:StopAllAnimations()
	if self.glowAnimationGroup then
		self.glowAnimationGroup:Stop()
		if self.glowTexture then
			self.glowTexture:SetScale(1)
		end
	end
	if self.EnterAnimation then
		self.EnterAnimation:Stop()
	end
	if self.ExitAnimation then
		self.ExitAnimation:Stop()
	end
	if self.HighlightFadeIn then
		self.HighlightFadeIn:Stop()
	end
	if self.HighlightFadeOut then
		self.HighlightFadeOut:Stop()
	end
	if self.HighlightAnimation then
		self.HighlightAnimation:Stop()
	end
	if self.ElementFadeInAnimation then
		self.ElementFadeInAnimation:Stop()
	end
	if self.ShiftAnimation then
		self.ShiftAnimation:Stop()
		-- If the glow was paused for a shift that got interrupted, restart it
		if self._glowWasPlaying and self.glowAnimationGroup then
			self.glowAnimationGroup:Play()
		end
		self._glowWasPlaying = false
	end

	-- Stop scripted effects
	self:StopScriptedEffects()

	-- Stop timer bar
	self:ResetTimerBar()
end

function RLF_RowAnimationMixin:StyleElementFadeIn()
	-- Fade in all of the UI elements for the row
	-- Icon, PrimaryText, ItemCountText, SecondaryText, UnitPortrait
	local fadeInDuration = 0.2
	local fadeInSmoothing = "IN_OUT"

	if not self.ElementFadeInAnimation then
		self.ElementFadeInAnimation = self:CreateAnimationGroup()
		self.ElementFadeInAnimation:SetToFinalAlpha(true)
		self.ElementFadeInAnimation:SetScript("OnFinished", function()
			self:HighlightIcon()
			self:ResetFadeOut()
			if self.updatePending then
				self:UpdateQuantity(self.pendingElement)
			end
		end)
	end

	-- Icon
	if not self.Icon.elementFadeIn then
		self.Icon.elementFadeIn = {
			icon = self.ElementFadeInAnimation:CreateAnimation("Alpha"),
			IconBorder = self.ElementFadeInAnimation:CreateAnimation("Alpha"),
			IconOverlay = self.ElementFadeInAnimation:CreateAnimation("Alpha"),
			Stock = self.ElementFadeInAnimation:CreateAnimation("Alpha"),
			Count = self.ElementFadeInAnimation:CreateAnimation("Alpha"),
			TopLeftText = self.ElementFadeInAnimation:CreateAnimation("Alpha"),
		}
		self.Icon.elementFadeIn.icon:SetTarget(self.Icon.icon)
		self.Icon.elementFadeIn.icon:SetFromAlpha(0)
		self.Icon.elementFadeIn.icon:SetToAlpha(1)
		self.Icon.elementFadeIn.icon:SetSmoothing(fadeInSmoothing)
		self.Icon.elementFadeIn.IconBorder:SetTarget(self.Icon.IconBorder)
		self.Icon.elementFadeIn.IconBorder:SetFromAlpha(0)
		self.Icon.elementFadeIn.IconBorder:SetToAlpha(1)
		self.Icon.elementFadeIn.IconBorder:SetSmoothing(fadeInSmoothing)
		self.Icon.elementFadeIn.IconOverlay:SetTarget(self.Icon.IconOverlay)
		self.Icon.elementFadeIn.IconOverlay:SetFromAlpha(0)
		self.Icon.elementFadeIn.IconOverlay:SetToAlpha(1)
		self.Icon.elementFadeIn.IconOverlay:SetSmoothing(fadeInSmoothing)
		self.Icon.elementFadeIn.Stock:SetTarget(self.Icon.Stock)
		self.Icon.elementFadeIn.Stock:SetFromAlpha(0)
		self.Icon.elementFadeIn.Stock:SetToAlpha(1)
		self.Icon.elementFadeIn.Stock:SetSmoothing(fadeInSmoothing)
		self.Icon.elementFadeIn.Count:SetTarget(self.Icon.Count)
		self.Icon.elementFadeIn.Count:SetFromAlpha(0)
		self.Icon.elementFadeIn.Count:SetToAlpha(1)
		self.Icon.elementFadeIn.Count:SetSmoothing(fadeInSmoothing)
		self.Icon.elementFadeIn.TopLeftText:SetTarget(self.Icon.topLeftText)
		self.Icon.elementFadeIn.TopLeftText:SetFromAlpha(0)
		self.Icon.elementFadeIn.TopLeftText:SetToAlpha(1)
		self.Icon.elementFadeIn.TopLeftText:SetSmoothing(fadeInSmoothing)
	end
	self.Icon.elementFadeIn.icon:SetDuration(fadeInDuration)
	self.Icon.elementFadeIn.IconBorder:SetDuration(fadeInDuration)
	self.Icon.elementFadeIn.IconOverlay:SetDuration(fadeInDuration)
	self.Icon.elementFadeIn.Stock:SetDuration(fadeInDuration)
	self.Icon.elementFadeIn.Count:SetDuration(fadeInDuration)
	self.Icon.elementFadeIn.TopLeftText:SetDuration(fadeInDuration)

	-- PrimaryText
	if not self.PrimaryText.elementFadeIn then
		self.PrimaryText.elementFadeIn = self.ElementFadeInAnimation:CreateAnimation("Alpha")
		self.PrimaryText.elementFadeIn:SetTarget(self.PrimaryText)
		self.PrimaryText.elementFadeIn:SetFromAlpha(0)
		self.PrimaryText.elementFadeIn:SetToAlpha(1)
		self.PrimaryText.elementFadeIn:SetSmoothing(fadeInSmoothing)
	end
	self.PrimaryText.elementFadeIn:SetDuration(fadeInDuration)

	-- AmountText (quantity suffix — must fade in sync with PrimaryText)
	if not self.AmountText.elementFadeIn then
		self.AmountText.elementFadeIn = self.ElementFadeInAnimation:CreateAnimation("Alpha")
		self.AmountText.elementFadeIn:SetTarget(self.AmountText)
		self.AmountText.elementFadeIn:SetFromAlpha(0)
		self.AmountText.elementFadeIn:SetToAlpha(1)
		self.AmountText.elementFadeIn:SetSmoothing(fadeInSmoothing)
	end
	self.AmountText.elementFadeIn:SetDuration(fadeInDuration)

	-- ItemCountText
	if not self.ItemCountText.elementFadeIn then
		self.ItemCountText.elementFadeIn = self.ElementFadeInAnimation:CreateAnimation("Alpha")
		self.ItemCountText.elementFadeIn:SetTarget(self.ItemCountText)
		self.ItemCountText.elementFadeIn:SetFromAlpha(0)
		self.ItemCountText.elementFadeIn:SetToAlpha(1)
		self.ItemCountText.elementFadeIn:SetSmoothing(fadeInSmoothing)
	end
	self.ItemCountText.elementFadeIn:SetDuration(fadeInDuration)

	-- SecondaryText
	if not self.SecondaryText.elementFadeIn then
		self.SecondaryText.elementFadeIn = self.ElementFadeInAnimation:CreateAnimation("Alpha")
		self.SecondaryText.elementFadeIn:SetTarget(self.SecondaryText)
		self.SecondaryText.elementFadeIn:SetFromAlpha(0)
		self.SecondaryText.elementFadeIn:SetToAlpha(1)
		self.SecondaryText.elementFadeIn:SetSmoothing(fadeInSmoothing)
	end
	self.SecondaryText.elementFadeIn:SetDuration(fadeInDuration)

	-- UnitPortrait
	if not self.UnitPortrait.elementFadeIn then
		self.UnitPortrait.elementFadeIn = self.ElementFadeInAnimation:CreateAnimation("Alpha")
		self.UnitPortrait.elementFadeIn:SetTarget(self.UnitPortrait)
		self.UnitPortrait.elementFadeIn:SetFromAlpha(0)
		self.UnitPortrait.elementFadeIn:SetToAlpha(1)
		self.UnitPortrait.elementFadeIn:SetSmoothing(fadeInSmoothing)
	end
	self.UnitPortrait.elementFadeIn:SetDuration(fadeInDuration)

	-- CoinDisplay and SecondaryCoinDisplay are created lazily from SetRow().
	-- On pool reuse, Init() runs before SetRow() so they exist here; update
	-- the duration on the already-registered animation.
	if self.CoinDisplay and self.CoinDisplay.elementFadeIn then
		self.CoinDisplay.elementFadeIn:SetDuration(fadeInDuration)
	end
	if self.SecondaryCoinDisplay and self.SecondaryCoinDisplay.elementFadeIn then
		self.SecondaryCoinDisplay.elementFadeIn:SetDuration(fadeInDuration)
	end
end

function RLF_RowAnimationMixin:StyleHighlightBorder()
	if not self.HighlightAnimation then
		self.HighlightAnimation = self:CreateAnimationGroup()
		self.HighlightAnimation:SetToFinalAlpha(true)
	end

	---@type RLF_ConfigAnimations
	local animationsDb = G_RLF.DbAccessor:Animations(self.frameType)

	if
		self.cachedUpdateDisableHighlight ~= animationsDb.update.disableHighlight
		or self.cachedUpdateDuration ~= animationsDb.update.duration
		or self.cachedUpdateLoop ~= animationsDb.update.loop
	then
		self.cachedUpdateDisableHighlight = animationsDb.update.disableHighlight
		self.cachedUpdateDuration = animationsDb.update.duration
		self.cachedUpdateLoop = animationsDb.update.loop

		local duration = animationsDb.update.duration
		local borderSize = G_RLF.PerfPixel.PScale(1)
		self.TopBorder:SetHeight(borderSize)
		self.RightBorder:SetWidth(borderSize)
		self.BottomBorder:SetHeight(borderSize)
		self.LeftBorder:SetWidth(borderSize)
		local borders = {
			self.TopBorder,
			self.RightBorder,
			self.BottomBorder,
			self.LeftBorder,
		}

		for _, b in ipairs(borders) do
			if not b.fadeIn then
				b.fadeIn = self.HighlightAnimation:CreateAnimation("Alpha")
				b.fadeIn:SetTarget(b)
				b.fadeIn:SetOrder(1)
				b.fadeIn:SetFromAlpha(0)
				b.fadeIn:SetToAlpha(1)
				b.fadeIn:SetSmoothing("IN_OUT")
			end
			b.fadeIn:SetDuration(duration)

			if not b.fadeOut then
				b.fadeOut = self.HighlightAnimation:CreateAnimation("Alpha")
				b.fadeOut:SetTarget(b)
				b.fadeOut:SetOrder(2)
				b.fadeOut:SetFromAlpha(1)
				b.fadeOut:SetToAlpha(0)
				b.fadeOut:SetStartDelay(0.1)
				b.fadeOut:SetSmoothing("IN_OUT")
			end
			b.fadeOut:SetDuration(duration)
		end

		if animationsDb.update.loop then
			self.HighlightAnimation:SetLooping("BOUNCE")
		else
			self.HighlightAnimation:SetLooping("NONE")
		end
	end
end

function RLF_RowAnimationMixin:StyleShiftAnimation()
	if not self.ShiftAnimation then
		self.ShiftAnimation = self:CreateAnimationGroup() --[[@as RLF_RowShiftAnimationGroup]]
		self.ShiftAnimation:SetToFinalAlpha(false)
		self.ShiftAnimation.translation = self.ShiftAnimation:CreateAnimation("Translation")
		self.ShiftAnimation.translation:SetSmoothing("IN_OUT")
		self.ShiftAnimation:SetScript("OnFinished", function()
			local frame = self:GetParent() --[[@as RLF_LootDisplayFrame]]
			if not frame then
				return
			end
			-- Anchor at the pre-computed final position (frame-relative) so the
			-- row doesn't depend on sibling chain anchors that may still be
			-- mid-animation.  This eliminates the flicker from the
			-- offset-clear → UpdatePosition gap.
			self:ClearAllPoints()
			self:SetPoint(frame.vertDir, frame, frame.vertDir, 0, self._shiftFinalFrameOffset)
			-- Preserve correct frame level so borders render properly
			self:SetFrameLevel(self._shiftFinalFrameLevel)
			-- Restart glow animation if it was playing before the shift
			if self._glowWasPlaying and self.glowAnimationGroup then
				self.glowAnimationGroup:Play()
				self._glowWasPlaying = false
			end
			-- Decrement shift counter
			frame.shiftingRowCount = math.max(0, (frame.shiftingRowCount or 0) - 1)
			if frame.shiftingRowCount == 0 then
				-- All shift animations complete — restore proper chain anchors
				frame:RestoreRowChain()
				G_RLF:SendMessage("RLF_ROW_RETURNED", frame.frameType)
			end
		end)
	end
end

--- Animate this row from its old visual edge position to its new anchor
--- position via a Translation animation (FLIP technique).
---
--- The row is temporarily anchored to the parent frame at the old visual
--- position.  A Translation slides it to the new position.  OnFinished
--- re-anchors at the final position (frame-relative) to avoid flicker,
--- and once all shifts complete the chain is restored.
---
--- @param yDelta number oldEdgeY minus newEdgeY in screen coordinates;
---   positive = row shifted downward, negative = shifted upward.
--- @param oldEdgeY number the row's visual edge-Y at the time of snapshot.
function RLF_RowAnimationMixin:AnimateShift(yDelta, oldEdgeY)
	if not self.ShiftAnimation then
		self:StyleShiftAnimation()
	end

	local frame = self:GetParent() --[[@as RLF_LootDisplayFrame]]
	if not frame then
		return
	end

	-- Update duration from current config
	local animationsDb = G_RLF.DbAccessor:Animations(self.frameType)
	if not animationsDb.reposition then
		return
	end
	self.ShiftAnimation.translation:SetDuration(animationsDb.reposition.duration)

	local frameEdgeY
	if frame.vertDir == "BOTTOM" then
		frameEdgeY = frame:GetBottom()
	else
		frameEdgeY = frame:GetTop()
	end

	-- Pre-compute the final frame-relative offset for OnFinished
	local newEdgeY = oldEdgeY - yDelta
	self._shiftFinalFrameOffset = newEdgeY - frameEdgeY

	-- Preserve the current frame level for OnFinished so borders render
	-- at the correct stacking order during and after the animation.
	self._shiftFinalFrameLevel = self:GetFrameLevel()

	-- Pause the glow Scale animation so it doesn't accumulate transforms
	-- across the anchor change.  It will be restarted in OnFinished.
	local glowWasPlaying = self.glowAnimationGroup and self.glowAnimationGroup:IsPlaying()
	if glowWasPlaying then
		self.glowAnimationGroup:Stop()
	end
	self._glowWasPlaying = glowWasPlaying

	-- Temporarily anchor to the parent frame at the old visual position
	self:ClearAllPoints()
	self:SetPoint(frame.vertDir, frame, frame.vertDir, 0, oldEdgeY - frameEdgeY)

	-- Translation slides from anchor (oldEdgeY) toward newEdgeY
	-- WoW Translation goes FROM (0,0) TO the offset, so -yDelta moves
	-- from old position toward new position.
	self.ShiftAnimation.translation:SetOffset(0, -yDelta)

	-- Increment counter and play
	frame.shiftingRowCount = (frame.shiftingRowCount or 0) + 1
	self.ShiftAnimation:Play()
end

function RLF_RowAnimationMixin:StyleExitAnimation()
	local animationChanged = false
	if self.isSampleRow then
		-- Sample rows should never fade out
		self.showForSeconds = math.pow(2, 19) -- Never fade out
		self.bustCacheExitAnimation = true
	end

	---@type RLF_ConfigAnimations
	local animationsDb = G_RLF.DbAccessor:Animations(self.frameType)
	local animationsExitDb = animationsDb.exit
	local disableExitAnimation = animationsExitDb.disable
	local exitAnimationType = animationsExitDb.type
	local exitDuration = animationsExitDb.duration
	local exitDelay = self.showForSeconds

	if
		self.cachedExitAnimationType ~= exitAnimationType
		or self.cachedExitAnimationDuration ~= exitDuration
		or self.cachedExitFadeOutDelay ~= exitDelay
		or self.cachedExitDisableAnimation ~= disableExitAnimation
		or self.bustCacheExitAnimation
	then
		self.cachedExitAnimationType = exitAnimationType
		self.cachedExitAnimationDuration = exitDuration
		self.cachedExitFadeOutDelay = exitDelay
		self.cachedExitDisableAnimation = disableExitAnimation
		self.bustCacheExitAnimation = false
		animationChanged = true
	end

	if animationChanged then
		if not self.ExitAnimation then
			self.ExitAnimation = self:CreateAnimationGroup() --[[@as RLF_RowExitAnimationGroup]]
			self.ExitAnimation:SetScript("OnFinished", function()
				self:Hide()
				local frame = self:GetParent() --[[@as RLF_LootDisplayFrame]]
				if not frame then
					return
				end
				frame:ReleaseRow(self)
			end)
		else
			self.ExitAnimation:Stop()
			self.ExitAnimation:RemoveAnimations()
		end

		if disableExitAnimation then
			exitDelay = math.pow(2, 19)
			exitAnimationType = G_RLF.ExitAnimationType.NONE
		end

		if exitAnimationType == G_RLF.ExitAnimationType.NONE then
			self.ExitAnimation:SetToFinalAlpha(false)
			self.ExitAnimation.noop = self.ExitAnimation:CreateAnimation()
			self.ExitAnimation.fadeOut = nil
			self.ExitAnimation.noop:SetStartDelay(exitDelay)
			self.ExitAnimation.noop:SetDuration(0)
			self:SetAlpha(1)
			return
		end

		if exitAnimationType ~= G_RLF.ExitAnimationType.NONE then
			self.ExitAnimation:SetToFinalAlpha(true)
			self.ExitAnimation.noop = nil
			self.ExitAnimation.fadeOut = self.ExitAnimation:CreateAnimation("Alpha")
			self.ExitAnimation.fadeOut:SetStartDelay(exitDelay)
			self.ExitAnimation.fadeOut:SetDuration(exitDuration)
			self.ExitAnimation.fadeOut:SetFromAlpha(1)
			self.ExitAnimation.fadeOut:SetToAlpha(0)
			self.ExitAnimation.fadeOut:SetScript("OnUpdate", function()
				if self.glowTexture and self.glowTexture:IsShown() then
					self.glowTexture:SetAlpha(0.75 * (1 - self.ExitAnimation.fadeOut:GetProgress()))
				end
			end)
		end
	else
		if self.ExitAnimation.fadeOut then
			self.ExitAnimation.fadeOut:SetStartDelay(exitDelay)
			self.ExitAnimation.fadeOut:SetDuration(exitDuration)
		end
		if self.ExitAnimation.noop then
			self.ExitAnimation.noop:SetStartDelay(exitDelay)
			self.ExitAnimation.noop:SetDuration(0)
		end
	end
end

function RLF_RowAnimationMixin:StyleEnterAnimation()
	local animationChanged = false

	---@type RLF_ConfigAnimations
	local animationsDb = G_RLF.DbAccessor:Animations(self.frameType)
	local animationsEnterDb = animationsDb.enter
	local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)
	local enterAnimationType = animationsEnterDb.type
	local slideDirection = animationsEnterDb.slide.direction
	local enterDuration = animationsEnterDb.duration
	local feedWidth = sizingDb.feedWidth
	local rowHeight = sizingDb.rowHeight

	if
		self.cachedEnterAnimationType ~= enterAnimationType
		or self.cachedEnterAnimationSlideDirection ~= slideDirection
		or self.cachedEnterAnimationDuration ~= enterDuration
		or self.cachedEnterAnimationFeedWidth ~= feedWidth
		or self.cachedEnterAnimationRowHeight ~= rowHeight
	then
		self.cachedEnterAnimationType = enterAnimationType
		self.cachedEnterAnimationSlideDirection = slideDirection
		self.cachedEnterAnimationDuration = enterDuration
		self.cachedEnterAnimationFeedWidth = feedWidth
		self.cachedEnterAnimationRowHeight = rowHeight
		animationChanged = true
	end

	if not self.EnterAnimation then
		self.EnterAnimation = self:CreateAnimationGroup() --[[@as RLF_RowEnterAnimationGroup]]
	end

	if animationChanged then
		self.EnterAnimation:Stop()
		self.EnterAnimation:RemoveAnimations()
		self.EnterAnimation:SetToFinalAlpha(true)
		self.EnterAnimation:SetScript("OnPlay", function()
			self.waiting = false
			self:ElementsVisible()
		end)
		self.EnterAnimation:SetScript("OnFinished", function()
			self:HighlightIcon()
			self:ResetFadeOut()
			if self.updatePending then
				self:UpdateQuantity(self.pendingElement)
			end
			if self:IsStaggeredEnter() then
				if self._next then
					self._next.waiting = false
					self._next:Enter()
				end
			end
		end)

		if enterAnimationType == G_RLF.EnterAnimationType.NONE then
			self.EnterAnimation.noop = self.EnterAnimation:CreateAnimation()
			self.EnterAnimation.fadeIn = nil
			self.EnterAnimation.slideIn = nil
			self:SetAlpha(1)
			return
		end

		-- Fade In unless explicitly disabled
		if enterAnimationType ~= G_RLF.EnterAnimationType.NONE then
			self.EnterAnimation.noop = nil
			self.EnterAnimation.slideIn = nil
			self.EnterAnimation.fadeIn = self.EnterAnimation:CreateAnimation("Alpha")
			self.EnterAnimation.fadeIn:SetFromAlpha(0)
			self.EnterAnimation.fadeIn:SetToAlpha(1)
			self.EnterAnimation.fadeIn:SetDuration(enterDuration)
			self.EnterAnimation.fadeIn:SetSmoothing("IN_OUT")
			self.EnterAnimation.fadeIn:SetScript("OnFinished", function()
				self:SetAlpha(1)
			end)
		end

		if enterAnimationType == G_RLF.EnterAnimationType.SLIDE then
			self.EnterAnimation:SetScript("OnPlay", function()
				self:ElementsInvisible()
			end)
			self.EnterAnimation:SetScript("OnFinished", function()
				self:FadeInElements()
				if self:IsStaggeredEnter() then
					if self._next then
						self._next.waiting = false
						self._next:Enter()
					end
				end
			end)

			self.EnterAnimation.slideIn = self.EnterAnimation:CreateAnimation("Translation")

			local initialOffsetX, initialOffsetY = 0, 0

			-- Determine the initial offset based on slide direction
			if slideDirection == G_RLF.SlideDirection.LEFT then
				initialOffsetX = feedWidth
			elseif slideDirection == G_RLF.SlideDirection.RIGHT then
				initialOffsetX = -feedWidth
			elseif slideDirection == G_RLF.SlideDirection.UP then
				initialOffsetY = -rowHeight
			elseif slideDirection == G_RLF.SlideDirection.DOWN then
				initialOffsetY = rowHeight
			end

			self.EnterAnimation.slideIn:SetOffset(-initialOffsetX, -initialOffsetY) -- Opposite of initial to slide to the final position
			self.EnterAnimation.slideIn:SetDuration(enterDuration)
			self.EnterAnimation.slideIn:SetSmoothing("OUT")

			-- Set the starting position before the animation begins
			self.EnterAnimation.slideIn:SetScript("OnPlay", function()
				if slideDirection == G_RLF.SlideDirection.LEFT or slideDirection == G_RLF.SlideDirection.RIGHT then
					self:SetPoint(slideDirection == G_RLF.SlideDirection.LEFT and "LEFT" or "RIGHT", initialOffsetX, 0)
				elseif slideDirection == G_RLF.SlideDirection.UP or slideDirection == G_RLF.SlideDirection.DOWN then
					if self.opposite then
						self:SetPoint(self.anchorPoint, self.anchorTo, self.opposite, 0, initialOffsetY)
					else
						self:SetPoint(self.anchorPoint, self.anchorTo, self.anchorPoint, 0, initialOffsetY)
					end
				end
			end)

			-- Reset the final position after the animation completes
			self.EnterAnimation.slideIn:SetScript("OnFinished", function()
				self:ClearAllPoints()
				local frame = self:GetParent() --[[@as RLF_LootDisplayFrame]]
				if not frame then
					return
				end
				self:UpdatePosition(frame)
				self.waiting = false
			end)
		end
	end
end

function RLF_RowAnimationMixin:StyleIconHighlight()
	if not self.glowTexture then
		-- Create the glow texture
		self.glowTexture = self.Icon:CreateTexture(nil, "OVERLAY")
		self.glowTexture:SetDrawLayer("OVERLAY", 7)
		self.glowTexture:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
		self.glowTexture:SetPoint("CENTER", self.Icon, "CENTER", 0, 0)
		self.glowTexture:SetBlendMode("ADD") -- "ADD" is often better for glow effects
		self.glowTexture:SetAlpha(0.75)
		self.glowTexture:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
	end

	G_RLF.PerfPixel.PSize(self.glowTexture, self.Icon:GetWidth() * 1.75, self.Icon:GetHeight() * 1.75)
	self.glowTexture:Hide()

	-- Create the animation group if it doesn't exist
	if not self.glowAnimationGroup then
		self.glowAnimationGroup = self.glowTexture:CreateAnimationGroup()
		self.glowAnimationGroup:SetLooping("BOUNCE")
	end

	if not self.glowAnimationGroup.scaleUp then
		-- -- Scale up animation
		self.glowAnimationGroup.scaleUp = self.glowAnimationGroup:CreateAnimation("Scale")
		local factor = 1.1
		self.glowAnimationGroup.scaleUp:SetScaleFrom(1 / factor, 1 / factor)
		self.glowAnimationGroup.scaleUp:SetScaleTo(factor, factor)
		self.glowAnimationGroup.scaleUp:SetDuration(0.5)
		self.glowAnimationGroup.scaleUp:SetSmoothing("OUT")
	end

	-- Add scripted animation effects support
	self:CreateScriptedEffects()
end

function RLF_RowAnimationMixin:ElementsVisible()
	self.Icon:SetAlpha(1)
	self.PrimaryText:SetAlpha(1)
	self.AmountText:SetAlpha(1)
	self.ItemCountText:SetAlpha(1)
	self.SecondaryText:SetAlpha(1)
	self.UnitPortrait:SetAlpha(1)
	if self.CoinDisplay then
		self.CoinDisplay:SetAlpha(1)
	end
	if self.SecondaryCoinDisplay then
		self.SecondaryCoinDisplay:SetAlpha(1)
	end
end

function RLF_RowAnimationMixin:ElementsInvisible()
	self.Icon:SetAlpha(0)
	self.PrimaryText:SetAlpha(0)
	self.AmountText:SetAlpha(0)
	self.ItemCountText:SetAlpha(0)
	self.SecondaryText:SetAlpha(0)
	self.UnitPortrait:SetAlpha(0)
	if self.CoinDisplay then
		self.CoinDisplay:SetAlpha(0)
	end
	if self.SecondaryCoinDisplay then
		self.SecondaryCoinDisplay:SetAlpha(0)
	end
end

function RLF_RowAnimationMixin:FadeInElements()
	self.ElementFadeInAnimation:Play()
end

function RLF_RowAnimationMixin:IsStaggeredEnter()
	local animationsDb = G_RLF.DbAccessor:Animations(self.frameType)
	local enterAnimationType = animationsDb.enter.type
	local slideDirection = animationsDb.enter.slide.direction

	if
		enterAnimationType == G_RLF.EnterAnimationType.SLIDE
		and (slideDirection == G_RLF.SlideDirection.UP or slideDirection == G_RLF.SlideDirection.DOWN)
	then
		return true
	end
end

function RLF_RowAnimationMixin:IsPreviousRowEntering()
	if not self._prev then
		return false
	end

	if not self._prev.waiting then
		if not self._prev.EnterAnimation then
			return false
		end
		if not self._prev.EnterAnimation:IsPlaying() then
			return false
		end
	end

	return true
end

function RLF_RowAnimationMixin:Enter()
	self.EnterAnimation:Stop()
	self.ElementFadeInAnimation:Stop()
	self.ExitAnimation:Stop()
	if not self:IsStaggeredEnter() or not self.waiting then
		RunNextFrame(function()
			self:Show()
			self.EnterAnimation:Play()
		end)
		return
	end
	if self:IsPreviousRowEntering() then
		self:Hide()
		return
	end
	RunNextFrame(function()
		self:Show()
		self.EnterAnimation:Play()
	end)
end

function RLF_RowAnimationMixin:HandlerOnRightClick()
	self:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" and not self.isHistoryMode then
			if not self.ExitAnimation then
				return
			end
			-- Stop any ongoing animation
			if self.ExitAnimation:IsPlaying() then
				self.ExitAnimation:Stop()
			end

			if self.ExitAnimation.noop then
				self.ExitAnimation.noop:SetStartDelay(0)
			elseif self.ExitAnimation.fadeOut then
				self.ExitAnimation.fadeOut:SetStartDelay(0)
			end
			self.bustCacheExitAnimation = true

			-- Start the fade-out animation
			self.ExitAnimation:Play()
		end
	end)
end

function RLF_RowAnimationMixin:UpdateEnterAnimation()
	self:StyleEnterAnimation()
end

function RLF_RowAnimationMixin:UpdateFadeoutDelay()
	if not self.isSampleRow and not self.hasElementFadeOverride then
		self.showForSeconds = G_RLF.DbAccessor:Animations(self.frameType).exit.fadeOutDelay
	end
	self:StyleExitAnimation()
end

-- Utility function to check if the mouse is over the parent or any of its children
local function isMouseOverSelfOrChildren(frame)
	if frame:IsMouseOver() then
		return true
	end

	for _, child in ipairs({ frame:GetChildren() }) do
		if child:IsMouseOver() then
			return true
		end
	end

	return false
end

function RLF_RowAnimationMixin:SetUpHoverEffect()
	---@type RLF_ConfigAnimations
	local animationsDb = G_RLF.DbAccessor:Animations(self.frameType)
	local hoverDb = animationsDb.hover
	local highlightedAlpha = hoverDb.alpha
	local baseDuration = hoverDb.baseDuration

	-- Fade-in animation group
	if not self.HighlightFadeIn then
		self.HighlightFadeIn = self.HighlightBGOverlay:CreateAnimationGroup()

		local fadeIn = self.HighlightFadeIn:CreateAnimation("Alpha")
		local startingAlpha = self.HighlightBGOverlay:GetAlpha()
		fadeIn:SetFromAlpha(startingAlpha) -- Start from the current alpha
		fadeIn:SetToAlpha(highlightedAlpha) -- Target alpha for the highlight
		local duration = baseDuration * (highlightedAlpha - startingAlpha) / highlightedAlpha
		fadeIn:SetDuration(duration)
		fadeIn:SetSmoothing("OUT")

		-- Ensure alpha is held at target level after animation finishes
		self.HighlightFadeIn:SetScript("OnFinished", function()
			self.HighlightBGOverlay:SetAlpha(highlightedAlpha) -- Hold at target alpha
		end)
	end

	-- Fade-out animation group
	if not self.HighlightFadeOut then
		self.HighlightFadeOut = self.HighlightBGOverlay:CreateAnimationGroup()

		local fadeOut = self.HighlightFadeOut:CreateAnimation("Alpha")
		local startingAlpha = self.HighlightBGOverlay:GetAlpha()
		fadeOut:SetFromAlpha(startingAlpha) -- Start from the target alpha of the fade-in
		fadeOut:SetToAlpha(0) -- Return to original alpha
		local duration = baseDuration * startingAlpha / highlightedAlpha
		fadeOut:SetDuration(duration)
		fadeOut:SetSmoothing("IN")
		-- fadeOut:SetStartDelay(0.15) -- Delay before starting the fade-out

		-- Ensure alpha is fully reset after animation finishes
		self.HighlightFadeOut:SetScript("OnFinished", function()
			self.HighlightBGOverlay:SetAlpha(0) -- Reset to invisible
		end)
	end

	-- OnEnter: Play fade-in animation; show sample row tooltip if present
	self:SetScript("OnEnter", function()
		---@type RLF_ConfigAnimations
		local animationsDb = G_RLF.DbAccessor:Animations(self.frameType)
		G_RLF:LogDebug(
			"[PIN] Row:OnEnter key=" .. tostring(self.key) .. " hasMouseOver=" .. tostring(self.hasMouseOver),
			addonName
		)
		if self.hasMouseOver then
			return
		end
		-- Always track hover state and pin — these are independent of the
		-- highlight animation setting.  Also stop the exit animation here so
		-- hovering anywhere on the row (not just the ClickableButton) pauses
		-- the fade-out countdown.
		if not self.isHistoryMode then
			if self.ExitAnimation then
				self.ExitAnimation:Stop()
			end
			self:StopTimerBar()
		end
		self.hasMouseOver = true
		if animationsDb.hover.enabled then
			-- Stop fade-out if it's playing
			if self.HighlightFadeOut:IsPlaying() then
				self.HighlightFadeOut:Stop()
			end
			-- Play fade-in
			self.HighlightFadeIn:Play()
		end
		-- Show sample row tooltip
		if self.sampleTooltipText then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.sampleTooltipText, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
		-- Pin the row so it doesn't shift while hovered.
		-- History rows are parented to historyContent (a plain Frame with no
		-- vertDir or ReleasePin method), so skip pinning entirely for them.
		if not self.isHistoryMode then
			local frame = self:GetParent() --[[@as RLF_LootDisplayFrame]]
			if frame then
				self:PinPosition(frame)
			end
		end
	end)

	-- OnLeave: Play fade-out animation; hide sample row tooltip if present
	self:SetScript("OnLeave", function()
		-- Prevent OnLeave from firing if the mouse is still over the row or any of its children
		local overSelfOrChildren = isMouseOverSelfOrChildren(self)
		G_RLF:LogDebug(
			"[PIN] Row:OnLeave key="
				.. tostring(self.key)
				.. " hasMouseOver="
				.. tostring(self.hasMouseOver)
				.. " overSelfOrChildren="
				.. tostring(overSelfOrChildren),
			addonName
		)
		if overSelfOrChildren or not self.hasMouseOver then
			return
		end
		self.hasMouseOver = false
		---@type RLF_ConfigAnimations
		local animationsDb = G_RLF.DbAccessor:Animations(self.frameType)
		if animationsDb.hover.enabled then
			-- Stop fade-in if it's playing
			if self.HighlightFadeIn:IsPlaying() then
				self.HighlightFadeIn:Stop()
			end
			-- Play fade-out
			self.HighlightFadeOut:Play()
		end
		-- Hide sample row tooltip
		if self.sampleTooltipText then
			GameTooltip:Hide()
		end
		-- Release the pin first so isPinned is false before the exit animation
		-- resumes. Prevents ExitAnimation:Play() from firing while pinned.
		-- History rows skip this: historyContent has no ReleasePin method.
		if not self.isHistoryMode then
			local frame = self:GetParent() --[[@as RLF_LootDisplayFrame]]
			if frame then
				frame:ReleasePin(self)
			end
		end
		-- Resume the exit animation now that mouse has truly left.
		if not self.isHistoryMode then
			if self.ExitAnimation then
				self.ExitAnimation:Play()
			end
			self:StartTimerBar()
		end
	end)
end

function RLF_RowAnimationMixin:HighlightIcon()
	if self.highlight then
		RunNextFrame(function()
			if self.type == G_RLF.FeatureModule.Transmog and G_RLF:IsRetail() then
				self:PlayTransmogEffect()
			else
				-- Show the glow texture and play the animation
				self.glowTexture:SetAlpha(0.75)
				self.glowTexture:Show()
				self.glowAnimationGroup:Play()
			end
		end)
	end
end

function RLF_RowAnimationMixin:ResetFadeOut()
	RunNextFrame(function()
		if self.ExitAnimation and not self.isPinned then
			if self.ExitAnimation:IsPlaying() then
				self.ExitAnimation:Stop()
			end
			self.ExitAnimation:Play()
		end
		self:StartTimerBar()
	end)
end

function RLF_RowAnimationMixin:ResetHighlightBorder()
	self.TopBorder:SetAlpha(0)
	self.RightBorder:SetAlpha(0)
	self.BottomBorder:SetAlpha(0)
	self.LeftBorder:SetAlpha(0)
end

G_RLF.RLF_RowAnimationMixin = RLF_RowAnimationMixin
