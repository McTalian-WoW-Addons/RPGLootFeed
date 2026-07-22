---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--@alpha@
-- trunk-ignore-begin(no-invalid-prints/invalid-print)
---@type RLF_TestMode
local TestMode = G_RLF.RLF:GetModule(G_RLF.SupportModule.TestMode) --[[@as RLF_TestMode]]
local runner = G_RLF.GameTestRunner:new("Integration Test", {
	printHeader = function(msg)
		G_RLF:Print(msg)
	end,
	printLine = print,
	raiseError = error,
})

local function runExperienceIntegrationTest()
	local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Experience) --[[@as RLF_Experience]]
	local LootElementBase = G_RLF.LootElementBase
	local accepts = 0

	local payload = module:BuildPayload(1336)
	if not payload then
		G_RLF:Print("Experience payload not created, something went wrong")
		return accepts
	end
	local e = LootElementBase:fromPayload(payload)
	runner:runTestSafely(e.Show, "LootDisplay: Experience", e)
	accepts = accepts + 1

	local payload2 = module:BuildPayload(1)
	if not payload2 then
		G_RLF:Print("Experience update payload not created, something went wrong")
		return accepts
	end
	local e2 = LootElementBase:fromPayload(payload2)
	runner:runTestSafely(e2.Show, "LootDisplay: Experience Update", e2)
	accepts = accepts + 1
	return accepts
end

local function runMoneyIntegrationTest()
	local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Money) --[[@as RLF_Money]]
	local payload = module:BuildPayload(12345)
	if not payload then
		G_RLF:Print("Money payload not created, something went wrong")
		return 0
	end
	local e = G_RLF.LootElementBase:fromPayload(payload)
	runner:runTestSafely(e.Show, "LootDisplay: Money", e)
	return 1
end

--- Verifies subscription-based routing using the existing second frame.
--- Disables Money on Main, enables it on the second frame, fires one Money
--- element, then asserts via _testAcceptCount that it only landed on the
--- second frame.
---
--- NOTE: G_RLF:SendMessage defers dispatch via RunNextFrame, so the
--- assertions and cleanup must also be deferred.
--- @return integer rowsShown
--- @return fun() verify   — call from a deferred context to assert
--- @return fun() cleanup  — call after verify to restore state
local function runMoneySubscriptionRoutingIntegrationTest()
	local lootDisplay = G_RLF.LootDisplay
	local framesDb = G_RLF.db.global.frames
	local mainFrameConfig = framesDb[G_RLF.Frames.MAIN]
	local noop = function() end
	if not mainFrameConfig then
		return 0, noop, noop
	end

	-- Find the first non-Main frame that already exists.
	local secondId
	for id in pairs(framesDb) do
		local f = lootDisplay:GetFrame(id)
		if f and id ~= G_RLF.Frames.MAIN then
			secondId = id
			break
		end
	end

	local mainFrame = lootDisplay:GetFrame(G_RLF.Frames.MAIN)
	local secondFrame = secondId and lootDisplay:GetFrame(secondId)
	runner:assertEqual(mainFrame ~= nil, true, "LootDisplay: MainLootFrame exists for subscription routing")
	runner:assertEqual(secondFrame ~= nil, true, "LootDisplay: Second frame exists for subscription routing")
	if not mainFrame or not secondFrame then
		return 0, noop, noop
	end

	-- Save original money subscription states.
	local oldMainMoneySub = mainFrameConfig.features.money.enabled
	local secondFrameConfig = framesDb[secondId]
	local oldSecondMoneySub = secondFrameConfig.features.money.enabled

	-- Route money exclusively to the second frame.
	mainFrameConfig.features.money.enabled = false
	secondFrameConfig.features.money.enabled = true

	-- Snapshot acceptance counters before firing.
	local mainCountBefore = mainFrame._testAcceptCount or 0
	local secondCountBefore = secondFrame._testAcceptCount or 0

	-- Fire a money element through the normal pipeline.
	local rowsShown = runMoneyIntegrationTest()

	-- Assertions must be deferred because G_RLF:SendMessage uses RunNextFrame.
	-- The config changes must stay in place until OnLootReady fires, so cleanup
	-- is also deferred.
	local verify = function()
		local mainDelta = (mainFrame._testAcceptCount or 0) - mainCountBefore
		local secondDelta = (secondFrame._testAcceptCount or 0) - secondCountBefore
		runner:assertEqual(mainDelta, 0, "LootDisplay: Money unsubscribed from Main")
		runner:assertEqual(secondDelta, rowsShown, "LootDisplay: Money routed to second frame")
	end

	local cleanup = function()
		mainFrameConfig.features.money.enabled = oldMainMoneySub
		secondFrameConfig.features.money.enabled = oldSecondMoneySub
	end

	return rowsShown, verify, cleanup
