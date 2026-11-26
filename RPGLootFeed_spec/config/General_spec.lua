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

	it("keeps only quick actions and the minimap icon on General", function()
		local args = ns.options.args.general.args
		assert.is_not_nil(args.quickActions)
		assert.is_not_nil(args.showMinimapIcon)
		assert.is_nil(args.feedDisplay)
		assert.is_nil(args.lootHistoryOptions)
		assert.is_nil(args.tooltipOptions)
		assert.is_nil(args.interactionsOptions)
	end)

	it("has a top-level Feed Options page with the feed display toggles", function()
		local feedOptions = ns.options.args.feedOptions
		assert.is_not_nil(feedOptions)
		assert.are.equal("group", feedOptions.type)
		assert.is_nil(feedOptions.inline)
		assert.is_not_nil(feedOptions.args.showOneQuantity)
		assert.is_not_nil(feedOptions.args.hideAllIcons)
	end)

	it("has a Show Bag and Bank Counts toggle on Feed Options", function()
		local toggle = ns.options.args.feedOptions.args.showBagBankCounts
		assert.is_not_nil(toggle)
		assert.are.equal("toggle", toggle.type)

		ns.db.global.misc.showBagBankCounts = false
		ns.LootDisplay = { RefreshSampleRowsIfShown = function() end }
		assert.is_false(toggle.get())
		toggle.set(nil, true)
		assert.is_true(ns.db.global.misc.showBagBankCounts)
		assert.is_true(toggle.get())
	end)

	it("shows an icon legend under the bag and bank toggle only while it is on", function()
		local legend = ns.options.args.feedOptions.args.bagBankCountsLegend
		assert.is_not_nil(legend)
		ns.db.global.misc.showBagBankCounts = false
		assert.is_true(legend.hidden())
		ns.db.global.misc.showBagBankCounts = true
		assert.is_false(legend.hidden())

		ns.WoWAPI = ns.WoWAPI or {}
		ns.WoWAPI.ItemLoot = {
			HasAtlas = function()
				return false
			end,
		}
		local text = legend.name()
		assert.is_truthy(text:find("Icons/BagCount", 1, true))
		assert.is_truthy(text:find("Icons/BankCount", 1, true))
		assert.is_nil(text:find("Warband", 1, true))

		ns.WoWAPI.ItemLoot.HasAtlas = function()
			return true
		end
		ns.WoWAPI.ItemLoot.CreateAtlasMarkup = function(atlas)
			return "<" .. atlas .. ">"
		end
		assert.is_truthy(legend.name():find("<warbands-icon> Warband", 1, true))
	end)

	it("has a top-level Loot History page", function()
		local lootHistory = ns.options.args.lootHistory
		assert.is_not_nil(lootHistory)
		assert.are.equal("group", lootHistory.type)
		assert.is_nil(lootHistory.inline)
		assert.is_not_nil(lootHistory.args.enableLootHistory)
		assert.is_not_nil(lootHistory.args.lootHistorySize)
		assert.is_not_nil(lootHistory.args.hideLootHistoryTab)
		assert.is_not_nil(lootHistory.args.tabFreePosition)
		assert.is_not_nil(lootHistory.args.tabSize)
		assert.is_not_nil(lootHistory.args.tabXOffset)
		assert.is_not_nil(lootHistory.args.tabYOffset)
	end)

	it("has a top-level Tooltip Options page", function()
		local tooltipOptions = ns.options.args.tooltipOptions
		assert.is_not_nil(tooltipOptions)
		assert.are.equal("group", tooltipOptions.type)
		assert.is_nil(tooltipOptions.inline)
		assert.is_not_nil(tooltipOptions.args.enableTooltip)
		assert.is_not_nil(tooltipOptions.args.onlyShiftOnEnter)
	end)

	it("has a top-level Interactions page", function()
		local interactions = ns.options.args.interactions
		assert.is_not_nil(interactions)
		assert.are.equal("group", interactions.type)
		assert.is_nil(interactions.inline)
		assert.is_not_nil(interactions.args.disableAllInteraction)
		assert.is_not_nil(interactions.args.disableMouseInCombat)
		assert.is_not_nil(interactions.args.pinOnHover)
		assert.is_not_nil(interactions.args.itemClicks)
		assert.is_not_nil(interactions.args.rightClickDismiss)
		assert.is_not_nil(interactions.args.rollButtons)
	end)

	it("orders the split pages right after General", function()
		local args = ns.options.args
		local orders = {
			args.general.order,
			args.feedOptions.order,
			args.lootHistory.order,
			args.tooltipOptions.order,
			args.interactions.order,
		}
		for i = 2, #orders do
			assert.is_true(orders[i] > orders[i - 1], "page " .. i .. " should sort after page " .. (i - 1))
		end
		-- ...and before the Blizzard UI page (order 2) and the frame pages (10+).
		assert.is_true(args.interactions.order < 2)
	end)
end)
