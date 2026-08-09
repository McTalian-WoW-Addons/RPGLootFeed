---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

G_RLF.addonVersion = "@project-version@"

---@class RPGLootFeed: AceAddon, AceConsole-3.0, AceEvent-3.0, AceHook-3.0, AceTimer-3.0
---@field public GetModule fun(self: RPGLootFeed, name: string): RLF_Module
---@field public NewModule fun(self: RPGLootFeed, name: string, ...: string): RLF_Module
local RLF = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")
RLF:SetDefaultModuleState(true)
RLF:SetDefaultModulePrototype({
	fn = function(s, func, ...)
		return G_RLF.fn(s, func, ...)
	end,
})

---@class RLF_Module: AceModule
---@field protected fn fun(self: RLF_Module, func: function, ...?: any): any

local function DbMigrations()
	local latestMigrationVersion = #G_RLF.migrations
	if G_RLF.db.global.migrationVersion == nil or G_RLF.db.global.migrationVersion == 0 then
		G_RLF:LogDebug(
			"Seeding migrationVersion to " .. latestMigrationVersion .. " on fresh install and skipping migrations."
		)
		G_RLF.db.global.migrationVersion = latestMigrationVersion
		return
	end

	for version, migration in ipairs(G_RLF.migrations) do
		local ok, err = pcall(function()
			migration:run()
		end)
		if not ok then
			local colorMessage = "|cffff4444"
				.. string.format(G_RLF.L["MigrationError"], version)
				.. "|r "
				.. tostring(err)
			RLF:Print(colorMessage)
			RLF:Print(G_RLF.L["Issues"])
		end
	end
end

G_RLF.localeName = addonName .. "Locale"
G_RLF.lsm = LibStub("LibSharedMedia-3.0")
G_RLF.Masque = LibStub and LibStub("Masque", true)
G_RLF.ElvUI = nil
G_RLF.ElvSkins = nil
if ElvUI then
	G_RLF.ElvUI = ElvUI
	---@type ElvUIApp, ElvUILocale, ElvUIPrivateDb, ElvUIProfileDb, ElvUIGlobalDb
	local E, _, _, _, _ = unpack(ElvUI)
	local S = E:GetModule("Skins") --[[@as ElvUISkinsModule]]
	if S then
		G_RLF.ElvSkins = S
	end
end
---@type EllesmereUIApp?
G_RLF.EllesmereUI = EllesmereUI
---@type EllesmereUISkinFacade?
G_RLF.EUISkin = nil
if EllesmereUI and EllesmereUI.RegisterSkin then
	-- Registration is free: EllesmereUI queues it and only dispatches at
	-- PLAYER_LOGIN, and never at all if the user turned third-party skinning
	-- off in its options.  So the facade may stay nil -- call sites guard on
	-- G_RLF.EUISkin rather than on G_RLF.EllesmereUI.
	EllesmereUI.RegisterSkin(addonName, function(S)
		G_RLF.EUISkin = S
	end)
end
G_RLF.iconGroup = G_RLF.Masque and G_RLF.Masque:Group(addonName)
local dbName = addonName .. "DB"
G_RLF.acd = LibStub("AceConfigDialog-3.0") --[[@as AceConfigDialog-3.0]]
G_RLF.DBIcon = LibStub("LibDBIcon-1.0")
G_RLF.PerfPixel = LibStub("LibPixelPerfect-1.0")

