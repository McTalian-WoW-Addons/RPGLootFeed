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

---@class RLF_KeystoneInfo
---@field itemId number
---@field dungeonId number
---@field dungeonName string
---@field level number
---@field affixId1? number
---@field affixId2? number
---@field affixId3? number
---@field affixId4? number
---@field link string

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

function ItemInfo:populateKeystoneInfo()
	self.keystoneInfo = nil
	if not self.itemLink then
		return
	end

	if not (C_Item.IsItemKeystoneByID and C_Item.IsItemKeystoneByID(self.itemId)) then
		return
	end

	local itemLink = self.itemLink
	-- "|cffa335ee|Hitem:180653::::::::60:250::::6:17:381:18:13:19:9:20:7:21:124:22:121:::::|h[Mythic Keystone]|h|r"
	-- Need to strip off everything before and including |Hitem:
	local start, stop = string.find(itemLink, "|Hitem:")
	if not start then
		return
	end
	local fieldString = string.sub(itemLink, stop + 1)
	start, stop = string.find(fieldString, "|h")
	fieldString = string.sub(fieldString, 1, start - 1)
	-- 180653::::::::60:250::::6:17:381:18:13:19:9:20:7:21:124:22:121:::::
	-- Now we need to split the string by ":", include the empty fields
	local fields = {}
	for field in string.gmatch(fieldString, "(.-)" .. ":") do
		table.insert(fields, field)
	end

	local keystoneInfo = {}
	local itemId = tonumber(fields[1])
	if not itemId then
		return
	end
	keystoneInfo.itemId = itemId
	local numModifiers = tonumber(fields[14]) or 0
	for i = 1, numModifiers do
		local modifierValue = tonumber(fields[14 + i * 2])
		if modifierValue then
			if i == 1 then
				keystoneInfo.dungeonId = modifierValue
				keystoneInfo.dungeonName = C_ChallengeMode.GetMapUIInfo(keystoneInfo.dungeonId)
			elseif i == 2 then
				keystoneInfo.level = modifierValue
			elseif i == 3 then
				keystoneInfo.affixId1 = modifierValue
			elseif i == 4 then
				keystoneInfo.affixId2 = modifierValue
			elseif i == 5 then
				keystoneInfo.affixId3 = modifierValue
			elseif i == 6 then
				keystoneInfo.affixId4 = modifierValue
			end
		end
	end
	self.keystoneInfo = keystoneInfo
	local linkPrefix = string.format(
		"|cnIQ4:|Hkeystone:%d:%d:%d:%d:%d:%d:%d|h[",
		self.keystoneInfo.itemId,
		self.keystoneInfo.dungeonId,
		self.keystoneInfo.level,
		self.keystoneInfo.affixId1 or 0,
		self.keystoneInfo.affixId2 or 0,
		self.keystoneInfo.affixId3 or 0,
		self.keystoneInfo.affixId4 or 0
	)
	local linkText =
		string.format(CHALLENGE_MODE_KEYSTONE_NAME, keystoneInfo.dungeonName .. " (" .. keystoneInfo.level .. ")")
	local linkPostFix = "]|h|r"
	self.keystoneInfo.link = linkPrefix .. linkText .. linkPostFix

	self.itemLink = self.keystoneInfo.link
	self.itemName = linkText
	self.itemLevel = keystoneInfo.level
end

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

function ItemInfo:IsAppearanceCollected()
	if not self:IsEquippableItem() then
		return true -- non-equippable items are not tracked for appearances
	end

	if C_TransmogCollection and C_TransmogCollection.GetItemInfo then
		local appearanceId, modId = C_TransmogCollection.GetItemInfo(self.itemLink)
		if not appearanceId or not modId then
			G_RLF:LogDebug(
				string.format(
					"ItemInfo:IsAppearanceCollected: Unable to determine appearanceId or modId for item %s",
					self.itemLink
				),
				addonName,
				"General",
				tostring(self.itemId)
			)
			return true -- If we can't determine, assume it's collected
		end

		-- Retail implementation. Checked before the expansion gates below
		-- because WoW Forever is a Mainline client reporting expansion 0.
		if G_RLF:IsRetail() and C_TransmogCollection.PlayerHasTransmogByItemInfo then
			return C_TransmogCollection.PlayerHasTransmogByItemInfo(self.itemLink)
		end
		-- Classic implementation
		if
			GetExpansionLevel() < G_RLF.Expansion.SL
			and self.itemQuality > G_RLF.ItemQualEnum.Poor
			and self:IsEligibleEquipment()
			and C_TransmogCollection.PlayerHasTransmog
		then
			G_RLF:LogDebug(
				string.format(
					"ItemInfo:IsAppearanceCollected: Checking appearanceId %d, modId %d for item %s",
					appearanceId,
					modId,
					self.itemLink
				),
				addonName,
				"General",
				tostring(self.itemId)
			)
			return C_TransmogCollection.PlayerHasTransmog(self.itemId, modId)
		end
		-- Pre Warband implementation
		if
			GetExpansionLevel() >= G_RLF.Expansion.SL
			and GetExpansionLevel() < G_RLF.Expansion.TWW
			and self:IsEligibleEquipment()
			and C_TransmogCollection.PlayerHasTransmogByItemInfo
		then
			return C_TransmogCollection.PlayerHasTransmogByItemInfo(self.itemLink)
		end
	end

	return true -- If we can't determine, assume it's collected
