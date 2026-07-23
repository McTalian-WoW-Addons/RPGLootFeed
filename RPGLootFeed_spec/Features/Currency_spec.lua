---@diagnostic disable: need-check-nil
local assert = require("luassert")
local match = require("luassert.match")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local spy = busted.spy
local stub = busted.stub

describe("Currency Module", function()
	local _ = match._
	---@type RLF_Currency, table
	local CurrencyModule, ns, sendMessageSpy

	-- Build a fresh default adapter each before_each; tests override individual
	-- methods as needed.  Defaults represent a Retail BFA+ Retail client.
	local function makeDefaultAdapter()
		return {
			GetExpansionLevel = function()
				return 10 -- above BFA (8) → CURRENCY_DISPLAY_UPDATE path
			end,
			IssecretValue = function()
				return false
			end,
			HasGetCurrencyLinkAPI = function()
				return true
			end,
			GetCurrencyInfo = function(id)
				return {
					currencyID = id or 123,
					description = "An awesome currency",
					iconFileID = 123456,
					quantity = 5,
					quality = 2,
					maxQuantity = 0,
					totalEarned = 0,
				}
			end,
			GetBasicCurrencyInfo = function(id, amount)
				return { displayAmount = amount or 1 }
			end,
			GetCurrencyLinkFromLib = function(id)
				return "|c12345678|Hcurrency:" .. (id or 123) .. "|h[Test Currency]|h|r"
			end,
			GetCurrencyLinkFromGlobal = function(id, qty)
				return "|c12345678|Hcurrency:" .. (id or 123) .. "|h[Test Currency]|h|r"
			end,
			GetAccountWideHonorCurrencyID = function()
				return 1901
			end,
			GetPerksProgramCurrencyID = function()
				return 3008
			end,
			GetUnitHonorLevel = function()
				return 5
			end,
			GetUnitHonorMax = function()
				return 500
			end,
			GetUnitHonor = function()
				return 100
			end,
			GetCurrencyGainedMultiplePattern = function()
				return "You receive currency: %s x%d."
			end,
			GetCurrencyGainedMultipleBonusPattern = function()
				return "You receive currency: %s x%d. (Bonus Objective)"
			end,
			GenericTraitToggle = function() end,
		}
	end

	before_each(function()
		sendMessageSpy = spy.new(function() end)

		-- Build a minimal ns from scratch – no nsMocks framework needed.
		-- Only the fields actually referenced by Currency.lua and LootElementBase.lua
		-- are included.  G_RLF.db and G_RLF.hiddenCurrencies are runtime lookups so
		-- per-test overrides (ns.hiddenCurrencies = ...) work correctly.
		ns = {
			FeatureModule = { Currency = "Currency" },
			Expansion = { TBC = 2, WOTLK = 3, BFA = 8 },
			LogDebug = spy.new(function() end),
			LogInfo = spy.new(function() end),
			LogWarn = spy.new(function() end),
			RGBAToHexFormat = function()
				return "|cFFFFFFFF"
			end,
			ExtractCurrencyID = function(_, msg)
				local id = msg:match("|Hcurrency:(%d+):")
				return id and tonumber(id) or nil
			end,
			SendMessage = sendMessageSpy,
			-- Runtime lookup; tests override per-test as needed.
			hiddenCurrencies = {},
			L = { ClickToOpenCloakTree = "Open Cloak Tree" },
			db = {
				global = {
					animations = { exit = { fadeOutDelay = 3 } },
					currency = {
						enabled = true,
						enableIcon = true,
						lowerThreshold = 0.25,
						upperThreshold = 0.75,
						lowestColor = { 1, 0, 0, 1 },
						midColor = { 1, 1, 0, 1 },
						upperColor = { 0, 1, 0, 1 },
					},
					misc = { hideAllIcons = false, showOneQuantity = false },
				},
			},
			DbAccessor = {
				IsFeatureNeededByAnyFrame = function()
					return true
				end,
				AnyFeatureConfig = function(_, featureKey)
					if featureKey == "currency" then
						return ns.db.global.currency
					end
					return nil
				end,
				Animations = function(_, frameId)
					return ns.db.global.animations
				end,
			},
			Frames = { MAIN = 1 },
		}

		-- DI container for dependency injection
		ns.DI = {
			_registry = {},
			Register = function(self, name, instance)
				self._registry[name] = instance
			end,
			Resolve = function(self, name)
				return self._registry[name]
			end,
		}

		-- Load real LootElementBase so elements are fully constructed.
		assert(loadfile("RPGLootFeed/Features/_Internals/LootElementBase.lua"))("TestAddon", ns)
		assert.is_not_nil(ns.LootElementBase)

		-- Load TextTemplateEngine so DI can resolve it for Currency.
		assert(loadfile("RPGLootFeed/Features/_Internals/TextTemplateEngine.lua"))("TestAddon", ns)
		assert.is_not_nil(ns.TextTemplateEngine)

		-- Register DI dependencies before loading Currency
		ns.DI:Register("LootElementBase", ns.LootElementBase)
		ns.DI:Register("TextTemplateEngine", ns.TextTemplateEngine)
		ns.DI:Register("WoWAPI.Currency", makeDefaultAdapter())
		ns.DI:Register("IsRetail", function()
			return false
		end)

		-- FeatureBase stub – supports DI deps table and logging injection.
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

				-- Resolve DI dependencies
				for fieldName, depName in pairs(deps.di or {}) do
					module[fieldName] = ns.DI:Resolve(depName)
				end

				-- Inject logging methods
				if deps.logging then
					module.LogDebug = function(self, message, source, type_, id, content, amount, isNew)
						ns.LogDebug(
							message,
							source or "TestAddon",
							type_ or self.moduleName,
							id,
							content,
							amount,
							isNew
						)
					end
					module.LogInfo = function(self, message, source, type_, id, content, amount, isNew)
						ns.LogInfo(message, source or "TestAddon", type_ or self.moduleName, id, content, amount, isNew)
					end
					module.LogWarn = function(self, message, source, type_, id, content, amount, isNew)
						ns.LogWarn(message, source or "TestAddon", type_ or self.moduleName, id, content, amount, isNew)
					end
					module.LogError = function(self, message, source, type_, id, content, amount, isNew)
						-- no-op for tests
					end
				end

				return module
			end,
		}

		-- Load Currency.lua – all external dependency locals captured at this point.
		CurrencyModule = assert(loadfile("RPGLootFeed/Features/Currency/Currency.lua"))("TestAddon", ns)
	end)

	-- ── Lifecycle ──────────────────────────────────────────────────────────────

	describe("Lifecycle event handlers", function()
		it("OnInitialize enables when any frame needs currency and expansion >= WOTLK", function()
			ns.DbAccessor.IsFeatureNeededByAnyFrame = function()
				return true
			end
			CurrencyModule.currencyApi.GetExpansionLevel = function()
				return 3 -- WOTLK
			end
			local spyEnable = spy.on(CurrencyModule, "Enable")
			local spyDisable = spy.on(CurrencyModule, "Disable")
			CurrencyModule:OnInitialize()
			assert.spy(spyEnable).was.called(1)
			assert.spy(spyDisable).was_not.called()
		end)

		it("OnInitialize disables when no frame needs currency", function()
			ns.DbAccessor.IsFeatureNeededByAnyFrame = function()
				return false
			end
			CurrencyModule.currencyApi.GetExpansionLevel = function()
				return 3
			end
			local spyEnable = spy.on(CurrencyModule, "Enable")
			local spyDisable = spy.on(CurrencyModule, "Disable")
			CurrencyModule:OnInitialize()
			assert.spy(spyEnable).was_not.called()
			assert.spy(spyDisable).was.called(1)
		end)

		it("OnInitialize disables when expansion < WOTLK", function()
			ns.DbAccessor.IsFeatureNeededByAnyFrame = function()
				return true
			end
			CurrencyModule.currencyApi.GetExpansionLevel = function()
				return 2 -- TBC
			end
			local spyEnable = spy.on(CurrencyModule, "Enable")
			local spyDisable = spy.on(CurrencyModule, "Disable")
			CurrencyModule:OnInitialize()
			assert.spy(spyEnable).was_not.called()
			assert.spy(spyDisable).was.called(1)
		end)

		it("OnEnable registers CURRENCY_DISPLAY_UPDATE + PERKS_PROGRAM for Retail >= BFA", function()
			CurrencyModule.isRetail = function()
				return true
			end
			CurrencyModule.currencyApi.GetExpansionLevel = function()
				return 8 -- BFA
			end
			local spyReg = spy.on(CurrencyModule, "RegisterEvent")
			CurrencyModule:OnEnable()
			assert.spy(spyReg).was.called(2)
			assert.spy(spyReg).was.called_with(_, "CURRENCY_DISPLAY_UPDATE")
			assert.spy(spyReg).was.called_with(_, "PERKS_PROGRAM_CURRENCY_AWARDED")
		end)

		it("OnEnable registers only CHAT_MSG_CURRENCY for Classic >= WOTLK", function()
			CurrencyModule.isRetail = function()
				return false
			end
			CurrencyModule.currencyApi.GetExpansionLevel = function()
				return 3 -- WOTLK
			end
			local spyReg = spy.on(CurrencyModule, "RegisterEvent")
			CurrencyModule:OnEnable()
			assert.spy(spyReg).was.called(1)
			assert.spy(spyReg).was.called_with(_, "CHAT_MSG_CURRENCY")
		end)

		it("OnEnable does not register events for TBC (below WOTLK)", function()
			CurrencyModule.currencyApi.GetExpansionLevel = function()
				return 2 -- TBC
			end
			local spyReg = spy.on(CurrencyModule, "RegisterEvent")
			CurrencyModule:OnEnable()
			assert.spy(spyReg).was_not.called()
		end)

		it("OnDisable unregisters all three events for Retail >= BFA", function()
			CurrencyModule.isRetail = function()
				return true
			end
			CurrencyModule.currencyApi.GetExpansionLevel = function()
				return 8
			end
			local spyUnreg = spy.on(CurrencyModule, "UnregisterEvent")
			CurrencyModule:OnDisable()
			assert.spy(spyUnreg).was.called(3)
			assert.spy(spyUnreg).was.called_with(_, "CURRENCY_DISPLAY_UPDATE")
			assert.spy(spyUnreg).was.called_with(_, "PERKS_PROGRAM_CURRENCY_AWARDED")
			assert.spy(spyUnreg).was.called_with(_, "PERKS_PROGRAM_CURRENCY_REFRESH")
		end)

		it("OnDisable unregisters only CHAT_MSG_CURRENCY for Classic >= WOTLK", function()
			CurrencyModule.isRetail = function()
				return false
			end
			CurrencyModule.currencyApi.GetExpansionLevel = function()
				return 3
			end
			local spyUnreg = spy.on(CurrencyModule, "UnregisterEvent")
			CurrencyModule:OnDisable()
			assert.spy(spyUnreg).was.called(1)
			assert.spy(spyUnreg).was.called_with(_, "CHAT_MSG_CURRENCY")
		end)

		it("OnDisable does not unregister events when expansion < WOTLK", function()
			CurrencyModule.currencyApi.GetExpansionLevel = function()
				return 2
			end
			local spyUnreg = spy.on(CurrencyModule, "UnregisterEvent")
			CurrencyModule:OnDisable()
			assert.spy(spyUnreg).was_not.called()
		end)
	end)

	-- ── CURRENCY_DISPLAY_UPDATE / Process ──────────────────────────────────────

	it("does not show loot if the currency type is nil", function()
		CurrencyModule:CURRENCY_DISPLAY_UPDATE("CURRENCY_DISPLAY_UPDATE", nil)
		assert.spy(sendMessageSpy).was_not.called()
	end)

	it("does not show loot if quantityChange is nil", function()
		CurrencyModule:CURRENCY_DISPLAY_UPDATE("CURRENCY_DISPLAY_UPDATE", 123, nil, nil)
		assert.spy(sendMessageSpy).was_not.called()
	end)

	it("does not show loot if quantityChange is 0", function()
		CurrencyModule:CURRENCY_DISPLAY_UPDATE("CURRENCY_DISPLAY_UPDATE", 123, nil, 0)
		assert.spy(sendMessageSpy).was_not.called()
	end)

	it("does not show loot if currency info is nil", function()
		CurrencyModule.currencyApi.GetCurrencyInfo = function()
			return nil
		end
		CurrencyModule:CURRENCY_DISPLAY_UPDATE("CURRENCY_DISPLAY_UPDATE", 123, 1, 1)
		assert.spy(sendMessageSpy).was_not.called()
	end)

	it("does not show loot if currency info has empty description", function()
		CurrencyModule.currencyApi.GetCurrencyInfo = function()
			return { currencyID = 123, description = "", iconFileID = 123456 }
		end
		CurrencyModule:CURRENCY_DISPLAY_UPDATE("CURRENCY_DISPLAY_UPDATE", 123, 5, 2)
		assert.spy(sendMessageSpy).was_not.called()
	end)

	it("does not show loot if currency info has nil iconFileID", function()
		CurrencyModule.currencyApi.GetCurrencyInfo = function()
			return { currencyID = 123, description = "Some currency", iconFileID = nil }
		end
		CurrencyModule:CURRENCY_DISPLAY_UPDATE("CURRENCY_DISPLAY_UPDATE", 123, 5, 2)
		assert.spy(sendMessageSpy).was_not.called()
	end)

	it("does not show hidden currencies", function()
		ns.hiddenCurrencies = { [123] = true }
		CurrencyModule:CURRENCY_DISPLAY_UPDATE("CURRENCY_DISPLAY_UPDATE", 123, 5, 2)
		assert.spy(sendMessageSpy).was_not.called()
	end)

	it("does not show if currency link is nil", function()
		CurrencyModule.currencyApi.GetCurrencyLinkFromLib = function()
			return nil
		end
		CurrencyModule:CURRENCY_DISPLAY_UPDATE("CURRENCY_DISPLAY_UPDATE", 123, 5, 2)
		assert.spy(sendMessageSpy).was_not.called()
	end)

	it("shows loot when currency info is valid", function()
		local info = {
			currencyID = 123,
			description = "An awesome currency",
			iconFileID = 123456,
			quantity = 5,
			quality = 2,
			maxQuantity = 0,
			totalEarned = 0,
		}
		local basicInfo = { displayAmount = 2 }
		local link = "|c12345678|Hcurrency:123|h[Best Coin]|h|r"
		CurrencyModule.currencyApi.GetCurrencyInfo = function()
			return info
		end
		CurrencyModule.currencyApi.GetBasicCurrencyInfo = function()
			return basicInfo
		end
		CurrencyModule.currencyApi.GetCurrencyLinkFromLib = function()
			return link
		end

		local spyBuildPayload = spy.on(CurrencyModule, "BuildPayload")
		CurrencyModule:CURRENCY_DISPLAY_UPDATE("CURRENCY_DISPLAY_UPDATE", 123, 5, 2)
		assert.spy(spyBuildPayload).was.called_with(CurrencyModule, link, info, basicInfo)
		assert.spy(sendMessageSpy).was.called(1)
	end)

	it("falls back to GetCurrencyLinkFromGlobal when HasGetCurrencyLinkAPI returns false", function()
		CurrencyModule.currencyApi.HasGetCurrencyLinkAPI = function()
			return false
		end
		local fallbackLink = "|c12345678|Hcurrency:123|h[Fallback]|h|r"
		CurrencyModule.currencyApi.GetCurrencyLinkFromGlobal = function()
			return fallbackLink
		end
		local spyBuildPayload = spy.on(CurrencyModule, "BuildPayload")
		CurrencyModule:CURRENCY_DISPLAY_UPDATE("CURRENCY_DISPLAY_UPDATE", 123, 5, 2)
		assert.spy(spyBuildPayload).was.called_with(CurrencyModule, fallbackLink, _, _)
		assert.spy(sendMessageSpy).was.called(1)
	end)

	-- ── PERKS ──────────────────────────────────────────────────────────────────

	it("shows Trader's Tender currency via PERKS events", function()
		local info = {
			currencyID = 3008,
			description = "Trader's Tender",
			iconFileID = 123456,
			quantity = 5,
			quality = 2,
			maxQuantity = 0,
			totalEarned = 0,
		}
		local basicInfo = { displayAmount = 5 }
		local link = "|c12345678|Hcurrency:3008|h[Trader's Tender]|h|r"
		CurrencyModule.currencyApi.GetCurrencyInfo = function()
			return info
		end
		CurrencyModule.currencyApi.GetBasicCurrencyInfo = function()
			return basicInfo
		end
		CurrencyModule.currencyApi.GetCurrencyLinkFromLib = function()
			return link
		end

		local spyBuildPayload = spy.on(CurrencyModule, "BuildPayload")
		CurrencyModule:PERKS_PROGRAM_CURRENCY_AWARDED("PERKS_PROGRAM_CURRENCY_AWARDED", 5)
		CurrencyModule:PERKS_PROGRAM_CURRENCY_REFRESH("PERKS_PROGRAM_CURRENCY_REFRESH", 10, 15)

		assert.spy(spyBuildPayload).was.called_with(CurrencyModule, link, info, basicInfo)
		assert.spy(sendMessageSpy).was.called(1)
	end)

	it("does not show for Traders Tender when quantityChange is 0", function()
		CurrencyModule:PERKS_PROGRAM_CURRENCY_AWARDED("PERKS_PROGRAM_CURRENCY_AWARDED", 5)
		CurrencyModule:PERKS_PROGRAM_CURRENCY_REFRESH("PERKS_PROGRAM_CURRENCY_REFRESH", 10, 10)
		assert.spy(sendMessageSpy).was_not.called()
	end)

	-- ── Classic CHAT_MSG_CURRENCY parsing ──────────────────────────────────────

	describe("Classic chat message parsing", function()
		-- Helper to set up WOTLK Classic currency parsing in before_each
		local currencyLink = "|cffffffff|Hcurrency:241:0|h[Champion's Seal]|h|r"

		before_each(function()
			-- Switch to Classic WOTLK expansion (< BFA) to activate the
			-- CHAT_MSG_CURRENCY code path and classic pattern computation.
			CurrencyModule.currencyApi.GetExpansionLevel = function()
				return 3 -- WOTLK
			end
			CurrencyModule.currencyApi.GetCurrencyGainedMultiplePattern = function()
				return "You receive currency: %s x%d."
			end
			CurrencyModule.currencyApi.GetCurrencyGainedMultipleBonusPattern = function()
				return "You receive currency: %s x%d. (Bonus Objective)"
			end
			CurrencyModule.currencyApi.GetCurrencyLinkFromGlobal = function()
				return currencyLink
			end
			-- Call OnInitialize to pre-compute classicCurrencyPatterns from the
			-- adapter-provided locale strings (pure Lua string work, no WoW API).
			ns.DbAccessor.IsFeatureNeededByAnyFrame = function()
				return true
			end
			CurrencyModule:OnInitialize()
		end)

		describe("ParseCurrencyChangeMessage", function()
			it("defaults to 1 when no quantity in CURRENCY_GAINED message", function()
				local qty = CurrencyModule:ParseCurrencyChangeMessage(
					"You receive currency: |cffffffff|Hcurrency:241:0|h[Champion's Seal]|h|r."
				)
				assert.equals(1, qty)
			end)

			it("extracts quantity from CURRENCY_GAINED_MULTIPLE pattern", function()
				local qty = CurrencyModule:ParseCurrencyChangeMessage(
					"You receive currency: |cffffffff|Hcurrency:241:0|h[Champion's Seal]|h|r x5."
				)
				assert.equals(5, qty)
			end)

			it("extracts quantity from CURRENCY_GAINED_MULTIPLE_BONUS pattern", function()
				local qty = CurrencyModule:ParseCurrencyChangeMessage(
					"You receive currency: |cffffffff|Hcurrency:241:0|h[Champion's Seal]|h|r x5. (Bonus Objective)"
				)
				assert.equals(5, qty)
			end)
		end)

		describe("CHAT_MSG_CURRENCY", function()
			local currencyInfo

			before_each(function()
				currencyInfo = {
					currencyID = 241,
					quantity = 0,
					iconFileID = 133784,
					quality = 1,
				}
				CurrencyModule.currencyApi.GetCurrencyInfo = function()
					return currencyInfo
				end
			end)

			it("does not show when no currency link found in message", function()
				ns.ExtractCurrencyID = function()
					return nil
				end
				CurrencyModule:CHAT_MSG_CURRENCY("CHAT_MSG_CURRENCY", "Some random message")
				assert.spy(sendMessageSpy).was_not.called()
			end)

			it("does not show when ExtractCurrencyID returns 0", function()
				ns.ExtractCurrencyID = function()
					return 0
				end
				CurrencyModule:CHAT_MSG_CURRENCY("CHAT_MSG_CURRENCY", "You receive currency: " .. currencyLink .. ".")
				assert.spy(sendMessageSpy).was_not.called()
			end)

			it("does not show hidden currencies", function()
				ns.hiddenCurrencies = { [241] = true }
				CurrencyModule:CHAT_MSG_CURRENCY("CHAT_MSG_CURRENCY", "You receive currency: " .. currencyLink .. ".")
				assert.spy(sendMessageSpy).was_not.called()
			end)

			it("does not show when currency info is nil", function()
				CurrencyModule.currencyApi.GetCurrencyInfo = function()
					return nil
				end
				CurrencyModule:CHAT_MSG_CURRENCY("CHAT_MSG_CURRENCY", "You receive currency: " .. currencyLink .. ".")
				assert.spy(sendMessageSpy).was_not.called()
			end)

			it("does not show when BuildPayload returns nil", function()
				stub(CurrencyModule, "BuildPayload").returns(nil)
				CurrencyModule:CHAT_MSG_CURRENCY("CHAT_MSG_CURRENCY", "You receive currency: " .. currencyLink .. ".")
				assert.spy(sendMessageSpy).was_not.called()
			end)

			it("shows currency when parsing succeeds", function()
				local expectedBasicInfo = { displayAmount = 1 }
				local spyBuildPayload = spy.on(CurrencyModule, "BuildPayload")
				CurrencyModule:CHAT_MSG_CURRENCY("CHAT_MSG_CURRENCY", "You receive currency: " .. currencyLink .. ".")
				assert
					.spy(spyBuildPayload).was
					.called_with(CurrencyModule, currencyLink, currencyInfo, expectedBasicInfo)
				assert.spy(sendMessageSpy).was.called(1)
			end)

			it("overrides zero quantity from currency info with parsed quantityChange", function()
				local spyBuildPayload = spy.on(CurrencyModule, "BuildPayload")
				CurrencyModule:CHAT_MSG_CURRENCY(
					"CHAT_MSG_CURRENCY",
					"You receive currency: " .. currencyLink .. " x3."
				)
				local expectedCurrencyInfo = {
					currencyID = 241,
					quantity = 3, -- patched from quantityChange
					iconFileID = 133784,
					quality = 1,
				}
				assert
					.spy(spyBuildPayload).was
					.called_with(CurrencyModule, currencyLink, expectedCurrencyInfo, match.is_same({ displayAmount = 3 }))
				assert.spy(sendMessageSpy).was.called(1)
			end)

			it("overrides zero currencyID with extracted ID", function()
				currencyInfo.currencyID = 0
				CurrencyModule:CHAT_MSG_CURRENCY("CHAT_MSG_CURRENCY", "You receive currency: " .. currencyLink .. ".")
				-- The code patches currencyID from 0 → 241 in-place; check after the call.
				assert.equals(241, currencyInfo.currencyID)
				assert.spy(sendMessageSpy).was.called(1)
			end)

			it("ignores secrets-value messages", function()
				CurrencyModule.currencyApi.IssecretValue = function()
					return true
				end
				CurrencyModule:CHAT_MSG_CURRENCY("CHAT_MSG_CURRENCY", "secretmsg")
				assert.spy(sendMessageSpy).was_not.called()
				assert.spy(ns.LogWarn).was.called(1)
			end)
		end)
	end)

	-- ── ruRU localization ──────────────────────────────────────────────────────

	describe("ruRU localization", function()
		local ruCurrencyLink = "|cffffffff|Hcurrency:241:0|h[Печать чемпиона]|h|r"
		local currencyInfo

		before_each(function()
			CurrencyModule.currencyApi.GetExpansionLevel = function()
				return 3 -- WOTLK
			end
			CurrencyModule.currencyApi.GetCurrencyGainedMultiplePattern = function()
				return "Вы получаете валюту – %s, %d шт."
			end
			CurrencyModule.currencyApi.GetCurrencyGainedMultipleBonusPattern = function()
				return "Вы получаете валюту – %s, %d шт. (дополнительные задачи)"
			end
			CurrencyModule.currencyApi.GetCurrencyLinkFromGlobal = function()
				return ruCurrencyLink
			end
			currencyInfo = {
				currencyID = 241,
				quantity = 0,
				iconFileID = 133784,
				quality = 1,
			}
			CurrencyModule.currencyApi.GetCurrencyInfo = function()
				return currencyInfo
			end
			ns.DbAccessor.IsFeatureNeededByAnyFrame = function()
				return true
			end
			CurrencyModule:OnInitialize()
		end)

		describe("ParseCurrencyChangeMessage", function()
			it("defaults to 1 when no quantity in Russian message", function()
				local qty =
					CurrencyModule:ParseCurrencyChangeMessage("Какое-то случайное сообщение")
				assert.equals(1, qty) -- returns 1 as default
			end)

			it("extracts quantity from Russian CURRENCY_GAINED_MULTIPLE", function()
				local qty = CurrencyModule:ParseCurrencyChangeMessage(
					"Вы получаете валюту – |cffffffff|Hcurrency:241:0|h[Печать чемпиона]|h|r, 5 шт."
				)
				assert.equals(5, qty)
			end)

			it("extracts quantity from Russian CURRENCY_GAINED_MULTIPLE_BONUS", function()
				local qty = CurrencyModule:ParseCurrencyChangeMessage(
					"Вы получаете валюту – |cffffffff|Hcurrency:241:0|h[Печать чемпиона]|h|r, 5 шт. (дополнительные задачи)"
				)
				assert.equals(5, qty)
			end)
		end)

		describe("CHAT_MSG_CURRENCY", function()
			it("does not show when Russian message has no currency link", function()
				ns.ExtractCurrencyID = function()
					return nil
				end
				CurrencyModule:CHAT_MSG_CURRENCY(
					"CHAT_MSG_CURRENCY",
					"Какое-то случайное сообщение"
				)
				assert.spy(sendMessageSpy).was_not.called()
			end)

			it("shows currency when parsing Russian message succeeds", function()
				local spyBuildPayload = spy.on(CurrencyModule, "BuildPayload")
				CurrencyModule:CHAT_MSG_CURRENCY(
					"CHAT_MSG_CURRENCY",
					"Вы получаете валюту – " .. ruCurrencyLink .. "."
				)
				assert
					.spy(spyBuildPayload).was
					.called_with(CurrencyModule, ruCurrencyLink, currencyInfo, match.is_same({ displayAmount = 1 }))
				assert.spy(sendMessageSpy).was.called(1)
			end)

			it("handles Russian multiple quantity", function()
				local spyBuildPayload = spy.on(CurrencyModule, "BuildPayload")
				CurrencyModule:CHAT_MSG_CURRENCY(
					"CHAT_MSG_CURRENCY",
					"Вы получаете валюту – " .. ruCurrencyLink .. ", 3 шт."
				)
				local expectedCurrencyInfo = {
					currencyID = 241,
					quantity = 3,
					iconFileID = 133784,
					quality = 1,
				}
				assert
					.spy(spyBuildPayload).was
					.called_with(CurrencyModule, ruCurrencyLink, expectedCurrencyInfo, match.is_same({ displayAmount = 3 }))
				assert.spy(sendMessageSpy).was.called(1)
			end)

			it("handles Russian bonus objective quantity", function()
				local spyBuildPayload = spy.on(CurrencyModule, "BuildPayload")
				CurrencyModule:CHAT_MSG_CURRENCY(
					"CHAT_MSG_CURRENCY",
					"Вы получаете валюту – "
						.. ruCurrencyLink
						.. ", 5 шт. (дополнительные задачи)"
				)
				assert
					.spy(spyBuildPayload).was
					.called_with(CurrencyModule, ruCurrencyLink, _, match.is_same({ displayAmount = 5 }))
				assert.spy(sendMessageSpy).was.called(1)
			end)

			it("overrides basicInfo.displayAmount=0 with parsed quantityChange", function()
				-- Regression: Russian Classic sometimes returns displayAmount=0 from
				-- the API even though the chat message contains the real amount.
				local bigCurrencyInfo = {
					currencyID = 395,
					quantity = 2540,
					iconFileID = 133784,
					quality = 1,
					name = "Очки справедливости",
				}
				CurrencyModule.currencyApi.GetCurrencyInfo = function()
					return bigCurrencyInfo
				end
				ns.ExtractCurrencyID = function()
					return 395
				end
				CurrencyModule.currencyApi.GetCurrencyLinkFromGlobal = function()
					return "|cffffffff|Hcurrency:395:0|h[Очки справедливости]|h|r"
				end
				local parseStub = stub(CurrencyModule, "ParseCurrencyChangeMessage").returns(83)

				local spyBuildPayload = spy.on(CurrencyModule, "BuildPayload")
				CurrencyModule:CHAT_MSG_CURRENCY(
					"CHAT_MSG_CURRENCY",
					"Вы получаете валюту – [Очки справедливости], 83 шт."
				)
				-- basicInfo should have displayAmount patched to 83
				assert
					.spy(spyBuildPayload).was
					.called_with(CurrencyModule, _, bigCurrencyInfo, match.is_same({ displayAmount = 83 }))
				assert.spy(sendMessageSpy).was.called(1)
				parseStub:revert()
			end)
		end)
	end)

	-- ── BuildPayload ──────────────────────────────────────────────────────────

	describe("BuildPayload", function()
		local function makeLink(id)
			return "|c12345678|Hcurrency:" .. (id or 123) .. "|h[Test Currency]|h|r"
		end
		local function makeInfo(overrides)
			local base = {
				currencyID = 123,
				description = "An awesome currency",
				iconFileID = 123456,
				quantity = 5,
				quality = 2,
				maxQuantity = 0,
				totalEarned = 0,
			}
			if overrides then
				for k, v in pairs(overrides) do
					base[k] = v
				end
			end
			return base
		end

		it("sets type, isLink, key, icon, and quality", function()
			local info = makeInfo()
			local basicInfo = { displayAmount = 2 }
			local p = CurrencyModule:BuildPayload(makeLink(), info, basicInfo)
			assert.is_not_nil(p)
			assert.equals("Currency", p.type)
			assert.is_true(p.isLink)
			assert.equals("CURRENCY_123", p.key)
			assert.equals(123456, p.icon)
			assert.equals(2, p.quality)
		end)

		it("returns nil when currencyLink is nil", function()
			local p = CurrencyModule:BuildPayload(nil, makeInfo(), { displayAmount = 1 })
			assert.is_nil(p)
		end)

		it("hides icon when currency.enableIcon is false", function()
			ns.db.global.currency.enableIcon = false
			local p = CurrencyModule:BuildPayload(makeLink(), makeInfo(), { displayAmount = 1 })
			assert.is_nil(p.icon)
		end)

		it("hides icon when misc.hideAllIcons is true", function()
			ns.db.global.misc.hideAllIcons = true
			local p = CurrencyModule:BuildPayload(makeLink(), makeInfo(), { displayAmount = 1 })
			assert.is_nil(p.icon)
		end)

		it("textFn returns raw link when no truncatedLink", function()
			local link = makeLink()
			local p = CurrencyModule:BuildPayload(link, makeInfo(), { displayAmount = 1 })
			assert.equals(link, p.textFn(nil, nil))
		end)

		it("textFn returns truncatedLink when provided", function()
			local p = CurrencyModule:BuildPayload(makeLink(), makeInfo(), { displayAmount = 2 })
			assert.equals("[Currency]", p.textFn(0, "[Currency]"))
		end)

		it("amountTextFn returns quantity suffix when quantity > 1", function()
			local p = CurrencyModule:BuildPayload(makeLink(), makeInfo(), { displayAmount = 2 })
			assert.equals("x2", p.amountTextFn(0))
		end)

		it("amountTextFn returns empty string when quantity is 1 and showOneQuantity is false", function()
			ns.db.global.misc.showOneQuantity = false
			local p = CurrencyModule:BuildPayload(makeLink(), makeInfo(), { displayAmount = 1 })
			assert.equals("", p.amountTextFn(0))
		end)

		it("secondaryTextFn returns empty string when cappedQuantity is 0", function()
			CurrencyModule:OnEnable() -- registers context provider
			local p = CurrencyModule:BuildPayload(makeLink(), makeInfo(), { displayAmount = 1 })
			-- cappedQuantity = maxQuantity = 0
			assert.equals("", p.secondaryTextFn())
		end)

		it("sets isCustomLink for Ethereal Strands (ID 3278)", function()
			local info = makeInfo({ currencyID = 3278 })
			local p = CurrencyModule:BuildPayload(
				"|c12345678|Hcurrency:3278|h[Ethereal Strands]|h|r",
				info,
				{ displayAmount = 1 }
			)
			assert.is_not_nil(p)
			assert.is_true(p.isCustomLink)
		end)
	end)
end)
