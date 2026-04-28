---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_LootDisplayFrame: Frame
---@field BoundingBox Texture
---@field InstructionText FontString
---@field ArrowUp Texture
---@field ArrowDown Texture
---@field ArrowLeft Texture
---@field ArrowRight Texture
---@field isClickThrough boolean
---@field shiftingRowCount integer
---@field bypassShiftAnimation boolean
---@field hasPinnedRow boolean
LootDisplayFrameMixin = {}

-- Maps a loot element's .type field (G_RLF.FeatureModule value) to the
-- matching key in db.global.frames[id].features.
local featureKeyForType = {
	[G_RLF.FeatureModule.ItemLoot] = "itemLoot",
	[G_RLF.FeatureModule.PartyLoot] = "partyLoot",
	[G_RLF.FeatureModule.Currency] = "currency",
	[G_RLF.FeatureModule.Money] = "money",
	[G_RLF.FeatureModule.Experience] = "experience",
	[G_RLF.FeatureModule.Reputation] = "reputation",
	[G_RLF.FeatureModule.Profession] = "profession",
	[G_RLF.FeatureModule.TravelPoints] = "travelPoints",
	[G_RLF.FeatureModule.Transmog] = "transmog",
}

--- Check whether this frame should display the given loot element based on
--- the frame's per-feature configuration.
--- @param element RLF_BaseLootElement
--- @return boolean
function LootDisplayFrameMixin:IsFeatureEnabled(element)
	local featureKey = featureKeyForType[element.type]
	if not featureKey then
		-- Non-feature elements (e.g. Notifications) fall back to their own
		-- module-level IsEnabled gate and only show on the main frame.
		return self.frameType == G_RLF.Frames.MAIN and element.IsEnabled()
	end
	local frameConfig = G_RLF.db.global.frames[self.frameType]
	if not frameConfig then
		return false
	end
	local featureCfg = frameConfig.features[featureKey]
	return featureCfg and featureCfg.enabled or false
end

--- Check whether the element passes per-frame configuration filters such as
--- item quality tiers and user-defined deny lists.  Called after IsFeatureEnabled
--- confirms the feature is turned on for this frame.
--- @param element RLF_BaseLootElement
--- @return boolean
function LootDisplayFrameMixin:PassesPerFrameFilters(element)
	local featureKey = featureKeyForType[element.type]
	if not featureKey then
		-- Non-feature elements carry no filter metadata.
		return true
	end
	local frameConfig = G_RLF.db.global.frames[self.frameType]
	if not frameConfig then
		return true
	end
	local featureCfg = frameConfig.features[featureKey]
	if not featureCfg then
		return true
	end

	-- ── Item quality tier filter (ItemLoot and PartyLoot) ─────────────────────
	if element.filterItemQuality ~= nil then
		if featureKey == "itemLoot" then
			local qualSettings = (featureCfg.itemQualitySettings or {})[element.filterItemQuality]
			if not qualSettings or not qualSettings.enabled then
				return false
			end
		elseif featureKey == "partyLoot" then
			if not (featureCfg.itemQualityFilter or {})[element.filterItemQuality] then
				return false
			end
		end
	end

	-- ── Item ID deny list (ItemLoot and PartyLoot) ────────────────────────────
	if element.filterItemId ~= nil then
		local ignoredIds = featureCfg.ignoreItemIds or {}
		for _, id in ipairs(ignoredIds) do
			if tonumber(id) == tonumber(element.filterItemId) then
				return false
			end
		end
	end

	-- ── Currency ID deny list (Currency) ─────────────────────────────────────
	if element.filterCurrencyId ~= nil then
		local ignoredIds = featureCfg.ignoreCurrencyIds or {}
		for _, id in ipairs(ignoredIds) do
			if tonumber(id) == tonumber(element.filterCurrencyId) then
				return false
			end
		end
	end

	return true
end

function LootDisplayFrameMixin:getFrameHeight()
	local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)
	local padding = sizingDb.padding
	return sizingDb.maxRows * (sizingDb.rowHeight + padding) - padding
end

function LootDisplayFrameMixin:getNumberOfRows()
	return self.rows.length
end

function LootDisplayFrameMixin:getPositioningDetails()
	local stylingDb = G_RLF.DbAccessor:Styling(self.frameType)
	local growUp = stylingDb.growUp
	-- Position the new row at the bottom (or top if growing down)
	local textAlignment = stylingDb.textAlignment
	local horizDir = (textAlignment ~= G_RLF.TextAlignment.RIGHT) and "LEFT" or "RIGHT"
	local vertDir = growUp and "BOTTOM" or "TOP"
	local opposite = growUp and "TOP" or "BOTTOM"
	local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)
	local yOffset = sizingDb.padding
	if not growUp then
		yOffset = -yOffset
	end

	return vertDir, opposite, yOffset, horizDir
end

local function configureArrowRotation(arrow, direction)
	if direction == "UP" then
		arrow:SetRotation(0)
	elseif direction == "DOWN" then
		arrow:SetRotation(math.pi)
	elseif direction == "LEFT" then
		arrow:SetRotation(math.pi * 0.5)
	elseif direction == "RIGHT" then
		arrow:SetRotation(math.pi * 1.5)
	end
end

function LootDisplayFrameMixin:CreateArrowsTestArea()
	if not self.arrows then
		self.arrows = { self.ArrowUp, self.ArrowDown, self.ArrowLeft, self.ArrowRight }

		-- Set arrow rotations
		configureArrowRotation(self.ArrowUp, "UP")
		configureArrowRotation(self.ArrowDown, "DOWN")
		configureArrowRotation(self.ArrowLeft, "LEFT")
		configureArrowRotation(self.ArrowRight, "RIGHT")

		-- Hide arrows initially
		for _, arrow in ipairs(self.arrows) do
			arrow:Hide()
		end
	end
end

