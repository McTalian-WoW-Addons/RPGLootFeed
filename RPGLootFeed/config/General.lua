---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local General = {}

G_RLF.options.args.general = {
	type = "group",
	handler = General,
	name = G_RLF.L["General"],
	desc = G_RLF.L["GeneralDesc1.32"],
	order = 1,
	args = {
		quickActions = {
			type = "group",
			inline = true,
			name = G_RLF.L["Quick Actions"],
			order = 1,
			args = {
				testMode = {
					type = "execute",
					name = G_RLF.L["Toggle Test Mode"],
					func = function()
						local TestMode = G_RLF.RLF:GetModule(G_RLF.SupportModule.TestMode) --[[@as RLF_TestMode]]
						TestMode:ToggleTestMode()
					end,
					order = 1,
				},
				clearRows = {
					type = "execute",
					name = G_RLF.L["Clear rows"],
					func = function()
						G_RLF.LootDisplay:HideLoot()
					end,
					order = 2,
				},
				lootHistory = {
					type = "execute",
					name = G_RLF.L["Toggle Loot History"],
					func = function()
						G_RLF.HistoryService:ToggleHistoryFrame()
					end,
					order = 3,
				},
			},
		},
		showMinimapIcon = {
			type = "toggle",
			name = G_RLF.L["Show Minimap Icon"],
			desc = G_RLF.L["ShowMinimapIconDesc"],
			width = "double",
			get = function()
				return not G_RLF.db.global.minimap.hide
			end,
			set = function(info, value)
				G_RLF.db.global.minimap.hide = not value
				if G_RLF.db.global.minimap.hide then
					G_RLF.DBIcon:Hide(addonName)
				else
					G_RLF.DBIcon:Show(addonName)
				end
			end,
			order = 2,
		},
		feedDisplay = {
			type = "group",
			inline = true,
			name = G_RLF.L["Feed Display"],
			order = 3,
			args = {
				showOneQuantity = {
					type = "toggle",
					name = G_RLF.L["Show '1' Quantity"],
					desc = G_RLF.L["ShowOneQuantityDesc"],
					width = "double",
					get = function(info, value)
						return G_RLF.db.global.misc.showOneQuantity
					end,
					set = function(info, value)
						G_RLF.db.global.misc.showOneQuantity = value
						G_RLF.LootDisplay:RefreshSampleRowsIfShown()
					end,
					order = 1,
				},
				hideAllIcons = {
					type = "toggle",
					name = G_RLF.L["Hide All Icons"],
					desc = G_RLF.L["HideAllIconsDesc"],
					width = "double",
					get = function(info, value)
						return G_RLF.db.global.misc.hideAllIcons
					end,
					set = function(info, value)
						G_RLF.db.global.misc.hideAllIcons = value
						G_RLF.LootDisplay:RefreshSampleRowsIfShown()
					end,
					order = 2,
				},
			},
		},
		lootHistoryOptions = {
			type = "group",
			inline = true,
			name = G_RLF.L["Loot History"],
			order = 4,
			args = {
				enableLootHistory = {
					type = "toggle",
					name = G_RLF.L["Enable Loot History"],
					desc = G_RLF.L["EnableLootHistoryDesc"],
					get = function()
						return G_RLF.db.global.lootHistory.enabled
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.enabled = value
						---@type RLF_LootDisplayFrame
						local frame = G_RLF.RLF_MainLootFrame
						frame:UpdateTabVisibility()
					end,
					order = 1,
				},
				lootHistorySize = {
					type = "range",
					name = G_RLF.L["Loot History Size"],
					desc = G_RLF.L["LootHistorySizeDesc"],
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled
					end,
					min = 1,
					max = 1000,
					step = 1,
					get = function()
						return G_RLF.db.global.lootHistory.historyLimit
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.historyLimit = value
					end,
					order = 2,
				},
				hideLootHistoryTab = {
					type = "toggle",
					name = G_RLF.L["Hide Loot History Tab"],
					desc = G_RLF.L["HideLootHistoryTabDesc"],
					width = "double",
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled
					end,
					get = function()
						return G_RLF.db.global.lootHistory.hideTab
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.hideTab = value
						---@type RLF_LootDisplayFrame
						local frame = G_RLF.RLF_MainLootFrame
						frame:UpdateTabAppearance()
						frame:UpdateTabVisibility()
					end,
					order = 3,
				},
				tabFreePosition = {
					type = "toggle",
					name = G_RLF.L["Free Position Loot History Tab"],
					desc = G_RLF.L["FreePositionLootHistoryTabDesc"],
					width = "double",
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled or G_RLF.db.global.lootHistory.hideTab
					end,
					get = function()
						return G_RLF.db.global.lootHistory.tabFreePosition
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.tabFreePosition = value
						---@type RLF_LootDisplayFrame
						local frame = G_RLF.RLF_MainLootFrame
						frame:UpdateTabAppearance()
						frame:UpdateTabVisibility()
					end,
					order = 4,
				},
				tabSize = {
					type = "range",
					name = G_RLF.L["Loot History Tab Size"],
					desc = G_RLF.L["LootHistoryTabSizeDesc"],
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled or G_RLF.db.global.lootHistory.hideTab
					end,
					min = 8,
					max = 64,
					step = 1,
					get = function()
						return G_RLF.db.global.lootHistory.tabSize
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.tabSize = value
						---@type RLF_LootDisplayFrame
						local frame = G_RLF.RLF_MainLootFrame
						frame:UpdateTabAppearance()
						frame:UpdateTabVisibility()
					end,
					order = 5,
				},
				tabXOffset = {
					type = "range",
					name = G_RLF.L["Loot History Tab X Offset"],
					desc = G_RLF.L["LootHistoryTabXOffsetDesc"],
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled or G_RLF.db.global.lootHistory.hideTab
					end,
					min = -3000,
					max = 3000,
					step = 1,
					get = function()
						return G_RLF.db.global.lootHistory.tabXOffset
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.tabXOffset = value
						---@type RLF_LootDisplayFrame
						local frame = G_RLF.RLF_MainLootFrame
						frame:UpdateTabAppearance()
						frame:UpdateTabVisibility()
					end,
					order = 6,
				},
				tabYOffset = {
					type = "range",
					name = G_RLF.L["Loot History Tab Y Offset"],
					desc = G_RLF.L["LootHistoryTabYOffsetDesc"],
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled or G_RLF.db.global.lootHistory.hideTab
					end,
					min = -3000,
					max = 3000,
					step = 1,
					get = function()
						return G_RLF.db.global.lootHistory.tabYOffset
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.tabYOffset = value
						---@type RLF_LootDisplayFrame
						local frame = G_RLF.RLF_MainLootFrame
						frame:UpdateTabAppearance()
						frame:UpdateTabVisibility()
					end,
					order = 7,
				},
				enableScrollWheelActivation = {
					type = "toggle",
					name = G_RLF.L["Enable Scroll Wheel History Activation"],
					desc = G_RLF.L["EnableScrollWheelActivationDesc"],
					width = "double",
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled
					end,
					get = function()
						return G_RLF.db.global.lootHistory.enableScrollWheelActivation
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.enableScrollWheelActivation = value
					end,
					order = 8,
				},
				scrollWheelDoubleScrollMode = {
					type = "toggle",
					name = G_RLF.L["Double Scroll Required"],
					desc = G_RLF.L["DoubleScrollRequiredDesc"],
					width = "double",
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled
							or not G_RLF.db.global.lootHistory.enableScrollWheelActivation
					end,
					get = function()
						return G_RLF.db.global.lootHistory.scrollWheelDoubleScrollMode
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.scrollWheelDoubleScrollMode = value
					end,
					order = 9,
				},
				scrollWheelDoubleScrollThreshold = {
					type = "select",
					name = G_RLF.L["Scroll Window (ms)"],
					desc = G_RLF.L["ScrollWindowDesc"],
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled
							or not G_RLF.db.global.lootHistory.enableScrollWheelActivation
							or not G_RLF.db.global.lootHistory.scrollWheelDoubleScrollMode
					end,
					values = {
						[500] = "500 ms",
						[1000] = "1000 ms",
						[1500] = "1500 ms",
						[2000] = "2000 ms",
						[3000] = "3000 ms",
					},
					sorting = { 500, 1000, 1500, 2000, 3000 },
					get = function()
						return G_RLF.db.global.lootHistory.scrollWheelDoubleScrollThreshold
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.scrollWheelDoubleScrollThreshold = value
					end,
					order = 10,
				},
				scrollWheelTargetWidth = {
					type = "range",
					name = G_RLF.L["Scroll Wheel Target Width"],
					desc = G_RLF.L["ScrollWheelTargetWidthDesc"],
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled
							or not G_RLF.db.global.lootHistory.enableScrollWheelActivation
					end,
					min = 0,
					max = 1000,
					step = 1,
					get = function()
						return G_RLF.db.global.lootHistory.scrollWheelTargetWidth
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.scrollWheelTargetWidth = value
						---@type RLF_LootDisplayFrame
						local frame = G_RLF.RLF_MainLootFrame
						if frame then
							frame:UpdateScrollWheelTarget()
						end
					end,
					order = 11,
				},
				scrollWheelTargetHeight = {
					type = "range",
					name = G_RLF.L["Scroll Wheel Target Height"],
					desc = G_RLF.L["ScrollWheelTargetHeightDesc"],
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled
							or not G_RLF.db.global.lootHistory.enableScrollWheelActivation
					end,
					min = 0,
					max = 1000,
					step = 1,
					get = function()
						return G_RLF.db.global.lootHistory.scrollWheelTargetHeight
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.scrollWheelTargetHeight = value
						---@type RLF_LootDisplayFrame
						local frame = G_RLF.RLF_MainLootFrame
						if frame then
							frame:UpdateScrollWheelTarget()
						end
					end,
					order = 12,
				},
				showScrollTargetBorderOnHover = {
					type = "toggle",
					name = G_RLF.L["Show Border on Hover"],
					desc = G_RLF.L["ShowScrollTargetBorderOnHoverDesc"],
					width = "double",
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled
							or not G_RLF.db.global.lootHistory.enableScrollWheelActivation
					end,
					get = function()
						return G_RLF.db.global.lootHistory.showScrollTargetBorderOnHover
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.showScrollTargetBorderOnHover = value
					end,
					order = 13,
				},
				scrollWheelTargetAnchor = {
					type = "select",
					name = G_RLF.L["Scroll Wheel Target Anchor"],
					desc = G_RLF.L["ScrollWheelTargetAnchorDesc"],
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled
							or not G_RLF.db.global.lootHistory.enableScrollWheelActivation
					end,
					values = {
						["CENTER"] = "Center",
						["TOP"] = "Top",
						["BOTTOM"] = "Bottom",
						["LEFT"] = "Left",
						["RIGHT"] = "Right",
						["TOPLEFT"] = "Top Left",
						["TOPRIGHT"] = "Top Right",
						["BOTTOMLEFT"] = "Bottom Left",
						["BOTTOMRIGHT"] = "Bottom Right",
					},
					sorting = {
						"CENTER",
						"TOP",
						"BOTTOM",
						"LEFT",
						"RIGHT",
						"TOPLEFT",
						"TOPRIGHT",
						"BOTTOMLEFT",
						"BOTTOMRIGHT",
					},
					get = function()
						return G_RLF.db.global.lootHistory.scrollWheelTargetAnchor
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.scrollWheelTargetAnchor = value
						---@type RLF_LootDisplayFrame
						local frame = G_RLF.RLF_MainLootFrame
						if frame then
							frame:UpdateScrollWheelTarget()
						end
					end,
					order = 14,
				},
				scrollWheelTargetXOffset = {
					type = "range",
					name = G_RLF.L["Scroll Wheel Target X Offset"],
					desc = G_RLF.L["ScrollWheelTargetXOffsetDesc"],
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled
							or not G_RLF.db.global.lootHistory.enableScrollWheelActivation
					end,
					min = -1000,
					max = 1000,
					step = 1,
					get = function()
						return G_RLF.db.global.lootHistory.scrollWheelTargetXOffset
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.scrollWheelTargetXOffset = value
						---@type RLF_LootDisplayFrame
						local frame = G_RLF.RLF_MainLootFrame
						if frame then
							frame:UpdateScrollWheelTarget()
						end
					end,
					order = 15,
				},
				scrollWheelTargetYOffset = {
					type = "range",
					name = G_RLF.L["Scroll Wheel Target Y Offset"],
					desc = G_RLF.L["ScrollWheelTargetYOffsetDesc"],
					disabled = function()
						return not G_RLF.db.global.lootHistory.enabled
							or not G_RLF.db.global.lootHistory.enableScrollWheelActivation
					end,
					min = -1000,
					max = 1000,
					step = 1,
					get = function()
						return G_RLF.db.global.lootHistory.scrollWheelTargetYOffset
					end,
					set = function(info, value)
						G_RLF.db.global.lootHistory.scrollWheelTargetYOffset = value
						---@type RLF_LootDisplayFrame
						local frame = G_RLF.RLF_MainLootFrame
						if frame then
							frame:UpdateScrollWheelTarget()
						end
					end,
					order = 16,
				},
			},
		},
		tooltipOptions = {
			type = "group",
			name = G_RLF.L["Tooltip Options"],
			inline = true,
			order = 5,
			args = {
				enableTooltip = {
					type = "toggle",
					name = G_RLF.L["Enable Item/Currency Tooltips"],
					desc = G_RLF.L["EnableTooltipsDesc"],
					width = "double",
					get = function(info, value)
						return G_RLF.db.global.tooltips.hover.enabled
					end,
					set = function(info, value)
						G_RLF.db.global.tooltips.hover.enabled = value
					end,
					order = 1,
				},
				onlyShiftOnEnter = {
					type = "toggle",
					name = G_RLF.L["Show only when SHIFT is held"],
					desc = G_RLF.L["OnlyShiftOnEnterDesc"],
					width = "double",
					disabled = function()
						return not G_RLF.db.global.tooltips.hover.enabled
					end,
					get = function(info, value)
						return G_RLF.db.global.tooltips.hover.onShift
					end,
					set = function(info, value)
						G_RLF.db.global.tooltips.hover.onShift = value
					end,
					order = 2,
				},
			},
		},
		interactionsOptions = {
			type = "group",
			name = G_RLF.L["Interactions"],
			desc = G_RLF.L["InteractionsDesc"],
			inline = true,
			order = 6,
			args = {
				disableMouseInCombat = {
					type = "toggle",
					name = G_RLF.L["Disable Mouse Interactions In Combat"],
					desc = G_RLF.L["DisableMouseInCombatDesc"],
					width = "double",
					get = function()
						return G_RLF.db.global.interactions.disableMouseInCombat
					end,
					set = function(info, value)
						G_RLF.db.global.interactions.disableMouseInCombat = value
						G_RLF.LootDisplay:OnPlayerCombatChange()
					end,
					order = 1,
				},
				pinOnHover = {
					type = "toggle",
					name = G_RLF.L["Lock Row Position On Hover"],
					desc = G_RLF.L["LockRowPositionOnHoverDesc"],
					width = "double",
					get = function()
						return G_RLF.db.global.interactions.pinOnHover
					end,
					set = function(info, value)
						G_RLF.db.global.interactions.pinOnHover = value
					end,
					order = 2,
				},
			},
		},
	},
}

return General
