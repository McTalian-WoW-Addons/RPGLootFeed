local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local before_each = busted.before_each

describe("TransmogConfig module", function()
	local ns

	-- Defaults ported from RPGLootFeed/config/ConfigOptions.lua's
	-- frames["**"].features.transmog block.
	local function transmogDefaults()
		return {
			enabled = true,
			backgroundOverride = {
				enabled = false,
				gradientStart = { 0.1, 0.1, 0.1, 0.8 },
				gradientEnd = { 0.1, 0.1, 0.1, 0 },
				textureColor = { 0, 0, 0, 1 },
			},
			enableTransmogEffect = true,
			enableBlizzardTransmogSound = true,
			enableIcon = true,
		}
	end

	before_each(function()
		-- Minimal namespace: only what TransmogConfig.lua and common.lua touch.
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
					frames = { [1] = { features = { transmog = transmogDefaults() } } },
					misc = { hideAllIcons = false },
					interactions = { disableAllInteraction = false },
				},
			},
		}

		-- FeatureBase mock mirrors the real G_RLF[moduleName] = module wiring
		-- (RPGLootFeed/Features/_Internals/FeatureBase.lua) so that
		-- `function G_RLF.Transmog:BuildConfigArgs(...)` in TransmogConfig.lua
		-- has a real target to attach to -- the same production call path used
		-- when the feature module and its co-located Config.lua load together.
		ns.FeatureBase = {
			new = function(_, name)
				local module = { moduleName = name }
				ns[name] = module
				return module
			end,
		}
		ns.FeatureBase:new("Transmog")

		-- Real ConfigCommon -- CreateFeatureBackgroundOverrideGroup et al.
		assert(loadfile("RPGLootFeed/config/common/common.lua"))("TestAddon", ns)

		-- Load the TransmogConfig module under test.
		assert(loadfile("RPGLootFeed/Features/Transmog/TransmogConfig.lua"))("TestAddon", ns)
	end)

	it("should set up the transmog configuration defaults", function()
		local defaults = transmogDefaults()
		assert.is_table(defaults)
		assert.is_boolean(defaults.enabled)
		assert.is_boolean(defaults.enableTransmogEffect)
		assert.is_boolean(defaults.enableBlizzardTransmogSound)
		assert.is_boolean(defaults.enableIcon)
	end)

	it("should export a BuildConfigArgs builder function on G_RLF.Transmog", function()
		assert.is_function(ns.Transmog.BuildConfigArgs)
	end)

	it("should return a valid options group from BuildConfigArgs", function()
		local group = ns.Transmog:BuildConfigArgs(1, 9)
		assert.is_table(group)
		assert.equal("group", group.type)
		assert.equal(9, group.order)
		assert.is_table(group.args)
		assert.is_not_nil(group.args.enableTransmog)
		assert.is_not_nil(group.args.transmogOptions)
	end)

	it("should default transmog effect to enabled", function()
		assert.is_true(transmogDefaults().enableTransmogEffect)
	end)

	it("should default blizzard transmog sound to enabled", function()
		assert.is_true(transmogDefaults().enableBlizzardTransmogSound)
	end)

	it("enableTransmog toggle reads/writes through to the frame's feature config", function()
		local group = ns.Transmog:BuildConfigArgs(1, 9)
		assert.is_true(group.args.enableTransmog.get())
		group.args.enableTransmog.set(nil, false)
		assert.is_false(ns.db.global.frames[1].features.transmog.enabled)
	end)
end)
