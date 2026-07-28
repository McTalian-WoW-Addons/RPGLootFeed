---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_LootRollRowMixin
---@field rollID number|nil
---@field _rolled boolean
---@field _rollButtons table[]
---@field _rollResultText FontString|nil
---@field _rollTimerFrame Frame|nil
---@field _rollGreedBtn Button|nil
---@field _rollTransmogBtn Button|nil
RLF_LootRollRowMixin = {}

local BUTTON_GAP = 4
local PADDING_RIGHT = 8

--- Atlas name suffix table matching Blizzard's loot roll button textures.
local ROLL_BUTTON_ATLAS = {
	[LOOT_ROLL_TYPE_NEED] = { base = "lootroll-toast-icon-need" },
	[LOOT_ROLL_TYPE_GREED] = { base = "lootroll-toast-icon-greed" },
	[LOOT_ROLL_TYPE_PASS] = { base = "lootroll-toast-icon-pass" },
	[4] = { base = "lootroll-toast-icon-transmog" }, -- Transmog
}

--- Create a single roll button matching Blizzard's LootRollButtonTemplate.
--- Uses atlas textures and tooltip mirroring the built-in group loot frame.
--- Resolve the button size from the frame's lootRolls config, falling back to 18.
---@return number
function RLF_LootRollRowMixin:_GetButtonSize()
	local frameConfig = G_RLF.db.global.frames[self.frameType]
	if frameConfig and frameConfig.features and frameConfig.features.lootRolls then
		return frameConfig.features.lootRolls.buttonSize or 18
	end
	return 18
end

---@param label string  Button label text (tooltip title)
---@param id number  Roll type id passed to RollOnLoot
---@param enabled boolean  Whether the button starts enabled
---@param reason number|nil  Ineligibility reason key suffix
---@return Button
function RLF_LootRollRowMixin:_CreateRollButton(label, id, enabled, reason)
	local btnSize = self:_GetButtonSize()
	local btn = CreateFrame("Button", nil, self)
	btn:SetSize(btnSize, btnSize)
	btn:SetMotionScriptsWhileDisabled(true)

	-- Normal texture (atlas)
	local nt = btn:CreateTexture(nil, "BACKGROUND")
	local atlasInfo = ROLL_BUTTON_ATLAS[id]
	if atlasInfo then
		nt:SetAtlas(atlasInfo.base .. "-up", TextureKitConstants.IgnoreAtlasSize)
	end
	nt:SetAllPoints()
	btn:SetNormalTexture(nt)

	-- Pushed texture
	local pt = btn:CreateTexture(nil, "BACKGROUND")
	if atlasInfo then
		pt:SetAtlas(atlasInfo.base .. "-down", TextureKitConstants.IgnoreAtlasSize)
	end
	pt:SetAllPoints()
	btn:SetPushedTexture(pt)

	-- Highlight texture (ADD blend mode)
	local ht = btn:CreateTexture(nil, "HIGHLIGHT")
	if atlasInfo then
		ht:SetAtlas(atlasInfo.base .. "-highlight", TextureKitConstants.IgnoreAtlasSize)
	end
	ht:SetAllPoints()
	ht:SetBlendMode("ADD")
	btn:SetHighlightTexture(ht)

	-- Fallback for buttons without atlas (e.g. Disenchant in Classic)
	if not atlasInfo then
		btn:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			insets = { left = 1, right = 1, top = 1, bottom = 1 },
		})
		btn:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
		local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		txt:SetText(label)
		txt:SetPoint("CENTER")
		txt:SetTextColor(1, 1, 1)
	end

	-- Tooltip — matches Blizzard's LootRollButtonTemplate OnEnter/OnLeave
	btn:SetScript("OnEnter", function()
		if G_RLF.db.global.interactions.disableAllInteraction then
			return
		end
		GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, label)
		if reason then
			local reasonText = _G["LOOT_ROLL_INELIGIBLE_REASON" .. reason]
			if reasonText then
				GameTooltip:AddLine(reasonText, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true)
			end
		end
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function()
		if G_RLF.db.global.interactions.disableAllInteraction then
			return
		end
		GameTooltip:Hide()
	end)

	-- Click — only fires when enabled (Blizzard disables non-eligible buttons)
	btn:SetScript("OnClick", function()
		if G_RLF.db.global.interactions.disableAllInteraction then
			return
		end
		RollOnLoot(self.rollID, id)
		self:OnRollCast(label, id)
	end)

	if not enabled then
		btn:Disable()
		btn:SetAlpha(0.45)
	end

	return btn
