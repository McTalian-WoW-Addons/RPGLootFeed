local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("ItemInfoKeystone", function()
	local ns, ItemInfo
	local itemMocks

	before_each(function()
		itemMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.namespaces.C_Item")
		_G.CreateAtlasMarkup = function()
			return "<->"
		end
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		if nsMocks.RGBAToHexFormat then
			nsMocks.RGBAToHexFormat.returns("|cFFFFFFFF")
		end
		ns.tertiaryToString = {}
		ns.AtlasIconCoefficients = ns.AtlasIconCoefficients or {}
		assert(loadfile("RPGLootFeed/utils/ItemInfo.lua"))("TestAddon", ns)
		assert(loadfile("RPGLootFeed/utils/ItemInfoKeystone.lua"))("TestAddon", ns)
		assert(loadfile("RPGLootFeed/utils/ItemInfoEquipment.lua"))("TestAddon", ns)
		ItemInfo = ns.ItemInfo
	end)

	describe("Keystone helpers", function()
		it("is not a keystone by default and uses normal quality", function()
			local item = ItemInfo:new(
				99999,
				"Normal Item",
				"link",
				Enum.ItemQuality.Rare,
				5,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_WEAPON",
				"tex",
				0,
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
			assert.is_false(item:IsKeystone())
			assert.are.equal(Enum.ItemQuality.Rare, item:GetDisplayQuality())
		end)

		it("reports keystone when keystoneInfo exists and forces Epic quality", function()
			local item = ItemInfo:new(
				180653,
				"Keystone",
				"link",
				Enum.ItemQuality.Common,
				10,
				1,
				"Gem",
				"Keystone",
				1,
				"",
				"tex",
				0,
				7,
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
			item.keystoneInfo =
				{ itemId = 180653, dungeonId = 375, dungeonName = "Halls of Atonement", level = 12, link = "" }
			assert.is_true(item:IsKeystone())
			assert.are.equal(Enum.ItemQuality.Epic, item:GetDisplayQuality())
		end)

		it("generates upgrade text for keystones using level", function()
			local fromItem = ItemInfo:new(
				180653,
				"Key From",
				"link1",
				2,
				10,
				1,
				"Gem",
				"Keystone",
				1,
				"",
				"tex",
				0,
				7,
				0,
				1,
				1,
				1,
				false
			)
			local toItem = ItemInfo:new(
				180653,
				"Key To",
				"link2",
				2,
				12,
				1,
				"Gem",
				"Keystone",
				1,
				"",
				"tex",
				0,
				7,
				0,
				1,
				1,
				1,
				false
			)
			if not fromItem or not toItem then
				assert.is_not_nil(fromItem)
				assert.is_not_nil(toItem)
				return
			end
			fromItem.keystoneInfo = { itemId = 180653, dungeonId = 375, dungeonName = "HoA", level = 10, link = "" }
			toItem.keystoneInfo = { itemId = 180653, dungeonId = 375, dungeonName = "HoA", level = 12, link = "" }
			local out = toItem:GetUpgradeText(fromItem, 12)
			assert.matches("10", out)
			assert.matches("12", out)
			assert.matches("%-%->", out) -- plain-text right arrow (WoW does not render Unicode arrows)
		end)
	end)

	describe("populateKeystoneInfo", function()
		it("parses keystone itemLink and overrides fields", function()
			-- Mock keystone related APIs/globals
			_G.C_ChallengeMode = _G.C_ChallengeMode or {}
			---@diagnostic disable-next-line: duplicate-set-field
			_G.C_ChallengeMode.GetMapUIInfo = function(mapId)
				return "Dungeon " .. tostring(mapId)
			end
			_G.CHALLENGE_MODE_KEYSTONE_NAME = "Mythic Keystone: %s"
			-- Make the item id recognized as a keystone
			---@diagnostic disable-next-line: duplicate-set-field
			_G.C_Item.IsItemKeystoneByID = function(id)
				return id == 180653
			end

			-- Example keystone link from code comment; 6 modifiers: map=381, level=13, affixes=9,7,124,121
			local keyLink =
				"|cffa335ee|Hitem:180653::::::::60:250::::6:17:381:18:13:19:9:20:7:21:124:22:121:::::|h[Mythic Keystone]|h|r"
			local item = ItemInfo:new(
				180653,
				"Mythic Keystone",
				keyLink,
				Enum.ItemQuality.Epic,
				0,
				1,
				"Gem",
				"Keystone",
				1,
				"",
				"tex",
				0,
				7,
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
			-- Keystone info populated
			assert.is_truthy(item.keystoneInfo)
			assert.are.equal(180653, item.keystoneInfo.itemId)
			assert.are.equal(381, item.keystoneInfo.dungeonId)
			assert.are.equal(13, item.keystoneInfo.level)
			assert.are.equal(9, item.keystoneInfo.affixId1)
			assert.are.equal(7, item.keystoneInfo.affixId2)
			assert.are.equal(124, item.keystoneInfo.affixId3)
			assert.are.equal(121, item.keystoneInfo.affixId4)
			-- Overrides
			assert.matches("Mythic Keystone: Dungeon 381 %(13%)", item.itemName)
			assert.matches("^|cnIQ4:|Hkeystone:", item.itemLink)
			assert.are.equal(13, item.itemLevel)
		end)
	end)
end)
