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

	local icon = self.defaultIcons.MONEY
	local moneyBuildConfig = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
	if not moneyBuildConfig.enableIcon or G_RLF.db.global.misc.hideAllIcons then
		icon = nil
	end

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
			if mc.showMoneyTotal then
				-- Return a single-space placeholder so the row layout applies the
				-- vertical split (primary top / secondary bottom).  The actual wallet
				-- total is rendered by SecondaryCoinDisplay (real Textures).
				return " "
			end
			return ""
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
		---@param existingCopper? number
		coinDataFn = function(existingCopper)
			local total = math.abs((existingCopper or 0) + quantity)
			local gold = math.floor(total / 10000)
			local silver = math.floor((total % 10000) / 100)
			local copper = total % 100
			return gold, silver, copper
		end,
		-- Secondary coin display: current wallet total rendered with real Textures.
		---@param existingCopper? number
		secondaryCoinDataFn = function(existingCopper)
			local mc = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
			if not mc.showMoneyTotal then
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
	-- Template produces only the sign/bracket prefix; the actual coin amounts
	-- are rendered by the row's CoinDisplay frame (real Textures, not |T| markup).
	-- Template order: "{coinString}{sign}" so accountant mode produces "(-…)"
	-- where coinString="(" comes before the sign "-".
	elements[1] = {}
	elements[1].primary = {
		type = "primary",
		template = "{coinString}{sign}",
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
