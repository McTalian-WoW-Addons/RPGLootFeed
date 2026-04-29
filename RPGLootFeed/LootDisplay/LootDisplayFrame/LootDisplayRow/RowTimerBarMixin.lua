---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_RowTimerBarMixin
---@field TimerBar StatusBar
---@field _timerBarCoordinatorSubscribed boolean
RLF_RowTimerBarMixin = {}

--- Apply configuration to the timer bar (height, color, alpha, drain direction).
--- Called during row initialization and when animation settings change.
function RLF_RowTimerBarMixin:StyleTimerBar()
	if not self.TimerBar then
		return
	end

	local animCfg = G_RLF.DbAccessor:Animations(self.frameType)
	if not animCfg or not animCfg.timerBar then
		self.TimerBar:Hide()
		return
	end

	local timerBarCfg = animCfg.timerBar

	-- Set height
	local currentWidth = self.TimerBar:GetWidth()
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
	local drainDirection = timerBarCfg.drainDirection or "REVERSE"
	if C_StatusBar and C_StatusBar.SetFillStyle then
		self.TimerBar:SetFillStyle(drainDirection)
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
		return animCfg and animCfg.timerBar and animCfg.timerBar.enabled
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

	-- Retail: Use C_DurationUtil for hardware-accelerated countdown
	if C_DurationUtil and C_DurationUtil.CreateDuration then
		if not self._timerBarDuration then
			self._timerBarDuration = C_DurationUtil.CreateDuration()
		end

		self._timerBarDuration:SetTimeFromStart(GetTime(), duration)
		self.TimerBar:SetTimerDuration(
			self._timerBarDuration,
			Enum.StatusBarInterpolation.Immediate,
			Enum.StatusBarTimerDirection.RemainingTime
		)
		self.TimerBar:Show()
	else
		-- Classic: Use subscription-based coordinator for efficient OnUpdate
		if not G_RLF.TimerBarCoordinator then
			G_RLF.TimerBarCoordinator = ns.NewTimerBarCoordinator()
		end

		self._timerBarCoordinatorSubscribed = true
		G_RLF.TimerBarCoordinator:Subscribe(self, duration)
		self.TimerBar:Show()
	end
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
