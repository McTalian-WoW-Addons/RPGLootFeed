local busted = require("busted")
local stub = busted.stub
local embedLibs = require("RPGLootFeed_spec._mocks.Libs.embedLibUtil")
local addonNamespaceMocks = {}

--- @enum addonNamespaceMocks.LoadSections
addonNamespaceMocks.LoadSections = {
	None = 0,
	Core = 1,
	Locale = 2,
	UtilsNotifications = 2.001,
	UtilsAddonMethods = 2.01,
	UtilsAlphaHelpers = 2.02,
	UtilsList = 2.03,
	UtilsEnums = 2.04,
	UtilsGameVersionHelpers = 2.05,
	UtilsIconSkin = 2.055,
	UtilsItemInfo = 2.06,
	UtilsLogger = 2.06,
	UtilsMaps = 2.08,
	UtilsQueue = 2.09,
	Utils = 3,
	ConfigOptions = 3.01,
	ConfigFeaturesInit = 3.02,
	ConfigFeatureItemLoot = 3.03,
	ConfigFeaturePartyLoot = 3.04,
	ConfigFeatureCurrency = 3.05,
	ConfigFeatureMoney = 3.06,
	ConfigFeatureXP = 3.07,
	ConfigFeatureRep = 3.08,
	ConfigFeatureSkills = 3.09,
	ConfigFeatureTravelPoints = 3.10,
	ConfigFeatureTransmog = 3.11,
	ConfigFeaturesAll = 3.99,
	Config = 4,
	BlizzOverrides = 5,
	FeatureInternals = 5.01,
	FeatureItemLootAuction = 5.02,
	FeatureItemLoot = 5.03,
	FeaturePartyLoot = 5.04,
	FeatureCurrencyHidden = 5.05,
	FeatureCurrency = 5.06,
	FeatureMoney = 5.07,
	FeatureXP = 5.08,
	FeatureRep = 5.09,
	FeatureSkills = 5.10,
	Features = 6,
	LootDisplayFrameMixin = 6.01,
	LootDisplayRowMixin = 6.02,
	LootDisplay = 7,
	GameTesting = 8,
	All = 100,
}

