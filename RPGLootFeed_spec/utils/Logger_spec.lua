local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local match = require("luassert.match")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local spy = busted.spy

describe("Logger module", function()
	local ns, Logger
	local _ = match._

	before_each(function()
		require("RPGLootFeed_spec._mocks.Libs.LibStub")
		-- Define the global G_RLF
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		ns.db.global.logger = {
			{
				timestamp = "2023-01-01 12:00:00",
				level = "INFO",
				source = "TestAddon",
				type = "General",
				id = "",
				content = "",
				amount = "",
				new = true,
				message = "Test log entry",
			},
			{
				timestamp = "2023-01-01 12:00:01",
				level = "INFO",
				source = "TestAddon",
				type = "General",
				id = "",
				content = "",
				amount = "",
				new = true,
				message = "Test log entry 2",
			},
			{
				timestamp = "2023-01-01 12:00:02",
				level = "INFO",
				source = "TestAddon",
				type = "General",
				id = "",
				content = "",
				amount = "",
				new = true,
				message = "Test log entry 3",
			},
		}

		-- Load the module before each test
		Logger = assert(loadfile("RPGLootFeed/utils/Logger.lua"))("TestAddon", ns)
	end)

	describe("addon initialization", function()
		it("initializes the logger", function()
			spy.on(Logger, "RegisterEvent")
			spy.on(Logger, "RegisterBucketMessage")
			spy.on(Logger, "InitializeFrame")
			Logger:OnInitialize()
			assert.spy(Logger.RegisterEvent).was.called_with(_, "PLAYER_ENTERING_WORLD")
			assert.spy(Logger.RegisterBucketMessage).was.called_with(_, "RLF_LOG", 0.5, "ProcessLogs")
			assert.spy(Logger.InitializeFrame).was.called(1)
		end)

		it("resets logger on login", function()
			Logger:PLAYER_ENTERING_WORLD(nil, true, false)
			assert.are.equal(#ns.db.global.logger, 0)
		end)
	end)

	describe("logging functionality", function()
		before_each(function()
			Logger:OnInitialize()
			Logger:PLAYER_ENTERING_WORLD(nil, true, false)
		end)

		it("adds a log entry", function()
			local logEntry = {
				timestamp = "2023-01-01 12:00:00",
				level = "INFO",
				source = "TestAddon",
				type = "General",
				id = "",
				content = "",
				amount = "",
				new = true,
				message = "Test log entry",
			}
			Logger:ProcessLogs({
				[{
					logEntry.level,
					logEntry.message,
					logEntry.source,
					logEntry.type,
					logEntry.id,
					logEntry.content,
					logEntry.amount,
					logEntry.new,
				}] = 1,
			})
			assert.are.equal(#ns.db.global.logger, 1)
			assert.are.same(ns.db.global.logger[1], logEntry)
		end)

		it("formats log entries correctly", function()
			local logEntry = {
				timestamp = "2023-01-01 12:00:00",
				level = "INFO",
				source = "TestAddon",
				type = "General",
				id = "",
				content = "",
				amount = "",
				new = true,
				message = "Test log entry",
			}
			local formattedEntry = Logger:FormatLogEntry(logEntry)
			assert.are.equal(formattedEntry, "[|cFF80808012:00:00|r]|cFFADD8E6{I}|r(TestAddon): Test log entry\n")
		end)

		it("hides the frame if it is already shown", function()
			local frameVisible = false
			Logger.frame = {
				IsShown = function()
					return frameVisible
				end,
				Show = function()
					frameVisible = true
				end,
				Hide = function()
					frameVisible = false
				end,
			}
			Logger:Show()
			spy.on(Logger, "Hide")
			Logger:Show()
			assert.spy(Logger.Hide).was.called(1)
		end)
	end)
end)
