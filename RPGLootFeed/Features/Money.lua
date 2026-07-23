---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_Money: RLF_Module, AceEvent-3.0
local Money = G_RLF.FeatureBase:new("Money", {
	di = {
		lootElementBase = "LootElementBase",
		defaultIcons = "DefaultIcons",
		itemQualEnum = "ItemQualEnum",
		textTemplateEngine = "TextTemplateEngine",
		moneyApi = "WoWAPI.Money",
		soundService = "SoundService",
	},
	logging = true,
}, "AceEvent-3.0")

--- Plays the configured money loot sound if the override is enabled.
function Money:PlaySoundIfEnabled()
	local moneyConfig = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
	if moneyConfig.overrideMoneyLootSound and (moneyConfig.moneyLootSound or "") ~= "" then
		local didPlay = self.soundService:PlaySound(moneyConfig.moneyLootSound)
		if didPlay then
			self:LogDebug("Sound queued to play " .. moneyConfig.moneyLootSound, addonName, Money.moduleName or "Money")
		end
	end
end

--- Decomposes a non-negative copper amount into gold/silver/copper parts.
--- Shared by coinDataFn (coin texture display) and the icon denomination
--- picker in BuildPayload so the icon and the coin display can never disagree.
---@param totalCopper number Non-negative copper amount
---@return number gold, number silver, number copper
local function DecomposeCopper(totalCopper)
	local gold = math.floor(totalCopper / 10000)
	local silver = math.floor((totalCopper % 10000) / 100)
	local copper = totalCopper % 100
	return gold, silver, copper
end

--- Format a copper amount as plain text (e.g. "1g 2s 3c") instead of the
--- real-Texture coin display, mirroring ItemLoot's plainTextPrices formatter.
--- No |T|/|A| markup -> no animation jank.
---@param totalCopper number Non-negative copper amount
---@param colored boolean? Wrap each denomination in its coin color
---@param abbreviate boolean? Collapse to an abbreviated gold-only string at >=1000g
---@return string
local function PlainMoneyString(totalCopper, colored, abbreviate)
	local gold, silver, copper = DecomposeCopper(totalCopper)

	local function colorWrap(hex, text)
		if colored then
			return "|cff" .. hex .. text .. "|r"
		end
		return text
	end

	if abbreviate and gold >= 1000 then
		local goldText = Money.textTemplateEngine:AbbreviateNumber(gold) .. Money.moneyApi.GetGoldAmountSymbol()
		return colorWrap("ffd700", goldText)
	end

	local parts = {}
	if gold > 0 then
		table.insert(parts, colorWrap("ffd700", gold .. Money.moneyApi.GetGoldAmountSymbol()))
	end
	if silver > 0 or gold > 0 then
		table.insert(parts, colorWrap("c7c7cf", silver .. Money.moneyApi.GetSilverAmountSymbol()))
	end
	table.insert(parts, colorWrap("eda55f", copper .. Money.moneyApi.GetCopperAmountSymbol()))
	return table.concat(parts, " ")
end

-- Context provider function to be registered when module is enabled.
-- Defined after Money so the inner closure can reference Money.moneyApi.
local function createMoneyContextProvider()
	return function(context, data)
		local moneyConfig = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}

		-- Coin icons are real Textures (via coinDataFn on the payload), not |T| markup.
		-- In accountant mode, ONLY negative amounts are wrapped: "(coins)" replaces
		-- "-coins".  Positive amounts are displayed normally (no parens, no sign).
		if moneyConfig.accountantMode and context.sign == "-" then
			context.coinString = "("
			context.sign = "" -- parens convey negativity; suppress the minus sign
		else
			context.coinString = ""
		end

		-- plainTextMoney: coinDataFn suppresses itself (see BuildPayload), so the
		-- looted amount is rendered here instead, inline with the sign/parens.
		if moneyConfig.plainTextMoney then
			context.plainAmount = PlainMoneyString(context.absTotal, moneyConfig.plainTextMoneyColored, false)
		else
			context.plainAmount = ""
		end

		-- Secondary text: only retain the spacer indent when the money total is shown.
		-- The actual coin amounts are rendered via secondaryCoinDataFn.
		if moneyConfig.showMoneyTotal then
			context.currentMoney = "" -- coins come from SecondaryCoinDisplay
		else
			context.currentMoney = ""
		end
	end
