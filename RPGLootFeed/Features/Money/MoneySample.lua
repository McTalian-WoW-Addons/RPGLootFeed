---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build sample rows for the Money feature in the options preview.
---@param frame integer Frame ID
---@param features table Per-frame feature config
function G_RLF.Money:GetSampleRows(frame, features)
	if not features.money or not features.money.enabled then
		return
	end
	if not self:IsEnabled() then
		return
	end
	local quantity = 12345
	local moneyTextElements = self:GenerateTextElements(quantity)
	local moneyFeature = G_RLF.DbAccessor:Feature(frame, "money") or {}
	local moneyElementData = {
		key = "sample_money_loot",
		type = G_RLF.FeatureModule.Money,
		textElements = moneyTextElements,
		quantity = quantity,
		icon = (moneyFeature.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and G_RLF.DefaultIcons.MONEY or nil,
		quality = G_RLF.ItemQualEnum.Poor,
	}
	G_RLF.LootElementBase
		:fromPayload({
			key = "sample_money_loot",
			type = G_RLF.FeatureModule.Money,
			icon = moneyElementData.icon,
			quality = G_RLF.ItemQualEnum.Poor,
			quantity = quantity,
			textFn = function(existingCopper)
				return G_RLF.TextTemplateEngine:ProcessRowElements(1, moneyElementData, existingCopper)
			end,
			secondaryTextFn = function()
				local mc = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
				if mc.showMoneyTotal then
					return " "
				end
				return ""
			end,
			amountTextFn = function(existingCopper)
				local mc = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
				if mc.accountantMode then
					local net = (existingCopper or 0) + quantity
					if net < 0 then
						return ")"
					end
				end
				return ""
			end,
			coinDataFn = function(existingCopper)
				local total = math.abs((existingCopper or 0) + quantity)
				local gold = math.floor(total / 10000)
				local silver = math.floor((total % 10000) / 100)
				local copper = total % 100
				return gold, silver, copper
			end,
			secondaryCoinDataFn = function()
				local mc = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
				if not mc.showMoneyTotal then
					return nil
				end
				local sampleTotal = 1234567
				local gold = math.floor(sampleTotal / 10000)
				local silver = math.floor((sampleTotal % 10000) / 100)
				local copper = sampleTotal % 100
				local goldText = nil
				if mc.abbreviateTotal and gold >= 1000 then
					goldText = G_RLF.TextTemplateEngine:AbbreviateNumber(gold)
				end
				return gold, silver, copper, nil, nil, goldText
			end,
			isSampleRow = true,
			sampleTooltipText = G_RLF.L["Money"],
			moduleRef = self,
		})
		:Show()
end

return {}
