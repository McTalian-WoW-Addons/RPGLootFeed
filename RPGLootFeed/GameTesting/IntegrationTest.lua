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
	record = function(result)
		TestMode:RecordTestResult(result)
	end,
})

--- Print a diagnostic line and keep it with the saved results.
local function note(text)
	TestMode:LogDiagnostic("Integration Test", text)
end

local function runExperienceIntegrationTest()
	local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Experience) --[[@as RLF_Experience]]
	local LootElementBase = G_RLF.LootElementBase
	local accepts = 0

	local payload = module:BuildPayload(1336)
	if not payload then
		note("Experience payload not created, something went wrong")
		return accepts
	end
	local e = LootElementBase:fromPayload(payload)
	runner:runTestSafely(e.Show, "LootDisplay: Experience", e)
	accepts = accepts + 1

	local payload2 = module:BuildPayload(1)
	if not payload2 then
		note("Experience update payload not created, something went wrong")
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
		note("Money payload not created, something went wrong")
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

	-- Find the first configured non-Main frame.
	local secondId
	for id in pairs(framesDb) do
		if id ~= G_RLF.Frames.MAIN then
			secondId = id
			break
		end
	end

	local mainFrame = lootDisplay:GetFrame(G_RLF.Frames.MAIN)
	runner:assertEqual(mainFrame ~= nil, true, "LootDisplay: MainLootFrame exists for subscription routing")
	-- A profile with only the Main frame cannot exercise routing; skip rather than fail.
	if not secondId then
		runner:assertEqual(true, true, "LootDisplay: Subscription routing (skipped — no second frame configured)")
		return 0, noop, noop
	end
	local secondFrame = lootDisplay:GetFrame(secondId)
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
		note("Item not cached or filtered, skipping ItemLoot test")
	elseif info.itemName == nil then
		note("Item not cached, skipping ItemLoot test")
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

--- Checks the newer Item Loot features against a real item on this client. Fires no
--- rows, so it does not change the accepted-row count.
local function runItemFeatureChecks()
	local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.ItemLoot) --[[@as RLF_ItemLoot]]
	local info = TestMode.testItems[2]
	if not info or info.itemName == nil or not info.itemLink then
		note("Item not cached, skipping Item Loot feature checks")
		return
	end

	-- Bag and bank counts: ask for 5 of an item the player does not hold, so everything
	-- beyond the bags is "elsewhere" and must show up as a warband or folded bank figure.
	local text = module:FormatBagBankCounts(info.itemLink, 5)
	runner:assertEqual(type(text), "string", "BagBank: FormatBagBankCounts returns text")
	if type(text) == "string" then
		runner:assertEqual(text:find("Icons/BagCount", 1, true) ~= nil, true, "BagBank: shows the bag icon")
		if G_RLF.WoWAPI.ItemLoot.HasAtlas("warbands-icon") then
			runner:assertEqual(text:find("warbands-icon", 1, true) ~= nil, true, "BagBank: shows the warband atlas")
		else
			runner:assertEqual(
				text:find("Icons/BankCount", 1, true) ~= nil,
				true,
				"BagBank: folds the warband count into the bank without the atlas"
			)
		end
	end

	-- Quest-starting detection runs against this item's real tooltip.
	if type(info.IsQuestItem) == "function" then
		runner:runTestSafely(function()
			assert(type(info:StartsQuest()) == "boolean", "StartsQuest did not return a boolean")
			assert(type(info:IsQuestItem()) == "boolean", "IsQuestItem did not return a boolean")
		end, "QuestStart: ItemInfo:StartsQuest on a real item")
	end

	-- A highlight color rides the payload onto the element the row reads.
	local payload = module:BuildPayload(info, 1)
	if payload then
		payload.highlightColor = { 0.64, 0.21, 0.93 }
		local e = G_RLF.LootElementBase:fromPayload(payload)
		runner:assertEqual(
			e.highlightColor ~= nil and e.highlightColor[1] == 0.64 and e.highlightColor[3] == 0.93,
			true,
			"Highlight: color carried from payload to element"
		)
	end
