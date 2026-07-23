---@diagnostic disable: need-check-nil
local assert = require("luassert")
local match = require("luassert.match")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local spy = busted.spy
local stub = busted.stub

describe("Reputation Regressions", function()
	local _ = match._
	---@type RLF_Reputation, table
	local RepModule, ns, sendMessageSpy

	before_each(function()
		sendMessageSpy = spy.new(function() end)

		-- Build a minimal ns from scratch – no nsMocks framework needed.
		-- Only the fields actually referenced by Reputation.lua and
		-- LootElementBase.lua are included.
		ns = {
			-- Captured as locals by Reputation.lua at load time.
			ItemQualEnum = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4 },
			FeatureModule = { Reputation = "Reputation" },
			DefaultIcons = { REPUTATION = 236681 },
			Expansion = { TWW = 10 },
			-- Closure wrappers call these as G_RLF:Method(...).
			LogDebug = function() end,
			LogInfo = function() end,
			LogWarn = function() end,
			LogError = function() end,
			IsRetail = function()
				return false
			end,
			RGBAToHexFormat = function()
				return "|cFFFFFFFF"
			end,
			-- Used by LegacyChatParsingImpl locals; no-op stubs since
			-- LegacyRepParsing is stubbed inline and never actually calls these.
			CreatePatternSegmentsForStringNumber = function()
				return {}
			end,
			ExtractDynamicsFromPattern = function()
				return nil, nil
			end,
			SendMessage = sendMessageSpy,
			-- Shared adapter namespace; tests override Rep._repAdapter directly.
			WoWAPI = { Reputation = {} },
			DbAccessor = {
				IsFeatureNeededByAnyFrame = function()
					return true
				end,
				AnyFeatureConfig = function(_, featureKey)
					if featureKey == "reputation" then
						return ns.db.global.rep
					end
					return nil
				end,
				Animations = function(_, frameId)
					return ns.db.global.animations
				end,
			},
			Frames = { MAIN = 1 },
			-- Runtime lookups by LootElementBase:fromPayload() and feature code.
			db = {
				global = {
					animations = { exit = { fadeOutDelay = 5 } },
					rep = {
						enabled = true,
						defaultRepColor = { 1, 1, 1, 1 },
						enableIcon = true,
						secondaryTextAlpha = 1,
						enableRepLevel = true,
						repLevelColor = { 0.5, 0.5, 1, 1 },
						repLevelTextWrapChar = 1,
					},
					misc = { hideAllIcons = false },
				},
			},
		}

		-- Stub RepUtils inline – avoids loading ReputationHelpers.lua and its
		-- chain of C_Reputation / C_Gossip / C_MajorFactions dependencies.
		ns.RepUtils = {
			RepType = {
				Unknown = 0x0000,
				BaseFaction = 0x0001,
				MajorFaction = 0x0002,
				DelveCompanion = 0x0004,
				Friendship = 0x0008,
				Guild = 0x0010,
				DelversJourney = 0x0020,
				Paragon = 0x1000,
				Warband = 0x2000,
			},
			GetCount = function()
				return 0
			end,
			DetermineRepType = function()
				return 0x0001 -- BaseFaction
			end,
			-- Returns the exact shape that CHAT_MSG_COMBAT_FACTION_CHANGE expects.
			-- The caller adds the `delta` field after this returns.
			GetFactionData = function(factionID)
				if factionID == 12345 then
					return {
						factionId = 12345,
						name = "Рыболовы",
						standing = 2,
						icon = 236681,
						quality = 3,
						rank = "Test Text",
						rankStandingMax = 3,
						rankStandingMin = 2,
						color = { r = 1, g = 0, b = 0 },
						contextInfo = "2",
					}
				end
				return nil
			end,
			GetDeltaAndUpdateCache = function()
				return nil
			end,
			GetCachedFactionDetails = function()
				return nil
			end,
			InsertNewCacheEntry = function() end,
			UpdateCacheEntry = function() end,
		}

		-- Stub LegacyRepParsing inline – individual test cases stub the methods
		-- they care about via busted stub().
		ns.LegacyRepParsing = {
			InitializeLegacyReputationChatParsing = function() end,
			ParseFactionChangeMessage = function()
				return nil, nil, false, false
			end,
			GetLocaleFactionMapData = function()
				return nil
			end,
			buildFactionLocaleMap = function() end,
		}

		-- Load real LootElementBase so elements are fully constructed.
		assert(loadfile("RPGLootFeed/Features/_Internals/LootElementBase.lua"))("TestAddon", ns)
		assert.is_not_nil(ns.LootElementBase)

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
		ns.DI:Register("WoWAPI.Reputation", {})
		ns.DI:Register("IsRetail", function()
			return ns.IsRetail()
		end)

		-- Mock FeatureBase – returns a minimal stub module so Reputation tests
		-- are completely independent of AceAddon plumbing.
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
					UnregisterAllBuckets = function() end,
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

		-- Load Reputation – the FeatureBase mock above captures deps from ns.DI.
		-- RepUtils and LegacyRepParsing stubs set above are also captured here.
		RepModule = assert(loadfile("RPGLootFeed/Features/Reputation/Reputation.lua"))("TestAddon", ns)

		-- Inject a fresh mock adapter so tests control external WoW API calls
		-- without patching _G directly.
		RepModule.reputationApi = {
			GetExpansionLevel = function()
				return 8 -- below TWW (10), skips all Delvers Journey / TWW paths
			end,
			RunNextFrame = function(fn)
				fn()
			end,
			IssecretValue = function()
				return false
			end,
			IsEventValid = function()
				return false -- Classic path: use CHAT_MSG_COMBAT_FACTION_CHANGE
			end,
			GetFactionForCompanion = function()
				return 2640
			end,
			GetFactionDataByID = function()
				return nil
			end,
			GetDelvesFactionForSeason = function()
				return 0
			end,
			GetMajorFactionRenownInfo = function()
				return nil
			end,
			GetNumFactions = function()
				return nil
			end,
			GetFactionDataByIndex = function()
				return nil
			end,
			HasRetailReputationAPIAvailable = function()
				return false
			end,
			GetAccountWideFontColor = function()
				return {
					GetRGBA = function()
						return 1, 1, 1, 1
					end,
				}
			end,
			GetDelveReputationBarTitle = function()
				return nil
			end,
			Strtrim = function(str)
				return str
			end,
		}
	end)

	it("handles The Anglers in MOP Classic, ruRU", function()
		local spyBuildPayload = spy.on(RepModule, "BuildPayload")

		-- Stub ParseFactionChangeMessage to return faction name and repChange.
		stub(RepModule, "ParseFactionChangeMessage").returns("Рыболовы", 1100, false, false)

		-- Stub GetLocaleFactionMapData to return the faction ID for "Рыболовы".
		stub(ns.LegacyRepParsing, "GetLocaleFactionMapData").returns(12345)

		RepModule:OnInitialize()
		RepModule:PLAYER_ENTERING_WORLD("PLAYER_ENTERING_WORLD", true, false)

		RepModule:CHAT_MSG_COMBAT_FACTION_CHANGE(
			"CHAT_MSG_COMBAT_FACTION_CHANGE",
			'Отношение фракции "Рыболовы" к вам улучшилось на 1100 (+550.0 дополнительно).'
		)

		local expectedFactionDetails = {
			factionId = 12345,
			name = "Рыболовы",
			delta = 1100,
			color = { r = 1, g = 0, b = 0 },
			contextInfo = "2",
			icon = 236681,
			quality = 3,
			rank = "Test Text",
			rankStandingMax = 3,
			rankStandingMin = 2,
			standing = 2,
		}

		assert.spy(spyBuildPayload).was.called_with(RepModule, match.is_same(expectedFactionDetails))
	end)
end)
