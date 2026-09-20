local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("FeatureRegistry beta modules", function()
	local ns

	local function register(opts)
		ns.FeatureRegistry:Register(opts)
	end

	local function moduleStub(name)
		return { moduleName = name }
	end

	before_each(function()
		ns = {
			L = setmetatable({}, {
				__index = function(_, key)
					return key
				end,
			}),
			FeatureModule = {},
		}
		assert(loadfile("RPGLootFeed/utils/FeatureRegistry.lua"))("TestAddon", ns)
	end)

	describe("options group decoration", function()
		local function buildGroup(beta)
			local module = moduleStub("Sample")
			module.BuildConfigArgs = function(_, _frameId, order)
				return {
					type = "group",
					name = "Sample Config",
					order = order,
					args = { enableSample = { type = "toggle", order = 1 } },
				}
			end
			register({ module = module, key = "sample", order = 1, beta = beta })
			return ns._featureConfigs.sample(1, 6)
		end

		it("appends a beta tag to the group heading", function()
			local group = buildGroup(true)
			assert.truthy(group.name:find("Sample Config", 1, true))
			assert.truthy(group.name:find("Beta", 1, true))
		end)

		it("adds a notice ahead of the builder's own args", function()
			local group = buildGroup(true)
			assert.is_table(group.args.betaModuleNotice)
			assert.equal("description", group.args.betaModuleNotice.type)
			assert.truthy(group.args.betaModuleNotice.order < group.args.enableSample.order)
			-- The builder's own args survive the wrapping.
			assert.is_table(group.args.enableSample)
		end)

		it("leaves a non-beta feature's group untouched", function()
			local group = buildGroup(false)
			assert.equal("Sample Config", group.name)
			assert.is_nil(group.args.betaModuleNotice)
		end)
	end)

	describe("registry queries", function()
		before_each(function()
			register({ module = moduleStub("BetaOne"), key = "betaOne", order = 1, beta = true })
			register({ module = moduleStub("Stable"), key = "stable", order = 2 })
		end)

		it("reports which keys are beta", function()
			assert.is_true(ns.FeatureRegistry:IsBeta("betaOne"))
			assert.is_false(ns.FeatureRegistry:IsBeta("stable"))
			assert.is_false(ns.FeatureRegistry:IsBeta("neverRegistered"))
		end)

		it("lists every beta key", function()
			assert.same({ "betaOne" }, ns.FeatureRegistry:BetaKeys())
		end)
	end)
end)

-- The promise a beta label makes is that opting in is deliberate. Assert it
-- against the real defaults rather than trusting each module's registration.
describe("beta features ship disabled", function()
	local defaults

	before_each(function()
		local ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.Utils)
		assert(loadfile("RPGLootFeed/config/ConfigOptions.lua"))("TestAddon", ns)
		defaults = ns.defaults.global.frames["**"].features
	end)

	-- Listed explicitly: a new beta module must be added here, which is the
	-- prompt to confirm its default really is off.
	local BETA_FEATURE_KEYS = { "lootRolls" }

	for _, key in ipairs(BETA_FEATURE_KEYS) do
		it("defaults " .. key .. " to disabled", function()
			assert.is_table(defaults[key])
			assert.is_false(defaults[key].enabled)
		end)
	end
end)
