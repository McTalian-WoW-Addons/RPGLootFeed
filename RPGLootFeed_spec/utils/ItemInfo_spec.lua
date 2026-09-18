local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local after_each = busted.after_each
local describe = busted.describe
local it = busted.it

describe("ItemInfo", function()
	---@type test_G_RLF, RLF_ItemInfo
	local ns, ItemInfo
	local itemMocks, functionMocks, transmogCollectionMocks

	before_each(function()
		functionMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.Functions")
		itemMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.namespaces.C_Item")
		transmogCollectionMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.namespaces.C_TransmogCollection")
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)

		-- Provide color/atlas helpers and required globals used by new code paths
		if nsMocks.RGBAToHexFormat then
			nsMocks.RGBAToHexFormat.returns("|cFFFFFFFF")
		end
		_G.CreateAtlasMarkup = function()
			return "<->"
		end
		-- Equipment location display names
		_G["INVTYPE_CLOAK"] = "Back"
		_G["INVTYPE_WEAPONMAINHAND"] = "Main Hand"
		_G["INVTYPE_WEAPON"] = "One-Hand"
		_G["INVTYPE_CHEST"] = "Chest"
		-- Tertiary strings used by Maps. Rebuild mapping to ensure non-nil values in tests
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
			nsMocks.IsRetail.returns(false)
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

	describe("IsEligibleEquipment", function()
		it("checks if an item is eligible equipment", function()
			ns.armorClassMapping = { WARRIOR = 4 }
			ns.equipSlotMap = { INVTYPE_CHEST = 5 }

			local item = ItemInfo:new(
				18803,
				"Test Armor",
				"itemLink",
				2,
				10,
				1,
				"Armor",
				"Plate",
				1,
				"INVTYPE_CHEST",
				"texture",
				100,
				Enum.ItemClass.Armor,
				Enum.ItemArmorSubclass.Plate,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.is_true(item:IsEligibleEquipment())
		end)

		it("checks if an item is not eligible equipment due to classID", function()
			local item = ItemInfo:new(
				18803,
				"Test Weapon",
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
			assert.is_false(item:IsEligibleEquipment())
		end)

		it("checks if an item is not eligible equipment due to missing itemEquipLoc", function()
			local item = ItemInfo:new(
				18803,
				"Test Armor",
				"itemLink",
				2,
				10,
				1,
				"Armor",
				"Plate",
				1,
				nil,
				"texture",
				100,
				4,
				4,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.is_false(item:IsEligibleEquipment())
		end)

		it("checks if an item is not eligible equipment due to mismatched armor class", function()
			functionMocks.UnitClass.returns("Mage", "MAGE", 1)
			ns.armorClassMapping = { MAGE = 1 }

			local item = ItemInfo:new(
				18803,
				"Test Armor",
				"itemLink",
				2,
				10,
				1,
				"Armor",
				"Plate",
				1,
				"INVTYPE_CHEST",
				"texture",
				100,
				4,
				4,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.is_false(item:IsEligibleEquipment())
		end)

		it("checks if an item is not eligible equipment due to missing equip slot", function()
			functionMocks.UnitClass.returns("Warrior", "WARRIOR", 1)
			ns.armorClassMapping = { WARRIOR = 4 }
			ns.equipSlotMap = {}

			local item = ItemInfo:new(
				18803,
				"Test Armor",
				"itemLink",
				2,
				10,
				1,
				"Armor",
				"Plate",
				1,
				"INVTYPE_CHEST",
				"texture",
				100,
				4,
				4,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.is_false(item:IsEligibleEquipment())
		end)
	end)

	-- New tests for ItemBonusRoll parsing and related text generation
	describe("Item rolls and text generation", function()
		it("returns default rolls when no tertiary/sockets present", function()
			itemMocks.GetItemStats.returns({
				["ITEM_MOD_STRENGTH_SHORT"] = 10,
			})
			local item = ItemInfo:new(
				18803,
				"Item",
				"itemLink",
				2,
				10,
				1,
				"Armor",
				"Cloth",
				1,
				"INVTYPE_CLOAK",
				"tex",
				0,
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
			assert.is_false(item:HasItemRollBonus())
			assert.are.equal(item.itemRolls.tertiaryStat, ns.TertiaryStats.None)
			assert.is_false(item.itemRolls.isSocketed)
			assert.is_false(item.itemRolls.isIndestructible)
			assert.are.equal(item:GetItemRollText(), "")
		end)

		it("detects tertiary stat (Leech)", function()
			itemMocks.GetItemStats.returns({ ["ITEM_MOD_CR_LIFESTEAL_SHORT"] = 1 })
			local item = ItemInfo:new(
				18803,
				"Item",
				"itemLink",
				2,
				10,
				1,
				"Armor",
				"Cloth",
				1,
				"INVTYPE_CLOAK",
				"tex",
				0,
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
			assert.is_true(item:HasItemRollBonus())
			assert.are.equal(item.itemRolls.tertiaryStat, ns.TertiaryStats.Leech)
			local txt = item:GetItemRollText()
			assert.matches("Leech", txt)
		end)

		it("detects indestructible", function()
			itemMocks.GetItemStats.returns({ ["ITEM_MOD_CR_STURDINESS_SHORT"] = 1 })
			local item = ItemInfo:new(
				18803,
				"Item",
				"itemLink",
				2,
				10,
				1,
				"Armor",
				"Cloth",
				1,
				"INVTYPE_CLOAK",
				"tex",
				0,
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
			assert.is_true(item:HasItemRollBonus())
			assert.is_true(item.itemRolls.isIndestructible)
			local txt = item:GetItemRollText()
			assert.matches("Indestructible", txt)
		end)

		it("detects sockets and formats count and label", function()
			itemMocks.GetItemStats.returns({ ["EMPTY_SOCKET_RED"] = 2 })
			local item = ItemInfo:new(
				18803,
				"Item",
				"itemLink",
				2,
				10,
				1,
				"Armor",
				"Cloth",
				1,
				"INVTYPE_CLOAK",
				"tex",
				0,
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
			assert.is_true(item:HasItemRollBonus())
			assert.is_true(item.itemRolls.isSocketed)
			assert.are.equal(2, item.itemRolls.numSockets)
			local txt = item:GetItemRollText()
			assert.matches("2x", txt)
			assert.matches("Socket", txt)
			assert.matches("|T136258:0|t", txt)
		end)

		it("generates upgrade text when item level increases", function()
			itemMocks.GetItemStats.returns({})
			local fromItem = ItemInfo:new(
				18801,
				"From",
				"link1",
				2,
				90,
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
			local toItem = ItemInfo:new(
				18802,
				"To",
				"link2",
				2,
				100,
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
			if not fromItem or not toItem then
				assert.is_not_nil(fromItem)
				assert.is_not_nil(toItem)
				return
			end
			local out = toItem:GetUpgradeText(fromItem, 12)
			assert.matches("90", out)
			assert.matches("100", out)
			assert.matches("%-%->", out) -- plain-text right arrow (WoW does not render Unicode arrows)
		end)

		it("generates upgrade text based on roll changes when item levels are equal", function()
			-- from: sockets
			itemMocks.GetItemStats.returns({ ["EMPTY_SOCKET_YELLOW"] = 1 })
			local fromItem = ItemInfo:new(
				18801,
				"From",
				"link1",
				2,
				100,
				1,
				"Armor",
				"Cloth",
				1,
				"INVTYPE_CLOAK",
				"tex",
				0,
				4,
				1,
				1,
				1,
				1,
				false
			)
			-- to: tertiary Avoidance
			itemMocks.GetItemStats.returns({ ["ITEM_MOD_CR_AVOIDANCE_SHORT"] = 1 })
			local toItem = ItemInfo:new(
				18802,
				"To",
				"link2",
				2,
				100,
				1,
				"Armor",
				"Cloth",
				1,
				"INVTYPE_CLOAK",
				"tex",
				0,
				4,
				1,
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
			local out = toItem:GetUpgradeText(fromItem, 12)
			assert.is_true(#out > 0)
			assert.matches("Socket", out)
			assert.matches("Avoidance", out)
		end)

		it("returns empty string when equal item level and no roll changes", function()
			itemMocks.GetItemStats.returns({})
			local fromItem = ItemInfo:new(
				18801,
				"From",
				"link1",
				2,
				100,
				1,
				"Armor",
				"Cloth",
				1,
				"INVTYPE_CLOAK",
				"tex",
				0,
				4,
				1,
				1,
				1,
				1,
				false
			)
			itemMocks.GetItemStats.returns({})
			local toItem = ItemInfo:new(
				18802,
				"To",
				"link2",
				2,
				100,
				1,
				"Armor",
				"Cloth",
				1,
				"INVTYPE_CLOAK",
				"tex",
				0,
				4,
				1,
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
			local out = toItem:GetUpgradeText(fromItem, 12)
			assert.are.equal("", out)
		end)
	end)

	describe("GetEquipmentTypeText", function()
		it("shows equip location only (cloak)", function()
			local item = ItemInfo:new(
				10001,
				"Cloak",
				"link",
				2,
				10,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_CLOAK",
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
			local txt = item:GetEquipmentTypeText()
			assert.is_not_nil(txt)
			assert.matches("%[Back%]", txt)
		end)

		it("shows equip loc and subtype for main hand", function()
			local item = ItemInfo:new(
				10002,
				"MH Weapon",
				"link",
				2,
				10,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_WEAPONMAINHAND",
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
			local txt = item:GetEquipmentTypeText()
			assert.matches("%[Main Hand %- Sword%]", txt)
		end)

		it("shows only subtype for generic weapon", function()
			local item = ItemInfo:new(
				10003,
				"Weapon",
				"link",
				2,
				10,
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
			local txt = item:GetEquipmentTypeText()
			assert.matches("%[Sword%]", txt)
		end)

		it("returns nil for invalid equip loc token", function()
			local item = ItemInfo:new(
				10004,
				"Weird",
				"link",
				2,
				10,
				1,
				"Weapon",
				"Sword",
				1,
				"INVTYPE_DOES_NOT_EXIST",
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
			local txt = item:GetEquipmentTypeText()
			assert.is_nil(txt)
		end)

		it("colors text red for ineligible armor", function()
			functionMocks.UnitClass.returns("Mage", "MAGE", 1)
			ns.armorClassMapping = { MAGE = Enum.ItemArmorSubclass.Cloth }
			local item = ItemInfo:new(
				10005,
				"Plate Chest",
				"link",
				2,
				10,
				1,
				"Armor",
				"Plate",
				1,
				"INVTYPE_CHEST",
				"tex",
				0,
				Enum.ItemClass.Armor,
				Enum.ItemArmorSubclass.Plate,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			local txt = item:GetEquipmentTypeText()
			assert.is_not_nil(txt)
			assert.matches("Plate", txt)
		end)
	end)

	-- Keystone helper tests
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

	-- WoW Forever: Mainline client (IsRetail) reporting expansion 0, with only
	-- C_SkillInfo (no bare GetNumSkillLines/GetSkillLineInfo globals).
	describe("WoW Forever", function()
		local function newClothChest()
			return ItemInfo:new(
				18805,
				"Cloth Chest",
				"itemLink",
				2,
				10,
				1,
				"Armor",
				"Cloth",
				1,
				"INVTYPE_CHEST",
				"texture",
				0,
				Enum.ItemClass.Armor,
				Enum.ItemArmorSubclass.Cloth,
				1,
				1,
				1,
				false
			)
		end

		before_each(function()
			functionMocks.GetExpansionLevel.returns(ns.Expansion.CLASSIC)
			nsMocks.IsRetail.returns(true)
			ns.equipSlotMap = { INVTYPE_CHEST = 5 }
			---@diagnostic disable-next-line: duplicate-set-field
			_G.C_Item.GetItemSubClassInfo = function(itemClass, subClass)
				local names = {
					[Enum.ItemArmorSubclass.Cloth] = "Cloth",
					[Enum.ItemArmorSubclass.Leather] = "Leather",
					[Enum.ItemArmorSubclass.Mail] = "Mail",
					[Enum.ItemArmorSubclass.Plate] = "Plate",
				}
				return names[subClass]
			end
			_G.strmatch = _G.strmatch or string.match
			_G.GetNumSkillLines = nil
			_G.GetSkillLineInfo = nil
			local skills = {
				{ name = "Weapon Skills", isHeader = true },
				{ name = "Daggers", isHeader = false },
				{ name = "Cloth", isHeader = false },
			}
			_G.C_SkillInfo = {
				GetNumSkillLines = function()
					return #skills
				end,
				GetSkillLineInfo = function(i)
					return skills[i]
				end,
			}
		end)

		after_each(function()
			_G.C_SkillInfo = nil
		end)

		it("reads armor proficiency from C_SkillInfo", function()
			local item = newClothChest()
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.is_true(item:IsEligibleEquipment())
		end)

		it("uses the Retail transmog check instead of the Classic branch", function()
			transmogCollectionMocks.PlayerHasTransmogByItemInfo.returns(false)
			transmogCollectionMocks.PlayerHasTransmog.returns(true)
			transmogCollectionMocks.PlayerHasTransmog:clear()
			local item = newClothChest()
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.is_false(item:IsAppearanceCollected())
			assert.stub(transmogCollectionMocks.PlayerHasTransmog).was_not.called()
		end)
	end)

	-- New Classic (pre-Cata) eligibility tests leveraging ClassicSkillLineCheck
	describe("IsEligibleEquipment (Classic pre-Cata)", function()
		it("treats 'Plate Mail' skill as Plate proficiency", function()
			-- Force Classic branch
			functionMocks.GetExpansionLevel.returns(ns.Expansion.WOTLK)

			-- Equip slot map for chest
			ns.equipSlotMap = { INVTYPE_CHEST = 5 }

			-- Provide subclass display names returned by the API
			---@diagnostic disable-next-line: duplicate-set-field
			_G.C_Item.GetItemSubClassInfo = function(itemClass, subClass)
				if itemClass ~= Enum.ItemClass.Armor then
					return nil
				end
				if subClass == Enum.ItemArmorSubclass.Cloth then
					return "Cloth"
				end
				if subClass == Enum.ItemArmorSubclass.Leather then
					return "Leather"
				end
				if subClass == Enum.ItemArmorSubclass.Mail then
					return "Mail"
				end
				if subClass == Enum.ItemArmorSubclass.Plate then
					return "Plate"
				end -- Classic skill line is 'Plate Mail'
				return nil
			end

			-- WoW provides strmatch as a global; ensure it exists in tests
			_G.strmatch = _G.strmatch or string.match

			-- Simulate Classic skill lines including "Plate Mail"
			_G.GetNumSkillLines = function()
				return 3
			end
			local skills = {
				{ name = "Armor", isHeader = true },
				{ name = "Mail", isHeader = false },
				{ name = "Plate Mail", isHeader = false },
			}
			_G.GetSkillLineInfo = function(i)
				local s = skills[i]
				if not s then
					return nil
				end
				-- name, isHeader, a, skillRank, b, c, skillMaxRank
				return s.name, s.isHeader, 0, 300, 0, 0, 300
			end

			local item = ItemInfo:new(
				18803,
				"Plate Chest",
				"itemLink",
				2,
				100,
				1,
				"Armor",
				"Plate",
				1,
				"INVTYPE_CHEST",
				"texture",
				0,
				Enum.ItemClass.Armor,
				Enum.ItemArmorSubclass.Plate,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.is_true(item:IsEligibleEquipment())
		end)

		it("is ineligible when highest Classic skill is below item subclass", function()
			-- Force Classic branch
			functionMocks.GetExpansionLevel.returns(ns.Expansion.WOTLK)

			-- Equip slot map for chest
			ns.equipSlotMap = { INVTYPE_CHEST = 5 }

			-- Provide subclass display names
			---@diagnostic disable-next-line: duplicate-set-field
			_G.C_Item.GetItemSubClassInfo = function(itemClass, subClass)
				if itemClass ~= Enum.ItemClass.Armor then
					return nil
				end
				if subClass == Enum.ItemArmorSubclass.Cloth then
					return "Cloth"
				end
				if subClass == Enum.ItemArmorSubclass.Leather then
					return "Leather"
				end
				if subClass == Enum.ItemArmorSubclass.Mail then
					return "Mail"
				end
				if subClass == Enum.ItemArmorSubclass.Plate then
					return "Plate"
				end
				return nil
			end

			_G.strmatch = _G.strmatch or string.match

			-- Only up to Mail skill present
			_G.GetNumSkillLines = function()
				return 2
			end
			local skills = {
				{ name = "Armor", isHeader = true },
				{ name = "Mail", isHeader = false },
			}
			_G.GetSkillLineInfo = function(i)
				local s = skills[i]
				if not s then
					return nil
				end
				return s.name, s.isHeader, 0, 300, 0, 0, 300
			end

			local item = ItemInfo:new(
				18804,
				"Plate Chest",
				"itemLink",
				2,
				100,
				1,
				"Armor",
				"Plate",
				1,
				"INVTYPE_CHEST",
				"texture",
				0,
				Enum.ItemClass.Armor,
				Enum.ItemArmorSubclass.Plate,
				1,
				1,
				1,
				false
			)
			if not item then
				assert.is_not_nil(item)
				return
			end
			assert.is_false(item:IsEligibleEquipment())
		end)
	end)
end)
