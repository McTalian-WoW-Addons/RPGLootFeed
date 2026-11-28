local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local setup = busted.setup
local before_each = busted.before_each

-- Feature defaults (ns.defaults.global.frames["**"].features.partyLoot) are
-- already covered end-to-end by RPGLootFeed_spec/config/ConfigOptions_spec.lua.
-- This spec covers what that one can't: that PartyLoot.BuildConfigArgs (the
-- options-panel builder, moved from a standalone G_RLF.BuildPartyLootArgs
-- function to a method on the PartyLoot module during the Features/
-- co-location refactor) still returns a valid AceConfig options group when
-- invoked the way FeatureRegistry actually calls it:
-- featureModule:BuildConfigArgs(frameId, order).
describe("PartyLootConfig module", function()
	local ns

	setup(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.ConfigFeaturePartyLoot)
		assert(loadfile("RPGLootFeed/config/common/common.lua"))("TestAddon", ns)

		-- In production, PartyLoot.lua runs before PartyLootConfig.lua (see
		-- Features/PartyLoot/PartyLoot.xml) and G_RLF.FeatureBase:new() sets
		-- G_RLF.PartyLoot to the module table as a side effect. PartyLootConfig.lua
		-- then attaches BuildConfigArgs as a method on that same table. Recreate
		-- just that hand-off here so the config file loads exactly as it does
		-- in-game, without dragging in all of PartyLoot.lua's runtime DI.
		ns.PartyLoot = { moduleName = "PartyLoot" }
		assert(loadfile("RPGLootFeed/Features/PartyLoot/PartyLootConfig.lua"))("TestAddon", ns)
	end)

	it("should export BuildConfigArgs as a method on the PartyLoot module", function()
		assert.is_function(ns.PartyLoot.BuildConfigArgs)
	end)

	it("should return a valid options group from BuildConfigArgs", function()
		local partyLootDefaults = ns.defaults.global.frames["**"].features.partyLoot
		ns.db = { global = { frames = { [1] = { features = { partyLoot = partyLootDefaults } } } } }
		local group = ns.PartyLoot:BuildConfigArgs(1, 3)
		assert.is_table(group)
		assert.equal("group", group.type)
		assert.equal(3, group.order)
		assert.is_table(group.args)
		assert.is_table(group.args.enablePartyLoot)
		assert.equal("toggle", group.args.enablePartyLoot.type)
		assert.is_table(group.args.partyLootOptions)
		assert.is_table(group.args.partyLootOptions.args.itemQualityFilter)
		-- Ensure no legacy separate frame option blocks
		assert.is_nil(group.args.partyLootOptions.args.positioning)
		assert.is_nil(group.args.partyLootOptions.args.sizing)
		assert.is_nil(group.args.partyLootOptions.args.styling)
	end)

	describe("always show crafting materials option (issue #431)", function()
		local option, partyCfg

		before_each(function()
			partyCfg = {}
			for k, v in pairs(ns.defaults.global.frames["**"].features.partyLoot) do
				partyCfg[k] = v
			end
			ns.db = { global = { frames = { [1] = { features = { partyLoot = partyCfg } } } } }
			option = ns.PartyLoot:BuildConfigArgs(1, 3).args.partyLootOptions.args.alwaysShowCraftingMaterials
		end)

		it("defaults to off", function()
			assert.is_false(ns.defaults.global.frames["**"].features.partyLoot.alwaysShowCraftingMaterials)
		end)

		it("is a toggle that reads and writes the setting", function()
			assert.is_table(option)
			assert.equal("toggle", option.type)
			assert.is_false(option.get())
			option.set(nil, true)
			assert.is_true(partyCfg.alwaysShowCraftingMaterials)
			assert.is_true(option.get())
		end)
	end)
end)
