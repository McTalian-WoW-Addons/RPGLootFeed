---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_LootRollRowMixin
---@field rollID number|nil
---@field _rolled boolean
---@field _rollButtons table[]
---@field _rollDropInfo table|nil
---@field _rollTimerFrame Frame|nil
---@field _displayStart number|nil
---@field _resolved boolean|nil
---@field _timerLogNext number|nil
RLF_LootRollRowMixin = {}

local BUTTON_GAP = 4
local PADDING_RIGHT = 8
local RESULTS_DISPLAY_SECONDS = 60

--- Atlas name suffix table matching Blizzard's loot roll button textures.
local ROLL_BUTTON_ATLAS = {
	[LOOT_ROLL_TYPE_NEED] = { base = "lootroll-toast-icon-need" },
	[LOOT_ROLL_TYPE_GREED] = { base = "lootroll-toast-icon-greed" },
	[LOOT_ROLL_TYPE_PASS] = { base = "lootroll-toast-icon-pass" },
	[4] = { base = "lootroll-toast-icon-transmog" }, -- Transmog
}

---@return number
function RLF_LootRollRowMixin:_GetButtonSize()
	local frameConfig = G_RLF.db.global.frames[self.frameType]
	if frameConfig and frameConfig.features and frameConfig.features.lootRolls then
		return frameConfig.features.lootRolls.buttonSize or 18
	end
	return 18
end

---@param label string
---@param id number
---@param enabled boolean
---@param reason number|nil
---@return Button
function RLF_LootRollRowMixin:_CreateRollButton(label, id, enabled, reason)
	local btnSize = self:_GetButtonSize()
	local btn = CreateFrame("Button", nil, self)
	btn:SetSize(btnSize, btnSize)
	btn:SetMotionScriptsWhileDisabled(true)

	local nt = btn:CreateTexture(nil, "BACKGROUND")
	local atlasInfo = ROLL_BUTTON_ATLAS[id]
	if atlasInfo then
		nt:SetAtlas(atlasInfo.base .. "-up", TextureKitConstants.IgnoreAtlasSize)
	end
	nt:SetAllPoints()
	btn:SetNormalTexture(nt)

	local pt = btn:CreateTexture(nil, "BACKGROUND")
	if atlasInfo then
		pt:SetAtlas(atlasInfo.base .. "-down", TextureKitConstants.IgnoreAtlasSize)
	end
	pt:SetAllPoints()
	btn:SetPushedTexture(pt)

	local ht = btn:CreateTexture(nil, "HIGHLIGHT")
	if atlasInfo then
		ht:SetAtlas(atlasInfo.base .. "-highlight", TextureKitConstants.IgnoreAtlasSize)
	end
	ht:SetAllPoints()
	ht:SetBlendMode("ADD")
	btn:SetHighlightTexture(ht)

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

function RLF_LootRollRowMixin:_LayoutRollButtons()
	if not self._rollButtons or #self._rollButtons == 0 then
		return
	end

	local btnSize = self:_GetButtonSize()
	local count = #self._rollButtons
	for i = count, 1, -1 do
		local btn = self._rollButtons[i]
		btn:ClearAllPoints()
		btn:SetPoint("RIGHT", self, "RIGHT", -(count - i) * (btnSize + BUTTON_GAP) - PADDING_RIGHT, 0)
		btn:Show()
	end
end

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

	-- Only log once per second to avoid spam
	if not self._timerLogNext or GetTime() >= self._timerLogNext then
		local minVal, maxVal = self.TimerBar:GetMinMaxValues()
		G_RLF:LogDebug(
			("UpdateRollTimer rollID=%s left=%s min=%s max=%s"):format(
				tostring(self.rollID),
				tostring(left),
				tostring(minVal),
				tostring(maxVal)
			),
			addonName,
			"LootRolls"
		)
		self._timerLogNext = GetTime() + 1
	end

	local minVal, maxVal = self.TimerBar:GetMinMaxValues()
	if left <= 0 then
		self.TimerBar:SetValue(0)
	elseif minVal ~= maxVal then
		local padded = math.min(math.max(left, 1), maxVal)
		self.TimerBar:SetValue(padded)
	end
end

