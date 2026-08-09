local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local rowFrameMocks = require("RPGLootFeed_spec._mocks.Internal.LootDisplayRowFrame")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local stub = busted.stub

local MIXIN_FILE = "RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayRow/RowIconMixin.lua"

describe("RLF_RowIconMixin", function()
	local ns, row

	before_each(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		assert(loadfile(MIXIN_FILE))("TestAddon", ns)
		row = rowFrameMocks.new()
		-- Mix mixin methods into the row so self:Method() calls inside the
		-- mixin (UpdateIcon → ApplyQualityBorder/ClearQualityBorder) resolve.
		for k, v in pairs(RLF_RowIconMixin) do
			row[k] = v
		end
	end)

	describe("load order", function()
		it("loads the file and exposes the global mixin table", function()
			assert.is_not_nil(_G.RLF_RowIconMixin)
			assert.is_function(RLF_RowIconMixin.StyleIcon)
			assert.is_function(RLF_RowIconMixin.UpdateIcon)
		end)
	end)

	-- ── StyleIcon ──────────────────────────────────────────────────────────

	describe("StyleIcon", function()
		local sizingDb, stylingDb

		before_each(function()
			sizingDb = { iconSize = 32 }
			stylingDb = { textAlignment = "LEFT", iconSkin = ns.IconSkin.AUTO }
			stub(ns.DbAccessor, "Sizing").returns(sizingDb)
			stub(ns.DbAccessor, "Styling").returns(stylingDb)
		end)

		it("calls SetSize on first call", function()
			RLF_RowIconMixin.StyleIcon(row)
			assert.stub(row.Icon.SetSize).was.called(1)
		end)

		it("calls SetPoint on first call", function()
			RLF_RowIconMixin.StyleIcon(row)
			assert.stub(row.Icon.SetPoint).was.called(1)
		end)

		it("calls ClearAllPoints on first call", function()
			RLF_RowIconMixin.StyleIcon(row)
			assert.stub(row.Icon.ClearAllPoints).was.called(1)
		end)

		it("skips SetSize on a second call when nothing changed (cache hit)", function()
			RLF_RowIconMixin.StyleIcon(row)
			row.Icon.SetSize:clear()
			RLF_RowIconMixin.StyleIcon(row)
			assert.stub(row.Icon.SetSize).was_not.called()
		end)

		it("calls SetSize again when iconSize changes", function()
			RLF_RowIconMixin.StyleIcon(row)
			row.Icon.SetSize:clear()
			sizingDb.iconSize = 64
			RLF_RowIconMixin.StyleIcon(row)
			assert.stub(row.Icon.SetSize).was.called(1)
		end)

		it("calls SetSize again when textAlignment changes", function()
			RLF_RowIconMixin.StyleIcon(row)
			row.Icon.SetSize:clear()
			stylingDb.textAlignment = "RIGHT"
			RLF_RowIconMixin.StyleIcon(row)
			assert.stub(row.Icon.SetSize).was.called(1)
		end)

		it("calls PerfPixel.PScale to scale the icon size", function()
			RLF_RowIconMixin.StyleIcon(row)
			assert.stub(nsMocks.PerfPixel.PScale).was.called()
		end)

		it("shows the Icon when self.icon is set", function()
			local capturedArg
			stub(row.Icon, "SetShown", function(_, val)
				capturedArg = val
			end)
			row.icon = "Interface/Icons/INV_Misc_QuestionMark"
			RLF_RowIconMixin.StyleIcon(row)
			assert.is_true(capturedArg)
		end)

		it("hides the Icon when self.icon is nil", function()
			local capturedArg
			stub(row.Icon, "SetShown", function(_, val)
				capturedArg = val
			end)
			row.icon = nil
			RLF_RowIconMixin.StyleIcon(row)
			assert.is_false(capturedArg)
		end)

		it("adds Icon to Masque iconGroup when both are available", function()
			-- ns.iconGroup is not set by the namespace mock (Core.lua sets it at
			-- runtime via Masque:Group); wire it up here so StyleIcon can reach it.
			local called = false
			ns.iconGroup = {
				AddButton = function()
					called = true
				end,
			}
			RLF_RowIconMixin.StyleIcon(row)
			assert.is_true(called)
		end)

		it("does not add Icon to the Masque group when another skin is active", function()
			-- Masque is installed, but the user picked Square.  Group membership
			-- is sticky, so the button must never be enrolled.
			local called = false
			ns.iconGroup = {
				AddButton = function()
					called = true
				end,
			}
			stylingDb.iconSkin = ns.IconSkin.SQUARE
			RLF_RowIconMixin.StyleIcon(row)
			assert.is_false(called)
		end)

		it("re-runs the style pass when only the icon skin changed", function()
			ns.iconGroup = { AddButton = function() end }
			RLF_RowIconMixin.StyleIcon(row)
			row.Icon.SetSize:clear()
			stylingDb.iconSkin = ns.IconSkin.NONE
			RLF_RowIconMixin.StyleIcon(row)
			assert.stub(row.Icon.SetSize).was.called(1)
		end)
	end)

	-- ── UpdateIcon ─────────────────────────────────────────────────────────
	-- RunNextFrame executes synchronously in tests, so the deferred callback runs.

	describe("UpdateIcon", function()
		local stylingDb

		before_each(function()
			stylingDb = {
				enableTopLeftIconText = false,
				topLeftIconTextUseQualityColor = false,
				topLeftIconTextColor = { 1, 1, 1, 1 },
				iconSkin = ns.IconSkin.AUTO,
			}
			stub(ns.DbAccessor, "Sizing").returns({ iconSize = 32 })
			stub(ns.DbAccessor, "Styling").returns(stylingDb)
		end)

		it("stores the icon on self", function()
			RLF_RowIconMixin.UpdateIcon(row, "key1", "Interface/Icons/Foo", nil)
			assert.equal("Interface/Icons/Foo", row.icon)
		end)

		it("calls SetItemButtonTexture when quality is provided", function()
			row.link = "|Hitem:123|h[Foo]|h"
			RLF_RowIconMixin.UpdateIcon(row, "key1", "Interface/Icons/Foo", 4)
			assert.stub(row.Icon.SetItemButtonTexture).was.called(1)
		end)

		it("calls SetItem (no quality) when quality is nil", function()
			row.link = "|Hitem:123|h[Foo]|h"
			RLF_RowIconMixin.UpdateIcon(row, "key1", "Interface/Icons/Foo", nil)
			assert.stub(row.Icon.SetItem).was.called(1)
		end)

		it("hides topLeftText when enableTopLeftIconText is false", function()
			RLF_RowIconMixin.UpdateIcon(row, "key1", "Interface/Icons/Foo", 2)
			assert.stub(row.Icon.topLeftText.Hide).was.called(1)
		end)

		it("shows topLeftText when conditions are met", function()
			stylingDb.enableTopLeftIconText = true
			row.topLeftText = "x5"
			row.topLeftColor = { 1, 0.82, 0 }
			RLF_RowIconMixin.UpdateIcon(row, "key1", "Interface/Icons/Foo", 2)
			assert.stub(row.Icon.topLeftText.Show).was.called(1)
		end)

		-- ── Icon skin dispatch ─────────────────────────────────────────────
		-- Exactly one skinner may run per update.  Every case below installs
		-- all three third-party handles so the assertions prove the dispatch
		-- chose, rather than that only one was reachable.

		describe("icon skin dispatch", function()
			local masque, elvSkins, euiSkin

			local function update()
				RLF_RowIconMixin.UpdateIcon(row, "key1", "Interface/Icons/Foo", 2)
			end

			local function assertOnly(skinner)
				assert.stub(masque.ReSkin).was.called(skinner == "masque" and 1 or 0)
				assert.stub(elvSkins.HandleItemButton).was.called(skinner == "elvui" and 1 or 0)
				assert.stub(elvSkins.HandleIconBorder).was.called(skinner == "elvui" and 1 or 0)
				assert.stub(euiSkin.SquareIcon).was.called(skinner == "ellesmere" and 1 or 0)
				assert.stub(row.Icon.icon.SetTexCoord).was.called(skinner == "square" and 1 or 0)
			end

			before_each(function()
				masque = { ReSkin = function() end, AddButton = function() end }
				stub(masque, "ReSkin")
				elvSkins = { HandleItemButton = function() end, HandleIconBorder = function() end }
				stub(elvSkins, "HandleItemButton")
				stub(elvSkins, "HandleIconBorder")
				euiSkin = { SquareIcon = function() end }
				stub(euiSkin, "SquareIcon")
				ns.iconGroup = masque
				ns.ElvSkins = elvSkins
				ns.EllesmereUI = {}
				ns.EUISkin = euiSkin
			end)

			it("uses Masque for AUTO when Masque is loaded", function()
				update()
				assertOnly("masque")
			end)

			it("uses only ElvUI when ElvUI is chosen explicitly", function()
				stylingDb.iconSkin = ns.IconSkin.ELVUI
				update()
				assertOnly("elvui")
			end)

			it("uses only Masque when Masque is chosen explicitly", function()
				stylingDb.iconSkin = ns.IconSkin.MASQUE
				update()
				assertOnly("masque")
			end)

			it("crops the icon texture for SQUARE and skins nothing else", function()
				stylingDb.iconSkin = ns.IconSkin.SQUARE
				update()
				assertOnly("square")
				assert.stub(row.Icon.icon.SetTexCoord).was.called_with(row.Icon.icon, 0.08, 0.92, 0.08, 0.92)
			end)

			it("uses only EllesmereUI when it is chosen explicitly", function()
				stylingDb.iconSkin = ns.IconSkin.ELLESMERE
				update()
				assertOnly("ellesmere")
				-- Dot call: the facade is a plain table of functions, so the
				-- icon texture is the first argument, not a self.  No parent
				-- argument: that would make EUI draw its own quality-blind
				-- black border underneath ours.
				assert.stub(euiSkin.SquareIcon).was.called_with(row.Icon.icon)
			end)

			it("falls back to our own Square when the EllesmereUI facade never arrived", function()
				-- Registration is queued until PLAYER_LOGIN, and skipped
				-- entirely when the user disables third-party skinning in
				-- EllesmereUI's options.  Resolve stands SQUARE in, which
				-- applies the same crop EllesmereUI would have.
				ns.EUISkin = nil
				stylingDb.iconSkin = ns.IconSkin.ELLESMERE
				update()
				assert.stub(masque.ReSkin).was_not.called()
				assert.stub(elvSkins.HandleItemButton).was_not.called()
				assert.stub(row.Icon.icon.SetTexCoord).was.called_with(row.Icon.icon, 0.08, 0.92, 0.08, 0.92)
			end)

			it("skins nothing for NONE", function()
				stylingDb.iconSkin = ns.IconSkin.NONE
				update()
				assertOnly("none")
			end)

			it("skins nothing when the chosen skinner is not loaded", function()
				ns.ElvSkins = nil
				stylingDb.iconSkin = ns.IconSkin.ELVUI
				update()
				assert.stub(masque.ReSkin).was_not.called()
				assert.stub(row.Icon.icon.SetTexCoord).was_not.called()
			end)

			it("undoes its own crop when Square is turned off", function()
				-- Rows are pooled and SetTexture does not reset texcoords, so
				-- the crop would otherwise outlive the setting.
				stylingDb.iconSkin = ns.IconSkin.SQUARE
				update()
				row.Icon.icon.SetTexCoord:clear()
				stylingDb.iconSkin = ns.IconSkin.NONE
				update()
				assert.stub(row.Icon.icon.SetTexCoord).was.called_with(row.Icon.icon, 0, 1, 0, 1)
			end)

			it("undoes its own crop only once", function()
				stylingDb.iconSkin = ns.IconSkin.SQUARE
				update()
				stylingDb.iconSkin = ns.IconSkin.NONE
				update()
				row.Icon.icon.SetTexCoord:clear()
				update()
				assert.stub(row.Icon.icon.SetTexCoord).was_not.called()
			end)

			it("does not touch texcoords it never set", function()
				-- Masque and ElvUI manage their own cropping; a row that was
				-- never squared must be left alone.
				stylingDb.iconSkin = ns.IconSkin.ELVUI
				update()
				assert.stub(row.Icon.icon.SetTexCoord).was_not.called()
			end)

			it("leaves a masked icon alone under SQUARE", function()
				-- SetTexCoord on a masked texture is a hard Lua error in-game.
				row.Icon.icon.GetNumMaskTextures = function()
					return 1
				end
				stylingDb.iconSkin = ns.IconSkin.SQUARE
				update()
				assert.stub(row.Icon.icon.SetTexCoord).was_not.called()
			end)

			-- ── Square quality border ──────────────────────────────────────
			-- Blizzard's IconBorder is the rounded WhiteIconFrame; the squaring
			-- skins swap it for four 1px edges tinted with the quality color.

			describe("square quality border", function()
				local edges

				local function assertEdgesShown(times)
					for _, edge in ipairs(edges) do
						assert.stub(edge.Show).was.called(times)
					end
				end

				before_each(function()
					edges = {
						row.Icon.SquareBorderTop,
						row.Icon.SquareBorderRight,
						row.Icon.SquareBorderBottom,
						row.Icon.SquareBorderLeft,
					}
					-- Blizzard shows IconBorder and writes the quality color onto
					-- it inside SetItemButtonQuality, which runs before the skinner.
					row.Icon.IconBorder.IsShown.returns(true)
					row.Icon.IconBorder.GetVertexColor.returns(0.64, 0.21, 0.93, 1)
				end)

				it("hides IconBorder and tints the edges for SQUARE", function()
					stylingDb.iconSkin = ns.IconSkin.SQUARE
					update()
					assert.stub(row.Icon.IconBorder.Hide).was.called(1)
					assertEdgesShown(1)
					for _, edge in ipairs(edges) do
						assert.stub(edge.SetColorTexture).was.called_with(edge, 0.64, 0.21, 0.93, 1)
					end
				end)

				it("hides IconBorder and tints the edges for ELLESMERE", function()
					stylingDb.iconSkin = ns.IconSkin.ELLESMERE
					update()
					assert.stub(row.Icon.IconBorder.Hide).was.called(1)
					assertEdgesShown(1)
				end)

				it("draws no border when Blizzard drew none (quality-less item)", function()
					row.Icon.IconBorder.IsShown.returns(false)
					stylingDb.iconSkin = ns.IconSkin.SQUARE
					update()
					assert.stub(row.Icon.IconBorder.Hide).was_not.called()
					assertEdgesShown(0)
				end)

				it("leaves the border alone for skins that own it", function()
					-- ElvUI's HandleIconBorder and Masque both manage the border.
					stylingDb.iconSkin = ns.IconSkin.ELVUI
					update()
					assert.stub(row.Icon.IconBorder.Hide).was_not.called()
					assertEdgesShown(0)
				end)

				it("hides its edges when a squaring skin is turned off", function()
					-- Rows are pooled, so the swap has to be reversible.
					stylingDb.iconSkin = ns.IconSkin.SQUARE
					update()
					stylingDb.iconSkin = ns.IconSkin.NONE
					update()
					for _, edge in ipairs(edges) do
						assert.stub(edge.Hide).was.called(1)
					end
				end)

				it("leaves IconBorder's visibility to Blizzard on an update pass", function()
					-- SetItemButtonQuality has already set it from the new item's
					-- quality by the time we run; re-showing here would resurrect
					-- the previous item's border color on a quality-less item.
					stylingDb.iconSkin = ns.IconSkin.SQUARE
					update()
					stylingDb.iconSkin = ns.IconSkin.NONE
					update()
					assert.stub(row.Icon.IconBorder.Show).was_not.called()
				end)

				it("hands IconBorder back when StyleIcon sees the skin change", function()
					-- A live skin change reaches an on-screen row through
					-- StyleIcon, which has not re-run SetItemButtonQuality.
					stylingDb.iconSkin = ns.IconSkin.SQUARE
					update()
					stylingDb.textAlignment = "LEFT"
					stylingDb.iconSkin = ns.IconSkin.NONE
					RLF_RowIconMixin.StyleIcon(row)
					assert.stub(row.Icon.IconBorder.Show).was.called(1)
				end)

				it("does not resurrect a stale border color on a pooled row", function()
					-- Epic item swapped for a quality-less one on the same row:
					-- Blizzard hides IconBorder, so there is nothing to restore.
					stylingDb.iconSkin = ns.IconSkin.SQUARE
					update()
					row.Icon.IconBorder.IsShown.returns(false)
					update()
					stylingDb.iconSkin = ns.IconSkin.NONE
					RLF_RowIconMixin.StyleIcon(row)
					assert.stub(row.Icon.IconBorder.Show).was_not.called()
				end)

				it("still borders the icon when ELLESMERE falls back to Square", function()
					ns.EUISkin = nil
					stylingDb.iconSkin = ns.IconSkin.ELLESMERE
					update()
					assert.stub(row.Icon.IconBorder.Hide).was.called(1)
					assertEdgesShown(1)
				end)

				it("draws no border around a masked icon under SQUARE", function()
					row.Icon.icon.GetNumMaskTextures = function()
						return 1
					end
					stylingDb.iconSkin = ns.IconSkin.SQUARE
					update()
					assert.stub(row.Icon.IconBorder.Hide).was_not.called()
					assertEdgesShown(0)
				end)
			end)
		end)
	end)

	-- ── StyleIcon border sizing ────────────────────────────────────────────

	describe("StyleIcon square border sizing", function()
		before_each(function()
			stub(ns.DbAccessor, "Sizing").returns({ iconSize = 32 })
			stub(ns.DbAccessor, "Styling").returns({ textAlignment = "LEFT", iconSkin = ns.IconSkin.NONE })
		end)

		it("scales the border edges to one physical pixel", function()
			RLF_RowIconMixin.StyleIcon(row)
			assert.stub(row.Icon.SquareBorderTop.SetHeight).was.called(1)
			assert.stub(row.Icon.SquareBorderBottom.SetHeight).was.called(1)
			assert.stub(row.Icon.SquareBorderLeft.SetWidth).was.called(1)
			assert.stub(row.Icon.SquareBorderRight.SetWidth).was.called(1)
		end)
	end)
end)
