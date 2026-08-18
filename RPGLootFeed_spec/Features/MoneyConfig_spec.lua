local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local setup = busted.setup

-- Feature defaults (ns.defaults.global.frames["**"].features.money) are
-- already covered end-to-end by RPGLootFeed_spec/config/ConfigOptions_spec.lua.
-- This spec covers what that one can't: that Money.BuildConfigArgs (the
-- options-panel builder, moved from a standalone G_RLF.BuildMoneyArgs
-- function to a method on the Money module during the Features/ co-location
-- refactor) still returns a valid AceConfig options group when invoked the
-- way FeatureRegistry actually calls it: featureModule:BuildConfigArgs(frameId, order).
describe("MoneyConfig module", function()
	local ns

	setup(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.ConfigFeaturePartyLoot)
		assert(loadfile("RPGLootFeed/config/common/common.lua"))("TestAddon", ns)

		-- In production, Money.lua runs before MoneyConfig.lua (see
		-- Features/Money/Money.xml) and G_RLF.FeatureBase:new() sets
		-- G_RLF.Money to the module table as a side effect. MoneyConfig.lua
		-- then attaches BuildConfigArgs as a method on that same table. Recreate
		-- just that hand-off here so the config file loads exactly as it does
		-- in-game, without dragging in all of Money.lua's runtime DI.
		ns.Money = { moduleName = "Money" }
		assert(loadfile("RPGLootFeed/Features/Money/MoneyConfig.lua"))("TestAddon", ns)
	end)

	it("should export BuildConfigArgs as a method on the Money module", function()
		assert.is_function(ns.Money.BuildConfigArgs)
	end)

	it("should return a valid options group from BuildConfigArgs", function()
		ns.db = {
			global = { frames = { [1] = { features = { money = ns.defaults.global.frames["**"].features.money } } } },
		}
		local group = ns.Money:BuildConfigArgs(1, 4)
		assert.is_table(group)
		assert.equal("group", group.type)
		assert.equal(4, group.order)
		assert.is_table(group.args)
		assert.is_table(group.args.enableMoney)
		assert.equal("toggle", group.args.enableMoney.type)
		assert.is_table(group.args.moneyOptions)
		assert.is_table(group.args.moneyOptions.args.moneyTotalOptions)
		assert.is_table(group.args.moneyOptions.args.moneyLootSound)
	end)
end)
