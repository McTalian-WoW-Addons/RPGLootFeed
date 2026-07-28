---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build the AceConfig options group for Party Loot on the given frame.
--- Called from the config system by function name.
---@param frameId integer
---@param order number
---@return table
function G_RLF.PartyLoot:BuildConfigArgs(frameId, order)
	local function fc()
		return G_RLF.db.global.frames[frameId].features.partyLoot
	end
	return {
		type = "group",
		name = G_RLF.L["Party Loot Config"],
		order = order,
		args = {
			interactionsWarning = {
				type = "description",
				name = "|cFFFFAA00" .. G_RLF.L["DisableAllInteractionFeatureWarning"] .. "|r",
				order = 0.9,
				hidden = function()
					return not G_RLF.db.global.interactions.disableAllInteraction
				end,
			},
			enablePartyLoot = {
				type = "toggle",
				name = G_RLF.L["Enable Party Loot in Feed"],
				desc = G_RLF.L["EnablePartyLootDesc"],
				width = "double",
				get = function()
					return fc().enabled
				end,
				set = function(_, value)
					fc().enabled = value
					G_RLF.DbAccessor:UpdateFeatureModuleState("partyLoot")
					G_RLF.LootDisplay:RefreshSampleRowsIfShown()
				end,
				order = 1,
			},
			partyLootOptions = {
				type = "group",
				inline = true,
				name = G_RLF.L["Party Loot Options"],
				disabled = function()
					return not fc().enabled
				end,
				order = 2,
				args = {
					backgroundOverride = G_RLF.ConfigCommon.CreateFeatureBackgroundOverrideGroup({
						frameId = frameId,
						featureKey = "partyLoot",
						order = 0.75,
						isFeatureEnabled = function()
							return fc().enabled
						end,
					}),
					showIcon = {
						type = "toggle",
						name = G_RLF.L["Show Item Icon"],
						desc = G_RLF.L["ShowItemIconDesc"],
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
					showPartyAvatar = {
						type = "toggle",
						name = G_RLF.L["Show Party Avatar"],
						desc = G_RLF.L["ShowPartyAvatarDesc"],
						width = "double",
						get = function()
							return fc().enablePartyAvatar
						end,
						set = function(_, value)
							fc().enablePartyAvatar = value
						end,
						order = 1,
					},
					hideServerNames = {
						type = "toggle",
						name = G_RLF.L["Hide Server Names"],
						desc = G_RLF.L["HideServerNamesDesc"],
						width = "double",
						get = function()
							return fc().hideServerNames
						end,
						set = function(_, value)
							fc().hideServerNames = value
						end,
						order = 1.5,
					},
					itemQualityFilter = {
						type = "multiselect",
						name = G_RLF.L["Party Item Quality Filter"],
						desc = G_RLF.L["PartyItemQualityFilterDesc"],
						values = {
							[G_RLF.ItemQualEnum.Poor] = G_RLF.L["Poor"],
							[G_RLF.ItemQualEnum.Common] = G_RLF.L["Common"],
							[G_RLF.ItemQualEnum.Uncommon] = G_RLF.L["Uncommon"],
							[G_RLF.ItemQualEnum.Rare] = G_RLF.L["Rare"],
							[G_RLF.ItemQualEnum.Epic] = G_RLF.L["Epic"],
							[G_RLF.ItemQualEnum.Legendary] = G_RLF.L["Legendary"],
							[G_RLF.ItemQualEnum.Artifact] = G_RLF.L["Artifact"],
							[G_RLF.ItemQualEnum.Heirloom] = G_RLF.L["Heirloom"],
						},
						get = function(_, key)
							return fc().itemQualityFilter[key]
						end,
						set = function(_, key, value)
							fc().itemQualityFilter[key] = value
						end,
						order = 2,
					},
					onlyEpicAndAboveInRaid = {
						type = "toggle",
						name = G_RLF.L["Only Epic and Above in Raid"],
						desc = G_RLF.L["OnlyEpicAndAboveInRaidDesc"],
						width = "double",
						get = function()
							return fc().onlyEpicAndAboveInRaid
						end,
						set = function(_, value)
							fc().onlyEpicAndAboveInRaid = value
							local partyLoot = G_RLF.RLF:GetModule(G_RLF.FeatureModule.PartyLoot)
							partyLoot:SetPartyLootFilters()
						end,
						order = 3,
					},
					onlyEpicAndAboveInInstance = {
						type = "toggle",
						name = G_RLF.L["Only Epic and Above in Instance"],
						desc = G_RLF.L["OnlyEpicAndAboveInInstanceDesc"],
						width = "double",
						get = function()
							return fc().onlyEpicAndAboveInInstance
						end,
						set = function(_, value)
							fc().onlyEpicAndAboveInInstance = value
							local partyLoot = G_RLF.RLF:GetModule(G_RLF.FeatureModule.PartyLoot)
							partyLoot:SetPartyLootFilters()
						end,
						order = 4,
					},
					ignoreItemIds = {
						type = "input",
						name = G_RLF.L["Ignore Item IDs"],
						desc = G_RLF.L["IgnoreItemIDsDesc"],
						multiline = true,
						width = "double",
						get = function()
							return table.concat(fc().ignoreItemIds, ", ")
						end,
						set = function(_, value)
							local ids = {}
							for id in value:gmatch("%d+") do
								table.insert(ids, tonumber(id))
							end
							fc().ignoreItemIds = ids
						end,
						order = 5,
					},
				},
			},
		},
	}
end

return {}
