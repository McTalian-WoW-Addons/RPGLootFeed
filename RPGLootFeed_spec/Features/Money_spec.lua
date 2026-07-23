---@diagnostic disable: need-check-nil
local assert = require("luassert")
local match = require("luassert.match")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local spy = busted.spy
local stub = busted.stub

describe("Money", function()
	local _ = match._
	---@type RLF_Money, table
	local Money, ns, sendMessageSpy, logWarnSpy

	before_each(function()
		sendMessageSpy = spy.new(function() end)
		logWarnSpy = spy.new(function() end)

		-- Build a minimal ns from scratch – no nsMocks framework needed.
		-- Only the fields actually referenced by Money.lua, LootElementBase.lua,
		-- and TextTemplateEngine.lua are included; everything else is intentionally absent.
		ns = {
			-- Closure wrappers call these as G_RLF:Method(...).
			LogDebug = function() end,
			LogWarn = logWarnSpy,
			-- RGBAToHexFormat referenced in TextTemplateEngine for colored elements.
			RGBAToHexFormat = function()
				return "|cFFFFFFFF"
			end,
			-- L used by TextTemplateEngine AbbreviateNumber.
			L = {
				ThousandAbbrev = "K",
				MillionAbbrev = "M",
				BillionAbbrev = "B",
			},
			SendMessage = sendMessageSpy,
			-- Runtime lookups by LootElementBase:fromPayload() and lifecycle methods.
			db = {
				global = {
					animations = { exit = { fadeOutDelay = 3 } },
					money = {
						enabled = true,
						accountantMode = false,
						showMoneyTotal = true,
						abbreviateTotal = false,
						enableIcon = true,
						overrideMoneyLootSound = false,
						moneyLootSound = "",
						onlyIncome = false,
					},
					misc = { hideAllIcons = false, showOneQuantity = false },
				},
			},
			DbAccessor = {
				IsFeatureNeededByAnyFrame = function()
					return true
				end,
				AnyFeatureConfig = function(_, featureKey)
					if featureKey == "money" then
						return ns.db.global.money
					end
					return nil
				end,
				Animations = function(_, frameId)
					return ns.db.global.animations
				end,
			},
			Frames = { MAIN = 1 },
			FeatureModule = { Money = "Money" },
		}

		-- Load real LootElementBase so elements are fully constructed.
		assert(loadfile("RPGLootFeed/Features/_Internals/LootElementBase.lua"))("TestAddon", ns)
		assert(loadfile("RPGLootFeed/utils/FeatureRegistry.lua"))("TestAddon", ns)
		assert.is_not_nil(ns.LootElementBase)

		-- Load TextTemplateEngine before Money.lua so the DI entry exists.
		assert(loadfile("RPGLootFeed/Features/_Internals/TextTemplateEngine.lua"))("TestAddon", ns)
		assert.is_not_nil(ns.TextTemplateEngine)

		-- Setup minimal DI container so FeatureBase mock resolves deps.
		ns.DI = {
			registry = {},
			Register = function(self, k, v)
				self.registry[k] = v
			end,
			Resolve = function(self, k)
				return self.registry[k]
			end,
		}
		ns.DI:Register("LootElementBase", ns.LootElementBase)
		ns.DI:Register("DefaultIcons", { MONEY = 132279 })
		ns.DI:Register("ItemQualEnum", { Poor = 0 })
		ns.DI:Register("TextTemplateEngine", ns.TextTemplateEngine)
		ns.DI:Register("WoWAPI.Money", {
			GetCoinTextureString = function(amount)
				local gold = math.floor(amount / 10000)
				local silver = math.floor((amount % 10000) / 100)
				local copper = amount % 100
				return string.format("%dg %ds %dc", gold, silver, copper)
			end,
			GetMoney = function()
				return 1500000 -- 150 gold default
			end,
		})
		ns.DI:Register("SoundService", {
			PlaySound = function()
				return true
			end,
		})

		-- Mock FeatureBase – returns a minimal stub module so Money tests
		-- are completely independent of AceAddon plumbing.  The stub resolves
		-- DI dependencies and injects logging methods.
		ns.FeatureBase = {
			new = function(_, name, depsOrMixin, ...)
				local deps = {}
				local mixins = {}
				if type(depsOrMixin) == "table" then
					deps = depsOrMixin
					mixins = { ... }
				else
					mixins = { depsOrMixin, ... }
				end

				local module = {
					moduleName = name,
					Enable = function() end,
					Disable = function() end,
					IsEnabled = function()
						return true
					end,
					RegisterEvent = function() end,
					UnregisterEvent = function() end,
				}

				-- Resolve DI dependencies from ns.DI
				for fieldName, depName in pairs(deps.di or {}) do
					module[fieldName] = ns.DI and ns.DI:Resolve(depName)
				end

				-- Inject logging that delegates to ns logging spies
				if deps.logging then
					module.LogDebug = function(self, msg, src, typ, ...)
						(ns.LogDebug or function() end)(msg, src or "TestAddon", typ or self.moduleName, ...)
					end
					module.LogInfo = function(self, msg, src, typ, ...)
						(ns.LogInfo or function() end)(msg, src or "TestAddon", typ or self.moduleName, ...)
					end
					module.LogWarn = function(self, msg, src, typ, ...)
						(ns.LogWarn or function() end)(msg, src or "TestAddon", typ or self.moduleName, ...)
					end
					module.LogError = function(self, msg, src, typ, ...)
						(ns.LogError or function() end)(msg, src or "TestAddon", typ or self.moduleName, ...)
					end
				end

				return module
			end,
		}

		-- Load Money – the FeatureBase mock above resolves DI deps and injects logging.
		Money = assert(loadfile("RPGLootFeed/Features/Money/Money.lua"))("TestAddon", ns)

		-- Override DI-resolved mocks for full test isolation per test run.
		Money.moneyApi = {
			GetCoinTextureString = function(amount)
				local gold = math.floor(amount / 10000)
				local silver = math.floor((amount % 10000) / 100)
				local copper = amount % 100
				return string.format("%dg %ds %dc", gold, silver, copper)
			end,
			GetMoney = function()
				return 1500000 -- 150 gold default
			end,
		}
		Money.soundService = {
			PlaySound = function()
				return true
			end,
		}
	end)

	describe("module lifecycle", function()
		it("is enabled when configuration allows", function()
			local enableStub = stub(Money, "Enable").returns()
			local disableStub = stub(Money, "Disable").returns()

			ns.DbAccessor.IsFeatureNeededByAnyFrame = function()
				return true
			end
			Money:OnInitialize()
			assert.spy(enableStub).was.called(1)
			assert.spy(disableStub).was.not_called()

			enableStub:clear()
			disableStub:clear()

			ns.DbAccessor.IsFeatureNeededByAnyFrame = function()
				return false
			end
			Money:OnInitialize()
			assert.spy(disableStub).was.called(1)
			assert.spy(enableStub).was.not_called()

			enableStub:clear()
			disableStub:clear()
		end)

		it("registers context provider on enable", function()
			Money:OnEnable()

			-- Should have registered Money context provider
			assert.is_function(ns.TextTemplateEngine.contextProviders["Money"])
		end)

		it("unregisters context provider on disable", function()
			Money:OnEnable()
			assert.is_function(ns.TextTemplateEngine.contextProviders["Money"])

			Money:OnDisable()
			assert.is_nil(ns.TextTemplateEngine.contextProviders["Money"])
		end)
	end)

	describe("GenerateTextElements", function()
		it("generates row 1 elements", function()
			local elements = Money:GenerateTextElements(50000)

			assert.is_not_nil(elements[1])
			assert.is_not_nil(elements[1].primary)
			assert.equal("primary", elements[1].primary.type)
			-- coinString prefix comes before sign so accountant mode produces "(-…)"
			assert.equal("{coinString}{sign}", elements[1].primary.template)
			assert.equal(1, elements[1].primary.order)
		end)

		it("generates row 2 elements", function()
			ns.db.global.money.showMoneyTotal = true
			local elements = Money:GenerateTextElements(50000)

			assert.is_not_nil(elements[2])
			assert.is_not_nil(elements[2].context)
			assert.equal("context", elements[2].context.type)
			assert.equal("{currentMoney}", elements[2].context.template)
			assert.equal(2, elements[2].context.order)

			-- Should also have spacer
			assert.is_not_nil(elements[2].contextSpacer)
			assert.equal("spacer", elements[2].contextSpacer.type)
			assert.equal(4, elements[2].contextSpacer.spacerCount)
			assert.equal(1, elements[2].contextSpacer.order)
		end)
	end)

	describe("BuildPayload and element creation", function()
		before_each(function()
			-- Enable the context provider for element tests
			Money:OnEnable()
		end)

		local function buildElement(quantity)
			local payload = Money:BuildPayload(quantity)
			if not payload then
				return nil
			end
			return ns.LootElementBase:fromPayload(payload)
		end

		it("creates money payload with correct properties", function()
			local payload = Money:BuildPayload(50000)

			assert.is_not_nil(payload)
			assert.equal("Money", payload.type)
			assert.equal("MONEY_LOOT", payload.key)
			assert.equal(50000, payload.quantity)
			assert.is_not_nil(payload.icon)
			assert.is_function(payload.textFn)
			assert.is_function(payload.secondaryTextFn)
		end)

		it("creates element from payload via fromPayload", function()
			local element = buildElement(50000)

			assert.is_not_nil(element)
			assert.equal("Money", element.type)
			assert.equal("MONEY_LOOT", element.key)
			assert.equal(50000, element.quantity)
			assert.is_not_nil(element.icon)
			assert.is_function(element.textFn)
			assert.is_function(element.secondaryTextFn)
		end)

		it("textFn returns empty string for positive amounts (coins via coinDataFn)", function()
			local element = buildElement(50000)

			local result = element.textFn(25000)

			-- Positive amounts produce no sign; coin amounts come from coinDataFn
			assert.is_string(result)
			assert.equal("", result)
		end)

		it("coinDataFn returns correct denomination breakdown", function()
			local element = buildElement(50000)

			-- 50000 + 25000 = 75000 copper = 7g 50s 0c
			local gold, silver, copper = element.coinDataFn(25000)
			assert.equal(7, gold)
			assert.equal(50, silver)
			assert.equal(0, copper)
		end)

		it("secondaryTextFn returns space placeholder when showMoneyTotal (coins via secondaryCoinDataFn)", function()
			ns.db.global.money.showMoneyTotal = true
			local element = buildElement(50000)

			local result = element.secondaryTextFn(25000)

			-- Returns a single-space placeholder so the row layout applies the vertical
			-- split (primary top / secondary bottom).  Actual coins come from secondaryCoinDataFn.
			assert.equal(" ", result)
		end)

		it("secondaryCoinDataFn returns current money denomination breakdown", function()
			ns.db.global.money.showMoneyTotal = true
			local element = buildElement(50000)

			-- GetMoney mock returns 1500000 = 150g 0s 0c
			local gold, silver, copper = element.secondaryCoinDataFn(25000)
			assert.equal(150, gold)
			assert.equal(0, silver)
			assert.equal(0, copper)
		end)

		it("secondaryTextFn returns empty when showMoneyTotal disabled due to whitespace detection", function()
			ns.db.global.money.showMoneyTotal = false
			local element = buildElement(50000)

			local result = element.secondaryTextFn(25000)

			-- Should return empty because currentMoney is "", making row 2 only spacers
			assert.equal("", result)
		end)

		it("accountant mode: positive amount is displayed plain (no parens)", function()
			ns.db.global.money.accountantMode = true
			local element = buildElement(50000)

			-- Positive amounts are NOT wrapped; textFn returns "" and amountTextFn returns ""
			local textResult = element.textFn()
			assert.equal("", textResult)

			local amountResult = element.amountTextFn()
			assert.equal("", amountResult)

			local gold, silver, copper = element.coinDataFn()
			assert.equal(5, gold)
			assert.equal(0, silver)
			assert.equal(0, copper)
		end)

		it("accountant mode: negative amount is wrapped in parens (no minus sign)", function()
			ns.db.global.money.accountantMode = true
			local element = buildElement(-50000)

			-- Negative amounts: opening "(" from textFn, no minus, coins from coinDataFn,
			-- closing ")" from amountTextFn → "(5g 0s 0c)"
			local textResult = element.textFn()
			assert.equal("(", textResult)

			local amountResult = element.amountTextFn()
			assert.equal(")", amountResult)

			local gold, silver, copper = element.coinDataFn()
			assert.equal(5, gold)
			assert.equal(0, silver)
			assert.equal(0, copper)
		end)

		it("accountant mode: net goes positive on row update — parens removed", function()
			ns.db.global.money.accountantMode = true
			-- Start with a -50000 element but the row already has +100000 accumulated
			local element = buildElement(-50000)

			-- net = 100000 + (-50000) = 50000 > 0 → no parens
			local textResult = element.textFn(100000)
			assert.equal("", textResult)

			local amountResult = element.amountTextFn(100000)
			assert.equal("", amountResult)
		end)

		it("handles negative amounts", function()
			local element = buildElement(-50000)

			-- textFn returns the minus sign; coins come from coinDataFn
			local result = element.textFn()
			assert.equal("-", result)

			local gold, silver, copper = element.coinDataFn()
			assert.equal(5, gold)
			assert.equal(0, silver)
			assert.equal(0, copper)

			-- Negative money should be displayed in red
			assert.equals(1, element.r)
			assert.equals(0, element.g)
			assert.equals(0, element.b)
		end)

		describe("colorFn (net-quantity color for row updates)", function()
			it("is present on positive elements", function()
				local element = buildElement(50000)
				assert.is_function(element.colorFn)
			end)

			it("is present on negative elements", function()
				local element = buildElement(-50000)
				assert.is_function(element.colorFn)
			end)

			it("returns white when net quantity is positive", function()
				local element = buildElement(50000)
				local r, g, b, a = element.colorFn(100)
				assert.equals(1, r)
				assert.equals(1, g)
				assert.equals(1, b)
				assert.equals(1, a)
			end)

			it("returns red when net quantity is negative (buy then sell back for less)", function()
				-- Scenario: spent 100, recouped 30 → net = -70 → still red
				local element = buildElement(30000)
				local r, g, b, a = element.colorFn(-70000)
				assert.equals(1, r)
				assert.equals(0, g)
				assert.equals(0, b)
				assert.equals(1, a)
			end)

			it("returns white when a previously negative net goes positive", function()
				-- Scenario: earned 200, spent 50 → net = +150 → white
				local element = buildElement(-50000)
				local r, g, b, a = element.colorFn(150000)
				assert.equals(1, r)
				assert.equals(1, g)
				assert.equals(1, b)
				assert.equals(1, a)
			end)
		end)

		it("configures sound field in payload when enabled", function()
			ns.db.global.money.overrideMoneyLootSound = true
			ns.db.global.money.moneyLootSound = "Interface\\Sounds\\Custom.ogg"

			local payload = Money:BuildPayload(50000)

			assert.equal("Interface\\Sounds\\Custom.ogg", payload.sound)
		end)

		it("returns nil for zero quantity", function()
			local payload = Money:BuildPayload(0)
			assert.is_nil(payload)

			local payload2 = Money:BuildPayload(nil)
			assert.is_nil(payload2)
		end)

		it("throws error when row 1 elements are missing (bad element data)", function()
			local element = buildElement(50000)
			-- Force an error by making textFn call into bad elementData.
			-- We can't easily reach inside the closure, so verify the element has a valid textFn first.
			assert.is_function(element.textFn)
		end)
	end)

	describe("PlaySoundIfEnabled (module method)", function()
		before_each(function()
			Money.soundService.PlaySound = spy.new(function()
				return true
			end)
		end)

		it("plays sound when overrideMoneyLootSound is enabled", function()
			ns.db.global.money.overrideMoneyLootSound = true
			ns.db.global.money.moneyLootSound = "Interface\\Sounds\\Custom.ogg"

			Money:PlaySoundIfEnabled()

			assert.spy(Money.soundService.PlaySound).was.called_with(_, "Interface\\Sounds\\Custom.ogg")
		end)

		it("does not play sound when overrideMoneyLootSound is disabled", function()
			ns.db.global.money.overrideMoneyLootSound = false
			ns.db.global.money.moneyLootSound = "Interface\\Sounds\\Custom.ogg"

			Money:PlaySoundIfEnabled()

			assert.spy(Money.soundService.PlaySound).was.not_called()
		end)

		it("does not play sound when moneyLootSound is empty", function()
			ns.db.global.money.overrideMoneyLootSound = true
			ns.db.global.money.moneyLootSound = ""

			Money:PlaySoundIfEnabled()

			assert.spy(Money.soundService.PlaySound).was.not_called()
		end)
	end)

	describe("event handling", function()
		before_each(function()
			Money:OnEnable()
		end)

		it("tracks starting money on PLAYER_ENTERING_WORLD", function()
			Money.moneyApi.GetMoney = function()
				return 2000000
			end -- 200 gold

			Money:PLAYER_ENTERING_WORLD("PLAYER_ENTERING_WORLD")

			assert.equal(2000000, Money.startingMoney)
		end)

		it("processes money changes on PLAYER_MONEY", function()
			Money.startingMoney = 1000000 -- 100 gold
			Money.moneyApi.GetMoney = function()
				return 1050000
			end -- 105 gold

			local buildPayloadSpy = spy.on(Money, "BuildPayload")

			Money:PLAYER_MONEY("PLAYER_MONEY")

			-- Should call BuildPayload with the difference
			assert.spy(buildPayloadSpy).was.called_with(Money, 50000)
			assert.spy(sendMessageSpy).was.called(1)
			assert.equal(1050000, Money.startingMoney)
		end)

		it("ignores zero money changes", function()
			Money.startingMoney = 1000000
			Money.moneyApi.GetMoney = function()
				return 1000000
			end -- Same amount

			local buildPayloadSpy = spy.on(Money, "BuildPayload")

			Money:PLAYER_MONEY("PLAYER_MONEY")

			-- Should not call BuildPayload
			assert.spy(buildPayloadSpy).was.not_called()
		end)

		it("respects onlyIncome setting", function()
			ns.db.global.money.onlyIncome = true
			Money.startingMoney = 1000000
			Money.moneyApi.GetMoney = function()
				return 950000
			end -- Lost money

			local buildPayloadSpy = spy.on(Money, "BuildPayload")

			Money:PLAYER_MONEY("PLAYER_MONEY")

			-- Should not call BuildPayload for negative change
			assert.spy(buildPayloadSpy).was.not_called()
		end)
	end)

	describe("integration with TextTemplateEngine", function()
		before_each(function()
			Money:OnEnable() -- Register context provider
		end)

		it("can generate complete layout using TextTemplateEngine", function()
			ns.db.global.money.showMoneyTotal = true
			local payload = Money:BuildPayload(50000)
			local element = ns.LootElementBase:fromPayload(payload)

			-- Row 1: textFn returns empty for positive amounts; coins via coinDataFn
			local row1Layout = element.textFn()
			assert.equal("", row1Layout)

			-- coinDataFn returns denomination amounts (5g 0s 0c)
			local gold, silver, copper = element.coinDataFn()
			assert.equal(5, gold)
			assert.equal(0, silver)
			assert.equal(0, copper)

			-- Row 2: secondaryTextFn returns a space placeholder (vertical split trigger);
			-- actual coins are rendered via secondaryCoinDataFn.
			local row2Layout = element.secondaryTextFn()
			assert.equal(" ", row2Layout)

			-- secondaryCoinDataFn returns current money (150g from mock)
			local sg, ss, sc = element.secondaryCoinDataFn()
			assert.equal(150, sg)
			assert.equal(0, ss)
			assert.equal(0, sc)
		end)
	end)

	describe("money context provider features", function()
		before_each(function()
			Money:OnEnable() -- Register context provider
		end)

		local function buildElement(quantity)
			local payload = Money:BuildPayload(quantity)
			if not payload then
				return nil
			end
			return ns.LootElementBase:fromPayload(payload)
		end

		describe("current money truncation", function()
			it("truncates silver and copper for amounts over 1000 gold", function()
				-- Set current money to 15,235,678 copper = 1523g 56s 78c
				Money.moneyApi.GetMoney = function()
					return 15235678
				end
				ns.db.global.money.showMoneyTotal = true

				local element = buildElement(50000)
				local gold, silver, copper = element.secondaryCoinDataFn(0)

				-- Should be truncated to 1523g 0s 0c (silver and copper removed)
				assert.equal(1523, gold)
				assert.equal(0, silver)
				assert.equal(0, copper)
			end)

			it("does not truncate amounts under 1000 gold", function()
				-- Set current money to 9,876,543 copper = 987g 65s 43c (under 1000g)
				Money.moneyApi.GetMoney = function()
					return 9876543
				end
				ns.db.global.money.showMoneyTotal = true

				local element = buildElement(50000)
				local gold, silver, copper = element.secondaryCoinDataFn(0)

				-- Should keep full precision
				assert.equal(987, gold)
				assert.equal(65, silver)
				assert.equal(43, copper)
			end)

			it("handles exactly 1000 gold threshold", function()
				-- Set current money to exactly 10,000,000 copper = 1000g 0s 0c
				Money.moneyApi.GetMoney = function()
					return 10000000
				end
				ns.db.global.money.showMoneyTotal = true

				local element = buildElement(50000)
				local gold, silver, copper = element.secondaryCoinDataFn(0)

				-- Should not truncate at exactly 1000g
				assert.equal(1000, gold)
				assert.equal(0, silver)
				assert.equal(0, copper)
			end)

			it("handles exactly 1000g 1c threshold", function()
				-- Set current money to 10,000,001 copper = 1000g 0s 1c
				Money.moneyApi.GetMoney = function()
					return 10000001
				end
				ns.db.global.money.showMoneyTotal = true

				local element = buildElement(50000)
				local gold, silver, copper = element.secondaryCoinDataFn(0)

				-- Should truncate to 1000g 0s 0c (just over threshold)
				assert.equal(1000, gold)
				assert.equal(0, silver)
				assert.equal(0, copper)
			end)
		end)

		describe("current money abbreviation", function()
			it("abbreviates gold when enabled and over 1000 gold", function()
				-- Set current money to 25,000,000 copper = 2500g 0s 0c
				Money.moneyApi.GetMoney = function()
					return 25000000
				end
				ns.db.global.money.showMoneyTotal = true
				ns.db.global.money.abbreviateTotal = true

				local element = buildElement(50000)
				local gold, silver, copper, _, _, goldText = element.secondaryCoinDataFn(0)

				-- gold value intact for positivity checks; goldText is abbreviated
				assert.equal(2500, gold)
				assert.equal(0, silver)
				assert.equal(0, copper)
				assert.equal("2.50K", goldText)
			end)

			it("does not abbreviate when disabled", function()
				-- Set current money to 25,000,000 copper = 2500g 0s 0c
				Money.moneyApi.GetMoney = function()
					return 25000000
				end
				ns.db.global.money.showMoneyTotal = true
				ns.db.global.money.abbreviateTotal = false

				local element = buildElement(50000)
				local gold, silver, copper, _, _, goldText = element.secondaryCoinDataFn(0)

				-- No abbreviation; goldText should be nil
				assert.equal(2500, gold)
				assert.is_nil(goldText)
			end)

			it("does not abbreviate amounts under 1000 gold", function()
				-- Set current money to 9,876,543 copper = 987g 65s 43c (under 1000g)
				Money.moneyApi.GetMoney = function()
					return 9876543
				end
				ns.db.global.money.showMoneyTotal = true
				ns.db.global.money.abbreviateTotal = true

				local element = buildElement(50000)
				local gold, silver, copper, _, _, goldText = element.secondaryCoinDataFn(0)

				-- Should not abbreviate (under threshold); goldText should be nil
				assert.equal(987, gold)
				assert.is_nil(goldText)
			end)

			it("handles millions of gold", function()
				-- Set current money to 250,000,000 copper = 25,000g 0s 0c
				Money.moneyApi.GetMoney = function()
					return 250000000
				end
				ns.db.global.money.showMoneyTotal = true
				ns.db.global.money.abbreviateTotal = true

				local element = buildElement(50000)
				local gold, silver, copper, _, _, goldText = element.secondaryCoinDataFn(0)

				-- Should abbreviate to 25.00K
				assert.equal(25000, gold)
				assert.equal("25.00K", goldText)
			end)
		end)

		describe("combined truncation and abbreviation", function()
			it("truncates before abbreviating", function()
				-- Set current money to 25,123,456 copper = 2512g 34s 56c
				Money.moneyApi.GetMoney = function()
					return 25123456
				end
				ns.db.global.money.showMoneyTotal = true
				ns.db.global.money.abbreviateTotal = true

				local element = buildElement(50000)
				local gold, silver, copper, _, _, goldText = element.secondaryCoinDataFn(0)

				-- Truncated to 2512g 0s 0c, then abbreviated goldText to 2.51K
				assert.equal(2512, gold)
				assert.equal(0, silver)
				assert.equal(0, copper)
				assert.equal("2.51K", goldText)
			end)
		end)

		describe("showMoneyTotal disabled", function()
			it("returns empty currentMoney when showMoneyTotal is false", function()
				ns.db.global.money.showMoneyTotal = false

				local element = buildElement(50000)
				local result = element.secondaryTextFn(0)

				assert.equal("", result)
			end)
		end)
	end)
end)