end

--- Build a uniform payload for a money loot event.
--- Returns nil when the amount is zero or nil (nothing to display).
---@param quantity number The copper amount (positive = income, negative = loss)
---@return RLF_ElementPayload?
function Money:BuildPayload(quantity)
	if not quantity or quantity == 0 then
		return nil
	end

	-- Icon tracks the highest non-zero denomination of the running accumulated
	-- total (gold > silver > copper) instead of always showing gold coins, so
	-- a row that only ever loots silver/copper doesn't read as "gold looted".
	-- Mirrors coinDataFn's convention below: called with the OLD accumulated
	-- amount, and computes the new total itself as (existingCopper or 0) +
	-- quantity, rather than colorFn's convention of receiving the net amount
	-- pre-computed by the caller.
	---@param existingCopper? number
	local function iconFn(existingCopper)
		local moneyConfig = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
		if not moneyConfig.enableIcon or G_RLF.db.global.misc.hideAllIcons then
			return nil
		end
		local total = math.abs((existingCopper or 0) + quantity)
		local gold, silver = DecomposeCopper(total)
		if gold > 0 then
			return self.defaultIcons.MONEY
		elseif silver > 0 then
			return self.defaultIcons.MONEY_SILVER
		else
			return self.defaultIcons.MONEY_COPPER
		end
	end

	-- Resolve the initial icon now, with existingCopper = 0 (mirroring how the
	-- row's create path calls coinDataFn(0) -- see LootDisplayRow.lua), so a
	-- row that is created and never updated still gets the correct
	-- denomination icon instead of only being fixed up on the next accumulation.
	local icon = iconFn(0)
	local moneyBuildConfig = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}

	local r, g, b = 1, 1, 1
	if quantity < 0 then
		r, g, b = 1, 0, 0
	end

	local textElements = Money:GenerateTextElements(quantity)

	---@type RLF_LootElementData
	local elementData = {
		key = "MONEY_LOOT",
		type = "Money",
		textElements = textElements,
		quantity = quantity,
		icon = icon,
		quality = self.itemQualEnum.Poor,
	}

	---@type RLF_ElementPayload
	local payload = {
		key = "MONEY_LOOT",
		type = G_RLF.FeatureModule.Money,
		icon = icon,
		iconFn = iconFn,
		quality = self.itemQualEnum.Poor,
		quantity = quantity,
		r = r,
		g = g,
		b = b,
		-- Recompute color based on net quantity when an existing row is updated.
		-- The net is (existing accumulated amount) + (this element's quantity).
		colorFn = function(netQuantity)
			if netQuantity < 0 then
				return 1, 0, 0, 1
			else
				return 1, 1, 1, 1
			end
		end,
		textFn = function(existingCopper)
			return self.textTemplateEngine:ProcessRowElements(1, elementData, existingCopper)
		end,
		secondaryTextFn = function(existingCopper)
			local mc = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
			if not mc.showMoneyTotal then
				return ""
			end
			if mc.plainTextMoney then
				local currentMoney = Money.moneyApi.GetMoney()
				-- Truncation: amounts over 1000g strip silver and copper
				if currentMoney > 10000000 then
					currentMoney = math.floor(currentMoney / 10000) * 10000
				end
				return PlainMoneyString(currentMoney, mc.plainTextMoneyColored, mc.abbreviateTotal)
			end
			-- Return a single-space placeholder so the row layout applies the
			-- vertical split (primary top / secondary bottom).  The actual wallet
			-- total is rendered by SecondaryCoinDisplay (real Textures).
			return " "
		end,
		-- Accountant-mode closing bracket: only append ")" when the net amount is
		-- negative (parens wrap negative amounts; positive amounts are shown plain).
		amountTextFn = function(existingCopper)
			local mc = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
			if mc.accountantMode then
				local net = (existingCopper or 0) + quantity
				if net < 0 then
					return ")"
				end
			end
			return ""
		end,
		-- Primary coin display: real Texture denomination frames instead of |T| markup.
		-- Suppressed when plainTextMoney is on -- the context provider renders the
		-- amount as plain text inline instead (see context.plainAmount above).
		---@param existingCopper? number
		coinDataFn = function(existingCopper)
			local mc = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
			if mc.plainTextMoney then
				return nil
			end
			local total = math.abs((existingCopper or 0) + quantity)
			return DecomposeCopper(total)
		end,
		-- Secondary coin display: current wallet total rendered with real Textures.
		---@param existingCopper? number
		secondaryCoinDataFn = function(existingCopper)
			local mc = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
			if not mc.showMoneyTotal or mc.plainTextMoney then
				return nil
			end
			local currentMoney = Money.moneyApi.GetMoney()
			-- Truncation: amounts over 1000g strip silver and copper
			if currentMoney > 10000000 then
				currentMoney = math.floor(currentMoney / 10000) * 10000
			end
			local gold = math.floor(currentMoney / 10000)
			local silver = math.floor((currentMoney % 10000) / 100)
			local copper = currentMoney % 100
			-- Abbreviation: return a formatted goldText string when enabled and >= 1000g
			local goldText = nil
			if mc.abbreviateTotal and gold >= 1000 then
				goldText = self.textTemplateEngine:AbbreviateNumber(gold)
			end
			return gold, silver, copper, nil, nil, goldText
		end,
		moduleRef = Money,
	}

	if moneyBuildConfig.overrideMoneyLootSound and (moneyBuildConfig.moneyLootSound or "") ~= "" then
		payload.sound = moneyBuildConfig.moneyLootSound
	end

	return payload
end

--- Generate text elements for Money type using the new data-driven approach
---@param quantity number The money amount in copper
---@return table<number, table<string, RLF_TextElement>> textElements Row-indexed elements: [row][elementKey] = element
function Money:GenerateTextElements(quantity)
	local elements = {}

	-- Row 1: Primary money display
	-- Template produces the sign/bracket prefix, plus the plain-text amount when
	-- plainTextMoney is enabled ({plainAmount} is "" otherwise -- see the context
	-- provider). Normally the actual coin amounts are rendered by the row's
	-- CoinDisplay frame (real Textures, not |T| markup).
	-- Template order: "{coinString}{sign}{plainAmount}" so accountant mode produces
	-- "(-…)" where coinString="(" comes before the sign "-".
	elements[1] = {}
	elements[1].primary = {
		type = "primary",
		template = "{coinString}{sign}{plainAmount}",
		order = 1,
		color = nil,
	}

	-- Row 2: Context text element (money total) - only if enabled
	elements[2] = {}
	elements[2].contextSpacer = {
		type = "spacer",
		spacerCount = 4, -- "    " spacing
		order = 1,
	}

	elements[2].context = {
		type = "context",
		template = "{currentMoney}",
		order = 2,
		color = nil,
	}

	return elements
end

function Money:OnInitialize()
	self.startingMoney = 0
	if G_RLF.DbAccessor:IsFeatureNeededByAnyFrame("money") then
		self:Enable()
	else
		self:Disable()
	end
end

function Money:OnEnable()
	-- Register our context provider with the TextTemplateEngine
	self.textTemplateEngine:RegisterContextProvider("Money", createMoneyContextProvider())

	self:RegisterEvent("PLAYER_MONEY")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.startingMoney = self.moneyApi.GetMoney()
end

function Money:OnDisable()
	-- Unregister our context provider
	self.textTemplateEngine.contextProviders["Money"] = nil

	self:UnregisterEvent("PLAYER_MONEY")
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

function Money:PLAYER_ENTERING_WORLD(eventName)
	self.startingMoney = self.moneyApi.GetMoney()
end

function Money:PLAYER_MONEY(eventName)
	local newMoney = self.moneyApi.GetMoney()
	local amountInCopper = newMoney - self.startingMoney
	if amountInCopper == 0 then
		return
	end
	self.startingMoney = newMoney
	local moneyFilterConfig = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
	if moneyFilterConfig.onlyIncome and amountInCopper < 0 then
		return
	end

	local payload = Money:BuildPayload(amountInCopper)
	if payload then
		self.lootElementBase:fromPayload(payload):Show()
		Money:PlaySoundIfEnabled()
	end
end

return Money
