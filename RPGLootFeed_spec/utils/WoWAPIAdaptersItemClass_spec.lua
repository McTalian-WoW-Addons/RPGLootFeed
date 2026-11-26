local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local after_each = busted.after_each
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it

describe("WoWAPI.ItemLoot.GetItemClassName", function()
	local ns, originalCItem, originalGlobal

	before_each(function()
		originalCItem, originalGlobal = _G.C_Item, _G.GetItemClassInfo
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		ns.WoWAPI = nil
		assert(loadfile("RPGLootFeed/utils/WoWAPIAdapters.lua"))("TestAddon", ns)
	end)

	after_each(function()
		_G.C_Item, _G.GetItemClassInfo = originalCItem, originalGlobal
	end)

	it("uses C_Item.GetItemClassInfo, the current API", function()
		_G.C_Item = {
			GetItemClassInfo = function(classID)
				return "Modern" .. classID
			end,
		}
		_G.GetItemClassInfo = function()
			return "Deprecated"
		end
		assert.equal("Modern4", ns.WoWAPI.ItemLoot.GetItemClassName(4))
	end)

	it("falls back to the global on a client without C_Item.GetItemClassInfo", function()
		_G.C_Item = {}
		_G.GetItemClassInfo = function(classID)
			return "Legacy" .. classID
		end
		assert.equal("Legacy4", ns.WoWAPI.ItemLoot.GetItemClassName(4))
	end)

	it("works when only the modern API exists, which is how current clients ship (issue #415)", function()
		_G.C_Item = {
			GetItemClassInfo = function()
				return "Armor"
			end,
		}
		_G.GetItemClassInfo = nil
		assert.equal("Armor", ns.WoWAPI.ItemLoot.GetItemClassName(4))
	end)

	it("returns nil when the client has neither API", function()
		_G.C_Item = {}
		_G.GetItemClassInfo = nil
		assert.is_nil(ns.WoWAPI.ItemLoot.GetItemClassName(4))
	end)

	it("returns nil for a class the client has no name for", function()
		_G.C_Item = {
			GetItemClassInfo = function()
				return ""
			end,
		}
		assert.is_nil(ns.WoWAPI.ItemLoot.GetItemClassName(16))
		_G.C_Item = {
			GetItemClassInfo = function()
				return nil
			end,
		}
		assert.is_nil(ns.WoWAPI.ItemLoot.GetItemClassName(16))
	end)
end)