local TestMode
function RLF:OnInitialize()
	---@class RLF_DB : AceDBObject-3.0
	---@field global RLF_DBGlobal
	---@field locale RLF_DBLocale
	---@field profile RLF_DBProfile
	G_RLF.db = LibStub("AceDB-3.0"):New(dbName, G_RLF.defaults, true)
	if G_RLF.db.global.guid == nil then
		-- This is not an identifier associated with your character, but a way
		-- to identify a unique installation of the addon. It cannot be used to
		-- identify a specific character or account.
		G_RLF.db.global.guid = G_RLF:GenerateGUID()
	end
	G_RLF.noQualColor = {}
	G_RLF.noQualColor.r, G_RLF.noQualColor.g, G_RLF.noQualColor.b = C_Item.GetItemQualityColor(G_RLF.ItemQualEnum.Poor)
	DbMigrations()
	G_RLF.FramesConfig:OnInitialize()
	LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, G_RLF.options)
	G_RLF.acd:SetDefaultSize(addonName, 900, 600)
	local rlfLDB = LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
		type = "launcher",
		icon = "Interface\\AddOns\\RPGLootFeed\\Icons\\logo.blp",
		OnClick = function(og_frame, button)
			G_RLF:OpenOptions(button)
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(
				G_RLF:RGBAToHexFormat(1, 0.5, 0, 1)
					.. addonName
					.. "|r "
					.. G_RLF:RGBAToHexFormat(0.2, 0.5, 0.4, 1)
					.. G_RLF.addonVersion
					.. "|r"
			)
			tooltip:AddLine(" ")
			local unseenNotifications = G_RLF.Notifications:GetNumUnseenNotifications()
			if unseenNotifications > 0 then
				local notifStr = string.format(G_RLF.L["You have Notifications"], unseenNotifications)
				tooltip:AddLine(notifStr, 1, 1, 1, 1)
				tooltip:AddLine(" ")
			end
			tooltip:AddLine(G_RLF.L["LauncherLeftClick"], 1, 1, 1, 1)
			if G_RLF.db.global.lootHistory.enabled or unseenNotifications > 0 then
				tooltip:AddLine(G_RLF.L["LauncherRightClick"], 1, 1, 1, 1)
			end
		end,
	})

	local lsm = G_RLF.lsm
	lsm:Register(lsm.MediaType.FONT, "BAR SADY Regular", "Interface\\AddOns\\RPGLootFeed\\Fonts\\BAR_SADY_Variable.ttf")
	lsm:Register(
		lsm.MediaType.SOUND,
		"LittleRobotSoundFactory - Pickup_Gold_04",
		"Interface\\AddOns\\RPGLootFeed\\Sounds\\Pickup_Gold_04.ogg"
	)
	-- Details also provides this, but in case someone doesn't have it installed
	-- RLF will register it as well.
	lsm:Register("border", "1 Pixel", [[Interface\Buttons\WHITE8X8]])
	G_RLF.DBIcon:Register(addonName, rlfLDB, G_RLF.db.global.minimap)
	G_RLF.DBIcon:AddButtonToCompartment(addonName)
	self:Hook(G_RLF.acd, "Open", "OnOptionsOpen")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterChatCommand("rlf", "SlashCommand")
	self:RegisterChatCommand("RLF", "SlashCommand")
	self:RegisterChatCommand("rpglootfeed", "SlashCommand")
	self:RegisterChatCommand("rpgLootFeed", "SlashCommand")

	if EditModeManagerFrame then
		EventRegistry:RegisterCallback("EditMode.Enter", function()
			G_RLF.LootDisplay:SetBoundingBoxVisibility(true)
		end)
		EventRegistry:RegisterCallback("EditMode.Exit", function()
			G_RLF.LootDisplay:SetBoundingBoxVisibility(false)
		end)
	end

	TestMode = self:GetModule(G_RLF.SupportModule.TestMode) --[[@as RLF_TestMode]]
end