function LootDisplayFrameMixin:ConfigureTestArea()
	self.BoundingBox:Hide() -- Hide initially

	self:MakeUnmovable()

	-- Use the frame's configured display name when available; fall back to the
	-- addon name alone for the main frame or when the DB entry is absent.
	local firstLine = addonName
	local frameConfig = G_RLF.db and G_RLF.db.global.frames and G_RLF.db.global.frames[self.frameType]
	if frameConfig and frameConfig.name and frameConfig.name ~= "" then
		firstLine = firstLine .. " - " .. frameConfig.name
	end
	self.InstructionText:SetText(firstLine .. "\n" .. G_RLF.L["Drag to Move"]) -- Set localized text
	self.InstructionText:Hide() -- Hide initially

	self:CreateArrowsTestArea()
end

-- Create the tab frame and anchor it to the loot frame
function LootDisplayFrameMixin:CreateTab()
	self.tab = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate") --[[@as Button]]
	self.tab:SetClampedToScreen(true)
	self.tab:SetAlpha(0.2)
	self.tab:Hide()

	-- Add an icon to the button
	local icon = self.tab:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09") -- Replace with the desired icon path
	icon:SetAllPoints(self.tab)

	-- Handle mouse enter and leave events to change alpha
	self.tab:SetScript("OnEnter", function()
		self.tab:SetAlpha(1.0)
		GameTooltip:SetOwner(self.tab, "ANCHOR_RIGHT")
		GameTooltip:SetText(G_RLF.L["Toggle Loot History"], 1, 1, 1)
		GameTooltip:Show()
	end)
	self.tab:SetScript("OnLeave", function()
		self.tab:SetAlpha(0.2)
		GameTooltip:Hide()
	end)

	-- Handle click event to show the history frame
	self.tab:SetScript("OnClick", function()
		G_RLF.HistoryService:ToggleHistoryFrame()
	end)

	self:UpdateOverlayFrameDepth()
	self:UpdateTabAppearance()
end

function LootDisplayFrameMixin:UpdateTabAppearance()
	if not self.tab then
		return
	end

	local historyDb = G_RLF.db.global.lootHistory
	local tabSize = math.max(historyDb.tabSize or 14, 1)
	local xOffset = historyDb.tabXOffset or 0
	local yOffset = historyDb.tabYOffset or 0

	self.tab:SetSize(tabSize, tabSize)
	self.tab:ClearAllPoints()

	if historyDb.tabFreePosition then
		self.tab:SetPoint("CENTER", UIParent, "CENTER", xOffset, yOffset)
		return
	end

	local stylingDb = G_RLF.DbAccessor:Styling(self.frameType)
	local anchor = stylingDb.growUp and "BOTTOMLEFT" or "TOPLEFT"
	local xBase = stylingDb.growUp and -tabSize or 0
	self.tab:SetPoint(anchor, self, anchor, xBase + xOffset, yOffset)
end

function LootDisplayFrameMixin:UpdateOverlayFrameDepth()
	local frameLevel = self:GetFrameLevel()
	if self.tab then
		self.tab:SetFrameStrata(self:GetFrameStrata())
		self.tab:SetFrameLevel(frameLevel + 10)
	end
	if self.historyFrame then
		self.historyFrame:SetFrameStrata(self:GetFrameStrata())
		self.historyFrame:SetFrameLevel(frameLevel + 20)
	end
	if self.historyTitle then
		self.historyTitle:SetDrawLayer("OVERLAY", 7)
	end
end

--- Function to update the loot history tab visibility
function LootDisplayFrameMixin:UpdateTabVisibility()
	if not self.tab then
		return
	end

	local isEnabled = G_RLF.db.global.lootHistory.enabled
	if not isEnabled then
		self.tab:Hide()
		return
	end

	local hideTab = G_RLF.db.global.lootHistory.hideTab
	if hideTab then
		self.tab:Hide()
		return
	end

	local inCombat = UnitAffectingCombat("player")
	local hasItems = self:getNumberOfRows() > 0
	local optionsVisible = self.BoundingBox and self.BoundingBox:IsVisible()

	if not inCombat and (not hasItems or optionsVisible) then
		self.tab:Show()
	else
		G_RLF.HistoryService:HideHistoryFrame()
		self.tab:Hide()
	end
end

--- Apply or remove click-through (mouse passthrough) on all active rows.
--- Called when combat state changes.
--- @param inCombat boolean
function LootDisplayFrameMixin:SetCombatClickThrough(inCombat)
	local shouldBeClickThrough = inCombat and G_RLF.db.global.interactions.disableMouseInCombat
	self.isClickThrough = shouldBeClickThrough
	for row in self.rows:iterate() do
		---@cast row RLF_LootDisplayRow
		row:SetClickThrough(shouldBeClickThrough)
	end
end

