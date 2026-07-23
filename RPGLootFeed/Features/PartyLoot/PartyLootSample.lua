---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local SAMPLE_ITEM_LINK = "|cff0070dd|Hitem:14344::::::::60:::::|h[Large Brilliant Shard]|h|r"

--- Build sample rows for the PartyLoot feature in the options preview.
---@param frame integer Frame ID
---@param features table Per-frame feature config
function G_RLF.PartyLoot:GetSampleRows(frame, features)
	if not features.partyLoot or not features.partyLoot.enabled then
		return
	end
	if not self:IsEnabled() then
		return
	end
	local partyDb = G_RLF.DbAccessor:Feature(frame, "partyLoot") or {}
	local sampleIcon = nil
	if partyDb.enableIcon ~= false and not G_RLF.db.global.misc.hideAllIcons then
		local ok, icon = pcall(C_Item.GetItemIconByID, 14344)
		sampleIcon = ok and icon or nil
	end

	G_RLF.LootElementBase
		:fromPayload({
			key = "sample_party_loot",
			type = "PartyLoot",
			isLink = true,
			unit = "player",
			icon = sampleIcon,
			quality = G_RLF.ItemQualEnum.Rare,
			quantity = 2,
			textFn = function(_, truncatedLink)
				return truncatedLink or SAMPLE_ITEM_LINK
			end,
			amountTextFn = function(existingQuantity)
				local effectiveQuantity = (existingQuantity or 0) + 2
				if effectiveQuantity == 1 and not G_RLF.db.global.misc.showOneQuantity then
					return ""
				end
				return "x" .. effectiveQuantity
			end,
			secondaryText = "    Adventurer",
			secondaryTextFn = function()
				return "    Adventurer"
			end,
			isSampleRow = true,
			sampleTooltipText = G_RLF.L["Party Loot"],
			moduleRef = self,
		})
		:Show()
end

return {}
