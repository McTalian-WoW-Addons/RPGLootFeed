local assert = require("luassert")
local busted = require("busted")
local spy = busted.spy
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("GameTestRunner", function()
	local ns, GameTestRunner

	before_each(function()
		ns = {}
		assert(loadfile("RPGLootFeed/GameTesting/GameTestRunner.lua"))("TestAddon", ns)
		GameTestRunner = ns.GameTestRunner
	end)

	describe("new", function()
		it("creates a runner with the given suite name", function()
			local runner = GameTestRunner:new("My Suite")
			assert.are.equal("My Suite", runner.suiteName)
		end)

		it("initializes counters to zero", function()
			local runner = GameTestRunner:new("Suite")
			assert.are.equal(0, runner.successCount)
			assert.are.equal(0, runner.failureCount)
			assert.are.equal("", runner.dotSummary)
		end)

		it("uses default IO functions when opts not provided", function()
			local runner = GameTestRunner:new("Suite")
			assert.are.equal(print, runner.printHeader)
			assert.are.equal(print, runner.printLine)
			assert.are.equal(error, runner.raiseError)
		end)

		it("accepts custom IO functions via opts", function()
			local myPrint = function() end
			local myError = function() end
			local runner = GameTestRunner:new("Suite", {
				printHeader = myPrint,
				printLine = myPrint,
				raiseError = myError,
			})
			assert.are.equal(myPrint, runner.printHeader)
			assert.are.equal(myPrint, runner.printLine)
			assert.are.equal(myError, runner.raiseError)
		end)
	end)

	describe("reset", function()
		it("clears all state after assertions have been recorded", function()
			local runner = GameTestRunner:new("Suite")
			runner:assertEqual(1, 1, "pass")
			runner:assertEqual(1, 2, "fail")
			assert.are.equal(1, runner.successCount)
			assert.are.equal(1, runner.failureCount)

			runner:reset()
			assert.are.equal(0, runner.successCount)
			assert.are.equal(0, runner.failureCount)
			assert.are.equal("", runner.dotSummary)
			assert.are.same({}, runner.tests)
			assert.is_nil(runner.currentSection)
		end)
	end)

	describe("section", function()
		it("sets the current section name", function()
			local runner = GameTestRunner:new("Suite", {
				printLine = function() end,
			})
			runner:section("WoW Globals")
			assert.are.equal("WoW Globals", runner.currentSection)
		end)

		it("resets dotSummary for the new section", function()
			local runner = GameTestRunner:new("Suite", {
				printLine = function() end,
			})
			runner:section("First")
			runner:assertEqual(1, 1, "t1")
			assert.is_truthy(#runner.dotSummary > 0)
			runner:section("Second")
			assert.are.equal("", runner.dotSummary)
		end)

		it("flushes previous section dots with label when starting a new section", function()
			local lines = {}
			local runner = GameTestRunner:new("Suite", {
				printLine = function(msg)
					table.insert(lines, msg)
				end,
			})
			runner:section("First")
			runner:assertEqual(1, 1, "t1")
			runner:section("Second")
			assert.are.equal(1, #lines)
			assert.is_truthy(lines[1]:match("^First: "))
		end)

		it("does not flush if previous section had no assertions", function()
			local lines = {}
			local runner = GameTestRunner:new("Suite", {
				printLine = function(msg)
					table.insert(lines, msg)
				end,
			})
			runner:section("Empty")
			runner:section("Second")
			assert.are.equal(0, #lines)
		end)

		it("preserves cumulative success/failure counts across sections", function()
			local runner = GameTestRunner:new("Suite", {
				printLine = function() end,
			})
			runner:section("First")
			runner:assertEqual(1, 1, "pass1")
			runner:assertEqual(1, 2, "fail1")
			runner:section("Second")
			runner:assertEqual(2, 2, "pass2")
			assert.are.equal(2, runner.successCount)
			assert.are.equal(1, runner.failureCount)
		end)
	end)

	describe("assertEqual", function()
		it("records a success when actual equals expected", function()
			local runner = GameTestRunner:new("Suite")
			runner:assertEqual(42, 42, "answer")
			assert.are.equal(1, runner.successCount)
			assert.are.equal(0, runner.failureCount)
			assert.is_true(runner.tests["answer"].result)
		end)

		it("records a failure when actual does not equal expected", function()
			local runner = GameTestRunner:new("Suite")
			runner:assertEqual("a", "b", "mismatch")
			assert.are.equal(0, runner.successCount)
			assert.are.equal(1, runner.failureCount)
			assert.is_false(runner.tests["mismatch"].result)
			assert.are.equal("b", runner.tests["mismatch"].expected)
			assert.are.equal("a", runner.tests["mismatch"].actual)
		end)

		it("stores the error message when provided", function()
			local runner = GameTestRunner:new("Suite")
			runner:assertEqual(false, true, "with error", "something broke")
			assert.are.equal("something broke", runner.tests["with error"].err)
		end)

		it("appends green dot for success", function()
			local runner = GameTestRunner:new("Suite")
			runner:assertEqual(1, 1, "t1")
			assert.are.equal("|cff00ff00•|r", runner.dotSummary)
		end)

		it("appends red x for failure", function()
			local runner = GameTestRunner:new("Suite")
			runner:assertEqual(1, 2, "t1")
			assert.are.equal("|cffff0000x|r", runner.dotSummary)
		end)

		it("accumulates multiple dots", function()
			local runner = GameTestRunner:new("Suite")
			runner:assertEqual(1, 1, "pass1")
			runner:assertEqual(1, 2, "fail1")
			runner:assertEqual(true, true, "pass2")
			assert.are.equal(2, runner.successCount)
			assert.are.equal(1, runner.failureCount)
			assert.are.equal("|cff00ff00•|r|cffff0000x|r|cff00ff00•|r", runner.dotSummary)
		end)
	end)

	describe("runTestSafely", function()
		it("records success when the function does not error", function()
			local runner = GameTestRunner:new("Suite")
			runner:runTestSafely(function()
				return 42
			end, "safe call")
			assert.are.equal(1, runner.successCount)
			assert.are.equal(0, runner.failureCount)
			assert.is_true(runner.tests["safe call"].result)
		end)

		it("records failure with error message when the function errors", function()
			local runner = GameTestRunner:new("Suite")
			runner:runTestSafely(function()
				error("boom")
			end, "exploding call")
			assert.are.equal(0, runner.successCount)
			assert.are.equal(1, runner.failureCount)
			assert.is_false(runner.tests["exploding call"].result)
			assert.is_truthy(runner.tests["exploding call"].err:match("boom"))
		end)

		it("passes varargs to the test function", function()
			local received = {}
			local runner = GameTestRunner:new("Suite")
			runner:runTestSafely(function(a, b, c)
				received = { a, b, c }
			end, "args test", 10, "hello", true)
			assert.are.same({ 10, "hello", true }, received)
		end)
	end)

	describe("record hook", function()
		it("hands the counts and failed assertions to the recorder before raising", function()
			local recorded
			local runner = GameTestRunner:new("Suite", {
				printHeader = function() end,
				printLine = function() end,
				raiseError = function() end,
				record = function(result)
					recorded = result
				end,
			})
			runner:assertEqual(1, 1, "passes")
			runner:assertEqual(1, 2, "fails")
			runner:displayResults()
			assert.are.equal("Suite", recorded.suite)
			assert.are.equal(1, recorded.successes)
			assert.are.equal(1, recorded.failures)
			assert.same({ "fails: expected 2, got 1" }, recorded.failed)
		end)

		it("records even when the failure raises an error", function()
			local recorded
			local runner = GameTestRunner:new("Suite", {
				printHeader = function() end,
				printLine = function() end,
				raiseError = error,
				record = function(result)
					recorded = result
				end,
			})
			runner:assertEqual(1, 2, "fails")
			assert.has_error(function()
				runner:displayResults()
			end)
			assert.are.equal(1, recorded.failures)
		end)

		it("is optional", function()
			local runner = GameTestRunner:new("Suite", {
				printHeader = function() end,
				printLine = function() end,
				raiseError = error,
			})
			runner:assertEqual(1, 1, "ok")
			assert.has_no.errors(function()
				runner:displayResults()
			end)
		end)
	end)

	describe("displayResults", function()
		it("calls printHeader with the suite name", function()
			local headerSpy = spy.new(function() end)
			local lineSpy = spy.new(function() end)
			local runner = GameTestRunner:new("My Tests", {
				printHeader = headerSpy,
				printLine = lineSpy,
				raiseError = error,
			})
			runner:assertEqual(1, 1, "ok")
			runner:displayResults()
			assert.spy(headerSpy).was.called_with("My Tests")
		end)

		it("prints dot summary and success count when no sections used", function()
			local lines = {}
			local lineSpy = spy.new(function(msg)
				table.insert(lines, msg)
			end)
			local runner = GameTestRunner:new("Suite", {
				printHeader = function() end,
				printLine = lineSpy,
				raiseError = error,
			})
			runner:assertEqual(1, 1, "t1")
			runner:assertEqual(2, 2, "t2")
			runner:displayResults()
			-- dots line, then successes line
			assert.is_truthy(lines[1]:match("|cff00ff00"))
			assert.is_truthy(lines[2]:match("Successes: 2"))
		end)

		it("flushes last section and does not print dots line when sections used", function()
			local lines = {}
			local runner = GameTestRunner:new("Suite", {
				printHeader = function() end,
				printLine = function(msg)
					table.insert(lines, msg)
				end,
				raiseError = function() end,
			})
			runner:section("Group A")
			runner:assertEqual(1, 1, "t1")
			runner:section("Group B")
			runner:assertEqual(2, 2, "t2")
			runner:displayResults()
			-- lines: "Group A: •", "Group B: •", "Successes: 2"
			assert.is_truthy(lines[1]:match("^Group A: "))
			assert.is_truthy(lines[2]:match("^Group B: "))
			assert.is_truthy(lines[3]:match("Successes: 2"))
		end)

		it("does not raise error when all tests pass", function()
			local errorSpy = spy.new(function() end)
			local runner = GameTestRunner:new("Suite", {
				printHeader = function() end,
				printLine = function() end,
				raiseError = errorSpy,
			})
			runner:assertEqual(1, 1, "ok")
			runner:displayResults()
			assert.spy(errorSpy).was_not.called()
		end)

		it("raises error with failure details when tests fail", function()
			local errorMsg = nil
			local runner = GameTestRunner:new("Suite", {
				printHeader = function() end,
				printLine = function() end,
				raiseError = function(msg)
					errorMsg = msg
				end,
			})
			runner:assertEqual("got", "want", "bad test")
			runner:displayResults()
			assert.is_not_nil(errorMsg)
			assert.is_truthy(errorMsg:match("bad test"))
			assert.is_truthy(errorMsg:match("want"))
			assert.is_truthy(errorMsg:match("got"))
		end)

		it("includes error message in failure details when present", function()
			local errorMsg = nil
			local runner = GameTestRunner:new("Suite", {
				printHeader = function() end,
				printLine = function() end,
				raiseError = function(msg)
					errorMsg = msg
				end,
			})
			runner:assertEqual(false, true, "err test", "detailed error info")
			runner:displayResults()
			assert.is_truthy(errorMsg:match("detailed error info"))
		end)

		it("prints failure count when there are failures", function()
			local lines = {}
			local runner = GameTestRunner:new("Suite", {
				printHeader = function() end,
				printLine = function(msg)
					table.insert(lines, msg)
				end,
				raiseError = function() end,
			})
			runner:assertEqual(1, 2, "fail1")
			runner:assertEqual(3, 4, "fail2")
			runner:displayResults()
			local found = false
			for _, line in ipairs(lines) do
				if line:match("Failures: 2") then
					found = true
				end
			end
			assert.is_true(found)
		end)
	end)
end)
