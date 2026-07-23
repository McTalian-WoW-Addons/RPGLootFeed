---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- ── Armor class helpers ───────────────────────────────────────────────────────

local nameToSubClass
local plateName

--- Determine the highest armor proficiency the character has; Clients prior to Cata only.
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
	for i = 1, GetNumSkillLines() do
		local skillName, isHeader, a, skillRank, b, c, skillMaxRank = GetSkillLineInfo(i)
		if not isHeader then
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

--- Determine the highest armor proficiency the character has.
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

-- ── Equipment eligibility ─────────────────────────────────────────────────────

function G_RLF.ItemInfo:IsEligibleEquipment()
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

-- ── Equipment type text ──────────────────────────────────────────────────────

function G_RLF.ItemInfo:GetEquipmentTypeText()
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

-- ── Upgrade text ─────────────────────────────────────────────────────────────

function G_RLF.ItemInfo:GetUpgradeText(fromInfo, fontSize)
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
				string.format(
					"ItemInfo:GetUpgradeText: No upgrade detected, item levels are equal and no item roll changes"
				),
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
	local _ = fontSize * sizeCoeff -- kept for future real-texture overlay
	local arrowSep = "-->"
	return "    " .. fromStr .. " " .. arrowSep .. " " .. toStr
end

return {}
