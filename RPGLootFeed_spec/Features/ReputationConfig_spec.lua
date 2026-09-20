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
			repIconTexture = "",
		}
	end

	before_each(function()
		-- Minimal namespace: only what ReputationConfig.lua and common.lua touch.
		ns = {
			L = setmetatable({
				-- Carries a %s: TestIcon formats the resolved icon markup into it.
				["Chosen Icon"] = "Your chosen icon: %s",
			}, {
				__index = function(_, key)
					return key
				end,
			}),
			WrapCharEnum = { BRACKET = 3, ANGLE = 5 },
			DefaultIcons = { REPUTATION = 236681 },
			WrapCharOptions = { [3] = "Bracket", [5] = "Angle" },
			DbAccessor = {
				UpdateFeatureModuleState = function() end,
				Feature = function()
					return nil
				end,
				Styling = function()
					return { secondaryFontSize = 12 }
				end,
			},
			LootDisplay = {
				RefreshSampleRowsIfShown = function() end,
			},
			db = {
				-- revertRepIconToDefault reads the "**" frame defaults through db.defaults.
				defaults = {
					global = { frames = { ["**"] = { features = { reputation = reputationDefaults() } } } },
				},
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
	-- Ported from the pre-co-location RPGLootFeed_spec/config/Features/ReputationConfig_spec.lua
	-- (main commit 2285e18). The move to Features/Reputation/ dropped these, and with them the
	-- only guard on the handler table the named validate/preview callbacks resolve against.
	describe("reputation icon override", function()
		local group, fc

		before_each(function()
			group = ns.Reputation:BuildConfigArgs(1, 6)
			fc = function()
				return ns.db.global.frames[1].features.reputation
			end
		end)

		it("defaults the reputation icon override to empty (use the flavor default)", function()
			assert.equal("", fc().repIconTexture)
		end)

		it("exposes an input, a preview, and a revert-to-default button", function()
			local args = group.args.repOptions.args
			assert.equal("input", args.repIconTexture.type)
			assert.equal("description", args.testRepIcon.type)
			assert.equal("execute", args.revertRepIconToDefault.type)
		end)

		it("get/set round-trip through the per-frame reputation config", function()
			local args = group.args.repOptions.args
			assert.equal("", args.repIconTexture.get())
			args.repIconTexture.set(nil, "135026")
			assert.equal("135026", fc().repIconTexture)
			assert.equal("135026", args.repIconTexture.get())
		end)

		it("reverts the override back to the empty default", function()
			fc().repIconTexture = "135026"
			group.args.repOptions.args.revertRepIconToDefault.func()
			assert.equal("", fc().repIconTexture)
		end)

		describe("ValidateRepIcon", function()
			local handler
			before_each(function()
				handler = group.handler
			end)

			it("is reachable as the options group handler", function()
				assert.is_table(handler)
				assert.is_function(handler.ValidateRepIcon)
				assert.is_function(handler.TestIcon)
			end)

			it("accepts nil and empty string (meaning: use the flavor default)", function()
				assert.is_true(handler:ValidateRepIcon(nil, nil))
				assert.is_true(handler:ValidateRepIcon(nil, ""))
			end)

			it("accepts a numeric FileDataID", function()
				assert.is_true(handler:ValidateRepIcon(nil, "135026"))
			end)

			it("accepts a texture file path", function()
				assert.is_true(handler:ValidateRepIcon(nil, "interface/icons/inv_shirt_guildtabard_01"))
			end)

			it("rejects a bare Atlas-style name (not a FileDataID or path)", function()
				local result = handler:ValidateRepIcon(nil, "some-atlas-name")
				assert.is_string(result)
				assert.are_not.equal(true, result)
			end)
		end)

		describe("TestIcon", function()
			-- These assert the actual resolved icon appears in the markup, not
			-- just that a string comes back -- a stub that always returned the
			-- default (or always the override) would still pass an is_string check.
			it("embeds the flavor default icon in the markup when no override is set", function()
				local text = group.handler:TestIcon(1, "")
				assert.truthy(text:find(tostring(ns.DefaultIcons.REPUTATION), 1, true))
			end)

			it("embeds the override icon in the markup instead of the default when one is set", function()
				local text = group.handler:TestIcon(1, "135026")
				assert.truthy(text:find("135026", 1, true))
				assert.falsy(text:find(tostring(ns.DefaultIcons.REPUTATION), 1, true))
			end)
		end)
	end)
end)
