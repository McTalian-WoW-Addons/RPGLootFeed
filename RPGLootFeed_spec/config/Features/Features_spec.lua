local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local io = require("io")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("Features module", function()
	describe("load order", function()
		it("loads after ConfigOptions", function()
			local ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.ConfigOptions)
			local features = assert(loadfile("RPGLootFeed/config/Features/Features.lua"))("TestAddon", ns)
			---@diagnostic disable-next-line: redundant-parameter
			assert.is_not_nil(features, "ConfigOptions should be loaded before Features")
		end)
	end)

	---@type test_G_RLF, number
	local ns, lastFeature
	before_each(function()
		-- Define the global G_RLF
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		-- Load the list module before each test
		assert(loadfile("RPGLootFeed/config/Features/Features.lua"))("TestAddon", ns)
		lastFeature = 0
		for _, v in pairs(ns.mainFeatureOrder) do
			if v > lastFeature then
				lastFeature = v
			end
		end
	end)

	it("has parity with the FeatureModules enum", function()
		local featureModules = ns.FeatureModule
		local featureOrder = ns.mainFeatureOrder

		local numberOfFeatureModules = 0
		for _, _ in pairs(featureModules) do
			numberOfFeatureModules = numberOfFeatureModules + 1
		end
		local numberOfFeatureOrder = 0
		for _, _ in pairs(featureOrder) do
			numberOfFeatureOrder = numberOfFeatureOrder + 1
		end
		assert.equal(
			numberOfFeatureModules,
			numberOfFeatureOrder,
			"FeatureModules and mainFeatureOrder should have the same number of elements"
		)
	end)

	it("has a config for each loaded feature in features.xml", function()
		-- Open file in read mode
		local file = io.open("RPGLootFeed/Features/features.xml", "r")
		if not file then
			assert.is_not_nil(file)
			return
		end

		local featureImports = 0
		for line in file:lines() do
			if line:find("file=") then
				-- Skip internal files, co-located config files, and co-located sample files
				if
					not (line:find('file="_Internals'))
					and not (line:find('Config%.lua"'))
					and not (line:find('Sample%.lua"'))
				then
					featureImports = featureImports + 1
				end
			end
		end

		-- Close the file
		file:close()

		assert.equal(
			lastFeature,
			featureImports,
			"Number of feature imports in features.xml should match the number of features in mainFeatureOrder"
		)
	end)

	it("does not create the old lootFeeds options group", function()
		assert.is_nil(ns.options.args.lootFeeds)
	end)
end)
