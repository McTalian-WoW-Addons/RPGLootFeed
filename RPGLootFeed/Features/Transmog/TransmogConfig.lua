---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build the AceConfig options group for Transmog on the given frame.
--- Co-located on the module to avoid a G_RLF global.
---@param frameId integer
---@param order number
---@return table
function G_RLF.Transmog:BuildConfigArgs(frameId, order)
	local function fc()
		return G_RLF.db.global.frames[frameId].features.transmog
	end
	return {
		type = "group",
		name = G_RLF.L["Transmog Config"],
		order = order,
		args = {
			enabled = {
				type = "toggle",
				name = G_RLF.L["Enable Transmog in Feed"],
				desc = G_RLF.L["EnableTransmogDesc"],
				width = "double",
				get = function(info, value)
					return fc().enabled
				end,
				set = function(info, value)
					fc().enabled = value
					G_RLF.DbAccessor:UpdateFeatureModuleState("transmog")
					G_RLF.LootDisplay:RefreshSampleRowsIfShown()
				end,
				order = 1,
			},
			transmogOptions = {
				type = "group",
				name = G_RLF.L["Transmog Options"],
				inline = true,
				disabled = function()
					return not fc().enabled
				end,
				order = 2,
				args = {
					backgroundOverride = G_RLF.ConfigCommon.CreateFeatureBackgroundOverrideGroup({
						frameId = frameId,
						featureKey = "transmog",
						order = 0.75,
						isFeatureEnabled = function()
							return fc().enabled
						end,
					}),
					showIcon = {
						type = "toggle",
						name = G_RLF.L["Show Transmog Icon"],
						desc = G_RLF.L["ShowTransmogIconDesc"],
						width = "double",
						disabled = function()
							return not fc().enabled or G_RLF.db.global.misc.hideAllIcons
						end,
						get = function(info, value)
							return fc().enableIcon
						end,
						set = function(info, value)
							fc().enableIcon = value
							G_RLF.LootDisplay:RefreshSampleRowsIfShown()
						end,
						order = 0.5,
					},
					enableTransmogEffect = {
						type = "toggle",
						name = G_RLF.L["Enable Transmog Effect"],
						desc = G_RLF.L["EnableTransmogEffectDesc"],
						width = "double",
						get = function(info, value)
							return fc().enableTransmogEffect
						end,
						set = function(info, value)
							fc().enableTransmogEffect = value
						end,
						order = 1,
						disabled = function()
							return not fc().enabled or not G_RLF:IsRetail()
						end,
					},
					enableBlizzardTransmogSound = {
						type = "toggle",
						name = G_RLF.L["Enable Blizzard Transmog Sound"],
						desc = G_RLF.L["EnableBlizzardTransmogSoundDesc"],
						width = "double",
						get = function(info, value)
							return fc().enableBlizzardTransmogSound
						end,
						set = function(info, value)
							fc().enableBlizzardTransmogSound = value
						end,
						order = 2,
						disabled = function()
							return not fc().enabled or not G_RLF:IsRetail()
						end,
					},
					testTransmogSound = {
						type = "execute",
						name = G_RLF.L["Test Transmog Sound"],
						desc = G_RLF.L["TestTransmogSoundDesc"],
						width = "double",
						disabled = function()
							return not fc().enabled or not G_RLF:IsRetail() or not fc().enableBlizzardTransmogSound
						end,
						func = function()
							PlaySound(SOUNDKIT.UI_COSMETIC_ITEM_TOAST_SHOW)
						end,
					},
				},
			},
		},
	}
end

return {}
