local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local spy = require("luassert.spy")

describe("DbAccessors module", function()
	local ns, DbAccessor, mockDb

	before_each(function()
		-- Setup the namespace and mock database
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)

		-- Create mock database structure
		mockDb = {
			global = {
				frames = {
					[1] = {
						sizing = { mockFrameMainSizing = true },
						positioning = { mockFrameMainPositioning = true },
						styling = { mockFrameMainStyling = true },
						animations = { mockFrameMainAnimations = true },
					},
					[2] = {
						sizing = { mockFramePartySizing = true },
						positioning = { mockFramePartyPositioning = true },
						styling = { mockFramePartyStyling = true },
						animations = { mockFramePartyAnimations = true },
					},
				},
			},
		}

		-- Attach mock db to namespace
		ns.db = mockDb
		mockDb.global.interactions = { disableAllInteraction = false }

		-- Define frame types
		ns.Frames = {
			MAIN = 1,
		}

		-- Load the module being tested
		assert(loadfile("RPGLootFeed/config/DbAccessors.lua"))("TestAddon", ns)
		DbAccessor = ns.DbAccessor
	end)

	describe("Interactions", function()
		before_each(function()
			mockDb.global.interactions = {
				disableAllInteraction = false,
				itemClicks = true,
				rightClickDismiss = true,
				pinOnHover = true,
				rollButtons = true,
			}
			mockDb.global.tooltips = { hover = { enabled = true } }
			mockDb.global.frames[1].interactions = { override = true, tooltips = true, rollButtons = false }
			mockDb.global.frames[2].interactions = { override = false, tooltips = false }
		end)

		it("returns per-frame interactions", function()
			assert.is_false(DbAccessor:Interactions(1).rollButtons)
		end)

		it("an overriding frame uses its own toggles", function()
			assert.is_true(DbAccessor:InteractionAllowed(1, "tooltips"))
			assert.is_false(DbAccessor:InteractionAllowed(1, "rollButtons"))
		end)

		it("an overriding frame treats a missing toggle as allowed", function()
			assert.is_true(DbAccessor:InteractionAllowed(1, "itemClicks"))
		end)

		it("an overriding frame beats disableAllInteraction", function()
			mockDb.global.interactions.disableAllInteraction = true
			assert.is_true(DbAccessor:InteractionAllowed(1, "tooltips"))
		end)

		it("a non-overriding frame follows the global settings", function()
			assert.is_true(DbAccessor:InteractionAllowed(2, "tooltips"))
			mockDb.global.tooltips.hover.enabled = false
			assert.is_false(DbAccessor:InteractionAllowed(2, "tooltips"))
			mockDb.global.interactions.rollButtons = false
			assert.is_false(DbAccessor:InteractionAllowed(2, "rollButtons"))
		end)

		it("a non-overriding frame is fully disabled by disableAllInteraction", function()
			mockDb.global.interactions.disableAllInteraction = true
			assert.is_false(DbAccessor:InteractionAllowed(2, "tooltips"))
			assert.is_false(DbAccessor:InteractionAllowed(2, "pinOnHover"))
		end)

		it("a missing frame follows the global settings", function()
			assert.is_true(DbAccessor:InteractionAllowed(99, "itemClicks"))
			mockDb.global.interactions.itemClicks = false
			assert.is_false(DbAccessor:InteractionAllowed(99, "itemClicks"))
		end)
	end)

	describe("Sizing", function()
		it("returns per-frame sizing for frame 2", function()
			local result = DbAccessor:Sizing(2)
			assert.is_true(result.mockFramePartySizing)
		end)

		it("returns per-frame sizing for the main frame", function()
			local result = DbAccessor:Sizing(ns.Frames.MAIN)
			assert.is_true(result.mockFrameMainSizing)
		end)
	end)

	describe("Positioning", function()
		it("returns per-frame positioning for frame 2", function()
			local result = DbAccessor:Positioning(2)
			assert.is_true(result.mockFramePartyPositioning)
		end)

		it("returns per-frame positioning for the main frame", function()
			local result = DbAccessor:Positioning(ns.Frames.MAIN)
			assert.is_true(result.mockFrameMainPositioning)
		end)
	end)

	describe("Styling", function()
		it("returns per-frame styling for frame 2", function()
			local result = DbAccessor:Styling(2)
			assert.is_true(result.mockFramePartyStyling)
		end)

		it("returns per-frame styling for the main frame", function()
			local result = DbAccessor:Styling(ns.Frames.MAIN)
			assert.is_true(result.mockFrameMainStyling)
		end)
	end)

	describe("Animations", function()
		it("returns per-frame animations for frame 1", function()
			local result = DbAccessor:Animations(1)
			assert.is_true(result.mockFrameMainAnimations)
		end)

		it("returns per-frame animations for frame 2", function()
			local result = DbAccessor:Animations(2)
			assert.is_true(result.mockFramePartyAnimations)
		end)
	end)
end)
