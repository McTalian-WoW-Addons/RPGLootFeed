---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_RowTimerBarMixin
---@field TimerBar StatusBar
---@field _timerBarCoordinatorSubscribed boolean
RLF_RowTimerBarMixin = {}

--- Widget fill styles keyed by the config's drainDirection value.
---
--- The config stores UI-facing direction keys, not widget enum names, and the
--- two are mirror images: a bar labelled "Right to Left" empties from its right
--- edge, which is a Standard fill (anchored left, so the boundary recedes
--- leftward as the value drops). "NORMAL" is not a StatusBarFillStyle at all --
--- passing it straight through errors inside the widget.
local fillStyleByDrainDirection = Enum.StatusBarFillStyle
		and {
			REVERSE = Enum.StatusBarFillStyle.Standard,
			NORMAL = Enum.StatusBarFillStyle.Reverse,
		}
	or {}

--- Apply configuration to the timer bar (height, color, alpha, drain direction).
--- Called during row initialization and when animation settings change.
function RLF_RowTimerBarMixin:StyleTimerBar()
	if not self.TimerBar then
		return
	end

	local animCfg = G_RLF.DbAccessor:Animations(self.frameType)
	local timerBarCfg = animCfg and animCfg.timerBar
	-- Styling must never reveal the bar. A disabled bar stays hidden even though
	-- its config table is always present (the AceDB "**" wildcard supplies it for
	-- every frame), and StartTimerBar() is the only thing allowed to Show() it.
	if not timerBarCfg or not timerBarCfg.enabled then
		self.TimerBar:Hide()
		return
	end

	-- Set height
	self.TimerBar:SetHeight(timerBarCfg.height or 2)

	-- Reposition with yOffset so the bar can sit above the row border
	local yOffset = timerBarCfg.yOffset or 0
	self.TimerBar:ClearAllPoints()
	self.TimerBar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, yOffset)
	self.TimerBar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, yOffset)

	-- Set color and alpha
	local color = timerBarCfg.color or { 0.5, 0.5, 0.5 }
	local alpha = timerBarCfg.alpha or 0.7
	self.TimerBar:SetStatusBarColor(color[1], color[2], color[3], alpha)

	-- Set fill style (drain direction)
	-- SetFillStyle is a StatusBar widget method, so probe the widget itself.
	-- The old guard tested the unrelated C_StatusBar namespace and never passed.
	-- An unrecognized drainDirection leaves the XML default (Standard) in place,
	-- which is the same thing the default "REVERSE" config value maps to.
	local fillStyle = fillStyleByDrainDirection[timerBarCfg.drainDirection or "REVERSE"]
	if fillStyle and self.TimerBar.SetFillStyle then
		self.TimerBar:SetFillStyle(fillStyle)
	end
end

--- Determine if the timer bar should be shown for this row.
--- Rules:
--- - History mode rows: Never show
--- - Rows with exit disabled: Never show (non-sample only)
--- - Sample rows: Always show (for styling preview)
--- - Normal rows: Show if enabled in config
---@return boolean
function RLF_RowTimerBarMixin:ShouldShowTimerBar()
	if not self.TimerBar then
		return false
	end

	-- History mode rows never show timer bar (no animations in history)
	if self.isHistoryMode then
		return false
	end

	-- Sample rows always show timer bar (for styling preview)
	if self.isSampleRow then
		local animCfg = G_RLF.DbAccessor:Animations(self.frameType)
		return (animCfg and animCfg.timerBar and animCfg.timerBar.enabled) and true or false
	end

	-- Check if exit animation is disabled
	local exitCfg = G_RLF.DbAccessor:Animations(self.frameType).exit
	if exitCfg and exitCfg.disable then
		-- Persistent bar that never counts down is confusing
		return false
	end

	-- Check if timer bar is enabled in config
	local timerBarCfg = G_RLF.DbAccessor:Animations(self.frameType).timerBar
	return timerBarCfg and timerBarCfg.enabled or false
end

--- Start the timer bar countdown synchronized with fadeOutDelay.
--- Called from RowAnimationMixin:ResetFadeOut().
function RLF_RowTimerBarMixin:StartTimerBar()
	if not self:ShouldShowTimerBar() then
		self:StopTimerBar()
		return
	end

	local duration = self.showForSeconds or 5

	-- C_DurationUtil drives the drain natively where it exists, which is every
	-- flavor we currently ship (it is documented on live, classic, classic_era
	-- and classic_anniversary alike) -- the guard is a floor, not a Retail check.
	local nativeDuration = false
	if C_DurationUtil and C_DurationUtil.CreateDuration and self.TimerBar.SetTimerDuration then
		if not self._timerBarDuration then
			self._timerBarDuration = C_DurationUtil.CreateDuration()
		end

		self._timerBarDuration:SetTimeFromStart(GetTime(), duration)
		self.TimerBar:SetTimerDuration(
			self._timerBarDuration,
			Enum.StatusBarInterpolation.Immediate,
			Enum.StatusBarTimerDirection.RemainingTime
		)
		nativeDuration = true
	end

	-- Subscribe either way. A native duration animates the value but never
	-- signals completion, so without this the drained background track lingers
	-- for the rest of the fade-out; hideOnly keeps the coordinator from fighting
	-- the native driver for control of the value. Without a native duration the
	-- coordinator drives the value itself.
	if not G_RLF.TimerBarCoordinator then
		G_RLF.TimerBarCoordinator = ns.NewTimerBarCoordinator()
	end

	self._timerBarCoordinatorSubscribed = true
	G_RLF.TimerBarCoordinator:Subscribe(self, duration, nativeDuration)
	self.TimerBar:Show()
end

--- Stop the timer bar countdown and reset to full.
--- Called from RowAnimationMixin:StopAllAnimations().
function RLF_RowTimerBarMixin:StopTimerBar()
	if not self.TimerBar then
		return
	end

	-- Unsubscribe from coordinator if active
	if self._timerBarCoordinatorSubscribed and G_RLF.TimerBarCoordinator then
		G_RLF.TimerBarCoordinator:Unsubscribe(self)
		self._timerBarCoordinatorSubscribed = false
	end

	self.TimerBar:Hide()
end

--- Reset the timer bar state (called from Reset()).
--- Ensures clean slate when row is recycled.
function RLF_RowTimerBarMixin:ResetTimerBar()
	if self._timerBarCoordinatorSubscribed and G_RLF.TimerBarCoordinator then
		G_RLF.TimerBarCoordinator:Unsubscribe(self)
		self._timerBarCoordinatorSubscribed = false
	end

	if self.TimerBar then
		self.TimerBar:Hide()
		self.TimerBar:SetMinMaxValues(0, 1)
		self.TimerBar:SetValue(0)
	end

	self._timerBarDuration = nil
end

--- Update the timer bar (used by TimerBarCoordinator in Classic).
---@param elapsed number Delta time in seconds
function RLF_RowTimerBarMixin:OnTimerBarUpdate(elapsed)
	-- This is called by the coordinator in Classic mode
	-- The StatusBar will be updated by the coordinator
	-- This is a hook point for future enhancements
end

G_RLF.RLF_RowTimerBarMixin = RLF_RowTimerBarMixin