--- Release the pin on a hovered row, animating it from its pinned position
--- to its current chain position (FLIP technique, mirroring ReleaseRow).
--- Called from SetClickThrough (combat start) and SetUpHoverEffect OnLeave.
--- @param row RLF_LootDisplayRow
function LootDisplayFrameMixin:ReleasePin(row)
	G_RLF:LogDebug("[PIN] ReleasePin: key=" .. tostring(row.key) .. " isPinned=" .. tostring(row.isPinned), addonName)
	if not row.isPinned then
		return
	end

	local getEdgeY = (self.vertDir == "BOTTOM") and function(r)
		return r:GetBottom()
	end or function(r)
		return r:GetTop()
	end

	-- Fast-forward any running shift animations to their intended final position
	-- before snapshotting, so the delta base is visually stable (not mid-animation).
	for r in self.rows:iterate() do
		---@cast r RLF_LootDisplayRow
		if r.ShiftAnimation and r.ShiftAnimation:IsPlaying() then
			r.ShiftAnimation:Stop()
			if r._shiftFinalFrameOffset ~= nil then
				r:ClearAllPoints()
				r:SetPoint(self.vertDir, self, self.vertDir, 0, r._shiftFinalFrameOffset)
			else
				-- Fallback: restore chain anchor (safe, old behaviour)
				r:UpdatePosition(self)
			end
			r.PrimaryLineLayout:SetAlpha(1)
			r.SecondaryLineLayout:SetAlpha(1)
			r._textHiddenForShift = false
			self.shiftingRowCount = math.max(0, self.shiftingRowCount - 1)
		end
	end

	-- FLIP Phase 1: Snapshot visual positions of all rows (including pinned
	-- row AND rows below it) after fast-forwarding, so the delta base is stable.
	local snapshots = {}
	for r in self.rows:iterate() do
		---@cast r RLF_LootDisplayRow
		snapshots[r] = getEdgeY(r)
	end

	-- Clear pin state BEFORE chain restore so UpdateNeighborPositions / FLIP
	-- iterators don't treat this row as pinned anymore.
	row.isPinned = false
	row.pinnedFrameOffset = nil
	self.hasPinnedRow = false

	-- FLIP Phase 2: Restore the chain anchor for the unpinned row.
	-- WoW cascades: all rows below snap to their new chain positions.
	row:UpdatePosition(self)

	-- Restore chain anchors for rows that were fast-forwarded (frame-directly-
	-- anchored) so Phase 3 getEdgeY calls return correct final positions.
	-- Same reasoning as the ReleaseRow fix: cascade won't reach rows that
	-- AnimateShift already broke out of the chain.
	for r in self.rows:iterate() do
		---@cast r RLF_LootDisplayRow
		if not r.isPinned then
			r:UpdatePosition(self)
		end
	end

	-- FLIP Phase 3: Pre-compute all deltas.
	local shifts = {}
	for r, oldEdgeY in pairs(snapshots) do
		---@cast r RLF_LootDisplayRow
		local newEdgeY = getEdgeY(r)
		local yDelta = oldEdgeY - newEdgeY
		if math.abs(yDelta) > 0.5 then
			shifts[r] = { yDelta = yDelta, oldEdgeY = oldEdgeY }
		end
	end

	-- FLIP Phase 4: Play.
	local anyShifting = false
	for r, info in pairs(shifts) do
		---@cast r RLF_LootDisplayRow
		r:AnimateShift(info.yDelta, info.oldEdgeY)
		anyShifting = true
	end

	if not anyShifting then
		G_RLF:SendMessage("RLF_ROW_RETURNED", self.frameType)
	end
end

