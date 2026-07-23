local assert = require("luassert")
local match = require("luassert.match")
local busted = require("busted")
local spy = busted.spy
local stub = busted.stub
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("TravelPoints module", function()
	local _ = match._
	local TravelPointsModule, ns
	local sendMessageSpy

	before_each(function()
		-- Spy on ns.SendMessage so event-handling tests can assert it was called.
		sendMessageSpy = spy.new(function() end)

		-- Build a minimal ns from scratch – no nsMocks framework needed.
		-- Only the fields actually referenced by TravelPoints.lua and LootElementBase.lua
		-- are included; everything else is intentionally absent.
		ns = {
			-- Captured as locals by TravelPoints.lua at load time.
			DefaultIcons = { TRAVELPOINTS = "Interface/Icons/Ability_mount_travelhorse" },
			ItemQualEnum = { Common = 1 },
			FeatureModule = { TravelPoints = "TravelPoints" },
			WoWAPI = { TravelPoints = {} },
			-- Closure wrappers call these as G_RLF:Method(...).
			LogDebug = function() end,
			LogInfo = function() end,
			LogWarn = function() end,
			IsRetail = function()
				return true
			end,
			-- RGBAToHexFormat is used by secondaryTextFn; return a fixed hex for tests.
			RGBAToHexFormat = function()
				return "|cFFFFFFFF"
			end,
			SendMessage = sendMessageSpy,
			-- Runtime lookup by LootElementBase:fromPayload() and TravelPoints lifecycle methods.
			db = {
				global = {
					animations = { exit = { fadeOutDelay = 3 } },
					travelPoints = { textColor = { 1, 1, 1, 1 }, enableIcon = true, enabled = true },
					misc = { hideAllIcons = false },
				},
			},
			DbAccessor = {
				IsFeatureNeededByAnyFrame = function()
					return true
				end,
				AnyFeatureConfig = function(_, featureKey)
					return ns.db.global.travelPoints
				end,
				Animations = function(_, frameId)
					return ns.db.global.animations
				end,
			},
			Frames = { MAIN = 1 },
		}

		-- Load real LootElementBase so elements are fully constructed.
		assert(loadfile("RPGLootFeed/Features/_Internals/LootElementBase.lua"))("TestAddon", ns)
		assert(loadfile("RPGLootFeed/utils/FeatureRegistry.lua"))("TestAddon", ns)
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
		ns.DI:Register("WoWAPI.TravelPoints", {})
		ns.DI:Register("IsRetail", function()
			return ns.IsRetail()
		end)

		-- Mock FeatureBase – returns a minimal stub module so TravelPoints tests
		-- are completely independent of AceAddon plumbing.  The stub includes the
		-- Ace lifecycle methods that TravelPoints.lua calls (Enable, Disable, etc.)
		-- so spy.on() has something to wrap.
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

		-- Load TravelPoints – the FeatureBase mock above captures deps from ns.DI.
		TravelPointsModule = assert(loadfile("RPGLootFeed/Features/TravelPoints/TravelPoints.lua"))("TestAddon", ns)

		-- Inject fresh mock adapter for full test isolation.
		TravelPointsModule.travelPointsApi = {
			GetPerksActivitiesInfo = function()
				return nil
			end,
			GetPerksActivityInfo = function(_activityID)
				return nil
			end,
			GetMonthlyActivitiesPointsLabel = function()
				return "Traveler's Log"
			end,
		}
	end)

	describe("BuildPayload and element creation", function()
		local function buildElement(quantity)
			local payload = TravelPointsModule:BuildPayload(quantity)
			if not payload then
				return nil
			end
			return ns.LootElementBase:fromPayload(payload)
		end

		it("creates payload with correct properties", function()
			local quantity = 25

			local payload = TravelPointsModule:BuildPayload(quantity)

			assert.is_not_nil(payload)
			assert.are.equal("TravelPoints", payload.type)
			assert.are.equal("TRAVELPOINTS", payload.key)
			assert.are.equal(quantity, payload.quantity)
			assert.are.equal(ns.ItemQualEnum.Common, payload.quality)
			assert.is_function(payload.textFn)
			assert.is_function(payload.secondaryTextFn)
		end)

		it("creates element from payload via fromPayload", function()
			local quantity = 25

			local element = buildElement(quantity)

			assert.is_not_nil(element)
			assert.are.equal("TravelPoints", element.type)
			assert.are.equal("TRAVELPOINTS", element.key)
			assert.are.equal(quantity, element.quantity)
			assert.are.equal(ns.DefaultIcons.TRAVELPOINTS, element.icon)
			assert.are.equal(ns.ItemQualEnum.Common, element.quality)
			assert.is_function(element.textFn)
			assert.is_function(element.secondaryTextFn)
		end)

		it("textFn returns correct format with existing amount", function()
			local quantity = 25
			local existingAmount = 50

			local element = buildElement(quantity)
			local result = element.textFn(existingAmount)

			assert.are.equal("Traveler's Log + 75", result)
		end)

		it("textFn returns correct format with no existing amount", function()
			local quantity = 25

			local element = buildElement(quantity)
			local result = element.textFn()

			assert.are.equal("Traveler's Log + 25", result)
		end)

		it("secondaryTextFn returns progress when journey values are set", function()
			local quantity = 25

			TravelPointsModule.travelPointsApi = {
				GetPerksActivitiesInfo = function()
					return {
						activities = {
							{ ID = 1, completed = true, thresholdContributionAmount = 10 },
							{ ID = 2, completed = false, thresholdContributionAmount = 20 },
						},
						thresholds = {
							{ requiredContributionAmount = 100 },
							{ requiredContributionAmount = 150 },
						},
					}
				end,
				GetPerksActivityInfo = function(_activityID)
					return { thresholdContributionAmount = 20 }
				end,
				GetMonthlyActivitiesPointsLabel = function()
					return "Traveler's Log"
				end,
			}

			-- Trigger the event to populate internal journey values
			TravelPointsModule:PERKS_ACTIVITY_COMPLETED("PERKS_ACTIVITY_COMPLETED", 2)

			local element = buildElement(quantity)
			local result = element.secondaryTextFn()

			-- current = 10 (completed) + 20 (activity 2) = 30, max = 150
			assert.matches("30/150", result)
		end)

		it("secondaryTextFn returns empty string when no journey data", function()
			local quantity = 25

			local element = buildElement(quantity)
			local result = element.secondaryTextFn()

			assert.are.equal("", result)
		end)

		it("IsEnabled function returns module enabled state", function()
			local element = buildElement(25)

			-- Test when enabled
			local enabledStub = stub(TravelPointsModule, "IsEnabled").returns(true)
			assert.is_true(element.IsEnabled())
			enabledStub:revert()

			-- Test when disabled
			local disabledStub = stub(TravelPointsModule, "IsEnabled").returns(false)
			assert.is_false(element.IsEnabled())
			disabledStub:revert()
		end)
	end)

	describe("Module lifecycle", function()
		it("OnInitialize enables module when retail and any frame needs travelPoints", function()
			ns.DbAccessor.IsFeatureNeededByAnyFrame = function()
				return true
			end
			local isRetailStub = stub(ns, "IsRetail").returns(true)
			local enableSpy = spy.on(TravelPointsModule, "Enable")

			TravelPointsModule:OnInitialize()

			assert.spy(enableSpy).was.called(1)
			isRetailStub:revert()
		end)

		it("OnInitialize disables module when not retail", function()
			ns.DbAccessor.IsFeatureNeededByAnyFrame = function()
				return true
			end
			local isRetailStub = stub(ns, "IsRetail").returns(false)
			local disableSpy = spy.on(TravelPointsModule, "Disable")

			TravelPointsModule:OnInitialize()

			assert.spy(disableSpy).was.called(1)
			isRetailStub:revert()
		end)

		it("OnInitialize disables module when no frame needs travelPoints", function()
			ns.DbAccessor.IsFeatureNeededByAnyFrame = function()
				return false
			end
			local isRetailStub = stub(ns, "IsRetail").returns(true)
			local disableSpy = spy.on(TravelPointsModule, "Disable")

			TravelPointsModule:OnInitialize()

			assert.spy(disableSpy).was.called(1)
			isRetailStub:revert()
		end)

		it("OnEnable registers PERKS_ACTIVITY_COMPLETED event when retail", function()
			local isRetailStub = stub(ns, "IsRetail").returns(true)
			local registerEventSpy = spy.on(TravelPointsModule, "RegisterEvent")

			TravelPointsModule:OnEnable()

			assert.spy(registerEventSpy).was.called_with(_, "PERKS_ACTIVITY_COMPLETED")
			isRetailStub:revert()
		end)

		it("OnEnable does nothing when not retail", function()
			local isRetailStub = stub(ns, "IsRetail").returns(false)
			local registerEventSpy = spy.on(TravelPointsModule, "RegisterEvent")

			TravelPointsModule:OnEnable()

			assert.spy(registerEventSpy).was.not_called()
			isRetailStub:revert()
		end)

		it("OnDisable unregisters PERKS_ACTIVITY_COMPLETED event when retail", function()
			local isRetailStub = stub(ns, "IsRetail").returns(true)
			local unregisterEventSpy = spy.on(TravelPointsModule, "UnregisterEvent")

			TravelPointsModule:OnDisable()

			assert.spy(unregisterEventSpy).was.called_with(_, "PERKS_ACTIVITY_COMPLETED")
			isRetailStub:revert()
		end)

		it("OnDisable does nothing when not retail", function()
			local isRetailStub = stub(ns, "IsRetail").returns(false)
			local unregisterEventSpy = spy.on(TravelPointsModule, "UnregisterEvent")

			TravelPointsModule:OnDisable()

			assert.spy(unregisterEventSpy).was.not_called()
			isRetailStub:revert()
		end)
	end)

	describe("Event handling", function()
		it("PERKS_ACTIVITY_COMPLETED creates and shows element with valid amount", function()
			local activityID = 123
			local contributionAmount = 25

			TravelPointsModule.travelPointsApi = {
				GetPerksActivityInfo = function(_activityID)
					return { thresholdContributionAmount = contributionAmount }
				end,
				GetPerksActivitiesInfo = function()
					return {
						activities = {
							{ ID = 1, completed = true, thresholdContributionAmount = 10 },
							{ ID = activityID, completed = false, thresholdContributionAmount = contributionAmount },
						},
						thresholds = {
							{ requiredContributionAmount = 100 },
						},
					}
				end,
				GetMonthlyActivitiesPointsLabel = function()
					return "Traveler's Log"
				end,
			}

			local buildPayloadSpy = spy.on(TravelPointsModule, "BuildPayload")

			TravelPointsModule:PERKS_ACTIVITY_COMPLETED("PERKS_ACTIVITY_COMPLETED", activityID)

			-- BuildPayload was called with the correct contribution amount
			assert.spy(buildPayloadSpy).was.called_with(_, contributionAmount)
			-- Show() dispatches via G_RLF:SendMessage
			assert.spy(sendMessageSpy).was.called()
		end)

		it("PERKS_ACTIVITY_COMPLETED logs warning when GetPerksActivityInfo fails", function()
			local activityID = 123

			local buildPayloadSpy = spy.on(TravelPointsModule, "BuildPayload")
			local logWarnSpy = spy.on(ns, "LogWarn")

			TravelPointsModule:PERKS_ACTIVITY_COMPLETED("PERKS_ACTIVITY_COMPLETED", activityID)

			assert.spy(buildPayloadSpy).was.not_called()
			assert.spy(logWarnSpy).was.called()
		end)

		it("PERKS_ACTIVITY_COMPLETED logs warning when amount is not positive", function()
			local activityID = 123

			TravelPointsModule.travelPointsApi = {
				GetPerksActivityInfo = function(_activityID)
					return { thresholdContributionAmount = 0 }
				end,
				GetPerksActivitiesInfo = function()
					return { activities = {}, thresholds = {} }
				end,
				GetMonthlyActivitiesPointsLabel = function()
					return "Traveler's Log"
				end,
			}

			local buildPayloadSpy = spy.on(TravelPointsModule, "BuildPayload")
			local logWarnSpy = spy.on(ns, "LogWarn")

			TravelPointsModule:PERKS_ACTIVITY_COMPLETED("PERKS_ACTIVITY_COMPLETED", activityID)

			assert.spy(buildPayloadSpy).was.not_called()
			assert.spy(logWarnSpy).was.called()
		end)

		it("PERKS_ACTIVITY_COMPLETED logs warning when GetPerksActivitiesInfo fails", function()
			local activityID = 123

			TravelPointsModule.travelPointsApi = {
				GetPerksActivityInfo = function(_activityID)
					return { thresholdContributionAmount = 25 }
				end,
				GetPerksActivitiesInfo = function()
					return nil
				end,
				GetMonthlyActivitiesPointsLabel = function()
					return "Traveler's Log"
				end,
			}

			local logWarnSpy = spy.on(ns, "LogWarn")

			TravelPointsModule:PERKS_ACTIVITY_COMPLETED("PERKS_ACTIVITY_COMPLETED", activityID)

			assert.spy(logWarnSpy).was.called()
		end)
	end)

	describe("calcTravelersJourneyVal function", function()
		it("calculates progress correctly with completed and current activities", function()
			local activityID = 2

			TravelPointsModule.travelPointsApi = {
				GetPerksActivitiesInfo = function()
					return {
						activities = {
							{ ID = 1, completed = true, thresholdContributionAmount = 10 },
							{ ID = activityID, completed = false, thresholdContributionAmount = 20 },
							{ ID = 3, completed = false, thresholdContributionAmount = 15 },
						},
						thresholds = {
							{ requiredContributionAmount = 100 },
							{ requiredContributionAmount = 150 },
						},
					}
				end,
				GetPerksActivityInfo = function(_activityID)
					return { thresholdContributionAmount = 20 }
				end,
				GetMonthlyActivitiesPointsLabel = function()
					return "Traveler's Log"
				end,
			}

			-- Trigger the event which internally calls calcTravelersJourneyVal
			TravelPointsModule:PERKS_ACTIVITY_COMPLETED("PERKS_ACTIVITY_COMPLETED", activityID)

			-- Verify journey values via secondaryTextFn on a fresh element
			local payload = TravelPointsModule:BuildPayload(20)
			local element = ns.LootElementBase:fromPayload(payload)
			local result = element.secondaryTextFn()

			-- current = 10 (completed) + 20 (activity 2 = current) = 30, max = 150
			assert.matches("30/150", result)
		end)
	end)
end)
