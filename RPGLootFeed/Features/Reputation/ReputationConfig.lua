---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build the AceConfig options group for Reputation on the given frame.
--- Called from the config system by function name.
---@param frameId integer
---@param order number
---@return table
function G_RLF.Reputation:BuildConfigArgs(frameId, order)
	local function fc()
		return G_RLF.db.global.frames[frameId].features.reputation
	end
	return {
		type = "group",
		name = G_RLF.L["Reputation Config"],
		order = order,
		args = {
			enableRep = {
				type = "toggle",
				name = G_RLF.L["Enable Reputation in Feed"],
				desc = G_RLF.L["EnableRepDesc"],
				width = "double",
				get = function()
					return fc().enabled
				end,
				set = function(_, value)
					fc().enabled = value
					G_RLF.DbAccessor:UpdateFeatureModuleState("reputation")
					G_RLF.LootDisplay:RefreshSampleRowsIfShown()
				end,
				order = 1,
			},
			repOptions = {
				type = "group",
				inline = true,
				name = G_RLF.L["Reputation Options"],
				disabled = function()
					return not fc().enabled
				end,
				order = 1.1,
				args = {
					backgroundOverride = G_RLF.ConfigCommon.CreateFeatureBackgroundOverrideGroup({
						frameId = frameId,
						featureKey = "reputation",
						order = 0.75,
						isFeatureEnabled = function()
							return fc().enabled
						end,
					}),
					showIcon = {
						type = "toggle",
						name = G_RLF.L["Show Reputation Icon"],
						desc = G_RLF.L["ShowRepIconDesc"],
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
					defaultRepColor = {
						type = "color",
						hasAlpha = true,
						name = G_RLF.L["Default Rep Text Color"],
						desc = G_RLF.L["RepColorDesc"],
						get = function()
							return unpack(fc().defaultRepColor)
						end,
						set = function(_, r, g, b)
							fc().defaultRepColor = { r, g, b }
						end,
						order = 1,
					},
					secondaryTextAlpha = {
						type = "range",
						name = G_RLF.L["Secondary Text Alpha"],
						desc = G_RLF.L["SecondaryTextAlphaDesc"],
						min = 0,
						max = 1,
						step = 0.1,
						get = function()
							return fc().secondaryTextAlpha
						end,
						set = function(_, value)
							fc().secondaryTextAlpha = value
						end,
						order = 2,
					},
					repLevelOptions = {
						type = "group",
						inline = true,
						name = G_RLF.L["Reputation Level Options"],
						order = 3,
						args = {
							enableRepLevel = {
								type = "toggle",
								name = G_RLF.L["Enable Reputation Level"],
								desc = G_RLF.L["EnableRepLevelDesc"],
								width = "double",
								get = function()
									return fc().enableRepLevel
								end,
								set = function(_, value)
									fc().enableRepLevel = value
								end,
								order = 1,
							},
							repLevelColor = {
								type = "color",
								name = G_RLF.L["Reputation Level Color"],
								desc = G_RLF.L["RepLevelColorDesc"],
								disabled = function()
									return not fc().enabled or not fc().enableRepLevel
								end,
								width = "double",
								hasAlpha = true,
								get = function()
									return unpack(fc().repLevelColor)
								end,
								set = function(_, r, g, b, a)
									fc().repLevelColor = { r, g, b, a }
								end,
								order = 2,
							},
							repLevelWrapChar = {
								type = "select",
								name = G_RLF.L["Reputation Level Wrap Character"],
								desc = G_RLF.L["RepLevelWrapCharDesc"],
								disabled = function()
									return not fc().enabled or not fc().enableRepLevel
								end,
								values = G_RLF.WrapCharOptions,
								get = function()
									return fc().repLevelTextWrapChar
								end,
								set = function(_, value)
									fc().repLevelTextWrapChar = value
								end,
								order = 3,
							},
						},
					},
				},
			},
		},
	}
end

return {}