--- Create a single scroll-wheel capture frame for the MAIN loot frame.
--- Only called on the MAIN frame (one target for the whole addon).
--- history activation (issue #399).  The target covers the same area as the
--- loot frame by default; size/anchor/offset are user-configurable.
function LootDisplayFrameMixin:CreateScrollWheelTarget()
	-- Per-frame wheel state for double-scroll detection.
	self.wheelState = {
		scrollCount = 0,
		lastScrollTime = 0,
		lastScrollDirection = nil,
	}

	-- Capture self BEFORE any closures that reference it.
	local selfRef = self

	-- Invisible frame parented to UIParent so it sits independently.
	-- EnableMouseWheel() is required for OnMouseWheel to fire.
	self.scrollWheelTarget = CreateFrame("Frame", nil, UIParent)
	self.scrollWheelTarget:SetFrameStrata(self:GetFrameStrata())
	self.scrollWheelTarget:SetFrameLevel(self:GetFrameLevel() + 5)
	self.scrollWheelTarget:EnableMouseWheel(true)
	self.scrollWheelTarget:SetAlpha(0)

	-- Scroll counter indicator: two small colored squares shown briefly above
	-- the loot frame when a scroll event is detected in double-scroll mode.
	-- Uses WHITE8x8 textures tinted gold/grey — always renders regardless of font.
	self.scrollCounterFrame = CreateFrame("Frame", nil, UIParent)
	self.scrollCounterFrame:SetSize(28, 10) -- two 10px squares + 8px gap
	-- Anchor above the scroll target so the indicator follows target repositioning
	self.scrollCounterFrame:SetPoint("BOTTOM", self.scrollWheelTarget, "TOP", 0, 6)
	self.scrollCounterFrame:SetFrameStrata(self:GetFrameStrata())
	self.scrollCounterFrame:SetFrameLevel(self:GetFrameLevel() + 30)
	self.scrollCounterFrame:SetAlpha(0)
	self._scrollCounterDots = {}
	for i = 1, 2 do
		local dot = self.scrollCounterFrame:CreateTexture(nil, "OVERLAY")
		dot:SetTexture("Interface/Buttons/WHITE8x8")
		dot:SetSize(10, 10)
		if i == 1 then
			dot:SetPoint("LEFT", self.scrollCounterFrame, "LEFT", 0, 0)
		else
			dot:SetPoint("RIGHT", self.scrollCounterFrame, "RIGHT", 0, 0)
		end
		self._scrollCounterDots[i] = dot
	end
	self._scrollCounterTimer = nil -- Cancellable fade-out timer handle

	-- Border: 4 medium-thin (2px) gray edges around the scroll wheel target.
	-- Shown when the options test area is active, or optionally on hover.
	self._scrollTargetBorder = {}
	local function makeBorderEdge(pt1, pt2, isHorizontal)
		local edge = self.scrollWheelTarget:CreateTexture(nil, "OVERLAY")
		edge:SetTexture("Interface/Buttons/WHITE8x8")
		edge:SetVertexColor(0.55, 0.55, 0.55) -- medium gray
		edge:SetPoint(pt1, self.scrollWheelTarget, pt1)
		edge:SetPoint(pt2, self.scrollWheelTarget, pt2)
		if isHorizontal then
			edge:SetHeight(2)
		else
			edge:SetWidth(2)
		end
		edge:Hide()
		table.insert(self._scrollTargetBorder, edge)
	end
	makeBorderEdge("TOPLEFT", "TOPRIGHT", true) -- top
	makeBorderEdge("BOTTOMLEFT", "BOTTOMRIGHT", true) -- bottom
	makeBorderEdge("TOPLEFT", "BOTTOMLEFT", false) -- left
	makeBorderEdge("TOPRIGHT", "BOTTOMRIGHT", false) -- right

	-- Make the target EnableMouse so OnEnter/OnLeave fire for hover-border feature.
	self.scrollWheelTarget:EnableMouse(true)
	self.scrollWheelTarget:SetScript("OnEnter", function()
		local historyDb = G_RLF.db.global.lootHistory
		if historyDb and historyDb.showScrollTargetBorderOnHover then
			selfRef:SetScrollTargetBorderVisible(true)
		end
	end)
	self.scrollWheelTarget:SetScript("OnLeave", function()
		-- Only hide if the options test area is NOT currently open
		if not (selfRef.BoundingBox and selfRef.BoundingBox:IsVisible()) then
			selfRef:SetScrollTargetBorderVisible(false)
		end
	end)

	self.scrollWheelTarget:SetScript("OnMouseWheel", function(_, delta)
		local historyDb = G_RLF.db.global.lootHistory
		-- Feature guard: must be enabled and history feature enabled
		if not historyDb.enableScrollWheelActivation or not historyDb.enabled then
			return
		end

		-- When history is shown, the target drives the history frame scroll.
		-- The target is an invisible overlay; it captures all wheel events in the
		-- area, so we must manually forward scrolling to the history ScrollFrame.
		if G_RLF.HistoryService.historyShown then
			if not selfRef.historyFrame then
				return
			end
			local currentScroll = selfRef.historyFrame:GetVerticalScroll()
			local sizingDb = G_RLF.DbAccessor:Sizing(selfRef.frameType)
			local rowStep = sizingDb.rowHeight + sizingDb.padding
			if delta > 0 then
				-- Scroll up: already at top → deactivate; otherwise scroll one row up
				if currentScroll <= 0 then
					G_RLF.HistoryService:HideHistoryFrame()
				else
					local newScroll = math.max(currentScroll - rowStep, 0)
					selfRef.historyFrame:SetVerticalScroll(newScroll)
					selfRef:UpdateHistoryFrame(newScroll)
				end
			else
				-- Scroll down one row
				local maxScroll = selfRef.historyFrame:GetVerticalScrollRange()
				local newScroll = math.min(currentScroll + rowStep, maxScroll)
				selfRef.historyFrame:SetVerticalScroll(newScroll)
				selfRef:UpdateHistoryFrame(newScroll)
			end
			return
		end

		-- History not shown — process as activation scroll
		local threshold = historyDb.scrollWheelDoubleScrollThreshold or 500
		local doubleMode = (historyDb.scrollWheelDoubleScrollMode ~= false)
		local count = G_RLF.HistoryService:ProcessWheelInput(delta, selfRef.wheelState, threshold, doubleMode)
		selfRef:ShowScrollCounterFeedback(count, doubleMode)
	end)

	self:UpdateScrollWheelTarget()
end

--- Briefly display a scroll-progress indicator above the loot frame.
--- Two small squares: gold = reached, grey = pending.
--- count=0 hides immediately.
--- @param count integer
--- @param doubleMode boolean
function LootDisplayFrameMixin:ShowScrollCounterFeedback(count, doubleMode)
	if not self.scrollCounterFrame then
		return
	end

	-- Cancel any pending hide timer
	if self._scrollCounterTimer then
		self._scrollCounterTimer:Cancel()
		self._scrollCounterTimer = nil
	end

	if count == 0 then
		self.scrollCounterFrame:SetAlpha(0)
		return
	end

	local required = doubleMode and 2 or 1
	local filled = math.min(count, required)

	-- Resize frame to fit 1 or 2 dots
	local dotSize = 10
	local gap = 8
	self.scrollCounterFrame:SetSize(required * dotSize + (required - 1) * gap, dotSize)

	for i, dot in ipairs(self._scrollCounterDots) do
		if i <= required then
			dot:Show()
			if i <= filled then
				dot:SetVertexColor(1, 0.85, 0) -- gold
			else
				dot:SetVertexColor(0.5, 0.5, 0.5) -- grey
			end
			-- Re-anchor to spread evenly
			dot:ClearAllPoints()
			dot:SetPoint("LEFT", self.scrollCounterFrame, "LEFT", (i - 1) * (dotSize + gap), 0)
		else
			dot:Hide()
		end
	end

	self.scrollCounterFrame:SetAlpha(1)

	-- Auto-hide after 1.5s if the sequence isn't completed
	if count < required then
		self._scrollCounterTimer = C_Timer.NewTimer(1.5, function()
			self.scrollCounterFrame:SetAlpha(0)
			self._scrollCounterTimer = nil
		end)
	else
		-- Sequence complete — flash briefly then hide
		self._scrollCounterTimer = C_Timer.NewTimer(0.5, function()
			self.scrollCounterFrame:SetAlpha(0)
			self._scrollCounterTimer = nil
		end)
	end
end

--- Show or hide the cyan border drawn around the scroll wheel target area.
--- @param visible boolean
function LootDisplayFrameMixin:SetScrollTargetBorderVisible(visible)
	if not self._scrollTargetBorder then
		return
	end
	for _, edge in ipairs(self._scrollTargetBorder) do
		if visible then
			edge:Show()
		else
			edge:Hide()
		end
	end
	-- Make the target frame itself visible when the border is shown so the
	-- border textures (children) are drawn; keep alpha=0 so the frame itself
	-- doesn't tint anything — the border textures handle their own alpha.
	self.scrollWheelTarget:SetAlpha(visible and 1 or 0)
end

--- Reposition and resize the scroll wheel target.  Applies user overrides from
--- db.global.lootHistory (width, height, anchor, xOffset, yOffset).
--- 0 for width/height means auto-size to match the loot frame.
function LootDisplayFrameMixin:UpdateScrollWheelTarget()
	if not self.scrollWheelTarget then
		return
	end
	local frameW, frameH = self:GetSize()
	local historyDb = G_RLF.db.global.lootHistory
	local overrideW = historyDb and historyDb.scrollWheelTargetWidth or 0
	local overrideH = historyDb and historyDb.scrollWheelTargetHeight or 0
	local w = (overrideW and overrideW > 0) and overrideW or frameW
	local h = (overrideH and overrideH > 0) and overrideH or frameH
	local anchor = (historyDb and historyDb.scrollWheelTargetAnchor) or "CENTER"
	local xOff = (historyDb and historyDb.scrollWheelTargetXOffset) or 0
	local yOff = (historyDb and historyDb.scrollWheelTargetYOffset) or 0
	self.scrollWheelTarget:SetSize(math.max(w, 1), math.max(h, 1))
	self.scrollWheelTarget:ClearAllPoints()
	self.scrollWheelTarget:SetPoint(anchor, self, anchor, xOff, yOff)
end

--- Load the loot display frame
--- @param frame? G_RLF.Frames
function LootDisplayFrameMixin:Load(frame)
	self.frameType = frame or G_RLF.Frames.MAIN
	---@type list<RLF_LootDisplayRow>
	self.rows = G_RLF.list()
	---@type table<string, RLF_LootDisplayRow | integer>
	self.keyRowMap = {
		---@type integer
		length = 0,
	}
	---@type RLF_LootHistoryRowData[]
	self.rowHistory = {}
	self.shiftingRowCount = 0
	self.bypassShiftAnimation = false
	self.hasPinnedRow = false
	self.rowFramePool = CreateFramePool("Frame", self, "LootDisplayRowTemplate")
	self.vertDir, self.opposite, self.yOffset, self.horizDir = self:getPositioningDetails()
	local positioningDb = G_RLF.DbAccessor:Positioning(self.frameType)
	self:UpdateSize()
	self:SetPoint(
		positioningDb.anchorPoint,
		_G[positioningDb.relativePoint],
		positioningDb.xOffset,
		positioningDb.yOffset
	)

	self:SetFrameStrata(positioningDb.frameStrata) -- Set the frame strata here

	self:InitQueueLabel()
	self:ConfigureTestArea()
	if self.frameType == G_RLF.Frames.MAIN then
		self:CreateTab()
		-- Scroll-wheel history activation: single shared target on the main frame only.
		self:CreateScrollWheelTarget()
	else
		self.tab = nil -- No tab for party frame
	end

	self:UpdateOverlayFrameDepth()
end

function LootDisplayFrameMixin:InitQueueLabel()
	if not self.QueueLabel then
		self.QueueLabel = UIParent:CreateFontString(nil, "OVERLAY")
	end
	local anchorPoint = self.vertDir .. self.horizDir
	local relativePoint = self.opposite .. self.horizDir
	local stylingDb = G_RLF.DbAccessor:Styling(self.frameType)
	if stylingDb.useFontObjects then
		self.QueueLabel:SetFontObject(stylingDb.font)
	else
		local fontPath = G_RLF.lsm:Fetch(G_RLF.lsm.MediaType.FONT, stylingDb.fontFace)
		if not fontPath then
			error("Font not found: " .. tostring(stylingDb.fontFace))
		end
		-- Same helper the rows use, so the queue label picks up this frame's
		-- font flags (Slug included) and shadow settings rather than diverging.
		G_RLF:ApplyFontStyle(
			self.QueueLabel,
			fontPath,
			stylingDb.fontSize,
			G_RLF:FontFlagsToString(self.frameType),
			stylingDb.fontShadowColor,
			stylingDb.fontShadowOffsetX,
			stylingDb.fontShadowOffsetY
		)
	end
	self.QueueLabel:ClearAllPoints()
	self.QueueLabel:SetPoint(anchorPoint, self, relativePoint, 0, 0)
	self.QueueLabel:SetDrawLayer("OVERLAY", 7)
	self.QueueLabel:Hide()
end

function LootDisplayFrameMixin:ShowQueueLabel()
	if self.QueueLabel:IsShown() then
		return
	end
	local vertDir, opposite, _, horizDir = self:getPositioningDetails()
	self.QueueLabel:ClearAllPoints()
	self.QueueLabel:SetPoint(vertDir .. horizDir, self, opposite .. horizDir, 0, 0)
	self.QueueLabel:Show()
end

function LootDisplayFrameMixin:HideQueueLabel()
	self.QueueLabel:Hide()
end

function LootDisplayFrameMixin:UpdateQueueLabel(count)
	if count > 0 then
		self.QueueLabel:SetText(
			"|Tinterface/Widgets/azsharawards-state2-fill:0|t" .. string.format(G_RLF.L["Pending Items"], count)
		)
		self:ShowQueueLabel()
	else
		self.QueueLabel:Hide()
	end
end

function LootDisplayFrameMixin:ClearFeed()
	local row = self.rows.last --[[@as RLF_LootDisplayRow]]

	self.bypassShiftAnimation = true
	while row do
		local oldRow = row
		row = row._prev
		oldRow.ExitAnimation:Stop()
		oldRow:Hide()
		self:ReleaseRow(oldRow)
	end
	self.bypassShiftAnimation = false
end

function LootDisplayFrameMixin:UpdateSize()
	local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)
	self:SetSize(sizingDb.feedWidth, self:getFrameHeight())

	self:UpdateStyles()
	self:UpdateScrollWheelTarget()
