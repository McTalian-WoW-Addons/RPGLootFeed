---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_TimerBarSubscriber
---@field row RLF_LootDisplayRow
---@field startTime number
---@field duration number
---@field hideOnly boolean When true the bar's value is driven by a native
--- C_DurationUtil duration and the coordinator only watches for completion.

---@class RLF_TimerBarCoordinator
---@field _subscribers RLF_TimerBarSubscriber[]
---@field _updateFrame Frame
RLF_TimerBarCoordinator = {}

--- Create a new TimerBarCoordinator instance.
--- One shared OnUpdate for every active timer bar. It drives the bar's value
--- when nothing else does, and watches for completion so the bar can be hidden
--- even when a native C_DurationUtil duration owns the value (see hideOnly).
---@return RLF_TimerBarCoordinator
function ns.NewTimerBarCoordinator()
	local self = setmetatable({}, { __index = RLF_TimerBarCoordinator })

	self._subscribers = {}
	self._updateFrame = CreateFrame("Frame")
	self._updateFrame:SetScript("OnUpdate", function(frame, elapsed)
		self:_OnUpdate(elapsed)
	end)
	self._updateFrame:Hide() -- Start hidden; shown when first subscriber added

	return self
end

--- Subscribe a row to timer bar updates.
--- Automatically starts the OnUpdate loop if this is the first subscriber.
---@param row RLF_LootDisplayRow
---@param duration number Countdown duration in seconds
---@param hideOnly boolean? Set when the row already has a native C_DurationUtil
--- duration driving the bar's value; the coordinator then only hides the bar on
--- completion and leaves min/max and value untouched.
function RLF_TimerBarCoordinator:Subscribe(row, duration, hideOnly)
	if not row or not row.TimerBar then
		return
	end

	-- Check if already subscribed
	for _, subscriber in ipairs(self._subscribers) do
		if subscriber.row == row then
			-- Already subscribed; update duration
			subscriber.startTime = GetTime()
			subscriber.duration = duration
			subscriber.hideOnly = hideOnly or false
			return
		end
	end

	-- Add new subscription
	table.insert(self._subscribers, {
		row = row,
		startTime = GetTime(),
		duration = duration,
		hideOnly = hideOnly or false,
	})

	-- Start OnUpdate loop if first subscriber
	if #self._subscribers == 1 then
		self._updateFrame:Show()
	end

	-- Initialize bar to full, unless a native duration owns the value
	if not hideOnly then
		row.TimerBar:SetMinMaxValues(0, duration)
		row.TimerBar:SetValue(duration)
	end
end

--- Unsubscribe a row from timer bar updates.
--- Automatically stops the OnUpdate loop if no subscribers remain.
---@param row RLF_LootDisplayRow
function RLF_TimerBarCoordinator:Unsubscribe(row)
	if not row then
		return
	end

	for i, subscriber in ipairs(self._subscribers) do
		if subscriber.row == row then
			table.remove(self._subscribers, i)
			break
		end
	end

	-- Stop OnUpdate loop if no subscribers
	if #self._subscribers == 0 then
		self._updateFrame:Hide()
	end
end

--- OnUpdate handler: update all subscribed rows.
---@param elapsed number Delta time in seconds
function RLF_TimerBarCoordinator:_OnUpdate(elapsed)
	-- Iterate backwards to handle removal during iteration
	for i = #self._subscribers, 1, -1 do
		local subscriber = self._subscribers[i]
		local row = subscriber.row

		-- Check if row is still valid (may have been released)
		if row and row.TimerBar and row:IsVisible() then
			local elapsed_since_start = GetTime() - subscriber.startTime
			local remaining = subscriber.duration - elapsed_since_start

			if remaining <= 0 then
				-- Countdown finished; hide and unsubscribe. Hiding matters: the
				-- StatusBar's background track is drawn regardless of value, so
				-- a drained bar would otherwise linger for the rest of the fade.
				if not subscriber.hideOnly then
					row.TimerBar:SetValue(0)
				end
				row.TimerBar:Hide()
				row._timerBarCoordinatorSubscribed = false
				self:Unsubscribe(row)
			elseif not subscriber.hideOnly then
				-- Update bar value
				row.TimerBar:SetValue(remaining)
			end
		else
			-- Row invalid or hidden; clean up subscription
			if row then
				row._timerBarCoordinatorSubscribed = false
			end
			self:Unsubscribe(row)
		end
	end
end

G_RLF.NewTimerBarCoordinator = ns.NewTimerBarCoordinator