--- Setup the namespace table based on the load order
--- @param loadSection addonNamespaceMocks.LoadSections The section of the addon that is being loaded
function addonNamespaceMocks:unitLoadedAfter(loadSection)
	---@class test_G_RLF: G_RLF
	local ns = {}
	if loadSection >= addonNamespaceMocks.LoadSections.Core then
		ns.addonVersion = "v1.0.0"
		ns.localeName = "RPGLootFeedLocale"
		ns.lsm = {
			MediaType = {
				FONT = "font",
			},
		}
		addonNamespaceMocks.lsm = {}
		addonNamespaceMocks.lsm.HashTable = stub(ns.lsm, "HashTable")
		addonNamespaceMocks.lsm.Fetch = stub(ns.lsm, "Fetch")
		local iconGroupMock = {}
		addonNamespaceMocks.iconGroup = {}
		addonNamespaceMocks.iconGroup.AddButton = stub(iconGroupMock, "AddButton")
		addonNamespaceMocks.iconGroup.ReSkin = stub(iconGroupMock, "ReSkin")
		ns.Masque = {}
		addonNamespaceMocks.Masque = {}
		addonNamespaceMocks.Masque.Group = stub(ns.Masque, "Group").returns(iconGroupMock)
		ns.acd = {}
		ns.DBIcon = {}
		ns.RLF = {}
		embedLibs(ns.RLF, "AceAddon-3.0")
		ns.RLF:NewAddon("RPGLootFeed", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")
		-- LibPixelPerfect-1.0 — identity PScale keeps pixel math predictable in tests.
		ns.PerfPixel = {}
		addonNamespaceMocks.PerfPixel = {}
		addonNamespaceMocks.PerfPixel.PScale = stub(ns.PerfPixel, "PScale", function(v)
			return v
		end)
		-- noQualColor is initialized in Core.lua:OnInitialize from C_Item.GetItemQualityColor.
		-- The mock returns r=1, g=0.5, b=0 for Poor quality.
		ns.noQualColor = { r = 1, g = 0.5, b = 0 }
	end
	if loadSection >= addonNamespaceMocks.LoadSections.Locale then
		require("RPGLootFeed_spec._mocks.Libs.LibStub")
		ns.L = assert(loadfile("RPGLootFeed/locale/enUS.lua"))("TestAddon", ns)
	end
	if loadSection >= addonNamespaceMocks.LoadSections.UtilsNotifications then
		ns.Notifications = {}
		addonNamespaceMocks.Notifications = {}
		addonNamespaceMocks.Notifications.CheckForNotifications = stub(ns.Notifications, "CheckForNotifications")
		addonNamespaceMocks.Notifications.GetNumUnseenNotifications =
			stub(ns.Notifications, "GetNumUnseenNotifications").returns(0)
		addonNamespaceMocks.Notifications.AddNotification = stub(ns.Notifications, "AddNotification")
		addonNamespaceMocks.Notifications.AckAllNotifications = stub(ns.Notifications, "AckAllNotifications")
		addonNamespaceMocks.Notifications.AckNotification = stub(ns.Notifications, "AckNotification")
		addonNamespaceMocks.Notifications.RemoveSeenNotifications = stub(ns.Notifications, "RemoveSeenNotifications")
		addonNamespaceMocks.Notifications.NotifyGlow = stub(ns.Notifications, "NotifyGlow")
		addonNamespaceMocks.Notifications.StopNotifyGlow = stub(ns.Notifications, "StopNotifyGlow")
	end
	if loadSection >= addonNamespaceMocks.LoadSections.UtilsAddonMethods then
		addonNamespaceMocks.fn = stub(ns, "fn", function(s, func, ...)
			if type(func) == "function" then
				return xpcall(func, _G.handledError, ...)
			end
		end)
		addonNamespaceMocks.NotifyChange = stub(ns, "NotifyChange")
		addonNamespaceMocks.Print = stub(ns, "Print")
		addonNamespaceMocks.IsRetail = stub(ns, "IsRetail").returns(true)
		addonNamespaceMocks.IsClassic = stub(ns, "IsClassic").returns(false)
		addonNamespaceMocks.IsTBCClassic = stub(ns, "IsTBCClassic").returns(false)
		addonNamespaceMocks.IsCataClassic = stub(ns, "IsCataClassic").returns(false)
		addonNamespaceMocks.IsMoPClassic = stub(ns, "IsMoPClassic").returns(false)
		addonNamespaceMocks.SendMessage = stub(ns, "SendMessage")
		addonNamespaceMocks.RGBAToHexFormat = stub(ns, "RGBAToHexFormat")
		addonNamespaceMocks.LogDebug = stub(ns, "LogDebug")
		addonNamespaceMocks.LogInfo = stub(ns, "LogInfo")
		addonNamespaceMocks.LogWarn = stub(ns, "LogWarn")
		addonNamespaceMocks.LogError = stub(ns, "LogError")
		addonNamespaceMocks.CreatePatternSegmentsForStringNumber = stub(ns, "CreatePatternSegmentsForStringNumber")
		addonNamespaceMocks.ExtractDynamicsFromPattern = stub(ns, "ExtractDynamicsFromPattern")
		addonNamespaceMocks.ExtractCurrencyID = stub(ns, "ExtractCurrencyID")
		addonNamespaceMocks.OpenOptions = stub(ns, "OpenOptions")
		addonNamespaceMocks.TableToCommaSeparatedString = stub(ns, "TableToCommaSeparatedString")
		addonNamespaceMocks.FontFlagsToString = stub(ns, "FontFlagsToString")
		-- Kept behavioural rather than inert: row and queue-label specs assert
		-- on the SetFont/SetShadowColor/SetShadowOffset calls this makes.
		addonNamespaceMocks.ApplyFontStyle = stub(
			ns,
			"ApplyFontStyle",
			function(_, fontString, fontPath, fontSize, fontFlagsString, shadowColor, offsetX, offsetY)
				shadowColor = shadowColor or {}
				fontString:SetFont(fontPath, fontSize, fontFlagsString)
				fontString:SetShadowColor(
					shadowColor[1] or 0,
					shadowColor[2] or 0,
					shadowColor[3] or 0,
					shadowColor[4] or 1
				)
				fontString:SetShadowOffset(offsetX or 1, offsetY or -1)
			end
		)
		addonNamespaceMocks.ProbeSlugSupport = stub(ns, "ProbeSlugSupport").returns(false)
		addonNamespaceMocks.GenerateGUID = stub(ns, "GenerateGUID").returns("1234567890")
		addonNamespaceMocks.IsRLFStableRelease = stub(ns, "IsRLFStableRelease").returns(true)
		addonNamespaceMocks.ParseVersion = stub(ns, "ParseVersion").returns(1, 0, 0)
		addonNamespaceMocks.CompareWithVersion = stub(ns, "CompareWithVersion").returns(0)
		addonNamespaceMocks.ExtractItemLinks = stub(ns, "ExtractItemLinks").returns({})
		-- Returns predictable wrap chars so callers can format strings in tests.
		addonNamespaceMocks.GetWrapChars = stub(ns, "GetWrapChars", function(_, _wrapChar)
			return "(", ")"
		end)
		-- Delegates to frame:IsMouseOver() so tests that set up IsMouseOver
		-- mocks continue to work. In-game this uses GetMouseFoci (Retail) with
		-- IsMouseOver fallback (Classic).
		addonNamespaceMocks.MouseIsOverFrame = stub(ns, "MouseIsOverFrame", function(_, frame)
			return frame:IsMouseOver()
		end)
	end
	if loadSection >= addonNamespaceMocks.LoadSections.UtilsAlphaHelpers then
		addonNamespaceMocks.dump = stub(ns, "dump")
		addonNamespaceMocks.ProfileFunction = stub(ns, "ProfileFunction")
	end
	if loadSection >= addonNamespaceMocks.LoadSections.UtilsList then
		addonNamespaceMocks.list = stub(ns, "list")
		addonNamespaceMocks.list.push = stub(ns.list, "push")
		addonNamespaceMocks.list.unshift = stub(ns.list, "unshift")
		addonNamespaceMocks.list.pop = stub(ns.list, "pop")
		addonNamespaceMocks.list.shift = stub(ns.list, "shift")
		addonNamespaceMocks.list.remove = stub(ns.list, "remove")
		addonNamespaceMocks.list.iterate = stub(ns.list, "iterate")
	end
	if loadSection >= addonNamespaceMocks.LoadSections.UtilsEnums then
		assert(loadfile("RPGLootFeed/utils/Enums.lua"))("TestAddon", ns)
	end
	if loadSection >= addonNamespaceMocks.LoadSections.UtilsGameVersionHelpers then
		ns.ClassicToRetail = {}
		addonNamespaceMocks.ClassicToRetail = {}
		addonNamespaceMocks.ClassicToRetail.ConvertFactionInfoByID = stub(ns.ClassicToRetail, "ConvertFactionInfoByID")
		addonNamespaceMocks.ClassicToRetail.ConvertFactionInfoByIndex =
			stub(ns.ClassicToRetail, "ConvertFactionInfoByIndex")
	end
	if loadSection >= addonNamespaceMocks.LoadSections.UtilsIconSkin then
		-- Real resolver, not a stub -- it is pure logic over ns.Masque /
		-- ns.iconGroup / ns.ElvSkins / ns.EllesmereUI.  Those handles are left
		-- unset here (nil == "addon not loaded"); specs assign the ones they
		-- need, the same way they wire up ns.iconGroup.
		assert(loadfile("RPGLootFeed/utils/IconSkin.lua"))("TestAddon", ns)
	end
	if loadSection >= addonNamespaceMocks.LoadSections.UtilsItemInfo then
		ns.ItemInfo = {}
		addonNamespaceMocks.ItemInfo = {}
		addonNamespaceMocks.ItemInfo.new = stub(ns.ItemInfo, "new")
		addonNamespaceMocks.ItemInfo.IsMount = stub(ns.ItemInfo, "IsMount")
		addonNamespaceMocks.ItemInfo.IsLegendary = stub(ns.ItemInfo, "IsLegendary")
		addonNamespaceMocks.ItemInfo.IsEligibleEquipment = stub(ns.ItemInfo, "IsEligibleEquipment")
		addonNamespaceMocks.ItemInfo.IsEquippableItem = stub(ns.ItemInfo, "IsEquippableItem")
		addonNamespaceMocks.ItemInfo.HasItemRollBonus = stub(ns.ItemInfo, "HasItemRollBonus")
		addonNamespaceMocks.ItemInfo.GetEquipmentTypeText = stub(ns.ItemInfo, "GetEquipmentTypeText")
	end
	if loadSection >= addonNamespaceMocks.LoadSections.UtilsLogger then
	end
	if loadSection >= addonNamespaceMocks.LoadSections.UtilsMaps then
		assert(loadfile("RPGLootFeed/utils/Maps.lua"))("TestAddon", ns)
	end
	if loadSection >= addonNamespaceMocks.LoadSections.UtilsQueue then
		ns.Queue = {}
		addonNamespaceMocks.Queue = {}
		addonNamespaceMocks.Queue.new = stub(ns.Queue, "new")
		addonNamespaceMocks.Queue.enqueue = stub(ns.Queue, "enqueue")
		addonNamespaceMocks.Queue.dequeue = stub(ns.Queue, "dequeue")
		addonNamespaceMocks.Queue.isEmpty = stub(ns.Queue, "isEmpty")
		addonNamespaceMocks.Queue.peek = stub(ns.Queue, "peek")
		addonNamespaceMocks.Queue.size = stub(ns.Queue, "size")
	end
	if loadSection >= addonNamespaceMocks.LoadSections.ConfigOptions then
		ns.ConfigHandlers = {}
		addonNamespaceMocks.ConfigHandlers = {}
		-- Load ConfigOptions.lua to get the canonical defaults (including frames["**"])
		assert(loadfile("RPGLootFeed/config/ConfigOptions.lua"))("TestAddon", ns)
		ns.defaults.char = ns.defaults.char or {}
		ns.defaults.locale = ns.defaults.locale or {
			factionMap = {},
			accountWideFactionMap = {},
		}
		ns.defaults.profile = ns.defaults.profile or {}
		ns.options = {
			args = {},
		}
	end
	if loadSection >= addonNamespaceMocks.LoadSections.ConfigFeaturesInit then
		ns.mainFeatureOrder = {
			ItemLoot = 1,
			PartyLoot = 2,
			Currency = 3,
			Money = 4,
			Experience = 5,
			Reputation = 6,
			Profession = 7,
			TravelPoints = 8,
			Transmog = 9,
		}
	end
	if loadSection >= addonNamespaceMocks.LoadSections.ConfigFeaturePartyLoot then
		ns.ConfigHandlers.PartyLootConfig = {}
		addonNamespaceMocks.ConfigHandlers.PartyLootConfig = {}
		addonNamespaceMocks.ConfigHandlers.PartyLootConfig.GetPositioningOptions =
			stub(ns.ConfigHandlers.PartyLootConfig, "GetPositioningOptions")
		addonNamespaceMocks.ConfigHandlers.PartyLootConfig.GetSizingOptions =
			stub(ns.ConfigHandlers.PartyLootConfig, "GetSizingOptions")
		addonNamespaceMocks.ConfigHandlers.PartyLootConfig.GetStylingOptions =
			stub(ns.ConfigHandlers.PartyLootConfig, "GetStylingOptions")
	end
	if loadSection >= addonNamespaceMocks.LoadSections.Config then
		ns.DbMigrations = {}
		addonNamespaceMocks.DbMigrations = {}
		addonNamespaceMocks.DbMigrations.Migrate = stub(ns.DbMigrations, "Migrate")
		ns.migrations = {}
		ns.DbAccessor = {}
		addonNamespaceMocks.DbAccessor = {}
		addonNamespaceMocks.DbAccessor.Sizing = stub(ns.DbAccessor, "Sizing")
		addonNamespaceMocks.DbAccessor.Positioning = stub(ns.DbAccessor, "Positioning")
		addonNamespaceMocks.DbAccessor.Styling = stub(ns.DbAccessor, "Styling")
		addonNamespaceMocks.DbAccessor.Animations = stub(ns.DbAccessor, "Animations")
		addonNamespaceMocks.DbAccessor.Feature = stub(ns.DbAccessor, "Feature")
		addonNamespaceMocks.DbAccessor.AnyFeatureConfig = stub(ns.DbAccessor, "AnyFeatureConfig")
		addonNamespaceMocks.DbAccessor.IsFeatureNeededByAnyFrame = stub(ns.DbAccessor, "IsFeatureNeededByAnyFrame")
		addonNamespaceMocks.DbAccessor.UpdateFeatureModuleState = stub(ns.DbAccessor, "UpdateFeatureModuleState")
		addonNamespaceMocks.ShouldRunMigration = stub(ns, "ShouldRunMigration").returns(false)
		ns.FramesConfig = {}
		addonNamespaceMocks.FramesConfig = {}
		addonNamespaceMocks.FramesConfig.OnInitialize = stub(ns.FramesConfig, "OnInitialize")
		addonNamespaceMocks.FramesConfig.RebuildArgs = stub(ns.FramesConfig, "RebuildArgs")
	end
	if loadSection >= addonNamespaceMocks.LoadSections.BlizzOverrides then
		addonNamespaceMocks.retryHook = stub(ns, "retryHook")
	end
	if loadSection >= addonNamespaceMocks.LoadSections.FeatureInternals then
		ns.LootElementBase = {}
		addonNamespaceMocks.LootElementBase = {}
		addonNamespaceMocks.LootElementBase.new = stub(ns.LootElementBase, "new").returns({})
		ns.FeatureBase = {}
		addonNamespaceMocks.FeatureBase = {}
		addonNamespaceMocks.FeatureBase.new = stub(ns.FeatureBase, "new").returns({})
	end
	if loadSection >= addonNamespaceMocks.LoadSections.FeatureItemLootAuction then
		ns.AuctionIntegrations = {}
		addonNamespaceMocks.AuctionIntegrations = {}
		addonNamespaceMocks.AuctionIntegrations.Init = stub(ns.AuctionIntegrations, "Init")
		addonNamespaceMocks.AuctionIntegrations.GetAHPrice = stub(ns.AuctionIntegrations, "GetAHPrice")
	end
	if loadSection >= addonNamespaceMocks.LoadSections.FeatureCurrencyHidden then
		assert(loadfile("RPGLootFeed/Features/Currency/HiddenCurrencies.lua"))("TestAddon", ns)
	end
	if loadSection >= addonNamespaceMocks.LoadSections.LootDisplay then
		assert(loadfile("RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayFrame.lua"))("TestAddon", ns)
		assert(loadfile("RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayRow/LootDisplayRow.lua"))("TestAddon", ns)
		ns.LootDisplay = {}
		embedLibs(ns.LootDisplay, "AceBucket-3.0", "AceEvent-3.0", "AceHook-3.0")
		addonNamespaceMocks.LootDisplay = {}
		addonNamespaceMocks.LootDisplay.OnPlayerCombatChange = stub(ns.LootDisplay, "OnPlayerCombatChange")
		addonNamespaceMocks.LootDisplay.GetAllFrames = stub(ns.LootDisplay, "GetAllFrames")
		addonNamespaceMocks.LootDisplay.SetBoundingBoxVisibility = stub(ns.LootDisplay, "SetBoundingBoxVisibility")
		addonNamespaceMocks.LootDisplay.ShowSampleRows = stub(ns.LootDisplay, "ShowSampleRows")
		addonNamespaceMocks.LootDisplay.HideSampleRows = stub(ns.LootDisplay, "HideSampleRows")
		addonNamespaceMocks.LootDisplay.UpdateSize = stub(ns.LootDisplay, "UpdateSize")
		addonNamespaceMocks.LootDisplay.ToggleBoundingBox = stub(ns.LootDisplay, "ToggleBoundingBox")
		addonNamespaceMocks.LootDisplay.UpdatePosition = stub(ns.LootDisplay, "UpdatePosition")
		addonNamespaceMocks.LootDisplay.UpdateRowPositions = stub(ns.LootDisplay, "UpdateRowPositions")
		addonNamespaceMocks.LootDisplay.UpdateStrata = stub(ns.LootDisplay, "UpdateStrata")
		addonNamespaceMocks.LootDisplay.UpdateRowStyles = stub(ns.LootDisplay, "UpdateRowStyles")
		addonNamespaceMocks.LootDisplay.UpdateEnterAnimation = stub(ns.LootDisplay, "UpdateEnterAnimation")
		addonNamespaceMocks.LootDisplay.UpdateFadeDelay = stub(ns.LootDisplay, "UpdateFadeDelay")
		addonNamespaceMocks.LootDisplay.BAG_UPDATE_DELAY = stub(ns.LootDisplay, "BAG_UPDATE_DELAY")
		addonNamespaceMocks.LootDisplay.OnLootReady = stub(ns.LootDisplay, "OnLootReady")
		addonNamespaceMocks.LootDisplay.OnRowReturn = stub(ns.LootDisplay, "OnRowReturn")
		addonNamespaceMocks.LootDisplay.HideLoot = stub(ns.LootDisplay, "HideLoot")
	end
	-- No namespace changes in GameTesting
	-- if loadSection >= addonNamespaceMocks.LoadSections.GameTesting then
	-- end
	if loadSection >= addonNamespaceMocks.LoadSections.All then
		ns.db = {
			---@type RLF_DBGlobal
			global = {
				lastVersionLoaded = "v1.0.0",
				logger = {},
				migrationVersion = 0,
				about = {},
				animations = {
					exit = {},
				},
				blizzOverrides = {},
				currency = {},
				item = {
					itemQualitySettings = {},
					enableIcon = true,
				},
				prof = {
					skillColor = { 1, 1, 1, 1 },
					enableIcon = true,
				},
				partyLoot = {
					enabled = true,
					separateFrame = false,
					itemQualityFilter = {},
					hideServerNames = false,
					onlyEpicAndAboveInInstance = false,
					onlyEpicAndAboveInParty = false,
					onlyEpicAndAboveInRaid = false,
					positioning = {},
					sizing = {},
					styling = {},
					ignoreItemIds = {},
					enableIcon = true,
				},
				money = {
					enableIcon = true,
				},
				xp = {
					enableIcon = true,
					experienceTextColor = { 1, 1, 1, 1 },
				},
				rep = {
					enableIcon = true,
					defaultRepColor = { 1, 1, 1, 1 },
				},
				travelPoints = {
					enableIcon = true,
					textColor = { 1, 1, 1, 1 },
				},
				transmog = {
					enableIcon = true,
				},
				styling = {},
				lootHistory = {},
				minimap = {},
				tooltips = {},
				sizing = {},
				positioning = {},
				notifications = {},
				misc = {
					hideAllIcons = false,
				},
				warbandFactions = {
					cachedFactionDetailsById = {},
					count = 0,
				},
				--- Per-frame configuration, mirroring the real defaults populated by
				--- migration v8.  Frame 1 has all features enabled (except partyLoot);
				--- added here so code that reads db.global.frames works in tests.
				---@type table<integer, RLF_FrameConfig>
				frames = {
					[1] = {
						name = "Main",
						positioning = {},
						sizing = {},
						styling = {},
						animations = {},
						features = {
							itemLoot = { enabled = true },
							partyLoot = { enabled = true },
							currency = { enabled = true },
							money = { enabled = true },
							experience = { enabled = true },
							reputation = { enabled = true },
							profession = { enabled = true },
							travelPoints = { enabled = true },
							transmog = { enabled = true },
						},
					},
				},
				nextFrameId = 2,
			},
			locale = {
				factionMap = {},
				accountWideFactionMap = {
					["Faction A"] = 1,
				},
			},
			profile = {},
			char = {
				repFactions = {
					count = 0,
					cachedFactionDetailsById = {},
				},
			},
		}
	end

	return ns
end

return addonNamespaceMocks