end

function LootDisplayFrameMixin:UpdateStyles()
	for row in self.rows:iterate() do
		local row = row --[[@as RLF_LootDisplayRow]]
		row:UpdateStyles()
	end
end

function LootDisplayFrameMixin:UpdateFadeDelay()
	for row in self.rows:iterate() do
		local row = row --[[@as RLF_LootDisplayRow]]
		row:UpdateFadeoutDelay()
	end
end

function LootDisplayFrameMixin:UpdateEnterAnimationType()
	for row in self.rows:iterate() do
		local row = row --[[@as RLF_LootDisplayRow]]
		row:UpdateEnterAnimation()
	end
end

function LootDisplayFrameMixin:OnDragStop()
	self:StopMovingOrSizing()

	-- Save the new position
	local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
	local positioningDb = G_RLF.DbAccessor:Positioning(self.frameType)
	positioningDb.anchorPoint = point
	positioningDb.relativePoint = relativeTo or "UIParent"
	positioningDb.xOffset = xOfs
	positioningDb.yOffset = yOfs

	-- Update the frame position
	G_RLF.LootDisplay:UpdatePosition(self.frameType)
	G_RLF:NotifyChange(addonName)
end

function LootDisplayFrameMixin:ShowTestArea()
	self.BoundingBox:Show()
	self:RegisterForDrag("LeftButton")
	self:SetMovable(true)
	self:EnableMouse(true)
	self.InstructionText:Show()
	for i, a in ipairs(self.arrows) do
		a:Show()
	end
	-- Show scroll wheel target border so users can see the detection area
	self:SetScrollTargetBorderVisible(true)
	self:UpdateTabVisibility()
