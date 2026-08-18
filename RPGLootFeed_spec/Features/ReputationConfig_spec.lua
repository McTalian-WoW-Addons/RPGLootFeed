local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local before_each = busted.before_each

describe("ReputationConfig module", function()
	local ns

	-- Defaults ported from RPGLootFeed/config/ConfigOptions.lua's
	-- frames["**"].features.reputation block.
	local function reputationDefaults()
		return {
			enabled = true,
			backgroundOverride = {
				enabled = false,
				gradientStart = { 0.1, 0.1, 0.1, 0.8 },
				gradientEnd = { 0.1, 0.1, 0.1, 0 },
				textureColor = { 0, 0, 0, 1 },
			},
			defaultRepColor = { 0.5, 0.5, 1 },
			secondaryTextAlpha = 0.7,
			enableRepLevel = true,
			repLevelColor = { 0.5, 0.5, 1, 1 },
			repLevelTextWrapChar = 5, -- WrapCharEnum.ANGLE
			enableIcon = true,
		}
	end

	before_each(function()
		-- Minimal namespace: only what ReputationConfig.lua and common.lua touch.
		ns = {
			L = setmetatable({}, {
				__index = function(_, key)
					return key
				end,
			}),
			WrapCharEnum = { BRACKET = 3, ANGLE = 5 },
			WrapCharOptions = { [3] = "Bracket", [5] = "Angle" },
			DbAccessor = {
				UpdateFeatureModuleState = function() end,
				Feature = function()
					return nil
				end,
			},
			LootDisplay = {
				RefreshSampleRowsIfShown = function() end,
			},
			db = {
				global = {
					frames = { [1] = { features = { reputation = reputationDefaults() } } },
					misc = { hideAllIcons = false },
				},
			},
		}

		-- FeatureBase mock mirrors the real G_RLF[moduleName] = module wiring
		-- (RPGLootFeed/Features/_Internals/FeatureBase.lua) so that
		-- `function G_RLF.Reputation:BuildConfigArgs(...)` in ReputationConfig.lua
		-- has a real target to attach to -- the same production call path used
		-- when the feature module and its co-located Config.lua load together.
		ns.FeatureBase = {
			new = function(_, name)
				local module = { moduleName = name }
				ns[name] = module
				return module
			end,
		}
		ns.FeatureBase:new("Reputation")

		-- Real ConfigCommon -- CreateFeatureBackgroundOverrideGroup et al.
		assert(loadfile("RPGLootFeed/config/common/common.lua"))("TestAddon", ns)

		-- Load the ReputationConfig module under test.
		assert(loadfile("RPGLootFeed/Features/Reputation/ReputationConfig.lua"))("TestAddon", ns)
	end)

	it("should set up the reputation configuration defaults", function()
		local defaults = reputationDefaults()
		assert.is_table(defaults)
		assert.is_boolean(defaults.enabled)
		assert.is_table(defaults.defaultRepColor)
		assert.is_number(defaults.secondaryTextAlpha)
		assert.is_boolean(defaults.enableRepLevel)
		assert.is_table(defaults.repLevelColor)
		assert.is_not_nil(defaults.repLevelTextWrapChar)
	end)

	it("should export a BuildConfigArgs builder function on G_RLF.Reputation", function()
		assert.is_function(ns.Reputation.BuildConfigArgs)
	end)

	it("should return a valid options group from BuildConfigArgs", function()
		local group = ns.Reputation:BuildConfigArgs(1, 6)
		assert.is_table(group)
		assert.equal("group", group.type)
		assert.equal(6, group.order)
		assert.is_table(group.args)
		assert.is_not_nil(group.args.enableRep)
		assert.is_not_nil(group.args.repOptions)
	end)

	it("should have correct color defaults for reputation text", function()
		local repColor = reputationDefaults().defaultRepColor
		assert.is_table(repColor)
		assert.equal(0.5, repColor[1])
		assert.equal(0.5, repColor[2])
		assert.equal(1, repColor[3])
	end)

	it("should have correct color defaults for reputation level text", function()
		local levelColor = reputationDefaults().repLevelColor
		assert.is_table(levelColor)
		assert.equal(0.5, levelColor[1])
		assert.equal(0.5, levelColor[2])
		assert.equal(1, levelColor[3])
		assert.equal(1, levelColor[4])
	end)

	it("should have correct secondary text alpha", function()
		assert.equal(0.7, reputationDefaults().secondaryTextAlpha)
	end)

	it("should use angle brackets as default wrap character for reputation level", function()
		assert.equal(ns.WrapCharEnum.ANGLE, reputationDefaults().repLevelTextWrapChar)
	end)

	it("enableRep toggle reads/writes through to the frame's feature config", function()
		local group = ns.Reputation:BuildConfigArgs(1, 6)
		assert.is_true(group.args.enableRep.get())
		group.args.enableRep.set(nil, false)
		assert.is_false(ns.db.global.frames[1].features.reputation.enabled)
	end)
end)
