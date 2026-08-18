---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local ItemConfig = {}

local lsm = G_RLF.lsm

local PricesEnum = G_RLF.PricesEnum

local AH_CONFIRM_DIALOG = "RPGLOOTFEED_CONFIRM_AH_SOURCE"
local PRICES_CONFIRM_DIALOG = "RPGLOOTFEED_CONFIRM_PRICES_MODE"

--- Returns true when a PricesEnum value requires an active AH integration.
local function isAHBasedMode(mode)
	return mode == PricesEnum.AH
		or mode == PricesEnum.VendorAH
		or mode == PricesEnum.AHVendor
		or mode == PricesEnum.Highest
end

--- Returns the display label for an AH-based PricesEnum value.
local function ahPriceModeLabel(mode)
	if mode == PricesEnum.AH then
		return G_RLF.L["Auction Price"]
	elseif mode == PricesEnum.VendorAH then
		return G_RLF.L["Vendor Price then Auction Price"]
	elseif mode == PricesEnum.AHVendor then
		return G_RLF.L["Auction Price then Vendor Price"]
	elseif mode == PricesEnum.Highest then
		return G_RLF.L["Highest Price"]
	end
	return mode
end

--- Lazily registers the StaticPopup confirmation dialog for AH source changes.
--- Guarded so it is a no-op outside of the WoW client (e.g. in unit tests).
local function registerAHConfirmDialog()
	if not StaticPopupDialogs or StaticPopupDialogs[AH_CONFIRM_DIALOG] then
		return
	end
	StaticPopupDialogs[AH_CONFIRM_DIALOG] = {
		text = G_RLF.L["AHSourceChangeConfirmFmt"],
		button1 = YES,
		button2 = NO,
		OnAccept = function(self, data)
			if data and data.apply then
				data.apply()
				G_RLF:NotifyChange(addonName)
			end
		end,
		OnCancel = function()
			G_RLF:NotifyChange(addonName)
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
end

--- Lazily registers the StaticPopup confirmation dialog for price mode changes.
--- Guarded so it is a no-op outside of the WoW client (e.g. in unit tests).
local function registerPricesConfirmDialog()
	if not StaticPopupDialogs or StaticPopupDialogs[PRICES_CONFIRM_DIALOG] then
		return
	end
	StaticPopupDialogs[PRICES_CONFIRM_DIALOG] = {
		text = G_RLF.L["PricesModeChangeConfirmFmt"],
		button1 = YES,
		button2 = NO,
		OnAccept = function(self, data)
			if data and data.apply then
				data.apply()
				G_RLF:NotifyChange(addonName)
			end
		end,
		OnCancel = function()
			G_RLF:NotifyChange(addonName)
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
end

--- Build the AceConfig options group for Item Loot on the given frame.
--- @param frameId integer
--- @param order number
--- @return table
function G_RLF.BuildItemLootArgs(frameId, order)
	local function fc()
		return G_RLF.db.global.frames[frameId].features.itemLoot
	end
	return {
		type = "group",
		handler = ItemConfig,
		name = G_RLF.L["Item Loot Config"],
		order = order,
		args = {
			enableItemLoot = {
				type = "toggle",
				name = G_RLF.L["Enable Item Loot in Feed"],
				desc = G_RLF.L["EnableItemLootDesc"],
				width = "double",
				get = function()
					return fc().enabled
				end,
				set = function(_, value)
					fc().enabled = value
					G_RLF.DbAccessor:UpdateFeatureModuleState("itemLoot")
					G_RLF.LootDisplay:RefreshSampleRowsIfShown()
				end,
				order = 1,
			},
			itemLootOptions = {
				type = "group",
				inline = true,
				name = G_RLF.L["Item Loot Options"],
				disabled = function()
					return not fc().enabled
				end,
				order = 1.1,
				args = {
					backgroundOverride = G_RLF.ConfigCommon.CreateFeatureBackgroundOverrideGroup({
						frameId = frameId,
						featureKey = "itemLoot",
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
					itemCountText = {
						type = "group",
						name = G_RLF.L["Item Count Text"],
						inline = true,
						order = 1.1,
						args = {
							itemCountTextEnabled = {
								type = "toggle",
								name = G_RLF.L["Enable Item Count Text"],
								desc = G_RLF.L["EnableItemCountTextDesc"],
								width = "double",
								get = function()
									return fc().itemCountTextEnabled
								end,
								set = function(_, value)
									fc().itemCountTextEnabled = value
								end,
								order = 1,
							},
							itemCountTextColor = {
								type = "color",
								name = G_RLF.L["Item Count Text Color"],
								desc = G_RLF.L["ItemCountTextColorDesc"],
								width = "double",
								disabled = function()
									return not fc().enabled or not fc().itemCountTextEnabled
								end,
								hasAlpha = true,
								get = function()
									return unpack(fc().itemCountTextColor)
								end,
								set = function(_, r, g, b, a)
									fc().itemCountTextColor = { r, g, b, a }
								end,
								order = 2,
							},
							itemCountTextWrapChar = {
								type = "select",
								name = G_RLF.L["Item Count Text Wrap Character"],
								desc = G_RLF.L["ItemCountTextWrapCharDesc"],
								disabled = function()
									return not fc().enabled or not fc().itemCountTextEnabled
								end,
								values = G_RLF.WrapCharOptions,
								get = function()
									return fc().itemCountTextWrapChar
								end,
								set = function(_, value)
									fc().itemCountTextWrapChar = value
								end,
								order = 3,
							},
						},
					},
					itemSecondaryTextOptions = {
						type = "group",
						name = G_RLF.L["Item Secondary Text Options"],
						inline = true,
						order = 1.2,
						args = {
							pricesForSellableItems = {
								type = "select",
								name = G_RLF.L["Prices for Sellable Items"],
								desc = G_RLF.L["PricesForSellableItemsDesc"],
								width = 1.5,
								values = function()
									local values = {
										[PricesEnum.None] = G_RLF.L["None"],
										[PricesEnum.Vendor] = G_RLF.L["Vendor Price"],
									}
									if G_RLF.AuctionIntegrations.numActiveIntegrations > 0 then
										values[PricesEnum.AH] = G_RLF.L["Auction Price"]
										values[PricesEnum.VendorAH] = G_RLF.L["Vendor Price then Auction Price"]
										values[PricesEnum.AHVendor] = G_RLF.L["Auction Price then Vendor Price"]
										values[PricesEnum.Highest] = G_RLF.L["Highest Price"]
									end
									-- Include the saved AH-based mode even if unavailable so the
									-- dropdown shows the real preference rather than an empty entry.
									local savedMode = fc().pricesForSellableItems
									if
										isAHBasedMode(savedMode)
										and G_RLF.AuctionIntegrations.numActiveIntegrations == 0
									then
										values[savedMode] = string.format(
											G_RLF.L["AHSourceUnavailableFmt"],
											ahPriceModeLabel(savedMode)
										)
									end
									return values
								end,
								sorting = function()
									local order = {
										PricesEnum.None,
										PricesEnum.Vendor,
									}
									if G_RLF.AuctionIntegrations.numActiveIntegrations > 0 then
										table.insert(order, PricesEnum.AH)
										table.insert(order, PricesEnum.VendorAH)
										table.insert(order, PricesEnum.AHVendor)
										table.insert(order, PricesEnum.Highest)
									end
									-- Append the unavailable saved mode at the end of the list.
									local savedMode = fc().pricesForSellableItems
									if
										isAHBasedMode(savedMode)
										and G_RLF.AuctionIntegrations.numActiveIntegrations == 0
									then
										table.insert(order, savedMode)
									end
									return order
								end,
								get = function()
									-- Return the real saved value; if it is AH-based and unavailable
									-- it resolves to the "(unavailable)" entry added in `values`.
									return fc().pricesForSellableItems
								end,
								set = function(_, value)
									local currentSaved = fc().pricesForSellableItems
									local savedIsUnavailable = isAHBasedMode(currentSaved)
										and G_RLF.AuctionIntegrations.numActiveIntegrations == 0

									local function applyChange()
										fc().pricesForSellableItems = value
									end

									-- Prompt the user before overwriting a preference for a mode
									-- that requires an AH addon which is temporarily disabled.
									if savedIsUnavailable and value ~= currentSaved and StaticPopup_Show then
										registerPricesConfirmDialog()
										StaticPopup_Show(
											PRICES_CONFIRM_DIALOG,
											ahPriceModeLabel(currentSaved),
											nil,
											{ apply = applyChange }
										)
									else
										applyChange()
									end
								end,
								order = 1,
							},
							auctionHouseSource = {
								type = "select",
								name = G_RLF.L["Auction House Source"],
								desc = G_RLF.L["AuctionHouseSourceDesc"],
								width = 1.5,
								values = function()
									local values = {}
									local nilStr = G_RLF.AuctionIntegrations.nilIntegration:ToString()
									values[nilStr] = nilStr

									local activeIntegrations = G_RLF.AuctionIntegrations.activeIntegrations
									local numActiveIntegrations = G_RLF.AuctionIntegrations.numActiveIntegrations
									if activeIntegrations and numActiveIntegrations >= 1 then
										for k, _ in pairs(activeIntegrations) do
											values[k] = k
										end
									end
									-- Include the saved value even if unavailable so the dropdown
									-- shows the user's preference rather than an empty selection.
									local savedSource = fc().auctionHouseSource
									if
										savedSource
										and savedSource ~= nilStr
										and (not activeIntegrations or not activeIntegrations[savedSource])
									then
										values[savedSource] =
											string.format(G_RLF.L["AHSourceUnavailableFmt"], savedSource)
									end
									return values
								end,
								sorting = function()
									local sorted = {}
									local nilStr = G_RLF.AuctionIntegrations.nilIntegration:ToString()
									sorted[1] = nilStr

									local activeIntegrations = G_RLF.AuctionIntegrations.activeIntegrations
									local numActiveIntegrations = G_RLF.AuctionIntegrations.numActiveIntegrations
									if activeIntegrations and numActiveIntegrations >= 1 then
										local i = 2
										for k, _ in pairs(activeIntegrations) do
											sorted[i] = k
											i = i + 1
										end
									end
									-- Append the unavailable saved value at the end of the list.
									local savedSource = fc().auctionHouseSource
									if
										savedSource
										and savedSource ~= nilStr
										and (not activeIntegrations or not activeIntegrations[savedSource])
									then
										sorted[#sorted + 1] = savedSource
									end
									return sorted
								end,
								disabled = function()
									return not fc().enabled
										or fc().pricesForSellableItems == PricesEnum.Vendor
										or fc().pricesForSellableItems == PricesEnum.None
								end,
								hidden = function()
									local activeIntegrations = G_RLF.AuctionIntegrations.activeIntegrations
									local numActiveIntegrations = G_RLF.AuctionIntegrations.numActiveIntegrations
									if not activeIntegrations or numActiveIntegrations == 0 then
										-- Still reveal when there is an unavailable saved preference so
										-- the user can see and clear it.
										local saved = fc().auctionHouseSource
										local nilStr = G_RLF.AuctionIntegrations.nilIntegration:ToString()
										return not saved or saved == nilStr
									end
									return false
								end,
								get = function()
									local saved = fc().auctionHouseSource
									if not saved then
										return G_RLF.AuctionIntegrations.nilIntegration:ToString()
									end
									-- Return the saved value directly; if it is unavailable it will
									-- resolve to the "(unavailable)" entry added in `values`.
									return saved
								end,
								set = function(_, value)
									local currentSaved = fc().auctionHouseSource
									local nilStr = G_RLF.AuctionIntegrations.nilIntegration:ToString()
									local activeIntegrations = G_RLF.AuctionIntegrations.activeIntegrations
									local savedIsUnavailable = currentSaved
										and currentSaved ~= nilStr
										and (not activeIntegrations or not activeIntegrations[currentSaved])

									local function applyChange()
										fc().auctionHouseSource = value
										if value ~= nilStr and activeIntegrations and activeIntegrations[value] then
											G_RLF.AuctionIntegrations.activeIntegration = activeIntegrations[value]
										elseif value == nilStr then
											G_RLF.AuctionIntegrations.activeIntegration =
												G_RLF.AuctionIntegrations.nilIntegration
										else
											G_RLF.AuctionIntegrations.activeIntegration = nil
										end
									end

									-- Prompt the user before overwriting a preference for an addon
									-- that is only temporarily disabled.
									if savedIsUnavailable and value ~= currentSaved and StaticPopup_Show then
										registerAHConfirmDialog()
										StaticPopup_Show(AH_CONFIRM_DIALOG, currentSaved, nil, { apply = applyChange })
									else
										applyChange()
									end
								end,
								order = 2,
							},
							atlasIconDescription = {
								type = "description",
								name = G_RLF.L["AtlasIconDescription"],
								order = 2.99,
							},
							vendorIconTexture = {
								type = "input",
								name = G_RLF.L["Vendor Icon Texture"],
								desc = G_RLF.L["VendorIconTextureDesc"],
								width = "double",
								get = function()
									return fc().vendorIconTexture
								end,
								set = function(_, value)
									fc().vendorIconTexture = value
								end,
								validate = "ValidateAtlas",
								order = 3,
							},
							testVendorIcon = {
								type = "description",
								name = function()
									local icon = fc().vendorIconTexture
									return ItemConfig:TestIcon(frameId, icon)
								end,
								width = "normal",
								order = 3.1,
							},
							revertVendorToDefault = {
								type = "execute",
								name = CreateAtlasMarkup("common-icon-undo", 16, 16),
								desc = G_RLF.L["RevertVendorIconToDefaultDesc"],
								func = function()
									fc().vendorIconTexture =
										G_RLF.db.defaults.global.frames["**"].features.itemLoot.vendorIconTexture
								end,
								width = 0.35,
								order = 3.2,
							},
							auctionHouseIconTexture = {
								type = "input",
								name = G_RLF.L["Auction House Icon Texture"],
								desc = G_RLF.L["AuctionHouseIconTextureDesc"],
								width = "double",
								get = function()
									return fc().auctionHouseIconTexture
								end,
								set = function(_, value)
									fc().auctionHouseIconTexture = value
								end,
								validate = "ValidateAtlas",
								order = 4,
							},
							testAuctionHouseIcon = {
								type = "description",
								name = function()
									local icon = fc().auctionHouseIconTexture
									return ItemConfig:TestIcon(frameId, icon)
								end,
								width = "normal",
								order = 4.1,
							},
							revertAuctionHouseToDefault = {
								type = "execute",
								name = CreateAtlasMarkup("common-icon-undo", 16, 16),
								desc = G_RLF.L["RevertAuctionHouseIconToDefaultDesc"],
								func = function()
									fc().auctionHouseIconTexture =
										G_RLF.db.defaults.global.frames["**"].features.itemLoot.auctionHouseIconTexture
								end,
								width = 0.35,
								order = 4.2,
							},
							plainTextPrices = {
								type = "toggle",
								name = G_RLF.L["Show Prices as Plain Text"],
								desc = G_RLF.L["PlainTextPricesDesc"],
								disabled = function()
									return not fc().enabled or fc().pricesForSellableItems == PricesEnum.None
								end,
								get = function()
									return fc().plainTextPrices
								end,
								set = function(_, value)
									fc().plainTextPrices = value
								end,
								order = 5,
							},
						},
					},
					itemQualityFilter = {
						type = "group",
						name = G_RLF.L["Item Quality Filter"],
						desc = G_RLF.L["ItemQualityFilterDesc"],
						inline = true,
						order = 2,
						args = {
							resetAllDurationOverrides = {
								type = "execute",
								name = G_RLF.L["Reset All Duration Overrides"],
								desc = G_RLF.L["ResetAllDurationOverridesDesc"],
								func = function()
									for _, v in pairs(fc().itemQualitySettings) do
										v.duration = 0
									end
								end,
								order = 0.5,
								width = "full",
							},
							poorEnabled = {
								type = "toggle",
								width = 1.5,
								name = G_RLF.L["Poor"],
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Poor].enabled
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Poor].enabled = value
								end,
								order = 2,
							},
							poorDuration = {
								type = "range",
								width = 1.5,
								name = string.format(G_RLF.L["Duration (seconds)"], G_RLF.L["Poor"]),
								desc = string.format(G_RLF.L["DurationDesc"], G_RLF.L["Poor"]),
								min = 0,
								max = 30,
								step = 1,
								hidden = function()
									return not fc().itemQualitySettings[G_RLF.ItemQualEnum.Poor].enabled
								end,
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Poor].duration
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Poor].duration = value
								end,
								order = 3,
							},
							commonEnabled = {
								type = "toggle",
								width = 1.5,
								name = G_RLF.L["Common"],
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Common].enabled
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Common].enabled = value
								end,
								order = 5,
							},
							commonDuration = {
								type = "range",
								width = 1.5,
								name = string.format(G_RLF.L["Duration (seconds)"], G_RLF.L["Common"]),
								desc = string.format(G_RLF.L["DurationDesc"], G_RLF.L["Common"]),
								min = 0,
								max = 30,
								step = 1,
								hidden = function()
									return not fc().itemQualitySettings[G_RLF.ItemQualEnum.Common].enabled
								end,
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Common].duration
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Common].duration = value
								end,
								order = 6,
							},
							uncommonEnabled = {
								type = "toggle",
								width = 1.5,
								name = G_RLF.L["Uncommon"],
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Uncommon].enabled
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Uncommon].enabled = value
								end,
								order = 8,
							},
							uncommonDuration = {
								type = "range",
								width = 1.5,
								name = string.format(G_RLF.L["Duration (seconds)"], G_RLF.L["Uncommon"]),
								desc = string.format(G_RLF.L["DurationDesc"], G_RLF.L["Uncommon"]),
								min = 0,
								max = 30,
								step = 1,
								hidden = function()
									return not fc().itemQualitySettings[G_RLF.ItemQualEnum.Uncommon].enabled
								end,
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Uncommon].duration
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Uncommon].duration = value
								end,
								order = 9,
							},
							rareEnabled = {
								type = "toggle",
								width = 1.5,
								name = G_RLF.L["Rare"],
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Rare].enabled
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Rare].enabled = value
								end,
								order = 11,
							},
							rareDuration = {
								type = "range",
								width = 1.5,
								name = string.format(G_RLF.L["Duration (seconds)"], G_RLF.L["Rare"]),
								desc = string.format(G_RLF.L["DurationDesc"], G_RLF.L["Rare"]),
								min = 0,
								max = 30,
								step = 1,
								hidden = function()
									return not fc().itemQualitySettings[G_RLF.ItemQualEnum.Rare].enabled
								end,
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Rare].duration
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Rare].duration = value
								end,
								order = 12,
							},
							epicEnabled = {
								type = "toggle",
								width = 1.5,
								name = G_RLF.L["Epic"],
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Epic].enabled
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Epic].enabled = value
								end,
								order = 14,
							},
							epicDuration = {
								type = "range",
								width = 1.5,
								name = string.format(G_RLF.L["Duration (seconds)"], G_RLF.L["Epic"]),
								desc = string.format(G_RLF.L["DurationDesc"], G_RLF.L["Epic"]),
								min = 0,
								max = 30,
								step = 1,
								hidden = function()
									return not fc().itemQualitySettings[G_RLF.ItemQualEnum.Epic].enabled
								end,
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Epic].duration
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Epic].duration = value
								end,
								order = 15,
							},
							legendaryEnabled = {
								type = "toggle",
								width = 1.5,
								name = G_RLF.L["Legendary"],
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Legendary].enabled
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Legendary].enabled = value
								end,
								order = 17,
							},
							legendaryDuration = {
								type = "range",
								width = 1.5,
								name = string.format(G_RLF.L["Duration (seconds)"], G_RLF.L["Legendary"]),
								desc = string.format(G_RLF.L["DurationDesc"], G_RLF.L["Legendary"]),
								min = 0,
								max = 30,
								step = 1,
								hidden = function()
									return not fc().itemQualitySettings[G_RLF.ItemQualEnum.Legendary].enabled
								end,
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Legendary].duration
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Legendary].duration = value
								end,
								order = 18,
							},
							artifactEnabled = {
								type = "toggle",
								width = 1.5,
								name = G_RLF.L["Artifact"],
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Artifact].enabled
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Artifact].enabled = value
								end,
								order = 20,
							},
							artifactDuration = {
								type = "range",
								width = 1.5,
								name = string.format(G_RLF.L["Duration (seconds)"], G_RLF.L["Artifact"]),
								desc = string.format(G_RLF.L["DurationDesc"], G_RLF.L["Artifact"]),
								min = 0,
								max = 30,
								step = 1,
								hidden = function()
									return not fc().itemQualitySettings[G_RLF.ItemQualEnum.Artifact].enabled
								end,
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Artifact].duration
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Artifact].duration = value
								end,
								order = 21,
							},
							heirloomEnabled = {
								type = "toggle",
								width = 1.5,
								name = G_RLF.L["Heirloom"],
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Heirloom].enabled
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Heirloom].enabled = value
								end,
								order = 23,
							},
							heirloomDuration = {
								type = "range",
								width = 1.5,
								name = string.format(G_RLF.L["Duration (seconds)"], G_RLF.L["Heirloom"]),
								desc = string.format(G_RLF.L["DurationDesc"], G_RLF.L["Heirloom"]),
								min = 0,
								max = 30,
								step = 1,
								hidden = function()
									return not fc().itemQualitySettings[G_RLF.ItemQualEnum.Heirloom].enabled
								end,
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.Heirloom].duration
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.Heirloom].duration = value
								end,
								order = 24,
							},
							wowTokenEnabled = {
								type = "toggle",
								width = 1.5,
								name = _G["ITEM_QUALITY8_DESC"],
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.WoWToken].enabled
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.WoWToken].enabled = value
								end,
								order = 25,
							},
							wowTokenDuration = {
								type = "range",
								width = 1.5,
								name = string.format(G_RLF.L["Duration (seconds)"], _G["ITEM_QUALITY8_DESC"]),
								desc = string.format(G_RLF.L["DurationDesc"], _G["ITEM_QUALITY8_DESC"]),
								min = 0,
								max = 30,
								step = 1,
								hidden = function()
									return not fc().itemQualitySettings[G_RLF.ItemQualEnum.WoWToken].enabled
								end,
								get = function()
									return fc().itemQualitySettings[G_RLF.ItemQualEnum.WoWToken].duration
								end,
								set = function(_, value)
									fc().itemQualitySettings[G_RLF.ItemQualEnum.WoWToken].duration = value
								end,
								order = 26,
							},
						},
					},
					itemHighlights = {
						type = "group",
						name = G_RLF.L["Item Highlights"],
						desc = G_RLF.L["ItemHighlightsDesc"],
						inline = true,
						order = 3,
						args = {
							highlightMount = {
								type = "toggle",
								name = G_RLF.L["Highlight Mounts"],
								desc = G_RLF.L["HighlightMountsDesc"],
								width = "double",
								get = function(info)
									return fc().itemHighlights.mounts
								end,
								set = function(info, value)
									fc().itemHighlights.mounts = value
								end,
								order = 1,
							},
							highlightLegendary = {
								type = "toggle",
								name = G_RLF.L["Highlight Legendary Items"],
								desc = G_RLF.L["HighlightLegendaryDesc"],
								width = "double",
								get = function(info)
									return fc().itemHighlights.legendary
								end,
								set = function(info, value)
									fc().itemHighlights.legendary = value
								end,
								order = 2,
							},
							highlightBetterThanEquipped = {
								type = "toggle",
								name = G_RLF.L["Highlight Items Better Than Equipped"],
								desc = G_RLF.L["HighlightBetterThanEquippedDesc"],
								width = "double",
								get = function(info)
									return fc().itemHighlights.betterThanEquipped
								end,
								set = function(info, value)
									fc().itemHighlights.betterThanEquipped = value
								end,
								order = 3,
							},
							hasTertiaryOrSocket = {
								type = "toggle",
								name = G_RLF.L["Highlight Items with Tertiary Stats or Sockets"],
								desc = G_RLF.L["HighlightTertiaryOrSocketDesc"],
								width = "double",
								get = function(info)
									return fc().itemHighlights.hasTertiaryOrSocket
								end,
								set = function(info, value)
									fc().itemHighlights.hasTertiaryOrSocket = value
								end,
								order = 4,
							},
							-- highlightBoE = {
							--   type = "toggle",
							--   name = G_RLF.L["Highlight BoE Items"],
							--   desc = G_RLF.L["HighlightBoEDesc"],
							--   width = "double",
							--   get = function(info) return fc().itemHighlights.boe end,
							--   set = function(info, value) fc().itemHighlights.boe = value end,
							--   order = 3,
							-- },
							-- highlightBoP = {
							--   type = "toggle",
							--   name = G_RLF.L["Highlight BoP Items"],
							--   desc = G_RLF.L["HighlightBoPDesc"],
							--   width = "double",
							--   get = function(info) return fc().itemHighlights.bop end,
							--   set = function(info, value) fc().itemHighlights.bop = value end,
							--   order = 4,
							-- },
							highlightQuest = {
								type = "toggle",
								name = G_RLF.L["Highlight Quest Items"],
								desc = G_RLF.L["HighlightQuestDesc"],
								width = "double",
								get = function(info)
									return fc().itemHighlights.quest
								end,
								set = function(info, value)
									fc().itemHighlights.quest = value
								end,
								order = 5,
							},
							highlightTransmog = {
								type = "toggle",
								name = G_RLF.L["Highlight New Transmog Items"],
								desc = G_RLF.L["HighlightTransmogDesc"],
								width = "double",
								get = function(info)
									return fc().itemHighlights.transmog
								end,
								set = function(info, value)
									fc().itemHighlights.transmog = value
								end,
								order = 6,
							},
						},
					},
					itemSounds = {
						type = "group",
						name = G_RLF.L["Item Loot Sounds"],
						inline = true,
						order = 4,
						args = {
							mounts = {
								type = "toggle",
								name = G_RLF.L["Play Sound for Mounts"],
								desc = G_RLF.L["PlaySoundForMountsDesc"],
								width = "double",
								get = function()
									return fc().sounds.mounts.enabled
								end,
								set = function(_, value)
									fc().sounds.mounts.enabled = value
								end,
								order = 1,
							},
							playSelectedMountSound = {
								type = "execute",
								name = CreateAtlasMarkup("common-icon-forwardarrow", 16, 16),
								desc = G_RLF.L["TestMountSoundDesc"],
								func = function()
									PlaySoundFile(fc().sounds.mounts.sound)
								end,
								disabled = function()
									return not fc().enabled
										or not fc().sounds.mounts.enabled
										or fc().sounds.mounts.sound == ""
								end,
								width = 0.35,
								order = 1.5,
							},
							mountSound = {
								type = "select",
								name = G_RLF.L["Mount Sound"],
								desc = G_RLF.L["MountSoundDesc"],
								values = "SoundOptionValues",
								get = function()
									return fc().sounds.mounts.sound
								end,
								set = function(_, value)
									fc().sounds.mounts.sound = value
								end,
								disabled = function()
									return not fc().enabled or not fc().sounds.mounts.enabled
								end,
								order = 2,
								width = "full",
							},
							legendary = {
								type = "toggle",
								name = G_RLF.L["Play Sound for Legendary Items"],
								desc = G_RLF.L["PlaySoundForLegendaryDesc"],
								width = "double",
								get = function()
									return fc().sounds.legendary.enabled
								end,
								set = function(_, value)
									fc().sounds.legendary.enabled = value
								end,
								order = 3,
							},
							playSelectedLegendarySound = {
								type = "execute",
								name = CreateAtlasMarkup("common-icon-forwardarrow", 16, 16),
								desc = G_RLF.L["TestLegendarySoundDesc"],
								func = function()
									PlaySoundFile(fc().sounds.legendary.sound)
								end,
								disabled = function()
									return not fc().enabled
										or not fc().sounds.legendary.enabled
										or fc().sounds.legendary.sound == ""
								end,
								width = 0.35,
								order = 3.5,
							},
							legendarySound = {
								type = "select",
								name = G_RLF.L["Legendary Sound"],
								desc = G_RLF.L["LegendarySoundDesc"],
								values = "SoundOptionValues",
								get = function()
									return fc().sounds.legendary.sound
								end,
								set = function(_, value)
									fc().sounds.legendary.sound = value
								end,
								disabled = function()
									return not fc().enabled or not fc().sounds.legendary.enabled
								end,
								order = 4,
								width = "full",
							},
							betterThanEquipped = {
								type = "toggle",
								name = G_RLF.L["Play Sound for Items Better Than Equipped"],
								desc = G_RLF.L["PlaySoundForBetterDesc"],
								width = "double",
								get = function()
									return fc().sounds.betterThanEquipped.enabled
								end,
								set = function(_, value)
									fc().sounds.betterThanEquipped.enabled = value
								end,
								order = 5,
							},
							playSelectedBetterThanEquippedSound = {
								type = "execute",
								name = CreateAtlasMarkup("common-icon-forwardarrow", 16, 16),
								desc = G_RLF.L["TestBetterThanEquippedSoundDesc"],
								func = function()
									PlaySoundFile(fc().sounds.betterThanEquipped.sound)
								end,
								disabled = function()
									return not fc().enabled
										or not fc().sounds.betterThanEquipped.enabled
										or fc().sounds.betterThanEquipped.sound == ""
								end,
								width = 0.35,
								order = 5.5,
							},
							betterThanEquippedSound = {
								type = "select",
								name = G_RLF.L["Better Than Equipped Sound"],
								desc = G_RLF.L["BetterThanEquippedSoundDesc"],
								values = "SoundOptionValues",
								get = function()
									return fc().sounds.betterThanEquipped.sound
								end,
								set = function(_, value)
									fc().sounds.betterThanEquipped.sound = value
								end,
								disabled = function()
									return not fc().enabled or not fc().sounds.betterThanEquipped.enabled
								end,
								width = "full",
								order = 6,
							},
							transmog = {
								type = "toggle",
								name = G_RLF.L["Play Sound for New Transmog Items"],
								desc = G_RLF.L["PlaySoundForTransmogDesc"],
								width = "double",
								get = function()
									return fc().sounds.transmog.enabled
								end,
								set = function(_, value)
									fc().sounds.transmog.enabled = value
								end,
								order = 7,
							},
							playSelectedTransmogSound = {
								type = "execute",
								name = CreateAtlasMarkup("common-icon-forwardarrow", 16, 16),
								desc = G_RLF.L["TestTransmogSoundDesc"],
								func = function()
									PlaySoundFile(fc().sounds.transmog.sound)
								end,
								disabled = function()
									return not fc().enabled
										or not fc().sounds.transmog.enabled
										or fc().sounds.transmog.sound == ""
								end,
								width = 0.35,
								order = 7.5,
							},
							transmogSound = {
								type = "select",
								name = G_RLF.L["Transmog Sound"],
								desc = G_RLF.L["TransmogSoundDesc"],
								values = "SoundOptionValues",
								get = function()
									return fc().sounds.transmog.sound
								end,
								set = function(_, value)
									fc().sounds.transmog.sound = value
								end,
								disabled = function()
									return not fc().enabled or not fc().sounds.transmog.enabled
								end,
								width = "full",
								order = 8,
							},
						},
					},
					itemStyleOverrides = {
						type = "group",
						name = G_RLF.L["Item Text Style Overrides"],
						inline = true,
						order = 5,
						args = {
							questStyleOverrideEnabled = {
								type = "toggle",
								name = G_RLF.L["Override Text Style for Quest Items"],
								desc = G_RLF.L["QuestItemStyleOverrideDesc"],
								width = "double",
								get = function()
									return fc().textStyleOverrides.quest.enabled
								end,
								set = function(_, value)
									fc().textStyleOverrides.quest.enabled = value
								end,
								order = 1,
							},
							questStyleOverrideColor = {
								type = "color",
								name = G_RLF.L["Quest Item Color Text"],
								desc = G_RLF.L["QuestItemColorTextDesc"],
								width = "double",
								hasAlpha = true,
								disabled = function()
									return not fc().enabled or not fc().textStyleOverrides.quest.enabled
								end,
								get = function()
									return unpack(fc().textStyleOverrides.quest.color)
								end,
								set = function(_, r, g, b, a)
									fc().textStyleOverrides.quest.color = { r, g, b, a }
								end,
								order = 2,
							},
						},
					},
					itemDenyList = {
						type = "group",
						name = G_RLF.L["Item Loot Deny List"],
						inline = true,
						order = 6,
						args = {
							ignoreItemIds = {
								type = "input",
								name = G_RLF.L["Ignore Item IDs"],
								desc = G_RLF.L["IgnoreItemIDsItemLootDesc"],
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
								order = 1,
							},
						},
					},
				},
			},
		},
	}
end

function ItemConfig:SoundOptionValues()
	local sounds = {}
	for k, v in pairs(lsm:HashTable(lsm.MediaType.SOUND)) do
		sounds[v] = k
	end
	return sounds
end

function ItemConfig:TestIcon(frameId, icon)
	local styleDb = G_RLF.DbAccessor:Styling(frameId)
	local secondaryFontSize = styleDb.secondaryFontSize
	local sizeCoeff = G_RLF.AtlasIconCoefficients[icon] or 1
	local atlasIconSize = secondaryFontSize * sizeCoeff
	return string.format(G_RLF.L["Chosen Icon"], CreateAtlasMarkup(icon, atlasIconSize, atlasIconSize))
end

function ItemConfig:ValidateAtlas(_, value)
	local info = C_Texture.GetAtlasInfo(value)

	if info then
		return true
	end

	return string.format(G_RLF.L["InvalidAtlasTexture"], value)
end
