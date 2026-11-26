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
	for _, name in ipairs({ "ClearAllPoints", "SetPoint", "Show", "Hide", "SetScript", "SetFrameLevel" }) do
		btn[name] = function() end
		stub(btn, name)
	end
	return btn
end

describe("RLF_LootRollRowMixin", function()
	local ns, row, rollFramesOverride

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
		_G.YOU = "You"

		-- Additive-only: other spec files in this process share _G.Enum.
		_G.Enum = _G.Enum or {}
		_G.Enum.StatusBarInterpolation = _G.Enum.StatusBarInterpolation or { Immediate = 1 }
		_G.Enum.StatusBarTimerDirection = _G.Enum.StatusBarTimerDirection or { RemainingTime = 1 }

		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		ns.FeatureModule = { LootRolls = "LootRolls" }

		-- Class-color adapter seam (WoWAPIAdapters.lua's G_RLF.WoWAPI.LootRolls).
		-- Default stub resolves no colors, matching prior (unmocked
		-- RAID_CLASS_COLORS) behavior for tests that don't care about color.
		-- Individual tests override GetClassColor/GetRaidClassColor to prove
		-- the row actually goes through this seam rather than the global.
		ns.WoWAPI = {
			LootRolls = {
				GetExpansionLevel = function()
					return ns.Expansion.BFA
				end,
				GetClassColor = function()
					return nil
				end,
				GetRaidClassColor = function()
					return nil
				end,
				GetLootRollTimeLeft = function()
					return nil
				end,
			},
		}

		rollFramesOverride = { Refresh = function() end }
		stub(rollFramesOverride, "Refresh")
		ns.RLF.GetModule = function(_, name)
			if name == ns.BlizzModule.LootRollFrames then
				return rollFramesOverride
			end
			return {}
		end

		assert(loadfile(MIXIN_FILE))("TestAddon", ns)

		row = rowFrameMocks.new()
		for k, v in pairs(RLF_LootRollRowMixin) do
			row[k] = v
		end
		row.frameType = ns.Frames.MAIN
		-- Real frame-level storage so SetFrameLevel/GetFrameLevel behave like WoW's.
		row._level = 500
		row.GetFrameLevel = function(self)
			return self._level
		end
		row.SetFrameLevel = function(self, level)
			self._level = level
		end

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
		row.StartTimerBar = function() end
		stub(row, "StartTimerBar")
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

	describe("roll button frame level (issue #662)", function()
		local function bootstrapWithButtons()
			local buttons = {}
			stub(row, "_CreateRollButton", function()
				local btn = newDummyButton()
				buttons[#buttons + 1] = btn
				return btn
			end)
			row:PostBootstrapFromElement({
				type = ns.FeatureModule.LootRolls,
				rollID = 555,
				canNeed = true,
				canGreed = true,
				canTransmog = false,
				rollDuration = 60000,
			})
			return buttons
		end

		it("raises the buttons above the row's own children", function()
			local buttons = bootstrapWithButtons()

			assert.are.equal(3, #buttons)
			for _, btn in ipairs(buttons) do
				assert.stub(btn.SetFrameLevel).was.called_with(match._, 505)
			end
		end)

		it("keeps the buttons above the row whenever the row is re-leveled", function()
			local buttons = bootstrapWithButtons()

			row:SetFrameLevel(480)

			assert.are.equal(480, row:GetFrameLevel())
			for _, btn in ipairs(buttons) do
				assert.stub(btn.SetFrameLevel).was.called_with(match._, 485)
			end
		end)

		it("does not stack wrappers when the row is bootstrapped again", function()
			bootstrapWithButtons()
			local wrapped = row.SetFrameLevel
			bootstrapWithButtons()

			assert.are.equal(wrapped, row.SetFrameLevel)
		end)

		it("re-leveling a row with no roll buttons is harmless", function()
			bootstrapWithButtons()
			row._rollButtons = nil

			assert.has_no.errors(function()
				row:SetFrameLevel(300)
			end)
			assert.are.equal(300, row:GetFrameLevel())
		end)
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
				rollDuration = 60000,
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

			-- Timer bar was started from the roll-action phase, in seconds.
			assert.is_true(row._rollTimerBarActive)
			assert.stub(row.StartTimerBar).was.called_with(match._, 60)
		end)

		it("counts down the live time left, converted from ms to seconds", function()
			stub(row, "_CreateRollButton", function()
				return newDummyButton()
			end)
			ns.WoWAPI.LootRolls.GetLootRollTimeLeft = function(rollID)
				assert.are.equal(555, rollID)
				return 42500
			end

			row:PostBootstrapFromElement({
				type = ns.FeatureModule.LootRolls,
				rollID = 555,
				canNeed = true,
				canGreed = true,
				canTransmog = false,
				rollDuration = 60000,
			})

			assert.stub(row.StartTimerBar).was.called_with(match._, 42.5)
		end)

		it("asks the Blizzard roll frame override to re-check once the row exists", function()
			stub(row, "_CreateRollButton", function()
				return newDummyButton()
			end)

			row:PostBootstrapFromElement({
				type = ns.FeatureModule.LootRolls,
				rollID = 555,
				canNeed = true,
				canGreed = true,
				canTransmog = false,
				rollDuration = 60000,
			})

			assert.stub(rollFramesOverride.Refresh).was.called(1)
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
				rollDuration = 60000,
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

	describe("with the secondary text line enabled", function()
		before_each(function()
			ns.DbAccessor.Styling = function()
				return { enabledSecondaryRowText = true, textAlignment = 1, rowTextSpacing = 0 }
			end
			stub(row.SecondaryText, "SetText")
			stub(row.SecondaryText, "Show")
			stub(row.SecondaryText, "Hide")
			row.SecondaryLineLayout.Show = function() end
			row.SecondaryLineLayout.Hide = function() end
			stub(row.SecondaryLineLayout, "Hide")
			row.LayoutSecondaryLine = function() end
			row.rollID = 555
			row._rolled = true
		end)

		it("puts the leader after the waiting count on the secondary line, not on the primary line", function()
			row:SetRollResults({
				currentLeader = { playerName = "Carl", playerClass = "MAGE", roll = 33 },
				rollInfos = {
					{ playerName = "Carl", playerClass = "MAGE", state = 4 },
					{ playerName = "Dee", playerClass = "MAGE", state = 4 },
				},
			})

			assert
				.stub(row.SecondaryText.SetText).was
				.called_with(row.SecondaryText, "Waiting on 2 player(s) - Carl leads (33)")
			assert.stub(row.ItemCountText.SetText).was_not.called()
		end)

		it("shows the winner on the secondary line and resolves the row", function()
			row:SetRollResults({
				winner = { playerName = "Bob", playerClass = "WARRIOR", roll = 55, state = 3 },
				rollInfos = { { playerName = "Bob", playerClass = "WARRIOR", state = 3 } },
			})

			assert.stub(row.SecondaryText.SetText).was.called_with(row.SecondaryText, "Bob won (Greed, 55)")
			assert.stub(row.ItemCountText.SetText).was_not.called()
			assert.is_true(row._resolved)
		end)

		it("shows 'You won!' on the secondary line", function()
			row:SetRollResults({
				winner = { playerClass = "WARRIOR", isSelf = true, roll = 88, state = 0 },
				rollInfos = { { playerName = "Self", playerClass = "WARRIOR", state = 0 } },
			})

			assert.stub(row.SecondaryText.SetText).was.called_with(row.SecondaryText, "|cff00ff00You won! (Need, 88)|r")
		end)

		it("shows 'All passed' on the secondary line", function()
			row:SetRollResults({
				rollInfos = { { playerName = "Carl", playerClass = "MAGE", state = 5 } },
			})

			assert.stub(row.SecondaryText.SetText).was.called_with(row.SecondaryText, "|cffb0b0b0All passed|r")
			assert.stub(row.ItemCountText.SetText).was_not.called()
		end)

		it("hides the secondary line when there is nothing to say", function()
			row._rolled = false
			row:SetRollResults({
				rollInfos = { { playerName = "Carl", playerClass = "MAGE", state = 1 } },
			})

			assert.stub(row.SecondaryLineLayout.Hide).was.called()
			assert.stub(row.SecondaryText.SetText).was_not.called()
		end)

		it("shows a won roll from LOOT_ITEM_ROLL_WON on the secondary line", function()
			row:OnRollWon(2, 55, false)

			assert.stub(row.SecondaryText.SetText).was.called_with(row.SecondaryText, "|cff00ff00Greed Won! (55)|r")
			assert.stub(row.ItemCountText.SetText).was_not.called()
		end)

		it("keeps the player's own choice on the primary line", function()
			row._rollButtons = { newDummyButton() }
			row:OnRollCast(_G.GREED, _G.LOOT_ROLL_TYPE_GREED)
			row:SetRollResults({
				winner = { playerName = "Bob", playerClass = "WARRIOR", roll = 55, state = 3 },
				rollInfos = { { playerName = "Bob", playerClass = "WARRIOR", state = 3 } },
			})

			assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, _G.GREED)
			assert.stub(row.ItemCountText.SetText).was.called(1)
		end)

		it("re-renders when the secondary line setting changes between identical results", function()
			local results = {
				winner = { playerName = "Bob", playerClass = "WARRIOR", roll = 55, state = 3 },
				rollInfos = { { playerName = "Bob", playerClass = "WARRIOR", state = 3 } },
			}
			row:SetRollResults(results)
			ns.DbAccessor.Styling = function()
				return { enabledSecondaryRowText = false, textAlignment = 1, rowTextSpacing = 0 }
			end

			row:SetRollResults(results)

			assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Bob won (Greed, 55)")
		end)
	end)

	describe("Loot Rolls options", function()
		local function setOptions(opts)
			ns.db.global.frames[row.frameType].features.lootRolls = opts
		end

		local function bootstrap()
			stub(row, "_CreateRollButton", function()
				return newDummyButton()
			end)
			stub(row, "_SetupRollTimerBar")
			row:PostBootstrapFromElement({
				type = ns.FeatureModule.LootRolls,
				rollID = 555,
				canNeed = true,
				canGreed = true,
				canTransmog = false,
				rollDuration = 60000,
			})
		end

		local function winner(isSelf)
			return {
				winner = { playerName = "Bob", playerClass = "UNKNOWN", isSelf = isSelf, roll = 55, state = 3 },
				rollInfos = { { playerName = "Bob", playerClass = "UNKNOWN", state = 3 } },
			}
		end

		describe("roll buttons (issue #641)", function()
			it("defaults to showing the buttons", function()
				assert.is_true(row:ShowsRollButtons())
				bootstrap()
				assert.are.equal(3, #row._rollButtons)
			end)

			it("creates no buttons when turned off", function()
				setOptions({ showRollButtons = false })
				assert.is_false(row:ShowsRollButtons())

				bootstrap()

				assert.stub(row._CreateRollButton).was_not.called()
				assert.are.equal(0, #row._rollButtons)
			end)

			it("is still a live roll row, so results and cleanup keep working", function()
				setOptions({ showRollButtons = false })
				bootstrap()

				assert.are.equal(555, row.rollID)
				assert.is_true(row._isLootRollRow)
				row:SetRollResults(winner(false))
				assert.is_true(row._resolved)
			end)
		end)

		describe("button spacing and padding", function()
			local function layoutWith(opts)
				setOptions(opts)
				local buttons = { newDummyButton(), newDummyButton() }
				row._rollButtons = buttons
				row:_LayoutRollButtons()
				return buttons
			end

			it("keeps the old 4px gap and 8px padding by default", function()
				local buttons = layoutWith({ buttonSize = 20 })
				-- Rightmost button: padding only. Next one: padding plus one button and one gap.
				assert.stub(buttons[2].SetPoint).was.called_with(match._, "RIGHT", match._, "RIGHT", -8, 0)
				assert.stub(buttons[1].SetPoint).was.called_with(match._, "RIGHT", match._, "RIGHT", -(20 + 4) - 8, 0)
			end)

			it("uses the configured gap and padding", function()
				local buttons = layoutWith({ buttonSize = 20, buttonGap = 10, buttonPadding = 2 })
				assert.stub(buttons[2].SetPoint).was.called_with(match._, "RIGHT", match._, "RIGHT", -2, 0)
				assert.stub(buttons[1].SetPoint).was.called_with(match._, "RIGHT", match._, "RIGHT", -(20 + 10) - 2, 0)
			end)
		end)

		describe("results text", function()
			it("hides roll numbers in a win when turned off", function()
				setOptions({ showRollNumbers = false })
				row:SetRollResults(winner(false))
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Bob won (Greed)")
			end)

			it("hides roll numbers in your own win when turned off", function()
				setOptions({ showRollNumbers = false })
				row:SetRollResults({
					winner = { playerClass = "UNKNOWN", isSelf = true, roll = 88, state = 0 },
					rollInfos = { { playerName = "Self", playerClass = "UNKNOWN", state = 0 } },
				})
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "|cff00ff00You won! (Need)|r")
			end)

			it("hides the number on the current leader when turned off", function()
				setOptions({ showRollNumbers = false })
				row._rolled = true
				row:SetRollResults({
					currentLeader = { playerName = "Carl", playerClass = "UNKNOWN", roll = 33 },
					rollInfos = { { playerName = "Carl", playerClass = "UNKNOWN", state = 4 } },
				})
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Carl leads")
			end)

			it("hides the number on LOOT_ITEM_ROLL_WON and on your Need result when turned off", function()
				setOptions({ showRollNumbers = false })
				row:OnRollWon(2, 55, false)
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "|cff00ff00Greed Won!|r")
				row._rolled = true
				row:OnMainSpecNeedRoll(42, true)
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "|cff00ff00Need|r")
			end)

			it("does not show the current leader when turned off", function()
				setOptions({ showLeader = false })
				row._rolled = true
				row:SetRollResults({
					currentLeader = { playerName = "Carl", playerClass = "UNKNOWN", roll = 33 },
					rollInfos = { { playerName = "Carl", playerClass = "UNKNOWN", state = 4 } },
				})
				assert.stub(row.ItemCountText.SetText).was_not.called()
			end)

			it("still shows the winner when the leader is turned off", function()
				setOptions({ showLeader = false })
				row:SetRollResults(winner(false))
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Bob won (Greed, 55)")
			end)

			it("leaves names uncolored when class colors are turned off", function()
				setOptions({ useClassColors = false })
				ns.WoWAPI.LootRolls.GetClassColor = function()
					return {
						WrapTextInColorCode = function(_, text)
							return "|cffMOCKED" .. text .. "|r"
						end,
					}
				end
				local results = winner(false)
				results.winner.playerClass = "WARRIOR"
				row:SetRollResults(results)
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Bob won (Greed, 55)")
			end)

			it("uses the configured win color", function()
				setOptions({ winColor = { 1, 0, 0, 1 } })
				row:SetRollResults({
					winner = { playerClass = "UNKNOWN", isSelf = true, roll = 88, state = 0 },
					rollInfos = { { playerName = "Self", playerClass = "UNKNOWN", state = 0 } },
				})
				assert
					.stub(row.ItemCountText.SetText).was
					.called_with(row.ItemCountText, "|cffff0000You won! (Need, 88)|r")
			end)

			it("uses the configured muted color for passes and All passed", function()
				setOptions({ mutedColor = { 0, 0, 1, 1 } })
				row:SetRollResults({ rollInfos = { { playerName = "Carl", playerClass = "UNKNOWN", state = 5 } } })
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "|cff0000ffAll passed|r")
				row:OnRollCast(_G.PASS, _G.LOOT_ROLL_TYPE_PASS)
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "|cff0000ffPass|r")
			end)

			it("drops the waiting count from the secondary line when turned off", function()
				ns.DbAccessor.Styling = function()
					return { enabledSecondaryRowText = true, textAlignment = 1, rowTextSpacing = 0 }
				end
				stub(row.SecondaryText, "SetText")
				stub(row.SecondaryText, "Show")
				stub(row.SecondaryText, "Hide")
				row.SecondaryLineLayout.Show = function() end
				row.SecondaryLineLayout.Hide = function() end
				row.LayoutSecondaryLine = function() end
				setOptions({ showWaitingCount = false })
				row._rolled = true

				row:SetRollResults({
					currentLeader = { playerName = "Carl", playerClass = "UNKNOWN", roll = 33 },
					rollInfos = {
						{ playerName = "Carl", playerClass = "UNKNOWN", state = 4 },
						{ playerName = "Dee", playerClass = "UNKNOWN", state = 4 },
					},
				})

				assert.stub(row.SecondaryText.SetText).was.called_with(row.SecondaryText, "Carl leads (33)")
			end)
		end)

		describe("compact winners (issue #645)", function()
			local DICE = "|TInterface\\Buttons\\UI-GroupLoot-Dice-Up:14:14|t"
			local COIN = "|TInterface\\Buttons\\UI-GroupLoot-Coin-Up:14:14|t"
			local DE = "|TInterface\\Buttons\\UI-GroupLoot-DE-Up:14:14|t"
			local TMOG = "|A:lootroll-toast-icon-transmog-up:14:14|a"

			local function otherWinner(state, extra)
				local info = { playerName = "Bob", playerClass = "UNKNOWN", isSelf = false, roll = 55, state = state }
				for k, v in pairs(extra or {}) do
					info[k] = v
				end
				return { winner = info, rollInfos = { { playerName = "Bob", playerClass = "UNKNOWN", state = state } } }
			end

			it("is off by default: the long text stays", function()
				row:SetRollResults(otherWinner(3))
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Bob won (Greed, 55)")
			end)

			it("shows the name, the roll type icon and the number instead of 'won (Type, N)'", function()
				setOptions({ compactWinners = true })
				row:SetRollResults(otherWinner(3))
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Bob " .. COIN .. " 55")
			end)

			it("picks the icon for each roll type", function()
				setOptions({ compactWinners = true })
				local cases = { [0] = DICE, [1] = DICE, [2] = TMOG, [3] = COIN, [6] = DE }
				for state, icon in pairs(cases) do
					row.ItemCountText.SetText:clear()
					row._rollResultsSignature = nil
					row:SetRollResults(otherWinner(state))
					assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Bob " .. icon .. " 55")
				end
			end)

			it("sizes the icon from the row's font size", function()
				setOptions({ compactWinners = true })
				ns.DbAccessor.Styling = function()
					return { enabledSecondaryRowText = false, fontSize = 16 }
				end
				row:SetRollResults(otherWinner(1))
				assert
					.stub(row.ItemCountText.SetText).was
					.called_with(row.ItemCountText, "Bob |TInterface\\Buttons\\UI-GroupLoot-Dice-Up:20:20|t 55")
			end)

			it("drops the number when roll numbers are off", function()
				setOptions({ compactWinners = true, showRollNumbers = false })
				row:SetRollResults(otherWinner(3))
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Bob " .. COIN)
			end)

			it("shows your own win as You, the icon and the number in the win color", function()
				setOptions({ compactWinners = true })
				row:SetRollResults({
					winner = { playerClass = "UNKNOWN", isSelf = true, roll = 88, state = 0 },
					rollInfos = { { playerName = "Self", playerClass = "UNKNOWN", state = 0 } },
				})
				assert
					.stub(row.ItemCountText.SetText).was
					.called_with(row.ItemCountText, "|cff00ff00You " .. DICE .. " 88|r")
			end)

			it("still class-colors the winner's name", function()
				setOptions({ compactWinners = true })
				ns.WoWAPI.LootRolls.GetClassColor = function()
					return {
						WrapTextInColorCode = function(_, text)
							return "|cffMOCKED" .. text .. "|r"
						end,
					}
				end
				row:SetRollResults(otherWinner(3, { playerClass = "WARRIOR" }))
				assert
					.stub(row.ItemCountText.SetText).was
					.called_with(row.ItemCountText, "|cffMOCKEDBob|r " .. COIN .. " 55")
			end)

			it("leaves out the icon, and its gap, for a state that has none", function()
				setOptions({ compactWinners = true })
				row:SetRollResults(otherWinner(4))
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Bob 55")
			end)

			it("applies to LOOT_ITEM_ROLL_WON as well", function()
				setOptions({ compactWinners = true })
				row:OnRollWon(2, 55, false) -- 2 == Greed
				assert
					.stub(row.ItemCountText.SetText).was
					.called_with(row.ItemCountText, "|cff00ff00You " .. COIN .. " 55|r")
			end)

			it("keeps the upgraded note on LOOT_ITEM_ROLL_WON", function()
				setOptions({ compactWinners = true })
				row:OnRollWon(1, 77, true) -- 1 == Need
				assert
					.stub(row.ItemCountText.SetText).was
					.called_with(row.ItemCountText, "|cff00ff00You " .. DICE .. " 77 (Upgraded!)|r")
			end)
		end)

		describe("countdown bar", function()
			it("is set up by default", function()
				bootstrap()
				assert.stub(row._SetupRollTimerBar).was.called(1)
			end)

			it("is skipped when turned off", function()
				setOptions({ showTimerBar = false })
				bootstrap()
				assert.stub(row._SetupRollTimerBar).was_not.called()
			end)
		end)

		describe("roll details tooltip", function()
			it("hooks the secondary text by default", function()
				row:_SetupRollTooltip()
				assert.stub(row.SecondaryText.SetScript).was.called(2)
			end)

			it("hooks nothing when turned off", function()
				setOptions({ showRollTooltip = false })
				row:_SetupRollTooltip()
				assert.stub(row.SecondaryText.SetScript).was_not.called()
			end)
		end)
	end)

	describe("OnPlayerRolled (roll made outside RLF's buttons, e.g. Blizzard's frame or a gamepad)", function()
		local btn1, btn2

		before_each(function()
			btn1, btn2 = newDummyButton(), newDummyButton()
			row._rollButtons = { btn1, btn2 }
			row._rolled = false
		end)

		it("takes the action buttons down and shows the choice, like clicking a button", function()
			row:OnPlayerRolled(_G.LOOT_ROLL_TYPE_GREED)

			assert.is_true(row._rolled)
			assert.stub(btn1.Hide).was.called(1)
			assert.stub(btn2.Hide).was.called(1)
			assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, _G.GREED)
		end)

		it("shows greyed-out Pass text for a pass", function()
			row:OnPlayerRolled(_G.LOOT_ROLL_TYPE_PASS)

			assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "|cffb0b0b0Pass|r")
		end)

		it("labels a transmog roll", function()
			row:OnPlayerRolled(4)

			assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, _G.TRANSMOGRIFICATION)
		end)

		it("does nothing if the row already knows the player rolled", function()
			row._rolled = true

			row:OnPlayerRolled(_G.LOOT_ROLL_TYPE_NEED)

			assert.stub(btn1.Hide).was_not.called()
			assert.stub(row.ItemCountText.SetText).was_not.called()
		end)

		it("does nothing on a row that has already resolved to results", function()
			row._resolved = true

			row:OnPlayerRolled(_G.LOOT_ROLL_TYPE_NEED)

			assert.stub(btn1.Hide).was_not.called()
			assert.is_false(row._rolled)
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
			it("leaves the roll countdown alone and shows the current leader", function()
				row.rollID = 555
				row._rolled = true
				row:_SetupRollTimerBar(60000)
				assert.stub(row.StartTimerBar).was.called(1)

				row:SetRollResults({
					duration = 60,
					currentLeader = { playerName = "Carl", playerClass = "MAGE", roll = 33 },
					rollInfos = {
						{ playerName = "Carl", playerClass = "MAGE", state = 4 },
					},
				})

				assert.stub(row.StartTimerBar).was.called(1)
				assert.stub(row.TimerBar.SetMinMaxValues).was_not.called()
				assert.stub(row.TimerBar.SetValue).was_not.called()
				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Carl leads (33)")
				assert.is_nil(row._resolved)
			end)
		end)

		describe("when the poll re-sends identical results", function()
			local function waitingResults()
				return {
					currentLeader = { playerName = "Carl", playerClass = "MAGE", roll = 33 },
					rollInfos = { { playerName = "Carl", playerClass = "MAGE", state = 4 } },
				}
			end

			it("does not re-layout the row, which would drop the hover tooltip", function()
				row.rollID = 555
				row._rolled = true
				row:SetRollResults(waitingResults())
				spy.on(row, "LayoutPrimaryLine")
				spy.on(row, "LayoutSecondaryLine")
				row.ItemCountText.SetText:clear()

				row:SetRollResults(waitingResults())

				assert.spy(row.LayoutPrimaryLine).was_not.called()
				assert.spy(row.LayoutSecondaryLine).was_not.called()
				assert.stub(row.ItemCountText.SetText).was_not.called()
			end)

			it("still refreshes when the results change", function()
				row.rollID = 555
				row._rolled = true
				row:SetRollResults(waitingResults())
				local changed = waitingResults()
				changed.currentLeader.roll = 90
				row.ItemCountText.SetText:clear()

				row:SetRollResults(changed)

				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Carl leads (90)")
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

			it("colors the winner's name via G_RLF.WoWAPI.LootRolls, not the global RAID_CLASS_COLORS", function()
				-- A global RAID_CLASS_COLORS is deliberately present here with a
				-- DIFFERENT color than the adapter stub. If the row still reads
				-- the global directly (old behavior) rather than going through
				-- the adapter seam, this test's assertion on the mocked color
				-- fails and the "not called" assertion on the global catches it.
				_G.RAID_CLASS_COLORS = {
					WARRIOR = {
						r = 0,
						g = 0,
						b = 0,
						WrapTextInColorCode = function()
							return "|| SHOULD NOT BE USED ||"
						end,
					},
				}
				local mockColor = {
					r = 0.1,
					g = 0.2,
					b = 0.3,
				}
				mockColor.WrapTextInColorCode = function(_, text)
					return "|cffMOCKED" .. text .. "|r"
				end
				ns.WoWAPI.LootRolls.GetClassColor = function(className)
					if className == "WARRIOR" then
						return mockColor
					end
					return nil
				end

				row:SetRollResults({
					winner = { playerClass = "WARRIOR", playerName = "Bob", isSelf = false, roll = 55, state = 3 },
					rollInfos = {
						{ playerName = "Bob", playerClass = "WARRIOR", state = 3 },
					},
				})

				assert
					.stub(row.ItemCountText.SetText).was
					.called_with(row.ItemCountText, "|cffMOCKEDBob|r won (Greed, 55)")
			end)

			it("shows a Disenchant win via the addon-internal state 6 (Classic only)", function()
				row:SetRollResults({
					winner = { playerClass = "UNKNOWN", playerName = "Dave", isSelf = false, roll = 20, state = 6 },
					rollInfos = {
						{ playerName = "Dave", playerClass = "UNKNOWN", state = 6 },
					},
				})

				assert.stub(row.ItemCountText.SetText).was.called_with(row.ItemCountText, "Dave won (Disenchant, 20)")
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

		it("stays for the frame's configured results display time", function()
			ns.db.global.frames[row.frameType].features.lootRolls = { resultsDisplaySeconds = 15 }

			row:OnRollResolved()

			assert.are.equal(15, row.showForSeconds)
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

		it("groups Disenchant rollers under their own section (Classic only)", function()
			local lines = {}

			row:_BuildRollTooltipLines({
				rollInfos = { { playerName = "Dave", playerClass = "WARRIOR", state = 6, roll = 55 } },
			}, lines)

			assert.are.equal("Disenchant (1)", lines[1][1])
			assert.is_not_nil(lines[2][1]:find("Dave", 1, true))
		end)
	end)

	describe("CleanupLootRoll", function()
		it("untracks the roll and resets all row state, via the real payload->element->row pipeline", function()
			-- Goes through the actual production chain instead of manually
			-- injecting row.moduleRef: LootRolls.lua's BuildPayload sets
			-- payload.moduleRef, G_RLF.LootElementBase:fromPayload must carry
			-- it onto the element, and PostBootstrapFromElement must carry it
			-- from the element onto the row. A regression in any of those
			-- three hops must fail this test.
			assert(loadfile("RPGLootFeed/Features/_Internals/LootElementBase.lua"))("TestAddon", ns)
			assert.is_not_nil(ns.LootElementBase)

			local moduleRef = {}
			stub(moduleRef, "_UntrackRoll")

			-- Mirrors LootRolls.lua's START_LOOT_ROLL payload shape (no
			-- canNeed/canGreed overrides -- those are sample-row-only, so a
			-- real roll row falls through to GetLootRollItemInfo, exactly
			-- like the production, non-sample path does).
			local payload = {
				key = "lootRoll:999",
				type = ns.FeatureModule.LootRolls,
				rollID = 999,
				rollDuration = 60000,
				moduleRef = moduleRef,
			}
			_G.GetLootRollItemInfo = function()
				return nil, nil, nil, nil, nil, true, true, false, nil, nil, nil, nil, false
			end

			local element = ns.LootElementBase:fromPayload(payload)

			stub(row, "_CreateRollButton", function()
				return newDummyButton()
			end)

			row:PostBootstrapFromElement(element)

			-- Prove the indirection actually happened before relying on it.
			assert.are.equal(moduleRef, row.moduleRef)
			assert.are.equal(999, row.rollID)

			local btn = newDummyButton()
			row._rolled = true
			row._resolved = true
			row._rollTimerBarActive = true
			row._rollButtons = { btn }
			row._rollDropInfo = { rollInfos = {} }
			row._rollTimerFrame = { SetScript = function() end }
			stub(row._rollTimerFrame, "SetScript")

			row:CleanupLootRoll()

			assert.stub(moduleRef._UntrackRoll).was.called_with(moduleRef, 999)
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
