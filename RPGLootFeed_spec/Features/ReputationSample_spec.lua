local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local before_each = busted.before_each

-- Regression coverage for the icon-override resolution, ported from the
-- pre-co-location RPGLootFeed_spec/LootDisplay/SampleRows_spec.lua (main commit
-- 2285e18). The sample row used to reimplement "override or flavor default"
-- inline instead of calling G_RLF.RepUtils.ResolveRepIcon, the same function
-- RepUtils.GetFactionData uses, and the two could silently disagree.
describe("ReputationSample", function()
	---@type table Payloads captured from LootElementBase:fromPayload.
	local capturedPayloads
	local ns

	local function repConfig()
		return ns.db.global.frames[1].features.reputation
	end

	local function getRepPayload()
		capturedPayloads = {}
		ns.Reputation:GetSampleRows(1, ns.db.global.frames[1].features)
		return capturedPayloads[1]
	end

	before_each(function()
		capturedPayloads = {}

		ns = {
			DefaultIcons = { REPUTATION = 236681 },
			ItemQualEnum = { Poor = 0, Common = 1, Rare = 3 },
			L = setmetatable({}, {
				__index = function(_, key)
					return key
				end,
			}),
			RGBAToHexFormat = function()
				return "|cFFFFFFFF"
			end,
			LootElementBase = {
				fromPayload = function(_, payload)
					table.insert(capturedPayloads, payload)
					return { Show = function() end }
				end,
			},
			db = {
				global = {
					misc = { hideAllIcons = false },
					frames = {
						[1] = {
							features = {
								reputation = {
									enabled = true,
									enableIcon = true,
									repIconTexture = "",
									enableRepLevel = false,
									repLevelColor = { 0.5, 0.5, 1, 1 },
									repLevelTextWrapChar = 5,
									secondaryTextAlpha = 0.7,
								},
							},
						},
					},
				},
			},
		}
		ns.DbAccessor = {
			Feature = function(_, _frame, _key)
				return repConfig()
			end,
		}

		-- Mirror the real FeatureBase wiring so `function G_RLF.Reputation:GetSampleRows`
		-- in ReputationSample.lua has a target to attach to.
		ns.FeatureBase = {
			new = function(_, name)
				local module = {
					moduleName = name,
					IsEnabled = function()
						return true
					end,
				}
				ns[name] = module
				return module
			end,
		}
		ns.FeatureBase:new("Reputation")

		-- Real RepUtils: ResolveRepIcon is the behavior under test.
		assert(loadfile("RPGLootFeed/utils/ReputationHelpers.lua"))("TestAddon", ns)
		assert(loadfile("RPGLootFeed/Features/Reputation/ReputationSample.lua"))("TestAddon", ns)
	end)

	it("uses the flavor default icon when no override is configured", function()
		assert.equal(236681, getRepPayload().icon)
	end)

	it("uses the configured numeric FileDataID override instead of the default", function()
		repConfig().repIconTexture = "135026"
		assert.equal(135026, getRepPayload().icon)
	end)

	it("uses the configured texture path override instead of the default", function()
		repConfig().repIconTexture = "interface/icons/inv_shirt_guildtabard_01"
		assert.equal("interface/icons/inv_shirt_guildtabard_01", getRepPayload().icon)
	end)

	it("shows no icon at all when enableIcon is off, even with an override configured", function()
		repConfig().enableIcon = false
		repConfig().repIconTexture = "135026"
		assert.is_nil(getRepPayload().icon)
	end)

	it("shows no icon at all when hideAllIcons is set", function()
		ns.db.global.misc.hideAllIcons = true
		assert.is_nil(getRepPayload().icon)
	end)

	it("produces no sample row when reputation is disabled for the frame", function()
		repConfig().enabled = false
		assert.is_nil(getRepPayload())
	end)
end)
