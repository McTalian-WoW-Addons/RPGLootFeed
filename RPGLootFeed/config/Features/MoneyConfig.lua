---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local MoneyConfig = {}

local lsm = G_RLF.lsm

--- Build the AceConfig options group for Money on the given frame.
--- @param frameId integer
--- @param order number
--- @return table
function G_RLF.BuildMoneyArgs(frameId, order)
	local function fc()
		return G_RLF.db.global.frames[frameId].features.money
	end
	return {
		type = "group",
		handler = MoneyConfig,
		name = G_RLF.L["Money Config"],
		order = order,
		args = {
			enableMoney = {
				type = "toggle",
				name = G_RLF.L["Enable Money in Feed"],
				desc = G_RLF.L["EnableMoneyDesc"],
				width = "double",
				get = function()
					return fc().enabled
				end,
				set = function(_, value)
					fc().enabled = value
					G_RLF.DbAccessor:UpdateFeatureModuleState("money")
					G_RLF.LootDisplay:RefreshSampleRowsIfShown()
				end,
				order = 1,
			},
			moneyOptions = {
				type = "group",
				inline = true,
				name = G_RLF.L["Money Options"],
				disabled = function()
					return not fc().enabled
				end,
				order = 1.1,
				args = {
					backgroundOverride = G_RLF.ConfigCommon.CreateFeatureBackgroundOverrideGroup({
						frameId = frameId,
						featureKey = "money",
						order = 0.75,
						isFeatureEnabled = function()
							return fc().enabled
						end,
					}),
					showIcon = {
						type = "toggle",
						name = G_RLF.L["Show Money Icon"],
						desc = G_RLF.L["ShowMoneyIconDesc"],
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
					plainTextMoney = {
						type = "toggle",
						name = G_RLF.L["Show Money as Plain Text"],
						desc = G_RLF.L["PlainTextMoneyDesc"],
						width = "double",
						disabled = function()
							return not fc().enabled
						end,
						get = function()
							return fc().plainTextMoney
						end,
						set = function(_, value)
							fc().plainTextMoney = value
						end,
						order = 0.6,
					},
					plainTextMoneyColored = {
						type = "toggle",
						name = G_RLF.L["Color Code Plain Text Money"],
						desc = G_RLF.L["ColorCodePlainTextMoneyDesc"],
						width = "double",
						disabled = function()
							return not fc().enabled or not fc().plainTextMoney
						end,
						get = function()
							return fc().plainTextMoneyColored
						end,
						set = function(_, value)
							fc().plainTextMoneyColored = value
						end,
						order = 0.7,
					},
					-- TODO: Money total is in secondary text row, unlike other total counters
					-- Will need to make Money consistent with other features to have the same
					-- options for total counters.

					moneyTotalOptions = {
						type = "group",
						inline = true,
						name = G_RLF.L["Money Total Options"],
						order = 1,
						args = {
							showMoneyTotal = {
								type = "toggle",
								name = G_RLF.L["Show Money Total"],
								desc = G_RLF.L["ShowMoneyTotalDesc"],
								width = "double",
								get = function()
									return fc().showMoneyTotal
								end,
								set = function(_, value)
									fc().showMoneyTotal = value
								end,
							},
							-- moneyTotalColor = {
							--   type = "color",
							--   name = G_RLF.L["Money Total Color"],
							--   desc = G_RLF.L["MoneyTotalColorDesc"],
							--   disabled = function()
							--     return not fc().showMoneyTotal
							--   end,
							--   hasAlpha = true,
							--   get = function()
							--     return unpack(fc().moneyTotalColor)
							--   end,
							--   set = function(_, r, g, b, a)
							--     fc().moneyTotalColor = { r, g, b, a }
							--   end,
							-- },
							-- moneyTextWrapChar = {
							--   type = "select",
							--   name = G_RLF.L["Money Text Wrap Char"],
							--   desc = G_RLF.L["MoneyTextWrapCharDesc"],
							--   disabled = function()
							--     return not fc().showMoneyTotal
							--   end,
							--   values = G_RLF.WrapCharOptions,
							--   get = function()
							--     return fc().moneyTextWrapChar
							--   end,
							--   set = function(_, value)
							--     fc().moneyTextWrapChar = value
							--   end,
							-- },
							abbreviateTotal = {
								type = "toggle",
								name = G_RLF.L["Abbreviate Total"],
								desc = G_RLF.L["AbbreviateTotalDesc"],
								disabled = function()
									return not fc().enabled or not fc().showMoneyTotal
								end,
								width = "double",
								get = function()
									return fc().abbreviateTotal
								end,
								set = function(_, value)
									fc().abbreviateTotal = value
								end,
							},
						},
					},
					onlyIncome = {
						type = "toggle",
						name = G_RLF.L["Only Income"],
						desc = G_RLF.L["OnlyIncomeDesc"],
						width = "double",
						get = function()
							return fc().onlyIncome
						end,
						set = function(_, value)
							fc().onlyIncome = value
						end,
						order = 2,
					},
					accountantMode = {
						type = "toggle",
						name = G_RLF.L["Accountant Mode"],
						desc = G_RLF.L["AccountantModeDesc"],
						width = "double",
						disabled = function()
							return not fc().enabled or fc().onlyIncome
						end,
						get = function()
							return fc().accountantMode
						end,
						set = function(_, value)
							fc().accountantMode = value
						end,
						order = 3,
					},
					overrideMoneyLootSound = {
						type = "toggle",
						name = G_RLF.L["Override Money Loot Sound"],
						desc = G_RLF.L["OverrideMoneyLootSoundDesc"],
						get = function()
							return fc().overrideMoneyLootSound
						end,
						set = function(_, value)
							fc().overrideMoneyLootSound = value
							MoneyConfig:OverrideSound(frameId)
						end,
						width = "double",
						order = 5,
					},
					moneyLootSound = {
						type = "select",
						name = G_RLF.L["Money Loot Sound"],
						desc = G_RLF.L["MoneyLootSoundDesc"],
						values = function()
							local sounds = {}
							for k, v in pairs(lsm:HashTable(lsm.MediaType.SOUND)) do
								sounds[v] = k
							end
							return sounds
						end,
						get = function()
							return fc().moneyLootSound
						end,
						set = function(_, value)
							fc().moneyLootSound = value
							MoneyConfig:OverrideSound(frameId)
						end,
						disabled = function()
							return not fc().enabled or not fc().overrideMoneyLootSound
						end,
						width = "full",
						order = 6,
					},
				},
			},
		},
	}
end

function MoneyConfig:OverrideSound(frameId)
	local featureCfg = G_RLF.db.global.frames[frameId].features.money
	if featureCfg.overrideMoneyLootSound then
		MuteSoundFile(G_RLF.GameSounds.LOOT_SMALL_COIN)
	else
		UnmuteSoundFile(G_RLF.GameSounds.LOOT_SMALL_COIN)
	end
end
