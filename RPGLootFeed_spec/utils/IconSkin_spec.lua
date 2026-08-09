local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("IconSkin resolver", function()
	local ns, IconSkin, Skin

	--- Attach (or detach) the third-party handles the resolver inspects.
	--- Core.lua sets these at runtime; the namespace mock leaves them nil.
	---
	--- `ellesmere` models the normal case: the addon is loaded and it dispatched
	--- our RegisterSkin callback, so both handles exist.  `ellesmereSkinningOff`
	--- models the addon being loaded with third-party skinning disabled in its
	--- own options, where the facade never arrives.
	local function loaded(addons)
		ns.Masque = addons.masque and {} or nil
		ns.iconGroup = addons.masque and {} or nil
		ns.ElvSkins = addons.elvui and {} or nil
		ns.EllesmereUI = (addons.ellesmere or addons.ellesmereSkinningOff) and {} or nil
		ns.EUISkin = addons.ellesmere and {} or nil
	end

	before_each(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.UtilsEnums)
		IconSkin = assert(loadfile("RPGLootFeed/utils/IconSkin.lua"))("TestAddon", ns)
		Skin = ns.IconSkin
		loaded({})
	end)

	describe("load order", function()
		it("exposes the resolver on the namespace", function()
			assert.is_not_nil(ns.IconSkinResolver)
			assert.is_function(ns.IconSkinResolver.Resolve)
			assert.is_function(ns.IconSkinResolver.Available)
		end)
	end)

	describe("Available", function()
		it("always offers the built-in modes", function()
			local available = IconSkin:Available()
			assert.is_true(available[Skin.AUTO])
			assert.is_true(available[Skin.NONE])
			assert.is_true(available[Skin.SQUARE])
		end)

		it("reports third-party skinners as unavailable when nothing is loaded", function()
			local available = IconSkin:Available()
			assert.is_false(available[Skin.MASQUE])
			assert.is_false(available[Skin.ELVUI])
			assert.is_false(available[Skin.ELLESMERE])
		end)

		it("reports each third-party skinner once its handle is present", function()
			loaded({ masque = true, elvui = true, ellesmere = true })
			local available = IconSkin:Available()
			assert.is_true(available[Skin.MASQUE])
			assert.is_true(available[Skin.ELVUI])
			assert.is_true(available[Skin.ELLESMERE])
		end)

		it("does not report Masque when the group was never created", function()
			-- Masque present but Masque:Group() failed or has not run yet.
			loaded({ masque = true })
			ns.iconGroup = nil
			assert.is_false(IconSkin:Available()[Skin.MASQUE])
		end)

		it("keeps EllesmereUI selectable while its skinning is switched off", function()
			-- The user can flip EllesmereUI's own option back on; refusing the
			-- choice here would make them come back and re-pick it.
			loaded({ ellesmereSkinningOff = true })
			assert.is_true(IconSkin:Available()[Skin.ELLESMERE])
		end)
	end)

	describe("IsApplicable", function()
		it("reports EllesmereUI as inapplicable until its facade arrives", function()
			loaded({ ellesmereSkinningOff = true })
			assert.is_false(IconSkin:IsApplicable(Skin.ELLESMERE))
		end)

		it("reports EllesmereUI as applicable once its facade arrives", function()
			loaded({ ellesmere = true })
			assert.is_true(IconSkin:IsApplicable(Skin.ELLESMERE))
		end)

		it("tracks availability for every other skinner", function()
			loaded({ elvui = true })
			assert.is_true(IconSkin:IsApplicable(Skin.ELVUI))
			assert.is_true(IconSkin:IsApplicable(Skin.SQUARE))
			assert.is_false(IconSkin:IsApplicable(Skin.MASQUE))
		end)
	end)

	describe("Resolve with AUTO", function()
		it("falls back to NONE when nothing is loaded", function()
			assert.equal(Skin.NONE, IconSkin:Resolve(Skin.AUTO))
		end)

		it("treats a nil setting the same as AUTO", function()
			loaded({ elvui = true })
			assert.equal(Skin.ELVUI, IconSkin:Resolve(nil))
		end)

		it("prefers Masque over everything else", function()
			loaded({ masque = true, elvui = true, ellesmere = true })
			assert.equal(Skin.MASQUE, IconSkin:Resolve(Skin.AUTO))
		end)

		it("prefers ElvUI over EllesmereUI when Masque is absent", function()
			loaded({ elvui = true, ellesmere = true })
			assert.equal(Skin.ELVUI, IconSkin:Resolve(Skin.AUTO))
		end)

		it("picks EllesmereUI when it is the only one loaded", function()
			loaded({ ellesmere = true })
			assert.equal(Skin.ELLESMERE, IconSkin:Resolve(Skin.AUTO))
		end)

		it("falls back to SQUARE when EllesmereUI has its skinning switched off", function()
			-- SQUARE applies the identical crop EllesmereUI's SquareIcon would,
			-- so the user gets the look they installed EllesmereUI for instead
			-- of round icons and no explanation.
			loaded({ ellesmereSkinningOff = true })
			assert.equal(Skin.SQUARE, IconSkin:Resolve(Skin.AUTO))
		end)

		it("still prefers a working skinner over the EllesmereUI stand-in", function()
			loaded({ elvui = true, ellesmereSkinningOff = true })
			assert.equal(Skin.ELVUI, IconSkin:Resolve(Skin.AUTO))
		end)

		it("picks Masque when it is the only one loaded", function()
			loaded({ masque = true })
			assert.equal(Skin.MASQUE, IconSkin:Resolve(Skin.AUTO))
		end)

		it("never returns AUTO", function()
			for _, combo in ipairs({
				{},
				{ masque = true },
				{ elvui = true },
				{ ellesmere = true },
				{ masque = true, elvui = true, ellesmere = true },
			}) do
				loaded(combo)
				assert.are_not.equal(Skin.AUTO, IconSkin:Resolve(Skin.AUTO))
			end
		end)
	end)

	describe("Resolve with an explicit value", function()
		it("honors a built-in mode regardless of what is loaded", function()
			loaded({ masque = true, elvui = true })
			assert.equal(Skin.SQUARE, IconSkin:Resolve(Skin.SQUARE))
			assert.equal(Skin.NONE, IconSkin:Resolve(Skin.NONE))
		end)

		it("honors an available skinner over the AUTO precedence", function()
			loaded({ masque = true, elvui = true, ellesmere = true })
			assert.equal(Skin.ELVUI, IconSkin:Resolve(Skin.ELVUI))
			assert.equal(Skin.ELLESMERE, IconSkin:Resolve(Skin.ELLESMERE))
		end)

		it("falls back to NONE when the chosen skinner is not loaded", function()
			assert.equal(Skin.NONE, IconSkin:Resolve(Skin.ELVUI))
			assert.equal(Skin.NONE, IconSkin:Resolve(Skin.MASQUE))
			assert.equal(Skin.NONE, IconSkin:Resolve(Skin.ELLESMERE))
		end)

		it("does not silently substitute a different skinner", function()
			-- ElvUI was saved but is gone; Masque is loaded.  The user asked for
			-- ElvUI, so they get no skinning rather than a surprise.
			loaded({ masque = true })
			assert.equal(Skin.NONE, IconSkin:Resolve(Skin.ELVUI))
		end)

		it("falls back to SQUARE for an explicit EllesmereUI with its skinning off", function()
			loaded({ ellesmereSkinningOff = true })
			assert.equal(Skin.SQUARE, IconSkin:Resolve(Skin.ELLESMERE))
		end)

		it("falls back to NONE for EllesmereUI when the addon is gone entirely", function()
			-- Uninstalled degrades like every other skinner; only the
			-- installed-but-inert case gets the SQUARE stand-in.
			loaded({})
			assert.equal(Skin.NONE, IconSkin:Resolve(Skin.ELLESMERE))
		end)

		it("falls back to NONE for an unrecognized value", function()
			assert.equal(Skin.NONE, IconSkin:Resolve("SOMETHING_ELSE"))
		end)
	end)
end)
