local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local after_each = busted.after_each
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("WoWAPI.ItemLoot.ItemTypeUnusable", function()
	local ns, originalTooltipInfo, originalPlaceholder
	local RED = { r = 1, g = 0.1, b = 0.1 }
	local WHITE = { r = 1, g = 1, b = 1 }

	before_each(function()
		originalTooltipInfo, originalPlaceholder = _G.C_TooltipInfo, _G.RETRIEVING_ITEM_INFO
		_G.RETRIEVING_ITEM_INFO = "Retrieving item information"
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		ns.WoWAPI = nil
		assert(loadfile("RPGLootFeed/utils/WoWAPIAdapters.lua"))("TestAddon", ns)
	end)

	after_each(function()
		_G.C_TooltipInfo, _G.RETRIEVING_ITEM_INFO = originalTooltipInfo, originalPlaceholder
	end)

	local function tooltip(lines)
		_G.C_TooltipInfo = {
			GetHyperlink = function()
				return { lines = lines }
			end,
		}
	end

	it("is true when the type text in the right column is red", function()
		tooltip({
			{ leftText = "Worn Mace", leftColor = WHITE },
			{ leftText = "Main Hand", leftColor = RED, rightText = "Mace", rightColor = RED },
		})
		assert.is_true(ns.WoWAPI.ItemLoot.ItemTypeUnusable("item:36"))
	end)

	it("is true for an armor type shown red next to a level requirement", function()
		tooltip({
			{ leftText = "Coif", leftColor = WHITE },
			{ leftText = "Head", leftColor = WHITE, rightText = "Mail", rightColor = RED },
			{ leftText = "Requires Level 57", leftColor = RED },
		})
		assert.is_true(ns.WoWAPI.ItemLoot.ItemTypeUnusable("item:16667"))
	end)

	it("ignores a red requirement in the left column, such as a level", function()
		tooltip({
			{ leftText = "Arcanist Bindings", leftColor = WHITE },
			{ leftText = "Wrist", leftColor = WHITE, rightText = "Cloth", rightColor = WHITE },
			{ leftText = "Requires Level 60", leftColor = RED },
		})
		assert.is_false(ns.WoWAPI.ItemLoot.ItemTypeUnusable("item:16799"))
	end)

	it("is false for a usable item with no red lines", function()
		tooltip({
			{ leftText = "Worn Shortsword", leftColor = WHITE },
			{ leftText = "Main Hand", leftColor = WHITE, rightText = "Sword", rightColor = WHITE },
		})
		assert.is_false(ns.WoWAPI.ItemLoot.ItemTypeUnusable("item:25"))
	end)

	it("is nil while the tooltip is the loading placeholder", function()
		tooltip({ { leftText = "Retrieving item information", leftColor = RED } })
		assert.is_nil(ns.WoWAPI.ItemLoot.ItemTypeUnusable("item:36"))
	end)

	it("is nil when the tooltip has no lines", function()
		tooltip({})
		assert.is_nil(ns.WoWAPI.ItemLoot.ItemTypeUnusable("item:36"))
	end)
end)
