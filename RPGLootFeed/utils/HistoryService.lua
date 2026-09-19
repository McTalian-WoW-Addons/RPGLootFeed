---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class HistoryService
G_RLF.HistoryService = {
	---@type boolean
	historyShown = false,
}

function G_RLF.HistoryService:ToggleHistoryFrame()
	if not G_RLF.db.global.lootHistory.enabled then
		return
	end

	local show = not self.historyShown
	self.historyShown = show

	local LootDisplay = G_RLF.LootDisplay
	for _, frame in LootDisplay:GetAllFrames() do
		if frame then
			if show then
				frame:ShowHistoryFrame()
			else
				frame:HideHistoryFrame()
			end
		end
	end
end

function G_RLF.HistoryService:HideHistoryFrame()
	if self.historyShown then
		self.historyShown = false
		local LootDisplay = G_RLF.LootDisplay
		for _, frame in LootDisplay:GetAllFrames() do
			if frame then
				frame:HideHistoryFrame()
			end
		end
	end
end

--- Process a single mouse-wheel delta event for scroll-wheel history activation.
--- Tracks a double-scroll sequence (down to activate, up to deactivate) within a
--- configurable time window.  Call this from each LootDisplayFrame's OnMouseWheel
--- script whenever the feature is enabled.
---
--- Returns the current scroll count (1 or 2) so callers can provide feedback,
--- or 0 if the sequence was reset.
---
--- @param delta number  Positive = scroll up, negative = scroll down
--- @param wheelState table  Per-frame state table: {lastScrollTime, lastScrollDirection, scrollCount}
--- @param threshold number  Time window in milliseconds
--- @param doubleScrollMode boolean  When true, require 2 scrolls; single scroll activates immediately when false
--- @return integer count  Current scroll count in the sequence (0 = reset, 1 = first scroll, 2 = activated/deactivated)
function G_RLF.HistoryService:ProcessWheelInput(delta, wheelState, threshold, doubleScrollMode)
	local now = GetTime() * 1000 -- Convert to milliseconds

	local direction = (delta > 0) and "up" or "down"

	-- When already in history mode, "up" at top of list deactivates.
	-- When not in history mode, "down" activates.
	local desiredDirection = self.historyShown and "up" or "down"

	-- Reset state if direction changed or sequence timed out
	if
		direction ~= desiredDirection
		or (wheelState.scrollCount > 0 and (now - wheelState.lastScrollTime) > threshold)
	then
		wheelState.scrollCount = 0
		wheelState.lastScrollTime = 0
		wheelState.lastScrollDirection = nil
	end

	-- Wrong direction for current mode — ignore
	if direction ~= desiredDirection then
		return 0
	end

	-- Advance the scroll count
	wheelState.scrollCount = wheelState.scrollCount + 1
	wheelState.lastScrollTime = now
	wheelState.lastScrollDirection = direction

	local required = doubleScrollMode and 2 or 1
	if wheelState.scrollCount >= required then
		-- Reset state before toggling so re-entry works cleanly
		wheelState.scrollCount = 0
		wheelState.lastScrollTime = 0
		wheelState.lastScrollDirection = nil
		self:ToggleHistoryFrame()
		return required
	end

	return wheelState.scrollCount
end

--- Reset the per-frame wheel state (e.g. on combat entry or new loot).
--- @param wheelState table
function G_RLF.HistoryService:ResetWheelState(wheelState)
	wheelState.scrollCount = 0
	wheelState.lastScrollTime = 0
	wheelState.lastScrollDirection = nil
end
