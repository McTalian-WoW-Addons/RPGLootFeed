---@diagnostic disable: need-check-nil
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("ReputationHelpers", function()
	---@type RLF_RepUtils
	local RepUtils
	local ns

	--- Helper: build a minimal G_RLF namespace that satisfies ReputationHelpers at load time
	local function buildNs()
		local g = {
			L = setmetatable({}, {
				__index = function(_, k)
					return k
				end,
			}),
			DefaultIcons = { REPUTATION = 236681 },
			ItemQualEnum = { Rare = 3, Heirloom = 7 },
			LogDebug = function() end,
			LogInfo = function() end,
			LogWarn = function() end,
			LogError = function() end,
			IsRetail = function()
				return true
			end,
			AtlasIconCoefficients = {},
			DbAccessor = {
				Styling = function()
					return { fontSize = 12 }
				end,
				AnyFeatureConfig = function()
					return {}
				end,
			},
			Frames = { MAIN = 1 },
			-- db structure for the cache
			db = {
				global = {
					warbandFactions = {
						count = 0,
						cachedFactionDetailsById = {},
					},
				},
				char = {
					repFactions = {
						count = 0,
						cachedFactionDetailsById = {},
					},
				},
			},
		}
		return g
	end

	before_each(function()
		-- Provide minimal WoW API stubs in the global scope
		_G.bit = _G.bit or require("bit")
		_G.C_Reputation = {
			IsMajorFaction = function()
				return false
			end,
			IsFactionParagonForCurrentPlayer = function()
				return false
			end,
			IsAccountWideReputation = function()
				return false
			end,
			GetFactionDataByID = function()
				return nil
			end,
			GetGuildFactionData = function()
				return nil
			end,
		}
		_G.C_GossipInfo = {
			GetFriendshipReputation = function()
				return nil
			end,
			GetFriendshipReputationRanks = function()
				return nil
			end,
		}
		_G.C_MajorFactions = {
			GetMajorFactionRenownInfo = function()
				return nil
			end,
			GetMajorFactionData = function()
				return nil
			end,
		}
		_G.C_DelvesUI = nil
		_G.FACTION_BAR_COLORS = {
			[1] = { r = 0.8, g = 0.13, b = 0.13 },
			[2] = { r = 1, g = 0, b = 0 },
			[3] = { r = 1, g = 0.5, b = 0 },
			[4] = { r = 1, g = 1, b = 0 },
			[5] = { r = 0, g = 0.6, b = 0.1 },
			[6] = { r = 0, g = 1, b = 0 },
			[7] = { r = 0, g = 1, b = 0.5 },
			[8] = { r = 0, g = 1, b = 1 },
		}
		_G.ACCOUNT_WIDE_FONT_COLOR = { r = 1, g = 1, b = 1 }
		_G.FACTION_GREEN_COLOR = { r = 0, g = 0.6, b = 0.1 }
		_G.UnitSex = function()
			return 2
		end
		_G.GetText = function(key)
			return key
		end
		_G.CreateAtlasMarkup = function()
			return ""
		end

		ns = buildNs()
		assert(loadfile("RPGLootFeed/utils/ReputationHelpers.lua"))("TestAddon", ns)
		RepUtils = ns.RepUtils
	end)

	describe("GetDeltaAndUpdateCache", function()
		describe("first-time faction (no cache entry)", function()
			it("returns newStanding as the delta and creates cache entry", function()
				local fd = { rank = "Friendly", rankStandingMin = 0, rankStandingMax = 6000 }
				local repType = RepUtils.RepType.BaseFaction

				local delta = RepUtils.GetDeltaAndUpdateCache(1234, 500, fd, repType)

				assert.are.equal(500, delta)
				-- Cache should now exist
				local cached = ns.db.char.repFactions.cachedFactionDetailsById[1234]
				assert.is_not_nil(cached)
				assert.are.equal(500, cached.standing)
				assert.are.equal("Friendly", cached.rank)
				assert.are.equal(6000, cached.rankStandingMax)
				assert.are.equal(1, ns.db.char.repFactions.count)
			end)
		end)

		describe("normal rep gain (no level-up)", function()
			it("computes a simple positive delta", function()
				-- Seed cache: standing 200, rank "Friendly"
				ns.db.char.repFactions.cachedFactionDetailsById[1234] = {
					repType = RepUtils.RepType.BaseFaction,
					rank = "Friendly",
					standing = 200,
					rankStandingMin = 0,
					rankStandingMax = 6000,
				}
				ns.db.char.repFactions.count = 1

				local fd = { rank = "Friendly", rankStandingMin = 0, rankStandingMax = 6000 }
				local delta = RepUtils.GetDeltaAndUpdateCache(1234, 300, fd, RepUtils.RepType.BaseFaction)

				assert.are.equal(100, delta)
				assert.are.equal(300, ns.db.char.repFactions.cachedFactionDetailsById[1234].standing)
			end)
		end)

		describe("MajorFaction level-up", function()
			it("computes overflow delta when standing resets on renown level-up", function()
				-- Seed cache: renown level 5, standing 2200/2500
				ns.db.char.repFactions.cachedFactionDetailsById[5555] = {
					repType = RepUtils.RepType.MajorFaction,
					rank = 5,
					standing = 2200,
					rankStandingMin = 0,
					rankStandingMax = 2500,
				}
				ns.db.char.repFactions.count = 1

				-- After level-up: renown level 6, standing 100/2500 (gained 400 total)
				local fd = { rank = 6, rankStandingMin = 0, rankStandingMax = 2500 }
				local delta = RepUtils.GetDeltaAndUpdateCache(5555, 100, fd, RepUtils.RepType.MajorFaction)

				-- overflow: (2500 - 2200) + 100 = 400
				assert.are.equal(400, delta)
				-- Cache should be updated
				local cached = ns.db.char.repFactions.cachedFactionDetailsById[5555]
				assert.are.equal(100, cached.standing)
				assert.are.equal(6, cached.rank)
			end)
		end)

		describe("Friendship faction level-up (the bug)", function()
			it("computes overflow delta when standing resets on friendship rank-up", function()
				-- Seed cache: rank "Socialite", relative standing 400/500
				-- (friendInfo.standing=1900 - reactionThreshold=1500 = 400)
				ns.db.char.repFactions.cachedFactionDetailsById[2713] = {
					repType = RepUtils.RepType.Friendship,
					rank = "Socialite",
					standing = 400,
					rankStandingMin = 1500,
					rankStandingMax = 2000,
				}
				ns.db.char.repFactions.count = 1

				-- After rank-up to "Trendsetter":
				-- friendInfo.standing=2100, reactionThreshold=2000, nextThreshold=2500
				-- relative standing = 2100 - 2000 = 100
				-- newStanding = 100 (which is less than cached 400)
				-- Expected delta: (2000 - 1500) - 400 + 100  NO, using formula:
				-- rankStandingMax(2000) - cachedStanding(400) + newStanding(100)
				-- Wait, rankStandingMax is the OLD rankStandingMax from the cache.
				-- But the "standing" in cache is relative: 400 out of 500 range (1500..2000).
				-- No wait - rankStandingMax stored is the raw nextThreshold: 2000
				-- cachedDetails.standing is 400 (relative standing)
				-- So overflow: 2000 - 400 + 100 = 1700?? That's wrong.
				-- Hmm, let me re-read the GetFactionData code. For Friendship:
				--   factionData.standing = friendInfo.standing - friendInfo.reactionThreshold
				--   factionData.rankStandingMin = friendInfo.reactionThreshold
				--   factionData.rankStandingMax = friendInfo.nextThreshold
				-- So rankStandingMax = nextThreshold (absolute), but standing is relative.
				-- The range is actually rankStandingMax - rankStandingMin = 2000 - 1500 = 500.
				-- Standing of 400 out of 500.
				-- Overflow: remaining = 500 - 400 = 100; plus new standing 100 = 200 total.
				-- But the formula is: rankStandingMax - standing + newStanding
				-- = 2000 - 400 + 100 = 1700. That doesn't match!

				-- OK, the issue is that rankStandingMax for friendship is the absolute
				-- nextThreshold, not relative. But standing IS relative. There's a mismatch.
				-- For MajorFactions: standing is renownReputationEarned (0-based relative),
				-- rankStandingMax is renownLevelThreshold. So max - standing = remaining. Good.
				-- For Friendship: standing = friendInfo.standing - reactionThreshold (relative),
				-- rankStandingMax = friendInfo.nextThreshold (absolute threshold).
				-- remaining = nextThreshold - friendInfo.standing
				-- = (rankStandingMax) - (standing + rankStandingMin)
				-- = rankStandingMax - rankStandingMin - standing

				-- So for Friendship, the correct overflow formula would be:
				-- delta = (rankStandingMax - rankStandingMin - standing) + newStanding
				-- NOT: rankStandingMax - standing + newStanding

				-- Hmm... but the plan says to use the same formula. Let me re-examine.
				-- Actually wait. The issue was that for Friendship factions, the level-up
				-- branch was NEVER taken because it only checked IsMajorFaction.
				-- The simple delta formula gave: newStanding - cachedStanding = 100 - 400 = -300.
				-- That's the observed bug.

				-- With the fix (rank-based detection), the level-up branch IS now taken.
				-- The formula is: cachedDetails.rankStandingMax - cachedDetails.standing + newStanding
				-- = 2000 - 400 + 100 = 1700

				-- But the ACTUAL gain was only 200 (from 1900 to 2100 in absolute terms).
				-- So the formula is wrong for Friendship because rankStandingMax is absolute
				-- while standing is relative!

				-- For MajorFaction: standing=2200, rankStandingMax=2500 (both from 0-base)
				-- remaining = 2500 - 2200 = 300, + newStanding 100 = 400. Correct.

				-- For Friendship: standing=400 (relative), rankStandingMax=2000 (absolute)
				-- remaining should be (2000-1500) - 400 = 100, + newStanding 100 = 200. Correct.
				-- But formula gives 2000 - 400 + 100 = 1700. WRONG!

				-- We need: (rankStandingMax - rankStandingMin) - standing + newStanding
				-- Or equivalently: rankStandingMax - rankStandingMin - standing + newStanding

				-- I need to FIX the formula to account for rankStandingMin!
				-- For MajorFaction, rankStandingMin is always 0, so it doesn't matter.
				-- For Friendship, rankStandingMin is reactionThreshold (non-zero).

				-- Let me update the fix to handle this correctly.

				-- Actually wait, let me double check what GetFactionData stores.
				-- For Friendship (from GetFactionData):
				--   factionData.standing = friendInfo.standing - friendInfo.reactionThreshold  (RELATIVE to current rank)
				--   factionData.rankStandingMin = friendInfo.reactionThreshold (ABSOLUTE)
				--   factionData.rankStandingMax = friendInfo.nextThreshold (ABSOLUTE)
				--
				-- The "capacity" of the current rank = rankStandingMax - rankStandingMin
				-- Current progress within rank = standing (already relative)
				-- Remaining to level up = (rankStandingMax - rankStandingMin) - standing
				-- Overflow delta = remaining + newStanding
				--                = rankStandingMax - rankStandingMin - standing + newStanding

				-- For MajorFaction (from GetFactionData):
				--   factionData.standing = renownReputationEarned (relative to current level, starts at 0)
				--   factionData.rankStandingMin = 0
				--   factionData.rankStandingMax = renownLevelThreshold
				--
				-- Remaining = rankStandingMax - 0 - standing = rankStandingMax - standing
				-- So the formula with rankStandingMin works for both since min=0 for MajorFaction.

				-- NOW I understand: we had the wrong formula to begin with! It only worked
				-- for MajorFactions because rankStandingMin=0. The plan missed this detail.
				-- The correct generalized formula is:
				-- delta = (rankStandingMax - rankStandingMin) - standing + newStanding

				-- I need to fix the implementation I just applied! Let me not write this test
				-- yet, fix the formula first, then come back.

				-- For now let me write the test with the CORRECT expected value.
				-- Cache: standing=400, rankStandingMin=1500, rankStandingMax=2000
				-- New: standing=100, rank="Trendsetter"
				-- Correct delta: (2000 - 1500) - 400 + 100 = 200
				local fd = { rank = "Trendsetter", rankStandingMin = 2000, rankStandingMax = 2500 }
				local delta = RepUtils.GetDeltaAndUpdateCache(2713, 100, fd, RepUtils.RepType.Friendship)

				assert.are.equal(200, delta)
				local cached = ns.db.char.repFactions.cachedFactionDetailsById[2713]
				assert.are.equal(100, cached.standing)
				assert.are.equal("Trendsetter", cached.rank)
			end)

			it("handles multiple gains within the same rank correctly", function()
				-- Seed cache
				ns.db.char.repFactions.cachedFactionDetailsById[2713] = {
					repType = RepUtils.RepType.Friendship,
					rank = "Trendsetter",
					standing = 50,
					rankStandingMin = 2000,
					rankStandingMax = 2500,
				}
				ns.db.char.repFactions.count = 1

				-- Same rank, standing goes from 50 to 150
				local fd = { rank = "Trendsetter", rankStandingMin = 2000, rankStandingMax = 2500 }
				local delta = RepUtils.GetDeltaAndUpdateCache(2713, 150, fd, RepUtils.RepType.Friendship)

				assert.are.equal(100, delta)
			end)
		end)

		describe("warband faction routing", function()
			it("routes to warband cache when IsAccountWideReputation returns true", function()
				_G.C_Reputation.IsAccountWideReputation = function()
					return true
				end

				local fd = { rank = 1, rankStandingMin = 0, rankStandingMax = 2500 }
				local repType = bit.bor(RepUtils.RepType.MajorFaction, RepUtils.RepType.Warband)
				local delta = RepUtils.GetDeltaAndUpdateCache(9999, 300, fd, repType)

				assert.are.equal(300, delta)
				-- Should be in warband cache, not char cache
				assert.is_not_nil(ns.db.global.warbandFactions.cachedFactionDetailsById[9999])
				assert.is_nil(ns.db.char.repFactions.cachedFactionDetailsById[9999])
			end)
		end)

		describe("edge cases", function()
			it("uses default rankStandingMax of 2500 when cached value is nil", function()
				ns.db.char.repFactions.cachedFactionDetailsById[7777] = {
					repType = RepUtils.RepType.MajorFaction,
					rank = 3,
					standing = 2400,
					rankStandingMin = 0,
					rankStandingMax = nil,
				}
				ns.db.char.repFactions.count = 1

				local fd = { rank = 4, rankStandingMin = 0, rankStandingMax = 2500 }
				local delta = RepUtils.GetDeltaAndUpdateCache(7777, 50, fd, RepUtils.RepType.MajorFaction)

				-- overflow: (2500 - 0) - 2400 + 50 = 150
				-- with nil rankStandingMax defaulted to 2500
				assert.are.equal(150, delta)
			end)

			it("treats standing decrease WITHOUT rank change as negative delta", function()
				-- Possible if rep is lost (e.g., faction penalty)
				ns.db.char.repFactions.cachedFactionDetailsById[8888] = {
					repType = RepUtils.RepType.BaseFaction,
					rank = "Friendly",
					standing = 3000,
					rankStandingMin = 0,
					rankStandingMax = 6000,
				}
				ns.db.char.repFactions.count = 1

				local fd = { rank = "Friendly", rankStandingMin = 0, rankStandingMax = 6000 }
				local delta = RepUtils.GetDeltaAndUpdateCache(8888, 2500, fd, RepUtils.RepType.BaseFaction)

				assert.are.equal(-500, delta)
			end)
		end)
	end)

	describe("GetFactionData icon resolution", function()
		before_each(function()
			_G.C_Reputation.GetFactionDataByID = function()
				return {
					name = "Test Faction",
					reaction = 5,
					currentStanding = 500,
					currentReactionThreshold = 0,
					nextReactionThreshold = 6000,
				}
			end
		end)

		it("falls back to the flavor default icon when no override is configured", function()
			local fd = RepUtils.GetFactionData(1234, RepUtils.RepType.BaseFaction)
			assert.are.equal(236681, fd.icon)
		end)

		it("falls back to the flavor default icon when the override is an empty string", function()
			ns.DbAccessor.AnyFeatureConfig = function()
				return { repIconTexture = "" }
			end
			local fd = RepUtils.GetFactionData(1234, RepUtils.RepType.BaseFaction)
			assert.are.equal(236681, fd.icon)
		end)

		it("uses the configured numeric FileDataID override over the default", function()
			ns.DbAccessor.AnyFeatureConfig = function()
				return { repIconTexture = "135026" }
			end
			local fd = RepUtils.GetFactionData(1234, RepUtils.RepType.BaseFaction)
			assert.are.equal(135026, fd.icon)
		end)

		it("uses the configured texture path override over the default", function()
			ns.DbAccessor.AnyFeatureConfig = function()
				return { repIconTexture = "interface/icons/inv_shirt_guildtabard_01" }
			end
			local fd = RepUtils.GetFactionData(1234, RepUtils.RepType.BaseFaction)
			assert.are.equal("interface/icons/inv_shirt_guildtabard_01", fd.icon)
		end)

		it("does not stomp a real per-faction icon resolved from the faction ID map", function()
			-- 2601 is mapped to a real per-faction icon (The Weaver) in factionIdIconMap.
			ns.DbAccessor.AnyFeatureConfig = function()
				return { repIconTexture = "135026" }
			end
			local fd = RepUtils.GetFactionData(2601, RepUtils.RepType.BaseFaction)
			assert.are_not.equal(135026, fd.icon)
		end)
	end)
end)
