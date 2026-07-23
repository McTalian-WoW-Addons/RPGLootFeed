---@diagnostic disable: undefined-field
local assert = require("luassert")
local match = require("luassert.match")
local busted = require("busted")
local spy = busted.spy
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local stub = busted.stub

describe("Experience module", function()
	local _ = match._
	local XpModule, ns
	local sendMessageSpy

	before_each(function()
		sendMessageSpy = spy.new(function() end)

		-- Build a minimal ns from scratch – no nsMocks framework needed.
		-- Only the fields actually referenced by Experience.lua, LootElementBase.lua,
		-- and TextTemplateEngine.lua are included.
		ns = {
			DefaultIcons = { XP = 894556 },
			ItemQualEnum = { Epic = 4 },
			FeatureModule = { Experience = "Experience" },
			WoWAPI = { Experience = {} },
			-- Closure wrappers call these as G_RLF:Method(...).
			LogDebug = function() end,
			LogInfo = function() end,
			LogWarn = function() end,
			IsRetail = function()
				return true
			end,
			-- RGBAToHexFormat used by TextTemplateEngine for colored text.
			RGBAToHexFormat = function()
				return "|cFFEDCBA0"
			end,
			-- L used by createExperienceContextProvider for the {xpLabel} template key.
			L = { XP = "XP" },
			SendMessage = sendMessageSpy,
			-- Runtime lookups by LootElementBase:fromPayload() and lifecycle methods.
			db = {
				global = {
					animations = { exit = { fadeOutDelay = 3 } },
					xp = {
						enabled = true,
						enableIcon = true,
						experienceTextColor = { 0.93, 0.55, 0.63, 1.0 },
						showCurrentLevel = true,
						currentLevelColor = { 0.749, 0.737, 0.012, 1 },
						currentLevelTextWrapChar = "<",
					},
					misc = { hideAllIcons = false, showOneQuantity = false },
				},
			},
			DbAccessor = {
				IsFeatureNeededByAnyFrame = function()
					return true
				end,
				AnyFeatureConfig = function(_, featureKey)
					if featureKey == "experience" then
						return ns.db.global.xp
					end
					return nil
				end,
				Animations = function(_, frameId)
					return ns.db.global.animations
				end,
			},
			Frames = { MAIN = 1 },
		}

		-- Load real LootElementBase so elements are fully constructed.
		assert(loadfile("RPGLootFeed/Features/_Internals/LootElementBase.lua"))("TestAddon", ns)
		assert.is_not_nil(ns.LootElementBase)

		-- Load TextTemplateEngine before Experience.lua so DI can resolve it.
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
		ns.DI:Register("DefaultIcons", ns.DefaultIcons)
		ns.DI:Register("ItemQualEnum", ns.ItemQualEnum)
		ns.DI:Register("TextTemplateEngine", ns.TextTemplateEngine)
		ns.DI:Register("WoWAPI.Experience", {})
		ns.DI:Register("RGBAToHexFormat", ns.RGBAToHexFormat)

		-- Mock FeatureBase – returns a minimal stub module so Experience tests
		-- are completely independent of AceAddon plumbing.
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

		-- Load Experience – the FeatureBase mock above captures deps from ns.DI.
		XpModule = assert(loadfile("RPGLootFeed/Features/Experience.lua"))("TestAddon", ns)

		-- Inject a default adapter so event-handler tests work without
		-- patching _G directly.
		XpModule.xpApi = {
			UnitXP = function()
				return 10
			end,
			UnitXPMax = function()
				return 50
			end,
			UnitLevel = function()
				return 2
			end,
		}
	end)

	it("does not show xp if the unit target is not player", function()
		ns.db.global.xp.enabled = true

		XpModule:PLAYER_XP_UPDATE("PLAYER_XP_UPDATE", "target")

		assert.spy(sendMessageSpy).was.not_called()
	end)

	it("does not show xp if the calculated delta is 0", function()
		ns.db.global.xp.enabled = true

		XpModule:PLAYER_ENTERING_WORLD()

		XpModule:PLAYER_XP_UPDATE("PLAYER_XP_UPDATE", "player")

		assert.spy(sendMessageSpy).was.not_called()
	end)

	it("show xp if the player levels up", function()
		ns.db.global.xp.enabled = true

		XpModule:PLAYER_ENTERING_WORLD()

		-- Leveled up from 2 to 3
		-- old max XP was 50
		-- xp value is still 10
		-- (50 max for last level - 10 old xp value) + 10 new xp value = 50 xp earned
		XpModule.xpApi.UnitLevel = function()
			return 3
		end
		XpModule.xpApi.UnitXPMax = function()
			return 100
		end

		local buildPayload = spy.on(XpModule, "BuildPayload")

		XpModule:PLAYER_XP_UPDATE("PLAYER_XP_UPDATE", "player")

		assert.spy(buildPayload).was.called_with(_, 50)
		assert.spy(sendMessageSpy).was.called(1)
	end)

	describe("GenerateTextElements", function()
		it("generates row 1 elements", function()
			local elements = XpModule:GenerateTextElements(500)

			assert.is_not_nil(elements[1])
			assert.is_not_nil(elements[1].primary)
			assert.equal("primary", elements[1].primary.type)
			assert.equal("{sign}{total} {xpLabel}", elements[1].primary.template)
			assert.equal(1, elements[1].primary.order)
		end)

		it("generates row 2 elements", function()
			local elements = XpModule:GenerateTextElements(500)

			assert.is_not_nil(elements[2])
			assert.is_not_nil(elements[2].context)
			assert.equal("context", elements[2].context.type)
			assert.equal("{currentXPPercentage}", elements[2].context.template)
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
			XpModule:OnEnable()
		end)

		it("creates experience payload with correct properties", function()
			local payload = XpModule:BuildPayload(500)

			assert.is_not_nil(payload)
			assert.equal("Experience", payload.type)
			assert.equal("EXPERIENCE", payload.key)
			assert.equal(500, payload.quantity)
			assert.is_not_nil(payload.icon)
			assert.is_function(payload.textFn)
			assert.is_function(payload.secondaryTextFn)
			assert.is_function(payload.itemCountFn)
		end)

		it("creates element from payload via fromPayload", function()
			local payload = XpModule:BuildPayload(500)
			local element = ns.LootElementBase:fromPayload(payload)

			assert.is_not_nil(element)
			assert.equal("Experience", element.type)
			assert.equal("EXPERIENCE", element.key)
			assert.equal(500, element.quantity)
			assert.is_function(element.textFn)
			assert.is_function(element.secondaryTextFn)
			assert.is_function(element.itemCountFn)
			assert.is_function(element.IsEnabled)
			assert.is_function(element.Show)
		end)

		it("textFn uses TextTemplateEngine", function()
			local payload = XpModule:BuildPayload(500)

			local result = payload.textFn(250)

			-- Should contain the total amount: 500 + 250 = 750 XP
			assert.truthy(result)
			assert.is_string(result)
			assert.matches("750", result)
			assert.matches("XP", result)
			assert.matches("|cFFEDCBA0", result)
			assert.matches("|r", result) -- Ensure color reset at end
		end)

		it("secondaryTextFn shows XP percentage when XP data available", function()
			-- Override adapter to return specific XP values for this test.
			XpModule.xpApi.UnitXP = function()
				return 7526
			end
			XpModule.xpApi.UnitXPMax = function()
				return 10000
			end

			-- Initialize XP values via event handler
			XpModule:PLAYER_ENTERING_WORLD("PLAYER_ENTERING_WORLD")

			local payload = XpModule:BuildPayload(500)
			local result = payload.secondaryTextFn(250)

			-- Should contain percentage display (7526/10000 = 75.26%)
			assert.truthy(result)
			assert.is_string(result)
			assert.matches("    ", result) -- Check for 4 spaces
			assert.matches("75.26%%", result) -- Escape the dot and double % for literal match
			assert.matches("|cFFEDCBA0", result)
			assert.matches("|r", result) -- Ensure color reset at end
		end)

		it("secondaryTextFn returns empty when XP data unavailable", function()
			-- Override adapter to return nil to simulate missing data.
			XpModule.xpApi.UnitXP = function()
				return nil
			end
			XpModule.xpApi.UnitXPMax = function()
				return nil
			end

			-- Initialize with nil values
			XpModule:PLAYER_ENTERING_WORLD("PLAYER_ENTERING_WORLD")

			local payload = XpModule:BuildPayload(500)
			local result = payload.secondaryTextFn(250)

			-- Should return empty string when XP data is not available
			assert.equal("", result)
		end)

		it("returns nil for zero quantity", function()
			local payload = XpModule:BuildPayload(0)
			assert.is_nil(payload)

			local payload2 = XpModule:BuildPayload(nil)
			assert.is_nil(payload2)
		end)

		it("itemCountFn returns current level when showCurrentLevel is true", function()
			XpModule:PLAYER_ENTERING_WORLD("PLAYER_ENTERING_WORLD")

			local payload = XpModule:BuildPayload(500)
			local value, options = payload.itemCountFn()

			assert.equal(2, value) -- currentLevel from adapter mock
			assert.is_not_nil(options)
			assert.is_not_nil(options.color)
			assert.is_not_nil(options.wrapChar)
		end)

		it("itemCountFn returns nil when showCurrentLevel is false", function()
			ns.db.global.xp.showCurrentLevel = false
			XpModule:PLAYER_ENTERING_WORLD("PLAYER_ENTERING_WORLD")

			local payload = XpModule:BuildPayload(500)
			local value = payload.itemCountFn()

			assert.is_nil(value)
		end)
	end)
end)
