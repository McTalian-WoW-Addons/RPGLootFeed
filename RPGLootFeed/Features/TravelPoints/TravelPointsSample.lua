---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build sample rows for the TravelPoints feature in the options preview.
---@param frame integer Frame ID
---@param features table Per-frame feature config
function G_RLF.TravelPoints:GetSampleRows(frame, features)
	if not features.travelPoints or not features.travelPoints.enabled then
		return
	end
	if not self:IsEnabled() then
		return
	end
	local tpDb = G_RLF.DbAccessor:Feature(frame, "travelPoints") or {}
	local r, g, b, a = unpack(tpDb.textColor)
	G_RLF.LootElementBase
		:fromPayload({
			key = "sample_travel_points",
			type = "TravelPoints",
			icon = (tpDb.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and G_RLF.DefaultIcons.TRAVELPOINTS
				or nil,
			quality = G_RLF.ItemQualEnum.Common,
			quantity = 500,
			r = r,
			g = g,
			b = b,
			a = a,
			textFn = function(existingAmount)
				return "Travel Points + " .. ((existingAmount or 0) + 500)
			end,
			secondaryTextFn = function()
				local color = G_RLF:RGBAToHexFormat(r, g, b, a)
				return "    " .. color .. "1250/2000|r"
			end,
			isSampleRow = true,
			sampleTooltipText = G_RLF.L["Travel Points"],
			moduleRef = self,
		})
		:Show()
end

return {}
