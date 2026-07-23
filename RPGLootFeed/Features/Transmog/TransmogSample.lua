---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build sample rows for the Transmog feature in the options preview.
--- Co-located on the module to avoid a G_RLF global.
---@param frame integer Frame ID
---@param features table Per-frame feature config
function G_RLF.Transmog:GetSampleRows(frame, features)
	if not features.transmog or not features.transmog.enabled then
		return
	end
	if not self:IsEnabled() then
		return
	end
	local transmogFeature = G_RLF.DbAccessor:Feature(frame, "transmog") or {}

	local SAMPLE_TRANSMOG_LINK = "|cff9d9d9d|Htransmogappearance:285269|h[Sample Transmog]|h|r"

	G_RLF.LootElementBase
		:fromPayload({
			key = "sample_transmog",
			type = G_RLF.FeatureModule.Transmog,
			isLink = true,
			icon = (transmogFeature.enableIcon and not G_RLF.db.global.misc.hideAllIcons)
					and G_RLF.DefaultIcons.TRANSMOG
				or nil,
			quality = G_RLF.ItemQualEnum.Epic,
			quantity = 1,
			highlight = true,
			textFn = function(_, truncatedLink)
				return truncatedLink or SAMPLE_TRANSMOG_LINK
			end,
			secondaryTextFn = function()
				return "Appearance Collected"
			end,
			isSampleRow = true,
			sampleTooltipText = G_RLF.L["Transmog"],
			moduleRef = self,
		})
		:Show()
end

return {}
