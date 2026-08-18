local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("LoggerUI module", function()
	local ns, Logger

	before_each(function()
		require("RPGLootFeed_spec._mocks.Libs.LibStub")
		-- Define the global G_RLF
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)

		-- Load the core Logger module, then LoggerUI.lua on top of it, exactly
		-- like the real load order (Logger.lua then LoggerUI.lua per the .toc).
		-- LoggerUI overrides UpdateContent/InitializeFrame on the same module
		-- object, looking it up via G_RLF.RLF:GetModule(...) just like the real
		-- addon does. The generic embedLibUtil mock stubs GetModule to return
		-- an unrelated blank table, so point it at the real module returned
		-- above -- this is what a real AceAddon-3.0 GetModule call resolves to.
		Logger = assert(loadfile("RPGLootFeed/utils/Logger.lua"))("TestAddon", ns)
		ns.RLF.GetModule = function(_, _name)
			return Logger
		end
		assert(loadfile("RPGLootFeed/utils/LoggerUI.lua"))("TestAddon", ns)

		-- Stub out just enough of an AceGUI frame for UpdateContent to write into,
		-- without going through InitializeFrame's AceGUI widget construction.
		Logger.frame = {
			IsShown = function()
				return true
			end,
			contentBox = {
				text = nil,
				SetText = function(self, text)
					self.text = text
				end,
			},
		}

		-- Real production path for standing up log storage: PLAYER_ENTERING_WORLD
		-- on login, same as Core.lua fires it.
		Logger:PLAYER_ENTERING_WORLD(nil, true, false)
	end)

	describe("event type filter", function()
		it(
			"includes Profession-type log entries by default "
				.. "(regression: LoggerUI's eventType table must be keyed off "
				.. "G_RLF.FeatureModule.Profession's value, not a nonexistent "
				.. "plural 'Professions' FeatureModule key)",
			function()
				-- Real production entry point for adding a log line, exactly as
				-- G_RLF:LogInfo(...) would drive it for a Profession-sourced event.
				Logger:addLogEntry("INFO", "Profession log entry", "TestAddon", ns.FeatureModule.Profession)

				-- Real production method that applies the eventType filter built
				-- by LoggerUI.lua.
				Logger:UpdateContent()

				assert.is_not_nil(Logger.frame.contentBox.text)
				assert.is_true(Logger.frame.contentBox.text:find("Profession log entry", 1, true) ~= nil)
			end
		)
	end)
end)
