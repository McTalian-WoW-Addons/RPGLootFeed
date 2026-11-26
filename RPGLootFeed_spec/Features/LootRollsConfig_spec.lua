local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local before_each = busted.before_each
local spy = busted.spy

describe("LootRollsConfig module", function()
	local ns, refreshed, group

	-- Defaults ported from RPGLootFeed/config/ConfigOptions.lua's
	-- frames["**"].features.lootRolls block.
	local function lootRollsDefaults()
		return {
			enabled = false,
			showRollButtons = true,
			buttonSize = 18,
			buttonGap = 4,
			buttonPadding = 8,
			resultsDisplaySeconds = 60,
			showWaitingCount = true,
			showLeader = true,
			showRollNumbers = true,
			compactWinners = false,
			useClassColors = true,
			winColor = { 0, 1, 0, 1 },
			mutedColor = { 0.6903, 0.6903, 0.6903, 1 },
			showTimerBar = true,
			showRollTooltip = true,
		}
	end

	local function cfg()
		return ns.db.global.frames[1].features.lootRolls
	end

	before_each(function()
		refreshed = 0
		ns = {
			L = setmetatable({}, {
				__index = function(_, key)
					return key
				end,
			}),
			DbAccessor = {
				AllInteractionDisabled = function()
					return false
				end,
				UpdateFeatureModuleState = spy.new(function() end),
			},
			LootDisplay = {
				RefreshSampleRowsIfShown = function()
					refreshed = refreshed + 1
				end,
			},
			db = { global = { frames = { [1] = { features = { lootRolls = lootRollsDefaults() } } } } },
		}
		ns.LootRolls = {}
		assert(loadfile("RPGLootFeed/Features/LootRolls/LootRollsConfig.lua"))("TestAddon", ns)
		group = ns.LootRolls:BuildConfigArgs(1, 10)
	end)

	it("builds an options group at the requested order", function()
		assert.equal("group", group.type)
		assert.equal(10, group.order)
	end)

	it("organizes the options into buttons, results and display groups", function()
		assert.is_table(group.args.buttons)
		assert.is_table(group.args.results)
		assert.is_table(group.args.display)
	end)

	describe("roll buttons", function()
		it("reads the defaults", function()
			local args = group.args.buttons.args
			assert.is_true(args.showRollButtons.get())
			assert.equal(18, args.rollButtonSize.get())
			assert.equal(4, args.rollButtonSpacing.get())
			assert.equal(8, args.rollButtonPadding.get())
		end)

		it("writes the toggle and refreshes the sample rows", function()
			group.args.buttons.args.showRollButtons.set(nil, false)
			assert.is_false(cfg().showRollButtons)
			assert.equal(1, refreshed)
		end)

		it("disables the size, spacing and padding controls when the buttons are hidden", function()
			local args = group.args.buttons.args
			assert.is_false(args.rollButtonSize.disabled())
			cfg().showRollButtons = false
			assert.is_true(args.rollButtonSize.disabled())
			assert.is_true(args.rollButtonSpacing.disabled())
			assert.is_true(args.rollButtonPadding.disabled())
		end)

		it("writes spacing and padding", function()
			local args = group.args.buttons.args
			args.rollButtonSpacing.set(nil, 10)
			args.rollButtonPadding.set(nil, 3)
			assert.equal(10, cfg().buttonGap)
			assert.equal(3, cfg().buttonPadding)
		end)
	end)

	describe("results", function()
		it("treats an unset toggle as on, so older saved settings keep today's behavior", function()
			cfg().showLeader = nil
			assert.is_true(group.args.results.args.showLeader.get())
		end)

		it("compact winners is off by default, unlike the other toggles", function()
			assert.is_false(group.args.results.args.compactWinners.get())
			cfg().compactWinners = nil
			assert.is_false(group.args.results.args.compactWinners.get())
		end)

		it("writes compact winners and refreshes", function()
			group.args.results.args.compactWinners.set(nil, true)
			assert.is_true(cfg().compactWinners)
			assert.is_true(group.args.results.args.compactWinners.get())
			assert.equal(1, refreshed)
		end)

		for _, key in ipairs({ "showWaitingCount", "showLeader", "showRollNumbers", "useClassColors" }) do
			it("writes " .. key .. " and refreshes", function()
				group.args.results.args[key].set(nil, false)
				assert.is_false(cfg()[key])
				assert.equal(1, refreshed)
			end)
		end

		it("reads and writes the colors", function()
			local args = group.args.results.args
			local r, g, b, a = args.winColor.get()
			assert.same({ 0, 1, 0, 1 }, { r, g, b, a })

			args.winColor.set(nil, 1, 0.5, 0.25, 1)
			assert.same({ 1, 0.5, 0.25, 1 }, cfg().winColor)

			args.mutedColor.set(nil, 0.1, 0.2, 0.3, 1)
			assert.same({ 0.1, 0.2, 0.3, 1 }, cfg().mutedColor)
		end)

		it("writes the results display time", function()
			group.args.results.args.resultsDisplaySeconds.set(nil, 30)
			assert.equal(30, cfg().resultsDisplaySeconds)
		end)
	end)

	describe("display", function()
		for _, key in ipairs({ "showTimerBar", "showRollTooltip" }) do
			it("writes " .. key .. " and refreshes", function()
				assert.is_true(group.args.display.args[key].get())
				group.args.display.args[key].set(nil, false)
				assert.is_false(cfg()[key])
				assert.equal(1, refreshed)
			end)
		end
	end)

	it("enabling the feature updates the module state", function()
		group.args.enableLootRolls.set(nil, true)
		assert.is_true(cfg().enabled)
		assert.spy(ns.DbAccessor.UpdateFeatureModuleState).was.called_with(ns.DbAccessor, "lootRolls")
	end)
end)