end

function LootDisplayFrameMixin:HideTestArea()
	self.BoundingBox:Hide()
	self:MakeUnmovable()
	self.InstructionText:Hide()
	for i, a in ipairs(self.arrows) do
		a:Hide()
	end
	-- Hide the border unless hover-border is active and the cursor is inside
	self:SetScrollTargetBorderVisible(false)
	self:UpdateTabVisibility()
end

function LootDisplayFrameMixin:MakeUnmovable()
	self:SetMovable(false)
	self:EnableMouse(false)
	self:RegisterForDrag()
end

--- Get row from key
--- @param key string
--- @return RLF_LootDisplayRow
function LootDisplayFrameMixin:GetRow(key)
	if key == "length" then
		error("Attempted to access key 'length' from GetRow")
	end
	return self.keyRowMap[key] --[[@as RLF_LootDisplayRow]]
end

--- @param key string
--- @param isSampleRow? boolean When true, bypass the maxRows cap
--- @return RLF_LootDisplayRow|nil
function LootDisplayFrameMixin:LeaseRow(key, isSampleRow)
	local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)
	if self:getNumberOfRows() >= sizingDb.maxRows and not isSampleRow then
		-- Skip this, we've already allocated too much
		return nil
	end

	---@type RLF_LootDisplayRow
	local row = self.rowFramePool:Acquire()
	row.frameType = self.frameType
	row.key = key
	RunNextFrame(function()
		row:Hide()
	end)

	local success = self.rows:push(row)
	if not success then
		error("Tried to push a row that already exists in the list")
	end

	row:Init()
	row:SetParent(self)

	if self.isClickThrough then
		row:SetClickThrough(true)
	end

	self.keyRowMap[key] = row
	self.keyRowMap.length = self.keyRowMap.length + 1

	row:UpdatePosition(self)
	RunNextFrame(function()
		row:ResetHighlightBorder()
	end)
	self:UpdateTabVisibility()

	return row
end

