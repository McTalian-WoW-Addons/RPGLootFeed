local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local setup = busted.setup
local describe = busted.describe
local it = busted.it

describe("Enums", function()
	local ns

	setup(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.UtilsList)
		assert(loadfile("RPGLootFeed/utils/Enums.lua"))("TestAddon", ns)
	end)

	it("defines Expansion enum", function()
		assert.is_not_nil(ns.Expansion)
	end)

	it("defines DisableBossBanner enum", function()
		assert.is_not_nil(ns.DisableBossBanner)
	end)

	it("defines FontFlags enum", function()
		assert.is_not_nil(ns.FontFlags)
	end)

	it("includes the SLUG font flag", function()
		assert.are.equal("SLUG", ns.FontFlags.SLUG)
	end)

	it("defines ItemQualEnum enum", function()
		assert.is_not_nil(ns.ItemQualEnum)
	end)

	it("defines LogEventSource enum", function()
		assert.is_not_nil(ns.LogEventSource)
	end)

	it("defines LogLevel enum", function()
		assert.is_not_nil(ns.LogLevel)
	end)

	it("defines FeatureModule enum", function()
		assert.is_not_nil(ns.FeatureModule)
	end)

	it("defines PricesEnum enum", function()
		assert.is_not_nil(ns.PricesEnum)
	end)

	it("defines EnterAnimationType enum", function()
		assert.is_not_nil(ns.EnterAnimationType)
	end)

	it("defines ExitAnimationType enum", function()
		assert.is_not_nil(ns.ExitAnimationType)
	end)

	it("defines SlideDirection enum", function()
		assert.is_not_nil(ns.SlideDirection)
	end)

	it("defines WrapCharEnum enum", function()
		assert.is_not_nil(ns.WrapCharEnum)
	end)

	it("defines GameSounds enum", function()
		assert.is_not_nil(ns.GameSounds)
	end)

	it("defines DefaultIcons enum", function()
		assert.is_not_nil(ns.DefaultIcons)
	end)

	it("defines Frames enum", function()
		assert.is_not_nil(ns.Frames)
	end)

	it("defines TertiaryStats enum", function()
		assert.is_not_nil(ns.TertiaryStats)
	end)

	describe("DefaultIcons.REPUTATION", function()
		-- 236681 (achievement_reputation_01, the handshake icon) predates achievements and is
		-- absent from TBC Anniversary, which renders a missing texture as a solid green square.
		-- 135026 (the guild tabard) ships on every flavor, including TBC Anniversary.
		it("uses the handshake icon on flavors other than TBC Classic", function()
			local repNs = nsMocks:unitLoadedAfter(nsMocks.LoadSections.UtilsList)
			repNs.IsTBCClassic = function()
				return false
			end
			assert(loadfile("RPGLootFeed/utils/Enums.lua"))("TestAddon", repNs)
			assert.are.equal(236681, repNs.DefaultIcons.REPUTATION)
		end)

		it("uses the guild tabard icon on TBC Classic", function()
			local repNs = nsMocks:unitLoadedAfter(nsMocks.LoadSections.UtilsList)
			repNs.IsTBCClassic = function()
				return true
			end
			assert(loadfile("RPGLootFeed/utils/Enums.lua"))("TestAddon", repNs)
			assert.are.equal(135026, repNs.DefaultIcons.REPUTATION)
		end)
	end)
end)
