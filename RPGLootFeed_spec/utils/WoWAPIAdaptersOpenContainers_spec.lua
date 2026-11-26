local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local after_each = busted.after_each
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("WoWAPI.OpenContainers state and event adapters", function()
	local ns, api
	local saved = {}
	local globals = {
		"InCombatLockdown",
		"UnitAffectingCombat",
		"IsStealthed",
		"issecretvalue",
		"C_EventUtils",
		"CreateFrame",
	}

	before_each(function()
		for _, name in ipairs(globals) do
			saved[name] = _G[name]
		end
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		ns.WoWAPI = nil
		assert(loadfile("RPGLootFeed/utils/WoWAPIAdapters.lua"))("TestAddon", ns)
		api = ns.WoWAPI.OpenContainers
	end)

	after_each(function()
		for _, name in ipairs(globals) do
			_G[name] = saved[name]
		end
	end)

	describe("IsInCombat", function()
		it("is true when combat lockdown is on, even if the unit is not flagged yet", function()
			_G.InCombatLockdown = function()
				return true
			end
			_G.UnitAffectingCombat = function()
				return false
			end
			assert.is_true(api.IsInCombat())
		end)

		it("is true when the unit is flagged in combat, even without lockdown", function()
			_G.InCombatLockdown = function()
				return false
			end
			_G.UnitAffectingCombat = function()
				return true
			end
			assert.is_true(api.IsInCombat())
		end)

		it("is false when neither is set", function()
			_G.InCombatLockdown = function()
				return false
			end
			_G.UnitAffectingCombat = function()
				return false
			end
			assert.is_false(api.IsInCombat())
		end)

		it("still works on a client without InCombatLockdown", function()
			_G.InCombatLockdown = nil
			_G.UnitAffectingCombat = function()
				return true
			end
			assert.is_true(api.IsInCombat())
		end)
	end)

	describe("IsStealthed", function()
		it("passes a plain result through", function()
			_G.issecretvalue = function()
				return false
			end
			_G.IsStealthed = function()
				return true
			end
			assert.is_true(api.IsStealthed())
			_G.IsStealthed = function()
				return false
			end
			assert.is_false(api.IsStealthed())
		end)

		it("treats a secret result as stealthed, so it is never branched on", function()
			local secret = {}
			_G.issecretvalue = function(value)
				return value == secret
			end
			_G.IsStealthed = function()
				return secret
			end
			assert.is_true(api.IsStealthed())
		end)

		it("works on a client with no secret values at all", function()
			_G.issecretvalue = nil
			_G.IsStealthed = function()
				return false
			end
			assert.is_false(api.IsStealthed())
		end)
	end)

	describe("IsValidEvent", function()
		it("asks C_EventUtils when it exists", function()
			_G.C_EventUtils = {
				IsEventValid = function(event)
					return event == "GOOD"
				end,
			}
			assert.is_true(api.IsValidEvent("GOOD"))
			assert.is_false(api.IsValidEvent("BAD"))
		end)

		it("assumes an event is valid on a client without the check", function()
			_G.C_EventUtils = nil
			assert.is_true(api.IsValidEvent("ANYTHING"))
		end)
	end)

	describe("RegisterCastEndListener", function()
		local frame, fired

		before_each(function()
			frame = { unitEvents = {}, unregistered = 0 }
			function frame:SetScript(name, fn)
				self[name] = fn
			end
			function frame:RegisterUnitEvent(event, unit)
				self.unitEvents[#self.unitEvents + 1] = { event, unit }
			end
			function frame:UnregisterAllEvents()
				self.unregistered = self.unregistered + 1
			end
			_G.CreateFrame = function()
				return frame
			end
			_G.C_EventUtils = {
				IsEventValid = function()
					return true
				end,
			}
			fired = 0
		end)

		it("listens to the player's cast ends only, as unit events", function()
			local listener = api.RegisterCastEndListener(function()
				fired = fired + 1
			end)
			listener.Start()
			assert.are.equal(5, #frame.unitEvents)
			local seen = {}
			for _, entry in ipairs(frame.unitEvents) do
				assert.are.equal("player", entry[2])
				seen[entry[1]] = true
			end
			for _, event in ipairs({
				"UNIT_SPELLCAST_STOP",
				"UNIT_SPELLCAST_SUCCEEDED",
				"UNIT_SPELLCAST_FAILED",
				"UNIT_SPELLCAST_INTERRUPTED",
				"UNIT_SPELLCAST_CHANNEL_STOP",
			}) do
				assert.is_true(seen[event], event)
			end
		end)

		it("calls back when an event arrives", function()
			api.RegisterCastEndListener(function()
				fired = fired + 1
			end)
			frame.OnEvent(frame, "UNIT_SPELLCAST_STOP", "player")
			assert.are.equal(1, fired)
		end)

		it("skips events the client does not have", function()
			_G.C_EventUtils = {
				IsEventValid = function(event)
					return event ~= "UNIT_SPELLCAST_CHANNEL_STOP"
				end,
			}
			local listener = api.RegisterCastEndListener(function() end)
			listener.Start()
			assert.are.equal(4, #frame.unitEvents)
		end)

		it("stops by unregistering everything", function()
			local listener = api.RegisterCastEndListener(function() end)
			listener.Start()
			listener.Stop()
			assert.are.equal(1, frame.unregistered)
		end)
	end)
end)
