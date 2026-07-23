---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build the AceConfig options group for Experience on the given frame.
--- Called from the config system by function name.
---@param frameId integer
---@param order number
---@return table
function G_RLF.Experience:BuildConfigArgs(frameId, order)
	local function fc()
		return G_RLF.db.global.frames[frameId].features.experience
	end
	return {
		type = "group",
		name = G_RLF.L["Experience Config"],
		order = order,
		args = {
			enableXp = {
				type = "toggle",
				name = G_RLF.L["Enable Experience in Feed"],
				desc = G_RLF.L["EnableXPDesc"],
				width = "double",
				get = function()
					return fc().enabled
				end,
				set = function(_, value)
					fc().enabled = value
					G_RLF.DbAccessor:UpdateFeatureModuleState("experience")
					G_RLF.LootDisplay:RefreshSampleRowsIfShown()
				end,
				order = 1,
			},
			xpOptions = {
				type = "group",
				name = G_RLF.L["Experience Options"],
				inline = true,
				order = 2,
				disabled = function()
					return not fc().enabled
				end,
				args = {
					backgroundOverride = G_RLF.ConfigCommon.CreateFeatureBackgroundOverrideGroup({
						frameId = frameId,
						featureKey = "experience",
						order = 0.75,
						isFeatureEnabled = function()
							return fc().enabled
						end,
					}),
					showIcon = {
						type = "toggle",
						name = G_RLF.L["Show Experience Icon"],
						desc = G_RLF.L["ShowExperienceIconDesc"],
						width = "double",
						disabled = function()
							return not fc().enabled or G_RLF.db.global.misc.hideAllIcons
						end,
						get = function()
							return fc().enableIcon
						end,
						set = function(_, value)
							fc().enableIcon = value
							G_RLF.LootDisplay:RefreshSampleRowsIfShown()
						end,
						order = 0.5,
					},
					experienceTextColor = {
						type = "color",
						name = G_RLF.L["Experience Text Color"],
						desc = G_RLF.L["ExperienceTextColorDesc"],
						hasAlpha = true,
						width = "double",
						get = function()
							return unpack(fc().experienceTextColor)
						end,
						set = function(_, r, g, b, a)
							fc().experienceTextColor = { r, g, b, a }
						end,
						order = 1,
					},
					currentLevelOptions = {
						type = "group",
						inline = true,
						name = G_RLF.L["Current Level Options"],
						order = 2,
						args = {
							showCurrentLevel = {
								type = "toggle",
								name = G_RLF.L["Show Current Level"],
								desc = G_RLF.L["ShowCurrentLevelDesc"],
								width = "double",
								get = function()
									return fc().showCurrentLevel
								end,
								set = function(_, value)
									fc().showCurrentLevel = value
								end,
								order = 2,
							},
							currentLevelColor = {
								type = "color",
								hasAlpha = true,
								name = G_RLF.L["Current Level Color"],
								desc = G_RLF.L["CurrentLevelColorDesc"],
								disabled = function()
									return not fc().enabled or not fc().showCurrentLevel
								end,
								width = "double",
								get = function()
									return unpack(fc().currentLevelColor)
								end,
								set = function(_, r, g, b, a)
									fc().currentLevelColor = { r, g, b, a }
								end,
								order = 3,
							},
							currentLevelTextWrapChar = {
								type = "select",
								name = G_RLF.L["Current Level Text Wrap Character"],
								desc = G_RLF.L["CurrentLevelTextWrapCharDesc"],
								disabled = function()
									return not fc().enabled or not fc().showCurrentLevel
								end,
								get = function()
									return fc().currentLevelTextWrapChar
								end,
								set = function(_, value)
									fc().currentLevelTextWrapChar = value
								end,
								values = G_RLF.WrapCharOptions,
								style = "dropdown",
								order = 4,
							},
						},
					},
				},
			},
		},
	}
end

return {}
