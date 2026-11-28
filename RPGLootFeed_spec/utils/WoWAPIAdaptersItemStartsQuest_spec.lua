local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local after_each = busted.after_each
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("WoWAPI.ItemLoot.ItemStartsQuest", function()
	local ns, originalTooltipInfo, originalString, originalCItem

	before_each(function()
		originalTooltipInfo, originalString, originalCItem = _G.C_TooltipInfo, _G.ITEM_STARTS_QUEST, _G.C_Item
		_G.ITEM_STARTS_QUEST = "This Item Begins a Quest"
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		ns.WoWAPI = nil
		assert(loadfile("RPGLootFeed/utils/WoWAPIAdapters.lua"))("TestAddon", ns)
	end)

	after_each(function()
		_G.C_TooltipInfo, _G.ITEM_STARTS_QUEST, _G.C_Item = originalTooltipInfo, originalString, originalCItem
	end)

	local function tooltipWith(lines)
		_G.C_TooltipInfo = {
			GetHyperlink = function()
				local data = { lines = {} }
				for i, text in ipairs(lines) do
					data.lines[i] = { leftText = text }
				end
				return data
			end,
		}
	end

	it("is true when a tooltip line is the quest-start text", function()
		tooltipWith({ "Letter", "Use: Read", "This Item Begins a Quest" })
		assert.is_true(ns.WoWAPI.ItemLoot.ItemStartsQuest("link"))
	end)

	it("is false for a tooltip without the line", function()
		tooltipWith({ "Letter", "Use: Read" })
		assert.is_false(ns.WoWAPI.ItemLoot.ItemStartsQuest("link"))
	end)

	it("is nil while the tooltip has no lines yet", function()
		tooltipWith({})
		assert.is_nil(ns.WoWAPI.ItemLoot.ItemStartsQuest("link"))
	end)

	it("is nil, and requests the item, while the item data is not cached", function()
		local requested
		_G.C_Item = {
			IsItemDataCachedByID = function()
				return false
			end,
			RequestLoadItemDataByID = function(id)
				requested = id
			end,
		}
		tooltipWith({ "Head of Onyxia" }) -- a partial tooltip must not read as "false"
		assert.is_nil(ns.WoWAPI.ItemLoot.ItemStartsQuest("item:18423"))
		assert.equal(18423, requested)
	end)

	it("reads the tooltip once the item data is cached", function()
		_G.C_Item = {
			IsItemDataCachedByID = function()
				return true
			end,
		}
		tooltipWith({ "Head of Onyxia", "This Item Begins a Quest" })
		assert.is_true(ns.WoWAPI.ItemLoot.ItemStartsQuest("item:18423"))
	end)

	it("is false when the client has no such global string", function()
		_G.ITEM_STARTS_QUEST = nil
		tooltipWith({ "This Item Begins a Quest" })
		assert.is_false(ns.WoWAPI.ItemLoot.ItemStartsQuest("link"))
	end)
end)
