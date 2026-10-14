local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local rowFrameMocks = require("RPGLootFeed_spec._mocks.Internal.LootDisplayRowFrame")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local stub = busted.stub

local MIXIN_FILE = "RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayRow/RowBackdropMixin.lua"

describe("RLF_RowBackdropMixin", function()
	local ns, row

	before_each(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		assert(loadfile(MIXIN_FILE))("TestAddon", ns)
		row = rowFrameMocks.new()
	end)

	describe("load order", function()
		it("loads the file and exposes the global mixin table", function()
			assert.is_not_nil(_G.RLF_RowBackdropMixin)
			assert.is_function(RLF_RowBackdropMixin.StyleBackground)
			assert.is_function(RLF_RowBackdropMixin.StyleRowBackdrop)
		end)
	end)

	-- ── StyleBackground ────────────────────────────────────────────────────

	describe("StyleBackground", function()
		describe("when rowBackgroundType is not GRADIENT", function()
			before_each(function()
				stub(ns.DbAccessor, "Styling").returns({
					rowBackgroundType = ns.RowBackground.NONE,
				})
			end)

			it("hides the Background texture", function()
				RLF_RowBackdropMixin.StyleBackground(row)
				assert.stub(row.Background.Hide).was.called()
			end)

			it("does not call SetGradient", function()
				RLF_RowBackdropMixin.StyleBackground(row)
				assert.stub(row.Background.SetGradient).was_not.called()
			end)
		end)

		describe("when rowBackgroundType is GRADIENT", function()
			local stylingDb

			before_each(function()
				stylingDb = {
					rowBackgroundType = ns.RowBackground.GRADIENT,
					rowBackgroundGradientStart = { 0, 0, 0, 1 },
					rowBackgroundGradientEnd = { 1, 1, 1, 1 },
					textAlignment = "LEFT",
					backdropInsets = { top = 0, right = 0, bottom = 0, left = 0 },
				}
				stub(ns.DbAccessor, "Styling").returns(stylingDb)
			end)

			it("shows the Background texture", function()
				RLF_RowBackdropMixin.StyleBackground(row)
				assert.stub(row.Background.Show).was.called()
			end)

			it("calls SetGradient on the first call", function()
				RLF_RowBackdropMixin.StyleBackground(row)
				assert.stub(row.Background.SetGradient).was.called(1)
			end)

			it("skips SetGradient on a second call with identical values (cache hit)", function()
				RLF_RowBackdropMixin.StyleBackground(row)
				row.Background.SetGradient:clear()
				RLF_RowBackdropMixin.StyleBackground(row)
				assert.stub(row.Background.SetGradient).was_not.called()
			end)

			it("calls SetGradient again when a gradient value changes", function()
				RLF_RowBackdropMixin.StyleBackground(row)
				row.Background.SetGradient:clear()
				stylingDb.rowBackgroundGradientStart = { 1, 0, 0, 1 }
				RLF_RowBackdropMixin.StyleBackground(row)
				assert.stub(row.Background.SetGradient).was.called(1)
			end)

			it("calls SetGradient again when textAlignment changes", function()
				RLF_RowBackdropMixin.StyleBackground(row)
				row.Background.SetGradient:clear()
				stylingDb.textAlignment = "RIGHT"
				RLF_RowBackdropMixin.StyleBackground(row)
				assert.stub(row.Background.SetGradient).was.called(1)
			end)

			it("does not reposition Background when all insets are zero", function()
				RLF_RowBackdropMixin.StyleBackground(row)
				assert.stub(row.Background.ClearAllPoints).was_not.called()
			end)

			it("repositions Background via ClearAllPoints + two SetPoints when insets are non-zero", function()
				stylingDb.backdropInsets = { top = 4, right = 4, bottom = 4, left = 4 }
				RLF_RowBackdropMixin.StyleBackground(row)
				assert.stub(row.Background.ClearAllPoints).was.called(1)
				assert.stub(row.Background.SetPoint).was.called(2)
			end)
		end)
	end)

	-- ── StyleRowBackdrop ───────────────────────────────────────────────────

	describe("StyleRowBackdrop", function()
		describe("when neither border nor textured background is active", function()
			before_each(function()
				stub(ns.DbAccessor, "Styling").returns({
					enableRowBorder = false,
					rowBackgroundType = ns.RowBackground.GRADIENT,
					rowBorderTexture = "None",
					rowBackgroundTexture = "None",
					rowBackgroundTextureColor = { 0, 0, 0, 1 },
					backdropInsets = { top = 0, right = 0, bottom = 0, left = 0 },
					rowBorderClassColors = false,
					rowBorderColor = { 1, 1, 1, 1 },
					rowBorderSize = 4,
				})
			end)

			it("calls ClearBackdrop", function()
				RLF_RowBackdropMixin.StyleRowBackdrop(row)
				assert.stub(row.ClearBackdrop).was.called(1)
			end)

			it("does not call SetBackdrop", function()
				RLF_RowBackdropMixin.StyleRowBackdrop(row)
				assert.stub(row.SetBackdrop).was_not.called()
			end)
		end)

		describe("when a border texture is enabled", function()
			local stylingDb

			before_each(function()
				stylingDb = {
					enableRowBorder = true,
					rowBackgroundType = ns.RowBackground.NONE,
					rowBorderTexture = "Interface/Buttons/WHITE8X8",
					rowBorderSize = 8,
					rowBorderColor = { 1, 1, 1, 1 },
					rowBorderClassColors = false,
					rowBackgroundTexture = "None",
					rowBackgroundTextureColor = { 0, 0, 0, 1 },
					backdropInsets = { top = 0, right = 0, bottom = 0, left = 0 },
				}
				stub(ns.DbAccessor, "Styling").returns(stylingDb)
			end)

			it("calls SetBackdrop", function()
				RLF_RowBackdropMixin.StyleRowBackdrop(row)
				assert.stub(row.SetBackdrop).was.called(1)
			end)

			it("skips SetBackdrop on a re-call with the same cached values", function()
				RLF_RowBackdropMixin.StyleRowBackdrop(row)
				row.SetBackdrop:clear()
				RLF_RowBackdropMixin.StyleRowBackdrop(row)
				assert.stub(row.SetBackdrop).was_not.called()
			end)

			it("calls SetBackdrop again when a cached value changes", function()
				RLF_RowBackdropMixin.StyleRowBackdrop(row)
				row.SetBackdrop:clear()
				stylingDb.rowBorderSize = 16
				RLF_RowBackdropMixin.StyleRowBackdrop(row)
				assert.stub(row.SetBackdrop).was.called(1)
			end)

			it("calls SetBackdropBorderColor with flat color when classColors is false", function()
				RLF_RowBackdropMixin.StyleRowBackdrop(row)
				assert.stub(row.SetBackdropBorderColor).was.called(1)
			end)

			it("calls PerfPixel.PScale to scale the border size", function()
				RLF_RowBackdropMixin.StyleRowBackdrop(row)
				assert.stub(nsMocks.PerfPixel.PScale).was.called()
			end)
		end)

		describe("when classColors is true", function()
			before_each(function()
				stub(ns.DbAccessor, "Styling").returns({
					enableRowBorder = true,
					rowBackgroundType = ns.RowBackground.NONE,
					rowBorderTexture = "Interface/Buttons/WHITE8X8",
					rowBorderSize = 8,
					rowBorderColor = { 1, 1, 1, 1 },
					rowBorderClassColors = true,
					rowBackgroundTexture = "None",
					rowBackgroundTextureColor = { 0, 0, 0, 1 },
					backdropInsets = { top = 0, right = 0, bottom = 0, left = 0 },
				})
				-- Other specs may leave GetExpansionLevel returning an old-expansion value;
				-- ensure it's always >= BFA so the C_ClassColor path is taken.
				local fnMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.Functions")
				fnMocks.GetExpansionLevel.returns(ns.Expansion.TWW)
				-- GetClassColor must return a table with r/g/b to avoid indexing a number.
				local classColorMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.namespaces.C_ClassColor")
				classColorMocks.GetClassColor.returns({ r = 0.78, g = 0.61, b = 0.43 })
			end)

			it("calls C_ClassColor.GetClassColor", function()
				local classColorMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.namespaces.C_ClassColor")
				classColorMocks.GetClassColor:clear()
				RLF_RowBackdropMixin.StyleRowBackdrop(row)
				assert.stub(classColorMocks.GetClassColor).was.called()
			end)

			it("passes only the class filename to GetClassColor (12.1.5 added a tintColor arg #2)", function()
				local classColorMocks = require("RPGLootFeed_spec._mocks.WoWGlobals.namespaces.C_ClassColor")
				classColorMocks.GetClassColor:clear()
				RLF_RowBackdropMixin.StyleRowBackdrop(row)
				assert.stub(classColorMocks.GetClassColor).was.called_with("WARRIOR")
			end)

			it("calls SetBackdropBorderColor with the class-derived color", function()
				RLF_RowBackdropMixin.StyleRowBackdrop(row)
				assert.stub(row.SetBackdropBorderColor).was.called(1)
			end)
		end)

		describe("when a textured background is active", function()
			before_each(function()
				stub(ns.DbAccessor, "Styling").returns({
					enableRowBorder = false,
					rowBackgroundType = ns.RowBackground.TEXTURED,
					rowBorderTexture = "None",
					rowBorderSize = 0,
					rowBorderColor = { 1, 1, 1, 1 },
					rowBorderClassColors = false,
					rowBackgroundTexture = "Interface/Buttons/WHITE8X8",
					rowBackgroundTextureColor = { 0.5, 0.5, 0.5, 1 },
					backdropInsets = { top = 0, right = 0, bottom = 0, left = 0 },
				})
			end)

			it("calls SetBackdrop", function()
				RLF_RowBackdropMixin.StyleRowBackdrop(row)
				assert.stub(row.SetBackdrop).was.called(1)
			end)

			it("calls SetBackdropColor with the configured texture color", function()
				RLF_RowBackdropMixin.StyleRowBackdrop(row)
				assert.stub(row.SetBackdropColor).was.called(1)
			end)
		end)
	end)
end)
