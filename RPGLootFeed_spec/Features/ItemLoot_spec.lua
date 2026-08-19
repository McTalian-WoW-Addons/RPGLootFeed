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
	local ItemLoot, ns, sendMessageSpy

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
			Frames = { MAIN = 1 },
			Frames = { MAIN = "MAIN" },
			-- WoWAPI namespace: ItemLoot.lua captures G_RLF.WoWAPI.ItemLoot as
			-- _itemLootAdapter at load time.  The spec replaces _itemLootAdapter
			-- with a full mock after loadfile, so the table just needs to exist.
			WoWAPI = { ItemLoot = {} },
			-- Log closure wrappers call these as G_RLF:Method(...) so self is ns.
			LogDebug = spy.new(function() end),
			LogInfo = spy.new(function() end),
			LogWarn = spy.new(function() end),
			LogError = spy.new(function() end),
			IsRetail = function()
				return false
			end,
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
		assert.is_not_nil(ns.LootElementBase)

		-- FeatureBase stub – independent of AceAddon plumbing.
		-- ItemLoot uses AceBucket so RegisterBucketEvent / UnregisterBucket are needed.
		ns.FeatureBase = {
			new = function(_, name)
				return {
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
			end,
		}

		-- Load ItemLoot – all external dependency locals are captured from ns
		-- at load time.
		ItemLoot = assert(loadfile("RPGLootFeed/Features/ItemLoot/ItemLoot.lua"))("TestAddon", ns)

		-- Inject a fresh no-op adapter per-test so WoW API calls are controlled
		-- without patching _G directly.  Tests override individual methods as needed.
		ItemLoot._itemLootAdapter = {
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
			GetGoldAmountSymbol = function()
				return "g"
			end,
			GetSilverAmountSymbol = function()
				return "s"
			end,
			GetCopperAmountSymbol = function()
				return "c"
			end,
			CreateAtlasMarkup = function(icon)
				return "[" .. icon .. "]"
			end,
			PlaySoundFile = function()
				return true, 1
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
			assert.is_function(ItemLoot.PlaySoundIfEnabled)
		end)

		it("exposes _itemLootAdapter on the module", function()
			assert.is_table(ItemLoot._itemLootAdapter)
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
			ItemLoot._itemLootAdapter.GetExpansionLevel = function()
				return 10 -- CATA
			end
			spy.on(ItemLoot, "SetEquippableArmorClass")

			ItemLoot:OnEnable()

			assert.spy(ItemLoot.SetEquippableArmorClass).was.called(1)
		end)

		it("does not call SetEquippableArmorClass outside CATA-MOP range", function()
			ItemLoot._itemLootAdapter.GetExpansionLevel = function()
				return 9 -- before CATA
			end
			spy.on(ItemLoot, "SetEquippableArmorClass")

			ItemLoot:OnEnable()

			assert.spy(ItemLoot.SetEquippableArmorClass).was_not.called()
		end)
	end)

	describe("SetEquippableArmorClass", function()
		it("returns early for caster classes (MAGE)", function()
			ItemLoot._itemLootAdapter.UnitClass = function()
				return "Mage", "MAGE"
			end
			-- Should not error and should not set armorClassMapping
			ItemLoot:SetEquippableArmorClass()
			-- No error = pass
		end)

		it("registers bucket event at low level for non-casters", function()
			ItemLoot._itemLootAdapter.UnitClass = function()
				return "Warrior", "WARRIOR"
			end
			ItemLoot._itemLootAdapter.UnitLevel = function()
				return 20 -- below 40
			end
			spy.on(ItemLoot, "RegisterBucketEvent")

			ItemLoot:SetEquippableArmorClass()

			assert.spy(ItemLoot.RegisterBucketEvent).was.called_with(_, "PLAYER_LEVEL_UP", 1, "SetEquippableArmorClass")
		end)

		it("sets legacy armor class mapping below level 40", function()
			ItemLoot._itemLootAdapter.UnitClass = function()
				return "Warrior", "WARRIOR"
			end
			ItemLoot._itemLootAdapter.UnitLevel = function()
				return 20
			end
			ns.legacyArmorClassMappingLowLevel = { sentinel = true }

			ItemLoot:SetEquippableArmorClass()

			assert.equals(ns.legacyArmorClassMappingLowLevel, ns.armorClassMapping)
		end)

		it("sets standard armor class mapping at level 40+", function()
			ItemLoot._itemLootAdapter.UnitClass = function()
				return "Warrior", "WARRIOR"
			end
			ItemLoot._itemLootAdapter.UnitLevel = function()
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
			ItemLoot._itemLootAdapter.GetPlayerGuid = function()
				return GUID
			end
		end)

		it("ignores messages flagged as secret values", function()
			ItemLoot._itemLootAdapter.IssecretValue = function()
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
			ns.IsRetail = function()
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
			ns.IsRetail = function()
				return false
			end
			ItemLoot._itemLootAdapter.UnitName = function()
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
				"OtherChar",
				nil,
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
			ns.IsRetail = function()
				return true
			end
			local showSpy = spy.on(ItemLoot, "ShowItemLoot")
			local msg = "You receive loot: " .. ITEM_LINK

			ItemLoot:CHAT_MSG_LOOT("CHAT_MSG_LOOT", msg, "Player", nil, nil, nil, nil, nil, nil, nil, nil, nil, GUID)

			assert.spy(showSpy).was.called(1)
		end)

		it("processes own loot (Classic: playerName2 match)", function()
			ns.IsRetail = function()
				return false
			end
			ItemLoot._itemLootAdapter.UnitName = function()
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
			ns.IsRetail = function()
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
			ns.IsRetail = function()
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
			assert.is_function(payload.IsEnabled)
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
			ItemLoot._itemLootAdapter.GetItemQualityColor = function()
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

		describe("PlaySoundIfEnabled", function()
			it("plays mount sound when mount sound is enabled and item is a mount", function()
				ns.db.global.item.sounds.mounts = { enabled = true, sound = "Interface/Sounds/mount.ogg" }
				local playSpy = spy.new(function()
					return true, 1
				end)
				ItemLoot._itemLootAdapter.PlaySoundFile = playSpy
				local info = makeItemInfo({
					IsMount = function()
						return true
					end,
				})
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				ItemLoot:PlaySoundIfEnabled(payload)

				assert.spy(playSpy).was.called_with("Interface/Sounds/mount.ogg")
			end)

			it("plays legendary sound when legendary sound is enabled and item is legendary", function()
				ns.db.global.item.sounds.legendary = { enabled = true, sound = "Interface/Sounds/legendary.ogg" }
				local playSpy = spy.new(function()
					return true, 1
				end)
				ItemLoot._itemLootAdapter.PlaySoundFile = playSpy
				local info = makeItemInfo({
					IsLegendary = function()
						return true
					end,
				})
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				ItemLoot:PlaySoundIfEnabled(payload)

				assert.spy(playSpy).was.called_with("Interface/Sounds/legendary.ogg")
			end)

			it("does not play sound when no conditions match", function()
				local playSpy = spy.new(function()
					return true, 1
				end)
				ItemLoot._itemLootAdapter.PlaySoundFile = playSpy
				local info = makeItemInfo()
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				ItemLoot:PlaySoundIfEnabled(payload)

				assert.spy(playSpy).was_not.called()
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
				ItemLoot._itemLootAdapter.GetItemInfo = function()
					return "Finkle's Lava Dredger"
				end
				ItemLoot._itemLootAdapter.GetItemCount = function()
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
				ItemLoot._itemLootAdapter.GetItemInfo = function()
					error("item not cached")
				end
				local info = makeItemInfo()
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				local result = payload.itemCountFn()

				assert.is_nil(result)
			end)

			it("returns nil when GetItemInfo returns nil name", function()
				ns.db.global.item.itemCountTextEnabled = true
				ItemLoot._itemLootAdapter.GetItemInfo = function()
					return nil
				end
				local info = makeItemInfo()
				local payload = ItemLoot:BuildPayload(info, 1, nil)

				local result = payload.itemCountFn()

				assert.is_nil(result)
			end)
		end)

		describe("sellable item price display (secondaryTextFn / secondaryCoinDataFn)", function()
			describe("plainTextPrices disabled (default)", function()
				it("Vendor mode: returns spacer text and real coin data", function()
					ns.db.global.item.pricesForSellableItems = "Vendor"
					local info = makeItemInfo({ sellPrice = 10000 })
					local payload = ItemLoot:BuildPayload(info, 1, nil)

					assert.equals(" ", payload.secondaryTextFn())
					local g, s, c = payload.secondaryCoinDataFn(0)
					assert.equals(1, g)
					assert.equals(0, s)
					assert.equals(0, c)
				end)

				it("AH mode: returns spacer text and real coin data", function()
					ns.db.global.item.pricesForSellableItems = "AH"
					ItemLoot._itemLootAdapter.GetAHPrice = function()
						return 250000
					end
					local info = makeItemInfo({ sellPrice = 0 })
					local payload = ItemLoot:BuildPayload(info, 1, nil)

					assert.equals(" ", payload.secondaryTextFn())
					local g, s, c = payload.secondaryCoinDataFn(0)
					assert.equals(25, g)
					assert.equals(0, s)
					assert.equals(0, c)
				end)

				it("Highest mode: returns spacer text and real coin data", function()
					ns.db.global.item.pricesForSellableItems = "Highest"
					ItemLoot._itemLootAdapter.GetAHPrice = function()
						return 50000
					end
					local info = makeItemInfo({ sellPrice = 10000 })
					local payload = ItemLoot:BuildPayload(info, 1, nil)

					assert.equals(" ", payload.secondaryTextFn())
					local g, s, c = payload.secondaryCoinDataFn(0)
					assert.equals(5, g)
					assert.equals(0, s)
					assert.equals(0, c)
				end)
			end)

			describe("plainTextPrices enabled", function()
				before_each(function()
					ns.db.global.item.plainTextPrices = true
				end)

				it("Vendor mode: returns plain price text and no coin data", function()
					ns.db.global.item.pricesForSellableItems = "Vendor"
					local info = makeItemInfo({ sellPrice = 10000 })
					local payload = ItemLoot:BuildPayload(info, 1, nil)

					assert.equals("1g 0s 0c", payload.secondaryTextFn())
					assert.is_nil(payload.secondaryCoinDataFn(0))
				end)

				it("AH mode: returns plain price text and no coin data", function()
					ns.db.global.item.pricesForSellableItems = "AH"
					ItemLoot._itemLootAdapter.GetAHPrice = function()
						return 250000
					end
					local info = makeItemInfo({ sellPrice = 0 })
					local payload = ItemLoot:BuildPayload(info, 1, nil)

					assert.equals("25g 0s 0c", payload.secondaryTextFn())
					assert.is_nil(payload.secondaryCoinDataFn(0))
				end)

				it("Highest mode: returns plain price text for the higher price and no coin data", function()
					ns.db.global.item.pricesForSellableItems = "Highest"
					ItemLoot._itemLootAdapter.GetAHPrice = function()
						return 50000
					end
					local info = makeItemInfo({ sellPrice = 10000 })
					local payload = ItemLoot:BuildPayload(info, 1, nil)

					assert.equals("5g 0s 0c", payload.secondaryTextFn())
					assert.is_nil(payload.secondaryCoinDataFn(0))
				end)
			end)

			-- secondaryCoinDataFn's Highest branch and the plainTextPrices Highest
			-- branch each independently decide the tie-break ("vendor wins when
			-- vendor == auction"). They currently agree; lock that in so a future
			-- edit to one can't silently disagree with the other.
			describe("Highest mode tie-break (vendor == auction price)", function()
				it("coin-icon path (plainTextPrices off): picks vendor's icon on a tie", function()
					ns.db.global.item.plainTextPrices = false
					ns.db.global.item.pricesForSellableItems = "Highest"
					ItemLoot._itemLootAdapter.GetAHPrice = function()
						return 10000
					end
					local info = makeItemInfo({ sellPrice = 10000 })
					local payload = ItemLoot:BuildPayload(info, 1, nil)

					local _, _, _, icon = payload.secondaryCoinDataFn(0)
					assert.equals(ns.db.global.item.vendorIconTexture, icon)
				end)

				it("plain-text path (plainTextPrices on): resolves to a single price on a tie, not both", function()
					-- A tie formats identically regardless of which side wins, so
					-- this can't distinguish *which* side was picked the way the
					-- coin-icon test above does (that's what the tie-break formula
					-- comparison in the source establishes: both branches use
					-- `> ` not `>=`, so both fall through to vendor on equality).
					-- What this guards against is the multi-price code path
					-- accidentally being reached instead -- e.g. concatenating
					-- "1g 0s 0c    1g 0s 0c" -- since that bug would still "work"
					-- for the coin-icon path's distinct assertion above but not here.
					ns.db.global.item.plainTextPrices = true
					ns.db.global.item.pricesForSellableItems = "Highest"
					ItemLoot._itemLootAdapter.GetAHPrice = function()
						return 10000
					end
					local info = makeItemInfo({ sellPrice = 10000 })
					local payload = ItemLoot:BuildPayload(info, 1, nil)

					assert.equals("1g 0s 0c", payload.secondaryTextFn())
				end)
			end)

			describe("dual-price modes are unaffected by plainTextPrices", function()
				it("VendorAH mode: plain text is identical whether the toggle is off or on", function()
					ns.db.global.item.pricesForSellableItems = "VendorAH"
					local info = makeItemInfo({ sellPrice = 10000 })

					ns.db.global.item.plainTextPrices = false
					local payloadOff = ItemLoot:BuildPayload(info, 1, nil)
					local textOff = payloadOff.secondaryTextFn(1)

					ns.db.global.item.plainTextPrices = true
					local payloadOn = ItemLoot:BuildPayload(info, 1, nil)
					local textOn = payloadOn.secondaryTextFn(1)

					assert.equals("1g 0s 0c", textOff)
					assert.equals(textOff, textOn)
					assert.is_nil(payloadOff.secondaryCoinDataFn(0))
					assert.is_nil(payloadOn.secondaryCoinDataFn(0))
				end)
			end)

			describe("plain-text price suffixes", function()
				-- Distinct, non-English stand-ins. If plainPrice() ever falls back
				-- to a hardcoded "g"/"s"/"c" literal instead of the adapter, this
				-- test's assertion on the mocked suffixes fails.
				before_each(function()
					ItemLoot._itemLootAdapter.GetGoldAmountSymbol = function()
						return "au"
					end
					ItemLoot._itemLootAdapter.GetSilverAmountSymbol = function()
						return "ag"
					end
					ItemLoot._itemLootAdapter.GetCopperAmountSymbol = function()
						return "cu"
					end
				end)

				it("uses the client-localized symbols in single-price plain text mode", function()
					ns.db.global.item.plainTextPrices = true
					ns.db.global.item.pricesForSellableItems = "Vendor"
					local info = makeItemInfo({ sellPrice = 10000 })

					local payload = ItemLoot:BuildPayload(info, 1, nil)

					assert.equals("1au 0ag 0cu", payload.secondaryTextFn())
				end)

				it("uses the client-localized symbols in dual-price mode", function()
					ns.db.global.item.pricesForSellableItems = "VendorAH"
					local info = makeItemInfo({ sellPrice = 10000 })

					local payload = ItemLoot:BuildPayload(info, 1, nil)

					assert.equals("1au 0ag 0cu", payload.secondaryTextFn(1))
				end)
			end)
		end)
	end)
end)
