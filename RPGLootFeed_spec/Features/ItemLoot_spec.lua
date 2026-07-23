---@diagnostic disable: need-check-nil
local assert = require("luassert")
local match = require("luassert.match")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local spy = busted.spy
local stub = busted.stub

describe("ItemLoot Module", function()
	local _ = match._
	---@type RLF_ItemLoot, table
	local ItemLoot, ns, sendMessageSpy, soundServiceMock

	--- Build a minimal ItemInfo-like stub with sensible defaults.
	--- @param overrides? table
	local function makeItemInfo(overrides)
		local base = {
			itemId = 18803,
			itemName = "Finkle's Lava Dredger",
			itemQuality = 2,
			itemTexture = 123456,
			sellPrice = 10000,
			itemLevel = 60,
			itemEquipLoc = "",
			itemLink = "|cffa335ee|Hitem:18803::::::::60:::::|h[Finkle's Lava Dredger]|h|r",
			IsMount = function()
				return false
			end,
			IsLegendary = function()
				return false
			end,
			IsEligibleEquipment = function()
				return false
			end,
			IsEquippableItem = function()
				return false
			end,
			IsQuestItem = function()
				return false
			end,
			IsAppearanceCollected = function()
				return true
			end,
			IsKeystone = function()
				return false
			end,
			HasItemRollBonus = function()
				return false
			end,
			GetDisplayQuality = function()
				return 4
			end,
			GetEquipmentTypeText = function()
				return nil
			end,
			GetItemRollText = function()
				return ""
			end,
			GetUpgradeText = function()
				return ""
			end,
		}
		if overrides then
			for k, v in pairs(overrides) do
				base[k] = v
			end
		end
		return base
	end

	before_each(function()
		sendMessageSpy = spy.new(function() end)

		-- Build minimal ns from scratch – no nsMocks framework needed.
		-- Only fields actually referenced by ItemLoot.lua and LootElementBase.lua
		-- at load time or as G_RLF.X lookups in function bodies are included.
		-- G_RLF.db, G_RLF.equipSlotMap, G_RLF.AuctionIntegrations are intentionally
		-- present as runtime stubs but absent from the "captured as locals" block.
		ns = {
			-- Captured as locals by ItemLoot.lua at load time.
			ItemQualEnum = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 },
			FeatureModule = { ItemLoot = "ItemLoot" },
			Expansion = { CATA = 10, MOP = 11 },
			-- FeatureModule references replaced with string "ItemLoot"
			AtlasIconCoefficients = {},
			PricesEnum = {
				Vendor = "Vendor",
				AH = "AH",
				VendorAH = "VendorAH",
				AHVendor = "AHVendor",
				Highest = "Highest",
			},
			DbAccessor = {
				Styling = function(_, _)
					return { secondaryFontSize = 12 }
				end,
				IsFeatureNeededByAnyFrame = function()
					return true
				end,
				AnyFeatureConfig = function(_, featureKey)
					if featureKey == "itemLoot" then
						return ns.db.global.item
					end
					return nil
				end,
				Animations = function(_, frameId)
					return ns.db.global.animations
				end,
			},
			Frames = { MAIN = "MAIN" },
			-- Log methods for LootElementBase and FeatureBase logging injections
			LogDebug = spy.new(function() end),
			LogInfo = spy.new(function() end),
			LogWarn = spy.new(function() end),
			LogError = spy.new(function() end),
			RGBAToHexFormat = function()
				return "|cFFFFFFFF"
			end,
			SendMessage = sendMessageSpy,
			-- ItemInfo stub: default returns nil (item not in cache).
			-- Tests that exercise loot paths override ns.ItemInfo.new directly.
			ItemInfo = {
				new = function()
					return nil
				end,
			},
			-- Runtime lookups inside function bodies (not captured as locals).
			equipSlotMap = { INVTYPE_HEAD = 1, INVTYPE_CHEST = 5 },
			AuctionIntegrations = {
				activeIntegration = {
					GetAHPrice = function()
						return nil
					end,
				},
			},
			db = {
				global = {
					animations = { exit = { fadeOutDelay = 3 } },
					item = {
						enabled = true,
						enableIcon = true,
						itemQualitySettings = {
							[0] = { enabled = true, duration = 0 },
							[1] = { enabled = true, duration = 0 },
							[2] = { enabled = true, duration = 3 },
							[3] = { enabled = true, duration = 3 },
							[4] = { enabled = true, duration = 3 },
							[5] = { enabled = true, duration = 3 },
						},
						textStyleOverrides = {
							quest = { enabled = false, color = { 1, 0.82, 0, 1 } },
						},
						pricesForSellableItems = "Vendor",
						vendorIconTexture = "Interface/Icons/inv_misc_coin_01",
						auctionHouseIconTexture = "Interface/Icons/inv_misc_coin_02",
						sounds = {
							mounts = { enabled = false, sound = "" },
							legendary = { enabled = false, sound = "" },
							betterThanEquipped = { enabled = false, sound = "" },
							transmog = { enabled = false, sound = "" },
						},
						itemHighlights = {
							mounts = false,
							legendary = false,
							betterThanEquipped = false,
							quest = false,
							tertiaryOrSocket = false,
							transmog = false,
						},
						itemCountTextEnabled = false,
						itemCountTextColor = { 1, 1, 1, 1 },
						itemCountTextWrapChar = nil,
					},
					misc = {
						hideAllIcons = false,
						showOneQuantity = false,
					},
				},
			},
		}

		-- Load real LootElementBase so elements are fully constructed.
		assert(loadfile("RPGLootFeed/Features/_Internals/LootElementBase.lua"))("TestAddon", ns)
		assert(loadfile("RPGLootFeed/utils/FeatureRegistry.lua"))("TestAddon", ns)
		assert.is_not_nil(ns.LootElementBase)

		-- Load TextTemplateEngine so DI can resolve it for ItemLoot.
		assert(loadfile("RPGLootFeed/Features/_Internals/TextTemplateEngine.lua"))("TestAddon", ns)
		assert.is_not_nil(ns.TextTemplateEngine)

		-- Setup minimal DI container so FeatureBase mock resolves deps.
		ns.DI = {
			registry = {},
			Register = function(self, k, v)
				self.registry[k] = v
			end,
			Resolve = function(self, k)
				return self.registry[k]
			end,
		}
		ns.DI:Register("LootElementBase", ns.LootElementBase)
		ns.DI:Register("ItemQualEnum", ns.ItemQualEnum)
		ns.DI:Register("ItemInfo", ns.ItemInfo)
		ns.DI:Register("TextTemplateEngine", ns.TextTemplateEngine)
		ns.DI:Register("IsRetail", function()
			return false
		end)

		-- WoWAPI adapter injected via DI
		local defaultAdapter = {
			GetExpansionLevel = function()
				return 0
			end,
			UnitName = function()
				return "Player"
			end,
			UnitClass = function()
				return "Warrior", "WARRIOR"
			end,
			UnitLevel = function()
				return 60
			end,
			IssecretValue = function()
				return false
			end,
			GetPlayerGuid = function()
				return "Player-1234-ABCD1234"
			end,
			GetInventoryItemLink = function()
				return nil
			end,
			GetItemQualityColor = function()
				return 1, 1, 1
			end,
			GetCoinTextureString = function(p)
				return tostring(p)
			end,
			CreateAtlasMarkup = function(icon)
				return "[" .. icon .. "]"
			end,
			GetAHPrice = function()
				return nil
			end,
			GetItemInfo = function()
				return nil
			end,
			GetItemIDForItemInfo = function()
				return 18803
			end,
			GetItemCount = function()
				return 1
			end,
			GetItemStatDelta = function()
				return {}
			end,
		}
		ns.DI:Register("WoWAPI.ItemLoot", defaultAdapter)

		-- SoundService mock injected via DI
		soundServiceMock = {
			PlaySound = spy.new(function()
				return true
			end),
		}
		ns.DI:Register("SoundService", soundServiceMock)

		-- Mock FeatureBase – returns a minimal stub module so ItemLoot tests
		-- are completely independent of AceAddon plumbing.  The stub resolves
		-- DI dependencies and injects logging methods.
		ns.FeatureBase = {
			new = function(_, name, depsOrMixin, ...)
				local deps = {}
				local mixins = {}
				if type(depsOrMixin) == "table" then
					deps = depsOrMixin
					mixins = { ... }
				else
					mixins = { depsOrMixin, ... }
				end

				local module = {
					moduleName = name,
					Enable = function() end,
					Disable = function() end,
					IsEnabled = function()
						return true
					end,
					RegisterEvent = function() end,
					UnregisterEvent = function() end,
					RegisterBucketEvent = function() end,
					UnregisterBucket = function() end,
				}

				-- Resolve DI dependencies from ns.DI
				for fieldName, depName in pairs(deps.di or {}) do
					module[fieldName] = ns.DI and ns.DI:Resolve(depName)
				end

				-- Inject logging that delegates to ns logging spies
				if deps.logging then
					module.LogDebug = function(self, msg, src, typ, ...)
						(ns.LogDebug or function() end)(msg, src or "TestAddon", typ or self.moduleName, ...)
					end
					module.LogInfo = function(self, msg, src, typ, ...)
						(ns.LogInfo or function() end)(msg, src or "TestAddon", typ or self.moduleName, ...)
					end
					module.LogWarn = function(self, msg, src, typ, ...)
						(ns.LogWarn or function() end)(msg, src or "TestAddon", typ or self.moduleName, ...)
					end
					module.LogError = function(self, msg, src, typ, ...)
						(ns.LogError or function() end)(msg, src or "TestAddon", typ or self.moduleName, ...)
					end
				end

				return module
			end,
		}

		-- Load ItemLoot – all external dependency locals are captured from ns
		-- at load time via DI.
		ItemLoot = assert(loadfile("RPGLootFeed/Features/ItemLoot/ItemLoot.lua"))("TestAddon", ns)

		-- Per-test adapter overrides: reset to defaults each test.
		-- Tests override individual methods on this table as needed.
		ItemLoot.itemLootApi = {
			GetExpansionLevel = function()
				return 0
			end,
			UnitName = function()
				return "Player"
			end,
			UnitClass = function()
				return "Warrior", "WARRIOR"
			end,
			UnitLevel = function()
				return 60
			end,
			IssecretValue = function()
				return false
			end,
			GetPlayerGuid = function()
				return "Player-1234-ABCD1234"
			end,
			GetInventoryItemLink = function()
				return nil
			end,
			GetItemQualityColor = function()
				return 1, 1, 1
			end,
			GetCoinTextureString = function(p)
				return tostring(p)
			end,
			CreateAtlasMarkup = function(icon)
				return "[" .. icon .. "]"
			end,
			GetAHPrice = function()
				return nil
			end,
			GetItemInfo = function()
				return nil
			end,
			GetItemIDForItemInfo = function()
				return 18803
			end,
			GetItemCount = function()
				return 1
			end,
			GetItemStatDelta = function()
				return {}
			end,
		}
	end)

	describe("lifecycle", function()
		it("has expected interface functions after load", function()
			assert.is_function(ItemLoot.OnInitialize)
			assert.is_function(ItemLoot.OnEnable)
			assert.is_function(ItemLoot.OnDisable)
			assert.is_function(ItemLoot.SetEquippableArmorClass)
			assert.is_function(ItemLoot.OnItemReadyToShow)
			assert.is_function(ItemLoot.ShowItemLoot)
			assert.is_function(ItemLoot.BuildPayload)
		end)

		it("exposes itemLootApi on the module", function()
			assert.is_table(ItemLoot.itemLootApi)
		end)

		it("enables when any frame needs itemLoot", function()
			ns.DbAccessor.IsFeatureNeededByAnyFrame = function()
				return true
			end
			spy.on(ItemLoot, "Enable")
			spy.on(ItemLoot, "Disable")

			ItemLoot:OnInitialize()

			assert.spy(ItemLoot.Enable).was.called(1)
			assert.spy(ItemLoot.Disable).was_not.called()
		end)

		it("disables when no frame needs itemLoot", function()
			ns.DbAccessor.IsFeatureNeededByAnyFrame = function()
				return false
			end
			spy.on(ItemLoot, "Enable")
			spy.on(ItemLoot, "Disable")

			ItemLoot:OnInitialize()

			assert.spy(ItemLoot.Disable).was.called(1)
			assert.spy(ItemLoot.Enable).was_not.called()
		end)

		it("initializes pendingItemRequests on OnInitialize", function()
			ItemLoot:OnInitialize()

			assert.is_table(ItemLoot.pendingItemRequests)
		end)

		it("registers events on OnEnable", function()
			spy.on(ItemLoot, "RegisterEvent")

			ItemLoot:OnEnable()

			assert.spy(ItemLoot.RegisterEvent).was.called_with(_, "CHAT_MSG_LOOT")
			assert.spy(ItemLoot.RegisterEvent).was.called_with(_, "GET_ITEM_INFO_RECEIVED")
		end)

		it("unregisters events on OnDisable", function()
			spy.on(ItemLoot, "UnregisterEvent")

			ItemLoot:OnDisable()

			assert.spy(ItemLoot.UnregisterEvent).was.called_with(_, "CHAT_MSG_LOOT")
			assert.spy(ItemLoot.UnregisterEvent).was.called_with(_, "GET_ITEM_INFO_RECEIVED")
		end)

		it("calls SetEquippableArmorClass when expansion is in CATA-MOP range", function()
			ItemLoot.itemLootApi.GetExpansionLevel = function()
				return 10 -- CATA
			end
			spy.on(ItemLoot, "SetEquippableArmorClass")

			ItemLoot:OnEnable()

			assert.spy(ItemLoot.SetEquippableArmorClass).was.called(1)
		end)

		it("does not call SetEquippableArmorClass outside CATA-MOP range", function()
			ItemLoot.itemLootApi.GetExpansionLevel = function()
				return 9 -- before CATA
			end
			spy.on(ItemLoot, "SetEquippableArmorClass")

			ItemLoot:OnEnable()

			assert.spy(ItemLoot.SetEquippableArmorClass).was_not.called()
		end)
	end)

	describe("SetEquippableArmorClass", function()
		it("returns early for caster classes (MAGE)", function()
			ItemLoot.itemLootApi.UnitClass = function()
				return "Mage", "MAGE"
			end
			-- Should not error and should not set armorClassMapping
			ItemLoot:SetEquippableArmorClass()
			-- No error = pass
		end)

		it("registers bucket event at low level for non-casters", function()
			ItemLoot.itemLootApi.UnitClass = function()
				return "Warrior", "WARRIOR"
			end
			ItemLoot.itemLootApi.UnitLevel = function()
				return 20 -- below 40
			end
			spy.on(ItemLoot, "RegisterBucketEvent")

			ItemLoot:SetEquippableArmorClass()

			assert.spy(ItemLoot.RegisterBucketEvent).was.called_with(_, "PLAYER_LEVEL_UP", 1, "SetEquippableArmorClass")
		end)

		it("sets legacy armor class mapping below level 40", function()
			ItemLoot.itemLootApi.UnitClass = function()
				return "Warrior", "WARRIOR"
			end
			ItemLoot.itemLootApi.UnitLevel = function()
				return 20
			end
			ns.legacyArmorClassMappingLowLevel = { sentinel = true }

			ItemLoot:SetEquippableArmorClass()

			assert.equals(ns.legacyArmorClassMappingLowLevel, ns.armorClassMapping)
		end)

		it("sets standard armor class mapping at level 40+", function()
			ItemLoot.itemLootApi.UnitClass = function()
				return "Warrior", "WARRIOR"
			end
			ItemLoot.itemLootApi.UnitLevel = function()
				return 60
			end
			ns.standardArmorClassMapping = { sentinel = true }

			ItemLoot:SetEquippableArmorClass()

			assert.equals(ns.standardArmorClassMapping, ns.armorClassMapping)
		end)
	end)

	describe("CHAT_MSG_LOOT", function()
		local GUID = "Player-1234-ABCD1234"
		local ITEM_LINK = "|cffa335ee|Hitem:18803::::::::60:::::|h[Finkle's Lava Dredger]|h|r"

		before_each(function()
			ItemLoot:OnInitialize()
			ItemLoot.itemLootApi.GetPlayerGuid = function()
				return GUID
			end
		end)

		it("ignores messages flagged as secret values", function()
			ItemLoot.itemLootApi.IssecretValue = function()
				return true
			end
			spy.on(ItemLoot, "ShowItemLoot")
			local msg = "You receive loot: " .. ITEM_LINK

			ItemLoot:CHAT_MSG_LOOT("CHAT_MSG_LOOT", msg, "Player", nil, nil, nil, nil, nil, nil, nil, nil, nil, GUID)

			assert.spy(ItemLoot.ShowItemLoot).was_not.called()
		end)

		it("ignores raid loot history messages", function()
			spy.on(ItemLoot, "ShowItemLoot")
			local msg = "|HlootHistory:1:18803:" .. ITEM_LINK

			ItemLoot:CHAT_MSG_LOOT("CHAT_MSG_LOOT", msg, "Player", nil, nil, nil, nil, nil, nil, nil, nil, nil, GUID)

			assert.spy(ItemLoot.ShowItemLoot).was_not.called()
		end)

		it("ignores loot from other players (Retail: guid mismatch)", function()
			ItemLoot.isRetail = function()
				return true
			end
			spy.on(ItemLoot, "ShowItemLoot")
			local msg = "You receive loot: " .. ITEM_LINK
			local otherGuid = "Other-1234-DEADBEEF"

			ItemLoot:CHAT_MSG_LOOT(
				"CHAT_MSG_LOOT",
				msg,
				"Player",
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				otherGuid
			)

			assert.spy(ItemLoot.ShowItemLoot).was_not.called()
		end)

		it("ignores loot from other players (Classic: playerName2 mismatch)", function()
			ItemLoot.isRetail = function()
				return false
			end
			ItemLoot.itemLootApi.UnitName = function()
				return "MyChar"
			end
			spy.on(ItemLoot, "ShowItemLoot")
			local msg = "You receive loot: " .. ITEM_LINK

			ItemLoot:CHAT_MSG_LOOT(
				"CHAT_MSG_LOOT",
				msg,
				"Player",
				nil,
				nil,
				nil,
				"OtherChar",
				nil,
				nil,
				nil,
				nil,
				nil,
				nil
			)

			assert.spy(ItemLoot.ShowItemLoot).was_not.called()
		end)

		it("processes own loot (Retail: guid match)", function()
			ItemLoot.isRetail = function()
				return true
			end
			local showSpy = spy.on(ItemLoot, "ShowItemLoot")
			local msg = "You receive loot: " .. ITEM_LINK

			ItemLoot:CHAT_MSG_LOOT("CHAT_MSG_LOOT", msg, "Player", nil, nil, nil, nil, nil, nil, nil, nil, nil, GUID)

			assert.spy(showSpy).was.called(1)
		end)

		it("processes own loot (Classic: playerName2 match)", function()
			ItemLoot.isRetail = function()
				return false
			end
			ItemLoot.itemLootApi.UnitName = function()
				return "MyChar"
			end
			local showSpy = spy.on(ItemLoot, "ShowItemLoot")
			local msg = "You receive loot: " .. ITEM_LINK

			ItemLoot:CHAT_MSG_LOOT(
				"CHAT_MSG_LOOT",
				msg,
				"Player",
				nil,
				nil,
				"MyChar",
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil
			)

			assert.spy(showSpy).was.called(1)
		end)

		it("passes correct itemLink to ShowItemLoot for single-item message", function()
			ItemLoot.isRetail = function()
				return true
			end
			local capturedLink
			stub(ItemLoot, "ShowItemLoot", function(_, _, link, _)
				capturedLink = link
			end)
			local msg = "You receive loot: " .. ITEM_LINK

			ItemLoot:CHAT_MSG_LOOT("CHAT_MSG_LOOT", msg, "Player", nil, nil, nil, nil, nil, nil, nil, nil, nil, GUID)

			assert.equals(ITEM_LINK, capturedLink)
		end)

		it("handles item upgrade (2 item links): fromLink and itemLink both passed", function()
			ItemLoot.isRetail = function()
				return true
			end
			local capturedFrom, capturedLink
			stub(ItemLoot, "ShowItemLoot", function(_, _, link, from)
				capturedLink = link
				capturedFrom = from
			end)
			local fromLink = "|cffa335ee|Hitem:18789::::::::60:::::|h[Old Item]|h|r"
			local msg = "You upgrade " .. fromLink .. " to " .. ITEM_LINK

			ItemLoot:CHAT_MSG_LOOT("CHAT_MSG_LOOT", msg, "Player", nil, nil, nil, nil, nil, nil, nil, nil, nil, GUID)

			assert.equals(fromLink, capturedFrom)
			assert.equals(ITEM_LINK, capturedLink)
		end)
	end)

	describe("GET_ITEM_INFO_RECEIVED", function()
		local ITEM_ID = 18803
		local ITEM_LINK = "|cffa335ee|Hitem:18803::::::::60:::::|h[Finkle's Lava Dredger]|h|r"

		before_each(function()
			ItemLoot:OnInitialize()
		end)

		it("ignores unknown itemIDs not in pendingItemRequests", function()
			spy.on(ItemLoot, "OnItemReadyToShow")

			ItemLoot:GET_ITEM_INFO_RECEIVED("GET_ITEM_INFO_RECEIVED", ITEM_ID, true)

			assert.spy(ItemLoot.OnItemReadyToShow).was_not.called()
		end)

		it("calls OnItemReadyToShow on success with valid ItemInfo", function()
			local info = makeItemInfo()
			ns.ItemInfo.new = function()
				return info
			end
			ItemLoot.pendingItemRequests[ITEM_ID] = { ITEM_LINK, 1, nil }
			spy.on(ItemLoot, "OnItemReadyToShow")

			ItemLoot:GET_ITEM_INFO_RECEIVED("GET_ITEM_INFO_RECEIVED", ITEM_ID, true)

			assert.spy(ItemLoot.OnItemReadyToShow).was.called(1)
			assert.is_nil(ItemLoot.pendingItemRequests[ITEM_ID])
		end)

		it("errors when success=false for a pending item", function()
			ItemLoot.pendingItemRequests[ITEM_ID] = { ITEM_LINK, 1, nil }

			assert.has_error(function()
				ItemLoot:GET_ITEM_INFO_RECEIVED("GET_ITEM_INFO_RECEIVED", ITEM_ID, false)
			end)
		end)

		it("returns early without calling OnItemReadyToShow when ItemInfo:new returns nil", function()
			ns.ItemInfo.new = function()
				return nil
			end
			ItemLoot.pendingItemRequests[ITEM_ID] = { ITEM_LINK, 1, nil }
			spy.on(ItemLoot, "OnItemReadyToShow")

			ItemLoot:GET_ITEM_INFO_RECEIVED("GET_ITEM_INFO_RECEIVED", ITEM_ID, true)

			assert.spy(ItemLoot.OnItemReadyToShow).was_not.called()
		end)
	end)

	describe("BuildPayload", function()
		it("constructs payload with base fields", function()
			local info = makeItemInfo()
			local payload = ItemLoot:BuildPayload(info, 1, nil)

			assert.is_not_nil(payload)
			assert.equals("ItemLoot", payload.type)
			assert.equals(1, payload.quantity)
			assert.is_function(payload.textFn)
			assert.is_function(payload.secondaryTextFn)
			assert.is_function(payload.itemCountFn)
		end)

		it("sets payload.key to itemLink", function()
			local info = makeItemInfo()
			local payload = ItemLoot:BuildPayload(info, 1, nil)

			assert.equals(info.itemLink, payload.key)
		end)

		it("sets payload.icon when icons are enabled", function()
			local info = makeItemInfo()
			local payload = ItemLoot:BuildPayload(info, 1, nil)

			assert.equals(info.itemTexture, payload.icon)
		end)

		it("sets icon to nil when item icons are disabled", function()
			ns.db.global.item.enableIcon = false
			local info = makeItemInfo()
			local payload = ItemLoot:BuildPayload(info, 1, nil)

			assert.is_nil(payload.icon)
		end)

		it("sets icon to nil when hideAllIcons is set", function()
			ns.db.global.misc.hideAllIcons = true
			local info = makeItemInfo()
			local payload = ItemLoot:BuildPayload(info, 1, nil)

			assert.is_nil(payload.icon)
		end)

		it("sets isLink = true", function()
			local info = makeItemInfo()
			local payload = ItemLoot:BuildPayload(info, 1, nil)

			assert.is_true(payload.isLink)
		end)

		it("sets topLeftText and topLeftColor for equippable non-poor items", function()
			ItemLoot.itemLootApi.GetItemQualityColor = function()
				return 0.5, 0.5, 1
			end
			local info = makeItemInfo({
				itemQuality = 3,
				itemLevel = 55,
				IsEquippableItem = function()
					return true
				end,
			})
			local payload = ItemLoot:BuildPayload(info, 1, nil)

			assert.equals("55", payload.topLeftText)
			assert.same({ 0.5, 0.5, 1 }, payload.topLeftColor)
		end)

		it("does not set topLeftText for non-equippable items", function()
			local info = makeItemInfo({ itemQuality = 3 })
			-- IsEquippableItem defaults to false in makeItemInfo
			local payload = ItemLoot:BuildPayload(info, 1, nil)

			assert.is_nil(payload.topLeftText)
		end)

		it("key gets UPGRADE_ prefix when fromLink is provided", function()
			local info = makeItemInfo()
			local fromLink = "|cffa335ee|Hitem:18789::::::::60:::::|h[Old]|h|r"
			local payload = ItemLoot:BuildPayload(info, 1, fromLink)

			assert.matches("^UPGRADE_", payload.key)
		end)

		it("applies quest color to r/g/b/a when quest style override is enabled", function()
			ns.db.global.item.textStyleOverrides.quest.enabled = true
			ns.db.global.item.textStyleOverrides.quest.color = { 1, 0.82, 0, 1 }
			local info = makeItemInfo({
				IsQuestItem = function()
					return true
				end,
			})
			local payload = ItemLoot:BuildPayload(info, 1, nil)

			assert.equals(1, payload.r)
			assert.equals(0.82, payload.g)
			assert.equals(0, payload.b)
			assert.equals(1, payload.a)
		end)

		it("does not set r/g/b/a for non-quest items", function()
			local info = makeItemInfo()
			local payload = ItemLoot:BuildPayload(info, 1, nil)

			assert.is_nil(payload.r)
			assert.is_nil(payload.g)
			assert.is_nil(payload.b)
		end)

		describe("textFn", function()
			it("returns bare itemLink when no truncatedLink is provided", function()
				local info = makeItemInfo()
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				assert.equals(info.itemLink, payload.textFn(nil, nil))
			end)

			it("returns only the link with no quantity suffix", function()
				ns.db.global.misc.showOneQuantity = true
				local info = makeItemInfo()
				local payload = ItemLoot:BuildPayload(info, 3, nil)

				local text = payload.textFn(0, "[Link]")
				assert.equals("[Link]", text)
			end)

			it("omits quantity suffix when showOneQuantity is false and quantity is 1", function()
				ns.db.global.misc.showOneQuantity = false
				local info = makeItemInfo()
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				local text = payload.textFn(0, "[Link]")
				assert.equals("[Link]", text)
			end)
		end)

		describe("amountTextFn", function()
			it("returns quantity suffix when showOneQuantity is true and quantity > 1", function()
				ns.db.global.misc.showOneQuantity = true
				local info = makeItemInfo()
				local payload = ItemLoot:BuildPayload(info, 3, nil)

				assert.equals("x3", payload.amountTextFn(0))
			end)

			it("returns empty string when showOneQuantity is false and quantity is 1", function()
				ns.db.global.misc.showOneQuantity = false
				local info = makeItemInfo()
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				assert.equals("", payload.amountTextFn(0))
			end)
		end)

		describe("filter metadata", function()
			it("includes filterItemQuality in payload", function()
				local info = makeItemInfo({ itemQuality = 2 })
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				assert.is_not_nil(payload)
				assert.equals(2, payload.filterItemQuality)
			end)

			it("includes filterItemId in payload", function()
				local info = makeItemInfo({ itemId = 18803, itemQuality = 2 })
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				assert.is_not_nil(payload)
				assert.equals(18803, payload.filterItemId)
			end)

			it("builds payload regardless of quality tier enabled state (filter is per-frame)", function()
				ns.db.global.item.itemQualitySettings[2] = { enabled = false, duration = 3 }
				local info = makeItemInfo({ itemQuality = 2 })
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				-- Quality filtering now happens in LootDisplayFrame:PassesPerFrameFilters
				assert.is_not_nil(payload)
			end)

			it("does not set showForSeconds (duration is resolved per-frame in BootstrapFromElement)", function()
				-- Quality duration overrides are now looked up in the frame's own
				-- itemQualitySettings at display time, not baked into the payload.
				local info = makeItemInfo({ itemQuality = 4 })
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				assert.is_nil(payload.showForSeconds)
			end)
		end)

		describe("highlight", function()
			it("highlight is false when no conditions match", function()
				local info = makeItemInfo()
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				assert.is_false(payload.highlight)
			end)

			it("highlight is true for mounts when itemHighlights.mounts is enabled", function()
				ns.db.global.item.itemHighlights.mounts = true
				local info = makeItemInfo({
					IsMount = function()
						return true
					end,
				})
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				assert.is_true(payload.highlight)
			end)

			it("highlight is true for legendary items when itemHighlights.legendary is enabled", function()
				ns.db.global.item.itemHighlights.legendary = true
				local info = makeItemInfo({
					IsLegendary = function()
						return true
					end,
				})
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				assert.is_true(payload.highlight)
			end)
		end)

		describe("sound service (via OnItemReadyToShow)", function()
			before_each(function()
				ItemLoot:OnInitialize()
			end)

			it("plays mount sound when mount sound is enabled and item is a mount", function()
				ns.db.global.item.sounds.mounts = { enabled = true, sound = "Interface/Sounds/mount.ogg" }
				local info = makeItemInfo({
					IsMount = function()
						return true
					end,
				})

				ItemLoot:OnItemReadyToShow(info, 1, nil)

				assert.spy(soundServiceMock.PlaySound).was.called_with(_, "Interface/Sounds/mount.ogg")
			end)

			it("plays legendary sound when legendary sound is enabled and item is legendary", function()
				ns.db.global.item.sounds.legendary = { enabled = true, sound = "Interface/Sounds/legendary.ogg" }
				local info = makeItemInfo({
					IsLegendary = function()
						return true
					end,
				})

				ItemLoot:OnItemReadyToShow(info, 1, nil)

				assert.spy(soundServiceMock.PlaySound).was.called_with(_, "Interface/Sounds/legendary.ogg")
			end)

			it("does not play sound when no conditions match", function()
				local info = makeItemInfo()

				ItemLoot:OnItemReadyToShow(info, 1, nil)

				assert.spy(soundServiceMock.PlaySound).was_not.called()
			end)
		end)

		describe("itemCountFn", function()
			it("returns nil when itemCountTextEnabled is false", function()
				ns.db.global.item.itemCountTextEnabled = false
				local info = makeItemInfo()
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				local result = payload.itemCountFn()

				assert.is_nil(result)
			end)

			it("returns item count and options when enabled and item is in cache", function()
				ns.db.global.item.itemCountTextEnabled = true
				ItemLoot.itemLootApi.GetItemInfo = function()
					return "Finkle's Lava Dredger"
				end
				ItemLoot.itemLootApi.GetItemCount = function()
					return 5
				end
				local info = makeItemInfo()
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				local count, options = payload.itemCountFn()

				assert.equals(5, count)
				assert.is_table(options)
			end)

			it("returns nil when GetItemInfo fails (item not in cache)", function()
				ns.db.global.item.itemCountTextEnabled = true
				ItemLoot.itemLootApi.GetItemInfo = function()
					error("item not cached")
				end
				local info = makeItemInfo()
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				local result = payload.itemCountFn()

				assert.is_nil(result)
			end)

			it("returns nil when GetItemInfo returns nil name", function()
				ns.db.global.item.itemCountTextEnabled = true
				ItemLoot.itemLootApi.GetItemInfo = function()
					return nil
				end
				local info = makeItemInfo()
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				local result = payload.itemCountFn()

				assert.is_nil(result)
			end)
		end)
	end)
end)
