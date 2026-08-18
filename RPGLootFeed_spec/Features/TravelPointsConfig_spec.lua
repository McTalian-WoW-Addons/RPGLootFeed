local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local before_each = busted.before_each

describe("TravelPointsConfig module", function()
	local ns

	-- Defaults ported from RPGLootFeed/config/ConfigOptions.lua's
	-- frames["**"].features.travelPoints block.
	local function travelPointsDefaults()
		return {
			enabled = true,
			backgroundOverride = {
				enabled = false,
				gradientStart = { 0.1, 0.1, 0.1, 0.8 },
				gradientEnd = { 0.1, 0.1, 0.1, 0 },
				textureColor = { 0, 0, 0, 1 },
			},
			textColor = { 1, 0.988, 0.498, 1 },
			enableIcon = true,
		}
	end

	before_each(function()
		-- Minimal namespace: only what TravelPointsConfig.lua and common.lua touch.
		ns = {
			L = setmetatable({}, {
				__index = function(_, key)
					return key
				end,
			}),
			IsRetail = function()
				return true
			end,
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
					frames = { [1] = { features = { travelPoints = travelPointsDefaults() } } },
					misc = { hideAllIcons = false },
				},
			},
		}

		-- FeatureBase mock mirrors the real G_RLF[moduleName] = module wiring
		-- (RPGLootFeed/Features/_Internals/FeatureBase.lua) so that
		-- `function G_RLF.TravelPoints:BuildConfigArgs(...)` in TravelPointsConfig.lua
		-- has a real target to attach to -- the same production call path used
		-- when the feature module and its co-located Config.lua load together.
		ns.FeatureBase = {
			new = function(_, name)
				local module = { moduleName = name }
				ns[name] = module
				return module
			end,
		}
		ns.FeatureBase:new("TravelPoints")

		-- Real ConfigCommon -- CreateFeatureBackgroundOverrideGroup et al.
		assert(loadfile("RPGLootFeed/config/common/common.lua"))("TestAddon", ns)

		-- Load the TravelPointsConfig module under test.
		assert(loadfile("RPGLootFeed/Features/TravelPoints/TravelPointsConfig.lua"))("TestAddon", ns)
	end)

	it("should set up the travel points configuration defaults", function()
		local defaults = travelPointsDefaults()
		assert.is_table(defaults)
		assert.is_boolean(defaults.enabled)
		assert.is_table(defaults.textColor)
		assert.is_boolean(defaults.enableIcon)
	end)

	it("should export a BuildConfigArgs builder function on G_RLF.TravelPoints", function()
		assert.is_function(ns.TravelPoints.BuildConfigArgs)
	end)

	it("should return a valid options group from BuildConfigArgs", function()
		local group = ns.TravelPoints:BuildConfigArgs(1, 8)
		assert.is_table(group)
		assert.equal("group", group.type)
		assert.equal(8, group.order)
		assert.is_table(group.args)
		assert.is_not_nil(group.args.enable)
		assert.is_not_nil(group.args.travelPointOptions)
	end)

	it("should have correct color defaults for travel points text", function()
		local textColor = travelPointsDefaults().textColor
		assert.is_table(textColor)
		assert.equal(1, textColor[1])
		assert.equal(0.988, textColor[2])
		assert.equal(0.498, textColor[3])
		assert.equal(1, textColor[4])
	end)

	it("enable toggle reads/writes through to the frame's feature config", function()
		local group = ns.TravelPoints:BuildConfigArgs(1, 8)
		assert.is_true(group.args.enable.get())
		group.args.enable.set(nil, false)
		assert.is_false(ns.db.global.frames[1].features.travelPoints.enabled)
	end)
end)
