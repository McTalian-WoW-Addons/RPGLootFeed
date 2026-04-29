local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local rowFrameMocks = require("RPGLootFeed_spec._mocks.Internal.LootDisplayRowFrame")
local assert = require("luassert")
local match = require("luassert.match")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local stub = busted.stub
local spy = busted.spy

local MIXIN_FILE = "RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayRow/RowAnimationMixin.lua"

describe("RLF_RowAnimationMixin shift animation", function()
	local ns, row, frame

	--- Returns a minimal mock Translation animation.
	local function mockTranslation()
		local t = {}
		stub(t, "SetDuration")
		stub(t, "SetSmoothing")
		stub(t, "SetOffset")
		return t
	end

	--- Returns a mock AnimationGroup that captures OnFinished and supports
	--- CreateAnimation("Translation") to produce a mock Translation.
	local function mockAnimationGroup()
		local ag = {}
		stub(ag, "Stop")
		stub(ag, "Play")
		stub(ag, "IsPlaying")
		stub(ag, "SetToFinalAlpha")
		ag._onFinished = nil
		ag.SetScript = function(self, event, fn)
			if event == "OnFinished" then
				self._onFinished = fn
			end
		end
		ag.CreateAnimation = function(self, animType)
			if animType == "Translation" then
				ag.translation = mockTranslation()
				return ag.translation
			end
		end
		return ag
	end

	--- Mixes all RLF_RowAnimationMixin methods onto `row`, sets up a controlled
	--- `CreateAnimationGroup`, and stubs the layout methods AnimateShift needs.
	local function setupRowWithMockAnimGroup(ag)
		row.CreateAnimationGroup = function()
			return ag
		end
		stub(row, "GetParent").returns(frame)
		stub(row, "GetBottom").returns(200)
		stub(row, "GetTop").returns(200)
		stub(row, "ClearAllPoints")
		stub(row, "SetPoint")
		stub(row, "SetFrameLevel")
		stub(row, "GetFrameLevel").returns(498)
		stub(row, "UpdatePosition")
	end

	before_each(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		assert(loadfile(MIXIN_FILE))("TestAddon", ns)

		row = rowFrameMocks.new()
		for k, v in pairs(RLF_RowAnimationMixin) do
			row[k] = v
		end
		row.frameType = ns.Frames.MAIN

		frame = {
			vertDir = "BOTTOM",
			frameType = ns.Frames.MAIN,
			shiftingRowCount = 0,
		}
		stub(frame, "GetBottom").returns(100)
		frame.GetTop = function()
			return 400
		end

		stub(ns.DbAccessor, "Animations").returns({
			reposition = { duration = 0.2 },
		})
	end)

	-- ── StyleShiftAnimation ───────────────────────────────────────────────

	describe("StyleShiftAnimation", function()
		it("creates ShiftAnimation group and a Translation child", function()
			local ag = mockAnimationGroup()
			setupRowWithMockAnimGroup(ag)

			row:StyleShiftAnimation()

			assert.equal(ag, row.ShiftAnimation)
			assert.is_not_nil(row.ShiftAnimation.translation)
			assert.stub(ag.SetToFinalAlpha).was.called_with(match.ref(ag), false)
		end)

		it("does not recreate when ShiftAnimation already exists", function()
			local ag = mockAnimationGroup()
			setupRowWithMockAnimGroup(ag)
			row:StyleShiftAnimation()
			local firstAg = row.ShiftAnimation

			row:StyleShiftAnimation()

			assert.equal(firstAg, row.ShiftAnimation)
		end)

		it("registers an OnFinished script", function()
			local ag = mockAnimationGroup()
			setupRowWithMockAnimGroup(ag)

			row:StyleShiftAnimation()

			assert.is_function(ag._onFinished)
		end)
	end)

	-- ── AnimateShift ──────────────────────────────────────────────────────

	describe("AnimateShift", function()
		it("reads duration from DB and sets it on the translation", function()
			local ag = mockAnimationGroup()
			stub(ns.DbAccessor, "Animations").returns({ reposition = { duration = 0.3 } })
			setupRowWithMockAnimGroup(ag)

			row:AnimateShift(30, 230)

			assert.stub(ag.translation.SetDuration).was.called_with(ag.translation, 0.3)
		end)

		it("sets correct frame-relative anchor for a growUp (BOTTOM) feed", function()
			-- frame:GetBottom() = 100
			-- yDelta = 30, oldEdgeY = 230 → offset from frame = 230 - 100 = 130
			local ag = mockAnimationGroup()
			frame.vertDir = "BOTTOM"
			setupRowWithMockAnimGroup(ag)
			stub(frame, "GetBottom").returns(100)

			row:AnimateShift(30, 230)

			assert.stub(row.ClearAllPoints).was.called(1)
			assert.stub(row.SetPoint).was.called_with(match.ref(row), "BOTTOM", match.ref(frame), "BOTTOM", 0, 130)
		end)

		it("sets correct frame-relative anchor for a growDown (TOP) feed", function()
			-- frame:GetTop() = 500
			-- yDelta = -20, oldEdgeY = 280 → offset from frame = 280 - 500 = -220
			local ag = mockAnimationGroup()
			frame.vertDir = "TOP"
			setupRowWithMockAnimGroup(ag)
			frame.GetTop = function()
				return 500
			end

			row:AnimateShift(-20, 280)

			assert.stub(row.ClearAllPoints).was.called(1)
			assert.stub(row.SetPoint).was.called_with(match.ref(row), "TOP", match.ref(frame), "TOP", 0, -220)
		end)

		it("sets translation offset to -yDelta", function()
			local ag = mockAnimationGroup()
			frame.vertDir = "BOTTOM"
			setupRowWithMockAnimGroup(ag)

			row:AnimateShift(30, 230)

			assert.stub(ag.translation.SetOffset).was.called_with(ag.translation, 0, -30)
		end)

		it("stores pre-computed final frame-relative offset", function()
			local ag = mockAnimationGroup()
			frame.vertDir = "BOTTOM"
			setupRowWithMockAnimGroup(ag)
			stub(frame, "GetBottom").returns(100)

			-- yDelta = 30, oldEdgeY = 230 → newEdgeY = 200 → finalOffset = 200 - 100 = 100
			row:AnimateShift(30, 230)

			assert.equal(100, row._shiftFinalFrameOffset)
		end)

		it("stores current frame level for OnFinished", function()
			local ag = mockAnimationGroup()
			frame.vertDir = "BOTTOM"
			setupRowWithMockAnimGroup(ag)
			stub(row, "GetFrameLevel").returns(497)

			row:AnimateShift(30, 230)

			assert.equal(497, row._shiftFinalFrameLevel)
		end)

		it("increments frame.shiftingRowCount", function()
			local ag = mockAnimationGroup()
			frame.shiftingRowCount = 0
			setupRowWithMockAnimGroup(ag)

			row:AnimateShift(30, 230)

			assert.equal(1, frame.shiftingRowCount)
		end)

		it("plays the ShiftAnimation", function()
			local ag = mockAnimationGroup()
			setupRowWithMockAnimGroup(ag)

			row:AnimateShift(30, 230)

			assert.stub(ag.Play).was.called(1)
		end)

		it("does not re-anchor the row when GetParent is nil", function()
			local ag = mockAnimationGroup()
			setupRowWithMockAnimGroup(ag)
			stub(row, "GetParent").returns(nil)

			-- Should not error
			row:AnimateShift(30, 230)

			assert.stub(row.ClearAllPoints).was_not.called()
			assert.stub(row.SetPoint).was_not.called()
		end)
	end)

	-- ── ShiftAnimation OnFinished callback ────────────────────────────────

	describe("ShiftAnimation OnFinished", function()
		local ag

		before_each(function()
			ag = mockAnimationGroup()
			setupRowWithMockAnimGroup(ag)
			row:StyleShiftAnimation()
		end)

		it("anchors at pre-computed final position and frame level on finish", function()
			row._shiftFinalFrameOffset = 100
			row._shiftFinalFrameLevel = 497
			frame.shiftingRowCount = 2
			frame.RestoreRowChain = spy.new(function() end)
			ag._onFinished()
			assert.stub(row.ClearAllPoints).was.called(1)
			assert.stub(row.SetPoint).was.called_with(match.ref(row), "BOTTOM", match.ref(frame), "BOTTOM", 0, 100)
			assert.stub(row.SetFrameLevel).was.called_with(match.ref(row), 497)
		end)

		it("decrements frame.shiftingRowCount by 1", function()
			row._shiftFinalFrameOffset = 100
			frame.shiftingRowCount = 2
			ag._onFinished()
			assert.equal(1, frame.shiftingRowCount)
		end)

		it("clamps shiftingRowCount to 0 if already 0", function()
			row._shiftFinalFrameOffset = 100
			frame.shiftingRowCount = 0
			frame.RestoreRowChain = spy.new(function() end)
			ag._onFinished()
			assert.equal(0, frame.shiftingRowCount)
		end)

		it("does not send RLF_ROW_RETURNED when count > 0 after decrement", function()
			row._shiftFinalFrameOffset = 100
			frame.shiftingRowCount = 2
			ag._onFinished()
			assert.spy(nsMocks.SendMessage).was_not.called()
		end)

		it("calls RestoreRowChain and sends RLF_ROW_RETURNED when shiftingRowCount reaches 0", function()
			row._shiftFinalFrameOffset = 100
			frame.shiftingRowCount = 1
			frame.RestoreRowChain = spy.new(function() end)
			ag._onFinished()
			assert.spy(frame.RestoreRowChain).was.called(1)
			assert.spy(nsMocks.SendMessage).was.called_with(ns, "RLF_ROW_RETURNED", frame.frameType)
		end)

		it("does nothing safely when GetParent returns nil", function()
			stub(row, "GetParent").returns(nil)
			-- Should not error
			ag._onFinished()
		end)
	end)

	-- ── StopAllAnimations ─────────────────────────────────────────────────

	describe("StopAllAnimations", function()
		before_each(function()
			-- Nil out all the optional animation groups to avoid nil-index errors
			row.glowAnimationGroup = nil
			row.EnterAnimation = nil
			row.ExitAnimation = nil
			row.HighlightFadeIn = nil
			row.HighlightFadeOut = nil
			row.HighlightAnimation = nil
			row.ElementFadeInAnimation = nil
			stub(row, "StopScriptedEffects")
			stub(row, "ResetTimerBar")
		end)

		it("stops ShiftAnimation when present", function()
			local ag = mockAnimationGroup()
			row.ShiftAnimation = ag

			row:StopAllAnimations()

			assert.stub(ag.Stop).was.called(1)
		end)

		it("does not error when ShiftAnimation is absent", function()
			row.ShiftAnimation = nil

			-- Should not error
			row:StopAllAnimations()
		end)
	end)

	-- ── SetUpHoverEffect pin / unpin integration ──────────────────────

	describe("SetUpHoverEffect hover pin integration", function()
		local onEnter, onLeave

		--- Build an animation group that handles both Alpha and Translation
		--- CreateAnimation calls (needed by SetUpHoverEffect's fade groups).
		local function mockHighlightAnimGroup()
			local agInst = {}
			agInst._onFinished = nil
			agInst.SetScript = function(self, event, fn)
				if event == "OnFinished" then
					self._onFinished = fn
				end
			end
			agInst.CreateAnimation = function(self, animType)
				local anim = {}
				stub(anim, "SetFromAlpha")
				stub(anim, "SetToAlpha")
				stub(anim, "SetDuration")
				stub(anim, "SetSmoothing")
				stub(anim, "SetStartDelay")
				stub(anim, "SetOffset")
				return anim
			end
			stub(agInst, "Stop")
			stub(agInst, "Play")
			stub(agInst, "IsPlaying")
			stub(agInst, "SetToFinalAlpha")
			return agInst
		end

		--- Build a row with the hover highlight animation groups and the
		--- PinPosition / GetParent stubs needed by the hover scripts.
		local function buildHoverRow(mockParent)
			local r = rowFrameMocks.new()
			for k, v in pairs(RLF_RowAnimationMixin) do
				r[k] = v
			end
			r.frameType = ns.Frames.MAIN
			r.isPinned = false
			r.hasMouseOver = false
			r.sampleTooltipText = nil

			-- HighlightBGOverlay needs GetAlpha and CreateAnimationGroup
			r.HighlightBGOverlay.GetAlpha = function()
				return 0
			end
			local fadeInAg = mockHighlightAnimGroup()
			local fadeOutAg = mockHighlightAnimGroup()
			local agCallCount = 0
			r.HighlightBGOverlay.CreateAnimationGroup = function()
				agCallCount = agCallCount + 1
				return agCallCount == 1 and fadeInAg or fadeOutAg
			end

			-- Row's SetScript captures OnEnter / OnLeave
			r.SetScript = function(self, event, fn)
				if event == "OnEnter" then
					onEnter = fn
				elseif event == "OnLeave" then
					onLeave = fn
				end
			end
			stub(r, "GetParent").returns(mockParent)
			stub(r, "PinPosition")
			stub(r, "StartTimerBar")
			stub(r, "StopTimerBar")
			-- isMouseOverSelfOrChildren calls these; return false/empty so OnLeave proceeds.
			stub(r, "IsMouseOver").returns(false)
			r.GetChildren = function()
				-- Return no values so ipairs({frame:GetChildren()}) is empty.
			end

			stub(ns.DbAccessor, "Animations").returns({
				hover = { enabled = true, alpha = 0.3, baseDuration = 0.15 },
				reposition = { duration = 0.2 },
			})

			r:SetUpHoverEffect()
			return r
		end

		it("OnEnter calls PinPosition with the parent frame", function()
			local mockParent = {}
			row = buildHoverRow(mockParent)

			onEnter()

			assert.stub(row.PinPosition).was.called_with(row, mockParent)
		end)

		it("OnEnter does not call PinPosition when hasMouseOver guard fires", function()
			local mockParent = {}
			row = buildHoverRow(mockParent)
			row.hasMouseOver = true -- already over, guard will return early

			onEnter()

			assert.stub(row.PinPosition).was_not.called()
		end)

		it("OnLeave calls ReleasePin on the parent frame", function()
			local mockParent = { ReleasePin = spy.new(function() end) }
			row = buildHoverRow(mockParent)
			-- OnLeave guard: hasMouseOver must be true to proceed
			row.hasMouseOver = true

			onLeave()

			assert.spy(mockParent.ReleasePin).was.called_with(mockParent, row)
		end)

		it("OnLeave does not call ReleasePin when GetParent returns nil", function()
			row = buildHoverRow(nil) -- GetParent returns nil
			row.hasMouseOver = true

			-- Should not error
			onLeave()
		end)

		-- ── hover.enabled = false regression (issue #368 pin fix) ────────

		it("OnEnter still sets hasMouseOver and calls PinPosition when hover.enabled is false", function()
			local mockParent = {}
			row = buildHoverRow(mockParent)
			stub(ns.DbAccessor, "Animations").returns({
				hover = { enabled = false, alpha = 0.3, baseDuration = 0.15 },
				reposition = { duration = 0.2 },
			})
			-- Re-run SetUpHoverEffect with hover disabled so OnEnter uses the updated db
			row:SetUpHoverEffect()

			onEnter()

			assert.is_true(row.hasMouseOver)
			assert.stub(row.PinPosition).was.called_with(row, mockParent)
		end)

		it("OnEnter stops ExitAnimation when not in history mode", function()
			local mockParent = {}
			row = buildHoverRow(mockParent)
			row.isHistoryMode = false
			local exitSpy = { Stop = spy.new(function() end) }
			row.ExitAnimation = exitSpy

			onEnter()

			assert.spy(exitSpy.Stop).was.called(1)
		end)

		it("OnEnter does NOT play HighlightFadeIn when hover.enabled is false", function()
			local mockParent = {}
			row = buildHoverRow(mockParent)
			stub(ns.DbAccessor, "Animations").returns({
				hover = { enabled = false, alpha = 0.3, baseDuration = 0.15 },
				reposition = { duration = 0.2 },
			})
			row:SetUpHoverEffect()
			-- HighlightFadeIn was created during the first SetUpHoverEffect call
			assert.is_not_nil(row.HighlightFadeIn)
			-- Play would be called on it only if hover.enabled = true
			stub(row.HighlightFadeIn, "Play")

			onEnter()

			assert.stub(row.HighlightFadeIn.Play).was_not.called()
		end)

		it("OnLeave plays ExitAnimation when mouse truly leaves and not history mode", function()
			local mockParent = { ReleasePin = spy.new(function() end) }
			row = buildHoverRow(mockParent)
			row.isHistoryMode = false
			row.hasMouseOver = true
			local exitSpy = { Stop = spy.new(function() end), Play = spy.new(function() end) }
			row.ExitAnimation = exitSpy

			onLeave()

			assert.spy(exitSpy.Play).was.called(1)
		end)

		it("OnLeave does NOT play HighlightFadeOut when hover.enabled is false", function()
			local mockParent = { ReleasePin = spy.new(function() end) }
			row = buildHoverRow(mockParent)
			stub(ns.DbAccessor, "Animations").returns({
				hover = { enabled = false, alpha = 0.3, baseDuration = 0.15 },
				reposition = { duration = 0.2 },
			})
			row:SetUpHoverEffect()
			assert.is_not_nil(row.HighlightFadeOut)
			stub(row.HighlightFadeOut, "Play")
			row.hasMouseOver = true

			onLeave()

			assert.stub(row.HighlightFadeOut.Play).was_not.called()
		end)
	end)
end)
