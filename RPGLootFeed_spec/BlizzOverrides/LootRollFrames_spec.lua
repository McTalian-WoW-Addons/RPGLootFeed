local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local after_each = busted.after_each
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local stub = busted.stub

describe("LootRollFrames override", function()
	local ns, Override, rollFrame, button, rowsByRollID

	--- Mock Blizzard GroupLootFrame with one mouse-enabled child button.
	local function newMouseFrame(children)
		local f = { _mouse = true, _alpha = 1, _children = children or {} }
		function f:IsMouseEnabled()
			return self._mouse
		end
		function f:EnableMouse(v)
			self._mouse = v
		end
		function f:GetChildren()
			return unpack(self._children)
		end
		function f:SetAlpha(a)
			self._alpha = a
		end
		function f:IsShown()
			return true
		end
		return f
	end

	before_each(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		ns.db.global.blizzOverrides.hideBlizzLootRollFrames = true
		ns.db.global.interactions.disableAllInteraction = false

		rowsByRollID = {}
		ns.LootRolls = {
			IsEnabled = function()
				return true
			end,
			FindRollRows = function(_, rollID)
				return rowsByRollID[rollID] or {}
			end,
		}

		button = newMouseFrame()
		rollFrame = newMouseFrame({ button })
		rollFrame.rollID = 7
		_G.NUM_GROUP_LOOT_FRAMES = 1
		_G.GroupLootFrame1 = rollFrame

		Override = assert(loadfile("RPGLootFeed/BlizzOverrides/LootRollFrames.lua"))("TestAddon", ns)
	end)

	after_each(function()
		_G.GroupLootFrame1 = nil
		_G.NUM_GROUP_LOOT_FRAMES = nil
		_G.GroupLootContainer_OpenNewFrame = nil
		_G.GroupLootFrame_OpenNewFrame = nil
	end)

	describe("OnInitialize", function()
		it("post-hooks the Mainline container open function", function()
			_G.GroupLootContainer_OpenNewFrame = function() end
			Override.SecureHook = function() end
			stub(Override, "SecureHook")

			Override:OnInitialize()

			assert.stub(Override.SecureHook).was.called_with(Override, "GroupLootContainer_OpenNewFrame", "Refresh")
		end)

		it("post-hooks the Classic open function", function()
			_G.GroupLootFrame_OpenNewFrame = function() end
			Override.SecureHook = function() end
			stub(Override, "SecureHook")

			Override:OnInitialize()

			assert.stub(Override.SecureHook).was.called_with(Override, "GroupLootFrame_OpenNewFrame", "Refresh")
		end)
	end)

	it("conceals Blizzard's frame for a roll the feed is showing", function()
		rowsByRollID[7] = { {} }

		Override:Refresh()

		assert.are.equal(0, rollFrame._alpha)
		assert.is_false(rollFrame._mouse)
		assert.is_false(button._mouse)
	end)

	it("keeps Blizzard's frame for a roll the feed isn't showing", function()
		Override:Refresh()

		assert.are.equal(1, rollFrame._alpha)
		assert.is_true(button._mouse)
	end)

	it("keeps Blizzard's frame while the option is off (default)", function()
		rowsByRollID[7] = { {} }
		ns.db.global.blizzOverrides.hideBlizzLootRollFrames = false

		Override:Refresh()

		assert.are.equal(1, rollFrame._alpha)
	end)

	it("keeps Blizzard's frame when row interaction is disabled", function()
		rowsByRollID[7] = { {} }
		ns.db.global.interactions.disableAllInteraction = true

		Override:Refresh()

		assert.are.equal(1, rollFrame._alpha)
	end)

	it("restores Blizzard's frame once the feed row goes away", function()
		rowsByRollID[7] = { {} }
		Override:Refresh()
		rowsByRollID[7] = nil

		Override:Refresh()

		assert.are.equal(1, rollFrame._alpha)
		assert.is_true(rollFrame._mouse)
		assert.is_true(button._mouse)
	end)
end)
