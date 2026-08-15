---@diagnostic disable: need-check-nil
local assert = require("luassert")
local match = require("luassert.match")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local spy = busted.spy
local stub = busted.stub

-- LootRolls.lua's Classic-Era CHAT_MSG_LOOT parsing (global-string pattern
-- matching for servers without C_LootHistory) is a separate, large concern
-- and isn't covered here — only the Retail C_LootHistory-driven lifecycle
-- and event handlers are tested in this file.
describe("LootRolls Module", function()
	local _ = match._
	---@type RLF_LootRolls, table
	local LootRolls, ns

	--- Builds a mock frame satisfying the {row = ..., frame = ...} surface
	--- FindRollRows/ReleaseRollRows expect from G_RLF.LootDisplay:GetAllFrames().
	---@param rowsByKey table<string, table> key -> mock row
	local function makeFrame(rowsByKey)
		return {
			GetRow = function(_, key)
				return rowsByKey[key]
			end,
			ReleaseRow = function() end,
		}
	end

	--- Builds a mock row satisfying the surface LootRolls.lua calls on it.
	local function makeRow()
		local row = {
			OnCancelRoll = function() end,
			OnRollResolved = function() end,
			OnMainSpecNeedRoll = function() end,
			OnRollWon = function() end,
			SetRollResults = function() end,
		}
		for name in pairs(row) do
			stub(row, name)
		end
		return row
	end

	--- G_RLF.LootDisplay:GetAllFrames() returns pairs(lootFrames) — a live
	--- iterator triple, not a plain list — so mocks must match that shape.
	---@param frames table[]
	local function framesFrom(frames)
		return function()
			return pairs(frames)
		end
	end

	before_each(function()
		ns = {
			FeatureModule = { LootRolls = "LootRolls" },
			LogEventSource = { WOWEVENT = "WOWEVENT" },
			IsRetail = function()
				return true
			end,
			DbAccessor = {
				IsFeatureNeededByAnyFrame = function()
					return true
				end,
			},
			LootDisplay = {
				GetAllFrames = framesFrom({}),
			},
			LootElementBase = {
				fromPayload = function(_, payload)
					local element = { payload = payload, Show = function() end }
					stub(element, "Show")
					return element
				end,
			},
			-- Placeholder so `G_RLF.WoWAPI.LootRolls` doesn't index nil at
			-- module-load time; tests override LootRolls._adapter directly
			-- after loading, same as ItemLoot_spec does for its own adapter.
			WoWAPI = { LootRolls = {} },
			LogDebug = spy.new(function() end),
			LogInfo = spy.new(function() end),
			LogWarn = spy.new(function() end),
			LogError = spy.new(function() end),
		}

		-- Mock FeatureBase — same minimal stub ItemLoot_spec.lua uses, so
		-- LootRolls tests are independent of AceAddon/AceEvent/AceBucket
		-- plumbing. Event handlers are invoked directly in these tests
		-- rather than through RegisterEvent dispatch.
		ns.FeatureBase = {
			new = function(_, name, depsOrMixin, ...)
				local deps = {}
				if type(depsOrMixin) == "table" then
					deps = depsOrMixin
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

		LootRolls = assert(loadfile("RPGLootFeed/Features/LootRolls/LootRolls.lua"))("TestAddon", ns)

		-- Per-test adapter overrides: reset to defaults each test, mirroring
		-- ItemLoot_spec.lua's ItemLoot.itemLootApi pattern.
		LootRolls._adapter = {
			GetLootRollItemInfo = function()
				return nil
			end,
			GetLootRollItemLink = function()
				return nil
			end,
			GetLootRollTimeLeft = function()
				return nil
			end,
			GetActiveLootRollIDs = function()
				return {}
			end,
			RollOnLoot = function() end,
			GetLootRollDuration = function()
				return 60
			end,
			GetItemInfoInstant = function()
				return nil
			end,
			GetAllEncounterInfos = function()
				return nil
			end,
			GetSortedDropsForEncounter = function()
				return nil
			end,
			GetSortedInfoForDrop = function()
				return nil
			end,
		}
	end)

	describe("START_LOOT_ROLL", function()
		it("tracks the roll and shows a LootRolls element", function()
			LootRolls._adapter.GetLootRollItemInfo = function()
				return 12345, "Finkle's Lava Dredger", 1, 4 -- texture, name, count, quality
			end
			LootRolls._adapter.GetLootRollItemLink = function()
				return "|cffa335ee|Hitem:18803::::::::60:::::|h[Finkle's Lava Dredger]|h|r"
			end
			LootRolls._adapter.GetItemInfoInstant = function()
				return 18803
			end

			LootRolls:START_LOOT_ROLL("START_LOOT_ROLL", 555, 60, 999)

			assert.is_not_nil(LootRolls._activeRolls[555])
			assert.are.equal("LootRoll_555", LootRolls._activeRolls[555].key)
			assert.are.equal(999, LootRolls._activeRolls[555].lootHandle)
			assert.are.equal(18803, LootRolls._activeRolls[555].itemID)
			assert.is_true(LootRolls._lootHandleMap[999][555])
		end)

		it("does nothing when the item has no name (not yet cached)", function()
			LootRolls._adapter.GetLootRollItemInfo = function()
				return nil, nil, nil, nil
			end

			LootRolls:START_LOOT_ROLL("START_LOOT_ROLL", 555, 60, 999)

			assert.is_nil(LootRolls._activeRolls)
		end)

		it("does nothing when the item link isn't available yet", function()
			LootRolls._adapter.GetLootRollItemInfo = function()
				return 12345, "Finkle's Lava Dredger", 1, 4
			end
			LootRolls._adapter.GetLootRollItemLink = function()
				return nil
			end

			LootRolls:START_LOOT_ROLL("START_LOOT_ROLL", 555, 60, 999)

			assert.is_nil(LootRolls._activeRolls)
		end)
	end)

	describe("FindRollRows / ReleaseRollRows", function()
		it("finds only rows whose key matches the rollID", function()
			local matchingRow = makeRow()
			local otherRow = makeRow()
			ns.LootDisplay.GetAllFrames = framesFrom({
				makeFrame({ ["LootRoll_555"] = matchingRow }),
				makeFrame({ ["LootRoll_999"] = otherRow }),
			})

			local results = LootRolls:FindRollRows(555)

			assert.are.equal(1, #results)
			assert.are.equal(matchingRow, results[1].row)
		end)

		it("cancels and releases every matching row", function()
			local row = makeRow()
			local frame = makeFrame({ ["LootRoll_555"] = row })
			stub(frame, "ReleaseRow")
			ns.LootDisplay.GetAllFrames = framesFrom({ frame })

			LootRolls:ReleaseRollRows(555)

			assert.stub(row.OnCancelRoll).was.called(1)
			assert.stub(frame.ReleaseRow).was.called_with(frame, row)
		end)
	end)

	describe("CANCEL_LOOT_ROLL", function()
		it("cancels only the matching roll's rows", function()
			local targetRow = makeRow()
			local otherRow = makeRow()
			ns.LootDisplay.GetAllFrames = framesFrom({
				makeFrame({ ["LootRoll_555"] = targetRow, ["LootRoll_999"] = otherRow }),
			})

			LootRolls:CANCEL_LOOT_ROLL("CANCEL_LOOT_ROLL", 555)

			assert.stub(targetRow.OnCancelRoll).was.called(1)
			assert.stub(otherRow.OnCancelRoll).was_not.called()
		end)
	end)

	describe("CANCEL_ALL_LOOT_ROLLS", function()
		it("releases every active roll and clears tracking", function()
			local row1, row2 = makeRow(), makeRow()
			ns.LootDisplay.GetAllFrames = framesFrom({
				makeFrame({ ["LootRoll_1"] = row1, ["LootRoll_2"] = row2 }),
			})
			LootRolls._activeRolls = { [1] = { key = "LootRoll_1" }, [2] = { key = "LootRoll_2" } }
			LootRolls._lootHandleMap = { [777] = { [1] = true, [2] = true } }

			LootRolls:CANCEL_ALL_LOOT_ROLLS("CANCEL_ALL_LOOT_ROLLS")

			assert.stub(row1.OnCancelRoll).was.called(1)
			assert.stub(row2.OnCancelRoll).was.called(1)
			assert.are.same({}, LootRolls._activeRolls)
			assert.are.same({}, LootRolls._lootHandleMap)
		end)

		it("does nothing when there are no active rolls", function()
			assert.has_no.errors(function()
				LootRolls:CANCEL_ALL_LOOT_ROLLS("CANCEL_ALL_LOOT_ROLLS")
			end)
		end)
	end)

	describe("MAIN_SPEC_NEED_ROLL", function()
		it("forwards the roll result to matching rows only", function()
			local targetRow = makeRow()
			local otherRow = makeRow()
			ns.LootDisplay.GetAllFrames = framesFrom({
				makeFrame({ ["LootRoll_555"] = targetRow, ["LootRoll_999"] = otherRow }),
			})

			LootRolls:MAIN_SPEC_NEED_ROLL("MAIN_SPEC_NEED_ROLL", 555, 42, true)

			assert.stub(targetRow.OnMainSpecNeedRoll).was.called_with(targetRow, 42, true)
			assert.stub(otherRow.OnMainSpecNeedRoll).was_not.called()
		end)
	end)

	describe("LOOT_ROLLS_COMPLETE", function()
		it("cancels and resolves every row grouped under the lootHandle", function()
			local row1, row2 = makeRow(), makeRow()
			ns.LootDisplay.GetAllFrames = framesFrom({
				makeFrame({ ["LootRoll_1"] = row1, ["LootRoll_2"] = row2 }),
			})
			LootRolls._lootHandleMap = { [777] = { [1] = true, [2] = true } }

			LootRolls:LOOT_ROLLS_COMPLETE("LOOT_ROLLS_COMPLETE", 777)

			assert.stub(row1.OnCancelRoll).was.called(1)
			assert.stub(row1.OnRollResolved).was.called(1)
			assert.stub(row2.OnCancelRoll).was.called(1)
			assert.stub(row2.OnRollResolved).was.called(1)
		end)

		it("does nothing for an untracked lootHandle", function()
			assert.has_no.errors(function()
				LootRolls:LOOT_ROLLS_COMPLETE("LOOT_ROLLS_COMPLETE", 12345)
			end)
		end)
	end)

	describe("LOOT_ITEM_ROLL_WON", function()
		it("notifies only rows whose tracked item matches the won item", function()
			local wonRow = makeRow()
			local otherRow = makeRow()
			ns.LootDisplay.GetAllFrames = framesFrom({
				makeFrame({ ["LootRoll_1"] = wonRow, ["LootRoll_2"] = otherRow }),
			})
			LootRolls._activeRolls = {
				[1] = { key = "LootRoll_1", itemID = 18803 },
				[2] = { key = "LootRoll_2", itemID = 99999 },
			}
			LootRolls._adapter.GetItemInfoInstant = function()
				return 18803
			end

			LootRolls:LOOT_ITEM_ROLL_WON("LOOT_ITEM_ROLL_WON", "itemlink", 1, 1, 88, false)

			assert.stub(wonRow.OnRollWon).was.called_with(wonRow, 1, 88, false)
			assert.stub(otherRow.OnRollWon).was_not.called()
		end)
	end)

	describe("PollLootHistory", function()
		it("pushes the first unclaimed matching drop to the row", function()
			local row = makeRow()
			ns.LootDisplay.GetAllFrames = framesFrom({ makeFrame({ ["LootRoll_1"] = row }) })
			LootRolls._activeRolls = { [1] = { key = "LootRoll_1", itemLink = "itemlink" } }
			LootRolls._adapter.GetItemInfoInstant = function()
				return 18803
			end
			LootRolls._adapter.GetAllEncounterInfos = function()
				return { { encounterID = 42 } }
			end
			local matchingDrop = { lootListID = 7, itemHyperlink = "itemlink" }
			LootRolls._adapter.GetSortedDropsForEncounter = function()
				return { matchingDrop }
			end

			LootRolls:PollLootHistory()

			assert.stub(row.SetRollResults).was.called_with(row, matchingDrop)
			assert.are.equal(1, LootRolls._historyMatchMap[42][7])
		end)

		it("skips a drop that's already claimed by another roll", function()
			local row1 = makeRow()
			ns.LootDisplay.GetAllFrames = framesFrom({ makeFrame({ ["LootRoll_1"] = row1 }) })
			LootRolls._activeRolls = { [1] = { key = "LootRoll_1", itemLink = "itemlink" } }
			LootRolls._historyMatchMap = { [42] = { [7] = 999 } } -- claimed by a different rollID
			LootRolls._adapter.GetItemInfoInstant = function()
				return 18803
			end
			LootRolls._adapter.GetAllEncounterInfos = function()
				return { { encounterID = 42 } }
			end
			LootRolls._adapter.GetSortedDropsForEncounter = function()
				return { { lootListID = 7, itemHyperlink = "itemlink" } }
			end

			LootRolls:PollLootHistory()

			assert.stub(row1.SetRollResults).was_not.called()
		end)
	end)

	describe("HandleHistoryDropUpdate", function()
		it("pushes the updated drop to the matching row", function()
			local row = makeRow()
			ns.LootDisplay.GetAllFrames = framesFrom({ makeFrame({ ["LootRoll_1"] = row }) })
			LootRolls._historyMatchMap = { [42] = { [7] = 1 } }
			local dropInfo = { lootListID = 7 }
			LootRolls._adapter.GetSortedInfoForDrop = function()
				return dropInfo
			end

			LootRolls:HandleHistoryDropUpdate(42, 7)

			assert.stub(row.SetRollResults).was.called_with(row, dropInfo)
		end)

		it("also reports a self win when the drop has a winner", function()
			local row = makeRow()
			ns.LootDisplay.GetAllFrames = framesFrom({ makeFrame({ ["LootRoll_1"] = row }) })
			LootRolls._historyMatchMap = { [42] = { [7] = 1 } }
			LootRolls._adapter.GetSortedInfoForDrop = function()
				return { lootListID = 7, winner = { isSelf = true, state = 0, roll = 99 } }
			end

			LootRolls:HandleHistoryDropUpdate(42, 7)

			assert.stub(row.OnRollWon).was.called_with(row, 0, 99, false)
		end)

		it("does nothing for an untracked encounter/lootListID pair", function()
			assert.has_no.errors(function()
				LootRolls:HandleHistoryDropUpdate(42, 7)
			end)
		end)
	end)
end)
