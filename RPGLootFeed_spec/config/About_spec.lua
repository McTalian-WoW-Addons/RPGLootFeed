local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("About module", function()
	local ns
	before_each(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		assert(loadfile("RPGLootFeed/config/About.lua"))("TestAddon", ns)
	end)

	it("lists attributions between the author links and the translation credits", function()
		local args = ns.options.args.about.args
		assert.are.equal("header", args.attributionsHeader.type)
		assert.are.equal("description", args.attributions.type)
		assert.is_true(args.tipsLink.order < args.attributionsHeader.order)
		assert.is_true(args.attributionsHeader.order < args.attributions.order)
		assert.is_true(args.attributions.order < args.credits.order)
	end)

	it("credits Twemoji under CC-BY 4.0", function()
		local text = ns.options.args.about.args.attributions.name
		assert.is_truthy(text:find("Twemoji", 1, true))
		assert.is_truthy(text:find("CC-BY 4.0", 1, true))
	end)
end)
