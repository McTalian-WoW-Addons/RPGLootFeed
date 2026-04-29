local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local rowFrameMocks = require("RPGLootFeed_spec._mocks.Internal.LootDisplayRowFrame")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

local MIXIN_FILE = "RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayRow/RowTimerBarMixin.lua"

describe("RLF_RowTimerBarMixin", function()
	local ns, row

	before_each(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		assert(loadfile(MIXIN_FILE))("TestAddon", ns)

		-- Mock NewTimerBarCoordinator so StartTimerBar's Classic path works
		-- without needing TimerBarCoordinator.lua loaded
		ns.NewTimerBarCoordinator = function()
			return {
				Subscribe = function() end,
				Unsubscribe = function() end,
			}
		end

		row = rowFrameMocks.new()
		for k, v in pairs(RLF_RowTimerBarMixin) do
			row[k] = v
		end
		row.frameType = ns.Frames.MAIN

		-- Mock TimerBar StatusBar
		row.TimerBar = {
			Show = function() end,
			Hide = function() end,
			SetHeight = function() end,
			GetWidth = function()
				return 100
			end,
			SetStatusBarColor = function() end,
			SetMinMaxValues = function() end,
			SetValue = function() end,
			SetFillStyle = function() end,
			IsVisible = function()
				return true
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
	end)

	describe("StyleTimerBar", function()
		it("applies styling without errors", function()
			assert.has_no.errors(function()
				row:StyleTimerBar()
			end)
		end)

		it("handles disabled config", function()
			stub(ns.DbAccessor, "Animations").returns({
				timerBar = nil,
			})

			assert.has_no.errors(function()
				row:StyleTimerBar()
			end)
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
	end)

	describe("StartTimerBar", function()
		it("executes without errors", function()
			row.showForSeconds = 5
			assert.has_no.errors(function()
				row:StartTimerBar()
			end)
		end)
	end)

	describe("StopTimerBar", function()
		it("executes without errors", function()
			assert.has_no.errors(function()
				row:StopTimerBar()
			end)
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
	end)
end)
