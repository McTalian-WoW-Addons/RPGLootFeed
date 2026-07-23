---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local TertiaryStats = G_RLF.TertiaryStats

local SocketFDIDMap = {
	["EMPTY_SOCKET_BLUE"] = 136256,
	["EMPTY_SOCKET_META"] = 136257,
	["EMPTY_SOCKET_RED"] = 136258,
	["EMPTY_SOCKET_YELLOW"] = 136259,
	["EMPTY_SOCKET_NO_COLOR"] = 458977,
	["EMPTY_SOCKET_HYDRAULIC"] = 407325,
	["EMPTY_SOCKET_COGWHEEL"] = 407324,
	["EMPTY_SOCKET_PRISMATIC"] = 458977,
	["EMPTY_SOCKET_PUNCHCARDRED"] = 2958630,
	["EMPTY_SOCKET_PUNCHCARDYELLOW"] = 2958631,
	["EMPTY_SOCKET_PUNCHCARDBLUE"] = 2958629,
	["EMPTY_SOCKET_DOMINATION"] = 4095404,
	["EMPTY_SOCKET_CYPHER"] = 407324,
	["EMPTY_SOCKET_TINKER"] = 2958630,
	["EMPTY_SOCKET_PRIMORDIAL"] = 407324,
	["EMPTY_SOCKET_FRAGRANCE"] = 407324,
	["EMPTY_SOCKET_SINGING_THUNDER"] = 2958631,
	["EMPTY_SOCKET_SINGING_SEA"] = 2958629,
	["EMPTY_SOCKET_SINGING_WIND"] = 2958630,
	["EMPTY_SOCKET_SINGINGTHUNDER"] = 2958631,
	["EMPTY_SOCKET_SINGINGSEA"] = 2958629,
	["EMPTY_SOCKET_SINGINGWIND"] = 2958630,
}

local TertiaryStatMap = {
	["ITEM_MOD_CR_SPEED_SHORT"] = TertiaryStats.Speed,
	["ITEM_MOD_CR_LIFESTEAL_SHORT"] = TertiaryStats.Leech,
	["ITEM_MOD_CR_AVOIDANCE_SHORT"] = TertiaryStats.Avoid,
}
local IndestructibleMap = {
	["ITEM_MOD_CR_STURDINESS_SHORT"] = TertiaryStats.Indestructible,
}

---@class RLF_ItemInfo
---@field itemId number
---@field itemName string
---@field itemLink string
---@field itemQuality number
---@field itemLevel number
---@field itemMinLevel number
---@field itemType string
---@field itemSubType string
---@field itemStackCount number
---@field itemEquipLoc string
---@field itemTexture string
---@field sellPrice number
---@field classID number
---@field subclassID number
---@field bindType number
---@field expansionID number
---@field setID number
---@field isCraftingReagent boolean
---@field keystoneInfo RLF_KeystoneInfo
---@field itemRolls RLF_ItemRolls
---@field stats table
local ItemInfo = {}
ItemInfo.__index = ItemInfo

--- Create a new ItemInfo object
--- @param itemId? string|number
--- @param itemName? string
--- @param itemLink? string
--- @param itemQuality? number
--- @param itemLevel? number
--- @param itemMinLevel? number
--- @param itemType? string
--- @param itemSubType? string
--- @param itemStackCount? number
--- @param itemEquipLoc? string
--- @param itemTexture? string
--- @param sellPrice? number
--- @param classID? number
--- @param subclassID? number
--- @param bindType? number
--- @param expansionID? number
--- @param setID? number
--- @param isCraftingReagent? boolean
--- @return RLF_ItemInfo | nil
function ItemInfo:new(
	itemId,
	itemName,
	itemLink,
	itemQuality,
	itemLevel,
	itemMinLevel,
	itemType,
	itemSubType,
	itemStackCount,
	itemEquipLoc,
	itemTexture,
	sellPrice,
	classID,
	subclassID,
	bindType,
	expansionID,
	setID,
	isCraftingReagent
)
	---@type RLF_ItemInfo
	---@diagnostic disable-next-line: missing-fields
	local instance = {}
	setmetatable(instance, ItemInfo)
	if type(itemId) == "string" then
		instance.itemId = tonumber(itemId)
	else
		instance.itemId = itemId
	end
	instance.itemName = itemName
	instance.itemLink = itemLink
	instance.itemQuality = itemQuality
	instance.itemLevel = itemLevel
	instance.itemMinLevel = itemMinLevel
	instance.itemType = itemType
	instance.itemSubType = itemSubType
	instance.itemStackCount = itemStackCount
	instance.itemEquipLoc = itemEquipLoc
	instance.itemTexture = itemTexture
	instance.sellPrice = sellPrice
	instance.classID = classID
	instance.subclassID = subclassID
	instance.bindType = bindType
	instance.expansionID = expansionID
	instance.setID = setID
	instance.isCraftingReagent = isCraftingReagent

	if instance.itemName == nil then
		return nil
	end

	if instance.itemId == nil then
		instance.itemId = C_Item.GetItemIDForItemInfo(instance.itemLink)
	end
	instance.itemId = tonumber(instance.itemId)
	instance:populateKeystoneInfo()

	instance.itemRolls = instance:getItemRolls()

	return instance
end

---@class RLF_ItemRolls
---@field tertiaryStat G_RLF.TertiaryStats
---@field socketString string
---@field isSocketed boolean
---@field numSockets number
---@field isIndestructible boolean