end

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

function ItemInfo:GetUpgradeText(fromInfo, fontSize)
	local toItemLevel = self.itemLevel
	local fromItemLevel = fromInfo and fromInfo.itemLevel or 0
	if toItemLevel == 0 or fromItemLevel == 0 then
		return ""
	end
	local fromStr = G_RLF:RGBAToHexFormat(1, 1, 1, 1) .. fromItemLevel .. "|r"
	local toStr
	if toItemLevel > fromItemLevel then
		toStr = G_RLF:RGBAToHexFormat(0.12, 1.0, 0, 1) .. toItemLevel .. "|r"
	elseif toItemLevel == fromItemLevel and not self:IsKeystone() then
		-- Need to figure out what changed
		local fromItemRollText = fromInfo:GetItemRollText()
		local toItemRollText = self:GetItemRollText()
		if fromItemRollText ~= toItemRollText then
			fromStr = fromItemRollText
			toStr = toItemRollText

			if fromStr == "" then
				fromStr = G_RLF.L["None"]
			end
		else
			G_RLF:LogDebug(
				"ItemInfo:GetUpgradeText: No upgrade detected, item levels are equal and no item roll changes",
				addonName,
				G_RLF.FeatureModule.ItemLoot,
				tostring(self.itemId)
			)
			return ""
		end
	else
		toStr = G_RLF:RGBAToHexFormat(1.0, 0.12, 0.12, 1) .. toItemLevel .. "|r"
	end
	local atlasIcon = "npe_arrowrightglow"
	local sizeCoeff = G_RLF.AtlasIconCoefficients[atlasIcon] or 1
	local atlasIconSize = fontSize * sizeCoeff
	-- Use a plain ASCII arrow instead of |A| atlas markup or Unicode characters.
	-- |A|/|T| inline sequences do not receive Translation animation offsets and
	-- cause visual jank when the row shifts.  Unicode right-arrow (U+2192) does
	-- not render in WoW's font renderer, so "-->" is used as the separator.
	local _ = atlasIconSize -- kept for future real-texture overlay if desired
	local arrowSep = "-->"
	return "    " .. fromStr .. " " .. arrowSep .. " " .. toStr
end

---Name and header flag of the skill line at index.
---WoW Forever (Mainline client) only exposes C_SkillInfo; Classic clients
---only expose the bare GetNumSkillLines/GetSkillLineInfo globals.
---@return number
local function GetSkillLineCount()
	if C_SkillInfo and C_SkillInfo.GetNumSkillLines then
		return C_SkillInfo.GetNumSkillLines()
	end
	if GetNumSkillLines then
		return GetNumSkillLines()
	end
	return 0
end

---@param index number
---@return string | nil skillName, boolean | nil isHeader
local function GetSkillLineNameAndHeader(index)
	if C_SkillInfo and C_SkillInfo.GetSkillLineInfo then
		local info = C_SkillInfo.GetSkillLineInfo(index)
		if not info then
			return nil, nil
		end
		return info.name, info.isHeader
	end
	local skillName, isHeader = GetSkillLineInfo(index)
	return skillName, isHeader
end

local nameToSubClass
local plateName
---Determine the highest armor proficiency the character has; Clients prior to Cata only
---@return number | nil
local function ClassicSkillLineCheck()
	if not nameToSubClass then
		nameToSubClass = {}
		local subClasses = {
			Enum.ItemArmorSubclass.Cloth,
			Enum.ItemArmorSubclass.Leather,
			Enum.ItemArmorSubclass.Mail,
			Enum.ItemArmorSubclass.Plate,
		}

		for _, subClass in ipairs(subClasses) do
			local name = C_Item.GetItemSubClassInfo(Enum.ItemClass.Armor, subClass)
			if name then
				nameToSubClass[name] = subClass
				if subClass == Enum.ItemArmorSubclass.Plate then
					plateName = name
				end
			end
		end
	end

	local armorClass = nil
	for i = 1, GetSkillLineCount() do
		local skillName, isHeader = GetSkillLineNameAndHeader(i)
		if skillName and not isHeader then
			if nameToSubClass[skillName] and (armorClass == nil or armorClass < nameToSubClass[skillName]) then
				armorClass = nameToSubClass[skillName]
			elseif
				not nameToSubClass[skillName]
				and plateName
				and nameToSubClass[plateName]
				and strmatch(skillName, plateName)
			then
				armorClass = Enum.ItemArmorSubclass.Plate
			end
		end
	end
	return armorClass
end

---Determine the highest armor proficiency the character has
---@return number | nil
local function GetHighestArmorClass()
	if G_RLF.cachedArmorClass and GetExpansionLevel() >= G_RLF.Expansion.CATA then
		return G_RLF.cachedArmorClass
	end
	local _, playerClass = UnitClass("player")

	if GetExpansionLevel() >= G_RLF.Expansion.CATA then
		G_RLF.cachedArmorClass = G_RLF.armorClassMapping[playerClass]
	else
		G_RLF.cachedArmorClass = ClassicSkillLineCheck()
	end

	return G_RLF.cachedArmorClass