function RLF_LootRollRowMixin:OnCancelRoll()
	if self._rollTimerFrame then
		self._rollTimerFrame:SetScript("OnUpdate", nil)
		self._rollTimerFrame = nil
	end
	self:ResetTimerBar()
end

--- Transition to resolved results row. Enables normal row behaviors:
--- auto-hide (60s), hover pause, right-click dismiss.
function RLF_LootRollRowMixin:OnRollResolved()
	if self._resolved then
		return
	end
	self._resolved = true

	-- Clear roll-row flag so normal hover/exit/right-click behaviors work
	self._isLootRollRow = false

	self.showForSeconds = RESULTS_DISPLAY_SECONDS
	self.hasElementFadeOverride = true
	self:StyleExitAnimation()

	-- Timer bar: show countdown for the display period
	self.TimerBar:SetMinMaxValues(0, RESULTS_DISPLAY_SECONDS)
	self.TimerBar:SetValue(RESULTS_DISPLAY_SECONDS)
	self.TimerBar:Show()
	G_RLF:LogDebug(("OnRollResolved rollID=%s"):format(tostring(self.rollID or "?")), addonName, "LootRolls")

	-- OnCancelRoll killed the old polling frame. Start a new one for display countdown.
	self._displayStart = GetTime()
	self._rollTimerFrame = CreateFrame("Frame")
	self._rollTimerFrame:SetScript("OnUpdate", function()
		if not self.TimerBar then
			return
		end
		local elapsed = GetTime() - self._displayStart
		local remaining = math.max(RESULTS_DISPLAY_SECONDS - elapsed, 0)
		self.TimerBar:SetValue(remaining)
		if remaining <= 0 then
			self._rollTimerFrame:SetScript("OnUpdate", nil)
			self._rollTimerFrame = nil
		end
	end)
end

--- Helper: set ItemCountText and reflow primary line layout.
--- Without LayoutPrimaryLine, ItemCountText overlaps PrimaryText.
---@param text string
local function _ShowRollText(self, text)
	self.ItemCountText:SetText(text)
	self.ItemCountText:Show()
	self:LayoutPrimaryLine()
end

--- Handle MAIN_SPEC_NEED_ROLL — show local player's need roll result.
---@param roll number
---@param isWinning boolean
function RLF_LootRollRowMixin:OnMainSpecNeedRoll(roll, isWinning)
	if self._rolled then
		local color = isWinning and "ff00ff00" or "ffb0b0b0"
		_ShowRollText(self, ("|c%sNeed (%d)|r"):format(color, roll))
	end
end

--- Handle LOOT_ITEM_ROLL_WON — update row to show win state.
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
	_ShowRollText(self, ("|cff00ff00%s Won! (%d)%s|r"):format(typeName, roll, upgradeText))
end

---@class RLF_RollTooltipIcons
local ROLL_TOOLTIP_ICONS = {
	[0] = "|TInterface\\Buttons\\UI-GroupLoot-Dice-Up:16:16|t",
	[1] = "|TInterface\\Buttons\\UI-GroupLoot-Dice-Up:16:16|t",
	[2] = "|A:lootroll-toast-icon-transmog-up:16:16|a",
	[3] = "|TInterface\\Buttons\\UI-GroupLoot-Coin-Up:16:16|t",
	[5] = "|TInterface\\Buttons\\UI-GroupLoot-Pass-Up:16:16|t",
}

