local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("General module", function()
	describe("load order", function()
		it("loads after ConfigOptions", function()
			local ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.ConfigOptions)
			local general = assert(loadfile("RPGLootFeed/config/General.lua"))("TestAddon", ns)
			assert.is_not_nil(general, "ConfigOptions should be loaded before General")
		end)
	end)

	local ns
	before_each(function()
		_G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		assert(loadfile("RPGLootFeed/config/General.lua"))("TestAddon", ns)
	end)

	it("creates the general options group at the root", function()
		assert.is_not_nil(ns.options.args.general)
		assert.are.equal("group", ns.options.args.general.type)
		assert.are.equal(1, ns.options.args.general.order)
	end)

	it("has a Quick Actions inline group", function()
		local quickActions = ns.options.args.general.args.quickActions
		assert.is_not_nil(quickActions)
		assert.are.equal("group", quickActions.type)
		assert.is_true(quickActions.inline)
		assert.is_not_nil(quickActions.args.testMode)
		assert.is_not_nil(quickActions.args.clearRows)
		assert.is_not_nil(quickActions.args.lootHistory)
	end)

	it("has global feed behavior toggles", function()
		local args = ns.options.args.general.args
		assert.is_not_nil(args.showMinimapIcon)
		local feedDisplay = args.feedDisplay
		assert.is_not_nil(feedDisplay)
		assert.are.equal("group", feedDisplay.type)
		assert.is_true(feedDisplay.inline)
		assert.is_not_nil(feedDisplay.args.showOneQuantity)
		assert.is_not_nil(feedDisplay.args.hideAllIcons)
	end)

	it("has loot history settings", function()
		local lootHistoryOptions = ns.options.args.general.args.lootHistoryOptions
		assert.is_not_nil(lootHistoryOptions)
		assert.are.equal("group", lootHistoryOptions.type)
		assert.is_true(lootHistoryOptions.inline)
		assert.is_not_nil(lootHistoryOptions.args.enableLootHistory)
		assert.is_not_nil(lootHistoryOptions.args.lootHistorySize)
		assert.is_not_nil(lootHistoryOptions.args.hideLootHistoryTab)
		assert.is_not_nil(lootHistoryOptions.args.tabFreePosition)
		assert.is_not_nil(lootHistoryOptions.args.tabSize)
		assert.is_not_nil(lootHistoryOptions.args.tabXOffset)
		assert.is_not_nil(lootHistoryOptions.args.tabYOffset)
	end)

	it("has tooltip settings", function()
		local tooltipOptions = ns.options.args.general.args.tooltipOptions
		assert.is_not_nil(tooltipOptions)
		assert.are.equal("group", tooltipOptions.type)
		assert.is_true(tooltipOptions.inline)
		assert.is_not_nil(tooltipOptions.args.enableTooltip)
		assert.is_not_nil(tooltipOptions.args.onlyShiftOnEnter)
	end)
end)
