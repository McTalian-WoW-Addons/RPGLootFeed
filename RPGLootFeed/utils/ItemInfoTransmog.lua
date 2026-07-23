---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Check whether this item's appearance has been collected in the transmog system.
---@return boolean true if already collected or if the check cannot be determined
function G_RLF.ItemInfo:IsAppearanceCollected()
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

		-- Classic implementation
		if
			GetExpansionLevel() < G_RLF.Expansion.SL
			and self.itemQuality > G_RLF.ItemQualEnum.Poor
			and self:IsEligibleEquipment()
			and C_TransmogCollection.PlayerHasTransmog
		then
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
		-- Retail implementation
		if G_RLF:IsRetail() and C_TransmogCollection.PlayerHasTransmogByItemInfo then
			return C_TransmogCollection.PlayerHasTransmogByItemInfo(self.itemLink)
		end
	end

	return true -- If we can't determine, assume it's collected
end

return {}
