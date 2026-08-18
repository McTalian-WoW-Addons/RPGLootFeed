local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local setup = busted.setup

-- Feature defaults (ns.defaults.global.frames["**"].features.itemLoot) are
-- already covered end-to-end by RPGLootFeed_spec/config/ConfigOptions_spec.lua.
-- This spec covers what that one can't: that ItemLoot.BuildConfigArgs (the
-- options-panel builder, moved from a standalone G_RLF.BuildItemLootArgs
-- function, defined in the old config/Features/ItemConfig.lua, to a method
-- on the ItemLoot module during the Features/ co-location refactor) still
-- returns a valid AceConfig options group when invoked the way
-- FeatureRegistry actually calls it: featureModule:BuildConfigArgs(frameId, order).
describe("ItemLootConfig module", function()
	local ns

	setup(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.ConfigFeaturePartyLoot)
		assert(loadfile("RPGLootFeed/config/common/common.lua"))("TestAddon", ns)

		-- ItemLootConfig.lua reads G_RLF.AuctionIntegrations lazily (inside
		-- values()/hidden() closures we don't invoke here), but declare it so
		-- the shape matches production in case future edits touch it eagerly.
		ns.AuctionIntegrations = { numActiveIntegrations = 0, activeIntegrations = {} }

		-- In production, ItemLoot.lua runs before ItemLootConfig.lua (see
		-- Features/ItemLoot/ItemLoot.xml) and G_RLF.FeatureBase:new() sets
		-- G_RLF.ItemLoot to the module table as a side effect. ItemLootConfig.lua
		-- then attaches BuildConfigArgs as a method on that same table. Recreate
		-- just that hand-off here so the config file loads exactly as it does
		-- in-game, without dragging in all of ItemLoot.lua's runtime DI.
		ns.ItemLoot = { moduleName = "ItemLoot" }
		assert(loadfile("RPGLootFeed/Features/ItemLoot/ItemLootConfig.lua"))("TestAddon", ns)
	end)

	it("should export BuildConfigArgs as a method on the ItemLoot module", function()
		assert.is_function(ns.ItemLoot.BuildConfigArgs)
	end)

	it("should return a valid options group from BuildConfigArgs", function()
		ns.db = {
			global = {
				frames = { [1] = { features = { itemLoot = ns.defaults.global.frames["**"].features.itemLoot } } },
				interactions = {},
			},
		}
		local group = ns.ItemLoot:BuildConfigArgs(1, 5)
		assert.is_table(group)
		assert.equal("group", group.type)
		assert.equal(5, group.order)
		assert.is_not_nil(group.name)
		assert.is_table(group.args)
		assert.is_table(group.args.enableItemLoot)
		assert.equal("toggle", group.args.enableItemLoot.type)
		assert.is_table(group.args.itemLootOptions)
		assert.is_table(group.args.itemLootOptions.args.itemQualityFilter)
		assert.is_table(group.args.itemLootOptions.args.itemHighlights)
		assert.is_table(group.args.itemLootOptions.args.itemSounds)
	end)

	it("should set up an enabled/duration toggle pair for every item quality", function()
		ns.db = {
			global = {
				frames = { [1] = { features = { itemLoot = ns.defaults.global.frames["**"].features.itemLoot } } },
				interactions = {},
			},
		}
		local group = ns.ItemLoot:BuildConfigArgs(1, 5)
		local qualityArgs = group.args.itemLootOptions.args.itemQualityFilter.args
		for _, key in ipairs({
			"poor",
			"common",
			"uncommon",
			"rare",
			"epic",
			"legendary",
			"artifact",
			"heirloom",
			"wowToken",
		}) do
			assert.is_table(qualityArgs[key .. "Enabled"], "missing " .. key .. "Enabled")
			assert.is_table(qualityArgs[key .. "Duration"], "missing " .. key .. "Duration")
		end
	end)
end)
