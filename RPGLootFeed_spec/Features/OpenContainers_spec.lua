local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("OpenContainers module", function()
	local ns, OC, api, timers, used, bags, state, requested, names, notified

	-- Known ids from the ported Classic Era data.
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
		timers, used, state =
			{}, {}, {
				combat = false,
				casting = false,
				stealthed = false,
				interaction = false,
				now = 0,
				level = 60,
				requiredLevel = 1,
				bindType = 0,
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
			GetItemRequirements = function()
				return state.requiredLevel, state.bindType
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
			UnitAffectingCombat = function()
				return state.combat
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
				return false
			end,
			IsClassic = function()
				return true
			end,
			IsTBCClassic = function()
				return false
			end,
			db = {
				global = {
					openContainers = {
						enabled = true,
						minFreeSlots = 4,
						skipBindOnPickup = true,
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
					RegisterEvent = function() end,
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
		it("has data for Classic Era but not for unsupported clients", function()
			assert.is_true(OC:IsSupported())
			ns.IsClassic = function()
				return false
			end
			assert.is_false(OC:IsSupported())
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
			ns.IsClassic = function()
				return false
			end
			assert.is_false(OC:Seed())
			assert.is_false(ns.db.global.openContainers.seeded)
		end)
	end)

	describe("ApplyAdditions", function()
		before_each(function()
			ns.OpenContainersData.additions[11] = {
				era = { allowList = { 111, 222 }, blockList = { 333 } },
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
			ns.IsClassic = function()
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

	describe("PassesItemRequirements", function()
		it("rejects items above the player's level", function()
			state.requiredLevel = 70
			assert.is_false(OC:PassesItemRequirements(BIG_MOUTH_CLAM))
		end)

		it("skips Bind on Pickup unless disabled", function()
			state.bindType = 1
			assert.is_false(OC:PassesItemRequirements(BIG_MOUTH_CLAM))
			ns.db.global.openContainers.skipBindOnPickup = false
			assert.is_true(OC:PassesItemRequirements(BIG_MOUTH_CLAM))
		end)

		it("tries uncached items", function()
			api.GetItemRequirements = function()
				return nil, nil
			end
			assert.is_true(OC:PassesItemRequirements(BIG_MOUTH_CLAM))
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

		it("does not open in combat", function()
			OC:RunScan()
			state.combat = true
			flushTimers()
			assert.are.equal(0, #used)
		end)

		it("keeps retrying while temporarily unsafe", function()
			OC:RunScan()
			state.interaction = true
			flushTimers()
			assert.are.equal(0, #used)
			state.interaction = false
			flushTimers()
			assert.are.equal(1, #used)
		end)

		it("sets an item aside after repeated unanswered opens", function()
			api.UseContainerItem = function(bag, slot)
				used[#used + 1] = { bag, slot } -- slot stays filled: the game refused
			end
			for _ = 1, 8 do
				OC:RunScan()
				state.now = state.now + 2
				flushTimers()
				flushTimers()
			end
			assert.is_true(#used <= 3)
			assert.is_false(OC:IsEligible(BIG_MOUTH_CLAM))
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
			ns.IsClassic = function()
				return false
			end
			OC:Refresh()
			assert.is_false(OC:IsEnabled())
		end)
	end)
end)
