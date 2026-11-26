local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local after_each = busted.after_each
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local setup = busted.setup
local spy = busted.spy

describe("AlphaHelpers", function()
	local ns

	setup(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		assert(loadfile("RPGLootFeed/utils/AlphaHelpers.lua"))("TestAddon", ns)
	end)

	describe("dump", function()
		local function parse_dumped_table(dump_string)
			---@diagnostic disable-next-line: undefined-global
			local func, err = load("return " .. dump_string)
			if not func then
				error("Failed to parse dumped table: " .. err)
			end
			return func()
		end

		it("dumps a table to a string", function()
			local t = { key = "value", nested = { 1, 2, 3 } }
			local result = ns.dump(t)

			local parsed = parse_dumped_table(result)

			assert.are.same(parsed, t)
		end)

		it("dumps a non-table value to a string", function()
			local result = ns.dump(123)
			assert.are.equal(result, "123")
		end)
	end)

	describe("ProfileFunction", function()
		local originalProfileStop, clock, printSpy

		--- Make the profiled call appear to take `ms` milliseconds.
		local function profiled(ms)
			clock = 0
			_G.debugprofilestop = function()
				local now = clock
				clock = clock + ms
				return now
			end
			printSpy = spy.on(ns, "Print")
			ns:ProfileFunction(function() end, "testFunc")()
		end

		before_each(function()
			originalProfileStop = _G.debugprofilestop
		end)

		after_each(function()
			_G.debugprofilestop = originalProfileStop
			if printSpy then
				printSpy:revert()
				printSpy = nil
			end
		end)

		it("uses a 17 ms threshold (one frame at 60 fps)", function()
			assert.are.equal(17, ns.PROFILE_THRESHOLD_MS)
		end)

		it("stays quiet for a call that takes about a millisecond", function()
			profiled(1)
			assert.spy(ns.Print).was.not_called()
		end)

		it("stays quiet for a call that takes exactly the threshold", function()
			profiled(17)
			assert.spy(ns.Print).was.not_called()
		end)

		it("prints calls that take longer than the threshold", function()
			profiled(17.5)
			assert.spy(ns.Print).was.called_with(ns, "testFunc took 17.50 ms")
		end)

		it("returns the profiled function's results", function()
			local wrapped = ns:ProfileFunction(function(a, b)
				return a + b, "ok"
			end, "adder")
			local sum, tag = wrapped(2, 3)
			assert.are.equal(5, sum)
			assert.are.equal("ok", tag)
		end)
	end)
end)