end

local function runTravelPointsIntegrationTest()
	local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.TravelPoints) --[[@as RLF_TravelPoints]]
	local payload = module:BuildPayload(50)
	local e = G_RLF.LootElementBase:fromPayload(payload)
	runner:runTestSafely(e.Show, "LootDisplay: TravelPoints", e)
	return 1
end

--- Exercises the ItemLoot BuildPayload → fromPayload → Show pipeline directly.
local function runItemLootIntegrationTest()
	local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.ItemLoot) --[[@as RLF_ItemLoot]]
	local LootElementBase = G_RLF.LootElementBase
	local info = TestMode.testItems[2]
	local amountLooted = 1
	local rowsShown = 0
	local payload = module:BuildPayload(info, amountLooted)
	if not payload then
		G_RLF:Print("Item not cached or filtered, skipping ItemLoot test")
	elseif info.itemName == nil then
		G_RLF:Print("Item not cached, skipping ItemLoot test")
	else
		payload.highlight = true
		local e = LootElementBase:fromPayload(payload)
		runner:runTestSafely(e.Show, "LootDisplay: Item", e, info.itemName, info.itemQuality)
		rowsShown = rowsShown + 1
		local payload2 = module:BuildPayload(info, amountLooted)
		if payload2 then
			payload2.highlight = true
			local e2 = LootElementBase:fromPayload(payload2)
			runner:runTestSafely(e2.Show, "LootDisplay: Item Quantity Update", e2, info.itemName, info.itemQuality)
			rowsShown = rowsShown + 1
		end
	end
	return rowsShown
end

--- Exercises the PartyLoot BuildPayload → fromPayload → Show pipeline directly.
local function runPartyLootIntegrationTest()
	local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.PartyLoot) --[[@as RLF_PartyLoot]]
	local LootElementBase = G_RLF.LootElementBase
	local info = TestMode.testItems[2]
	local amountLooted = 1
	local payload = module:BuildPayload(info, amountLooted, "player")
	if not payload then
		G_RLF:Print("PartyLoot payload not created, something went wrong")
		return 0
	end
	local e = LootElementBase:fromPayload(payload)
	runner:runTestSafely(e.Show, "LootDisplay: Party Item", e, info.itemName, info.itemQuality)
	return 1
end

