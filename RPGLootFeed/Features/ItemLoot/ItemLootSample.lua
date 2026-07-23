---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local SAMPLE_ITEM_LINK = "|cff0070dd|Hitem:14344::::::::60:::::|h[Large Brilliant Shard]|h|r"

--- Build sample rows for the ItemLoot feature in the options preview.
---@param frame integer Frame ID
---@param features table Per-frame feature config
function G_RLF.ItemLoot:GetSampleRows(frame, features)
	if not features.itemLoot or not features.itemLoot.enabled then
		return
	end
	if not self:IsEnabled() then
		return
	end
	local itemDb = G_RLF.DbAccessor:Feature(frame, "itemLoot") or {}

	local sampleIcon = nil
	if itemDb.enableIcon ~= false and not G_RLF.db.global.misc.hideAllIcons then
		local ok, icon = pcall(C_Item.GetItemIconByID, 14344)
		sampleIcon = ok and icon or nil
	end

	G_RLF.LootElementBase
		:fromPayload({
			key = "sample_item_loot",
			type = G_RLF.FeatureModule.ItemLoot,
			isLink = true,
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
			itemCountFn = function()
				if not itemDb.itemCountTextEnabled then
					return nil
				end
				return 14,
					{
						color = G_RLF:RGBAToHexFormat(unpack(itemDb.itemCountTextColor)),
						wrapChar = itemDb.itemCountTextWrapChar,
					}
			end,
			isSampleRow = true,
			sampleTooltipText = G_RLF.L["Item Loot"],
			moduleRef = self,
		})
		:Show()
end

return {}