end

--- Position roll buttons along the right edge of the row.
function RLF_LootRollRowMixin:_LayoutRollButtons()
	if not self._rollButtons or #self._rollButtons == 0 then
		return
	end

	local btnSize = self:_GetButtonSize()
	local rowWidth = self:GetWidth() or 256

	local count = #self._rollButtons
	for i = count, 1, -1 do
		local btn = self._rollButtons[i]
		btn:ClearAllPoints()
		btn:SetPoint("RIGHT", self, "RIGHT", -(count - i) * (btnSize + BUTTON_GAP) - PADDING_RIGHT, 0)
		btn:Show()
	end
end

--- Update the timer bar from GetLootRollTimeLeft (or static display for samples).
function RLF_LootRollRowMixin:_UpdateRollTimer()
	if not self.rollID then
		return
	end
	if not GetLootRollTimeLeft then
		return
	end

	local left = GetLootRollTimeLeft(self.rollID)
	if not left then
		return
	end

	local minVal, maxVal = self.TimerBar:GetMinMaxValues()
	if left <= 0 or left > maxVal then
		self.TimerBar:SetValue(0)
	elseif minVal ~= maxVal then
		-- Add 1s padding so bar doesn't hit 0 before CANCEL_LOOT_ROLL fires
		local padded = math.max(left, 1)
		self.TimerBar:SetValue(padded)
	end
end

--- Handle cancel for this roll row.
function RLF_LootRollRowMixin:OnCancelRoll()
	-- The LootRolls module calls this, then releases the row via ReleaseRow
end

--- Handle MAIN_SPEC_NEED_ROLL — show local player's need roll result.
---@param roll number  The roll value
---@param isWinning boolean  Whether this is currently the winning roll
function RLF_LootRollRowMixin:OnMainSpecNeedRoll(roll, isWinning)
	if self._rolled then
		local color = isWinning and "ff00ff00" or "ffb0b0b0"
		self.ItemCountText:SetFormattedText("|c%sNeed (%d)|r", color, roll)
		self.ItemCountText:Show()
	end
end

--- Handle LOOT_ITEM_ROLL_WON — update row to show win state in ItemCountText.
---@param rollType number
---@param roll number
---@param isUpgraded? boolean
function RLF_LootRollRowMixin:OnRollWon(rollType, roll, isUpgraded)
	local rollTypeNames = {
		[1] = NEED,
		[2] = GREED,
		[3] = DISENCHANT,
		[4] = TRANSMOGRIFICATION,
	}
	local typeName = rollTypeNames[rollType] or ""
	local upgradeText = isUpgraded and " (Upgraded!)" or ""
	self.ItemCountText:SetFormattedText("|cff00ff00%s Won! (%d)%s|r", typeName, roll, upgradeText)
	self.ItemCountText:Show()
end

---@class RLF_RollTooltipIcons
local ROLL_TOOLTIP_ICONS = {
	-- Need Main Spec (0) and Need Off Spec (1) both use the dice icon
	[0] = "|TInterface\\Buttons\\UI-GroupLoot-Dice-Up:16:16|t",
	[1] = "|TInterface\\Buttons\\UI-GroupLoot-Dice-Up:16:16|t",
	-- Transmog (atlas from group loot toast)
	[2] = "|A:lootroll-toast-icon-transmog-up:16:16|a",
	-- Greed
	[3] = "|TInterface\\Buttons\\UI-GroupLoot-Coin-Up:16:16|t",
	-- Pass
	[5] = "|TInterface\\Buttons\\UI-GroupLoot-Pass-Up:16:16|t",
}

