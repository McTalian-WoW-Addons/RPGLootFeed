local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local setup = busted.setup

-- Feature defaults (ns.defaults.global.frames["**"].features.currency) are
-- already covered end-to-end by RPGLootFeed_spec/config/ConfigOptions_spec.lua.
-- This spec covers what that one can't: that Currency.BuildConfigArgs (the
-- options-panel builder, moved from a standalone G_RLF.BuildCurrencyArgs
-- function to a method on the Currency module during the Features/ co-location
-- refactor) still returns a valid AceConfig options group when invoked the
-- way FeatureRegistry actually calls it: featureModule:BuildConfigArgs(frameId, order).
describe("CurrencyConfig module", function()
	local ns

	setup(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.ConfigFeaturePartyLoot)
		assert(loadfile("RPGLootFeed/config/common/common.lua"))("TestAddon", ns)

		-- In production, Currency.lua runs before CurrencyConfig.lua (see
		-- Features/Currency/Currency.xml) and G_RLF.FeatureBase:new() sets
		-- G_RLF.Currency to the module table as a side effect. CurrencyConfig.lua
		-- then attaches BuildConfigArgs as a method on that same table. Recreate
		-- just that hand-off here so the config file loads exactly as it does
		-- in-game, without dragging in all of Currency.lua's runtime DI.
		ns.Currency = { moduleName = "Currency" }
		assert(loadfile("RPGLootFeed/Features/Currency/CurrencyConfig.lua"))("TestAddon", ns)
	end)

	it("should export BuildConfigArgs as a method on the Currency module", function()
		assert.is_function(ns.Currency.BuildConfigArgs)
	end)

	it("should return a valid options group from BuildConfigArgs", function()
		ns.db = {
			global = {
				frames = { [1] = { features = { currency = ns.defaults.global.frames["**"].features.currency } } },
			},
		}
		local group = ns.Currency:BuildConfigArgs(1, 7)
		assert.is_table(group)
		assert.equal("group", group.type)
		assert.equal(7, group.order)
		assert.is_table(group.args)
		assert.is_table(group.args.enableCurrency)
		assert.equal("toggle", group.args.enableCurrency.type)
		assert.is_table(group.args.currencyOptions)
		assert.is_table(group.args.currencyOptions.args.totalTextOptions)
		assert.is_table(group.args.currencyOptions.args.currencyDenyList)
	end)
end)