--- Exercises the LootRolls fromPayload → Show pipeline directly.
local function runLootRollsIntegrationTest()
	local LootElementBase = G_RLF.LootElementBase
	local ok, icon = pcall(function()
		return GetItemIcon(14344)
	end)
	LootElementBase:fromPayload({
		key = "it_loot_roll_test",
		type = G_RLF.FeatureModule.LootRolls,
		isLink = true,
		icon = ok and icon or nil,
		quality = G_RLF.ItemQualEnum.Rare,
		quantity = 1,
		textFn = function(_, truncatedLink)
			return truncatedLink or "|cff0070dd|Hitem:14344::::::::60:::::|h[Large Brilliant Shard]|h|r"
		end,
		rollID = nil,
		rollDuration = 60,
		canNeed = true,
		canGreed = true,
		canTransmog = false,
		isSampleRow = false,
		IsEnabled = function()
			return true
		end,
		mockDropInfo = {
			lootListID = 1,
			itemHyperlink = "|cff0070dd|Hitem:14344::::::::60:::::|h[Large Brilliant Shard]|h|r",
			rollInfos = {
				{
					playerName = "TestWar",
					playerClass = "WARRIOR",
					state = 0,
					roll = 87,
					isWinner = false,
					isSelf = false,
				},
				{
					playerName = "TestMage",
					playerClass = "MAGE",
					state = 3,
					roll = nil,
					isWinner = false,
					isSelf = false,
				},
				{
					playerName = "TestPriest",
					playerClass = "PRIEST",
					state = 5,
					roll = nil,
					isWinner = false,
					isSelf = false,
				},
				{ playerName = "You", playerClass = "HUNTER", state = 4, roll = nil, isWinner = false, isSelf = true },
			},
			currentLeader = { playerName = "TestWar", playerClass = "WARRIOR", roll = 87 },
			winner = nil,
			allPassed = false,
			startTime = 0,
			duration = 60,
		},
	}):Show()
	return 1
end

--- Exercises the Currency BuildPayload → fromPayload → Show pipeline directly.
local function runCurrencyIntegrationTest()
	local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Currency) --[[@as RLF_Currency]]
	local LootElementBase = G_RLF.LootElementBase
	local testObj = TestMode.testCurrencies[2]
	local amountLooted = 1
	testObj.basicInfo.displayAmount = amountLooted
	local accepts = 0
	local payload = module:BuildPayload(testObj.link, testObj.info, testObj.basicInfo)
	if not payload then
		G_RLF:Print("Currency payload not created, something went wrong")
		return accepts
	end
	local e = LootElementBase:fromPayload(payload)
	runner:runTestSafely(e.Show, "LootDisplay: Currency", e)
	accepts = accepts + 1
	payload = module:BuildPayload(testObj.link, testObj.info, testObj.basicInfo)
	if not payload then
		G_RLF:Print("Currency update payload not created, something went wrong")
		return accepts
	end
	e = LootElementBase:fromPayload(payload)
	runner:runTestSafely(e.Show, "LootDisplay: Currency Quantity Update", e)
	accepts = accepts + 1
	return accepts
end

--- Builds a synthetic UnifiedFactionData and exercises the
--- BuildPayload → fromPayload → Show pipeline directly.
--- Works on both Retail and Classic since it bypasses the event layer.
local function runReputationPayloadIntegrationTest()
	local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Reputation) --[[@as RLF_Reputation]]
	local LootElementBase = G_RLF.LootElementBase

	---@type UnifiedFactionData
	local testFactionData = {
		factionId = 99999,
		name = TestMode.testFactions[1] or "Test Faction",
		delta = 668,
		icon = G_RLF.DefaultIcons.REPUTATION,
		standing = 21000,
		rank = "Honored",
		quality = G_RLF.ItemQualEnum.Rare,
		contextInfo = "Integration test context",
	}

	local accepts = 0
	local payload = module:BuildPayload(testFactionData)
	if not payload then
		G_RLF:Print("Reputation payload not created, something went wrong")
		return accepts
	end
	local e = LootElementBase:fromPayload(payload)
	runner:runTestSafely(e.Show, "LootDisplay: Reputation", e)
	accepts = accepts + 1

	-- Second call with same key should stack/update the existing row
	local payload2 = module:BuildPayload(testFactionData)
	if not payload2 then
		G_RLF:Print("Reputation update payload not created, something went wrong")
		return accepts
	end
	payload2.quantity = payload2.quantity + 1
	local e2 = LootElementBase:fromPayload(payload2)
	runner:runTestSafely(e2.Show, "LootDisplay: Reputation Update", e2)
	accepts = accepts + 1

	return accepts
end