--- @param row RLF_LootDisplayRow
function LootDisplayFrameMixin:ReleaseRow(row)
	if not row.key then
		error("Row without key: " .. row:Dump())
	end

	if self.keyRowMap[row.key] then
		self.keyRowMap[row.key] = nil
		self.keyRowMap.length = self.keyRowMap.length - 1
	end

	if not row.isSampleRow then
		self:StoreRowHistory(row)
	end

	-- FLIP Phase 1: Snapshot visual edge positions of all remaining rows
	-- (before ANY anchor changes; GetBottom/GetTop returns the visual position
	-- including any ongoing Translation offset)
	local animationsDb = G_RLF.DbAccessor:Animations(self.frameType)
	local useShiftAnimation = not self.bypassShiftAnimation and animationsDb.reposition.duration > 0.04
	local snapshots = {}

	if useShiftAnimation then
		local getEdgeY = (self.vertDir == "BOTTOM") and function(r)
			return r:GetBottom()
		end or function(r)
			return r:GetTop()
		end

		-- Fast-forward any running shift animations to their intended final
		-- position.  Stop() alone snaps the row back to its frame-relative temp
		-- anchor (oldEdgeY), and the old UpdatePosition call then snapped it
		-- again to the chain position — both jumps visible to the player.
		-- Fast-forwarding to _shiftFinalFrameOffset lands the row at the stable
		-- position it was heading toward, eliminating the backward snap.
		for r in self.rows:iterate() do
			---@cast r RLF_LootDisplayRow
			if r ~= row and r.ShiftAnimation and r.ShiftAnimation:IsPlaying() then
				r.ShiftAnimation:Stop()
				if r._shiftFinalFrameOffset ~= nil then
					r:ClearAllPoints()
					r:SetPoint(self.vertDir, self, self.vertDir, 0, r._shiftFinalFrameOffset)
				else
					-- Fallback: restore chain anchor (safe, old behaviour)
					r:UpdatePosition(self)
				end
				r.PrimaryLineLayout:SetAlpha(1)
				r.SecondaryLineLayout:SetAlpha(1)
				r._textHiddenForShift = false
				self.shiftingRowCount = math.max(0, self.shiftingRowCount - 1)
			end
		end

		-- Handle the releasing row itself: stop and restore text alpha.
		-- No position restore needed — the row is about to be removed.
		if row.ShiftAnimation and row.ShiftAnimation:IsPlaying() then
			row.ShiftAnimation:Stop()
			row.PrimaryLineLayout:SetAlpha(1)
			row.SecondaryLineLayout:SetAlpha(1)
			row._textHiddenForShift = false
			self.shiftingRowCount = math.max(0, self.shiftingRowCount - 1)
		end

		-- Snapshot visual edge positions AFTER fast-forwarding so the base
		-- for Phase 3 deltas is measured from a visually stable position.
		for r in self.rows:iterate() do
			---@cast r RLF_LootDisplayRow
			if r ~= row then
				snapshots[r] = getEdgeY(r)
			end
		end
	end

	-- FLIP Phase 2: Re-anchor the chain (WoW snaps downstream rows here)
	row:UpdateNeighborPositions(self)
	self.rows:remove(row)
	row:SetParent(nil)
	if row.onReleased then
		row.onReleased()
		row.onReleased = nil
	end
	row.key = nil
	-- If this row was pinned, clear the frame-level pin gate before Reset()
	-- clears row.isPinned — otherwise the gate stays stuck and blocks the queue.
	if row.isPinned then
		self.hasPinnedRow = false
	end
	row:Reset()
	self.rowFramePool:Release(row)

	-- Restore chain anchors for all remaining rows before Phase 3 so that
	-- getEdgeY returns each row's correct final destination, not a stale
	-- fast-forwarded frame-relative offset.  Rows broken out of the chain
	-- by a previous AnimateShift batch are frame-directly-anchored and won't
	-- benefit from WoW's cascade, so we re-anchor each one explicitly.
	-- All changes occur within the same script invocation so WoW batches
	-- them — AnimateShift's own ClearAllPoints+SetPoint overwrites these
	-- anchors before the renderer draws a frame, so no visual snap occurs.
	if useShiftAnimation then
		for r in self.rows:iterate() do
			---@cast r RLF_LootDisplayRow
			if not r.isPinned then
				r:UpdatePosition(self)
			end
		end
	end

	-- FLIP Phase 3: Invert — pre-compute all deltas before modifying any
	-- anchors.  AnimateShift breaks each row out of the chain via
	-- ClearAllPoints, so reading positions and modifying them in the same
	-- loop produces order-dependent results with pairs().
	local shifts
	if useShiftAnimation then
		local getEdgeY = (self.vertDir == "BOTTOM") and function(r)
			return r:GetBottom()
		end or function(r)
			return r:GetTop()
		end

		shifts = {}
		for r, oldEdgeY in pairs(snapshots) do
			---@cast r RLF_LootDisplayRow
			local newEdgeY = getEdgeY(r)
			local yDelta = oldEdgeY - newEdgeY
			if math.abs(yDelta) > 0.5 then -- ignore sub-pixel deltas
				shifts[r] = { yDelta = yDelta, oldEdgeY = oldEdgeY }
			end
		end
	end

	-- FLIP Phase 4: Play — apply animations with pre-computed values.
	local anyShifting = false
	if shifts then
		for r, info in pairs(shifts) do
			r:AnimateShift(info.yDelta, info.oldEdgeY)
			anyShifting = true
		end
	end

	-- Only send RLF_ROW_RETURNED immediately when no shift animation was
	-- started. When shifts ARE active, OnFinished sends it once shiftingRowCount
	-- reaches 0 — a single deterministic drain trigger, no double-fire.
	if not anyShifting then
		G_RLF:SendMessage("RLF_ROW_RETURNED", self.frameType)
	end
	self:UpdateTabVisibility()
end

--- Restore proper inter-row chain anchors on all active rows.
--- Called after all shift animations complete so rows transition from
--- frame-relative temp anchors back to the doubly-linked list chain.
--- Pinned rows are skipped: their anchor is a fixed frame-relative offset
--- managed by PinPosition/ReleasePin, not the sibling chain.
function LootDisplayFrameMixin:RestoreRowChain()
	for row in self.rows:iterate() do
		---@cast row RLF_LootDisplayRow
		if not row.isPinned then
			row:UpdatePosition(self)
		end
	end
end

function LootDisplayFrameMixin:StoreRowHistory(row)
	if not G_RLF.db.global.lootHistory.enabled then
		return
	end

	---@class RLF_LootHistoryRowData
	local rowData = {
		key = row.key,
		amount = row.amount,
		quality = row.quality,
		icon = row.icon,
		link = row.link,
		rowText = row.PrimaryText:GetText(),
		textColor = { row.PrimaryText:GetTextColor() },
		unit = row.unit,
		secondaryText = row.SecondaryText:GetText(),
		secondaryTextColor = { row.SecondaryText:GetTextColor() },
		-- Coin display data for money/vendor-price rows (textures, not text).
		-- nil for non-money rows; UpdateWithHistoryData restores these via
		-- UpdateCoinDisplay / UpdateSecondaryCoinDisplay.
		coinData = row._coinData,
		secondaryCoinData = row._secondaryCoinData,
	}
	table.insert(self.rowHistory, 1, rowData)

	-- Trim the history to the configured limit
	if #self.rowHistory > G_RLF.db.global.lootHistory.historyLimit then
		table.remove(self.rowHistory) -- Remove the oldest entry to maintain the limit
	end
end

function LootDisplayFrameMixin:Dump()
	local firstKey, lastKey
	if self.rows.first then
		firstKey = self.rows.first.key or "NONE"
	else
		firstKey = "first nil"
	end

	if self.rows.last then
		lastKey = self.rows.last.key or "NONE"
	else
		lastKey = "last nil"
	end

	return format(
		"{getNumberOfRows=%s,#rowFramePool=%s,#keyRowMap=%s,first.key=%s,last.key=%s}",
		self:getNumberOfRows(),
		self.rowFramePool:size(),
		self.keyRowMap.length,
		firstKey,
		lastKey
	)
end

function LootDisplayFrameMixin:UpdateRowPositions()
	self.vertDir, self.opposite, self.yOffset, self.horizDir = self:getPositioningDetails()
	local index = 1
	for row in self.rows:iterate() do
		row:UpdatePosition(self)
		if index > self:getNumberOfRows() + 2 then
			error("Possible infinite loop detected!: " .. self:Dump())
		end
		index = index + 1
	end
