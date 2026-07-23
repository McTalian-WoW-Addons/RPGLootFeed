local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("ItemInfo", function()
	---@type test_G_RLF, RLF_ItemInfo
	local ns, ItemInfo
	local itemMocks, functionMocks

	before_each(function()
		functionMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.Functions")
		itemMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.namespaces.C_Item")
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)

		-- Provide color helpers
		if nsMocks.RGBAToHexFormat then
			nsMocks.RGBAToHexFormat.returns("|cFFFFFFFF")
		end
		-- Tertiary strings used by Maps
		_G["ITEM_MOD_CR_SPEED_SHORT"] = "Speed"
		_G["ITEM_MOD_CR_LIFESTEAL_SHORT"] = "Leech"
		_G["ITEM_MOD_CR_AVOIDANCE_SHORT"] = "Avoidance"
		_G["ITEM_MOD_CR_STURDINESS_SHORT"] = "Indestructible"
		ns.tertiaryToString = {
			[ns.TertiaryStats.Speed] = _G["ITEM_MOD_CR_SPEED_SHORT"],
			[ns.TertiaryStats.Leech] = _G["ITEM_MOD_CR_LIFESTEAL_SHORT"],
			[ns.TertiaryStats.Avoid] = _G["ITEM_MOD_CR_AVOIDANCE_SHORT"],
			[ns.TertiaryStats.Indestructible] = _G["ITEM_MOD_CR_STURDINESS_SHORT"],
		}

		assert(loadfile("RPGLootFeed/utils/ItemInfo.lua"))("TestAddon", ns)
		assert(loadfile("RPGLootFeed/utils/ItemInfoKeystone.lua"))("TestAddon", ns)
		---@type RLF_ItemInfo
		ItemInfo = ns.ItemInfo
	end)

	describe("new", function()
		it("creates a new ItemInfo instance", function()
			local item = ItemInfo:new(
				18803,
				"Test Item",
				"itemLink",
				2,
				10,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_WEAPON",
				"texture",
				100,
				2,
				1,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.are.equal(item.itemId, 18803)
			assert.are.equal(item.itemName, "Test Item")
		end)

		it("returns nil if itemName is not provided", function()
			local item = ItemInfo:new(
				18803,
				nil,
				"itemLink",
				2,
				10,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_WEAPON",
				"texture",
				100,
				2,
				1,
				1,
				1,
				1,
				false
			)
			assert.is_nil(item)
		end)

		it("retrieves the item ID if not provided", function()
			local item = ItemInfo:new(
				nil,
				"Test Item",
				"itemLink",
				2,
				10,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_WEAPON",
				"texture",
				100,
				2,
				1,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.are.equal(item.itemId, 18803)
		end)
	end)

	describe("IsMount", function()
		it("checks if an item is a mount", function()
			local item = ItemInfo:new(
				18803,
				"Test Mount",
				"itemLink",
				2,
				10,
				1,
				"Miscellaneous",
				"Mount",
				1,
				"INVTYPE_WEAPON",
				"texture",
				100,
				15,
				5,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.is_true(item:IsMount())
		end)

		it("checks if an item is not a mount", function()
			local item = ItemInfo:new(
				18803,
				"Test Item",
				"itemLink",
				2,
				10,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_WEAPON",
				"texture",
				100,
				2,
				1,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.is_false(item:IsMount())
		end)
	end)

	describe("IsQuestItem", function()
		it("checks if an item is a quest item", function()
			local item = ItemInfo:new(
				18803,
				"Test Quest Item",
				"itemLink",
				2,
				10,
				1,
				"Quest",
				"Item",
				1,
				"INVTYPE_QUEST",
				"texture",
				100,
				12,
				0,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.is_true(item:IsQuestItem())
		end)

		it("checks if an item is not a quest item", function()
			local item = ItemInfo:new(
				18803,
				"Test Item",
				"itemLink",
				2,
				10,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_WEAPON",
				"texture",
				100,
				2,
				1,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.is_false(item:IsQuestItem())
		end)
	end)

	-- IsAppearanceCollected tests moved to ItemInfoTransmog_spec.lua

	describe("IsLegendary", function()
		it("checks if an item is legendary", function()
			local item = ItemInfo:new(
				18803,
				"Test Legendary",
				"itemLink",
				5,
				10,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_WEAPON",
				"texture",
				100,
				2,
				1,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.is_true(item:IsLegendary())
		end)

		it("checks if an item is not legendary", function()
			local item = ItemInfo:new(
				18803,
				"Test Item",
				"itemLink",
				2,
				10,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_WEAPON",
				"texture",
				100,
				2,
				1,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.is_false(item:IsLegendary())
		end)
	end)

	describe("Item rolls", function()
		it("returns default rolls when no tertiary/sockets present", function()
			itemMocks.GetItemStats.returns(nil)
			local item = ItemInfo:new(
				18803,
				"Test Item",
				"itemLink",
				2,
				10,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_WEAPON",
				"texture",
				100,
				2,
				1,
				1,
				1,
				1,
				false
			)
			if not item then
				return
			end
			local rolls = item:getItemRolls()
			assert.are.equal(rolls.tertiaryStat, ns.TertiaryStats.None)
			assert.is_false(rolls.isSocketed)
			assert.is_false(rolls.isIndestructible)
			assert.are.equal(rolls.numSockets, 0)
			assert.are.equal(rolls.socketString, "")
		end)

		it("detects tertiary stat (Leech)", function()
			itemMocks.GetItemStats.returns({ ["ITEM_MOD_CR_LIFESTEAL_SHORT"] = 1 })
			local item = ItemInfo:new(
				18803,
				"Test Item",
				"itemLink",
				2,
				10,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_WEAPON",
				"texture",
				100,
				2,
				1,
				1,
				1,
				1,
				false
			)
			if not item then
				return
			end
			assert.are.equal(item:getItemRolls().tertiaryStat, ns.TertiaryStats.Leech)
		end)

		it("detects indestructible", function()
			itemMocks.GetItemStats.returns({ ["ITEM_MOD_CR_STURDINESS_SHORT"] = 1 })
			local item = ItemInfo:new(
				18803,
				"Test Item",
				"itemLink",
				2,
				10,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_WEAPON",
				"texture",
				100,
				2,
				1,
				1,
				1,
				1,
				false
			)
			if not item then
				return
			end
			assert.is_true(item:HasItemRollBonus())
			assert.is_true(item:getItemRolls().isIndestructible)
		end)

		it("detects sockets and formats count and label", function()
			itemMocks.GetItemStats.returns({ ["EMPTY_SOCKET_PRISMATIC"] = 2 })
			local item = ItemInfo:new(
				18803,
				"Test Item",
				"itemLink",
				2,
				10,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_WEAPON",
				"texture",
				100,
				2,
				1,
				1,
				1,
				1,
				false
			)
			if not item then
				return
			end
			assert.is_true(item:getItemRolls().isSocketed)
			assert.are.equal(item:getItemRolls().numSockets, 2)
		end)
	end)
end)