---@param dropInfo table
---@param lines table
function RLF_LootRollRowMixin:_BuildRollTooltipLines(dropInfo, lines)
	local groups = {
		waiting = {},
		need = {},
		greed = {},
		transmog = {},
		pass = {},
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
		-- ri.isSelf uses class color, <YOU> appended in display

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

	for _, section in ipairs(order) do
		local players = groups[section]
		if #players > 0 then
			local hdr = sectionLabels[section]
			local hc = sectionColors[section]
			table.insert(lines, { format("%s (%d)", hdr, #players), hc[1], hc[2], hc[3] })
			for _, p in ipairs(players) do
				local iconTex = ROLL_TOOLTIP_ICONS[p.state] or ""
				local winnerMark = p.isWinner and " |cff00ff00<-- Winner|r" or ""
				local selfMark = p.isSelf and " <YOU>" or ""
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
--- Shows winner, all passed, or current leader in ItemCountText on the primary line.
---@param dropInfo table EncounterLootDropInfo from C_LootHistory
function RLF_LootRollRowMixin:SetRollResults(dropInfo)
	if not dropInfo or not dropInfo.rollInfos then
		return
	end

	self._rollDropInfo = dropInfo

	local waitingCount = 0
	local allPassed = true
	local stateSummary = {}
	for _, ri in ipairs(dropInfo.rollInfos) do
		if ri.state == 4 then
			waitingCount = waitingCount + 1
		end
		if ri.state ~= 5 then
			allPassed = false
		end
		stateSummary[ri.state] = (stateSummary[ri.state] or 0) + 1
	end
	local summaryStr = ""
	for s, c in pairs(stateSummary) do
		summaryStr = summaryStr .. s .. "=" .. c .. " "
	end
	G_RLF:LogDebug(
		("SetRollResults rollID=%s waiting=%d allPassed=%s winner=%s rolled=%s states=%s"):format(
			tostring(self.rollID or "?"),
			waitingCount,
			tostring(allPassed),
			tostring(dropInfo.winner ~= nil),
			tostring(self._rolled),
			summaryStr
		),
		addonName,
		self.moduleName
	)

	-- Secondary text: waiting count with tooltip
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
		-- Re-center primary line now that secondary text is gone
		local sizingDb = G_RLF.DbAccessor:Sizing(self.frameType)
		local spacing = (stylingDb.rowTextSpacing or 0) == 0 and (sizingDb.iconSize / 4) or stylingDb.rowTextSpacing
		self:_LayoutRowLines(
			stylingDb.textAlignment,
			stylingDb.textAlignment ~= G_RLF.TextAlignment.RIGHT,
			sizingDb.padding,
			spacing
		)
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
			_ShowRollText(self, ("|cff00ff00You won! (%s, %d)|r"):format(rollTypeStr, dropInfo.winner.roll))
		else
			local name = classColor and classColor:WrapTextInColorCode(dropInfo.winner.playerName)
				or dropInfo.winner.playerName
			_ShowRollText(self, ("%s won (%s, %d)"):format(name, rollTypeStr, dropInfo.winner.roll))
		end
	elseif allPassed then
		_ShowRollText(self, ("|cffb0b0b0%s|r"):format(LOOT_HISTORY_ALL_PASSED))
	elseif self._rolled and dropInfo.currentLeader then
		local classColor = RAID_CLASS_COLORS[dropInfo.currentLeader.playerClass]
		local name = classColor and classColor:WrapTextInColorCode(dropInfo.currentLeader.playerName)
			or dropInfo.currentLeader.playerName
		_ShowRollText(self, ("%s leads (%d)"):format(name, dropInfo.currentLeader.roll))
	end

	-- Transition: resolved (winner/allPassed) vs unresolved (waiting)
	if dropInfo.winner or allPassed or (waitingCount == 0 and self._rolled) then
		-- Fully resolved results row
		self:OnRollResolved()
	elseif waitingCount > 0 and dropInfo.startTime and dropInfo.duration then
		-- Unresolved: show remaining roll time from dropInfo data
		local elapsed = GetTime() - (dropInfo.startTime / 1000)
		local remaining = math.max(dropInfo.duration - elapsed, 0)
		G_RLF:LogDebug(
			("SetRollResults_unresolved rollID=%s startTime=%s duration=%s elapsed=%.1f remaining=%.1f"):format(
				tostring(self.rollID or "?"),
				tostring(dropInfo.startTime),
				tostring(dropInfo.duration),
				elapsed,
				remaining
			),
			addonName,
			self.moduleName
		)
		if remaining > 0 then
			self.TimerBar:SetMinMaxValues(0, dropInfo.duration)
			self.TimerBar:SetValue(remaining)
			self.TimerBar:Show()
			-- Set up a light OnUpdate to tick the timer down
			self._displayStart = GetTime()
			self._rollTimerFrame = CreateFrame("Frame")
			self._rollTimerFrame:SetScript("OnUpdate", function()
				if not self.TimerBar then
					return
				end
				local e = GetTime() - self._displayStart
				local r = math.max(remaining - e, 0)
				self.TimerBar:SetValue(r)
				if r <= 0 then
					self._rollTimerFrame:SetScript("OnUpdate", nil)
					self._rollTimerFrame = nil
				end
			end)
		end
	end
end

--- Called after the player clicks a roll button.
--- Shows roll selection in ItemCountText with proper primary line reflow.
---@param label string
---@param id number
function RLF_LootRollRowMixin:OnRollCast(label, id)
	self._rolled = true

	for _, btn in ipairs(self._rollButtons or {}) do
		btn:Hide()
	end

	if id == LOOT_ROLL_TYPE_PASS then
		_ShowRollText(self, ("|cffb0b0b0%s|r"):format(PASS))
	else
		_ShowRollText(self, label)
	end
end

---@param element RLF_BaseLootElement
function RLF_LootRollRowMixin:PostBootstrapFromElement(element)
	if element.type ~= G_RLF.FeatureModule.LootRolls then
		return
	end

	self.rollID = element.rollID
	self._rolled = false
	self._isLootRollRow = true

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
		return
	end

	self._rollButtons = {}

	local hasRealRoll = self.rollID ~= nil

	local needBtn = self:_CreateRollButton(
		NEED,
		LOOT_ROLL_TYPE_NEED,
		hasRealRoll and canNeed or false,
		hasRealRoll and reasonNeed or nil
	)
	table.insert(self._rollButtons, needBtn)

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

	if not G_RLF:IsRetail() and canDisenchant then
		local deBtn = self:_CreateRollButton(
			DISENCHANT,
			LOOT_ROLL_TYPE_DISENCHANT,
			hasRealRoll and canDisenchant or false,
			hasRealRoll and reasonDisenchant or nil
		)
		table.insert(self._rollButtons, deBtn)
	end

	local passBtn = self:_CreateRollButton(PASS, LOOT_ROLL_TYPE_PASS, hasRealRoll, nil)
	table.insert(self._rollButtons, passBtn)

	self:_LayoutRollButtons()

	self.showForSeconds = (element.rollDuration or 60) + 1
	self.hasElementFadeOverride = true
	self:StyleExitAnimation()
	self.showForSeconds = (element.rollDuration or 60) + 1

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

	self._rollTimerFrame = CreateFrame("Frame")
	self._rollTimerFrame:SetScript("OnUpdate", function()
		self:_UpdateRollTimer()
	end)

	if element.mockDropInfo then
		self:SetRollResults(element.mockDropInfo)
	end

	if self.ClickableButton then
		local origOnEnter = self.ClickableButton:GetScript("OnEnter")
		local origOnLeave = self.ClickableButton:GetScript("OnLeave")
		self.ClickableButton:SetScript("OnEnter", function()
			if origOnEnter then
				origOnEnter()
			end
			if self._rollDropInfo then
				self:_AppendRollTooltipToItem()
			end
		end)
		if origOnLeave then
			self.ClickableButton:SetScript("OnLeave", origOnLeave)
		end
	end
end

function RLF_LootRollRowMixin:CleanupLootRoll()
	-- Notify module to drop tracking now that row is being released
	if self.rollID ~= nil and self.moduleRef then
		self.moduleRef:_UntrackRoll(self.rollID)
	end

	self.rollID = nil
	self._rolled = false
	self._resolved = nil
	self._displayStart = nil
	self._timerLogNext = nil

	if self._rollButtons then
		for _, btn in ipairs(self._rollButtons) do
			btn:Hide()
			btn:SetScript("OnClick", nil)
			btn:SetScript("OnEnter", nil)
			btn:SetScript("OnLeave", nil)
		end
		self._rollButtons = nil
	end

	self.ItemCountText:SetText(nil)
	self.ItemCountText:Hide()

	self._rollDropInfo = nil
	self.SecondaryText:SetScript("OnEnter", nil)
	self.SecondaryText:SetScript("OnLeave", nil)

	if self._rollTimerFrame then
		self._rollTimerFrame:SetScript("OnUpdate", nil)
		self._rollTimerFrame = nil
	end

	self:ResetTimerBar()
end

G_RLF.RLF_LootRollRowMixin = RLF_LootRollRowMixin
