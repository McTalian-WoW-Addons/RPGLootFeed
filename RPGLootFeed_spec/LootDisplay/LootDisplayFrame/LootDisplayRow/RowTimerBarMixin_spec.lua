local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local rowFrameMocks = require("RPGLootFeed_spec._mocks.Internal.LootDisplayRowFrame")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local after_each = busted.after_each
local describe = busted.describe
local it = busted.it

local MIXIN_FILE = "RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayRow/RowTimerBarMixin.lua"

describe("RLF_RowTimerBarMixin", function()
	local ns, row
	--- Tracks the TimerBar's visibility the way the real StatusBar would.
	--- Seeded to true in before_each to model the XML-created state of a
	--- brand-new (never-recycled) row.
	local timerBarShown
	local styleCalls
	local subscribeCalls
	local originalDurationUtil
	local originalGetTime

	before_each(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		assert(loadfile(MIXIN_FILE))("TestAddon", ns)

		-- Mock NewTimerBarCoordinator so StartTimerBar can subscribe without
		-- needing TimerBarCoordinator.lua loaded
		subscribeCalls = {}
		ns.TimerBarCoordinator = nil
		ns.NewTimerBarCoordinator = function()
			return {
				Subscribe = function(_, _, duration, hideOnly)
					table.insert(subscribeCalls, { duration = duration, hideOnly = hideOnly })
				end,
				Unsubscribe = function() end,
			}
		end

		row = rowFrameMocks.new()
		for k, v in pairs(RLF_RowTimerBarMixin) do
			row[k] = v
		end
		row.frameType = ns.Frames.MAIN

		-- Mock TimerBar StatusBar. Starts shown to mirror RowTimerBar.xml's
		-- freshly created state before anything hides it.
		timerBarShown = true
		styleCalls = {}
		row.TimerBar = {
			Show = function()
				timerBarShown = true
			end,
			Hide = function()
				timerBarShown = false
			end,
			SetHeight = function(_, h)
				styleCalls.height = h
			end,
			GetWidth = function()
				return 100
			end,
			SetStatusBarColor = function(_, r, g, b, a)
				styleCalls.color = { r, g, b, a }
			end,
			SetMinMaxValues = function() end,
			SetValue = function() end,
			SetFillStyle = function(_, direction)
				styleCalls.fillStyle = direction
			end,
			SetTimerDuration = function() end,
			IsVisible = function()
				return timerBarShown
			end,
			ClearAllPoints = function() end,
			SetPoint = function() end,
		}

		stub(ns.DbAccessor, "Animations").returns({
			timerBar = {
				enabled = true,
				height = 2,
				color = { 0.5, 0.5, 0.5 },
				alpha = 0.7,
				drainDirection = "REVERSE",
			},
			exit = {
				disable = false,
			},
		})

		originalDurationUtil = _G.C_DurationUtil
		originalGetTime = _G.GetTime
		_G.C_DurationUtil = nil
	end)

	after_each(function()
		_G.C_DurationUtil = originalDurationUtil
		_G.GetTime = originalGetTime
	end)

	--- Install a C_DurationUtil stub so StartTimerBar takes the native path.
	local function withNativeDuration()
		local applied = {}
		_G.GetTime = _G.GetTime or function()
			return 0
		end
		_G.C_DurationUtil = {
			CreateDuration = function()
				return {
					SetTimeFromStart = function(_, start, duration)
						applied.start, applied.duration = start, duration
					end,
				}
			end,
		}
		row.TimerBar.SetTimerDuration = function()
			applied.setTimerDuration = true
		end
		return applied
	end

	describe("StyleTimerBar", function()
		it("applies styling without errors", function()
			assert.has_no.errors(function()
				row:StyleTimerBar()
			end)
		end)

		it("applies height, color and drain direction when enabled", function()
			row:StyleTimerBar()
			assert.are.equal(2, styleCalls.height)
			assert.are.same({ 0.5, 0.5, 0.5, 0.7 }, styleCalls.color)
			-- "Right to Left" empties from the right edge, which is a Standard
			-- (left-anchored) fill -- not the same-named Reverse enum value.
			assert.are.equal(Enum.StatusBarFillStyle.Standard, styleCalls.fillStyle)
		end)

		-- Regression: the config's "NORMAL" is not a StatusBarFillStyle, so
		-- passing drainDirection straight to SetFillStyle errored inside the
		-- widget for anyone who picked "Left to Right".
		it("maps the left-to-right option to a valid fill style", function()
			stub(ns.DbAccessor, "Animations").returns({
				timerBar = { enabled = true, drainDirection = "NORMAL" },
				exit = { disable = false },
			})

			assert.has_no.errors(function()
				row:StyleTimerBar()
			end)
			assert.are.equal(Enum.StatusBarFillStyle.Reverse, styleCalls.fillStyle)
		end)

		it("skips SetFillStyle for an unrecognized drain direction", function()
			stub(ns.DbAccessor, "Animations").returns({
				timerBar = { enabled = true, drainDirection = "SIDEWAYS" },
				exit = { disable = false },
			})

			row:StyleTimerBar()

			assert.is_nil(styleCalls.fillStyle)
		end)

		-- Regression: issue #597. A newly created row's TimerBar is shown by the
		-- XML template; styling used to leave it that way when the feature was
		-- off, producing a grey bar until StartTimerBar eventually hid it.
		it("hides the bar when the timer bar is disabled", function()
			stub(ns.DbAccessor, "Animations").returns({
				timerBar = { enabled = false, height = 2, color = { 0.5, 0.5, 0.5 }, alpha = 0.7 },
				exit = { disable = false },
			})

			row:StyleTimerBar()

			assert.is_false(timerBarShown)
		end)

		it("does not resize a disabled bar", function()
			stub(ns.DbAccessor, "Animations").returns({
				timerBar = { enabled = false, height = 8 },
				exit = { disable = false },
			})

			row:StyleTimerBar()

			assert.is_nil(styleCalls.height)
		end)

		it("handles a missing timer bar config table", function()
			stub(ns.DbAccessor, "Animations").returns({
				timerBar = nil,
			})

			assert.has_no.errors(function()
				row:StyleTimerBar()
			end)
			assert.is_false(timerBarShown)
		end)

		it("never shows the bar on its own, even when enabled", function()
			timerBarShown = false

			row:StyleTimerBar()

			assert.is_false(timerBarShown)
		end)
	end)

	describe("ShouldShowTimerBar", function()
		it("returns false for history mode", function()
			row.isHistoryMode = true
			row.isSampleRow = false
			local result = row:ShouldShowTimerBar()
			assert.is_false(result)
		end)

		it("returns true for enabled normal rows", function()
			row.isHistoryMode = false
			row.isSampleRow = false
			local result = row:ShouldShowTimerBar()
			assert.is_true(result)
		end)

		it("returns false when exit is disabled", function()
			stub(ns.DbAccessor, "Animations").returns({
				timerBar = { enabled = true },
				exit = { disable = true },
			})
			row.isSampleRow = false
			row.isHistoryMode = false

			local result = row:ShouldShowTimerBar()
			assert.is_false(result)
		end)

		it("returns false when timer bar is disabled", function()
			stub(ns.DbAccessor, "Animations").returns({
				timerBar = { enabled = false },
				exit = { disable = false },
			})
			row.isSampleRow = false
			row.isHistoryMode = false

			local result = row:ShouldShowTimerBar()
			assert.is_false(result)
		end)

		it("returns false when TimerBar is nil", function()
			row.TimerBar = nil
			local result = row:ShouldShowTimerBar()
			assert.is_false(result)
		end)

		it("returns a boolean, not the raw config value, for sample rows", function()
			stub(ns.DbAccessor, "Animations").returns({
				timerBar = { enabled = false },
				exit = { disable = false },
			})
			row.isSampleRow = true
			row.isHistoryMode = false

			assert.is_false(row:ShouldShowTimerBar())
		end)
	end)

	describe("StartTimerBar", function()
		it("executes without errors", function()
			row.showForSeconds = 5
			assert.has_no.errors(function()
				row:StartTimerBar()
			end)
		end)

		it("shows the bar when enabled", function()
			timerBarShown = false
			row.showForSeconds = 5

			row:StartTimerBar()

			assert.is_true(timerBarShown)
		end)

		it("hides the bar instead of showing it when disabled", function()
			stub(ns.DbAccessor, "Animations").returns({
				timerBar = { enabled = false },
				exit = { disable = false },
			})
			row.showForSeconds = 5

			row:StartTimerBar()

			assert.is_false(timerBarShown)
		end)

		it("subscribes to the coordinator to drive the value with no native duration", function()
			row.showForSeconds = 7

			row:StartTimerBar()

			assert.are.equal(1, #subscribeCalls)
			assert.are.equal(7, subscribeCalls[1].duration)
			assert.is_false(subscribeCalls[1].hideOnly)
		end)

		-- C_DurationUtil animates the bar but never signals completion, so the
		-- coordinator has to stay subscribed as a completion watchdog or the
		-- drained background track lingers through the whole fade-out.
		it("still subscribes as a watchdog when a native duration drives the bar", function()
			local applied = withNativeDuration()
			row.showForSeconds = 7

			row:StartTimerBar()

			assert.is_true(applied.setTimerDuration)
			assert.are.equal(7, applied.duration)
			assert.are.equal(1, #subscribeCalls)
			assert.are.equal(7, subscribeCalls[1].duration)
			assert.is_true(subscribeCalls[1].hideOnly)
		end)
	end)

	describe("StopTimerBar", function()
		it("executes without errors", function()
			assert.has_no.errors(function()
				row:StopTimerBar()
			end)
		end)

		it("hides the bar", function()
			row:StopTimerBar()
			assert.is_false(timerBarShown)
		end)
	end)

	describe("ResetTimerBar", function()
		it("executes without errors", function()
			assert.has_no.errors(function()
				row:ResetTimerBar()
			end)
		end)

		it("clears duration reference", function()
			row._timerBarDuration = { some = "object" }
			row:ResetTimerBar()
			assert.is_nil(row._timerBarDuration)
		end)

		it("hides the bar", function()
			row:ResetTimerBar()
			assert.is_false(timerBarShown)
		end)
	end)
end)