--- Build grouped roll tooltip lines: sections for Waiting, Need, Greed, Transmog, Pass.
--- Each section shows a header with count, then player lines sorted by roll value descending.
---@param dropInfo table
---@param lines table  Output: list of {text, r, g, b} tuples
function RLF_LootRollRowMixin:_BuildRollTooltipLines(dropInfo, lines)
	-- Group players by state
	local groups = {
		waiting = {}, -- state 4
		need = {}, -- states 0, 1
		greed = {}, -- state 3
		transmog = {}, -- state 2
		pass = {}, -- state 5
	}
	local order = { "waiting", "need", "greed", "transmog", "pass" }
	local sectionLabels = {
		waiting = LOOT_HISTORY_WAITING_ON,
		need = NEED,
		greed = GREED,
		transmog = TRANSMOGRIFICATION,
		pass = PASS,
	}
	local sectionColors = {
		waiting = { 1, 1, 0.5 },
		need = { 1, 1, 1 },
		greed = { 1, 1, 1 },
		transmog = { 1, 1, 1 },
		pass = { 0.7, 0.7, 0.7 },
	}

	for _, ri in ipairs(dropInfo.rollInfos) do
		local classColor = RAID_CLASS_COLORS[ri.playerClass]
		local r, g, b = 1, 1, 1
		if classColor then
			r, g, b = classColor.r, classColor.g, classColor.b
		end
		if ri.isSelf then
			r, g, b = 0.3, 1, 0.3
		end

		local playerData = {
			name = ri.playerName,
			classColor = classColor,
			r = r,
			g = g,
			b = b,
			roll = ri.roll,
			isWinner = ri.isWinner,
			isSelf = ri.isSelf,
			state = ri.state,
		}

		if ri.state == 4 then
			table.insert(groups.waiting, playerData)
		elseif ri.state == 0 or ri.state == 1 then
			playerData.spec = ri.state == 0 and "MainSpec" or "OffSpec"
			table.insert(groups.need, playerData)
		elseif ri.state == 3 then
			table.insert(groups.greed, playerData)
		elseif ri.state == 2 then
			table.insert(groups.transmog, playerData)
		elseif ri.state == 5 then
			table.insert(groups.pass, playerData)
		end
	end

	-- Sort sections with rolls by value descending (nil = no roll, sorts last)
	local function sortByRoll(a, b)
		if a.roll and b.roll then
			return a.roll > b.roll
		end
		if a.roll then
			return true
		end
		if b.roll then
			return false
		end
		return a.name < b.name
	end
	table.sort(groups.need, sortByRoll)
	table.sort(groups.greed, sortByRoll)
	table.sort(groups.transmog, sortByRoll)

	-- Build lines per section
	for _, section in ipairs(order) do
		local players = groups[section]
		if #players > 0 then
			local hdr = sectionLabels[section]
			local hc = sectionColors[section]
			table.insert(lines, { format("%s (%d)", hdr, #players), hc[1], hc[2], hc[3] })
			for _, p in ipairs(players) do
				local iconTex = ROLL_TOOLTIP_ICONS[p.state] or ""
				local winnerMark = p.isWinner and " |cff00ff00<-- Winner|r" or ""
				local selfMark = p.isSelf and " *" or ""
				if p.roll then
					local specStr = p.spec and format(", %s", p.spec) or ""
					table.insert(lines, {
						format("  %s%s (%d%s)%s%s", iconTex, p.name, p.roll, specStr, winnerMark, selfMark),
						p.r,
						p.g,
						p.b,
					})
				else
					table.insert(lines, { format("  %s%s%s", iconTex, p.name, selfMark), p.r, p.g, p.b })
				end
			end
		end
	end
end

--- Show a tooltip with detailed per-player roll info in grouped sections.
function RLF_LootRollRowMixin:_ShowRollTooltip()
	local dropInfo = self._rollDropInfo
	if not dropInfo or not dropInfo.rollInfos then
		return
	end

	local lines = {}
	self:_BuildRollTooltipLines(dropInfo, lines)
	if #lines == 0 then
		return
	end

	GameTooltip:SetOwner(self.SecondaryText, "ANCHOR_RIGHT")
	GameTooltip:AddLine(LOOT_ROLLS, 1, 1, 1)
	GameTooltip:AddLine(" ")
	for _, line in ipairs(lines) do
		GameTooltip:AddLine(line[1], line[2], line[3], line[4])
	end
	GameTooltip:Show()
end

function RLF_LootRollRowMixin:_HideRollTooltip()
	GameTooltip:Hide()
end

--- Append grouped roll info lines to the existing item tooltip.
function RLF_LootRollRowMixin:_AppendRollTooltipToItem()
	local dropInfo = self._rollDropInfo
	if not dropInfo or not dropInfo.rollInfos then
		return
	end

	local lines = {}
	self:_BuildRollTooltipLines(dropInfo, lines)
	if #lines == 0 then
		return
	end

	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(LOOT_ROLLS, 1, 1, 1)
	GameTooltip:AddLine(" ")
	for _, line in ipairs(lines) do
		GameTooltip:AddLine(line[1], line[2], line[3], line[4])
	end
	GameTooltip:Show()
end

--- Setup tooltip on the secondary text for detailed roll info.
function RLF_LootRollRowMixin:_SetupRollTooltip()
	self.SecondaryText:SetScript("OnEnter", function()
		if G_RLF.db.global.interactions.disableAllInteraction then
			return
		end
		self:_ShowRollTooltip()
	end)
	self.SecondaryText:SetScript("OnLeave", function()
		if G_RLF.db.global.interactions.disableAllInteraction then
			return
		end
		self:_HideRollTooltip()
	end)
end

--- Update the row's display with per-player roll results from loot history.
--- Secondary text shows "Waiting on N player(s)" while unresolved.
--- Primary text shows winner, all passed, or current leader when player has rolled.
---@param dropInfo table EncounterLootDropInfo from C_LootHistory
function RLF_LootRollRowMixin:SetRollResults(dropInfo)
	if not dropInfo or not dropInfo.rollInfos then
		return
	end

	-- Store for tooltip access
	self._rollDropInfo = dropInfo

	-- Count states
	local waitingCount = 0
	local allPassed = true
	for _, ri in ipairs(dropInfo.rollInfos) do
		if ri.state == 4 then -- NoRoll
			waitingCount = waitingCount + 1
		end
		if ri.state ~= 5 and ri.state ~= 4 then -- Not Pass and not NoRoll
			allPassed = false
		end
	end

	-- Secondary text: waiting count with tooltip, or blank.
	-- Only shown on the secondary line when the user has enabled secondary row text.
	-- When disabled, the waiting info is still available via hover tooltip.
	--
	-- NOTE: StyleText() skips anchoring SecondaryLineLayout when secondaryText is nil
	-- (which it always is during BootstrapFromElement — UpdateSecondaryText clears it).
	-- Call _LayoutRowLines() directly to anchor both lines with the vertical split.
	local stylingDb = G_RLF.DbAccessor:Styling(self.frameType)
	if waitingCount > 0 and stylingDb.enabledSecondaryRowText then
		self.secondaryText = format("Waiting on %d player(s)", waitingCount)
		self.SecondaryText:SetText(self.secondaryText)
		self.SecondaryText:Show()
		local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)
		local spacing = (stylingDb.rowTextSpacing or 0) == 0 and (sizingDb.iconSize / 4) or stylingDb.rowTextSpacing
		self:_LayoutRowLines(
			stylingDb.textAlignment,
			stylingDb.textAlignment ~= G_RLF.TextAlignment.RIGHT,
			sizingDb.padding,
			spacing
		)
		self.SecondaryLineLayout:Show()
		self:LayoutSecondaryLine()
		self:_SetupRollTooltip()
	else
		self.secondaryText = nil
		self.SecondaryText:Hide()
		self.SecondaryLineLayout:Hide()
	end

	-- ItemCountText: show winner, all passed, or current leader on the primary line
	if dropInfo.winner then
		local classColor = RAID_CLASS_COLORS[dropInfo.winner.playerClass]
		local rollTypeStr = ""
		if dropInfo.winner.state == 0 or dropInfo.winner.state == 1 then
			rollTypeStr = NEED
		elseif dropInfo.winner.state == 2 then
			rollTypeStr = TRANSMOGRIFICATION
		elseif dropInfo.winner.state == 3 then
			rollTypeStr = GREED
		end

		if dropInfo.winner.isSelf then
			self.ItemCountText:SetFormattedText("|cff00ff00You won! (%s, %d)|r", rollTypeStr, dropInfo.winner.roll)
		else
			local name = classColor and classColor:WrapTextInColorCode(dropInfo.winner.playerName)
				or dropInfo.winner.playerName
			self.ItemCountText:SetFormattedText("%s won (%s, %d)", name, rollTypeStr, dropInfo.winner.roll)
		end
		self.ItemCountText:Show()
	elseif allPassed then
		self.ItemCountText:SetFormattedText("|cffb0b0b0%s|r", LOOT_HISTORY_ALL_PASSED)
		self.ItemCountText:Show()
	elseif self._rolled and dropInfo.currentLeader then
		-- Only show leader text if the player has already rolled
		local classColor = RAID_CLASS_COLORS[dropInfo.currentLeader.playerClass]
		local name = classColor and classColor:WrapTextInColorCode(dropInfo.currentLeader.playerName)
			or dropInfo.currentLeader.playerName
		self.ItemCountText:SetFormattedText("%s leads (%d)", name, dropInfo.currentLeader.roll)
		self.ItemCountText:Show()
	end
end

--- Called after the player clicks a roll button.
--- Shows roll selection in ItemCountText (primary line, right of item link).
---@param label string
---@param id number
function RLF_LootRollRowMixin:OnRollCast(label, id)
	self._rolled = true

	-- Hide all roll buttons
	for _, btn in ipairs(self._rollButtons or {}) do
		btn:Hide()
	end

	-- Show roll selection in ItemCountText on the primary line
	if id == LOOT_ROLL_TYPE_PASS then
		self.ItemCountText:SetFormattedText("|cffb0b0b0%s|r", PASS)
	else
		self.ItemCountText:SetText(label)
	end
	self.ItemCountText:Show()
end

---@param element RLF_BaseLootElement
function RLF_LootRollRowMixin:PostBootstrapFromElement(element)
	if element.type ~= G_RLF.FeatureModule.LootRolls then
		return
	end

	self.rollID = element.rollID
	self._rolled = false
	self._isLootRollRow = true

	-- Fetch eligibility: element provides its own for sample rows; real rows call API
	local canNeed, canGreed, canTransmog
	local reasonNeed, reasonGreed
	local canDisenchant, reasonDisenchant
	if element.canNeed ~= nil then
		canNeed = element.canNeed
		canGreed = element.canGreed
		canTransmog = element.canTransmog
		reasonNeed = element.reasonNeed
		reasonGreed = element.reasonGreed
		canDisenchant = nil
		reasonDisenchant = nil
	elseif element.rollID then
		local _, _, _, _, _, cn, cg, cd, rn, rg, rd, _, ct = GetLootRollItemInfo(element.rollID)
		canNeed, canGreed, canTransmog = cn, cg, ct
		reasonNeed, reasonGreed = rn, rg
		canDisenchant, reasonDisenchant = cd, rd
	else
		-- No eligibility data and no rollID — nothing to show
		return
	end

	-- Build button list
	self._rollButtons = {}

	-- For sample/test rows (no real rollID), buttons are shown but disabled
	local hasRealRoll = self.rollID ~= nil

	-- Need button
	local needBtn = self:_CreateRollButton(
		NEED,
		LOOT_ROLL_TYPE_NEED,
		hasRealRoll and canNeed or false,
		hasRealRoll and reasonNeed or nil
	)
	table.insert(self._rollButtons, needBtn)

	-- Greed or Transmog (mutually exclusive, Transmog replaces Greed)
	if canTransmog then
		local transmogBtn = self:_CreateRollButton(TRANSMOGRIFICATION, 4, hasRealRoll and true or false, nil)
		table.insert(self._rollButtons, transmogBtn)
	else
		local greedBtn = self:_CreateRollButton(
			GREED,
			LOOT_ROLL_TYPE_GREED,
			hasRealRoll and canGreed or false,
			hasRealRoll and reasonGreed or nil
		)
		table.insert(self._rollButtons, greedBtn)
	end

	-- Disenchant button (Classic only: no DE atlas, use text label)
	if not G_RLF:IsRetail() and canDisenchant then
		local deEnabled = hasRealRoll and canDisenchant or false
		local deReason = hasRealRoll and reasonDisenchant or nil
		local deBtn = self:_CreateRollButton(DISENCHANT, LOOT_ROLL_TYPE_DISENCHANT, deEnabled, deReason)
		table.insert(self._rollButtons, deBtn)
	end

	-- Pass button (shown disabled for sample/test rows)
	local passBtn = self:_CreateRollButton(PASS, LOOT_ROLL_TYPE_PASS, hasRealRoll, nil)
	table.insert(self._rollButtons, passBtn)

	self:_LayoutRollButtons()

	-- Auto-hide after roll duration + 1s padding (CANCEL_LOOT_ROLL dismisses earlier)
	-- Note: StyleExitAnimation overrides showForSeconds for isSampleRow, so restore after
	self.showForSeconds = (element.rollDuration or 60) + 1
	self.hasElementFadeOverride = true
	self:StyleExitAnimation()
	self.showForSeconds = (element.rollDuration or 60) + 1

	-- Setup timer bar — use custom OnUpdate polling GetLootRollTimeLeft
	-- Apply height/color/alpha from animation config but force-show regardless of enabled state
	local animCfg = G_RLF.DbAccessor:Animations(self.frameType)
	if animCfg and animCfg.timerBar then
		local cfg = animCfg.timerBar
		if cfg.height then
			self.TimerBar:SetHeight(cfg.height)
		end
		if cfg.color then
			self.TimerBar:SetStatusBarColor(cfg.color[1], cfg.color[2], cfg.color[3], cfg.alpha or 0.7)
		end
	end
	self.TimerBar:SetMinMaxValues(0, element.rollDuration or 60)
	self.TimerBar:SetValue(element.rollDuration or 60)
	self.TimerBar:Show()

	-- Custom OnUpdate for polling GetLootRollTimeLeft
	self._rollTimerFrame = CreateFrame("Frame")
	self._rollTimerFrame:SetScript("OnUpdate", function()
		self:_UpdateRollTimer()
	end)

	-- Phase 2 enrichment: mock drop info for sample/test rows to showcase the feature
	if element.mockDropInfo then
		self:SetRollResults(element.mockDropInfo)
	end

	-- Hook the ClickableButton tooltip to append roll info after the item tooltip
	if self.ClickableButton then
		local origOnEnter = self.ClickableButton:GetScript("OnEnter")
		local origOnLeave = self.ClickableButton:GetScript("OnLeave")
		self.ClickableButton:SetScript("OnEnter", function()
			if origOnEnter then
				origOnEnter()
			end
			-- Append roll info lines after item tooltip
			if self._rollDropInfo then
				self:_AppendRollTooltipToItem()
			end
		end)
		if origOnLeave then
			self.ClickableButton:SetScript("OnLeave", origOnLeave)
		end
	end
end

--- Cleanup all loot roll state (called from Reset).
function RLF_LootRollRowMixin:CleanupLootRoll()
	self.rollID = nil
	self._rolled = false

	-- Destroy roll buttons
	if self._rollButtons then
		for _, btn in ipairs(self._rollButtons) do
			btn:Hide()
			btn:SetScript("OnClick", nil)
			btn:SetScript("OnEnter", nil)
			btn:SetScript("OnLeave", nil)
		end
		self._rollButtons = nil
	end

	-- Reset roll status text on primary line
	self.ItemCountText:SetText(nil)
	self.ItemCountText:Hide()

	-- Clear loot history data and tooltip hooks
	self._rollDropInfo = nil
	self.SecondaryText:SetScript("OnEnter", nil)
	self.SecondaryText:SetScript("OnLeave", nil)

	-- Stop timer frame
	if self._rollTimerFrame then
		self._rollTimerFrame:SetScript("OnUpdate", nil)
		self._rollTimerFrame = nil
	end

	-- Reset timer bar to default hidden state
	self:ResetTimerBar()
end

G_RLF.RLF_LootRollRowMixin = RLF_LootRollRowMixin
