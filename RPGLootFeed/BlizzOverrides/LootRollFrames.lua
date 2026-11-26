---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class LootRollFramesOverride: RLF_Module, AceEvent-3.0, AceHook-3.0
local LootRollFramesOverride = G_RLF.RLF:NewModule(G_RLF.BlizzModule.LootRollFrames, "AceEvent-3.0", "AceHook-3.0")

--- Blizzard's roll frames are opened by its own START_LOOT_ROLL dispatcher,
--- which addons can't unregister, and removed through GroupLootContainer's
--- layout, which calls into the managed bottom frame container. Calling that
--- from addon code risks spreading taint to protected frames laid out with it,
--- so a roll frame RLF is showing is only made invisible and click-through;
--- Blizzard still removes it on CANCEL_LOOT_ROLL through its own code path.

function LootRollFramesOverride:OnInitialize()
	-- Mainline opens every roll (including queued ones) through
	-- GroupLootContainer_OpenNewFrame; Classic flavors through
	-- GroupLootFrame_OpenNewFrame.
	if GroupLootContainer_OpenNewFrame then
		self:SecureHook("GroupLootContainer_OpenNewFrame", "Refresh")
	elseif GroupLootFrame_OpenNewFrame then
		self:SecureHook("GroupLootFrame_OpenNewFrame", "Refresh")
	end
end

--- Should Blizzard's frame for this roll be concealed? Only while the option is
--- on, row interaction is possible, and a feed row for the roll exists, so a
--- roll the feed filtered out or failed to show keeps Blizzard's window.
---@param rollID number?
---@return boolean
function LootRollFramesOverride:ShouldConceal(rollID)
	if not rollID or not G_RLF.db.global.blizzOverrides.hideBlizzLootRollFrames then
		return false
	end
	local lootRolls = G_RLF.LootRolls
	if not lootRolls or not lootRolls:IsEnabled() then
		return false
	end
	-- Only conceal when a row that shows this roll lets the player click its buttons.
	for _, entry in ipairs(lootRolls:FindRollRows(rollID)) do
		local row = entry.row
		-- A results-only row has no buttons to click, so Blizzard's window stays.
		local hasButtons = row.ShowsRollButtons == nil or row:ShowsRollButtons()
		if hasButtons and row:IsInteractionAllowed("rollButtons") then
			return true
		end
	end
	return false
end

---@param frame Frame
---@param disabled Frame[]
local function disableMouse(frame, disabled)
	if frame:IsMouseEnabled() then
		frame:EnableMouse(false)
		table.insert(disabled, frame)
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		disableMouse(child, disabled)
	end
end

---@param frame Frame
function LootRollFramesOverride:Conceal(frame)
	if frame._rlfConcealed then
		return
	end
	frame._rlfConcealed = {}
	disableMouse(frame, frame._rlfConcealed)
	frame:SetAlpha(0)
end

---@param frame Frame
function LootRollFramesOverride:Reveal(frame)
	if not frame._rlfConcealed then
		return
	end
	for _, f in ipairs(frame._rlfConcealed) do
		f:EnableMouse(true)
	end
	frame._rlfConcealed = nil
	frame:SetAlpha(1)
end

--- Remember that the player already rolled on this roll, so its Blizzard frame is
--- finished business whatever Blizzard does with it. Called when the player rolls
--- through RLF's buttons or anywhere else (see LootRolls:OnPlayerRolled).
---@param rollID number
function LootRollFramesOverride:MarkRolled(rollID)
	for i = 1, NUM_GROUP_LOOT_FRAMES or 4 do
		local frame = _G["GroupLootFrame" .. i]
		if frame and frame.rollID == rollID then
			frame._rlfRolledID = rollID
		end
	end
end

--- Is this shown frame a leftover whose roll is over? Blizzard removes a roll
--- frame on CANCEL_LOOT_ROLL, but a frame it has not removed yet (or never will,
--- e.g. after the player rolled through RLF's buttons) must not be revealed: its
--- buttons do nothing, so revealing it only puts a dead window on screen.
---@param frame Frame
---@return boolean
function LootRollFramesOverride:IsStale(frame)
	local rollID = frame.rollID
	if not rollID or not frame:IsShown() then
		return false
	end
	if frame._rlfRolledID == rollID then
		return true
	end
	local lootRolls = G_RLF.LootRolls
	-- IsRollOpen is nil when unknown; only a definite "no" makes the frame stale.
	return lootRolls ~= nil and lootRolls.IsRollOpen ~= nil and lootRolls:IsRollOpen(rollID) == false
end

--- Re-evaluate every Blizzard roll frame. Called after Blizzard opens one,
--- after RLF creates or releases a roll row, and when the option changes, so
--- it is correct whichever side of START_LOOT_ROLL runs first.
function LootRollFramesOverride:Refresh()
	for i = 1, NUM_GROUP_LOOT_FRAMES or 4 do
		local frame = _G["GroupLootFrame" .. i]
		if frame then
			if frame:IsShown() and self:ShouldConceal(frame.rollID) then
				self:Conceal(frame)
			elseif frame._rlfConcealed and self:IsStale(frame) then
				-- Leave it concealed (invisible and click-through); Blizzard still
				-- removes it through its own code path.
			else
				self:Reveal(frame)
			end
		end
	end
end

return LootRollFramesOverride
