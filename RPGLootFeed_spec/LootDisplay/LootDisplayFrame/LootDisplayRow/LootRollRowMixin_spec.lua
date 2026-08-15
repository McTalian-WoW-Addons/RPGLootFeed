local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local rowFrameMocks = require("RPGLootFeed_spec._mocks.Internal.LootDisplayRowFrame")
local assert = require("luassert")
local match = require("luassert.match")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local stub = busted.stub

local MIXIN_FILE = "RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayRow/LootRollRowMixin.lua"

--- Minimal dummy roll-action button: everything _LayoutRollButtons and
--- CleanupLootRoll touch, as busted stubs so tests can assert on them.
local function newDummyButton()
	local btn = {}
	for _, name in ipairs({ "ClearAllPoints", "SetPoint", "Show", "Hide", "SetScript" }) do
		btn[name] = function() end
		stub(btn, name)
	end
	return btn
end

describe("RLF_LootRollRowMixin", function()
	local ns, row

	before_each(function()
		-- Loot-roll global constants. LOOT_ROLL_TYPE_* are indexed into the
		-- ROLL_BUTTON_ATLAS table at module-load time, so they must exist
		-- before loadfile() runs the mixin.
		_G.LOOT_ROLL_TYPE_PASS = 0
		_G.LOOT_ROLL_TYPE_NEED = 1
		_G.LOOT_ROLL_TYPE_GREED = 2
		_G.LOOT_ROLL_TYPE_DISENCHANT = 3
		_G.NEED = "Need"
		_G.GREED = "Greed"
		_G.PASS = "Pass"
		_G.ROLL_DISENCHANT = "Disenchant"
		_G.TRANSMOGRIFICATION = "Transmogrification"
		_G.LOOT_HISTORY_WAITING_ON = "Waiting on"
		_G.LOOT_HISTORY_ALL_PASSED = "All passed"
		_G.LOOT_ROLLS = "Loot Rolls"

		-- Additive-only: other spec files in this process share _G.Enum.
		_G.Enum = _G.Enum or {}
		_G.Enum.StatusBarInterpolation = _G.Enum.StatusBarInterpolation or { Immediate = 1 }
		_G.Enum.StatusBarTimerDirection = _G.Enum.StatusBarTimerDirection or { RemainingTime = 1 }

		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		ns.FeatureModule = { LootRolls = "LootRolls" }

		assert(loadfile(MIXIN_FILE))("TestAddon", ns)

		row = rowFrameMocks.new()
		for k, v in pairs(RLF_LootRollRowMixin) do
			row[k] = v
		end
		row.frameType = ns.Frames.MAIN

		-- Cross-mixin methods LootRollRowMixin calls but doesn't own (they
		-- live on RowTextMixin / RowAnimationMixin) — stub as no-ops so this
		-- file tests LootRollRowMixin in isolation, matching the pattern
		-- RowTimerBarMixin_spec.lua uses for its own cross-mixin calls.
		row.LayoutPrimaryLine = function() end
		row.LayoutSecondaryLine = function() end
		row._LayoutRowLines = function() end
		row.StyleExitAnimation = function() end
		row.ResetFadeOut = function() end
		row.ResetTimerBar = function() end
		stub(row, "LayoutPrimaryLine")
		stub(row, "StyleExitAnimation")
		stub(row, "ResetFadeOut")
		stub(row, "ResetTimerBar")
		row.ClickableButton.GetScript = function()
			return nil
		end
		-- CleanupLootRoll clears the roll-tooltip hooks on SecondaryText;
		-- the shared mock builder doesn't stub SetScript on FontStrings.
		row.SecondaryText.SetScript = function() end
		stub(row.SecondaryText, "SetScript")

		-- Mock TimerBar StatusBar (hardware C_DurationUtil surface + the
		-- static SetMinMaxValues/SetValue fallback surface).
		row.TimerBar = {
			Show = function() end,
			Hide = function() end,
			SetHeight = function() end,
			SetStatusBarColor = function() end,
			SetMinMaxValues = function() end,
			SetValue = function() end,
			SetTimerDuration = function() end,
		}
		stub(row.TimerBar, "Show")
		stub(row.TimerBar, "SetMinMaxValues")
		stub(row.TimerBar, "SetValue")
		stub(row.TimerBar, "SetTimerDuration")

		-- Retail hardware-accelerated countdown path (C_DurationUtil).
		local durationMock = { SetTimeFromStart = function() end }
		_G.C_DurationUtil = {
			CreateDuration = function()
				return durationMock
			end,
		}
		_G.GetTime = function()
			return 1000
		end

		stub(ns.DbAccessor, "Animations").returns({
			timerBar = { height = 2, color = { 0.5, 0.5, 0.5 }, alpha = 0.7 },
			exit = { disable = false },
		})
		stub(ns.DbAccessor, "Styling").returns({
			enabledSecondaryRowText = false,
		})
		stub(ns.DbAccessor, "Sizing").returns({
			iconSize = 24,
			padding = 4,
		})
	end)

	describe("PostBootstrapFromElement", function()
		it("ignores elements that aren't a LootRolls element", function()
			row:PostBootstrapFromElement({ type = "SomethingElse" })

			assert.is_nil(row.rollID)
			assert.is_nil(row._rollButtons)
		end)

		it("sets up an active roll row: never-fade, buttons, timer bar", function()
			stub(row, "_CreateRollButton", function()
				return newDummyButton()
			end)

			row:PostBootstrapFromElement({
				type = ns.FeatureModule.LootRolls,
				rollID = 555,
				canNeed = true,
				canGreed = true,
				canTransmog = false,
				rollDuration = 60,
			})

			assert.are.equal(555, row.rollID)
			assert.is_false(row._rolled)
			assert.is_true(row._isLootRollRow)
			assert.are.equal(math.pow(2, 19), row.showForSeconds)
			assert.is_true(row.hasElementFadeOverride)
			assert.stub(row.StyleExitAnimation).was.called(1)

			-- Need, Greed, Pass — no Transmog (canTransmog false), no
			-- Disenchant (retail). match._ for `self` sidesteps a deep
			-- same()-comparison over the large, self-referential mock row
			-- (its own _CreateRollButton stub holds a back-reference to it).
			assert.are.equal(3, #row._rollButtons)
			assert.stub(row._CreateRollButton).was.called_with(match._, _G.NEED, _G.LOOT_ROLL_TYPE_NEED, true, nil)
			assert.stub(row._CreateRollButton).was.called_with(match._, _G.GREED, _G.LOOT_ROLL_TYPE_GREED, true, nil)
			assert.stub(row._CreateRollButton).was.called_with(match._, _G.PASS, _G.LOOT_ROLL_TYPE_PASS, true, nil)

			-- Timer bar was started from the roll-action phase.
			assert.is_true(row._rollTimerBarActive)
			assert.stub(row.TimerBar.SetTimerDuration).was.called(1)
		end)

		it("creates a Transmog button instead of Greed when canTransmog is true", function()
			stub(row, "_CreateRollButton", function()
				return newDummyButton()
			end)

			row:PostBootstrapFromElement({
				type = ns.FeatureModule.LootRolls,
				rollID = 555,
				canNeed = true,
				canGreed = true,
				canTransmog = true,
				rollDuration = 60,
			})

			assert.are.equal(3, #row._rollButtons)
			assert.stub(row._CreateRollButton).was.called_with(match._, _G.TRANSMOGRIFICATION, 4, true, nil)
			assert
				.stub(row._CreateRollButton).was_not
				.called_with(match._, _G.GREED, _G.LOOT_ROLL_TYPE_GREED, match._, match._)
		end)
	end)

	describe("OnRollCast", function()
		local btn1, btn2

		before_each(function()
			btn1, btn2 = newDummyButton(), newDummyButton()
			row._rollButtons = { btn1, btn2 }
		end)

		it("hides the roll buttons and marks the row as rolled", function()
			row:OnRollCast(_G.GREED, _G.LOOT_ROLL_TYPE_GREED)

			assert.is_true(row._rolled)
			assert.stub(btn1.Hide).was.called(1)
			assert.stub(btn2.Hide).was.called(1)
			assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, _G.GREED)
			assert.stub(row.ItemCountText.Show).was.called(1)
			assert.stub(row.LayoutPrimaryLine).was.called(1)
		end)

		it("shows greyed-out Pass text when the player passes", function()
			row:OnRollCast(_G.PASS, _G.LOOT_ROLL_TYPE_PASS)

			assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "|cffb0b0b0Pass|r")
		end)
	end)

	describe("OnMainSpecNeedRoll", function()
		it("does nothing before the player has rolled", function()
			row._rolled = false

			row:OnMainSpecNeedRoll(42, true)

			assert.stub(row.ItemCountText.SetText).was_not.called()
		end)

		it("shows a green roll result when winning", function()
			row._rolled = true

			row:OnMainSpecNeedRoll(42, true)

			assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "|cff00ff00Need (42)|r")
		end)

		it("shows a grey roll result when losing", function()
			row._rolled = true

			row:OnMainSpecNeedRoll(17, false)

			assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "|cffb0b0b0Need (17)|r")
		end)
	end)

	describe("OnRollWon", function()
		it("shows the won roll type, value, and upgrade suffix", function()
			row:OnRollWon(1, 77, true) -- 1 == Need

			assert
				.stub(row.ItemCountText.SetText).was
				.called_with(row.ItemCountText, "|cff00ff00Need Won! (77) (Upgraded!)|r")
		end)

		it("omits the upgrade suffix when not upgraded", function()
			row:OnRollWon(2, 55, false) -- 2 == Greed

			assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "|cff00ff00Greed Won! (55)|r")
		end)

		it("shows the Disenchant roll type via ROLL_DISENCHANT, not the nonexistent DISENCHANT global", function()
			row:OnRollWon(3, 20, false) -- 3 == Disenchant

			assert
				.stub(row.ItemCountText.SetText).was
				.called_with(row.ItemCountText, "|cff00ff00Disenchant Won! (20)|r")
		end)
	end)

	describe("SetRollResults", function()
		describe("while still waiting on other players", function()
			it("does not touch the timer bar already running from the roll-action phase", function()
				-- Roll-action phase: START_LOOT_ROLL already set up the
				-- hardware-accelerated countdown via _SetupRollTimerBar.
				row.rollID = 555
				row:_SetupRollTimerBar(60)

				assert.stub(row.TimerBar.SetTimerDuration).was.called(1)
				assert.stub(row.TimerBar.SetMinMaxValues).was_not.called()
				assert.stub(row.TimerBar.SetValue).was_not.called()

				-- A LOOT_HISTORY_UPDATE_DROP event lands while a party member
				-- is still rolling — the roll isn't resolved yet.
				row:SetRollResults({
					duration = 60,
					rollInfos = {
						{ playerName = "Bob", playerClass = "WARRIOR", state = 4 }, -- waiting
					},
				})

				-- The static fallback must not stomp the hardware countdown
				-- already ticking down from the roll-action phase.
				assert.stub(row.TimerBar.SetMinMaxValues).was_not.called()
				assert.stub(row.TimerBar.SetValue).was_not.called()
			end)

			it("shows a static full bar when no roll-action timer was ever started", function()
				-- e.g. row replayed after a UI reload — _SetupRollTimerBar was
				-- never called for this row, so there's nothing to clobber.
				row._rolled = true

				row:SetRollResults({
					duration = 60,
					currentLeader = { playerName = "Carl", playerClass = "MAGE", roll = 33 },
					rollInfos = {
						{ playerName = "Carl", playerClass = "MAGE", state = 4 },
					},
				})

				assert.stub(row.TimerBar.SetMinMaxValues).was.called_with(row.TimerBar, 0, 60)
				assert.stub(row.TimerBar.SetValue).was.called_with(row.TimerBar, 60)
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Carl leads (33)")
				assert.is_nil(row._resolved)
			end)
		end)

		describe("when a winner is decided", function()
			it("shows the self-win text and resolves the row", function()
				row:SetRollResults({
					winner = { playerClass = "WARRIOR", isSelf = true, roll = 88, state = 0 },
					rollInfos = {
						{ playerName = "Self", playerClass = "WARRIOR", state = 0 },
					},
				})

				assert
					.stub(row.ItemCountText.SetText).was
					.called_with(row.ItemCountText, "|cff00ff00You won! (Need, 88)|r")
				assert.is_true(row._resolved)
				assert.is_false(row._isLootRollRow)
				assert.are.equal(60, row.showForSeconds)
			end)

			it("shows another player's win text and resolves the row", function()
				row:SetRollResults({
					winner = { playerClass = "UNKNOWN", playerName = "Bob", isSelf = false, roll = 55, state = 3 },
					rollInfos = {
						{ playerName = "Bob", playerClass = "UNKNOWN", state = 3 },
					},
				})

				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Bob won (Greed, 55)")
				assert.is_true(row._resolved)
			end)
		end)

		describe("when everyone passes", function()
			it("shows the all-passed text and resolves the row", function()
				row:SetRollResults({
					rollInfos = {
						{ playerName = "A", playerClass = "UNKNOWN", state = 5 },
						{ playerName = "B", playerClass = "UNKNOWN", state = 5 },
					},
				})

				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "|cffb0b0b0All passed|r")
				assert.is_true(row._resolved)
			end)
		end)
	end)

	describe("OnRollResolved", function()
		it("switches the row into a normal auto-hiding row", function()
			row:OnRollResolved()

			assert.is_true(row._resolved)
			assert.is_false(row._isLootRollRow)
			assert.are.equal(60, row.showForSeconds)
			assert.is_true(row.hasElementFadeOverride)
			assert.stub(row.StyleExitAnimation).was.called(1)
			assert.stub(row.ResetFadeOut).was.called(1)
		end)

		it("is idempotent — a second call does nothing", function()
			row:OnRollResolved()
			row:OnRollResolved()

			assert.stub(row.StyleExitAnimation).was.called(1)
			assert.stub(row.ResetFadeOut).was.called(1)
		end)
	end)

	describe("_BuildRollTooltipLines", function()
		it("uses LOOT_HISTORY_WAITING_ON for the waiting-section header when it exists (Retail)", function()
			_G.LOOT_HISTORY_WAITING_ON = "Custom Waiting Label"
			local lines = {}

			row:_BuildRollTooltipLines({
				rollInfos = { { playerName = "Bob", playerClass = "WARRIOR", state = 4 } },
			}, lines)

			assert.are.equal("Custom Waiting Label (1)", lines[1][1])
		end)

		it("falls back to a plain label when LOOT_HISTORY_WAITING_ON doesn't exist (Classic)", function()
			_G.LOOT_HISTORY_WAITING_ON = nil
			local lines = {}

			row:_BuildRollTooltipLines({
				rollInfos = { { playerName = "Bob", playerClass = "WARRIOR", state = 4 } },
			}, lines)

			assert.are.equal("Waiting on (1)", lines[1][1])
		end)
	end)

	describe("CleanupLootRoll", function()
		it("untracks the roll and resets all row state", function()
			row.moduleRef = { _UntrackRoll = function() end }
			stub(row.moduleRef, "_UntrackRoll")

			local btn = newDummyButton()
			row.rollID = 999
			row._rolled = true
			row._resolved = true
			row._rollTimerBarActive = true
			row._rollButtons = { btn }
			row._rollDropInfo = { rollInfos = {} }
			row._rollTimerFrame = { SetScript = function() end }
			stub(row._rollTimerFrame, "SetScript")

			row:CleanupLootRoll()

			assert.stub(row.moduleRef._UntrackRoll).was.called_with(row.moduleRef, 999)
			assert.is_nil(row.rollID)
			assert.is_false(row._rolled)
			assert.is_nil(row._resolved)
			assert.is_nil(row._rollTimerBarActive)
			assert.is_nil(row._rollButtons)
			assert.is_nil(row._rollDropInfo)
			assert.stub(btn.Hide).was.called(1)
			assert.stub(btn.SetScript).was.called_with(btn, "OnClick", nil)
			assert.stub(btn.SetScript).was.called_with(btn, "OnEnter", nil)
			assert.stub(btn.SetScript).was.called_with(btn, "OnLeave", nil)
			assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, nil)
			assert.stub(row.ItemCountText.Hide).was.called(1)
			assert.is_nil(row._rollTimerFrame)
			assert.stub(row.ResetTimerBar).was.called(1)
		end)
	end)
end)
