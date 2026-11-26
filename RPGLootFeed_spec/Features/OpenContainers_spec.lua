local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("OpenContainers module", function()
	local ns, OC, api, timers, used, bags, state, requested, names, notified
	local registered, castEnd, castStarts, castStops

	-- Known ids, all present in the WoW Forever data set.
	local BIG_MOUTH_CLAM = 7973 -- openable = true
	local BLUE_SACK = 17962 -- defaultBlocked (RAID)
	local UNKNOWN = 999999

	local function flushTimers()
		local pending = timers
		timers = {}
		for _, fn in ipairs(pending) do
			fn()
		end
	end

	before_each(function()
		requested, names, notified = {}, {}, 0
		registered, castEnd, castStarts, castStops = {}, nil, 0, 0
		timers, used, state =
			{}, {}, {
				combat = false,
				casting = false,
				stealthed = false,
				interaction = false,
				invalidEvents = {},
				now = 0,
				level = 60,
				requiredLevel = 1,
			}
		-- bags[bag][slot] = itemId
		bags = { [0] = { [1] = BIG_MOUTH_CLAM } }

		api = {
			GetContainerNumSlots = function(bag)
				local b = bags[bag]
				return b and 16 or 0
			end,
			GetContainerNumFreeSlots = function()
				return 10, 0
			end,
			GetContainerItemID = function(bag, slot)
				return bags[bag] and bags[bag][slot]
			end,
			UseContainerItem = function(bag, slot)
				used[#used + 1] = { bag, slot }
				bags[bag][slot] = nil
			end,
			GetItemRequiredLevel = function()
				return state.requiredLevel
			end,
			GetItemName = function(itemId)
				return names[itemId]
			end,
			RequestItemData = function(itemId)
				requested[#requested + 1] = itemId
			end,
			GetLocale = function()
				return "enUS"
			end,
			After = function(_, fn)
				timers[#timers + 1] = fn
			end,
			GetTime = function()
				return state.now
			end,
			UnitLevel = function()
				return state.level
			end,
			IsInCombat = function()
				return state.combat
			end,
			IsValidEvent = function(event)
				return state.invalidEvents[event] ~= true
			end,
			RegisterCastEndListener = function(fn)
				castEnd = fn
				return {
					Start = function()
						castStarts = castStarts + 1
					end,
					Stop = function()
						castStops = castStops + 1
					end,
				}
			end,
			IsPlayerCasting = function()
				return state.casting
			end,
			IsStealthed = function()
				return state.stealthed
			end,
			IsInteractionActive = function()
				return state.interaction
			end,
			GetLastBagIndex = function()
				return 4
			end,
		}

		ns = {
			SupportModule = { OpenContainers = "OpenContainers" },
			LogDebug = function() end,
			LogInfo = function() end,
			NotifyChange = function()
				notified = notified + 1
			end,
			IsForever = function()
				return true
			end,
			IsClassic = function()
				return false
			end,
			IsTBCClassic = function()
				return false
			end,
			db = {
				global = {
					openContainers = {
						enabled = true,
						minFreeSlots = 4,
						allowList = { [7973] = true },
						blockList = {},
						seeded = true,
						itemNames = {},
						itemNamesLocale = "enUS",
					},
				},
			},
			DI = {
				registry = { ["WoWAPI.OpenContainers"] = nil },
				Resolve = function(self, k)
					return self.registry[k]
				end,
			},
		}
		ns.DI.registry["WoWAPI.OpenContainers"] = api
		ns.FeatureBase = {
			new = function(_, name, deps)
				local module = {
					moduleName = name,
					enabled = false,
					Enable = function(self)
						self.enabled = true
					end,
					Disable = function(self)
						self.enabled = false
					end,
					IsEnabled = function(self)
						return self.enabled
					end,
					RegisterEvent = function(_, event, handler)
						registered[event] = handler or event
					end,
					UnregisterEvent = function(_, event)
						registered[event] = nil
					end,
					UnregisterAllEvents = function() end,
					LogDebug = function() end,
					LogInfo = function() end,
				}
				for field, dep in pairs(deps.di or {}) do
					module[field] = ns.DI:Resolve(dep)
				end
				return module
			end,
		}

		assert(loadfile("RPGLootFeed/Features/OpenContainers/OpenContainersData.lua"))("TestAddon", ns)
		OC = assert(loadfile("RPGLootFeed/Features/OpenContainers/OpenContainers.lua"))("TestAddon", ns)
		OC:ResetState()
	end)

	describe("ParseItemId", function()
		it("accepts numbers, numeric strings and item links", function()
			assert.are.equal(7973, OC.ParseItemId(7973))
			assert.are.equal(7973, OC.ParseItemId(" 7973 "))
			assert.are.equal(7973, OC.ParseItemId("|cffffffff|Hitem:7973::::::::|h[Big-mouth Clam]|h|r"))
		end)

		it("rejects junk", function()
			assert.is_nil(OC.ParseItemId("clam"))
			assert.is_nil(OC.ParseItemId(0))
			assert.is_nil(OC.ParseItemId(nil))
		end)
	end)

	describe("flavor data", function()
		it("has data for WoW Forever", function()
			assert.is_true(OC:IsSupported())
			assert.are.equal("forever", OC:GetFlavorKey())
		end)

		it("is not available on other clients for now", function()
			ns.IsForever = function()
				return false
			end
			assert.is_false(OC:IsSupported())
			assert.is_nil(OC:GetFlavorKey())
		end)

		it("is not available on Classic Era or TBC for now, even though their data is kept", function()
			ns.IsForever = function()
				return false
			end
			ns.IsClassic = function()
				return true
			end
			assert.is_false(OC:IsSupported())
			ns.IsClassic = function()
				return false
			end
			ns.IsTBCClassic = function()
				return true
			end
			assert.is_false(OC:IsSupported())
			assert.is_table(ns.OpenContainersData.era)
			assert.is_table(ns.OpenContainersData.tbc)
		end)
	end)

	describe("IsEligible", function()
		it("opens allow-listed items", function()
			assert.is_true(OC:IsEligible(BIG_MOUTH_CLAM))
		end)

		it("ignores items on neither list, even ones in the base data", function()
			ns.db.global.openContainers.allowList = {}
			assert.is_false(OC:IsEligible(BIG_MOUTH_CLAM))
			assert.is_false(OC:IsEligible(UNKNOWN))
		end)

		it("opens items the player adds to the allow list", function()
			ns.db.global.openContainers.allowList[UNKNOWN] = true
			assert.is_true(OC:IsEligible(UNKNOWN))
		end)

		it("never opens block-listed items, even if also allow-listed", function()
			ns.db.global.openContainers.blockList[BIG_MOUTH_CLAM] = true
			assert.is_false(OC:IsEligible(BIG_MOUTH_CLAM))
		end)
	end)

	describe("Seed", function()
		before_each(function()
			ns.db.global.openContainers.seeded = false
			ns.db.global.openContainers.allowList = {}
		end)

		it("puts keyless containers on the allow list and recommended-sealed ones on the block list", function()
			assert.is_true(OC:Seed())
			local cfg = ns.db.global.openContainers
			assert.is_true(cfg.allowList[BIG_MOUTH_CLAM])
			assert.is_nil(cfg.blockList[BIG_MOUTH_CLAM])
			assert.is_true(cfg.blockList[BLUE_SACK])
			assert.is_nil(cfg.allowList[BLUE_SACK])
			assert.is_true(cfg.seeded)
		end)

		it("does not seed locked boxes", function()
			OC:Seed()
			assert.is_nil(ns.db.global.openContainers.allowList[16882]) -- Battered Junkbox (locked)
		end)

		it("only seeds once, so removed entries stay removed", function()
			OC:Seed()
			OC:RemoveItem(BIG_MOUTH_CLAM)
			assert.is_false(OC:Seed())
			assert.is_nil(ns.db.global.openContainers.allowList[BIG_MOUTH_CLAM])
		end)

		it("restores defaults on reset", function()
			OC:Seed()
			OC:RemoveItem(BIG_MOUTH_CLAM)
			assert.is_true(OC:Seed(true))
			assert.is_true(ns.db.global.openContainers.allowList[BIG_MOUTH_CLAM])
		end)

		it("does nothing on unsupported clients", function()
			ns.IsForever = function()
				return false
			end
			assert.is_false(OC:Seed())
			assert.is_false(ns.db.global.openContainers.seeded)
		end)
	end)

	describe("ApplyAdditions", function()
		before_each(function()
			ns.OpenContainersData.additions[11] = {
				forever = { allowList = { 111, 222 }, blockList = { 333 } },
			}
		end)

		it("adds new IDs to the right lists", function()
			assert.are.equal(3, OC:ApplyAdditions(11))
			local cfg = ns.db.global.openContainers
			assert.is_true(cfg.allowList[111])
			assert.is_true(cfg.allowList[222])
			assert.is_true(cfg.blockList[333])
		end)

		it("never overrides the player's choices", function()
			local cfg = ns.db.global.openContainers
			cfg.blockList[111] = true -- player blocked it already
			cfg.allowList[333] = true -- player allowed it already
			assert.are.equal(1, OC:ApplyAdditions(11))
			assert.is_nil(cfg.allowList[111])
			assert.is_true(cfg.blockList[111])
			assert.is_true(cfg.allowList[333])
			assert.is_nil(cfg.blockList[333])
		end)

		it("is a no-op for players who were never seeded", function()
			ns.db.global.openContainers.seeded = false
			assert.are.equal(0, OC:ApplyAdditions(11))
			assert.is_nil(ns.db.global.openContainers.allowList[111])
		end)

		it("is a no-op for versions or flavors without additions", function()
			assert.are.equal(0, OC:ApplyAdditions(12))
			ns.IsForever = function()
				return false
			end
			assert.are.equal(0, OC:ApplyAdditions(11))
		end)
	end)

	describe("item names", function()
		it("returns and caches names the client knows", function()
			names[BIG_MOUTH_CLAM] = "Big-mouth Clam"
			assert.are.equal("Big-mouth Clam", OC:GetItemName(BIG_MOUTH_CLAM))
			names[BIG_MOUTH_CLAM] = nil -- client forgets it
			assert.are.equal("Big-mouth Clam", OC:GetItemName(BIG_MOUTH_CLAM))
			assert.are.equal("Big-mouth Clam", ns.db.global.openContainers.itemNames[BIG_MOUTH_CLAM])
		end)

		it("wipes the cache when the client locale changes", function()
			ns.db.global.openContainers.itemNames[BIG_MOUTH_CLAM] = "Big-mouth Clam"
			api.GetLocale = function()
				return "deDE"
			end
			OC:ValidateNameCache()
			assert.is_nil(ns.db.global.openContainers.itemNames[BIG_MOUTH_CLAM])
			assert.are.equal("deDE", ns.db.global.openContainers.itemNamesLocale)
		end)

		it("keeps the cache when the locale is unchanged", function()
			ns.db.global.openContainers.itemNames[BIG_MOUTH_CLAM] = "Big-mouth Clam"
			OC:ValidateNameCache()
			assert.are.equal("Big-mouth Clam", ns.db.global.openContainers.itemNames[BIG_MOUTH_CLAM])
		end)

		it("requests only the names that are missing, in batches", function()
			local cfg = ns.db.global.openContainers
			cfg.allowList = {}
			for id = 1, 60 do
				cfg.allowList[id] = true
			end
			cfg.itemNames[1] = "Cached"
			OC:RequestItemNames()
			assert.are.equal(25, #requested) -- first batch only
			flushTimers()
			flushTimers()
			assert.are.equal(59, #requested) -- everything but the cached one
		end)

		it("does not request anything when every name is cached", function()
			ns.db.global.openContainers.itemNames[BIG_MOUTH_CLAM] = "Big-mouth Clam"
			OC:RequestItemNames()
			assert.are.equal(0, #requested)
		end)

		it("stores a name when its item data arrives and refreshes the options once", function()
			names[BIG_MOUTH_CLAM] = "Big-mouth Clam"
			OC:GET_ITEM_INFO_RECEIVED("GET_ITEM_INFO_RECEIVED", BIG_MOUTH_CLAM, true)
			OC:GET_ITEM_INFO_RECEIVED("GET_ITEM_INFO_RECEIVED", BIG_MOUTH_CLAM, true)
			flushTimers()
			assert.are.equal("Big-mouth Clam", ns.db.global.openContainers.itemNames[BIG_MOUTH_CLAM])
			assert.are.equal(1, notified)
		end)

		it("ignores items that are not on a list or that failed to load", function()
			names[UNKNOWN] = "Whatever"
			OC:GET_ITEM_INFO_RECEIVED("GET_ITEM_INFO_RECEIVED", UNKNOWN, true)
			OC:GET_ITEM_INFO_RECEIVED("GET_ITEM_INFO_RECEIVED", BIG_MOUTH_CLAM, false)
			flushTimers()
			assert.is_nil(ns.db.global.openContainers.itemNames[UNKNOWN])
			assert.are.equal(0, notified)
		end)

		it("requests data for an item moved onto a list", function()
			OC:MoveItem(UNKNOWN, "allowList")
			assert.are.same({ UNKNOWN }, requested)
		end)
	end)

	describe("list editing helpers", function()
		it("moves and removes several items at once", function()
			local cfg = ns.db.global.openContainers
			cfg.allowList = { [1] = true, [2] = true, [3] = true }
			OC:MoveItems({ 1, 2 }, "blockList")
			assert.are.same({ [3] = true }, cfg.allowList)
			assert.are.same({ [1] = true, [2] = true }, cfg.blockList)
			OC:RemoveItems({ 2, 3 })
			assert.are.same({}, cfg.allowList)
			assert.are.same({ [1] = true }, cfg.blockList)
		end)

		it("sorts lists by name, case-insensitively, with unnamed items last by ID", function()
			local cfg = ns.db.global.openContainers
			cfg.allowList = { [5] = true, [6] = true, [7] = true, [9] = true, [8] = true }
			cfg.itemNames = { [5] = "banana Sack", [6] = "Apple Crate", [7] = "Cherry Box" }
			local rows = OC:GetSortedList("allowList")
			local ids = {}
			for _, row in ipairs(rows) do
				ids[#ids + 1] = row.itemId
			end
			assert.are.same({ 6, 5, 7, 8, 9 }, ids)
			assert.are.equal("Apple Crate (6)", rows[1].label)
			assert.are.equal("Item 8", rows[4].label)
		end)
	end)

	describe("MoveItem and RemoveItem", function()
		it("moves an item between lists", function()
			OC:MoveItem(BIG_MOUTH_CLAM, "blockList")
			assert.is_nil(ns.db.global.openContainers.allowList[BIG_MOUTH_CLAM])
			assert.is_true(ns.db.global.openContainers.blockList[BIG_MOUTH_CLAM])
			OC:MoveItem(BIG_MOUTH_CLAM, "allowList")
			assert.is_true(ns.db.global.openContainers.allowList[BIG_MOUTH_CLAM])
			assert.is_nil(ns.db.global.openContainers.blockList[BIG_MOUTH_CLAM])
		end)

		it("removes an item from both lists", function()
			OC:RemoveItem(BIG_MOUTH_CLAM)
			assert.is_false(OC:IsEligible(BIG_MOUTH_CLAM))
			assert.is_nil(ns.db.global.openContainers.blockList[BIG_MOUTH_CLAM])
		end)
	end)

	describe("MeetsLevelRequirement", function()
		it("rejects items above the player's level", function()
			state.requiredLevel = 70
			assert.is_false(OC:MeetsLevelRequirement(BIG_MOUTH_CLAM))
		end)

		it("accepts items at or below the player's level", function()
			state.requiredLevel = 60
			assert.is_true(OC:MeetsLevelRequirement(BIG_MOUTH_CLAM))
		end)

		it("tries uncached items", function()
			state.requiredLevel = nil
			assert.is_true(OC:MeetsLevelRequirement(BIG_MOUTH_CLAM))
		end)

		it("does not skip Bind on Pickup items: the lists are the only rules", function()
			assert.is_true(OC:IsEligible(BIG_MOUTH_CLAM))
			assert.is_true(OC:MeetsLevelRequirement(BIG_MOUTH_CLAM))
		end)
	end)

	describe("IsSafeToOpen", function()
		it("is safe by default", function()
			assert.is_true(OC:IsSafeToOpen())
		end)

		for _, key in ipairs({ "combat", "casting", "stealthed", "interaction" }) do
			it("is unsafe while " .. key, function()
				state[key] = true
				assert.is_false(OC:IsSafeToOpen())
			end)
		end

		it("is unsafe when bags are nearly full", function()
			api.GetContainerNumFreeSlots = function(bag)
				return bag == 0 and 3 or 0, 0
			end
			assert.is_false(OC:IsSafeToOpen())
		end)

		it("ignores free slots in specialty bags", function()
			api.GetContainerNumFreeSlots = function()
				return 10, 1
			end
			assert.is_false(OC:IsSafeToOpen())
		end)
	end)

	describe("scanning and opening", function()
		it("queues eligible items and opens them", function()
			bags[0][2] = UNKNOWN
			OC:RunScan()
			assert.are.equal(1, #OC:GetQueue())
			flushTimers()
			assert.are.same({ { 0, 1 } }, used)
		end)

		it("does nothing when disabled", function()
			ns.db.global.openContainers.enabled = false
			OC:RunScan()
			flushTimers()
			assert.are.equal(0, #used)
		end)

		it("does not open in combat, and schedules nothing more", function()
			OC:RunScan()
			state.combat = true
			flushTimers()
			assert.are.equal(0, #used)
			assert.are.equal(0, #timers)
		end)

		it("does not scan in combat", function()
			state.combat = true
			OC:RunScan()
			assert.are.equal(0, #OC:GetQueue())
			assert.are.equal(0, #timers)
		end)

		it("sets an item aside after repeated unanswered opens", function()
			api.UseContainerItem = function(bag, slot)
				used[#used + 1] = { bag, slot } -- slot stays filled: the game refused
			end
			for _ = 1, 5 do
				OC:RunScan()
				flushTimers() -- the tick opens it
				flushTimers() -- the answer timeout counts a refusal
			end
			assert.are.equal(3, #used)
			assert.is_false(OC:IsEligible(BIG_MOUTH_CLAM))
		end)
	end)

	describe("event driven, no polling", function()
		it("goes idle while blocked instead of retrying on a timer", function()
			OC:RunScan()
			state.interaction = true
			flushTimers()
			assert.are.equal(0, #used)
			assert.are.equal(0, #timers)
		end)

		it("goes idle while casting, stealthed, or short on bag space too", function()
			for _, setup in ipairs({
				function()
					state.casting = true
				end,
				function()
					state.stealthed = true
				end,
				function()
					api.GetContainerNumFreeSlots = function(bag)
						return bag == 0 and 3 or 0, 0
					end
				end,
			}) do
				timers, used = {}, {}
				OC:ResetState()
				OC:RunScan()
				setup()
				flushTimers()
				assert.are.equal(0, #used)
				assert.are.equal(0, #timers)
			end
		end)

		it("resumes the queue when an unblocking event fires", function()
			OC:RunScan()
			state.interaction = true
			flushTimers()
			state.interaction = false
			OC:OnUnblocked()
			flushTimers()
			assert.are.equal(1, #used)
		end)

		it("does nothing on an unblocking event when the queue is empty", function()
			OC:OnUnblocked()
			assert.are.equal(0, #timers)
		end)

		it("resumes when the player's cast ends", function()
			OC:OnEnable()
			flushTimers() -- the startup scan builds the queue and the tick is scheduled
			state.casting = true
			flushTimers()
			assert.are.equal(0, #used)
			state.casting = false
			castEnd()
			flushTimers()
			assert.are.equal(1, #used)
		end)

		it("waits for the loot instead of rechecking on a timer after an open", function()
			bags[0][2] = UNKNOWN
			ns.db.global.openContainers.allowList[UNKNOWN] = true
			OC:RunScan()
			flushTimers() -- opens the first container
			assert.are.same({ { 0, 1 } }, used)
			-- Exactly one timer is pending, the answer timeout: no recheck loop.
			assert.are.equal(1, #timers)
		end)

		it("continues on LOOT_CLOSED without waiting for the timeout", function()
			bags[0][2] = UNKNOWN
			ns.db.global.openContainers.allowList[UNKNOWN] = true
			OC:RunScan()
			flushTimers() -- opens the first
			OC:LOOT_CLOSED()
			flushTimers() -- the stale timeout is ignored; the next tick opens the second
			assert.are.equal(2, #used)
		end)

		it("ignores a stale answer timeout once the open was answered", function()
			OC:RunScan()
			flushTimers() -- opens the clam
			OC:LOOT_CLOSED()
			-- Every pending timer fires, including the first open's timeout. It must not count a refusal.
			flushTimers()
			flushTimers()
			assert.is_true(OC:IsEligible(BIG_MOUTH_CLAM))
		end)

		it("counts an unanswered open as a refusal after the timeout and moves on", function()
			bags[0][2] = UNKNOWN
			ns.db.global.openContainers.allowList[UNKNOWN] = true
			api.UseContainerItem = function(bag, slot)
				used[#used + 1] = { bag, slot }
				bags[bag][slot] = nil
			end
			OC:RunScan()
			flushTimers() -- opens the first; nobody answers
			flushTimers() -- the timeout fires and the next tick is scheduled
			flushTimers() -- opens the second
			assert.are.equal(2, #used)
		end)

		it("rescans on LOOT_CLOSED when the player looted something unrelated", function()
			OC:LOOT_CLOSED()
			assert.are.equal(1, #timers)
		end)
	end)

	describe("event registration", function()
		it("registers the rescan, unblock, loot and level events", function()
			OC:OnEnable()
			for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
				assert.are.equal("ScheduleScan", registered[event], event)
			end
			for _, event in ipairs({
				"UPDATE_STEALTH",
				"PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
				"MERCHANT_CLOSED",
				"MAIL_CLOSED",
				"BANKFRAME_CLOSED",
				"TRADE_CLOSED",
				"AUCTION_HOUSE_CLOSED",
				"GOSSIP_CLOSED",
				"QUEST_FINISHED",
			}) do
				assert.are.equal("OnUnblocked", registered[event], event)
			end
			assert.is_not_nil(registered.LOOT_CLOSED)
			assert.is_not_nil(registered.PLAYER_LEVEL_UP)
			assert.are.equal(1, castStarts)
		end)

		it("skips events this client does not have", function()
			state.invalidEvents.UPDATE_STEALTH = true
			state.invalidEvents.PLAYER_INTERACTION_MANAGER_FRAME_HIDE = true
			OC:OnEnable()
			assert.is_nil(registered.UPDATE_STEALTH)
			assert.is_nil(registered.PLAYER_INTERACTION_MANAGER_FRAME_HIDE)
			assert.are.equal("OnUnblocked", registered.MERCHANT_CLOSED)
		end)

		it("unregisters everything and stops the cast listener when disabled", function()
			OC:OnEnable()
			OC:OnDisable()
			assert.is_nil(next(registered))
			assert.are.equal(1, castStops)
		end)

		it("reuses one cast listener across enable and disable", function()
			OC:OnEnable()
			OC:OnDisable()
			OC:OnEnable()
			assert.are.equal(2, castStarts)
		end)
	end)

	describe("Refresh", function()
		it("enables when configured and supported, disables otherwise", function()
			OC:Refresh()
			assert.is_true(OC:IsEnabled())
			ns.db.global.openContainers.enabled = false
			OC:Refresh()
			assert.is_false(OC:IsEnabled())
		end)

		it("stays off on unsupported clients", function()
			ns.IsForever = function()
				return false
			end
			OC:Refresh()
			assert.is_false(OC:IsEnabled())
		end)
	end)
end)
