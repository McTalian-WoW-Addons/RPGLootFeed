local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local setup = busted.setup

-- Feature defaults (ns.defaults.global.frames["**"].features.experience) are
-- already covered end-to-end by RPGLootFeed_spec/config/ConfigOptions_spec.lua.
-- This spec covers what that one can't: that Experience.BuildConfigArgs (the
-- options-panel builder, moved from a standalone G_RLF.BuildExperienceArgs
-- function to a method on the Experience module during the Features/
-- co-location refactor) still returns a valid AceConfig options group when
-- invoked the way FeatureRegistry actually calls it:
-- featureModule:BuildConfigArgs(frameId, order).
describe("ExperienceConfig module", function()
	local ns

	setup(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.ConfigFeaturePartyLoot)
		assert(loadfile("RPGLootFeed/config/common/common.lua"))("TestAddon", ns)

		-- In production, Experience.lua runs before ExperienceConfig.lua (see
		-- Features/Experience/Experience.xml) and G_RLF.FeatureBase:new() sets
		-- G_RLF.Experience to the module table as a side effect. ExperienceConfig.lua
		-- then attaches BuildConfigArgs as a method on that same table. Recreate
		-- just that hand-off here so the config file loads exactly as it does
		-- in-game, without dragging in all of Experience.lua's runtime DI.
		ns.Experience = { moduleName = "Experience" }
		assert(loadfile("RPGLootFeed/Features/Experience/ExperienceConfig.lua"))("TestAddon", ns)
	end)

	it("should export BuildConfigArgs as a method on the Experience module", function()
		assert.is_function(ns.Experience.BuildConfigArgs)
	end)

	it("should return a valid options group from BuildConfigArgs", function()
		ns.db = {
			global = {
				frames = { [1] = { features = { experience = ns.defaults.global.frames["**"].features.experience } } },
			},
		}
		local group = ns.Experience:BuildConfigArgs(1, 5)
		assert.is_table(group)
		assert.equal("group", group.type)
		assert.equal(5, group.order)
		assert.is_table(group.args)
		assert.is_table(group.args.enableXp)
		assert.equal("toggle", group.args.enableXp.type)
		assert.is_table(group.args.xpOptions)
		assert.is_table(group.args.xpOptions.args.currentLevelOptions)
	end)
end)
