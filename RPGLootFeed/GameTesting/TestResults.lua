---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--@alpha@
---@type RLF_TestMode
local TestMode = G_RLF.RLF:GetModule(G_RLF.SupportModule.TestMode) --[[@as RLF_TestMode]]

local MAX_NOTES = 200

--- The results table for one suite, or nil before the DB exists. Kept in the global DB
--- (alpha builds only) so the last run can be read from the SavedVariables file after a
--- /reload, without copying chat output around.
---@param suite string
---@param reset? boolean
---@return table?
local function suiteEntry(suite, reset)
	if not (G_RLF.db and G_RLF.db.global) then
		return nil
	end
	local global = G_RLF.db.global
	global.testResults = global.testResults or {}
	if reset or not global.testResults[suite] then
		local _, build, _, interface = GetBuildInfo()
		global.testResults[suite] = {
			time = date("%Y-%m-%d %H:%M:%S"),
			addonVersion = G_RLF.addonVersion,
			interface = interface,
			build = build,
			notes = {},
		}
	end
	return global.testResults[suite]
end

--- Start a fresh record for a suite; call at the top of a run.
---@param suite string
function TestMode:BeginTestRun(suite)
	suiteEntry(suite, true)
end

--- Print a diagnostic line and keep it with the suite's saved results.
---@param suite string
---@param text string
function TestMode:LogDiagnostic(suite, text)
	G_RLF:Print(text)
	local entry = suiteEntry(suite)
	if entry and #entry.notes < MAX_NOTES then
		table.insert(entry.notes, text)
	end
end

--- Save a finished suite's counts and failed assertions.
---@param result RLF_GameTestResult
function TestMode:RecordTestResult(result)
	local entry = suiteEntry(result.suite)
	if not entry then
		return
	end
	entry.successes = result.successes
	entry.failures = result.failures
	entry.failed = result.failed
end
--@end-alpha@