local function runReputationIntegrationTest()
	local rowsShown = runReputationPayloadIntegrationTest()

	-- On non-Retail (Classic), also exercise the CHAT_MSG_COMBAT_FACTION_CHANGE event path
	if
		not G_RLF:IsRetail()
		or not C_EventUtils.IsEventValid
		or not C_EventUtils.IsEventValid("FACTION_STANDING_CHANGED")
	then
		local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Reputation) --[[@as RLF_Reputation]]
		local amountLooted = 664

		local testObj = TestMode.testFactions[2]
		runner:runTestSafely(
			module.CHAT_MSG_COMBAT_FACTION_CHANGE,
			"LootDisplay: Reputation with Bonus (Chat)",
			module,
			"CHAT_MSG_COMBAT_FACTION_CHANGE",
			string.format(_G.FACTION_STANDING_INCREASED_ACH_BONUS, testObj, amountLooted, amountLooted / 2)
		)
		runner:runTestSafely(
			module.CHAT_MSG_COMBAT_FACTION_CHANGE,
			"LootDisplay: Reputation with Bonus Update (Chat)",
			module,
			"CHAT_MSG_COMBAT_FACTION_CHANGE",
			string.format(_G.FACTION_STANDING_INCREASED_ACH_BONUS, testObj, amountLooted, amountLooted / 2)
		)

		testObj = TestMode.testFactions[1]
		runner:runTestSafely(
			module.CHAT_MSG_COMBAT_FACTION_CHANGE,
			"LootDisplay: Reputation (Chat)",
			module,
			"CHAT_MSG_COMBAT_FACTION_CHANGE",
			string.format(_G.FACTION_STANDING_INCREASED, testObj, 1030)
		)
		runner:runTestSafely(
			module.CHAT_MSG_COMBAT_FACTION_CHANGE,
			"LootDisplay: Reputation Update (Chat)",
			module,
			"CHAT_MSG_COMBAT_FACTION_CHANGE",
			string.format(_G.FACTION_STANDING_INCREASED, testObj, 307)
		)
		rowsShown = rowsShown + 4
	end

	return rowsShown
end

--- Exercises the Profession BuildPayload → fromPayload → Show pipeline directly.
local function runProfessionIntegrationTest()
	local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Profession) --[[@as RLF_Professions]]
	local LootElementBase = G_RLF.LootElementBase
	local icon = 4620671
	-- So far, MoP Classic and below doesn't have this icon
	if not G_RLF:IsRetail() then
		icon = G_RLF.DefaultIcons.PROFESSION
	end
	local payload = module:BuildPayload("Cooking", "Cooking", icon, 3, 1)
	local e = LootElementBase:fromPayload(payload)
	runner:runTestSafely(e.Show, "LootDisplay: Professions", e)
	payload = module:BuildPayload("Cooking", "Cooking", icon, 4, 2)
	e = LootElementBase:fromPayload(payload)
	runner:runTestSafely(e.Show, "LootDisplay: Professions Quantity Update", e)
	return 2
end

--- Exercises the Transmog BuildPayload → fromPayload → Show pipeline directly.
local function runTransmogIntegrationTest()
	if not G_RLF:IsRetail() then
		return 0
	end
	local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Transmog) --[[@as RLF_Transmog]]
	local LootElementBase = G_RLF.LootElementBase
	local transmogLink = "|cff9d9d9d|Htransmogappearance:285269|h[Test Transmog]|h|r"
	local payload = module:BuildPayload(transmogLink, nil)
	if not payload then
		G_RLF:Print("Transmog payload not created, something went wrong")
		return 0
	end
	local e = LootElementBase:fromPayload(payload)
	runner:runTestSafely(e.Show, "LootDisplay: Transmog", e)
	return 1
end

--- Fires two synthetic profession skill-gain events (initial + stack/update)
--- so the skill-delta badge can be verified without actually levelling a profession.
function TestMode:ProfessionTest()
	if not self.integrationTestReady then
		G_RLF:Print("Integration test not ready")
		return
	end

	runner:reset()
	local expected = runProfessionIntegrationTest()
	RunNextFrame(function()
		runner:assertEqual(type(expected), "number", "Profession test fired")
		runner:displayResults()
	end)
