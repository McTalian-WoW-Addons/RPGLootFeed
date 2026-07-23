---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build sample rows for the Currency feature in the options preview.
---@param frame integer Frame ID
---@param features table Per-frame feature config
function G_RLF.Currency:GetSampleRows(frame, features)
	if not features.currency or not features.currency.enabled then
		return
	end
	if not self:IsEnabled() then
		return
	end
	local currencyDb = G_RLF.DbAccessor:Feature(frame, "currency") or {}
	local currencyLink = "|cff00aaff|Hcurrency:2|h[Sample Currency]|h|r"
	G_RLF.LootElementBase
		:fromPayload({
			key = "sample_currency",
			type = "Currency",
			isLink = true,
			icon = (currencyDb.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and G_RLF.DefaultIcons.MONEY
				or nil,
			quality = G_RLF.ItemQualEnum.Rare,
			quantity = 50,
			textFn = function(_, truncatedLink)
				return truncatedLink or currencyLink
			end,
			amountTextFn = function(existingQuantity)
				local effectiveQuantity = (existingQuantity or 0) + 50
				if effectiveQuantity == 1 and not G_RLF.db.global.misc.showOneQuantity then
					return ""
				end
				return "x" .. effectiveQuantity
			end,
			itemCountFn = function()
				if not currencyDb.currencyTotalTextEnabled then
					return nil
				end
				return 1500,
					{
						color = G_RLF:RGBAToHexFormat(unpack(currencyDb.currencyTotalTextColor)),
						wrapChar = currencyDb.currencyTotalTextWrapChar,
					}
			end,
			secondaryTextFn = function()
				local color = G_RLF:RGBAToHexFormat(unpack(currencyDb.lowestColor))
				return "    " .. color .. "1500 / 3000|r"
			end,
			isSampleRow = true,
			sampleTooltipText = G_RLF.L["Currency"],
			moduleRef = self,
		})
		:Show()
end

return {}
