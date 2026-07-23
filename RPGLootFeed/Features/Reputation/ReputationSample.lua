---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build sample rows for the Reputation feature in the options preview.
---@param frame integer Frame ID
---@param features table Per-frame feature config
function G_RLF.Reputation:GetSampleRows(frame, features)
	if not features.reputation or not features.reputation.enabled then
		return
	end
	if not self:IsEnabled() then
		return
	end
	local repDb = G_RLF.DbAccessor:Feature(frame, "reputation") or {}
	local r, g, b, a = 1, 0.82, 0, 1
	G_RLF.LootElementBase
		:fromPayload({
			key = "sample_rep",
			type = "Reputation",
			icon = (repDb.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and G_RLF.DefaultIcons.REPUTATION
				or nil,
			quality = G_RLF.ItemQualEnum.Rare,
			quantity = 668,
			r = r,
			g = g,
			b = b,
			a = a,
			textFn = function(existingRep)
				local rep = (existingRep or 0) + 668
				local sign = rep >= 0 and "+" or "-"
				return sign .. math.abs(rep) .. " Stormwind"
			end,
			itemCountFn = function()
				if not repDb.enableRepLevel then
					return nil
				end
				return "Honored",
					{
						color = G_RLF:RGBAToHexFormat(unpack(repDb.repLevelColor)),
						wrapChar = repDb.repLevelTextWrapChar,
					}
			end,
			secondaryTextFn = function()
				local color = G_RLF:RGBAToHexFormat(r, g, b, repDb.secondaryTextAlpha)
				return "    " .. color .. "21000 / 42000|r"
			end,
			isSampleRow = true,
			sampleTooltipText = G_RLF.L["Reputation"],
			moduleRef = self,
		})
		:Show()
end

return {}
