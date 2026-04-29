---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_TimerBarSubscriber
---@field row RLF_LootDisplayRow
---@field startTime number
---@field duration number

---@class RLF_TimerBarCoordinator
---@field _subscribers RLF_TimerBarSubscriber[]
---@field _updateFrame Frame
RLF_TimerBarCoordinator = {}

--- Create a new TimerBarCoordinator instance.
--- This is a shared OnUpdate driver for Classic mode (Lua-driven timer bars).
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
function RLF_TimerBarCoordinator:Subscribe(row, duration)
	if not row or not row.TimerBar then
		return
	end

	-- Check if already subscribed
	for _, subscriber in ipairs(self._subscribers) do
		if subscriber.row == row then
			-- Already subscribed; update duration
			subscriber.startTime = GetTime()
			subscriber.duration = duration
			return
		end
	end

	-- Add new subscription
	table.insert(self._subscribers, {
		row = row,
		startTime = GetTime(),
		duration = duration,
	})

	-- Start OnUpdate loop if first subscriber
	if #self._subscribers == 1 then
		self._updateFrame:Show()
	end

	-- Initialize bar to full
	row.TimerBar:SetMinMaxValues(0, duration)
	row.TimerBar:SetValue(duration)
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
				-- Countdown finished; hide and unsubscribe
				row.TimerBar:SetValue(0)
				self:Unsubscribe(row)
			else
				-- Update bar value
				row.TimerBar:SetValue(remaining)
			end
		else
			-- Row invalid or hidden; clean up subscription
			self:Unsubscribe(row)
		end
	end
end

G_RLF.NewTimerBarCoordinator = ns.NewTimerBarCoordinator
