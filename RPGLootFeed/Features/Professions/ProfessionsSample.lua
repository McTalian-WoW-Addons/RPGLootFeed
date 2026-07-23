---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build sample rows for the Professions feature in the options preview.
---@param frame integer Frame ID
---@param features table Per-frame feature config
function G_RLF.Professions:GetSampleRows(frame, features)
	if not features.profession or not features.profession.enabled then
		return
	end
	if not self:IsEnabled() then
		return
	end
	local profDb = G_RLF.DbAccessor:Feature(frame, "profession") or {}
	local profColor = G_RLF:RGBAToHexFormat(unpack(profDb.skillColor))
	G_RLF.LootElementBase
		:fromPayload({
			key = "sample_professions",
			type = "Professions",
			icon = (profDb.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and G_RLF.DefaultIcons.PROFESSION
				or nil,
			quality = G_RLF.ItemQualEnum.Rare,
			quantity = 5,
			textFn = function()
				return profColor .. "Cooking 300|r"
			end,
			secondaryTextFn = function()
				return ""
			end,
			itemCountFn = function()
				if not profDb.showSkillChange then
					return nil
				end
				return 5,
					{
						color = G_RLF:RGBAToHexFormat(unpack(profDb.skillColor)),
						wrapChar = profDb.skillTextWrapChar,
						showSign = true,
					}
			end,
			isSampleRow = true,
			sampleTooltipText = G_RLF.L["Profession Skills"],
			moduleRef = self,
		})
		:Show()
end

return {}
