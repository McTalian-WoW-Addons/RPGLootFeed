---@diagnostic disable: need-check-nil
local assert = require("luassert")
local match = require("luassert.match")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local spy = busted.spy
local stub = busted.stub

describe("Reputation Module", function()
	local _ = match._
	---@type RLF_Reputation, table
	local RepModule, ns, sendMessageSpy

	-- ── Shared ns factory ─────────────────────────────────────────────────────
	local function makeNs()
		sendMessageSpy = spy.new(function() end)
		return {
			ItemQualEnum = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4 },
			FeatureModule = { Reputation = "Reputation" },
			DefaultIcons = { REPUTATION = 236681 },
			Expansion = { TWW = 10 },
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
			CreatePatternSegmentsForStringNumber = function()
				return {}
			end,
			ExtractDynamicsFromPattern = function()
				return nil, nil
			end,
			SendMessage = sendMessageSpy,
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
			RepUtils = {
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
					return 0x0001
				end,
				GetFactionData = function()
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
			},
			LegacyRepParsing = {
				InitializeLegacyReputationChatParsing = function() end,
				ParseFactionChangeMessage = function()
					return nil, nil, false, false
				end,
				GetLocaleFactionMapData = function()
					return nil
				end,
				buildFactionLocaleMap = function() end,
			},
		}
	end

	-- Classic (non-Retail) adapter – default for most test groups.
	local function makeClassicAdapter()
		return {
			GetExpansionLevel = function()
				return 8
			end,
			RunNextFrame = function(fn)
				fn()
			end,
			IssecretValue = function()
				return false
			end,
			IsEventValid = function()
				return false
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
	end

	-- TWW / Retail adapter with FACTION_STANDING_CHANGED and Delvers Journey.
	local function makeTWWAdapter()
		local a = makeClassicAdapter()
		a.GetExpansionLevel = function()
			return 10
		end
		a.IsEventValid = function(event)
			return event == "FACTION_STANDING_CHANGED"
		end
		a.GetFactionDataByID = function(id)
			if id == 2640 then
				return { name = "Brann Bronzebeard", factionID = 2640 }
			end
			return nil
		end
		a.GetDelvesFactionForSeason = function()
			return 2594
		end
		a.GetMajorFactionRenownInfo = function(id)
			if id == 2594 then
				return { renownLevel = 3, renownReputationEarned = 1500, renownLevelThreshold = 2500 }
			end
			return nil
		end
		a.HasRetailReputationAPIAvailable = function()
			return true
		end
		a.GetNumFactions = function()
			return 0
		end
		a.GetDelveReputationBarTitle = function()
			return "Delver's Journey (Season 1)"
		end
		a.Strtrim = function(str)
			return str:match("^%s*(.-)%s*$") or str
		end
		return a
	end

	-- ── Module loader ─────────────────────────────────────────────────────────

	local function loadRepModule(customNs)
		local n = customNs or ns

		-- DI container for dependency injection
		n.DI = {
			_registry = {},
			Register = function(self, name, instance)
				self._registry[name] = instance
			end,
			Resolve = function(self, name)
				return self._registry[name]
			end,
		}

		-- Load real LootElementBase so elements are fully constructed.
		if not n.LootElementBase then
			assert(loadfile("RPGLootFeed/Features/_Internals/LootElementBase.lua"))("TestAddon", n)
			assert.is_not_nil(n.LootElementBase)
		end

		-- Load TextTemplateEngine so DI can resolve it for Reputation.
		if not n.TextTemplateEngine then
			assert(loadfile("RPGLootFeed/Features/_Internals/TextTemplateEngine.lua"))("TestAddon", n)
			assert.is_not_nil(n.TextTemplateEngine)
		end

		-- Register DI dependencies before loading Reputation
		n.DI:Register("LootElementBase", n.LootElementBase)
		n.DI:Register("TextTemplateEngine", n.TextTemplateEngine)
		n.DI:Register("ItemQualEnum", n.ItemQualEnum)
		n.DI:Register("WoWAPI.Reputation", {})
		n.DI:Register("IsRetail", function()
			return n.IsRetail()
		end)

		-- FeatureBase stub – supports DI deps table and logging injection.
		n.FeatureBase = {
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
					ScheduleTimer = function() end,
					CancelTimer = function() end,
				}

				-- Resolve DI dependencies
				for fieldName, depName in pairs(deps.di or {}) do
					module[fieldName] = n.DI:Resolve(depName)
				end

				-- Inject logging methods
				if deps.logging then
					module.LogDebug = function(self, message, source, type_, id, content, amount, isNew)
						n.LogDebug(message, source or "TestAddon", type_ or self.moduleName, id, content, amount, isNew)
					end
					module.LogInfo = function(self, message, source, type_, id, content, amount, isNew)
						n.LogInfo(message, source or "TestAddon", type_ or self.moduleName, id, content, amount, isNew)
					end
					module.LogWarn = function(self, message, source, type_, id, content, amount, isNew)
						n.LogWarn(message, source or "TestAddon", type_ or self.moduleName, id, content, amount, isNew)
					end
					module.LogError = function(self, message, source, type_, id, content, amount, isNew)
						n.LogError(message, source or "TestAddon", type_ or self.moduleName, id, content, amount, isNew)
					end
				end

				return module
			end,
		}

		local mod = assert(loadfile("RPGLootFeed/Features/Reputation/Reputation.lua"))("TestAddon", n)
		assert(loadfile("RPGLootFeed/Features/Reputation/ReputationDelversJourney.lua"))("TestAddon", n)
		return mod
	end

	before_each(function()
		ns = makeNs()
		RepModule = loadRepModule(ns)
		RepModule.reputationApi = makeClassicAdapter()
	end)

	-- ── Lifecycle ─────────────────────────────────────────────────────────────

	describe("OnInitialize", function()
		it("calls InitializeLegacyReputationChatParsing on Classic (non-Retail)", function()
			ns.IsRetail = function()
				return false
			end
			local initSpy = spy.on(ns.LegacyRepParsing, "InitializeLegacyReputationChatParsing")
			RepModule:OnInitialize()
			assert.spy(initSpy).was.called(1)
		end)

		it("does NOT call InitializeLegacyReputationChatParsing on Retail", function()
			ns.IsRetail = function()
				return true
			end
			local initSpy = spy.on(ns.LegacyRepParsing, "InitializeLegacyReputationChatParsing")
			RepModule:OnInitialize()
			assert.spy(initSpy).was_not.called()
		end)

		it("calls Enable when any frame needs reputation", function()
			ns.DbAccessor.IsFeatureNeededByAnyFrame = function()
				return true
			end
			local enableSpy = spy.on(RepModule, "Enable")
			local disableSpy = spy.on(RepModule, "Disable")
			RepModule:OnInitialize()
			assert.spy(enableSpy).was.called(1)
			assert.spy(disableSpy).was_not.called()
		end)

		it("calls Disable when no frame needs reputation", function()
			ns.DbAccessor.IsFeatureNeededByAnyFrame = function()
				return false
			end
			local enableSpy = spy.on(RepModule, "Enable")
			local disableSpy = spy.on(RepModule, "Disable")
			RepModule:OnInitialize()
			assert.spy(enableSpy).was_not.called()
			assert.spy(disableSpy).was.called(1)
		end)
	end)

	describe("OnEnable", function()
		it("Classic: registers PLAYER_ENTERING_WORLD and CHAT_MSG_COMBAT_FACTION_CHANGE", function()
			RepModule.reputationApi.IsEventValid = function()
				return false
			end
			RepModule.reputationApi.GetExpansionLevel = function()
				return 8
			end
			local registerSpy = spy.on(RepModule, "RegisterEvent")
			local bucketSpy = spy.on(RepModule, "RegisterBucketEvent")

			RepModule:OnEnable()

			assert.spy(registerSpy).was.called_with(RepModule, "PLAYER_ENTERING_WORLD")
			assert.spy(registerSpy).was.called_with(RepModule, "CHAT_MSG_COMBAT_FACTION_CHANGE")
			assert.spy(bucketSpy).was_not.called()
		end)

		it("Retail (FACTION_STANDING_CHANGED): registers bucket event instead of chat msg", function()
			RepModule.reputationApi.IsEventValid = function(event)
				return event == "FACTION_STANDING_CHANGED"
			end
			RepModule.reputationApi.GetExpansionLevel = function()
				return 9
			end
			local registerSpy = spy.on(RepModule, "RegisterEvent")
			local bucketSpy = spy.on(RepModule, "RegisterBucketEvent")

			RepModule:OnEnable()

			assert.spy(registerSpy).was.called_with(RepModule, "PLAYER_ENTERING_WORLD")
			assert.spy(registerSpy).was_not.called_with(RepModule, "CHAT_MSG_COMBAT_FACTION_CHANGE")
			assert.spy(bucketSpy).was.called_with(RepModule, "FACTION_STANDING_CHANGED", 0.2)
		end)

		it("TWW: also registers bucket event for Delvers Journey polling", function()
			RepModule.reputationApi = makeTWWAdapter()
			local bucketSpy = spy.on(RepModule, "RegisterBucketEvent")

			RepModule:OnEnable()

			-- Should register TWW bucket with three-arg form (events-table, delay, handler)
			assert.spy(bucketSpy).was.called(2)
		end)
	end)

	describe("OnDisable", function()
		it("Classic: unregisters PLAYER_ENTERING_WORLD and CHAT_MSG_COMBAT_FACTION_CHANGE", function()
			RepModule.reputationApi.IsEventValid = function()
				return false
			end
			RepModule.reputationApi.GetExpansionLevel = function()
				return 8
			end
			local unregSpy = spy.on(RepModule, "UnregisterEvent")
			RepModule:OnDisable()
			assert.spy(unregSpy).was.called_with(RepModule, "PLAYER_ENTERING_WORLD")
			assert.spy(unregSpy).was.called_with(RepModule, "CHAT_MSG_COMBAT_FACTION_CHANGE")
		end)

		it("Retail: calls UnregisterAllBuckets for FACTION_STANDING_CHANGED", function()
			RepModule.reputationApi.IsEventValid = function(event)
				return event == "FACTION_STANDING_CHANGED"
			end
			RepModule.reputationApi.GetExpansionLevel = function()
				return 9
			end
			local bucketSpy = spy.on(RepModule, "UnregisterAllBuckets")
			local unregSpy = spy.on(RepModule, "UnregisterEvent")
			RepModule:OnDisable()
			assert.spy(bucketSpy).was.called()
			assert.spy(unregSpy).was_not.called_with(RepModule, "CHAT_MSG_COMBAT_FACTION_CHANGE")
		end)

		it("TWW: calls UnregisterAllBuckets twice (once per expansion guard)", function()
			RepModule.reputationApi = makeTWWAdapter()
			local bucketSpy = spy.on(RepModule, "UnregisterAllBuckets")
			RepModule:OnDisable()
			assert.spy(bucketSpy).was.called(2)
		end)
	end)

	-- ── CHAT_MSG_COMBAT_FACTION_CHANGE ────────────────────────────────────────

	describe("CHAT_MSG_COMBAT_FACTION_CHANGE", function()
		it("returns early when the message is a secret value", function()
			RepModule.reputationApi.IssecretValue = function()
				return true
			end
			local parseStub = stub(RepModule, "ParseFactionChangeMessage")

			RepModule:CHAT_MSG_COMBAT_FACTION_CHANGE("CHAT_MSG_COMBAT_FACTION_CHANGE", "secret msg")

			assert.spy(parseStub).was_not.called()
		end)

		it("logs error and returns when ParseFactionChangeMessage yields nil faction", function()
			stub(RepModule, "ParseFactionChangeMessage").returns(nil, nil, false, false)
			local elementSpy = spy.on(RepModule, "BuildPayload")

			RepModule:CHAT_MSG_COMBAT_FACTION_CHANGE("CHAT_MSG_COMBAT_FACTION_CHANGE", "Unrecognised msg.")

			assert.spy(elementSpy).was_not.called()
		end)

		it("logs warn and returns when factionMapEntry lookup fails", function()
			stub(RepModule, "ParseFactionChangeMessage").returns("SomeFaction", 100, false, false)
			stub(ns.LegacyRepParsing, "GetLocaleFactionMapData").returns(nil)
			local elementSpy = spy.on(RepModule, "BuildPayload")

			RepModule:CHAT_MSG_COMBAT_FACTION_CHANGE("CHAT_MSG_COMBAT_FACTION_CHANGE", "msg")

			assert.spy(elementSpy).was_not.called()
		end)

		it("logs warn and returns when GetFactionData returns nil despite known ID", function()
			stub(RepModule, "ParseFactionChangeMessage").returns("SomeFaction", 100, false, false)
			stub(ns.LegacyRepParsing, "GetLocaleFactionMapData").returns(9999)
			ns.RepUtils.GetFactionData = function()
				return nil
			end
			local elementSpy = spy.on(RepModule, "BuildPayload")

			RepModule:CHAT_MSG_COMBAT_FACTION_CHANGE("CHAT_MSG_COMBAT_FACTION_CHANGE", "msg")

			assert.spy(elementSpy).was_not.called()
		end)

		it("overrides factionData.name with parsed name when they differ", function()
			stub(RepModule, "ParseFactionChangeMessage").returns("ParsedName", 200, false, false)
			stub(ns.LegacyRepParsing, "GetLocaleFactionMapData").returns(99)
			ns.RepUtils.GetFactionData = function()
				return {
					factionId = 99,
					name = "StoredName",
					standing = 1,
					icon = 236681,
					quality = 1,
					rank = "Neutral",
					rankStandingMax = 3,
					rankStandingMin = 0,
					color = { r = 1, g = 1, b = 1 },
					contextInfo = "1",
				}
			end

			local spyBuild = spy.on(RepModule, "BuildPayload")
			RepModule:CHAT_MSG_COMBAT_FACTION_CHANGE("CHAT_MSG_COMBAT_FACTION_CHANGE", "msg")

			-- Verify name in the faction data passed to BuildPayload equals the parsed name
			local callArgs = spyBuild.calls[1].refs
			assert.equals("ParsedName", callArgs[2].name)
		end)
	end)

	-- ── UpdateReputationForFaction ────────────────────────────────────────────

	describe("UpdateReputationForFaction", function()
		local validFactionData
		before_each(function()
			validFactionData = {
				factionId = 1234,
				name = "Valdrakken Accord",
				standing = 3,
				icon = 236681,
				quality = 3,
				rank = "Exalted",
				rankStandingMax = 1000,
				rankStandingMin = 0,
				color = { r = 0, g = 0.75, b = 1 },
				contextInfo = "800 / 1000",
			}
			ns.RepUtils.GetFactionData = function()
				return validFactionData
			end
		end)

		it("creates and shows an element when repChange is positive", function()
			ns.RepUtils.GetDeltaAndUpdateCache = function()
				return 350
			end
			local elementSpy = spy.on(RepModule, "BuildPayload")

			RepModule:UpdateReputationForFaction(1234)

			assert.spy(elementSpy).was.called(1)
			assert.spy(sendMessageSpy).was.called(1)
		end)

		it("does not create an element when repChange is nil", function()
			ns.RepUtils.GetDeltaAndUpdateCache = function()
				return nil
			end
			local elementSpy = spy.on(RepModule, "BuildPayload")

			RepModule:UpdateReputationForFaction(1234)

			assert.spy(elementSpy).was_not.called()
		end)

		it("does not create an element when repChange is 0", function()
			ns.RepUtils.GetDeltaAndUpdateCache = function()
				return 0
			end
			local elementSpy = spy.on(RepModule, "BuildPayload")

			RepModule:UpdateReputationForFaction(1234)

			assert.spy(elementSpy).was_not.called()
		end)

		it("logs warn and returns when GetFactionData returns nil", function()
			ns.RepUtils.GetFactionData = function()
				return nil
			end
			local deltaStub = stub(ns.RepUtils, "GetDeltaAndUpdateCache")
			local elementSpy = spy.on(RepModule, "BuildPayload")

			RepModule:UpdateReputationForFaction(9999)

			assert.spy(deltaStub).was_not.called()
			assert.spy(elementSpy).was_not.called()
		end)
	end)

	-- ── FACTION_STANDING_CHANGED ──────────────────────────────────────────────

	describe("FACTION_STANDING_CHANGED", function()
		it("calls UpdateReputationForFaction for each faction in the events table", function()
			local updatedIDs = {}
			stub(RepModule, "UpdateReputationForFaction").invokes(function(self, id)
				table.insert(updatedIDs, id)
			end)

			RepModule:FACTION_STANDING_CHANGED({ [111] = 1, [222] = 2, [333] = 1 })

			table.sort(updatedIDs)
			assert.are.same({ 111, 222, 333 }, updatedIDs)
		end)
	end)

	-- ── CheckForHiddenRenownFactions (TWW Delvers Journey) ────────────────────

	describe("CheckForHiddenRenownFactions", function()
		-- Each test uses a fresh module with the TWW adapter so module-local
		-- upvalues (CURRENT_SEASON_DELVE_JOURNEY, DELVER_JOURNEY_LABEL) start
		-- at zero / nil.
		before_each(function()
			ns = makeNs()
			RepModule = loadRepModule(ns)
			RepModule.reputationApi = makeTWWAdapter()
		end)

		it("returns early without calling GetMajorFactionRenownInfo when no season faction found", function()
			RepModule.reputationApi.GetDelvesFactionForSeason = function()
				return 0
			end
			local getMajorSpy = spy.new(function()
				return nil
			end)
			RepModule.reputationApi.GetMajorFactionRenownInfo = getMajorSpy

			RepModule:CheckForHiddenRenownFactions({})

			assert.spy(getMajorSpy).was_not.called()
		end)

		it("returns early when GetDelveReputationBarTitle returns nil", function()
			-- Season will be set on first call; label fetch should return early.
			RepModule.reputationApi.GetDelveReputationBarTitle = function()
				return nil
			end
			local getMajorSpy = spy.new(function()
				return nil
			end)
			RepModule.reputationApi.GetMajorFactionRenownInfo = getMajorSpy

			RepModule:CheckForHiddenRenownFactions({})

			assert.spy(getMajorSpy).was_not.called()
		end)

		it("returns early when locale string has no opening parenthesis", function()
			RepModule.reputationApi.GetDelveReputationBarTitle = function()
				return "Delver Journey No Parens"
			end
			local getMajorSpy = spy.new(function()
				return nil
			end)
			RepModule.reputationApi.GetMajorFactionRenownInfo = getMajorSpy

			RepModule:CheckForHiddenRenownFactions({})

			assert.spy(getMajorSpy).was_not.called()
		end)

		it("returns early when renown info is nil", function()
			RepModule.reputationApi.GetMajorFactionRenownInfo = function()
				return nil
			end
			local insertSpy = spy.on(ns.RepUtils, "InsertNewCacheEntry")

			RepModule:CheckForHiddenRenownFactions({})

			assert.spy(insertSpy).was_not.called()
		end)

		it("inserts cache entry on first encounter and does not show element", function()
			-- No existing cache → inserts and returns without showing.
			ns.RepUtils.GetCachedFactionDetails = function()
				return nil
			end
			local insertSpy = spy.on(ns.RepUtils, "InsertNewCacheEntry")
			local elementSpy = spy.on(RepModule, "BuildPayload")

			RepModule:CheckForHiddenRenownFactions({})

			assert.spy(insertSpy).was.called(1)
			assert.spy(elementSpy).was_not.called()
		end)

		it("shows element when cache exists and repChange is positive", function()
			-- First call: primes CURRENT_SEASON and DELVER_JOURNEY_LABEL, inserts cache.
			ns.RepUtils.GetCachedFactionDetails = function()
				return nil
			end
			RepModule:CheckForHiddenRenownFactions({})

			-- Second call: cache exists, positive repChange → element shown.
			ns.RepUtils.GetCachedFactionDetails = function()
				return {
					repType = bit.bor(0x2000, 0x0002),
					rank = 2,
					standing = 1000,
					rankStandingMin = 0,
					rankStandingMax = 2500,
				}
			end
			ns.RepUtils.GetDeltaAndUpdateCache = function()
				return 500
			end
			local elementSpy = spy.on(RepModule, "BuildPayload")

			RepModule:CheckForHiddenRenownFactions({})

			assert.spy(elementSpy).was.called(1)
			assert.spy(sendMessageSpy).was.called(1)
		end)

		it("does not show element when cache exists but repChange is not positive", function()
			-- First call primes state.
			ns.RepUtils.GetCachedFactionDetails = function()
				return nil
			end
			RepModule:CheckForHiddenRenownFactions({})

			-- Second call: cache hit, but no new rep gained.
			ns.RepUtils.GetCachedFactionDetails = function()
				return {
					repType = bit.bor(0x2000, 0x0002),
					rank = 2,
					standing = 1000,
					rankStandingMin = 0,
					rankStandingMax = 2500,
				}
			end
			ns.RepUtils.GetDeltaAndUpdateCache = function()
				return 0
			end
			local elementSpy = spy.on(RepModule, "BuildPayload")

			RepModule:CheckForHiddenRenownFactions({})

			assert.spy(elementSpy).was_not.called()
		end)
	end)
end)
