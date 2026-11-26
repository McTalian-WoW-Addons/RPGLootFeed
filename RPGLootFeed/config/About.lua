---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local About = {}

---@class RLF_DBGlobal
G_RLF.defaults.global = G_RLF.defaults.global or {}

---@class RLF_ConfigAbout
G_RLF.defaults.global.about = {}

About.argOrder = {
	["title"] = 1,
	["version"] = 2,
	["discordDescription"] = 3,
	["joinDiscord"] = 4,
	["issuesAndRequests"] = 5,
	["issuesLink"] = 6,
	["inGameCommunity"] = 7,
	["author"] = -4,
	["githubLink"] = -3,
	["tipsLink"] = -2,
	["attributionsHeader"] = -1.7,
	["attributions"] = -1.6,
	["credits"] = -1,
}

G_RLF.options.args.about = {
	type = "group",
	handler = About,
	name = G_RLF.L["About"],
	desc = G_RLF.L["AboutDesc"],
	order = 99,
	args = {
		title = {
			type = "header",
			name = G_RLF.L["AboutTitle"],
			order = About.argOrder.title,
		},
		version = {
			type = "description",
			name = string.format(G_RLF.L["Version"], G_RLF.addonVersion) .. "\n\n",
			order = About.argOrder.version,
		},
		discordDescription = {
			type = "description",
			fontSize = "medium",
			image = "Interface/AddOns/RPGLootFeed/Icons/logo.blp",
			name = G_RLF.L["JoinDiscordDesc"],
			order = About.argOrder.discordDescription,
		},
		joinDiscord = {
			type = "input",
			name = G_RLF.L["JoinDiscord"],
			width = "full",
			get = function()
				return "https://discord.gg/czRYVWhe33"
			end,
			order = About.argOrder.joinDiscord,
		},
		issuesAndRequests = {
			type = "description",
			name = G_RLF.L["IssuesAndRequests"],
			order = About.argOrder.issuesAndRequests,
		},
		issuesLink = {
			type = "input",
			name = G_RLF.L["GitHubIssuesLink"],
			width = "full",
			get = function()
				return "https://github.com/McTalian-WoW-Addons/RPGLootFeed/issues/new/choose"
			end,
			order = About.argOrder.issuesLink,
		},

		inGameCommunity = {
			type = "input",
			name = G_RLF.L["InGameCommunity"] .. " (" .. G_RLF.L["Experimental"] .. ")",
			desc = G_RLF.L["InGameCommunityDesc"],
			width = "full",
			get = function()
				return "zjz5YvzudWG"
			end,
			hidden = function()
				return not G_RLF:IsRetail()
			end,
			order = About.argOrder.inGameCommunity,
		},

		author = {
			type = "description",
			image = "Interface/AddOns/RPGLootFeed/Icons/mctalian_logo.png",
			name = G_RLF.L["Author"],
			order = About.argOrder.author,
		},
		githubLink = {
			type = "input",
			name = G_RLF.L["AuthorGitHub"],
			width = "full",
			get = function()
				return "https://github.com/McTalian"
			end,
			order = About.argOrder.githubLink,
		},
		tipsLink = {
			type = "input",
			name = G_RLF.L["TipsLink"],
			width = "full",
			get = function()
				return "https://buymeacoffee.com/mctalian"
			end,
			order = About.argOrder.tipsLink,
		},
		attributionsHeader = {
			type = "header",
			name = G_RLF.L["Attributions"],
			order = About.argOrder.attributionsHeader,
		},
		attributions = {
			type = "description",
			name = G_RLF.L["AttributionsDesc"],
			order = About.argOrder.attributions,
		},
		credits = {
			type = "description",
			name = function()
				local translationCredits = G_RLF.L["Credits"]
				local esMX = "* esMX by Lalz420"
				local frFR = "* frFR by polki92"
				local ruRU = "* ruRU by ZamestoTV"
				if GetLocale() == "ruRU" then
					ruRU = ruRU .. ", Карнажж (Пламегор)"
				else
					ruRU = ruRU .. ", Carnage (Flamegor)"
				end
				local zhCN = "* zhCN by byezero"
				return string.format(
					translationCredits,
					"\n",
					"\n" .. esMX .. "\n" .. frFR .. "\n" .. ruRU .. "\n" .. zhCN .. "\n" .. "\n"
				)
			end,
			order = About.argOrder.credits,
		},
	},
}
