local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local rowFrameMocks = require("RPGLootFeed_spec._mocks.Internal.LootDisplayRowFrame")
local assert = require("luassert")
local busted = require("busted")
local match = require("luassert.match")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local stub = busted.stub

local MIXIN_FILE = "RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayRow/LootDisplayRow.lua"

describe("LootDisplayRowMixin", function()
	local ns, row
	before_each(function()
		-- Define the global G_RLF
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)

		-- Load the module before each test
		assert(loadfile(MIXIN_FILE))("TestAddon", ns)
	end)

	it("loads the file and exposes the global mixin table", function()
		assert.is_not_nil(_G.LootDisplayRowMixin)
	end)

	-- Helper: build a mock row with all the mixin methods mixed in and the
	-- minimal stubs that UpdateQuantity / BootstrapFromElement call.
	-- Returns: row, captures
	-- captures.showText = { r, g, b, a } from the last ShowText call
	-- captures.showAmountText = { text, r, g, b, a } from the last ShowAmountText call
	local function buildRow()
		local r = rowFrameMocks.new()
		local captures = { showText = {}, showAmountText = {} }
		-- Mix LootDisplayRowMixin methods into the mock row
		for k, v in pairs(LootDisplayRowMixin) do
			r[k] = v
		end
		-- Mix RowTextMixin methods (ShowText, ShowAmountText, UpdateSecondaryText, etc.)
		assert(loadfile("RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayRow/RowTextMixin.lua"))("TestAddon", ns)
		for k, v in pairs(RLF_RowTextMixin) do
			r[k] = v
		end
		-- Replace ShowText/ShowAmountText with capturing fakes
		r.ShowText = function(self, rawText, cr, cg, cb, ca)
			captures.showText = { text = rawText, r = cr, g = cg, b = cb, a = ca }
		end
		r.ShowAmountText = function(self, amountText, cr, cg, cb, ca)
			captures.showAmountText = { text = amountText, r = cr, g = cg, b = cb, a = ca }
		end
		-- Stub mixin methods that touch UI internals we don't need to exercise
		stub(r, "UpdateSecondaryText")
		stub(r, "UpdateItemCount")
		stub(r, "UpdateStyles")
		stub(r, "StyleText")
		stub(r, "UpdateIcon")
		stub(r, "SetupTooltip")
		stub(r, "LogRow")
		stub(r, "StyleExitAnimation")
		stub(r, "Enter")
		-- PrimaryText:GetAlpha returns 1 so UpdateQuantity doesn't defer
		r.PrimaryText.GetAlpha = function()
			return 1
		end
		-- EnterAnimation / ElementFadeInAnimation not playing
		r.EnterAnimation = {
			IsPlaying = function()
				return false
			end,
		}
		r.ElementFadeInAnimation = {
			IsPlaying = function()
				return false
			end,
		}
		-- ExitAnimation stubs
		r.ExitAnimation = {
			IsPlaying = function()
				return false
			end,
			Stop = function() end,
			Play = function() end,
		}
		-- HighlightAnimation stubs
		r.HighlightAnimation = {
			Stop = function() end,
			Play = function() end,
		}
		-- Stub RunNextFrame to execute immediately
		_G.RunNextFrame = function(fn)
			fn()
		end
		-- Default db settings for animations
		ns.db.global.animations = ns.db.global.animations or {}
		ns.db.global.animations.update = ns.db.global.animations.update or {}
		ns.db.global.animations.update.disableHighlight = true
		-- Make DbAccessor:Animations() return the mock animations table
		ns.DbAccessor.Animations = function(_, frameType)
			return ns.db.global.animations
		end
		return r, captures
	end

	-- ── UpdateQuantity ─────────────────────────────────────────────────────

	describe("UpdateQuantity", function()
		describe("amount accumulation", function()
			it("passes the OLD amount to amountTextFn, not the already-updated value", function()
				local captures
				row, captures = buildRow()
				row.amount = 1

				local receivedAmount
				local element = {
					textFn = function()
						return "text"
					end,
					quantity = 2,
					itemCount = nil,
					r = 1,
					g = 1,
					b = 1,
					a = 1,
					amountTextFn = function(existingQuantity)
						receivedAmount = existingQuantity
						return "x" .. ((existingQuantity or 0) + 2)
					end,
				}

				row:UpdateQuantity(element)

				-- amountTextFn should have received the old amount (1), not 3
				assert.equal(1, receivedAmount)
			end)

			it("updates self.amount to old + element.quantity", function()
				local captures
				row, captures = buildRow()
				row.amount = 5

				local element = {
					textFn = function()
						return "text"
					end,
					quantity = 3,
					itemCount = nil,
					r = 1,
					g = 1,
					b = 1,
					a = 1,
				}

				row:UpdateQuantity(element)

				assert.equal(8, row.amount)
			end)

			it("displays correct cumulative amount text after multiple updates", function()
				local captures
				row, captures = buildRow()
				row.amount = 1

				-- Simulate the real amountTextFn pattern from ItemLoot/Currency/PartyLoot
				local function makeElement(qty)
					return {
						textFn = function()
							return "text"
						end,
						quantity = qty,
						itemCount = nil,
						r = 1,
						g = 1,
						b = 1,
						a = 1,
						amountTextFn = function(existingQuantity)
							local effective = (existingQuantity or 0) + qty
							return "x" .. effective
						end,
					}
				end

				-- First update: 1 existing + 2 new = 3
				row:UpdateQuantity(makeElement(2))
				assert.equal("x3", captures.showAmountText.text)
				assert.equal(3, row.amount)

				-- Second update: 3 existing + 4 new = 7
				row:UpdateQuantity(makeElement(4))
				assert.equal("x7", captures.showAmountText.text)
				assert.equal(7, row.amount)
			end)

			it("queues deferred updates and applies all deltas in order", function()
				local captures
				row, captures = buildRow()
				row.amount = 1

				local primaryAlpha = 0
				row.PrimaryText.GetAlpha = function()
					return primaryAlpha
				end

				local function makeElement(qty)
					return {
						textFn = function()
							return "text"
						end,
						quantity = qty,
						itemCount = nil,
						r = 1,
						g = 1,
						b = 1,
						a = 1,
						amountTextFn = function(existingQuantity)
							local effective = (existingQuantity or 0) + qty
							return "x" .. effective
						end,
					}
				end

				row:UpdateQuantity(makeElement(2))
				row:UpdateQuantity(makeElement(5))

				assert.is_true(row.updatePending)
				assert.is_not_nil(row.pendingElement)

				primaryAlpha = 1
				row:UpdateQuantity(row.pendingElement)

				assert.is_false(row.updatePending)
				assert.is_nil(row.pendingElement)
				assert.equal("x8", captures.showAmountText.text)
				assert.equal(8, row.amount)
			end)
		end)

		describe("negative amount coloring", function()
			it("overrides color to red when net amount is negative", function()
				local captures
				row, captures = buildRow()
				row.amount = 5

				local element = {
					textFn = function()
						return "-100 Faction"
					end,
					quantity = -10,
					itemCount = nil,
					r = 0.5,
					g = 0.8,
					b = 0.3,
					a = 1,
				}

				row:UpdateQuantity(element)

				assert.equal(1, captures.showText.r)
				assert.equal(0, captures.showText.g)
				assert.equal(0, captures.showText.b)
				assert.equal(0.8, captures.showText.a)
			end)

			it("preserves element color when net amount is positive", function()
				local captures
				row, captures = buildRow()
				row.amount = 10

				local element = {
					textFn = function()
						return "+5 Faction"
					end,
					quantity = 5,
					itemCount = nil,
					r = 0.2,
					g = 0.6,
					b = 0.9,
					a = 1,
				}

				row:UpdateQuantity(element)

				assert.equal(0.2, captures.showText.r)
				assert.equal(0.6, captures.showText.g)
				assert.equal(0.9, captures.showText.b)
				assert.equal(1, captures.showText.a)
			end)

			it("uses colorFn result when net amount is positive and colorFn is provided", function()
				local captures
				row, captures = buildRow()
				row.amount = -3

				local element = {
					textFn = function()
						return "+10 Money"
					end,
					quantity = 10,
					itemCount = nil,
					r = 1,
					g = 0,
					b = 0,
					a = 1,
					colorFn = function(netQty)
						if netQty < 0 then
							return 1, 0, 0, 1
						else
							return 1, 1, 1, 1
						end
					end,
				}

				row:UpdateQuantity(element)

				-- Net is 7 (positive), colorFn returns white, negative override doesn't trigger
				assert.equal(1, captures.showText.r)
				assert.equal(1, captures.showText.g)
				assert.equal(1, captures.showText.b)
				assert.equal(1, captures.showText.a)
			end)

			it("overrides colorFn color when net amount is still negative", function()
				local captures
				row, captures = buildRow()
				row.amount = -20

				local element = {
					textFn = function()
						return "-15 Money"
					end,
					quantity = -15,
					itemCount = nil,
					r = 0.5,
					g = 0.5,
					b = 0.5,
					a = 1,
					colorFn = function(netQty)
						-- colorFn returns some non-red color
						return 0.5, 0.5, 0.5, 1
					end,
				}

				row:UpdateQuantity(element)

				-- Net is -35 (negative), red override takes priority over colorFn
				assert.equal(1, captures.showText.r)
				assert.equal(0, captures.showText.g)
				assert.equal(0, captures.showText.b)
				assert.equal(0.8, captures.showText.a)
			end)
		end)
	end)

	-- ── BootstrapFromElement ───────────────────────────────────────────────

	describe("BootstrapFromElement", function()
		describe("negative amount coloring", function()
			it("overrides color to red when element quantity is negative", function()
				local captures
				row, captures = buildRow()

				local element = {
					key = "REP_123",
					textFn = function()
						return "-100 Faction"
					end,
					quantity = -100,
					quality = 1,
					r = 0.5,
					g = 0.8,
					b = 0.3,
					a = 1,
					highlight = false,
				}

				row:BootstrapFromElement(element)

				assert.equal(1, captures.showText.r)
				assert.equal(0, captures.showText.g)
				assert.equal(0, captures.showText.b)
				assert.equal(0.8, captures.showText.a)
			end)

			it("preserves element color when element quantity is positive", function()
				local captures
				row, captures = buildRow()

				local element = {
					key = "REP_456",
					textFn = function()
						return "+50 Faction"
					end,
					quantity = 50,
					quality = 1,
					r = 0.2,
					g = 0.6,
					b = 0.9,
					a = 1,
					highlight = false,
				}

				row:BootstrapFromElement(element)

				assert.equal(0.2, captures.showText.r)
				assert.equal(0.6, captures.showText.g)
				assert.equal(0.9, captures.showText.b)
				assert.equal(1, captures.showText.a)
			end)

			it("overrides color to red when element quantity is negative even with nil colors", function()
				local captures
				row, captures = buildRow()

				local element = {
					key = "MONEY",
					textFn = function()
						return "-5g"
					end,
					quantity = -5,
					quality = 1,
					highlight = false,
				}

				row:BootstrapFromElement(element)

				assert.equal(1, captures.showText.r)
				assert.equal(0, captures.showText.g)
				assert.equal(0, captures.showText.b)
				assert.equal(0.8, captures.showText.a)
			end)
		end)

		describe("per-element fade override", function()
			it("sets hasElementFadeOverride when element provides showForSeconds", function()
				local captures
				row, captures = buildRow()
				row.showForSeconds = 5

				local element = {
					key = "ITEM_123",
					textFn = function()
						return "Legendary Sword"
					end,
					quantity = 1,
					quality = 5,
					r = 1,
					g = 0.5,
					b = 0,
					a = 1,
					highlight = false,
					showForSeconds = 10,
				}

				row:BootstrapFromElement(element)

				assert.is_true(row.hasElementFadeOverride)
				assert.equal(10, row.showForSeconds)
			end)

			it("does not set hasElementFadeOverride for sample rows", function()
				local captures
				row, captures = buildRow()
				row.showForSeconds = 5

				local element = {
					key = "SAMPLE",
					textFn = function()
						return "Sample"
					end,
					quantity = 1,
					quality = 1,
					highlight = false,
					isSampleRow = true,
					showForSeconds = 99,
				}

				row:BootstrapFromElement(element)

				assert.is_false(row.hasElementFadeOverride)
			end)

			it("does not set hasElementFadeOverride when element has no showForSeconds", function()
				local captures
				row, captures = buildRow()
				row.showForSeconds = 5

				local element = {
					key = "ITEM_456",
					textFn = function()
						return "Common Item"
					end,
					quantity = 1,
					quality = 1,
					r = 1,
					g = 1,
					b = 1,
					a = 1,
					highlight = false,
				}

				row:BootstrapFromElement(element)

				assert.is_falsy(row.hasElementFadeOverride)
				assert.equal(5, row.showForSeconds)
			end)

			it("does not override showForSeconds when filterItemQuality has no frame config", function()
				local captures
				row, captures = buildRow()
				row.showForSeconds = 5
				-- frameType [1] has no itemQualitySettings in its itemLoot config
				ns.db.global.frames[1].features.itemLoot = { enabled = true }

				local element = {
					key = "ITEM_789",
					textFn = function()
						return "Rare Item"
					end,
					quantity = 1,
					quality = 3,
					r = 0,
					g = 0.44,
					b = 0.87,
					a = 1,
					highlight = false,
					filterItemQuality = 3,
				}
				row.frameType = ns.Frames.MAIN

				row:BootstrapFromElement(element)

				assert.is_falsy(row.hasElementFadeOverride)
				assert.equal(5, row.showForSeconds)
			end)

			it("applies per-frame quality duration override when duration > 0", function()
				local captures
				row, captures = buildRow()
				row.showForSeconds = 5
				ns.db.global.frames[1].features.itemLoot = {
					enabled = true,
					itemQualitySettings = {
						[4] = { enabled = true, duration = 12 },
					},
				}

				local element = {
					key = "ITEM_EPIC",
					textFn = function()
						return "Epic Item"
					end,
					quantity = 1,
					quality = 4,
					r = 0.64,
					g = 0.21,
					b = 0.93,
					a = 1,
					highlight = false,
					filterItemQuality = 4,
				}
				row.frameType = ns.Frames.MAIN

				row:BootstrapFromElement(element)

				assert.is_true(row.hasElementFadeOverride)
				assert.equal(12, row.showForSeconds)
			end)

			it("does not override showForSeconds when frame quality duration is 0", function()
				local captures
				row, captures = buildRow()
				row.showForSeconds = 5
				ns.db.global.frames[1].features.itemLoot = {
					enabled = true,
					itemQualitySettings = {
						[2] = { enabled = true, duration = 0 },
					},
				}

				local element = {
					key = "ITEM_UNCOMMON",
					textFn = function()
						return "Uncommon Item"
					end,
					quantity = 1,
					quality = 2,
					r = 0.12,
					g = 1,
					b = 0,
					a = 1,
					highlight = false,
					filterItemQuality = 2,
				}
				row.frameType = ns.Frames.MAIN

				row:BootstrapFromElement(element)

				assert.is_falsy(row.hasElementFadeOverride)
				assert.equal(5, row.showForSeconds)
			end)

			it("element.showForSeconds takes priority over frame quality duration", function()
				local captures
				row, captures = buildRow()
				row.showForSeconds = 5
				ns.db.global.frames[1].features.itemLoot = {
					enabled = true,
					itemQualitySettings = {
						[5] = { enabled = true, duration = 30 },
					},
				}

				local element = {
					key = "ITEM_LEGENDARY",
					textFn = function()
						return "Legendary Item"
					end,
					quantity = 1,
					quality = 5,
					r = 1,
					g = 0.5,
					b = 0,
					a = 1,
					highlight = false,
					filterItemQuality = 5,
					showForSeconds = 99,
				}
				row.frameType = ns.Frames.MAIN

				row:BootstrapFromElement(element)

				assert.is_true(row.hasElementFadeOverride)
				assert.equal(99, row.showForSeconds)
			end)

			it("preserves per-element showForSeconds when UpdateFadeoutDelay is called", function()
				row = buildRow()
				-- Load the animation mixin so UpdateFadeoutDelay is available
				assert(loadfile("RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayRow/RowAnimationMixin.lua"))(
					"TestAddon",
					ns
				)
				for k, v in pairs(RLF_RowAnimationMixin) do
					row[k] = v
				end

				row.showForSeconds = 10
				row.hasElementFadeOverride = true
				row.isSampleRow = false

				-- Stub StyleExitAnimation to avoid UI calls
				stub(row, "StyleExitAnimation")

				row:UpdateFadeoutDelay()

				assert.equal(10, row.showForSeconds)
				assert.stub(row.StyleExitAnimation).was.called(1)
			end)

			it("overwrites showForSeconds with frame default when no override is set", function()
				row = buildRow()
				assert(loadfile("RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayRow/RowAnimationMixin.lua"))(
					"TestAddon",
					ns
				)
				for k, v in pairs(RLF_RowAnimationMixin) do
					row[k] = v
				end

				row.showForSeconds = 10
				row.hasElementFadeOverride = false
				row.isSampleRow = false
				row.frameType = ns.Frames.MAIN

				-- Configure the frame default
				ns.db.global.animations.exit = ns.db.global.animations.exit or {}
				ns.db.global.animations.exit.fadeOutDelay = 3

				stub(row, "StyleExitAnimation")

				row:UpdateFadeoutDelay()

				assert.equal(3, row.showForSeconds)
			end)
		end)
	end)

	-- ── SetClickThrough ────────────────────────────────────────────────────

	describe("SetClickThrough", function()
		local function buildClickThroughRow()
			local r = buildRow()
			-- Add EnableMouse to row and its children
			stub(r, "EnableMouse")
			r.ClickableButton.EnableMouse = function() end
			stub(r.ClickableButton, "EnableMouse")
			r.Icon.EnableMouse = function() end
			stub(r.Icon, "EnableMouse")
			-- Make ExitAnimation.Play a spy so we can assert on it
			r.ExitAnimation.Play = spy.new(function() end)
			stub(r, "StartTimerBar")
			return r
		end

		it("disables mouse on row, ClickableButton, and Icon when enabled=true", function()
			row = buildClickThroughRow()
			row:SetClickThrough(true)

			assert.is_true(row.isClickThrough)
			assert.stub(row.EnableMouse).was.called_with(row, false)
			assert.stub(row.ClickableButton.EnableMouse).was.called_with(row.ClickableButton, false)
			assert.stub(row.Icon.EnableMouse).was.called_with(row.Icon, false)
		end)

		it("re-enables mouse on row, ClickableButton, and Icon when enabled=false", function()
			row = buildClickThroughRow()
			row.isClickThrough = true
			row:SetClickThrough(false)

			assert.is_false(row.isClickThrough)
			assert.stub(row.EnableMouse).was.called_with(row, true)
			assert.stub(row.ClickableButton.EnableMouse).was.called_with(row.ClickableButton, true)
			assert.stub(row.Icon.EnableMouse).was.called_with(row.Icon, true)
		end)

		it("cleans up hover state when enabled=true and hasMouseOver is true", function()
			_G.GameTooltip = { Hide = spy.new(function() end) }
			row = buildClickThroughRow()
			row.hasMouseOver = true
			row.isHistoryMode = false
			row.HighlightFadeIn = {
				IsPlaying = function()
					return true
				end,
				Stop = function() end,
			}
			stub(row.HighlightFadeIn, "Stop")
			row.HighlightFadeOut = { Play = function() end }
			stub(row.HighlightFadeOut, "Play")

			row:SetClickThrough(true)

			assert.is_false(row.hasMouseOver)
			assert.stub(row.HighlightFadeIn.Stop).was.called(1)
			assert.stub(row.HighlightFadeOut.Play).was.called(1)
			assert.spy(row.ExitAnimation.Play).was.called(1)
			assert.spy(_G.GameTooltip.Hide).was.called(1)
		end)

		it("does not play ExitAnimation in history mode when cleaning up hover", function()
			_G.GameTooltip = { Hide = spy.new(function() end) }
			row = buildClickThroughRow()
			row.hasMouseOver = true
			row.isHistoryMode = true
			row.HighlightFadeIn = {
				IsPlaying = function()
					return false
				end,
				Stop = function() end,
			}
			row.HighlightFadeOut = { Play = function() end }
			stub(row.HighlightFadeOut, "Play")

			row:SetClickThrough(true)

			assert.spy(row.ExitAnimation.Play).was_not.called()
		end)

		it("skips hover cleanup when hasMouseOver is false", function()
			_G.GameTooltip = { Hide = spy.new(function() end) }
			row = buildClickThroughRow()
			row.hasMouseOver = false

			row:SetClickThrough(true)

			assert.spy(row.ExitAnimation.Play).was_not.called()
			assert.spy(_G.GameTooltip.Hide).was_not.called()
		end)

		it("calls ReleasePin on frame when isPinned is true on SetClickThrough(true)", function()
			row = buildClickThroughRow()
			row.isPinned = true
			local mockFrame = { ReleasePin = spy.new(function() end) }
			stub(row, "GetParent").returns(mockFrame)
			row.hasMouseOver = false

			row:SetClickThrough(true)

			assert.spy(mockFrame.ReleasePin).was.called_with(mockFrame, row)
		end)

		it("does not call ReleasePin when isPinned is false on SetClickThrough(true)", function()
			row = buildClickThroughRow()
			row.isPinned = false
			local mockFrame = { ReleasePin = spy.new(function() end) }
			stub(row, "GetParent").returns(mockFrame)
			row.hasMouseOver = false

			row:SetClickThrough(true)

			assert.spy(mockFrame.ReleasePin).was_not.called()
		end)
	end)

	-- ── PinPosition ────────────────────────────────────────────────────────

	describe("PinPosition", function()
		local function buildPinRow()
			local r = buildRow()
			stub(r, "GetBottom").returns(300)
			stub(r, "GetTop").returns(322)
			stub(r, "ClearAllPoints")
			stub(r, "SetPoint")
			r.isPinned = false
			r.pinnedFrameOffset = nil
			return r
		end

		it("pins the row with frame-relative anchor (growUp, BOTTOM)", function()
			row = buildPinRow()
			ns.db.global.interactions = { pinOnHover = true }
			local mockFrame = {
				vertDir = "BOTTOM",
				hasPinnedRow = false,
				GetBottom = function()
					return 100
				end,
			}

			row:PinPosition(mockFrame)

			assert.is_true(row.isPinned)
			assert.equal(200, row.pinnedFrameOffset) -- 300 - 100
			assert.is_true(mockFrame.hasPinnedRow)
			assert.stub(row.ClearAllPoints).was.called(1)
			assert.stub(row.SetPoint).was.called_with(match.ref(row), "BOTTOM", match.ref(mockFrame), "BOTTOM", 0, 200)
		end)

		it("pins the row with frame-relative anchor (growDown, TOP)", function()
			row = buildPinRow()
			ns.db.global.interactions = { pinOnHover = true }
			local mockFrame = {
				vertDir = "TOP",
				hasPinnedRow = false,
				GetTop = function()
					return 500
				end,
			}

			row:PinPosition(mockFrame)

			assert.is_true(row.isPinned)
			assert.equal(-178, row.pinnedFrameOffset) -- 322 - 500
			assert.is_true(mockFrame.hasPinnedRow)
		end)

		it("is a no-op when already pinned", function()
			row = buildPinRow()
			ns.db.global.interactions = { pinOnHover = true }
			row.isPinned = true
			local mockFrame = { vertDir = "BOTTOM", hasPinnedRow = false }

			row:PinPosition(mockFrame)

			assert.stub(row.ClearAllPoints).was_not.called()
			assert.is_false(mockFrame.hasPinnedRow) -- unchanged
		end)

		it("is a no-op when pinOnHover setting is disabled", function()
			row = buildPinRow()
			ns.db.global.interactions = { pinOnHover = false }
			local mockFrame = { vertDir = "BOTTOM", hasPinnedRow = false }

			row:PinPosition(mockFrame)

			assert.is_false(row.isPinned)
			assert.stub(row.ClearAllPoints).was_not.called()
		end)
	end)

	-- ── Reset clears pin state ─────────────────────────────────────────────

	describe("Reset pin state cleanup", function()
		it("clears isPinned and pinnedFrameOffset in Reset()", function()
			-- Build row from the mixin and provide the minimum stubs Reset() needs.
			row = {}
			for k, v in pairs(LootDisplayRowMixin) do
				row[k] = v
			end
			row.isPinned = true
			row.pinnedFrameOffset = 42

			local function noopEl()
				return {
					SetAlpha = function() end,
					SetText = function() end,
					SetTextColor = function() end,
					Hide = function() end,
					SetTexture = function() end,
					SetVertexColor = function() end,
				}
			end

			stub(row, "Hide")
			stub(row, "SetAlpha")
			stub(row, "ClearAllPoints")
			stub(row, "CreateTopLeftText")
			stub(row, "StopAllAnimations")
			stub(row, "StopScriptedEffects")
			stub(row, "HideCoinDisplay")
			stub(row, "HideSecondaryCoinDisplay")

			row.TopBorder = noopEl()
			row.RightBorder = noopEl()
			row.BottomBorder = noopEl()
			row.LeftBorder = noopEl()
			row.UnitPortrait = noopEl()
			row.HighlightBGOverlay = noopEl()
			row.PrimaryText = noopEl()
			row.AmountText = noopEl()
			row.ItemCountText = noopEl()
			row.SecondaryText = noopEl()
			row.SecondaryLineLayout = { Hide = function() end }
			row.Icon = {
				Reset = function() end,
				SetScript = function() end,
				topLeftText = { Hide = function() end },
				IconBorder = noopEl(),
				NormalTexture = noopEl(),
				HighlightTexture = noopEl(),
				PushedTexture = noopEl(),
			}
			row.ClickableButton = {
				Hide = function() end,
				GetRegions = function() end,
				SetScript = function() end,
			}

			row:Reset()

			assert.is_false(row.isPinned)
			assert.is_nil(row.pinnedFrameOffset)
		end)
	end)
end)
