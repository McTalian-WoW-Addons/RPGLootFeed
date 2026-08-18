local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local before_each = busted.before_each

describe("ProfessionsConfig module", function()
	local ns

	-- Defaults ported from RPGLootFeed/config/ConfigOptions.lua's
	-- frames["**"].features.profession block.
	local function professionDefaults()
		return {
			enabled = true,
			backgroundOverride = {
				enabled = false,
				gradientStart = { 0.1, 0.1, 0.1, 0.8 },
				gradientEnd = { 0.1, 0.1, 0.1, 0 },
				textureColor = { 0, 0, 0, 1 },
			},
			showSkillChange = true,
			skillColor = { 0.333, 0.333, 1.0, 1.0 },
			skillTextWrapChar = 3, -- WrapCharEnum.BRACKET
			enableIcon = true,
		}
	end

	before_each(function()
		-- Minimal namespace: only what ProfessionsConfig.lua and common.lua touch.
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
					frames = { [1] = { features = { profession = professionDefaults() } } },
					misc = { hideAllIcons = false },
				},
			},
		}

		-- FeatureBase mock mirrors the real G_RLF[moduleName] = module wiring
		-- (RPGLootFeed/Features/_Internals/FeatureBase.lua) so that
		-- `function G_RLF.Professions:BuildConfigArgs(...)` in ProfessionsConfig.lua
		-- has a real target to attach to -- the same production call path used
		-- when the feature module and its co-located Config.lua load together.
		ns.FeatureBase = {
			new = function(_, name)
				local module = { moduleName = name }
				ns[name] = module
				return module
			end,
		}
		ns.FeatureBase:new("Professions")

		-- Real ConfigCommon -- CreateFeatureBackgroundOverrideGroup et al.
		assert(loadfile("RPGLootFeed/config/common/common.lua"))("TestAddon", ns)

		-- Load the ProfessionsConfig module under test.
		assert(loadfile("RPGLootFeed/Features/Professions/ProfessionsConfig.lua"))("TestAddon", ns)
	end)

	it("should set up the profession configuration defaults", function()
		local defaults = professionDefaults()
		assert.is_table(defaults)
		assert.is_boolean(defaults.enabled)
		assert.is_boolean(defaults.showSkillChange)
		assert.is_table(defaults.skillColor)
		assert.is_not_nil(defaults.skillTextWrapChar)
	end)

	it("should export a BuildConfigArgs builder function on G_RLF.Professions", function()
		assert.is_function(ns.Professions.BuildConfigArgs)
	end)

	it("should return a valid options group from BuildConfigArgs", function()
		local group = ns.Professions:BuildConfigArgs(1, 7)
		assert.is_table(group)
		assert.equal("group", group.type)
		assert.equal(7, group.order)
		assert.is_table(group.args)
		assert.is_not_nil(group.args.enableProfession)
		assert.is_not_nil(group.args.professionOptions)
	end)

	it("should have correct color defaults for skill text", function()
		local skillColor = professionDefaults().skillColor
		assert.is_table(skillColor)
		assert.equal(0.333, skillColor[1])
		assert.equal(0.333, skillColor[2])
		assert.equal(1.0, skillColor[3])
		assert.equal(1.0, skillColor[4])
	end)

	it("should use brackets as default wrap character for skill text", function()
		assert.equal(ns.WrapCharEnum.BRACKET, professionDefaults().skillTextWrapChar)
	end)

	it("enableProfession toggle reads/writes through to the frame's feature config", function()
		local group = ns.Professions:BuildConfigArgs(1, 7)
		assert.is_true(group.args.enableProfession.get())
		group.args.enableProfession.set(nil, false)
		assert.is_false(ns.db.global.frames[1].features.profession.enabled)
	end)
end)