end

--- Exercises the PartyLoot BuildPayload → fromPayload → Show pipeline directly.
local function runPartyLootIntegrationTest()
	local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.PartyLoot) --[[@as RLF_PartyLoot]]
	local LootElementBase = G_RLF.LootElementBase
	local info = TestMode.testItems[2]
	local amountLooted = 1
	local payload = module:BuildPayload(info, amountLooted, "player")
	if not payload then
		note("PartyLoot payload not created, something went wrong")
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
		rollDuration = 60000, -- ms, like START_LOOT_ROLL
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

--- Resolve the loot roll row the integration test showed, as if the roll had ended with
--- TestWar winning, instead of waiting out the whole simulated 60 second roll.
local function resolveLootRollIntegrationRow()
	local row
	for _, frame in G_RLF.LootDisplay:GetAllFrames() do
		row = row or frame:GetRow("it_loot_roll_test")
	end
	runner:assertEqual(row ~= nil, true, "LootRolls: the integration roll row is on screen")
	if not row then
		return
	end
	runner:assertEqual(row._resolved == true, false, "LootRolls: the roll row is still open before it resolves")
	runner:runTestSafely(function()
		row:SetRollResults({
			lootListID = 1,
			itemHyperlink = "|cff0070dd|Hitem:14344::::::::60:::::|h[Large Brilliant Shard]|h|r",
			rollInfos = {
				{
					playerName = "TestWar",
					playerClass = "WARRIOR",
					state = 0,
					roll = 87,
					isWinner = true,
					isSelf = false,
				},
				{
					playerName = "TestMage",
					playerClass = "MAGE",
					state = 3,
					roll = 42,
					isWinner = false,
					isSelf = false,
				},
				{ playerName = "You", playerClass = "HUNTER", state = 5, roll = nil, isWinner = false, isSelf = true },
			},
			currentLeader = { playerName = "TestWar", playerClass = "WARRIOR", roll = 87 },
			winner = {
				playerName = "TestWar",
				playerClass = "WARRIOR",
				state = 0,
				roll = 87,
				isWinner = true,
				isSelf = false,
			},
			allPassed = false,
			startTime = 0,
			duration = 60,
		})
	end, "LootRolls: SetRollResults with a winner")
	runner:assertEqual(row._resolved, true, "LootRolls: the roll row resolves when a winner is known")
	runner:assertEqual(row._isLootRollRow, false, "LootRolls: a resolved row behaves as a normal row")
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
		note("Currency payload not created, something went wrong")
		return accepts
	end
	local e = LootElementBase:fromPayload(payload)
	runner:runTestSafely(e.Show, "LootDisplay: Currency", e)
	accepts = accepts + 1
	payload = module:BuildPayload(testObj.link, testObj.info, testObj.basicInfo)
	if not payload then
		note("Currency update payload not created, something went wrong")
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
		note("Reputation payload not created, something went wrong")
		return accepts
	end
	local e = LootElementBase:fromPayload(payload)
	runner:runTestSafely(e.Show, "LootDisplay: Reputation", e)
	accepts = accepts + 1

	-- Second call with same key should stack/update the existing row
	local payload2 = module:BuildPayload(testFactionData)
	if not payload2 then
		note("Reputation update payload not created, something went wrong")
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
		note("Transmog payload not created, something went wrong")
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
		note("Integration test not ready")
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
		note("Integration test not ready")
		return
	end

	runner:reset()
	TestMode:BeginTestRun("Integration Test")
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
	if G_RLF:IsRetail() and not G_RLF:IsForever() then
		newRowsExpected = newRowsExpected + runTravelPointsIntegrationTest()
	end
	newRowsExpected = newRowsExpected + runItemLootIntegrationTest()
	runItemFeatureChecks()
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
					if lootRollsModule:IsEnabled() then
						resolveLootRollIntegrationRow()
					end
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
