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

	-- Tooltip — matches Blizzard's LootRollButtonTemplate OnEnter/OnLeave
	btn:SetScript("OnEnter", function()
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
		GameTooltip:Hide()
	end)

	-- Click — only fires when enabled (Blizzard disables non-eligible buttons)
	btn:SetScript("OnClick", function()
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

--- Position the roll result text in place of the buttons.
function RLF_LootRollRowMixin:_LayoutRollResultText()
	if not self._rollResultText then
		return
	end

	local primaryTextEnd = self.PrimaryText:GetRight() or 60
	local rowWidth = self:GetWidth() or 256
	local maxX = rowWidth - PADDING_RIGHT

	self._rollResultText:ClearAllPoints()
	self._rollResultText:SetPoint("LEFT", self, "LEFT", primaryTextEnd + 8, 0)
	self._rollResultText:SetPoint("RIGHT", self, "RIGHT", -(PADDING_RIGHT + 4), 0)
	self._rollResultText:SetJustifyH("RIGHT")
	self._rollResultText:Show()
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
		-- Update existing result text with roll value
		if self._rollResultText then
			local color = isWinning and GREEN_FONT_COLOR or RED_FONT_COLOR
			self._rollResultText:SetFormattedText(
				"%sNeed %s%d|r",
				color:GetHex() or "",
				color.r < 0.5 and "" or "",
				roll
			)
		end
	end
end

--- Handle LOOT_ITEM_ROLL_WON — update row to show win state.
---@param rollType number
---@param roll number
function RLF_LootRollRowMixin:OnRollWon(rollType, roll)
	if not self._rollResultText then
		self._rollResultText = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	end

	local rollTypeNames = {
		[1] = NEED,
		[2] = GREED,
		[3] = DISENCHANT,
		[4] = TRANSMOGRIFICATION,
	}
	local typeName = rollTypeNames[rollType] or ""
	self._rollResultText:SetFormattedText("|cff00ff00%s Won! (%d)|r", typeName, roll)
	self._rollResultText:Show()
	self:_LayoutRollResultText()
end

--- Called after the player clicks a roll button.
---@param label string
---@param id number
function RLF_LootRollRowMixin:OnRollCast(label, id)
	self._rolled = true

	-- Hide all roll buttons
	for _, btn in ipairs(self._rollButtons or {}) do
		btn:Hide()
	end

	-- Show result text
	if not self._rollResultText then
		self._rollResultText = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	end

	if id == LOOT_ROLL_TYPE_PASS then
		self._rollResultText:SetText(PASS)
	else
		self._rollResultText:SetText(label)
	end
	self._rollResultText:Show()
	self:_LayoutRollResultText()
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
	if element.canNeed ~= nil then
		canNeed = element.canNeed
		canGreed = element.canGreed
		canTransmog = element.canTransmog
		reasonNeed = element.reasonNeed
		reasonGreed = element.reasonGreed
	elseif element.rollID then
		local _, _, _, _, _, cn, cg, _, rn, rg, _, _, ct = GetLootRollItemInfo(element.rollID)
		canNeed, canGreed, canTransmog = cn, cg, ct
		reasonNeed, reasonGreed = rn, rg
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

	-- Destroy result text
	if self._rollResultText then
		self._rollResultText:Hide()
		self._rollResultText:SetText(nil)
	end

	-- Stop timer frame
	if self._rollTimerFrame then
		self._rollTimerFrame:SetScript("OnUpdate", nil)
		self._rollTimerFrame = nil
	end

	-- Reset timer bar to default hidden state
	self:ResetTimerBar()
end

G_RLF.RLF_LootRollRowMixin = RLF_LootRollRowMixin