end

function ItemInfo:IsEquippableItem()
	return C_Item.IsEquippableItem(self.itemLink)
end

function ItemInfo:IsEligibleEquipment()
	if self.classID ~= Enum.ItemClass.Armor then
		G_RLF:LogDebug(
			string.format("ItemInfo:IsEligibleEquipment: Item class %d is not Armor", self.classID),
			addonName,
			"General",
			tostring(self.itemId)
		)
		return false
	end

	if not self.itemEquipLoc then
		G_RLF:LogDebug(
			string.format("ItemInfo:IsEligibleEquipment: Item %s has no itemEquipLoc", self.itemLink),
			addonName,
			"General",
			tostring(self.itemId)
		)
		return false
	end

	local armorClass = GetHighestArmorClass()
	if not armorClass then
		G_RLF:LogDebug(
			"ItemInfo:IsEligibleEquipment: Unable to determine highest armor class",
			addonName,
			"General",
			tostring(self.itemId)
		)
		return false
	end

	if self.subclassID ~= armorClass and self.subclassID ~= Enum.ItemArmorSubclass.Generic then
		G_RLF:LogDebug(
			string.format(
				"ItemInfo:IsEligibleEquipment: Item subclass %d does not match highest armor class %d",
				self.subclassID,
				armorClass
			),
			addonName,
			"General",
			tostring(self.itemId)
		)
		return false
	end

	local slot = G_RLF.equipSlotMap[self.itemEquipLoc]
	if not slot then
		G_RLF:LogDebug(
			string.format(
				"ItemInfo:IsEligibleEquipment: Item %s has an invalid itemEquipLoc %s",
				self.itemLink,
				self.itemEquipLoc
			),
			addonName,
			"General",
			tostring(self.itemId)
		)
		return false
	end

	return true
end

function ItemInfo:GetEquipmentTypeText()
	if not self.itemEquipLoc or not self:IsEquippableItem() then
		return nil
	end

	if not _G[self.itemEquipLoc] then
		G_RLF:LogDebug(
			string.format(
				"ItemInfo:GetEquipmentTypeText: Item %s has an invalid itemEquipLoc %s",
				self.itemLink,
				self.itemEquipLoc
			),
			addonName,
			G_RLF.FeatureModule.ItemLoot,
			tostring(self.itemId)
		)
		return nil
	end

	local alwaysShowArmorSubTypes = {
		[Enum.ItemArmorSubclass.Cloth] = true,
		[Enum.ItemArmorSubclass.Leather] = true,
		[Enum.ItemArmorSubclass.Mail] = true,
		[Enum.ItemArmorSubclass.Plate] = true,
	}
	local equipLocNeverShowSubType = {
		INVTYPE_CLOAK = true,
		INVTYPE_BODY = true,
		INVTYPE_TABARD = true,
	}
	local equipLocShowSubType = { INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true }
	local equipLocShowOnlySubType = {
		INVTYPE_WEAPON = true,
		INVTYPE_2HWEAPON = true,
		INVTYPE_SHIELD = true,
		INVTYPE_RANGEDRIGHT = true,
		INVTYPE_RANGED = true,
	}

	local equipmentTypeText = " [" .. _G[self.itemEquipLoc] .. "]"
	if self.itemSubType and self.subclassID then
		if equipLocNeverShowSubType[self.itemEquipLoc] then
			equipmentTypeText = equipmentTypeText
		elseif self.classID == Enum.ItemClass.Armor and alwaysShowArmorSubTypes[self.subclassID] then
			equipmentTypeText = " [" .. _G[self.itemEquipLoc] .. " - " .. self.itemSubType .. "]"
		elseif equipLocShowSubType[self.itemEquipLoc] then
			equipmentTypeText = " [" .. _G[self.itemEquipLoc] .. " - " .. self.itemSubType .. "]"
		elseif equipLocShowOnlySubType[self.itemEquipLoc] then
			equipmentTypeText = " [" .. self.itemSubType .. "]"
		end
	else
		G_RLF:LogDebug(
			string.format(
				"ItemInfo:GetEquipmentTypeText: Item %s has no itemSubType. subClassID? %d",
				self.itemLink,
				self.subclassID or -1
			),
			addonName,
			G_RLF.FeatureModule.ItemLoot,
			tostring(self.itemId)
		)
	end

	if
		not self:IsEligibleEquipment()
		and self.classID == Enum.ItemClass.Armor
		and not equipLocNeverShowSubType[self.itemEquipLoc]
	then
		equipmentTypeText = string.format("%s%s|r", G_RLF:RGBAToHexFormat(1, 0, 0, 1), equipmentTypeText)
	else
		equipmentTypeText = string.format("%s%s|r", G_RLF:RGBAToHexFormat(1, 1, 1, 1), equipmentTypeText)
	end
	return equipmentTypeText
end

G_RLF.ItemInfo = ItemInfo
