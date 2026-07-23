local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("ItemInfoTransmog", function()
	local ns, ItemInfo

	local functionMocks, transmogCollectionMocks

	before_each(function()
		functionMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.Functions")
		local itemMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.namespaces.C_Item")
		transmogCollectionMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.namespaces.C_TransmogCollection")
		_G.CreateAtlasMarkup = function()
			return "<->"
		end
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		functionMocks.GetExpansionLevel.returns(ns.Expansion.TWW)
		ns.armorClassMapping = {}
		if nsMocks.RGBAToHexFormat then
			nsMocks.RGBAToHexFormat.returns("|cFFFFFFFF")
		end
		assert(loadfile("RPGLootFeed/utils/ItemInfo.lua"))("TestAddon", ns)
		assert(loadfile("RPGLootFeed/utils/ItemInfoTransmog.lua"))("TestAddon", ns)
		assert(loadfile("RPGLootFeed/utils/ItemInfoEquipment.lua"))("TestAddon", ns)
		ItemInfo = ns.ItemInfo
	end)

	describe("IsAppearanceCollected", function()
		it("checks if the item appearance has been collected", function()
			transmogCollectionMocks.PlayerHasTransmogByItemInfo.returns(true)
			local item = ItemInfo:new(
				18803,
				"Test Appearance",
				"itemLink",
				2,
				10,
				1,
				"Armor",
				"Cloth",
				1,
				"INVTYPE_CLOAK",
				"texture",
				100,
				4,
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
			assert.is_true(item:IsAppearanceCollected())
		end)

		it("returns true if the appearance id is nil", function()
			transmogCollectionMocks.GetItemInfo.returns(nil, nil)
			local item = ItemInfo:new(
				18803,
				"Test Appearance",
				"itemLink",
				2,
				10,
				1,
				"Armor",
				"Cloth",
				1,
				"INVTYPE_CLOAK",
				"texture",
				100,
				4,
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
			assert.is_true(item:IsAppearanceCollected())

			transmogCollectionMocks.GetItemInfo.returns(18803, 1)
		end)

		it("handles classic", function()
			ns.armorClassMapping = { MAGE = 1 }
			functionMocks.GetExpansionLevel.returns(ns.Expansion.CATA)
			transmogCollectionMocks.PlayerHasTransmog.returns(false)
			functionMocks.UnitClass.returns("Mage", "MAGE", 1)
			local item = ItemInfo:new(
				18803, -- itemId
				"Test Appearance", -- itemName
				"itemLink", -- itemLink
				2, -- itemQuality
				10, -- itemLevel
				1, -- itemMinLevel
				"Armor", -- itemType
				"Cloth", -- itemSubType
				1, -- itemStackCount
				"INVTYPE_CLOAK", -- itemEquipLoc
				"texture", -- itemTexture
				100, -- sellPrice
				4, -- classID
				1, -- subclassID
				1, -- bindType
				1, -- expansionID
				1, -- setID
				false -- isCraftingReagent
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			local result = item:IsAppearanceCollected()
			functionMocks.UnitClass.returns("Warrior", "WARRIOR", 1)
			assert.is_false(result)
		end)

		it("checks if the item appearance has not been collected", function()
			transmogCollectionMocks.PlayerHasTransmogByItemInfo.returns(false)
			local item = ItemInfo:new(
				18803,
				"Test Appearance",
				"itemLink",
				2,
				10,
				1,
				"Armor",
				"Cloth",
				1,
				"INVTYPE_CLOAK",
				"texture",
				100,
				4,
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
			assert.is_false(item:IsAppearanceCollected())
		end)
	end)
end)
