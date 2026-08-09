local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local stub = busted.stub

describe("Styling module", function()
	local ns = {}
	local handler, stylingDb

	before_each(function()
		-- Define the global G_RLF
		-- Config (not ConfigFeaturesAll) is the first section that provides
		-- ns.DbAccessor, which every handler method reads through.
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.Config)
		assert(loadfile("RPGLootFeed/config/common/common.lua"))("TestAddon", ns)
		assert(loadfile("RPGLootFeed/config/common/db.utils.lua"))("TestAddon", ns)
		assert(loadfile("RPGLootFeed/config/common/styling.base.lua"))("TestAddon", ns)
		-- Load the list module before each test
		assert(loadfile("RPGLootFeed/config/Styling.lua"))("TestAddon", ns)

		-- LootDisplay only exists from LoadSections.LootDisplay onward; the
		-- setters here just need the refresh call to be reachable.
		ns.LootDisplay = { UpdateRowStyles = function() end }
		stub(ns.LootDisplay, "UpdateRowStyles")

		stylingDb = { iconSkin = ns.IconSkin.AUTO }
		stub(ns.DbAccessor, "Styling").returns(stylingDb)

		handler = ns.Styling.MakeHandler(ns.Frames.MAIN)
	end)

	describe("GetIconSkin", function()
		it("reads the value straight from the frame's styling DB", function()
			stylingDb.iconSkin = ns.IconSkin.SQUARE
			assert.equal(ns.IconSkin.SQUARE, handler:GetIconSkin())
		end)
	end)

	describe("SetIconSkin", function()
		it("stores a built-in mode and refreshes the rows", function()
			handler:SetIconSkin(nil, ns.IconSkin.SQUARE)
			assert.equal(ns.IconSkin.SQUARE, stylingDb.iconSkin)
			assert.stub(ns.LootDisplay.UpdateRowStyles).was.called(1)
		end)

		it("stores a third-party skinner once its addon is loaded", function()
			ns.ElvSkins = {}
			handler:SetIconSkin(nil, ns.IconSkin.ELVUI)
			assert.equal(ns.IconSkin.ELVUI, stylingDb.iconSkin)
		end)

		it("accepts EllesmereUI on the addon being loaded, not on the facade", function()
			-- The facade only arrives at PLAYER_LOGIN, well after the user
			-- could open the options; gating the write on it would make the
			-- option unselectable during that window.
			ns.EllesmereUI = {}
			handler:SetIconSkin(nil, ns.IconSkin.ELLESMERE)
			assert.equal(ns.IconSkin.ELLESMERE, stylingDb.iconSkin)
		end)

		it("refuses a skinner whose addon is not loaded", function()
			-- The dropdown lists every skinner so the feature is discoverable,
			-- which means the write has to be refused here.
			handler:SetIconSkin(nil, ns.IconSkin.ELVUI)
			assert.equal(ns.IconSkin.AUTO, stylingDb.iconSkin)
		end)

		it("warns and skips the refresh when it refuses", function()
			handler:SetIconSkin(nil, ns.IconSkin.ELLESMERE)
			assert.stub(nsMocks.LogWarn).was.called(1)
			assert.stub(ns.LootDisplay.UpdateRowStyles).was_not.called()
		end)
	end)
end)
