local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("ItemInfoEquipment", function()
	local ns, ItemInfo
	local functionMocks

	before_each(function()
		functionMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.Functions")
		local itemMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.namespaces.C_Item")
		_G["INVTYPE_CLOAK"] = "Back"
		_G["INVTYPE_WEAPONMAINHAND"] = "Main Hand"
		_G["INVTYPE_WEAPON"] = "One-Hand"
		_G["INVTYPE_CHEST"] = "Chest"
		_G.CreateAtlasMarkup = function()
			return "<->"
		end
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		if nsMocks.RGBAToHexFormat then
			nsMocks.RGBAToHexFormat.returns("|cFFFFFFFF")
		end
		ns.tertiaryToString = ns.tertiaryToString or {}
		ns.AtlasIconCoefficients = ns.AtlasIconCoefficients or {}
		assert(loadfile("RPGLootFeed/utils/ItemInfo.lua"))("TestAddon", ns)
		assert(loadfile("RPGLootFeed/utils/ItemInfoEquipment.lua"))("TestAddon", ns)
		ItemInfo = ns.ItemInfo
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

	describe("Upgrade text", function()
		it("generates upgrade text when item level increases", function()
			local fromItem = ItemInfo:new(
				18803,
				"Test Item",
				"itemLink",
				2,
				5,
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
			if not item or not fromItem then
				return
			end
			local text = item:GetUpgradeText(fromItem, 14)
			assert.matches("%-%-%>", text)
		end)

		it("generates upgrade text based on roll changes when item levels are equal", function()
			local itemMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.namespaces.C_Item")
			itemMocks.GetItemStats.returns({ ["EMPTY_SOCKET_RED"] = 1 })
			local fromItem = ItemInfo:new(
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
			itemMocks.GetItemStats.returns({ ["EMPTY_SOCKET_RED"] = 1, ["EMPTY_SOCKET_BLUE"] = 1 })
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
			if not item or not fromItem then
				return
			end
			local text = item:GetUpgradeText(fromItem, 14)
			assert.matches("%-%-%>", text)
			assert.matches("Socket", text)
		end)

		it("returns empty string when equal item level and no roll changes", function()
			local fromItem = ItemInfo:new(
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
			if not item or not fromItem then
				return
			end
			assert.are.equal("", item:GetUpgradeText(fromItem, 14))
		end)
	end)
end)
