---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build the AceConfig animations group args for the given frame ID.
--- Returns the full type="group" table ready to embed in a per-frame group.
--- @param id integer frame ID
--- @param order number position order within the parent group
--- @return table
function G_RLF.BuildAnimationsArgs(id, order)
	return {
		type = "group",
		name = G_RLF.L["Animations"],
		desc = G_RLF.L["AnimationsDesc"],
		order = order,
		args = {
			enterAnimations = {
				type = "group",
				name = G_RLF.L["Row Enter Animation"],
				desc = G_RLF.L["RowEnterAnimationDesc"],
				inline = true,
				order = 1,
				args = {
					enterAnimationType = {
						type = "select",
						name = G_RLF.L["Enter Animation Type"],
						desc = G_RLF.L["EnterAnimationTypeDesc"],
						values = {
							[G_RLF.EnterAnimationType.NONE] = G_RLF.L["None"],
							[G_RLF.EnterAnimationType.FADE] = G_RLF.L["Fade"],
							[G_RLF.EnterAnimationType.SLIDE] = G_RLF.L["Slide"],
						},
						get = function()
							return G_RLF.DbAccessor:Animations(id).enter.type
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).enter.type = value
							G_RLF.LootDisplay:UpdateEnterAnimation(id)
						end,
						order = 1,
					},
					enterAnimationDuration = {
						type = "range",
						name = G_RLF.L["Enter Animation Duration"],
						desc = G_RLF.L["EnterAnimationDurationDesc"],
						min = 0.1,
						max = 1,
						step = 0.1,
						get = function()
							return G_RLF.DbAccessor:Animations(id).enter.duration
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).enter.duration = value
							G_RLF.LootDisplay:UpdateEnterAnimation(id)
						end,
						order = 2,
					},
					enterSlideDirection = {
						type = "select",
						name = G_RLF.L["Slide Direction"],
						desc = G_RLF.L["SlideDirectionDesc"],
						hidden = function()
							return G_RLF.DbAccessor:Animations(id).enter.type ~= G_RLF.EnterAnimationType.SLIDE
						end,
						values = {
							[G_RLF.SlideDirection.LEFT] = G_RLF.L["Left"],
							[G_RLF.SlideDirection.RIGHT] = G_RLF.L["Right"],
							[G_RLF.SlideDirection.UP] = G_RLF.L["Up"],
							[G_RLF.SlideDirection.DOWN] = G_RLF.L["Down"],
						},
						get = function()
							return G_RLF.DbAccessor:Animations(id).enter.slide.direction
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).enter.slide.direction = value
							G_RLF.LootDisplay:UpdateEnterAnimation(id)
						end,
						order = 3,
					},
				},
			},
			exitAnimations = {
				type = "group",
				name = G_RLF.L["Row Exit Animation"],
				desc = G_RLF.L["RowExitAnimationDesc"],
				inline = true,
				order = 2,
				args = {
					disableExitAnimation = {
						type = "toggle",
						width = "double",
						name = G_RLF.L["Disable Automatic Exit"],
						desc = G_RLF.L["DisableAutomaticExitDesc"],
						get = function()
							return G_RLF.DbAccessor:Animations(id).exit.disable
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).exit.disable = value
							G_RLF.LootDisplay:UpdateFadeDelay(id)
						end,
						order = 0.1,
					},
					fadeOutDelay = {
						type = "range",
						name = G_RLF.L["Fade Out Delay"],
						desc = G_RLF.L["FadeOutDelayDesc"],
						min = 1,
						max = 60,
						disabled = function()
							return G_RLF.DbAccessor:Animations(id).exit.disable
						end,
						get = function()
							return G_RLF.DbAccessor:Animations(id).exit.fadeOutDelay
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).exit.fadeOutDelay = value
							G_RLF.LootDisplay:UpdateFadeDelay(id)
						end,
						order = 1,
					},
					exitAnimationType = {
						type = "select",
						name = G_RLF.L["Exit Animation Type"],
						desc = G_RLF.L["ExitAnimationTypeDesc"],
						disabled = function()
							return G_RLF.DbAccessor:Animations(id).exit.disable
						end,
						values = {
							[G_RLF.ExitAnimationType.NONE] = G_RLF.L["None"],
							[G_RLF.ExitAnimationType.FADE] = G_RLF.L["Fade"],
						},
						get = function()
							return G_RLF.DbAccessor:Animations(id).exit.type
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).exit.type = value
						end,
						order = 2,
					},
					exitAnimationDuration = {
						type = "range",
						name = G_RLF.L["Exit Animation Duration"],
						desc = G_RLF.L["ExitAnimationDurationDesc"],
						disabled = function()
							return G_RLF.DbAccessor:Animations(id).exit.disable
						end,
						min = 0.1,
						max = 3,
						step = 0.1,
						get = function()
							return G_RLF.DbAccessor:Animations(id).exit.duration
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).exit.duration = value
							G_RLF.LootDisplay:UpdateFadeDelay(id)
						end,
						order = 3,
					},
				},
			},
			hoverAnimations = {
				type = "group",
				name = G_RLF.L["Hover Animation"],
				desc = G_RLF.L["HoverAnimationDesc"],
				inline = true,
				order = 3,
				args = {
					enabled = {
						type = "toggle",
						name = G_RLF.L["Enable Hover Animation"],
						desc = G_RLF.L["EnableHoverAnimationDesc"],
						get = function()
							return G_RLF.DbAccessor:Animations(id).hover.enabled
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).hover.enabled = value
						end,
						order = 1,
					},
					alpha = {
						type = "range",
						name = G_RLF.L["Hover Alpha"],
						desc = G_RLF.L["HoverAlphaDesc"],
						min = 0,
						max = 1,
						step = 0.05,
						disabled = function()
							return not G_RLF.DbAccessor:Animations(id).hover.enabled
						end,
						get = function()
							return G_RLF.DbAccessor:Animations(id).hover.alpha
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).hover.alpha = value
						end,
						order = 2,
					},
					baseDuration = {
						type = "range",
						name = G_RLF.L["Base Duration"],
						desc = G_RLF.L["BaseDurationDesc"],
						min = 0.1,
						max = 1,
						step = 0.1,
						disabled = function()
							return not G_RLF.DbAccessor:Animations(id).hover.enabled
						end,
						get = function()
							return G_RLF.DbAccessor:Animations(id).hover.baseDuration
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).hover.baseDuration = value
						end,
						order = 3,
					},
				},
			},
			updateAnimations = {
				type = "group",
				name = G_RLF.L["Update Animations"],
				desc = G_RLF.L["UpdateAnimationsDesc"],
				inline = true,
				order = 4,
				args = {
					disableHighlight = {
						type = "toggle",
						name = G_RLF.L["Disable Highlight"],
						desc = G_RLF.L["DisableHighlightDesc"],
						get = function()
							return G_RLF.DbAccessor:Animations(id).update.disableHighlight
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).update.disableHighlight = value
						end,
						order = 1,
					},
					duration = {
						type = "range",
						name = G_RLF.L["Update Animation Duration"],
						desc = G_RLF.L["UpdateAnimationDurationDesc"],
						min = 0.1,
						max = 1,
						step = 0.1,
						disabled = function()
							return G_RLF.DbAccessor:Animations(id).update.disableHighlight
						end,
						get = function()
							return G_RLF.DbAccessor:Animations(id).update.duration
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).update.duration = value
						end,
						order = 2,
					},
					loop = {
						type = "toggle",
						name = G_RLF.L["Loop Update Highlight"],
						desc = G_RLF.L["LoopUpdateHighlightDesc"],
						disabled = function()
							return G_RLF.DbAccessor:Animations(id).update.disableHighlight
						end,
						get = function()
							return G_RLF.DbAccessor:Animations(id).update.loop
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).update.loop = value
						end,
						order = 3,
					},
				},
			},
			repositioningAnimations = {
				type = "group",
				name = G_RLF.L["Repositioning Animation"],
				desc = G_RLF.L["RepositioningAnimationDesc"],
				inline = true,
				order = 5,
				args = {
					repositioningDuration = {
						type = "range",
						name = G_RLF.L["Repositioning Duration"],
						desc = G_RLF.L["RepositioningDurationDesc"],
						min = 0.05,
						max = 0.5,
						step = 0.05,
						get = function()
							return G_RLF.DbAccessor:Animations(id).reposition.duration
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).reposition.duration = value
						end,
						order = 1,
					},
				},
			},
			timerBarAnimations = {
				type = "group",
				name = G_RLF.L["Fade Out Timer Bar"],
				desc = G_RLF.L["FadeOutTimerBarDesc"],
				inline = true,
				order = 6,
				args = {
					enabled = {
						type = "toggle",
						name = G_RLF.L["Enable Timer Bar"],
						desc = G_RLF.L["EnableTimerBarDesc"],
						get = function()
							return G_RLF.DbAccessor:Animations(id).timerBar.enabled
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).timerBar.enabled = value
							G_RLF.LootDisplay:UpdateRowStyles(id)
						end,
						order = 1,
					},
					height = {
						type = "range",
						name = G_RLF.L["Timer Bar Height"],
						desc = G_RLF.L["TimerBarHeightDesc"],
						min = 1,
						max = 10,
						step = 1,
						disabled = function()
							return not G_RLF.DbAccessor:Animations(id).timerBar.enabled
						end,
						get = function()
							return G_RLF.DbAccessor:Animations(id).timerBar.height
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).timerBar.height = value
							G_RLF.LootDisplay:UpdateRowStyles(id)
						end,
						order = 2,
					},
					yOffset = {
						type = "range",
						name = G_RLF.L["Timer Bar Y Offset"],
						desc = G_RLF.L["TimerBarYOffsetDesc"],
						min = -10,
						max = 10,
						step = 1,
						disabled = function()
							return not G_RLF.DbAccessor:Animations(id).timerBar.enabled
						end,
						get = function()
							return G_RLF.DbAccessor:Animations(id).timerBar.yOffset
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).timerBar.yOffset = value
							G_RLF.LootDisplay:UpdateRowStyles(id)
						end,
						order = 3,
					},
					color = {
						type = "color",
						name = G_RLF.L["Timer Bar Color"],
						desc = G_RLF.L["TimerBarColorDesc"],
						hasAlpha = false,
						disabled = function()
							return not G_RLF.DbAccessor:Animations(id).timerBar.enabled
						end,
						get = function()
							local color = G_RLF.DbAccessor:Animations(id).timerBar.color
							return color[1], color[2], color[3]
						end,
						set = function(info, r, g, b)
							G_RLF.DbAccessor:Animations(id).timerBar.color = { r, g, b }
							G_RLF.LootDisplay:UpdateRowStyles(id)
						end,
						order = 4,
					},
					alpha = {
						type = "range",
						name = G_RLF.L["Timer Bar Alpha"],
						desc = G_RLF.L["TimerBarAlphaDesc"],
						min = 0,
						max = 1,
						step = 0.05,
						disabled = function()
							return not G_RLF.DbAccessor:Animations(id).timerBar.enabled
						end,
						get = function()
							return G_RLF.DbAccessor:Animations(id).timerBar.alpha
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).timerBar.alpha = value
							G_RLF.LootDisplay:UpdateRowStyles(id)
						end,
						order = 5,
					},
					drainDirection = {
						type = "select",
						name = G_RLF.L["Drain Direction"],
						desc = G_RLF.L["DrainDirectionDesc"],
						values = {
							["REVERSE"] = G_RLF.L["Right to Left"],
							["NORMAL"] = G_RLF.L["Left to Right"],
						},
						disabled = function()
							return not G_RLF.DbAccessor:Animations(id).timerBar.enabled
						end,
						get = function()
							return G_RLF.DbAccessor:Animations(id).timerBar.drainDirection
						end,
						set = function(info, value)
							G_RLF.DbAccessor:Animations(id).timerBar.drainDirection = value
							G_RLF.LootDisplay:UpdateRowStyles(id)
						end,
						order = 6,
					},
				},
			},
		},
	}
end
