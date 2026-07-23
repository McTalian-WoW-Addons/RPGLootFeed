---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build the AceConfig options group for Travel Points on the given frame.
--- Called from the config system by function name.
---@param frameId integer
---@param order number
---@return table
function G_RLF.TravelPoints:BuildConfigArgs(frameId, order)
	local function fc()
		return G_RLF.db.global.frames[frameId].features.travelPoints
	end
	return {
		type = "group",
		name = G_RLF.L["Travel Points Config"],
		order = order,
		disabled = function()
			return not G_RLF:IsRetail()
		end,
		args = {
			enable = {
				type = "toggle",
				name = G_RLF.L["Enable Travel Points in Feed"],
				desc = G_RLF.L["EnableTravelPointsDesc"],
				width = "double",
				disabled = function()
					return not G_RLF:IsRetail()
				end,
				get = function()
					return fc().enabled
				end,
				set = function(_, value)
					fc().enabled = value
					G_RLF.DbAccessor:UpdateFeatureModuleState("travelPoints")
					G_RLF.LootDisplay:RefreshSampleRowsIfShown()
				end,
				order = 1,
			},
			travelPointOptions = {
				type = "group",
				name = G_RLF.L["Travel Point Options"],
				inline = true,
				order = 2,
				disabled = function()
					return not fc().enabled
				end,
				args = {
					backgroundOverride = G_RLF.ConfigCommon.CreateFeatureBackgroundOverrideGroup({
						frameId = frameId,
						featureKey = "travelPoints",
						order = 0.75,
						isFeatureEnabled = function()
							return fc().enabled
						end,
					}),
					showIcon = {
						type = "toggle",
						name = G_RLF.L["Show Travel Point Icon"],
						desc = G_RLF.L["ShowTravelPointIconDesc"],
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
					textColor = {
						type = "color",
						name = G_RLF.L["Travel Points Text Color"],
						desc = G_RLF.L["TravelPointsTextColorDesc"],
						hasAlpha = true,
						width = "double",
						get = function()
							return unpack(fc().textColor)
						end,
						set = function(_, r, g, b, a)
							fc().textColor = { r, g, b, a }
						end,
						order = 1,
					},
				},
			},
		},
	}
end

return {}