end

function TestMode:IntegrationTest()
	if not self.integrationTestReady then
		G_RLF:Print("Integration test not ready")
		return
	end

	runner:reset()
	local lootDisplay = G_RLF.LootDisplay
	local mainFrame = lootDisplay:GetFrame(G_RLF.Frames.MAIN)
	if not mainFrame then
		runner:assertEqual(mainFrame ~= nil, true, "Main frame exists")
		runner:displayResults()
		return
	end

	-- Snapshot _testAcceptCount across all live frames before tests run.
	local frameSnapshots = {}
	for id in pairs(G_RLF.db.global.frames) do
		local f = lootDisplay:GetFrame(id)
		if f then
			frameSnapshots[id] = f._testAcceptCount or 0
		end
	end

	-- ── Phase 1: fire all feature tests ────────────────────────────────────
	-- Each Show() defers its OnLootReady via RunNextFrame, so no accepts are
	-- counted until the next render frame.
	local newRowsExpected = 0
	newRowsExpected = newRowsExpected + runExperienceIntegrationTest()
	newRowsExpected = newRowsExpected + runMoneyIntegrationTest()
	if G_RLF:IsRetail() then
		newRowsExpected = newRowsExpected + runTravelPointsIntegrationTest()
	end
	newRowsExpected = newRowsExpected + runItemLootIntegrationTest()
	if GetExpansionLevel() >= G_RLF.Expansion.WOTLK then
		newRowsExpected = newRowsExpected + runCurrencyIntegrationTest()
	end
	local partyModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.PartyLoot) --[[@as RLF_PartyLoot]]
	if partyModule:IsEnabled() then
		newRowsExpected = newRowsExpected + runPartyLootIntegrationTest()
	end
	newRowsExpected = newRowsExpected + runReputationIntegrationTest()
	newRowsExpected = newRowsExpected + runProfessionIntegrationTest()
	local transmogModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Transmog) --[[@as RLF_Transmog]]
	if transmogModule:IsEnabled() then
		newRowsExpected = newRowsExpected + runTransmogIntegrationTest()
	end
	local lootRollsModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.LootRolls) --[[@as RLF_LootRolls]]
	if lootRollsModule:IsEnabled() then
		newRowsExpected = newRowsExpected + runLootRollsIntegrationTest()
	end

	-- ── Phase 2: wait for phase-1 OnLootReady calls, then run routing ──────
	-- G_RLF:SendMessage defers dispatch via RunNextFrame, so our phase
	-- transition must double-nest RunNextFrame: the outer callback fires on
	-- the same frame as the deferred SendMessage callbacks (non-deterministic
	-- ordering), and the inner callback fires one frame later — guaranteeing
	-- all phase-1 accepts have settled.
	RunNextFrame(function()
		RunNextFrame(function()
			local routingRowsExpected, verifyRouting, cleanupRouting = runMoneySubscriptionRoutingIntegrationTest()
			newRowsExpected = newRowsExpected + routingRowsExpected

			-- ── Phase 3: wait for routing's OnLootReady, then verify all ────────
			RunNextFrame(function()
				RunNextFrame(function()
					verifyRouting()
					cleanupRouting()

					local totalAcceptAfter = 0
					for id, before in pairs(frameSnapshots) do
						local f = lootDisplay:GetFrame(id)
						if f then
							totalAcceptAfter = totalAcceptAfter + ((f._testAcceptCount or 0) - before)
						end
					end

					runner:assertEqual(totalAcceptAfter, newRowsExpected, "Total elements accepted by all frames")
					runner:displayResults()
				end)
			end)
		end)
	end)
end

-- trunk-ignore-end(no-invalid-prints/invalid-print)
--@end-alpha@
