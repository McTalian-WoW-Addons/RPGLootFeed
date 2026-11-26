---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build the AceConfig options group for Loot Rolls on the given frame.
--- Called from the config system by function name.
---@param frameId integer
---@param order number
---@return table
function G_RLF.LootRolls:BuildConfigArgs(frameId, order)
	local function fc()
		return G_RLF.db.global.frames[frameId].features.lootRolls
	end
	local function refresh()
		G_RLF.LootDisplay:RefreshSampleRowsIfShown()
	end

	--- A toggle bound to a boolean Loot Rolls option that defaults to on.
	local function toggle(key, name, desc, order, extra)
		local option = {
			type = "toggle",
			name = name,
			desc = desc,
			width = "double",
			get = function()
				return fc()[key] ~= false
			end,
			set = function(_, value)
				fc()[key] = value
				refresh()
			end,
			order = order,
		}
		for k, v in pairs(extra or {}) do
			option[k] = v
		end
		return option
	end

	local function buttonsOff()
		return fc().showRollButtons == false
	end

	return {
		type = "group",
		name = G_RLF.L["Loot Rolls Config"],
		order = order,
		args = {
			interactionsWarning = {
				type = "description",
				name = "|cFFFFAA00" .. G_RLF.L["DisableAllInteractionFeatureWarning"] .. "|r", -- nocheck
				order = 0.9,
				hidden = function()
					return not G_RLF.DbAccessor:AllInteractionDisabled(frameId)
				end,
			},
			enableLootRolls = {
				type = "toggle",
				name = G_RLF.L["Enable Loot Rolls in Feed"],
				desc = G_RLF.L["EnableLootRollsDesc"],
				width = "double",
				get = function()
					return fc().enabled
				end,
				set = function(_, value)
					fc().enabled = value
					G_RLF.DbAccessor:UpdateFeatureModuleState("lootRolls")
					refresh()
				end,
				order = 1,
			},
			buttons = {
				type = "group",
				inline = true,
				name = G_RLF.L["Roll Buttons"],
				order = 2,
				args = {
					showRollButtons = toggle(
						"showRollButtons",
						G_RLF.L["Show Roll Buttons"],
						G_RLF.L["ShowRollButtonsDesc"],
						1
					),
					rollButtonSize = {
						type = "range",
						name = G_RLF.L["Roll Button Size"],
						desc = G_RLF.L["RollButtonSizeDesc"],
						min = 12,
						max = 32,
						step = 1,
						disabled = buttonsOff,
						get = function()
							return fc().buttonSize
						end,
						set = function(_, value)
							fc().buttonSize = value
							refresh()
						end,
						order = 2,
					},
					rollButtonSpacing = {
						type = "range",
						name = G_RLF.L["Roll Button Spacing"],
						desc = G_RLF.L["RollButtonSpacingDesc"],
						min = 0,
						max = 16,
						step = 1,
						disabled = buttonsOff,
						get = function()
							return fc().buttonGap
						end,
						set = function(_, value)
							fc().buttonGap = value
							refresh()
						end,
						order = 3,
					},
					rollButtonPadding = {
						type = "range",
						name = G_RLF.L["Roll Button Padding"],
						desc = G_RLF.L["RollButtonPaddingDesc"],
						min = 0,
						max = 32,
						step = 1,
						disabled = buttonsOff,
						get = function()
							return fc().buttonPadding
						end,
						set = function(_, value)
							fc().buttonPadding = value
							refresh()
						end,
						order = 4,
					},
				},
			},
			results = {
				type = "group",
				inline = true,
				name = G_RLF.L["Roll Results"],
				order = 3,
				args = {
					resultsDisplaySeconds = {
						type = "range",
						name = G_RLF.L["Results Display Time"],
						desc = G_RLF.L["ResultsDisplayTimeDesc"],
						min = 5,
						max = 300,
						step = 1,
						get = function()
							return fc().resultsDisplaySeconds
						end,
						set = function(_, value)
							fc().resultsDisplaySeconds = value
						end,
						order = 1,
					},
					showWaitingCount = toggle(
						"showWaitingCount",
						G_RLF.L["Show Waiting Count"],
						G_RLF.L["ShowWaitingCountDesc"],
						2
					),
					showLeader = toggle(
						"showLeader",
						G_RLF.L["Show Current Leader"],
						G_RLF.L["ShowCurrentLeaderDesc"],
						3
					),
					showRollNumbers = toggle(
						"showRollNumbers",
						G_RLF.L["Show Roll Numbers"],
						G_RLF.L["ShowRollNumbersDesc"],
						4
					),
					compactWinners = toggle(
						"compactWinners",
						G_RLF.L["Compact Winners"],
						G_RLF.L["CompactWinnersDesc"],
						4.5,
						{
							get = function()
								return fc().compactWinners == true
							end,
						}
					),
					useClassColors = toggle(
						"useClassColors",
						G_RLF.L["Class Colored Names"],
						G_RLF.L["ClassColoredNamesDesc"],
						5
					),
					winColor = {
						type = "color",
						name = G_RLF.L["Win Color"],
						desc = G_RLF.L["WinColorDesc"],
						hasAlpha = false,
						get = function()
							local c = fc().winColor
							return c[1], c[2], c[3], c[4]
						end,
						set = function(_, r, g, b, a)
							fc().winColor = { r, g, b, a }
							refresh()
						end,
						order = 6,
					},
					mutedColor = {
						type = "color",
						name = G_RLF.L["Muted Color"],
						desc = G_RLF.L["MutedColorDesc"],
						hasAlpha = false,
						get = function()
							local c = fc().mutedColor
							return c[1], c[2], c[3], c[4]
						end,
						set = function(_, r, g, b, a)
							fc().mutedColor = { r, g, b, a }
							refresh()
						end,
						order = 7,
					},
				},
			},
			display = {
				type = "group",
				inline = true,
				name = G_RLF.L["Roll Display"],
				order = 4,
				args = {
					showTimerBar = toggle(
						"showTimerBar",
						G_RLF.L["Show Countdown Bar"],
						G_RLF.L["ShowCountdownBarDesc"],
						1
					),
					showRollTooltip = toggle(
						"showRollTooltip",
						G_RLF.L["Show Roll Details Tooltip"],
						G_RLF.L["ShowRollDetailsTooltipDesc"],
						2
					),
				},
			},
		},
	}
end

return {}
