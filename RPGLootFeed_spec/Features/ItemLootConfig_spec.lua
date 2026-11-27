local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local setup = busted.setup
local before_each = busted.before_each

-- Feature defaults (ns.defaults.global.frames["**"].features.itemLoot) are
-- already covered end-to-end by RPGLootFeed_spec/config/ConfigOptions_spec.lua.
-- This spec covers what that one can't: that ItemLoot.BuildConfigArgs (the
-- options-panel builder, moved from a standalone G_RLF.BuildItemLootArgs
-- function, defined in the old config/Features/ItemConfig.lua, to a method
-- on the ItemLoot module during the Features/ co-location refactor) still
-- returns a valid AceConfig options group when invoked the way
-- FeatureRegistry actually calls it: featureModule:BuildConfigArgs(frameId, order).
describe("ItemLootConfig module", function()
	local ns

	setup(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.ConfigFeaturePartyLoot)
		assert(loadfile("RPGLootFeed/config/common/common.lua"))("TestAddon", ns)

		-- ItemLootConfig.lua reads G_RLF.AuctionIntegrations lazily (inside
		-- values()/hidden() closures we don't invoke here), but declare it so
		-- the shape matches production in case future edits touch it eagerly.
		ns.AuctionIntegrations = { numActiveIntegrations = 0, activeIntegrations = {} }

		-- BuildConfigArgs asks the ItemLoot adapter for localized item class names
		-- while it builds the Item Type Durations group. Armor (4) stands in for a
		-- class this client has; Glyph (16) for one it does not.
		ns.WoWAPI = {
			ItemLoot = {
				GetItemClassName = function(classID)
					if classID == 16 then
						return nil
					end
					return "Class" .. classID
				end,
			},
		}

		-- In production, ItemLoot.lua runs before ItemLootConfig.lua (see
		-- Features/ItemLoot/ItemLoot.xml) and G_RLF.FeatureBase:new() sets
		-- G_RLF.ItemLoot to the module table as a side effect. ItemLootConfig.lua
		-- then attaches BuildConfigArgs as a method on that same table. Recreate
		-- just that hand-off here so the config file loads exactly as it does
		-- in-game, without dragging in all of ItemLoot.lua's runtime DI.
		ns.ItemLoot = { moduleName = "ItemLoot" }
		assert(loadfile("RPGLootFeed/Features/ItemLoot/ItemLootConfig.lua"))("TestAddon", ns)
	end)

	it("should export BuildConfigArgs as a method on the ItemLoot module", function()
		assert.is_function(ns.ItemLoot.BuildConfigArgs)
	end)

	it("should return a valid options group from BuildConfigArgs", function()
		ns.db = {
			global = {
				frames = { [1] = { features = { itemLoot = ns.defaults.global.frames["**"].features.itemLoot } } },
				interactions = {},
			},
		}
		local group = ns.ItemLoot:BuildConfigArgs(1, 5)
		assert.is_table(group)
		assert.equal("group", group.type)
		assert.equal(5, group.order)
		assert.is_not_nil(group.name)
		assert.is_table(group.args)
		assert.is_table(group.args.enableItemLoot)
		assert.equal("toggle", group.args.enableItemLoot.type)
		assert.is_table(group.args.itemLootOptions)
		assert.is_table(group.args.itemLootOptions.args.itemQualityFilter)
		assert.is_table(group.args.itemLootOptions.args.itemHighlights)
		assert.is_table(group.args.itemLootOptions.args.itemSounds)
	end)

	it("should set up an enabled/duration toggle pair for every item quality", function()
		ns.db = {
			global = {
				frames = { [1] = { features = { itemLoot = ns.defaults.global.frames["**"].features.itemLoot } } },
				interactions = {},
			},
		}
		local group = ns.ItemLoot:BuildConfigArgs(1, 5)
		local qualityArgs = group.args.itemLootOptions.args.itemQualityFilter.args
		for _, key in ipairs({
			"poor",
			"common",
			"uncommon",
			"rare",
			"epic",
			"legendary",
			"artifact",
			"heirloom",
			"wowToken",
		}) do
			assert.is_table(qualityArgs[key .. "Enabled"], "missing " .. key .. "Enabled")
			assert.is_table(qualityArgs[key .. "Duration"], "missing " .. key .. "Duration")
		end
	end)

	describe("combined price icons option (issue #615)", function()
		local group, option, itemLootCfg

		local function find(tbl, key)
			if type(tbl) ~= "table" then
				return nil
			end
			if tbl[key] ~= nil and type(tbl[key]) == "table" and tbl[key].type then
				return tbl[key]
			end
			for _, child in pairs(tbl) do
				local found = find(child, key)
				if found then
					return found
				end
			end
		end

		before_each(function()
			itemLootCfg = {}
			for k, v in pairs(ns.defaults.global.frames["**"].features.itemLoot) do
				itemLootCfg[k] = v
			end
			itemLootCfg.enabled = true
			ns.db = {
				global = { frames = { [1] = { features = { itemLoot = itemLootCfg } } }, interactions = {} },
			}
			group = ns.ItemLoot:BuildConfigArgs(1, 5)
			option = find(group.args, "combinedPriceIcons")
		end)

		it("defaults to off", function()
			assert.is_false(ns.defaults.global.frames["**"].features.itemLoot.combinedPriceIcons)
		end)

		it("exists as a toggle on the Item Loot page", function()
			assert.is_table(option)
			assert.equal("toggle", option.type)
		end)

		it("reads and writes the setting", function()
			assert.is_false(option.get())
			option.set(nil, true)
			assert.is_true(itemLootCfg.combinedPriceIcons)
		end)

		it("is only available for the two combined price modes", function()
			local modes = ns.PricesEnum
			itemLootCfg.pricesForSellableItems = modes.Vendor
			assert.is_true(option.disabled())
			itemLootCfg.pricesForSellableItems = modes.AH
			assert.is_true(option.disabled())
			itemLootCfg.pricesForSellableItems = modes.VendorAH
			assert.is_false(option.disabled())
			itemLootCfg.pricesForSellableItems = modes.AHVendor
			assert.is_false(option.disabled())
		end)

		it("is unavailable while Item Loot is disabled", function()
			itemLootCfg.pricesForSellableItems = ns.PricesEnum.VendorAH
			itemLootCfg.enabled = false
			assert.is_true(option.disabled())
		end)
	end)

	describe("item highlight colors (issue #670)", function()
		local highlightArgs, itemLootCfg

		before_each(function()
			itemLootCfg = {}
			for k, v in pairs(ns.defaults.global.frames["**"].features.itemLoot) do
				itemLootCfg[k] = v
			end
			itemLootCfg.enabled = true
			ns.db = {
				global = { frames = { [1] = { features = { itemLoot = itemLootCfg } } }, interactions = {} },
			}
			highlightArgs = ns.ItemLoot:BuildConfigArgs(1, 5).args.itemLootOptions.args.itemHighlights.args
		end)

		it("gives every highlight reason its own default color", function()
			local seen = {}
			for key, color in pairs(ns.DefaultItemHighlightColors()) do
				assert.is_not_nil(itemLootCfg.itemHighlights[key], key .. " is not a highlight reason")
				local id = table.concat(color, ",")
				assert.is_nil(seen[id], key .. " reuses another reason's color")
				seen[id] = true
			end
		end)

		for arg, key in pairs({
			highlightMountColor = "mounts",
			highlightLegendaryColor = "legendary",
			highlightBetterThanEquippedColor = "betterThanEquipped",
			hasTertiaryOrSocketColor = "hasTertiaryOrSocket",
			highlightQuestColor = "quest",
			highlightTransmogColor = "transmog",
		}) do
			it("has a color picker for " .. key, function()
				local option = highlightArgs[arg]
				assert.is_table(option)
				assert.equal("color", option.type)

				option.set(nil, 0.1, 0.2, 0.3)
				assert.same({ 0.1, 0.2, 0.3 }, itemLootCfg.itemHighlightColors[key])
				local r, g, b = option.get()
				assert.same({ 0.1, 0.2, 0.3 }, { r, g, b })
			end)

			it("disables the " .. key .. " picker while its highlight is off", function()
				itemLootCfg.itemHighlights[key] = true
				assert.is_false(highlightArgs[arg].disabled())
				itemLootCfg.itemHighlights[key] = false
				assert.is_true(highlightArgs[arg].disabled())
			end)
		end
	end)

	describe("item type durations option (issue #415)", function()
		local group, typeArgs, itemLootCfg

		before_each(function()
			itemLootCfg = {}
			for k, v in pairs(ns.defaults.global.frames["**"].features.itemLoot) do
				itemLootCfg[k] = v
			end
			itemLootCfg.itemTypeSettings = ns.DefaultItemTypeSettings()
			ns.db = {
				global = { frames = { [1] = { features = { itemLoot = itemLootCfg } } }, interactions = {} },
			}
			group = ns.ItemLoot:BuildConfigArgs(1, 5)
			typeArgs = group.args.itemLootOptions.args.itemTypeDurations.args
		end)

		it("has a duration range for every item class", function()
			for _, classID in ipairs(ns.ItemDurationClasses) do
				assert.is_table(typeArgs["class" .. classID], "missing class " .. classID)
				assert.equal("range", typeArgs["class" .. classID].type)
			end
		end)

		it("defaults every item class to 0 (no override)", function()
			for _, classID in ipairs(ns.ItemDurationClasses) do
				assert.equal(0, ns.defaults.global.frames["**"].features.itemLoot.itemTypeSettings[classID].duration)
			end
		end)

		it("reads and writes a class's duration", function()
			assert.equal(0, typeArgs.class4.get())
			typeArgs.class4.set(nil, 12)
			assert.equal(12, itemLootCfg.itemTypeSettings[4].duration)
			assert.equal(12, typeArgs.class4.get())
		end)

		it("hides classes the client has no name for", function()
			assert.is_false(typeArgs.class4.hidden())
			assert.is_true(typeArgs.class16.hidden())
		end)

		it("names a class when the options render, even if the client could not name it at build time", function()
			local original = ns.WoWAPI.ItemLoot.GetItemClassName
			local available = false
			ns.WoWAPI.ItemLoot.GetItemClassName = function(classID)
				return available and ("Late" .. classID) or nil
			end
			local lateGroup = ns.ItemLoot:BuildConfigArgs(1, 5)
			local late = lateGroup.args.itemLootOptions.args.itemTypeDurations.args.class4

			assert.is_true(late.hidden())

			available = true

			assert.is_false(late.hidden())
			assert.is_truthy(late.name():find("Late4", 1, true))
			assert.is_truthy(late.desc():find("Late4", 1, true))

			ns.WoWAPI.ItemLoot.GetItemClassName = original
		end)

		it("resets every item type duration", function()
			typeArgs.class4.set(nil, 12)
			typeArgs.class0.set(nil, 5)
			typeArgs.resetItemTypeDurations.func()
			assert.equal(0, itemLootCfg.itemTypeSettings[4].duration)
			assert.equal(0, itemLootCfg.itemTypeSettings[0].duration)
		end)
	end)
end)