end

function LootDisplayFrameMixin:CreateHistoryFrame()
	-- Parent to UIParent rather than self so the scrollbar from
	-- UIPanelScrollFrameTemplate is not clipped by self's clipChildren="true".
	-- Strata/level are set in UpdateOverlayFrameDepth; anchor stays on self.
	self.historyFrame = CreateFrame("ScrollFrame", nil, UIParent, "UIPanelScrollFrameTemplate")
	self.historyFrame:SetSize(self:GetSize())
	self.historyFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
	if not self.historyTitle then
		self.historyTitle = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end
	self.historyTitle:ClearAllPoints()
	self.historyTitle:SetPoint("BOTTOMLEFT", self.historyFrame, "TOPLEFT", 0, 0)
	local frameName = G_RLF.db.global.frames[self.frameType] and G_RLF.db.global.frames[self.frameType].name or ""
	local titleText = G_RLF.L["Loot History"] --[[@as string]]
	if frameName ~= "" then
		titleText = frameName .. " " .. titleText
	end
	self.historyTitle:SetText(titleText)

	-- Close button (×) to dismiss history mode without scrolling.
	-- Anchored to the right of the title, using UIParent as parent so it sits
	-- above the scroll frame in the draw order.
	if not self.historyCloseButton then
		self.historyCloseButton = CreateFrame("Button", nil, UIParent)
		self.historyCloseButton:SetSize(14, 14)
		self.historyCloseButton:SetPoint("LEFT", self.historyTitle, "RIGHT", 4, 0)
		self.historyCloseButton:SetFrameStrata(self:GetFrameStrata())
		self.historyCloseButton:SetFrameLevel(self:GetFrameLevel() + 25)
		self.historyCloseButton:Hide()

		-- Large "X" centered on the button; SetFontObject gives a readable glyph
		-- even though the click area is small.
		local closeText = self.historyCloseButton:CreateFontString(nil, "OVERLAY")
		closeText:SetFontObject(GameFontNormalLarge)
		closeText:SetTextColor(1, 0.25, 0.25)
		closeText:SetText("X")
		closeText:SetPoint("CENTER", self.historyCloseButton, "CENTER", 0, 0)

		self.historyCloseButton:SetScript("OnClick", function()
			G_RLF.HistoryService:HideHistoryFrame()
		end)
		self.historyCloseButton:SetScript("OnEnter", function()
			GameTooltip:SetOwner(self.historyCloseButton, "ANCHOR_RIGHT")
			GameTooltip:SetText(G_RLF.L["Close History"], 1, 1, 1)
			GameTooltip:Show()
		end)
		self.historyCloseButton:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	self.historyContent = CreateFrame("Frame", nil, self.historyFrame)
	self.historyContent:SetSize(self:GetSize())
	self.historyFrame:SetScrollChild(self.historyContent)

	---@type RLF_LootDisplayRow[]
	self.historyRows = {}
	local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)
	for i = 1, sizingDb.maxRows do
		local row = CreateFrame("Frame", nil, self.historyContent, "LootDisplayRowTemplate")
		row.frameType = self.frameType
		row:SetSize(sizingDb.feedWidth, sizingDb.rowHeight)
		row:Init()
		table.insert(self.historyRows, row)
	end

	self.historyFrame:SetScript("OnVerticalScroll", function(_, offset)
		self:UpdateHistoryFrame(offset)
	end)

	self:UpdateOverlayFrameDepth()
end

function LootDisplayFrameMixin:UpdateHistoryFrame(offset)
	offset = offset or 0
	---@type RLF_ConfigSizing
	local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)
	local padding = sizingDb.padding
	local feedWidth = sizingDb.feedWidth
	local rowHeight = sizingDb.rowHeight + padding
	local visibleRows = sizingDb.maxRows
	local totalRows = #self.rowHistory
	local contentSize = totalRows * rowHeight - padding
	local startIndex = math.floor(offset / rowHeight) + 1
	local endIndex = math.min(startIndex + visibleRows - 1, totalRows)

	for i, row in ipairs(self.historyRows) do
		local dataIndex = startIndex + i - 1
		if dataIndex <= endIndex then
			row:UpdateWithHistoryData(self.rowHistory[dataIndex])
			row:Show()
			row:ElementsVisible()
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", self.historyFrame, "TOPLEFT", 0, (i - 1) * -rowHeight)
		else
			row:Hide()
		end
	end

	self.historyFrame:SetSize(feedWidth, self:getFrameHeight() + rowHeight)
	self.historyContent:SetSize(feedWidth, contentSize)
end

function LootDisplayFrameMixin:ShowHistoryFrame()
	if not self.historyFrame then
		self:CreateHistoryFrame()
	end
	-- Move any currently visible live rows into history before switching views
	self:ClearFeed()
	self:UpdateHistoryFrame()
	self.historyFrame:Show()
	if self.historyTitle then
		self.historyTitle:Show()
	end
	if self.historyCloseButton then
		self.historyCloseButton:Show()
	end
end

function LootDisplayFrameMixin:HideHistoryFrame()
	if self.historyFrame then
		self.historyFrame:Hide()
		self.historyFrame:SetVerticalScroll(0)
	end
	if self.historyTitle then
		self.historyTitle:Hide()
	end
	if self.historyCloseButton then
		self.historyCloseButton:Hide()
	end
	-- Clear any in-progress scroll sequence so the next interaction starts fresh
	if self.wheelState then
		G_RLF.HistoryService:ResetWheelState(self.wheelState)
	end
end

function LootDisplayFrameMixin:UpdateRowItemCounts()
	for row in self.rows:iterate() do
		---@type RLF_LootDisplayRow
		local row = row --[[@as RLF_LootDisplayRow]]
		if row.key and row.type == "ItemLoot" and not row.unit then
			row:UpdateItemCount()
		end
	end
end

return LootDisplayFrameMixin