--- Get the tertiary stat and socket string for an item
--- @return RLF_ItemRolls
function ItemInfo:getItemRolls()
	local itemRolls = {
		isIndestructible = false,
		tertiaryStat = TertiaryStats.None,
		isSocketed = false,
		numSockets = 0,
		socketString = "",
	}
	local stats
	if C_Item.GetItemStats then
		stats = C_Item.GetItemStats(self.itemLink)
	else
		-- Fallback for older WoW versions
		stats = GetItemStats(self.itemLink)
	end

	if not stats then
		G_RLF:LogDebug(
			"No stats found for item: " .. self.itemLink,
			addonName,
			G_RLF.FeatureModule.ItemLoot,
			tostring(self.itemId)
		)
		return itemRolls
	end

	self.stats = stats

	for k, v in pairs(stats) do
		if k:find("ITEM_MOD_CR_") and v > 0 then
			G_RLF:LogDebug("Found tertiary stat: " .. k, addonName, G_RLF.FeatureModule.ItemLoot, tostring(self.itemId))
			if TertiaryStatMap[k] then
				itemRolls.tertiaryStat = TertiaryStatMap[k]
			elseif IndestructibleMap[k] then
				itemRolls.isIndestructible = true
			else
				G_RLF:LogWarn(
					"Unknown tertiary stat: " .. k,
					addonName,
					G_RLF.FeatureModule.ItemLoot,
					tostring(self.itemId)
				)
			end
		end

		if k:find("EMPTY_SOCKET_") and v > 0 then
			G_RLF:LogDebug(
				"Found empty socket type: " .. k,
				addonName,
				G_RLF.FeatureModule.ItemLoot,
				tostring(self.itemId)
			)
			if SocketFDIDMap[k] then
				itemRolls.isSocketed = true
				itemRolls.numSockets = itemRolls.numSockets + v
				itemRolls.socketString = "|T" .. SocketFDIDMap[k] .. ":0|t"
			else
				G_RLF:LogWarn(
					"Unknown socket type: " .. k,
					addonName,
					G_RLF.FeatureModule.ItemLoot,
					tostring(self.itemId)
				)
			end
		elseif k:find("SOCKET") and v > 0 then
			-- Handle the case where the socket is not in the map but still has a value
			itemRolls.isSocketed = true
			itemRolls.numSockets = itemRolls.numSockets + v
			G_RLF:LogDebug(
				"Found some sort of socket? " .. k .. " " .. tostring(v),
				addonName,
				G_RLF.FeatureModule.ItemLoot,
				tostring(self.itemId)
			)
		end
	end

	return itemRolls
end

-- populateKeystoneInfo is defined in ItemInfoKeystone.lua

---Determine if the item is a mount
---@return boolean
function ItemInfo:IsMount()
	return self.classID == Enum.ItemClass.Miscellaneous and self.subclassID == Enum.ItemMiscellaneousSubclass.Mount
end

---Determine if the item is a quest item
---@return boolean
function ItemInfo:IsQuestItem()
	return self.classID == Enum.ItemClass.Questitem
end

---Determine if the item is Legendary
---@return boolean
function ItemInfo:IsLegendary()
	return self.itemQuality == G_RLF.ItemQualEnum.Legendary
end

---Determine if the item is a Mythic Keystone
---@return boolean
function ItemInfo:IsKeystone()
	return self.keystoneInfo ~= nil
end

---Get the display quality for this item (e.g., keystones are always Epic)
---@return number
function ItemInfo:GetDisplayQuality()
	if self:IsKeystone() then
		return G_RLF.ItemQualEnum.Epic
	end
	return self.itemQuality
end

-- IsAppearanceCollected is defined in ItemInfoTransmog.lua

function ItemInfo:HasItemRollBonus()
	return self.itemRolls
		and (
			self.itemRolls.tertiaryStat ~= TertiaryStats.None
			or self.itemRolls.isSocketed
			or self.itemRolls.isIndestructible
		)
end

function ItemInfo:GetItemRollText()
	local secondaryText = ""
	local stats = self.itemRolls
	if stats.isSocketed then
		secondaryText = string.format(
			"%s%s%s %s|r ",
			G_RLF:RGBAToHexFormat(0.95, 0.90, 0.60, 1),
			secondaryText,
			stats.socketString,
			G_RLF.L["Socket"]
		)
		if stats.numSockets > 1 then
			secondaryText = stats.numSockets .. "x " .. secondaryText
		end
	end
	if stats.tertiaryStat ~= TertiaryStats.None then
		secondaryText = string.format(
			"%s%s%s|r ",
			G_RLF:RGBAToHexFormat(0.00, 0.55, 0.50, 1),
			secondaryText,
			G_RLF.tertiaryToString[stats.tertiaryStat]
		)
	end
	if stats.isIndestructible then
		secondaryText = string.format(
			"%s%s%s|r",
			G_RLF:RGBAToHexFormat(0.80, 0.60, 0.00, 1),
			secondaryText,
			G_RLF.tertiaryToString[TertiaryStats.Indestructible]
		)
	end

	return secondaryText
end

-- GetUpgradeText, IsEligibleEquipment, GetEquipmentTypeText
-- and armor class helpers (ClassicSkillLineCheck, GetHighestArmorClass)
-- are defined in ItemInfoEquipment.lua

function ItemInfo:IsEquippableItem()
	return C_Item.IsEquippableItem(self.itemLink)
end

-- ── No-op stubs for optional extensions ───────────────────────────────────────
-- These are overridden by the corresponding extension file when loaded.
-- The stubs ensure the methods always exist so callers don't crash when the
-- extension has not been loaded (e.g. in pared-down test setups).

--- Override: load ItemInfoKeystone.lua to enable keystone link parsing.
function ItemInfo:populateKeystoneInfo() end

--- Override: load ItemInfoEquipment.lua to enable equipment eligibility checks.
function ItemInfo:IsEligibleEquipment()
	return false
end

G_RLF.ItemInfo = ItemInfo
