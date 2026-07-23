---@diagnostic disable: need-check-nil
local assert = require("luassert")
local match = require("luassert.match")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local spy = busted.spy
local stub = busted.stub

describe("Professions Module", function()
	local _ = match._
	---@type RLF_Professions, table
	local Professions, ns, sendMessageSpy

	before_each(function()
		sendMessageSpy = spy.new(function() end)

		-- Build a minimal ns from scratch – no nsMocks framework needed.
		ns = {
			DefaultIcons = { PROFESSION = 134400 },
			ItemQualEnum = { Rare = 3 },
			FeatureModule = { Profession = "Professions" },
			WoWAPI = { Professions = {} },
			LogDebug = function() end,
			LogInfo = function() end,
			LogWarn = function() end,
			RGBAToHexFormat = function()
				return "|cFFFFFFFF"
			end,
			CreatePatternSegmentsForStringNumber = function()
				return {}
			end,
			ExtractDynamicsFromPattern = function()
				return nil, nil
			end,
			SendMessage = sendMessageSpy,
			db = {
				global = {
					animations = { exit = { fadeOutDelay = 3 } },
					prof = {
						enabled = true,
						enableIcon = true,
						skillColor = { 1, 1, 1, 1 },
						showSkillChange = true,
						skillTextWrapChar = ".",
					},
					misc = { hideAllIcons = false },
				},
			},
			DbAccessor = {
				IsFeatureNeededByAnyFrame = function()
					return true
				end,
				AnyFeatureConfig = function(_, featureKey)
					if featureKey == "profession" then
						return ns.db.global.prof
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
		ns.DI:Register("WoWAPI.Professions", {})

		-- Mock FeatureBase – returns a minimal stub module so Professions tests
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

		-- Load Professions – the FeatureBase mock above captures deps from ns.DI.
		Professions = assert(loadfile("RPGLootFeed/Features/Professions.lua"))("TestAddon", ns)

		-- Inject a fresh mock adapter so tests control external WoW API calls.
		Professions.professionsApi = {
			GetProfessions = function()
				return 1, 2, 3, 4, 5
			end,
			GetProfessionInfo = function(id)
				local profMap = {
					[1] = { "Mining", 133784, 100, 150 },
					[2] = { "Blacksmithing", 133782, 50, 150 },
					[3] = { "Archaeology", 133786, 200, 300 },
					[4] = { "Fishing", 133785, 75, 150 },
					[5] = { "Cooking", 133783, 25, 150 },
				}
				local info = profMap[id]
				return info[1], info[2], info[3], info[4]
			end,
			IssecretValue = function()
				return false
			end,
			GetSkillRankUpPattern = function()
				return "%s has increased to %d."
			end,
		}
	end)

	describe("BuildPayload and OnInitialize", function()
		it("creates payload and element with correct properties", function()
			local payload = Professions:BuildPayload("Mining", "Mining", 133784, 100, 5)

			assert.is_not_nil(payload)
			assert.is_not_nil(payload.textFn)
			assert.is_not_nil(payload.secondaryTextFn)
			assert.is_not_nil(payload.itemCountFn)
			assert.equals("Professions", payload.type)
		end)

		it("initializes profession tracking on enable via OnInitialize", function()
			Professions:OnInitialize()

			assert.is_not_nil(Professions.professions)
			assert.is_not_nil(Professions.profNameIconMap)
			assert.is_not_nil(Professions.profLocaleBaseNames)
		end)
	end)

	describe("IsEnabled closure", function()
		it("returns true when module is enabled", function()
			local payload = Professions:BuildPayload("Mining", "Mining", 133784, 100, 5)
			local element = ns.LootElementBase:fromPayload(payload)

			local enabledStub = stub(Professions, "IsEnabled").returns(true)
			assert.is_true(element.IsEnabled())
			enabledStub:revert()
		end)

		it("returns false when module is disabled", function()
			local payload = Professions:BuildPayload("Mining", "Mining", 133784, 100, 5)
			local element = ns.LootElementBase:fromPayload(payload)

			local disabledStub = stub(Professions, "IsEnabled").returns(false)
			assert.is_false(element.IsEnabled())
			disabledStub:revert()
		end)
	end)

	describe("Event handling", function()
		it("does not show skill when secret value", function()
			Professions:OnInitialize()

			Professions.professionsApi.IssecretValue = function()
				return true
			end

			Professions:CHAT_MSG_SKILL("CHAT_MSG_SKILL", "Some message")

			assert.spy(sendMessageSpy).was.not_called()
		end)

		it("does not show skill when CHAT_MSG_SKILL and skill name is nil", function()
			Professions:OnInitialize()

			-- Pattern already returns nil for skill name
			Professions:CHAT_MSG_SKILL("CHAT_MSG_SKILL", "Some message")

			assert.spy(sendMessageSpy).was.not_called()
		end)

		it("creates element when CHAT_MSG_SKILL fires with valid data", function()
			Professions:OnInitialize()

			-- Stub the extraction to return valid data
			ns.ExtractDynamicsFromPattern = function()
				return "Mining", 105
			end

			-- Mock the first call to InitializeProfessions to set up profession tracking
			Professions.profNameIconMap = { ["Mining"] = 133784 }
			Professions.profLocaleBaseNames = { "Mining" }

			Professions:CHAT_MSG_SKILL("CHAT_MSG_SKILL", "Mining has increased to 105.")

			assert.spy(sendMessageSpy).was.called(1)
		end)

		it("uses fallback icon when skill mapping not found", function()
			Professions:OnInitialize()

			-- Stub the extraction to return valid data for an unknown skill
			ns.ExtractDynamicsFromPattern = function()
				return "UnknownSkill", 50
			end

			Professions:CHAT_MSG_SKILL("CHAT_MSG_SKILL", "UnknownSkill has increased to 50.")

			assert.spy(sendMessageSpy).was.called(1)
		end)
	end)
end)
