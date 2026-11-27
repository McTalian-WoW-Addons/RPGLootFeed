---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_GameTestResult
---@field suite string
---@field successes number
---@field failures number
---@field failed string[] One "name: expected X, got Y" entry per failed assertion

--- Lightweight test runner for in-game smoke and integration tests.
--- Pure Lua logic — no WoW API dependencies — so it can be busted-tested.
---@class RLF_GameTestRunner
---@field suiteName string
---@field tests table<string, {result: boolean, expected: any, actual: any, err: string?}>
---@field dotSummary string
---@field successCount number
---@field failureCount number
---@field currentSection string?
---@field printHeader fun(msg: string)
---@field printLine fun(msg: string)
---@field raiseError fun(msg: string)
local GameTestRunner = {}
GameTestRunner.__index = GameTestRunner

--- Create a new test runner instance.
---@param suiteName string The name of the test suite (e.g., "Smoke Test")
---@param opts? {printHeader: fun(msg: string), printLine: fun(msg: string), raiseError: fun(msg: string), record: fun(result: RLF_GameTestResult)}
---@return RLF_GameTestRunner
function GameTestRunner:new(suiteName, opts)
	opts = opts or {}
	local instance = setmetatable({}, self)
	instance.suiteName = suiteName
	instance.printHeader = opts.printHeader or print
	instance.printLine = opts.printLine or print
	instance.raiseError = opts.raiseError or error
	instance.record = opts.record
	instance:reset()
	return instance
end

function GameTestRunner:reset()
	self.tests = {}
	self.dotSummary = ""
	self.successCount = 0
	self.failureCount = 0
	self.currentSection = nil
end

--- Start a named section. Flushes the previous section's dots (if any) and prints a label.
---@param name string
function GameTestRunner:section(name)
	if self.currentSection and #self.dotSummary > 0 then
		self.printLine(self.currentSection .. ": " .. self.dotSummary)
	end
	self.dotSummary = ""
	self.currentSection = name
end

--- Record an equality assertion.
---@param actual any
---@param expected any
---@param testName string
---@param err? string
function GameTestRunner:assertEqual(actual, expected, testName, err)
	self.tests[testName] = {
		result = actual == expected,
		expected = expected,
		actual = actual,
		err = err,
	}
	if actual == expected then
		self.dotSummary = self.dotSummary .. "|cff00ff00•|r"
		self.successCount = self.successCount + 1
	else
		self.dotSummary = self.dotSummary .. "|cffff0000x|r"
		self.failureCount = self.failureCount + 1
	end
end

--- Run a function inside pcall and record pass/fail.
---@param testFunction function
---@param testName string
---@param ... any
function GameTestRunner:runTestSafely(testFunction, testName, ...)
	local success, err = pcall(testFunction, ...)
	self:assertEqual(success, true, testName, err)
end

--- Print the dot summary, counts, and raise an error listing all failures.
function GameTestRunner:displayResults()
	-- Flush the last section's dots if sections were used
	if self.currentSection and #self.dotSummary > 0 then
		self.printLine(self.currentSection .. ": " .. self.dotSummary)
		self.dotSummary = ""
	end

	self.printHeader(self.suiteName)
	-- If no sections were used, print the accumulated dots in one line
	if not self.currentSection and #self.dotSummary > 0 then
		self.printLine(self.dotSummary)
	end
	self.printLine("|cff00ff00Successes: " .. self.successCount .. "|r")
	if self.failureCount > 0 then
		self.printLine("|cffff0000Failures: " .. self.failureCount .. "|r")
	end

	-- Hand the outcome to the recorder (if any) before a failure raises, so a run that
	-- errors out is still captured.
	if self.record then
		local failed = {}
		for testName, testData in pairs(self.tests) do
			if not testData.result then
				table.insert(
					failed,
					testName
						.. ": expected "
						.. tostring(testData.expected)
						.. ", got "
						.. tostring(testData.actual)
						.. (testData.err and (" (" .. tostring(testData.err) .. ")") or "")
				)
			end
		end
		table.sort(failed)
		self.record({
			suite = self.suiteName,
			successes = self.successCount,
			failures = self.failureCount,
			failed = failed,
		})
	end

	local msg = ""
	for testName, testData in pairs(self.tests) do
		if not testData.result then
			msg = msg
				.. "|cffff0000Failure: "
				.. testName
				.. " failed: expected "
				.. tostring(testData.expected)
				.. ", got "
				.. tostring(testData.actual)
			if testData.err then
				msg = msg .. " Error: " .. testData.err
			end
			msg = msg .. "|r|n\n"
		end
	end

	if self.failureCount > 0 then
		self.raiseError(msg)
	end
end

G_RLF.GameTestRunner = GameTestRunner
