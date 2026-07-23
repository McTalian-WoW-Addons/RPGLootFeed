---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build sample rows for the Experience feature in the options preview.
---@param frame integer Frame ID
---@param features table Per-frame feature config
function G_RLF.Experience:GetSampleRows(frame, features)
	if not features.experience or not features.experience.enabled then
		return
	end
	if not self:IsEnabled() then
		return
	end
	local xpDb = G_RLF.DbAccessor:Feature(frame, "experience") or {}
	local quantity = 1500
	local xpTextElements = self:GenerateTextElements(quantity)
	local xpElementData = {
		key = "sample_xp",
		type = "Experience",
		textElements = xpTextElements,
		quantity = quantity,
		icon = (xpDb.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and G_RLF.DefaultIcons.XP or nil,
		quality = G_RLF.ItemQualEnum.Epic,
	}
	G_RLF.LootElementBase
		:fromPayload({
			key = "sample_xp",
			type = "Experience",
			icon = xpElementData.icon,
			quality = G_RLF.ItemQualEnum.Epic,
			quantity = quantity,
			textFn = function(existingXP)
				return G_RLF.TextTemplateEngine:ProcessRowElements(1, xpElementData, existingXP)
			end,
			secondaryTextFn = function(existingXP)
				return G_RLF.TextTemplateEngine:ProcessRowElements(2, xpElementData, existingXP)
			end,
			itemCountFn = function()
				if not xpDb.showCurrentLevel then
					return nil
				end
				return 80,
					{
						color = G_RLF:RGBAToHexFormat(unpack(xpDb.currentLevelColor)),
						wrapChar = xpDb.currentLevelTextWrapChar,
					}
			end,
			isSampleRow = true,
			sampleTooltipText = G_RLF.L["Experience"],
			moduleRef = self,
		})
		:Show()
end

return {}
