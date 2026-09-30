local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local busted = require("busted")
local after_each = busted.after_each
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local spy = busted.spy
local stub = busted.stub

describe("LootHistory override", function()
	local ns, LootHistoryOverride, historyFrame

	local function newHistoryFrame()
		local frame = { RegisterEvent = function() end, UnregisterEvent = function() end }
		stub(frame, "RegisterEvent")
		stub(frame, "UnregisterEvent")
		return frame
	end

	before_each(function()
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
		ns.db.global.blizzOverrides.disableBlizzLootHistoryAutoShow = false
		LootHistoryOverride = assert(loadfile("RPGLootFeed/BlizzOverrides/LootHistory.lua"))("TestAddon", ns)
		LootHistoryOverride:OnInitialize()
	end)

	after_each(function()
		_G.GroupLootHistoryFrame = nil
		_G.LootHistoryFrame = nil
	end)

	it("waits for PLAYER_ENTERING_WORLD before touching Blizzard's frame", function()
		spy.on(LootHistoryOverride, "RegisterEvent")
		LootHistoryOverride:OnInitialize()
		assert
			.spy(LootHistoryOverride.RegisterEvent).was
			.called_with(LootHistoryOverride, "PLAYER_ENTERING_WORLD", "ApplyAutoShowSetting")
	end)

	describe("Mainline (GroupLootHistoryFrame)", function()
		before_each(function()
			historyFrame = newHistoryFrame()
			_G.GroupLootHistoryFrame = historyFrame
		end)

		it("leaves Blizzard's frame alone by default", function()
			LootHistoryOverride:ApplyAutoShowSetting()

			assert.stub(historyFrame.UnregisterEvent).was_not.called()
			assert.stub(historyFrame.RegisterEvent).was_not.called()
		end)

		it("unregisters only the auto-open event when enabled", function()
			ns.db.global.blizzOverrides.disableBlizzLootHistoryAutoShow = true

			LootHistoryOverride:ApplyAutoShowSetting()

			assert.stub(historyFrame.UnregisterEvent).was.called_with(historyFrame, "LOOT_HISTORY_GO_TO_ENCOUNTER")
		end)

		it("restores the auto-open event when turned back off", function()
			ns.db.global.blizzOverrides.disableBlizzLootHistoryAutoShow = true
			LootHistoryOverride:ApplyAutoShowSetting()
			ns.db.global.blizzOverrides.disableBlizzLootHistoryAutoShow = false
			LootHistoryOverride:ApplyAutoShowSetting()

			assert.stub(historyFrame.RegisterEvent).was.called_with(historyFrame, "LOOT_HISTORY_GO_TO_ENCOUNTER")
		end)
	end)

	it("uses LOOT_HISTORY_AUTO_SHOW on Classic's LootHistoryFrame", function()
		historyFrame = newHistoryFrame()
		_G.LootHistoryFrame = historyFrame
		ns.db.global.blizzOverrides.disableBlizzLootHistoryAutoShow = true

		LootHistoryOverride:ApplyAutoShowSetting()

		assert.stub(historyFrame.UnregisterEvent).was.called_with(historyFrame, "LOOT_HISTORY_AUTO_SHOW")
	end)

	describe("IsAutoShowSupported", function()
		it("is false when the client has no loot history frame", function()
			assert.is_false(LootHistoryOverride:IsAutoShowSupported())
		end)

		it("is true for Classic's LootHistoryFrame", function()
			_G.LootHistoryFrame = newHistoryFrame()
			assert.is_true(LootHistoryOverride:IsAutoShowSupported())
		end)

		it("is true for a mainline frame without ShouldAutoOpen", function()
			_G.GroupLootHistoryFrame = newHistoryFrame()
			assert.is_true(LootHistoryOverride:IsAutoShowSupported())
		end)

		it("is false when the mainline frame's ShouldAutoOpen returns false", function()
			historyFrame = newHistoryFrame()
			historyFrame.ShouldAutoOpen = function()
				return false
			end
			_G.GroupLootHistoryFrame = historyFrame
			ns.db.global.blizzOverrides.disableBlizzLootHistoryAutoShow = true

			assert.is_false(LootHistoryOverride:IsAutoShowSupported())
			LootHistoryOverride:ApplyAutoShowSetting()
			assert.stub(historyFrame.UnregisterEvent).was_not.called()
		end)
	end)
end)