function RLF:SlashCommand(msg, editBox)
	G_RLF:fn(function()
		--@alpha@
		local start, stop = msg:find("test ")
		--@end-alpha@
		if msg == "test" then
			TestMode:ToggleTestMode()
		--@alpha@
		-- Quick testing of item links
		elseif start then
			local itemLink = msg:sub(stop + 1)
			local itemModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.ItemLoot) --[[@as RLF_ItemLoot]]
			itemModule:CHAT_MSG_LOOT(
				"CHAT_MSG_LOOT",
				itemLink,
				"",
				"",
				"",
				UnitName("player"),
				"",
				"",
				"",
				"",
				"",
				"",
				GetPlayerGuid()
			)
		elseif msg == "i" then
			TestMode:IntegrationTest()
		elseif msg == "c" then
			TestMode:ConfigTest()
		elseif msg == "prof" then
			TestMode:ProfessionTest()
		elseif msg == "notif" then
			G_RLF.Notifications:AddNotification("TEST_NOTIF", "Test Notification")
		--@end-alpha@
		elseif msg == "clear" then
			G_RLF.LootDisplay:HideLoot()
		elseif msg == "log" then
			---@type RLF_Logger
			local loggerModule = self:GetModule(G_RLF.SupportModule.Logger) --[[@as RLF_Logger]]
			loggerModule:Show()
		elseif msg == "log clear" then
			---@type RLF_Logger
			local loggerModule = self:GetModule(G_RLF.SupportModule.Logger) --[[@as RLF_Logger]]
			loggerModule:ClearLog()
		elseif msg == "history" and G_RLF.db.global.lootHistory.enabled then
			---@type RLF_LootDisplayFrame
			G_RLF.HistoryService:ToggleHistoryFrame()
		else
			G_RLF.acd:Open(addonName)
		end
	end)
end

local currentVersion = "@project-version@"
function RLF:PLAYER_ENTERING_WORLD(event, isLogin, isReload)
	if self.optionsFrame == nil then
		self.optionsFrame = G_RLF.acd:AddToBlizOptions(addonName, addonName)
	end

	G_RLF.RLF_MainLootFrame:UpdateTabVisibility()

	local isNewVersion = currentVersion ~= G_RLF.db.global.lastVersionLoaded
	if isLogin and isReload == false and isNewVersion then
		G_RLF.db.global.lastVersionLoaded = currentVersion
		G_RLF.Notifications:AddNotification(
			G_RLF.NotificationKeys.WELCOME,
			G_RLF:RGBAToHexFormat(1, 0.5, 0, 1) .. G_RLF.L["Welcome"] .. "|r",
			G_RLF:RGBAToHexFormat(0.2, 0.5, 0.4, 1) .. currentVersion .. "|r"
		)
		local notifModule = G_RLF.RLF:GetModule(G_RLF.SupportModule.Notifications) --[[@as RLF_Notifications]]
		if notifModule then
			notifModule:ViewAllNotifications()
		end
	end
	if G_RLF.db.global.blizzOverrides.enableAutoLoot then
		C_CVar.SetCVar("autoLootDefault", "1")
	end
	G_RLF.AuctionIntegrations:Init()
	local moneyConfig = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
	if moneyConfig.overrideMoneyLootSound then
		MuteSoundFile(G_RLF.GameSounds.LOOT_SMALL_COIN)
	else
		UnmuteSoundFile(G_RLF.GameSounds.LOOT_SMALL_COIN)
	end
end

local optionsFrame
local isOpen = false
function RLF:OnOptionsOpen(...)
	local _, name, container, path = ...
	G_RLF:fn(function()
		if container then
			return
		end
		if name == addonName and not isOpen then
			isOpen = true
			G_RLF.LootDisplay:SetBoundingBoxVisibility(true)
			-- Show sample rows in existing frames
			G_RLF.LootDisplay:ShowSampleRows()
			self:ScheduleTimer(function()
				optionsFrame = G_RLF.acd.OpenFrames[name]
				if self:IsHooked(optionsFrame, "Hide") then
					self:Unhook(optionsFrame, "Hide")
				end
				if optionsFrame and optionsFrame.Hide then
					self:Hook(optionsFrame, "Hide", "OnOptionsClose", true)
				end
			end, 0.25)
		end
	end)
end

function RLF:OnOptionsClose(...)
	G_RLF:fn(function()
		isOpen = false
		G_RLF.LootDisplay:SetBoundingBoxVisibility(false)
		-- Hide sample rows when options close
		G_RLF.LootDisplay:HideSampleRows()
		self:Unhook(optionsFrame, "Hide")
		optionsFrame = nil
	end)
end

G_RLF.RLF = RLF

return RLF
