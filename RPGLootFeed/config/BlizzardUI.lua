---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local BlizzardUI = {}

---@class RLF_DBGlobal
G_RLF.defaults.global = G_RLF.defaults.global or {}

---@class RLF_ConfigBlizzardUI
G_RLF.defaults.global.blizzOverrides = {
	enableAutoLoot = false,
	disableBlizzLootToasts = false,
	disableBlizzMoneyAlerts = false,
	bossBannerConfig = G_RLF.DisableBossBanner.ENABLED,
	disableBlizzLootHistoryAutoShow = false,
	hideBlizzLootRollFrames = false,
}

G_RLF.options.args.blizz = {
	type = "group",
	handler = BlizzardUI,
	name = G_RLF.L["Blizzard UI"],
	desc = G_RLF.L["BlizzUIDesc"],
	order = 2,
	args = {
		lootBehavior = {
			type = "group",
			inline = true,
			name = G_RLF.L["Loot Behavior"],
			desc = G_RLF.L["LootBehaviorDesc"],
			order = 1,
			args = {
				enableAutoLoot = {
					type = "toggle",
					name = G_RLF.L["Enable Auto Loot"],
					desc = G_RLF.L["EnableAutoLootDesc"],
					get = function(info, value)
						return G_RLF.db.global.blizzOverrides.enableAutoLoot
					end,
					set = function(info, value)
						C_CVar.SetCVar("autoLootDefault", value and "1" or "0")
						G_RLF.db.global.blizzOverrides.enableAutoLoot = value
					end,
					order = 1,
				},
				alerts = {
					type = "header",
					name = G_RLF.L["Alerts"],
					order = 2,
				},
				disableLootToast = {
					type = "toggle",
					name = G_RLF.L["Disable Loot Toasts"],
					desc = G_RLF.L["DisableLootToastDesc"],
					width = "full",
					get = function(info, value)
						return G_RLF.db.global.blizzOverrides.disableBlizzLootToasts
					end,
					set = function(info, value)
						G_RLF.db.global.blizzOverrides.disableBlizzLootToasts = value
					end,
					order = 3,
				},
				disableMoneyAlert = {
					type = "toggle",
					name = G_RLF.L["Disable Money Alerts"],
					desc = G_RLF.L["DisableMoneyAlertsDesc"],
					width = "full",
					get = function(info, value)
						return G_RLF.db.global.blizzOverrides.disableBlizzMoneyAlerts
					end,
					set = function(info, value)
						G_RLF.db.global.blizzOverrides.disableBlizzMoneyAlerts = value
					end,
					order = 4,
				},
				bossBanner = {
					type = "select",
					name = G_RLF.L["Disable Boss Banner Elements"],
					desc = G_RLF.L["DisableBossBannerDesc"],
					get = function(info, value)
						return G_RLF.db.global.blizzOverrides.bossBannerConfig
					end,
					set = function(info, value)
						G_RLF.db.global.blizzOverrides.bossBannerConfig = value
					end,
					width = "double",
					values = {
						[G_RLF.DisableBossBanner.ENABLED] = G_RLF.L["Do not disable BossBanner"],
						[G_RLF.DisableBossBanner.FULLY_DISABLE] = G_RLF.L["Disable All BossBanner"],
						[G_RLF.DisableBossBanner.DISABLE_LOOT] = G_RLF.L["Disable All BossBanner Loot"],
						[G_RLF.DisableBossBanner.DISABLE_MY_LOOT] = G_RLF.L["Only Disable My BossBanner Loot"],
						[G_RLF.DisableBossBanner.DISABLE_GROUP_LOOT] = G_RLF.L["Disable Party/Raid Loot"],
					},
					order = 5,
				},
				groupLoot = {
					type = "header",
					name = G_RLF.L["Group Loot"],
					order = 6,
				},
				disableLootHistoryAutoShow = {
					type = "toggle",
					name = G_RLF.L["Disable Loot History Auto-Open"],
					desc = G_RLF.L["DisableLootHistoryAutoOpenDesc"],
					width = "full",
					get = function()
						return G_RLF.db.global.blizzOverrides.disableBlizzLootHistoryAutoShow
					end,
					set = function(_, value)
						G_RLF.db.global.blizzOverrides.disableBlizzLootHistoryAutoShow = value
						G_RLF.RLF:GetModule(G_RLF.BlizzModule.LootHistory):ApplyAutoShowSetting()
					end,
					order = 7,
				},
				hideLootRollFrames = {
					type = "toggle",
					name = G_RLF.L["Hide Blizzard Loot Roll Windows"],
					desc = G_RLF.L["HideBlizzLootRollFramesDesc"],
					width = "full",
					get = function()
						return G_RLF.db.global.blizzOverrides.hideBlizzLootRollFrames
					end,
					set = function(_, value)
						G_RLF.db.global.blizzOverrides.hideBlizzLootRollFrames = value
						G_RLF.RLF:GetModule(G_RLF.BlizzModule.LootRollFrames):Refresh()
					end,
					order = 8,
				},
			},
		},
		chatFilters = {
			type = "group",
			inline = true,
			name = G_RLF.L["Chat Filters"],
			desc = G_RLF.L["ChatFiltersDesc"],
			order = 2,
			args = {
				disableLootChatMessages = {
					type = "execute",
					name = G_RLF.L["Disable Loot Chat Messages"],
					desc = G_RLF.L["DisableLootChatMessagesDesc"],
					width = "double",
					func = function()
						ChatFrameUtil.ForEachChatFrame(function(frame)
							ChatFrame_RemoveMessageGroup(frame, "LOOT")
						end)
						G_RLF:Print(G_RLF.L["Item Loot messages Disabled"])
					end,
					order = 1,
				},
				disableCurrencyChatMessages = {
					type = "execute",
					name = G_RLF.L["Disable Currency Chat Messages"],
					desc = G_RLF.L["DisableCurrencyChatMessagesDesc"],
					width = "double",
					func = function()
						ChatFrameUtil.ForEachChatFrame(function(frame)
							ChatFrame_RemoveMessageGroup(frame, "CURRENCY")
						end)
						G_RLF:Print(G_RLF.L["Currency messages Disabled"])
					end,
					order = 2,
				},
				disableMoneyChatMessages = {
					type = "execute",
					name = G_RLF.L["Disable Money Chat Messages"],
					desc = G_RLF.L["DisableMoneyChatMessagesDesc"],
					width = "double",
					func = function()
						ChatFrameUtil.ForEachChatFrame(function(frame)
							ChatFrame_RemoveMessageGroup(frame, "MONEY")
						end)
						G_RLF:Print(G_RLF.L["Money messages Disabled"])
					end,
					order = 3,
				},
				disableXpChatMessages = {
					type = "execute",
					name = G_RLF.L["Disable Experience Chat Messages"],
					desc = G_RLF.L["DisableExperienceChatMessagesDesc"],
					width = "double",
					func = function()
						ChatFrameUtil.ForEachChatFrame(function(frame)
							ChatFrame_RemoveMessageGroup(frame, "COMBAT_XP_GAIN")
						end)
						G_RLF:Print(G_RLF.L["XP messages Disabled"])
					end,
					order = 4,
				},
				disableRepChatMessages = {
					type = "execute",
					name = G_RLF.L["Disable Reputation Chat Messages"],
					desc = G_RLF.L["DisableReputationChatMessagesDesc"],
					width = "double",
					func = function()
						ChatFrameUtil.ForEachChatFrame(function(frame)
							ChatFrame_RemoveMessageGroup(frame, "COMBAT_FACTION_CHANGE")
						end)
						G_RLF:Print(G_RLF.L["Rep messages Disabled"])
					end,
					order = 5,
				},
				disableSkillChatMessages = {
					type = "execute",
					name = G_RLF.L["Disable Skill Chat Messages"],
					desc = G_RLF.L["DisableSkillChatMessagesDesc"],
					width = "double",
					func = function()
						ChatFrameUtil.ForEachChatFrame(function(frame)
							ChatFrame_RemoveMessageGroup(frame, "SKILL")
							ChatFrame_RemoveMessageGroup(frame, "TRADESKILLS")
						end)
						G_RLF:Print(G_RLF.L["Skill messages Disabled"])
					end,
					order = 6,
				},
			},
		},
	},
}
