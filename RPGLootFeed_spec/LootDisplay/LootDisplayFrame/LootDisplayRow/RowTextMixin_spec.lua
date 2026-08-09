local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local rowFrameMocks = require("RPGLootFeed_spec._mocks.Internal.LootDisplayRowFrame")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local stub = busted.stub

local MIXIN_FILE = "RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayRow/RowTextMixin.lua"

--- Stub a list of method names onto `tbl` using busted stubs.
--- Mirrors the helper in LootDisplayRowFrame.lua so spec-local mocks
--- can be built without importing the internal mock module directly.
local function stubMethods(tbl, names)
	for _, name in ipairs(names) do
		if tbl[name] == nil then
			tbl[name] = function() end
		end
		stub(tbl, name)
	end
	return tbl
end

describe("RLF_RowTextMixin", function()
	local ns, row

	-- Full styling/sizing db used by StyleText.  Fields listed match every
	-- property read by StyleText, StyleTopLeftText, and the layout section.
	local function makeDefaultStylingDb()
		return {
			fontFace = "Fonts/FRIZQT__.TTF",
			useFontObjects = false,
			font = {},
			fontSize = 14,
			secondaryFontSize = 11,
			topLeftIconFontSize = 10,
			fontShadowColor = { 0, 0, 0, 1 },
			fontShadowOffsetX = 1,
			fontShadowOffsetY = -1,
			textAlignment = "LEFT",
			enabledSecondaryRowText = false,
			rowTextSpacing = 0,
		}
	end

	local function makeDefaultSizingDb()
		return { padding = 4, iconSize = 32 }
	end

	before_each(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		assert(loadfile(MIXIN_FILE))("TestAddon", ns)
		row = rowFrameMocks.new()
		-- Mix mixin methods into the row so self:Method() calls inside the
		-- mixin (e.g. StyleText → CreateTopLeftText → StyleTopLeftText) resolve.
		for k, v in pairs(RLF_RowTextMixin) do
			row[k] = v
		end
		-- RGBAToHexFormat must return a string so ShowItemCountText can concat it.
		nsMocks.RGBAToHexFormat.returns("|cffffffff")
	end)

	-- ── Load order ─────────────────────────────────────────────────────────

	describe("load order", function()
		it("loads the file and exposes the global mixin table", function()
			assert.is_not_nil(_G.RLF_RowTextMixin)
			assert.is_function(RLF_RowTextMixin.StyleText)
			assert.is_function(RLF_RowTextMixin.ShowText)
			assert.is_function(RLF_RowTextMixin.ShowAmountText)
			assert.is_function(RLF_RowTextMixin.ShowItemCountText)
			assert.is_function(RLF_RowTextMixin.UpdateSecondaryText)
			assert.is_function(RLF_RowTextMixin.CreatePrimaryLineLayout)
			assert.is_function(RLF_RowTextMixin.LayoutPrimaryLine)
			assert.is_function(RLF_RowTextMixin.CreateSecondaryLineLayout)
			assert.is_function(RLF_RowTextMixin.LayoutSecondaryLine)
		end)
	end)

	-- ── StyleText ──────────────────────────────────────────────────────────

	describe("StyleText", function()
		before_each(function()
			stub(ns.DbAccessor, "Styling").returns(makeDefaultStylingDb())
			stub(ns.DbAccessor, "Sizing").returns(makeDefaultSizingDb())
		end)

		it("calls SetFont on PrimaryText on the first call when not using font objects", function()
			RLF_RowTextMixin.StyleText(row)
			assert.stub(row.PrimaryText.SetFont).was.called(1)
		end)

		it("calls SetFont on all font strings on the first call", function()
			RLF_RowTextMixin.StyleText(row)
			assert.stub(row.PrimaryText.SetFont).was.called(1)
			assert.stub(row.AmountText.SetFont).was.called(1)
			assert.stub(row.ItemCountText.SetFont).was.called(1)
			assert.stub(row.SecondaryText.SetFont).was.called(1)
		end)

		it("skips SetFont on a re-call with identical values (cache hit)", function()
			RLF_RowTextMixin.StyleText(row)
			row.PrimaryText.SetFont:clear()
			RLF_RowTextMixin.StyleText(row)
			assert.stub(row.PrimaryText.SetFont).was_not.called()
		end)

		it("calls SetFont again when fontSize changes", function()
			RLF_RowTextMixin.StyleText(row)
			row.PrimaryText.SetFont:clear()
			ns.DbAccessor.Styling.returns(makeDefaultStylingDb())
			local db = makeDefaultStylingDb()
			db.fontSize = 18
			stub(ns.DbAccessor, "Styling").returns(db)
			RLF_RowTextMixin.StyleText(row)
			assert.stub(row.PrimaryText.SetFont).was.called(1)
		end)

		it("reads font flags for the row's own frame", function()
			-- Frame IDs are plain integers; 2 is the first non-main frame.
			row.frameType = 2
			RLF_RowTextMixin.StyleText(row)
			assert.stub(nsMocks.FontFlagsToString).was.called_with(ns, 2)
		end)

		describe("when useFontObjects is true", function()
			before_each(function()
				local db = makeDefaultStylingDb()
				db.useFontObjects = true
				db.font = {}
				stub(ns.DbAccessor, "Styling").returns(db)
			end)

			it("calls SetFontObject instead of SetFont on PrimaryText", function()
				RLF_RowTextMixin.StyleText(row)
				assert.stub(row.PrimaryText.SetFontObject).was.called(1)
				assert.stub(row.PrimaryText.SetFont).was_not.called()
			end)

			it("calls SetFontObject on all four text elements", function()
				RLF_RowTextMixin.StyleText(row)
				assert.stub(row.PrimaryText.SetFontObject).was.called(1)
				assert.stub(row.AmountText.SetFontObject).was.called(1)
				assert.stub(row.ItemCountText.SetFontObject).was.called(1)
				assert.stub(row.SecondaryText.SetFontObject).was.called(1)
			end)
		end)

		it("calls SetJustifyH on PrimaryText", function()
			RLF_RowTextMixin.StyleText(row)
			assert.stub(row.PrimaryText.SetJustifyH).was.called(1)
		end)

		it("calls SetPoint on PrimaryLineLayout (icon anchor) based on layout", function()
			RLF_RowTextMixin.StyleText(row)
			assert.stub(row.PrimaryLineLayout.SetPoint).was.called()
		end)

		it("sets PrimaryLineLayout.childLayoutDirection to nil when textAlignment is LEFT", function()
			RLF_RowTextMixin.StyleText(row)
			assert.is_nil(row.PrimaryLineLayout.childLayoutDirection)
		end)

		it("sets PrimaryLineLayout.childLayoutDirection to nil when textAlignment is CENTER", function()
			local db = makeDefaultStylingDb()
			db.textAlignment = "CENTER"
			stub(ns.DbAccessor, "Styling").returns(db)
			RLF_RowTextMixin.StyleText(row)
			assert.is_nil(row.PrimaryLineLayout.childLayoutDirection)
		end)

		it("sets PrimaryLineLayout.childLayoutDirection to rightToLeft when textAlignment is RIGHT", function()
			local db = makeDefaultStylingDb()
			db.textAlignment = "RIGHT"
			stub(ns.DbAccessor, "Styling").returns(db)
			RLF_RowTextMixin.StyleText(row)
			assert.equal("rightToLeft", row.PrimaryLineLayout.childLayoutDirection)
		end)

		it(
			"sets PrimaryLineLayout and SecondaryLineLayout spacing to iconSize/4 when rowTextSpacing is 0 (auto)",
			function()
				RLF_RowTextMixin.StyleText(row)
				assert.equal(8, row.PrimaryLineLayout.spacing) -- iconSize=32, 32/4=8
				assert.equal(8, row.SecondaryLineLayout.spacing) -- same value
			end
		)
	end)

	-- ── ShowText ───────────────────────────────────────────────────────────

	describe("ShowText", function()
		before_each(function()
			stub(ns.DbAccessor, "Styling").returns({
				enabledSecondaryRowText = false,
			})
			stub(ns.DbAccessor, "Sizing").returns({ iconSize = 32, feedWidth = 200, padding = 4 })
			-- Stub LayoutPrimaryLine so ShowText tests focus on text/color logic only.
			-- LayoutPrimaryLine and LayoutSecondaryLine each have their own describe blocks.
			stub(row, "LayoutPrimaryLine")
			stub(row, "LayoutSecondaryLine")
		end)

		it("calls SetText on PrimaryText", function()
			RLF_RowTextMixin.ShowText(row, "Hello World")
			assert.stub(row.PrimaryText.SetText).was.called_with(row.PrimaryText, "Hello World")
		end)

		it("stores the raw text in rawPrimaryText", function()
			RLF_RowTextMixin.ShowText(row, "Hello World")
			assert.equal("Hello World", row.rawPrimaryText)
		end)

		it("calls SetTextColor on PrimaryText", function()
			RLF_RowTextMixin.ShowText(row, "Hello", 0.5, 0.5, 0.5, 1)
			assert.stub(row.PrimaryText.SetTextColor).was.called(1)
		end)

		it("uses default white color when no color args are given", function()
			local r, g, b
			stub(row.PrimaryText, "SetTextColor", function(_, rr, gg, bb)
				r, g, b = rr, gg, bb
			end)
			RLF_RowTextMixin.ShowText(row, "Hello")
			assert.equal(1, r)
			assert.equal(1, g)
			assert.equal(1, b)
		end)

		it("uses default color when amount is negative and no color is given (callers handle red override)", function()
			local r, g, b
			stub(row.PrimaryText, "SetTextColor", function(_, rr, gg, bb)
				r, g, b = rr, gg, bb
			end)
			row.amount = -5
			RLF_RowTextMixin.ShowText(row, "-5g")
			assert.equal(1, r)
			assert.equal(1, g)
			assert.equal(1, b)
		end)

		it("calls LayoutPrimaryLine to drive the layout pass", function()
			RLF_RowTextMixin.ShowText(row, "Foo")
			assert.stub(row.LayoutPrimaryLine).was.called(1)
		end)

		it("shows SecondaryText when enabledSecondaryRowText is true and secondaryText is set", function()
			stub(ns.DbAccessor, "Styling").returns({ enabledSecondaryRowText = true })
			row.secondaryText = "Bonus"
			RLF_RowTextMixin.ShowText(row, "Main")
			assert.stub(row.SecondaryText.Show).was.called(1)
			assert.stub(row.SecondaryLineLayout.Show).was.called(1)
		end)

		it("hides SecondaryText when enabledSecondaryRowText is false", function()
			RLF_RowTextMixin.ShowText(row, "Main")
			assert.stub(row.SecondaryText.Hide).was.called(1)
			assert.stub(row.SecondaryLineLayout.Hide).was.called(1)
		end)
	end)
	-- ── ShowAmountText ───────────────────────────────────────────────────────

	describe("ShowAmountText", function()
		before_each(function()
			stub(ns.DbAccessor, "Sizing").returns({ iconSize = 32, feedWidth = 200 })
			-- Isolate ShowAmountText from LayoutPrimaryLine.
			stub(row, "LayoutPrimaryLine")
			row.AmountText.IsShown = function()
				return false
			end
			row.ItemCountText.IsShown = function()
				return false
			end
			row.rawPrimaryText = "Some Item"
		end)

		it("shows AmountText and sets text when amountText is non-empty", function()
			RLF_RowTextMixin.ShowAmountText(row, "x3", 1, 1, 1, 1)
			assert.stub(row.AmountText.Show).was.called(1)
			assert.stub(row.AmountText.SetText).was.called_with(row.AmountText, "x3")
		end)

		it("sets text color matching the provided r/g/b/a", function()
			RLF_RowTextMixin.ShowAmountText(row, "x2", 0.5, 0.2, 0.8, 1)
			assert.stub(row.AmountText.SetTextColor).was.called_with(row.AmountText, 0.5, 0.2, 0.8, 1)
		end)

		it("hides AmountText when amountText is an empty string", function()
			RLF_RowTextMixin.ShowAmountText(row, "", 1, 1, 1, 1)
			assert.stub(row.AmountText.Hide).was.called(1)
			assert.stub(row.AmountText.Show).was_not.called()
		end)

		it("hides AmountText when amountText is nil", function()
			RLF_RowTextMixin.ShowAmountText(row, nil, 1, 1, 1, 1)
			assert.stub(row.AmountText.Hide).was.called(1)
			assert.stub(row.AmountText.Show).was_not.called()
		end)

		it("calls LayoutPrimaryLine after updating visibility", function()
			RLF_RowTextMixin.ShowAmountText(row, "x2", 1, 1, 1, 1)
			assert.stub(row.LayoutPrimaryLine).was.called(1)
		end)

		it("calls LayoutPrimaryLine even when hiding", function()
			RLF_RowTextMixin.ShowAmountText(row, "", 1, 1, 1, 1)
			assert.stub(row.LayoutPrimaryLine).was.called(1)
		end)
	end)
	-- ── ShowItemCountText ──────────────────────────────────────────────────

	describe("ShowItemCountText", function()
		before_each(function()
			stub(ns.DbAccessor, "Sizing").returns({ iconSize = 32, feedWidth = 200, padding = 4 })
			-- Isolate ShowItemCountText from LayoutPrimaryLine - tested separately.
			stub(row, "LayoutPrimaryLine")
		end)
		it("shows ItemCountText when count is a number greater than 1", function()
			RLF_RowTextMixin.ShowItemCountText(row, 5, { color = "|cffffffff" })
			assert.stub(row.ItemCountText.Show).was.called(1)
		end)

		it("does not show ItemCountText when count is 1 (no showSign)", function()
			RLF_RowTextMixin.ShowItemCountText(row, 1, { color = "|cffffffff" })
			assert.stub(row.ItemCountText.Show).was_not.called()
		end)

		it("shows ItemCountText when count is 1 and showSign is true", function()
			RLF_RowTextMixin.ShowItemCountText(row, 1, { color = "|cffffffff", showSign = true })
			assert.stub(row.ItemCountText.Show).was.called(1)
		end)

		it("includes a '+' prefix when showSign is true", function()
			local capturedText
			stub(row.ItemCountText, "SetText", function(_, t)
				capturedText = t
			end)
			RLF_RowTextMixin.ShowItemCountText(row, 5, { color = "|cffffffff", showSign = true })
			assert.truthy(capturedText:find("%+"))
		end)

		it("hides ItemCountText when count is nil", function()
			RLF_RowTextMixin.ShowItemCountText(row, nil, { color = "|cffffffff" })
			assert.stub(row.ItemCountText.Hide).was.called(1)
		end)

		it("shows ItemCountText when count is a non-empty string", function()
			RLF_RowTextMixin.ShowItemCountText(row, "Veteran", { color = "|cffffffff" })
			assert.stub(row.ItemCountText.Show).was.called(1)
		end)

		it("does not show ItemCountText when count is an empty string", function()
			RLF_RowTextMixin.ShowItemCountText(row, "", { color = "|cffffffff" })
			assert.stub(row.ItemCountText.Show).was_not.called()
		end)

		it("calls LayoutPrimaryLine after updating ItemCountText", function()
			RLF_RowTextMixin.ShowItemCountText(row, 5, { color = "|cffffffff" })
			assert.stub(row.LayoutPrimaryLine).was.called(1)
		end)
	end)

	-- ── LayoutPrimaryLine ──────────────────────────────────────────────

	describe("LayoutPrimaryLine", function()
		-- iconSize=32, feedWidth=200
		-- iconOffset = iconSize/4 + iconSize + iconSize/4 = 8+32+8 = 48
		-- availableWidth = 200 - 48 = 152 (no portrait)
		local ICON_SIZE = 32
		local FEED_WIDTH = 200
		local AVAILABLE_WIDTH = FEED_WIDTH - (ICON_SIZE + 2 * (ICON_SIZE / 4)) -- 152
		local SPACING = ICON_SIZE / 4 -- 8

		before_each(function()
			stub(ns.DbAccessor, "Sizing").returns({ iconSize = ICON_SIZE, feedWidth = FEED_WIDTH })
			row.rawPrimaryText = "Some Item Name"
			row.ItemCountText.IsShown = function()
				return false
			end
			row.ItemCountText.GetUnboundedStringWidth = function()
				return 40
			end
			row.AmountText.IsShown = function()
				return false
			end
			row.AmountText.GetUnboundedStringWidth = function()
				return 30
			end
			row.PrimaryLineLayout.spacing = SPACING
		end)

		-- ── Natural width fits within available space ──────────────────────

		it("uses natural width when text fits (no ItemCountText)", function()
			local NATURAL = 80 -- fits within 152
			row.PrimaryText.GetUnboundedStringWidth = function()
				return NATURAL
			end
			RLF_RowTextMixin.LayoutPrimaryLine(row)
			assert.stub(row.PrimaryText.SetWidth).was.called_with(row.PrimaryText, NATURAL)
		end)

		it("uses natural width when text fits with ItemCountText shown", function()
			local COUNT_WIDTH = 40
			local NATURAL = 80 -- fits within 152-40-8 = 104
			row.ItemCountText.IsShown = function()
				return true
			end
			row.ItemCountText.GetUnboundedStringWidth = function()
				return COUNT_WIDTH
			end
			row.PrimaryText.GetUnboundedStringWidth = function()
				return NATURAL
			end
			RLF_RowTextMixin.LayoutPrimaryLine(row)
			assert.stub(row.PrimaryText.SetWidth).was.called_with(row.PrimaryText, NATURAL)
		end)

		it("uses natural width when text fits with AmountText shown", function()
			local AMOUNT_WIDTH = 30
			local NATURAL = 80 -- fits within 152-30-8 = 114
			row.AmountText.IsShown = function()
				return true
			end
			row.AmountText.GetUnboundedStringWidth = function()
				return AMOUNT_WIDTH
			end
			row.PrimaryText.GetUnboundedStringWidth = function()
				return NATURAL
			end
			RLF_RowTextMixin.LayoutPrimaryLine(row)
			assert.stub(row.PrimaryText.SetWidth).was.called_with(row.PrimaryText, NATURAL)
		end)

		-- ── Natural width exceeds budget → truncate ────────────────────────

		it("caps PrimaryText at availableWidth when text is wider than the row", function()
			local NATURAL = 200 -- wider than 152
			row.PrimaryText.GetUnboundedStringWidth = function()
				return NATURAL
			end
			RLF_RowTextMixin.LayoutPrimaryLine(row)
			assert.stub(row.PrimaryText.SetWidth).was.called_with(row.PrimaryText, AVAILABLE_WIDTH)
		end)

		it("caps PrimaryText when ItemCountText is shown and text overflows remaining space", function()
			local COUNT_WIDTH = 40
			local MAX_PRIMARY = AVAILABLE_WIDTH - COUNT_WIDTH - SPACING -- 104
			local NATURAL = 150 -- wider than 104
			row.ItemCountText.IsShown = function()
				return true
			end
			row.ItemCountText.GetUnboundedStringWidth = function()
				return COUNT_WIDTH
			end
			row.PrimaryText.GetUnboundedStringWidth = function()
				return NATURAL
			end
			RLF_RowTextMixin.LayoutPrimaryLine(row)
			assert.stub(row.PrimaryText.SetWidth).was.called_with(row.PrimaryText, MAX_PRIMARY)
		end)

		it("caps PrimaryText when AmountText is shown and text overflows remaining space", function()
			local AMOUNT_WIDTH = 30
			local MAX_PRIMARY = AVAILABLE_WIDTH - AMOUNT_WIDTH - SPACING -- 114
			local NATURAL = 150 -- wider than 114
			row.AmountText.IsShown = function()
				return true
			end
			row.AmountText.GetUnboundedStringWidth = function()
				return AMOUNT_WIDTH
			end
			row.PrimaryText.GetUnboundedStringWidth = function()
				return NATURAL
			end
			RLF_RowTextMixin.LayoutPrimaryLine(row)
			assert.stub(row.PrimaryText.SetWidth).was.called_with(row.PrimaryText, MAX_PRIMARY)
		end)

		it("accounts for both AmountText and ItemCountText when both are shown", function()
			local AMOUNT_WIDTH = 30
			local COUNT_WIDTH = 40
			local MAX_PRIMARY = AVAILABLE_WIDTH - AMOUNT_WIDTH - SPACING - COUNT_WIDTH - SPACING -- 66
			local NATURAL = 150
			row.AmountText.IsShown = function()
				return true
			end
			row.AmountText.GetUnboundedStringWidth = function()
				return AMOUNT_WIDTH
			end
			row.ItemCountText.IsShown = function()
				return true
			end
			row.ItemCountText.GetUnboundedStringWidth = function()
				return COUNT_WIDTH
			end
			row.PrimaryText.GetUnboundedStringWidth = function()
				return NATURAL
			end
			RLF_RowTextMixin.LayoutPrimaryLine(row)
			assert.stub(row.PrimaryText.SetWidth).was.called_with(row.PrimaryText, MAX_PRIMARY)
		end)

		-- ── Container and layout ───────────────────────────────────────────

		it("always sets PrimaryLineLayout.fixedWidth to availableWidth", function()
			row.PrimaryText.GetUnboundedStringWidth = function()
				return 80
			end
			RLF_RowTextMixin.LayoutPrimaryLine(row)
			assert.equal(AVAILABLE_WIDTH, row.PrimaryLineLayout.fixedWidth)
		end)

		it("calls PrimaryLineLayout:Layout()", function()
			row.PrimaryText.GetUnboundedStringWidth = function()
				return 80
			end
			RLF_RowTextMixin.LayoutPrimaryLine(row)
			assert.stub(row.PrimaryLineLayout.Layout).was.called(1)
		end)

		-- ── ClickableButton ────────────────────────────────────────────────

		it("sets ClickableButton anchor and size when link is set", function()
			row.link = "|Hitem:123|h[Foo]|h"
			row.PrimaryText.GetUnboundedStringWidth = function()
				return 80
			end
			RLF_RowTextMixin.LayoutPrimaryLine(row)
			assert.stub(row.ClickableButton.SetSize).was.called(1)
			assert.stub(row.ClickableButton.SetPoint).was.called(1)
		end)

		it("does not touch ClickableButton when link is nil", function()
			row.link = nil
			row.PrimaryText.GetUnboundedStringWidth = function()
				return 80
			end
			RLF_RowTextMixin.LayoutPrimaryLine(row)
			assert.stub(row.ClickableButton.SetSize).was_not.called()
		end)
	end)
	-- ── LayoutSecondaryLine ─────────────────────────────────────

	describe("LayoutSecondaryLine", function()
		-- iconSize=32, feedWidth=200
		-- iconOffset = iconSize/4 + iconSize + iconSize/4 = 8+32+8 = 48
		-- availableWidth = 200 - 48 = 152 (no portrait)
		local ICON_SIZE = 32
		local FEED_WIDTH = 200
		local AVAILABLE_WIDTH = FEED_WIDTH - (ICON_SIZE + 2 * (ICON_SIZE / 4)) -- 152

		before_each(function()
			stub(ns.DbAccessor, "Sizing").returns({ iconSize = ICON_SIZE, feedWidth = FEED_WIDTH })
			row.secondaryText = "Some secondary text"
			row.SecondaryLineLayout.spacing = 0
		end)

		it("uses natural width when secondary text fits", function()
			row.SecondaryText.GetUnboundedStringWidth = function()
				return 80
			end
			RLF_RowTextMixin.LayoutSecondaryLine(row)
			assert.stub(row.SecondaryText.SetWidth).was.called_with(row.SecondaryText, 80)
		end)

		it("caps SecondaryText at availableWidth when text overflows", function()
			row.SecondaryText.GetUnboundedStringWidth = function()
				return 200
			end
			RLF_RowTextMixin.LayoutSecondaryLine(row)
			assert.stub(row.SecondaryText.SetWidth).was.called_with(row.SecondaryText, AVAILABLE_WIDTH)
		end)

		it("re-sets secondary text after SetWidth to enable engine truncation", function()
			row.SecondaryText.GetUnboundedStringWidth = function()
				return 80
			end
			RLF_RowTextMixin.LayoutSecondaryLine(row)
			assert.stub(row.SecondaryText.SetText).was.called_with(row.SecondaryText, "Some secondary text")
		end)

		it("sets SecondaryLineLayout.fixedWidth to availableWidth", function()
			row.SecondaryText.GetUnboundedStringWidth = function()
				return 80
			end
			RLF_RowTextMixin.LayoutSecondaryLine(row)
			assert.equal(AVAILABLE_WIDTH, row.SecondaryLineLayout.fixedWidth)
		end)

		it("calls SecondaryLineLayout:Layout()", function()
			row.SecondaryText.GetUnboundedStringWidth = function()
				return 80
			end
			RLF_RowTextMixin.LayoutSecondaryLine(row)
			assert.stub(row.SecondaryLineLayout.Layout).was.called(1)
		end)
	end)
	-- ── UpdateSecondaryText ────────────────────────────────────────────────

	describe("UpdateSecondaryText", function()
		it("sets secondaryText to nil when enabledSecondaryRowText is false", function()
			stub(ns.DbAccessor, "Styling").returns({ enabledSecondaryRowText = false })
			row.secondaryText = "stale"
			RLF_RowTextMixin.UpdateSecondaryText(row, nil)
			assert.is_nil(row.secondaryText)
		end)

		it("uses elementSecondaryText when present (ignores fn)", function()
			stub(ns.DbAccessor, "Styling").returns({ enabledSecondaryRowText = true })
			row.elementSecondaryText = "Soulbound"
			RLF_RowTextMixin.UpdateSecondaryText(row, function()
				return "from fn"
			end)
			assert.equal("Soulbound", row.secondaryText)
		end)

		it("uses the result of secondaryTextFn when elementSecondaryText is absent", function()
			stub(ns.DbAccessor, "Styling").returns({ enabledSecondaryRowText = true })
			row.amount = 100
			RLF_RowTextMixin.UpdateSecondaryText(row, function(amount)
				return tostring(amount) .. "g"
			end)
			assert.equal("100g", row.secondaryText)
		end)

		it("sets secondaryText to nil when secondaryTextFn returns empty string", function()
			stub(ns.DbAccessor, "Styling").returns({ enabledSecondaryRowText = true })
			RLF_RowTextMixin.UpdateSecondaryText(row, function()
				return ""
			end)
			assert.is_nil(row.secondaryText)
		end)

		it("sets secondaryText to nil when secondaryTextFn returns nil", function()
			stub(ns.DbAccessor, "Styling").returns({ enabledSecondaryRowText = true })
			RLF_RowTextMixin.UpdateSecondaryText(row, function()
				return nil
			end)
			assert.is_nil(row.secondaryText)
		end)
	end)

	-- ── CreateTopLeftText ──────────────────────────────────────────────────

	describe("CreateTopLeftText", function()
		before_each(function()
			stub(ns.DbAccessor, "Styling").returns(makeDefaultStylingDb())
		end)

		it("hides Icon.topLeftText after creation/styling", function()
			RLF_RowTextMixin.CreateTopLeftText(row)
			assert.stub(row.Icon.topLeftText.Hide).was.called(1)
		end)

		it("does not call CreateFontString when topLeftText already exists", function()
			RLF_RowTextMixin.CreateTopLeftText(row)
			assert.stub(row.Icon.CreateFontString).was_not.called()
		end)

		it("calls CreateFontString when topLeftText is nil (fresh row)", function()
			row.Icon.topLeftText = nil
			-- CreateFontString stub returns a fresh FontString mock so the
			-- follow-up SetPoint call on the result does not error.
			RLF_RowTextMixin.CreateTopLeftText(row)
			assert.stub(row.Icon.CreateFontString).was.called(1)
		end)
	end)

	-- ── RecheckSecondaryCoinDisplayAnchor ──────────────────────────────────
	-- Regression guard for issue #554: anchor must flip to RIGHT/LEFT when
	-- the feed is right-aligned (icon on right) so the coin display appears to
	-- the left of the text instead of overlapping the icon.

	describe("RecheckSecondaryCoinDisplayAnchor", function()
		local function makeScdMock()
			local scd = {}
			stubMethods(scd, { "ClearAllPoints", "SetPoint", "SetSize", "Show", "Hide" })
			scd.IsShown = function()
				return true
			end
			return scd
		end

		before_each(function()
			row.PrimaryLineLayout.spacing = 8
			row.SecondaryLineLayout.IsShown = function()
				return false
			end
		end)

		it("returns early without error when SecondaryCoinDisplay is absent", function()
			row.SecondaryCoinDisplay = nil
			RLF_RowTextMixin.RecheckSecondaryCoinDisplayAnchor(row)
		end)

		it("returns early when SecondaryCoinDisplay is hidden", function()
			local scd = makeScdMock()
			scd.IsShown = function()
				return false
			end
			row.SecondaryCoinDisplay = scd
			RLF_RowTextMixin.RecheckSecondaryCoinDisplayAnchor(row)
			assert.stub(scd.SetPoint).was_not.called()
		end)

		it("returns early when SecondaryLineLayout is shown (SCD already on secondary row)", function()
			row.SecondaryCoinDisplay = makeScdMock()
			row.SecondaryLineLayout.IsShown = function()
				return true
			end
			RLF_RowTextMixin.RecheckSecondaryCoinDisplayAnchor(row)
			assert.stub(row.SecondaryCoinDisplay.SetPoint).was_not.called()
		end)

		describe("when left-aligned (icon on left)", function()
			before_each(function()
				row.cachedRowTextAlignment = "LEFT"
				row.SecondaryCoinDisplay = makeScdMock()
			end)

			it("anchors SCD with LEFT/RIGHT points (after PrimaryText)", function()
				local anchor, relPoint
				stub(row.SecondaryCoinDisplay, "SetPoint", function(_, a, _, p)
					anchor, relPoint = a, p
				end)
				RLF_RowTextMixin.RecheckSecondaryCoinDisplayAnchor(row)
				assert.equal("LEFT", anchor)
				assert.equal("RIGHT", relPoint)
			end)

			it("uses PrimaryText as the anchor frame when no count/amount/coin is shown", function()
				local relFrame
				stub(row.SecondaryCoinDisplay, "SetPoint", function(_, _, f)
					relFrame = f
				end)
				RLF_RowTextMixin.RecheckSecondaryCoinDisplayAnchor(row)
				assert.equal(row.PrimaryText, relFrame)
			end)

			it("uses ItemCountText as the anchor frame when ItemCountText is shown", function()
				row.ItemCountText.IsShown = function()
					return true
				end
				local relFrame
				stub(row.SecondaryCoinDisplay, "SetPoint", function(_, _, f)
					relFrame = f
				end)
				RLF_RowTextMixin.RecheckSecondaryCoinDisplayAnchor(row)
				assert.equal(row.ItemCountText, relFrame)
			end)
		end)

		describe("when right-aligned (icon on right) — issue #554 regression", function()
			before_each(function()
				row.cachedRowTextAlignment = "RIGHT"
				row.SecondaryCoinDisplay = makeScdMock()
			end)

			it("anchors SCD with RIGHT/LEFT points (before PrimaryText, away from icon)", function()
				local anchor, relPoint
				stub(row.SecondaryCoinDisplay, "SetPoint", function(_, a, _, p)
					anchor, relPoint = a, p
				end)
				RLF_RowTextMixin.RecheckSecondaryCoinDisplayAnchor(row)
				assert.equal("RIGHT", anchor)
				assert.equal("LEFT", relPoint)
			end)

			it("uses a negative x-offset so SCD clears the text to the left", function()
				local xOff
				stub(row.SecondaryCoinDisplay, "SetPoint", function(_, _, _, _, x)
					xOff = x
				end)
				RLF_RowTextMixin.RecheckSecondaryCoinDisplayAnchor(row)
				assert.is_true(xOff < 0)
			end)

			it("uses PrimaryText as anchor frame when no count/amount/coin is shown", function()
				local relFrame
				stub(row.SecondaryCoinDisplay, "SetPoint", function(_, _, f)
					relFrame = f
				end)
				RLF_RowTextMixin.RecheckSecondaryCoinDisplayAnchor(row)
				assert.equal(row.PrimaryText, relFrame)
			end)
		end)
	end)

	-- ── UpdateSecondaryCoinDisplay — anchor direction ──────────────────────
	-- Regression guard for issue #554: when the secondary row is active the
	-- coin display must be anchored on the correct side of SecondaryText.

	describe("UpdateSecondaryCoinDisplay anchor direction (secondary row active)", function()
		-- Build a minimal SecondaryCoinDisplay mock with denomination groups so
		-- UpdateSecondaryCoinDisplay can run to completion and reach the anchor code.
		local function makeDenomGroup()
			local group = stubMethods({}, { "SetSize", "SetPoint", "ClearAllPoints", "Show", "Hide" })
			group.amountText = stubMethods({}, {
				"SetText",
				"SetPoint",
				"ClearAllPoints",
				"SetFont",
				"SetFontObject",
				"SetTextColor",
				"SetWordWrap",
			})
			group.amountText.GetUnboundedStringWidth = function()
				return 20
			end
			group.icon = stubMethods({}, { "SetSize", "SetPoint", "ClearAllPoints", "Show", "Hide", "SetAtlas" })
			return group
		end

		local function makeFullScdMock()
			local scd = stubMethods({}, { "SetSize", "SetPoint", "ClearAllPoints", "Show", "Hide" })
			scd.prefixIcon = stubMethods({}, {
				"SetAtlas",
				"SetSize",
				"SetPoint",
				"ClearAllPoints",
				"Show",
				"Hide",
			})
			scd.goldGroup = makeDenomGroup()
			scd.silverGroup = makeDenomGroup()
			scd.copperGroup = makeDenomGroup()
			return scd
		end

		before_each(function()
			-- Pre-set SCD so CreateSecondaryCoinDisplay is not called.
			row.SecondaryCoinDisplay = makeFullScdMock()
			-- Activate secondary row (so the onSecondaryRow branch is taken).
			row.SecondaryLineLayout.IsShown = function()
				return true
			end
			row.SecondaryLineLayout.spacing = 8
			row.cachedSecondaryFontSize = 12
			-- Stub layout helpers — tested separately.
			stub(row, "LayoutSecondaryLine")
			stub(row, "LayoutPrimaryLine")
			stub(row, "RecheckSecondaryCoinDisplayAnchor")
			stub(row, "StyleSecondaryCoinDisplay")
		end)

		it("anchors SCD with LEFT/RIGHT when left-aligned (icon on left)", function()
			row.cachedRowTextAlignment = "LEFT"
			local anchor, relPoint
			stub(row.SecondaryCoinDisplay, "SetPoint", function(_, a, _, p)
				anchor, relPoint = a, p
			end)
			-- Pass 5g so totalWidth > 0 and we reach the anchor code.
			RLF_RowTextMixin.UpdateSecondaryCoinDisplay(row, 5, 0, 0)
			assert.equal("LEFT", anchor)
			assert.equal("RIGHT", relPoint)
		end)

		it("anchors SCD with RIGHT/LEFT when right-aligned — issue #554 regression", function()
			row.cachedRowTextAlignment = "RIGHT"
			local anchor, relPoint
			stub(row.SecondaryCoinDisplay, "SetPoint", function(_, a, _, p)
				anchor, relPoint = a, p
			end)
			RLF_RowTextMixin.UpdateSecondaryCoinDisplay(row, 5, 0, 0)
			assert.equal("RIGHT", anchor)
			assert.equal("LEFT", relPoint)
		end)

		it("uses SecondaryText as the relative frame for both alignments", function()
			for _, alignment in ipairs({ "LEFT", "RIGHT" }) do
				row.cachedRowTextAlignment = alignment
				row.SecondaryCoinDisplay = makeFullScdMock()
				local relFrame
				stub(row.SecondaryCoinDisplay, "SetPoint", function(_, _, f)
					relFrame = f
				end)
				RLF_RowTextMixin.UpdateSecondaryCoinDisplay(row, 5, 0, 0)
				assert.equal(row.SecondaryText, relFrame, "alignment=" .. alignment)
			end
		end)
	end)

	-- ── Coin display font styling ──────────────────────────────────────────
	--
	-- The custom-font branch of both styling methods routes through
	-- G_RLF:ApplyFontStyle.  These cases exist because that branch was calling
	-- a file-local helper that no longer existed, which only surfaced in game.

	describe("coin display font styling", function()
		local function makeAmountText()
			return stubMethods({}, {
				"SetText",
				"SetPoint",
				"ClearAllPoints",
				"SetFont",
				"SetFontObject",
				"SetShadowColor",
				"SetShadowOffset",
				"SetTextColor",
				"SetWordWrap",
			})
		end

		local function makeCoinDisplay()
			local display = {}
			for _, denom in ipairs({ "gold", "silver", "copper" }) do
				local group = stubMethods({}, { "SetSize", "SetPoint", "ClearAllPoints", "Show", "Hide" })
				group.amountText = makeAmountText()
				group.icon = stubMethods({}, { "SetSize", "SetPoint", "ClearAllPoints", "Show", "Hide", "SetAtlas" })
				display[denom .. "Group"] = group
			end
			return display
		end

		before_each(function()
			row.cachedFontFace = "Expressway"
			row.cachedFontSize = 14
			row.cachedSecondaryFontSize = 12
			row.cachedFontFlags = "SLUG, OUTLINE"
			row.cachedFontShadowColor = { 0, 0, 0, 1 }
			row.cachedFontShadowOffsetX = 2
			row.cachedFontShadowOffsetY = -2
			row.cachedUseFontObject = false
			nsMocks.lsm.Fetch.returns("Fonts/Expressway.TTF")
		end)

		describe("StyleCoinDisplay", function()
			before_each(function()
				row.CoinDisplay = makeCoinDisplay()
			end)

			it("returns early when CoinDisplay is absent", function()
				row.CoinDisplay = nil
				RLF_RowTextMixin.StyleCoinDisplay(row)
				assert.stub(nsMocks.ApplyFontStyle).was_not.called()
			end)

			it("applies the row font to every denomination", function()
				RLF_RowTextMixin.StyleCoinDisplay(row)
				assert.stub(nsMocks.ApplyFontStyle).was.called(3)
				local amountText = row.CoinDisplay.goldGroup.amountText
				assert.stub(amountText.SetFont).was.called_with(amountText, "Fonts/Expressway.TTF", 14, "SLUG, OUTLINE")
				assert.stub(amountText.SetShadowOffset).was.called_with(amountText, 2, -2)
			end)

			it("uses the primary font object when font objects are enabled", function()
				row.cachedUseFontObject = true
				local fontObj = {}
				row.PrimaryText.GetFontObject = function()
					return fontObj
				end
				RLF_RowTextMixin.StyleCoinDisplay(row)
				assert.stub(nsMocks.ApplyFontStyle).was_not.called()
				local amountText = row.CoinDisplay.goldGroup.amountText
				assert.stub(amountText.SetFontObject).was.called_with(amountText, fontObj)
			end)
		end)

		describe("StyleSecondaryCoinDisplay", function()
			before_each(function()
				row.SecondaryCoinDisplay = makeCoinDisplay()
			end)

			it("returns early when SecondaryCoinDisplay is absent", function()
				row.SecondaryCoinDisplay = nil
				RLF_RowTextMixin.StyleSecondaryCoinDisplay(row)
				assert.stub(nsMocks.ApplyFontStyle).was_not.called()
			end)

			it("applies the secondary font size to every denomination", function()
				RLF_RowTextMixin.StyleSecondaryCoinDisplay(row)
				assert.stub(nsMocks.ApplyFontStyle).was.called(3)
				local amountText = row.SecondaryCoinDisplay.goldGroup.amountText
				assert.stub(amountText.SetFont).was.called_with(amountText, "Fonts/Expressway.TTF", 12, "SLUG, OUTLINE")
			end)
		end)
	end)
end)
