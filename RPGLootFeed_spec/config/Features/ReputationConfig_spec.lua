local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local setup = busted.setup

describe("ReputationConfig module", function()
	local ns
	setup(function()
		-- Define the global namespace
		-- ReputationConfig comes after ExperienceConfig in features.xml
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.ConfigFeatureXP)
		assert(loadfile("RPGLootFeed/config/common/common.lua"))("TestAddon", ns)
		-- Load the ReputationConfig module
		assert(loadfile("RPGLootFeed/config/Features/ReputationConfig.lua"))("TestAddon", ns)
	end)

	it("should set up the reputation configuration defaults", function()
		-- Check that the reputation configuration is set up in the defaults
		assert.is_table(ns.defaults.global.frames["**"].features.reputation)
		assert.is_boolean(ns.defaults.global.frames["**"].features.reputation.enabled)
		assert.is_table(ns.defaults.global.frames["**"].features.reputation.defaultRepColor)
		assert.is_number(ns.defaults.global.frames["**"].features.reputation.secondaryTextAlpha)
		assert.is_boolean(ns.defaults.global.frames["**"].features.reputation.enableRepLevel)
		assert.is_table(ns.defaults.global.frames["**"].features.reputation.repLevelColor)
		assert.is_not_nil(ns.defaults.global.frames["**"].features.reputation.repLevelTextWrapChar)
	end)

	it("should export a BuildReputationArgs builder function", function()
		assert.is_function(ns.BuildReputationArgs)
	end)

	it("should return a valid options group from BuildReputationArgs", function()
		ns.db = {
			global = {
				frames = { [1] = { features = { reputation = ns.defaults.global.frames["**"].features.reputation } } },
			},
		}
		local group = ns.BuildReputationArgs(1, 6)
		assert.is_table(group)
		assert.equal("group", group.type)
		assert.equal(6, group.order)
		assert.is_table(group.args)
	end)

	it("should have correct color defaults for reputation text", function()
		local repColor = ns.defaults.global.frames["**"].features.reputation.defaultRepColor
		assert.is_table(repColor)
		assert.equal(0.5, repColor[1])
		assert.equal(0.5, repColor[2])
		assert.equal(1, repColor[3])
	end)

	it("should have correct color defaults for reputation level text", function()
		local levelColor = ns.defaults.global.frames["**"].features.reputation.repLevelColor
		assert.is_table(levelColor)
		assert.equal(0.5, levelColor[1])
		assert.equal(0.5, levelColor[2])
		assert.equal(1, levelColor[3])
		assert.equal(1, levelColor[4])
	end)

	it("should have correct secondary text alpha", function()
		assert.equal(0.7, ns.defaults.global.frames["**"].features.reputation.secondaryTextAlpha)
	end)

	it("should use angle brackets as default wrap character for reputation level", function()
		assert.equal(ns.WrapCharEnum.ANGLE, ns.defaults.global.frames["**"].features.reputation.repLevelTextWrapChar)
	end)

	it("should default the reputation icon override to empty (use the flavor default)", function()
		assert.equal("", ns.defaults.global.frames["**"].features.reputation.repIconTexture)
	end)

	describe("reputation icon override", function()
		local group, fc

		setup(function()
			_G.CreateAtlasMarkup = function()
				return ""
			end
		end)

		before_each(function()
			ns.LootDisplay = { RefreshSampleRowsIfShown = function() end }
			-- ConfigFeatureXP is below the Config load threshold that stubs ns.DbAccessor
			-- as a busted stub table, so provide a minimal real implementation here.
			ns.DbAccessor = {
				Styling = function()
					return { secondaryFontSize = 12 }
				end,
			}
			ns.db = {
				defaults = ns.defaults,
				global = {
					misc = { hideAllIcons = false },
					frames = {
						[1] = {
							features = {
								reputation = {
									enabled = true,
									enableIcon = true,
									repIconTexture = "",
								},
							},
						},
					},
				},
			}
			group = ns.BuildReputationArgs(1, 6)
			fc = function()
				return ns.db.global.frames[1].features.reputation
			end
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
