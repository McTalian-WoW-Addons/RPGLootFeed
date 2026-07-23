---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build the AceConfig options group for Currency on the given frame.
--- Called from the config system by function name.
---@param frameId integer
---@param order number
---@return table
function G_RLF.Currency:BuildConfigArgs(frameId, order)
	local function fc()
		return G_RLF.db.global.frames[frameId].features.currency
	end
	return {
		type = "group",
		name = G_RLF.L["Currency Config"],
		order = order,
		disabled = function()
			return GetExpansionLevel() < G_RLF.Expansion.WOTLK
		end,
		args = {
			enableCurrency = {
				type = "toggle",
				name = G_RLF.L["Enable Currency in Feed"],
				desc = G_RLF.L["EnableCurrencyDesc"],
				width = "double",
				get = function()
					return fc().enabled
				end,
				set = function(_, value)
					fc().enabled = value
					G_RLF.DbAccessor:UpdateFeatureModuleState("currency")
					G_RLF.LootDisplay:RefreshSampleRowsIfShown()
				end,
				disabled = function()
					return GetExpansionLevel() < G_RLF.Expansion.WOTLK
				end,
				order = 1,
			},
			currencyOptions = {
				type = "group",
				inline = true,
				name = G_RLF.L["Currency Options"],
				disabled = function()
					return not fc().enabled
				end,
				order = 2,
				args = {
					backgroundOverride = G_RLF.ConfigCommon.CreateFeatureBackgroundOverrideGroup({
						frameId = frameId,
						featureKey = "currency",
						order = 0.75,
						isFeatureEnabled = function()
							return fc().enabled
						end,
					}),
					showIcon = {
						type = "toggle",
						name = G_RLF.L["Show Currency Icon"],
						desc = G_RLF.L["ShowCurrencyIconDesc"],
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
					totalTextOptions = {
						type = "group",
						inline = true,
						name = G_RLF.L["Currency Total Text Options"],
						order = 1,
						args = {
							currencyTotalTextEnabled = {
								type = "toggle",
								name = G_RLF.L["Enable Currency Total Text"],
								desc = G_RLF.L["EnableCurrencyTotalTextDesc"],
								width = "double",
								get = function()
									return fc().currencyTotalTextEnabled
								end,
								set = function(_, value)
									fc().currencyTotalTextEnabled = value
								end,
								order = 1,
							},
							currencyTotalTextColor = {
								type = "color",
								name = G_RLF.L["Currency Total Text Color"],
								desc = G_RLF.L["CurrencyTotalTextColorDesc"],
								hasAlpha = true,
								disabled = function()
									return not fc().enabled or not fc().currencyTotalTextEnabled
								end,
								width = "double",
								get = function()
									return unpack(fc().currencyTotalTextColor)
								end,
								set = function(_, r, g, b, a)
									fc().currencyTotalTextColor = { r, g, b, a }
								end,
								order = 2,
							},
							currencyTotalTextWrapChar = {
								type = "select",
								name = G_RLF.L["Currency Total Text Wrap Character"],
								desc = G_RLF.L["CurrencyTotalTextWrapCharDesc"],
								disabled = function()
									return not fc().enabled or not fc().currencyTotalTextEnabled
								end,
								values = G_RLF.WrapCharOptions,
								get = function()
									return fc().currencyTotalTextWrapChar
								end,
								set = function(_, value)
									fc().currencyTotalTextWrapChar = value
								end,
								order = 3,
							},
						},
					},
					currencyDenyList = {
						type = "group",
						name = G_RLF.L["Currency Deny List"],
						inline = true,
						order = 3,
						args = {
							ignoreCurrencyIds = {
								type = "input",
								name = G_RLF.L["Ignore Currency IDs"],
								desc = G_RLF.L["IgnoreCurrencyIDsDesc"],
								multiline = true,
								width = "double",
								get = function()
									return table.concat(fc().ignoreCurrencyIds, ", ")
								end,
								set = function(_, value)
									local ids = {}
									for id in value:gmatch("%d+") do
										table.insert(ids, tonumber(id))
									end
									fc().ignoreCurrencyIds = ids
								end,
								order = 1,
							},
						},
					},
				},
			},
		},
	}
end

return {}
