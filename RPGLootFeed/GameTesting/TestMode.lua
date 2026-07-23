---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local C = LibStub("C_Everywhere")

---@class RLF_TestMode: RLF_Module, AceEvent-3.0
---@field public SmokeTest fun(s: RLF_TestMode)
---@field public IntegrationTest fun(s: RLF_TestMode)
local TestMode = G_RLF.RLF:NewModule(G_RLF.SupportModule.TestMode, "AceEvent-3.0")

local logger
local allItemsInitialized = false
local allCurrenciesInitialized = false
local allFactionsInitialized = false
local isLootDisplayReady = false
local pendingRequests = {}
TestMode.testItems = {}
TestMode.testCurrencies = {}
TestMode.testFactions = {}

local function idExistsInTable(id, table)
	for _, item in pairs(table) do
		if item.id and item.id == id then
			return true
		end
		if item.itemId and item.itemId == id then
			return true
		end
	end
	return false
end

local function anyPendingRequests()
	for _, v in pairs(pendingRequests) do
		if v ~= nil then
			return true
		end
	end
	return false
end

local function signalIntegrationTestReady()
	if
		not TestMode.integrationTestReady
		and allItemsInitialized
		and isLootDisplayReady
		and allCurrenciesInitialized
		and allFactionsInitialized
	then
		--@alpha@
		TestMode:IntegrationTestReady()
		--@end-alpha@
	end
end

local function getItem(id)
	local info = G_RLF.ItemInfo:new(id, C.Item.GetItemInfo(id))
	local isCached = info ~= nil
	if isCached then
		if not idExistsInTable(id, TestMode.testItems) then
			pendingRequests[id] = nil
			table.insert(TestMode.testItems, info)
		end
	else
		pendingRequests[id] = true
	end
end

local function tconcat(t1, t2)
	for i = 1, #t2 do
		t1[#t1 + 1] = t2[i]
	end
	return t1
end

local testItemIds = { 2589, 2592, 1515, 730 }
if G_RLF:IsRetail() then
	tconcat(testItemIds, { 50818, 128827, 219325, 34494 })
elseif G_RLF:IsClassic() then
	tconcat(testItemIds, { 233620 })
elseif G_RLF:IsCataClassic() then
	tconcat(testItemIds, { 71086 })
	-- TODO: Add MoP Classic test items
	--elseif G_RLF:IsMoPClassic() then
	--	tconcat(testItemIds, { 123456 })
end
local function initializeTestItems()
	for _, id in pairs(testItemIds) do
		getItem(id)
	end

	if #TestMode.testItems == #testItemIds then
		allItemsInitialized = true
		signalIntegrationTestReady()
		return
	end
end

local testCurrencyIds = {}
if G_RLF:IsRetail() then
	tconcat(testCurrencyIds, { 2245, 1191, 1828, 1792, 1755, 1580, 1273, 1166, 515, 241, 1813, 2778, 3089, 1101, 1704 })
elseif GetExpansionLevel() == G_RLF.Expansion.WOTLK then
	tconcat(testCurrencyIds, { 221, 241, 126, 81 })
elseif GetExpansionLevel() == G_RLF.Expansion.CATA then
	tconcat(testCurrencyIds, { 391, 416, 401, 402 })
elseif GetExpansionLevel() == G_RLF.Expansion.MOP then
	tconcat(testCurrencyIds, { 777, 738, 697, 677, 789 })
end
local function initializeTestCurrencies()
	for _, id in pairs(testCurrencyIds) do
		if not idExistsInTable(id, TestMode.testCurrencies) then
			local info = C.CurrencyInfo.GetCurrencyInfo(id)
			local link
			if G_RLF:IsRetail() then
				link = C.CurrencyInfo.GetCurrencyLink(id)
			else
				link = C.CurrencyInfo.GetCurrencyLink(id, 100)
			end
			local basicInfo = C.CurrencyInfo.GetBasicCurrencyInfo(id, 100)
			if info and link and info.currencyID and info.iconFileID then
				table.insert(TestMode.testCurrencies, {
					link = link,
					info = info,
					basicInfo = basicInfo,
				})
			end
		end
	end

	allCurrenciesInitialized = true
	signalIntegrationTestReady()
end

local numTestFactions = 3
local function initializeTestFactions()
	local j, i = 1, 1
	while j <= numTestFactions do
		i = i + 1
		local factionInfo
		if G_RLF:IsRetail() then
			factionInfo = C_Reputation.GetFactionDataByIndex(i)
		-- So far up through MoP Classic, there is no C_Reputation.GetFactionDataByIndex
		else
			factionInfo = G_RLF.ClassicToRetail:ConvertFactionInfoByIndex(i)
		end
		if factionInfo then
			if
				factionInfo.name
				and factionInfo.name ~= ""
				and (not factionInfo.isHeader or factionInfo.isHeaderWithRep)
			then
				table.insert(TestMode.testFactions, factionInfo.name)
				j = j + 1
			end
		end
	end

	allFactionsInitialized = true
	signalIntegrationTestReady()
end

function TestMode:OnInitialize()
	isLootDisplayReady = false
	allItemsInitialized = false
	self.testCurrencies = {}
	self.testItems = {}
	self.testFactions = {}
	self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	RunNextFrame(function()
		self:InitializeTestData()
	end)
	--@alpha@
	RunNextFrame(function()
		self:SmokeTest()
	end)
	--@end-alpha@
end

function TestMode:IntegrationTestReady()
	self.integrationTestReady = true
end

function TestMode:OnLootDisplayReady()
	isLootDisplayReady = true
	signalIntegrationTestReady()
end

local failedRetrievals = {}
function TestMode:GET_ITEM_INFO_RECEIVED(eventName, itemID, success)
	if not pendingRequests[itemID] then
		return
	end

	if not success then
		failedRetrievals[itemID] = (failedRetrievals[itemID] or 0) + 1
		if failedRetrievals[itemID] >= 5 then
			--@alpha@
			error("Failed to load item 5 times: " .. itemID)
			--@end-alpha@
			return
		end
	end

	getItem(itemID)

	if #self.testItems == #testItemIds and not anyPendingRequests() then
		allItemsInitialized = true
		signalIntegrationTestReady()
	end
end

local function generateRandomLoot()
	if #TestMode.testItems ~= #testItemIds then
		initializeTestItems()
	end

	if #TestMode.testCurrencies ~= #testCurrencyIds then
		initializeTestCurrencies()
	end
	-- Randomly decide whether to generate an item or currency
	local numberOfRowsToGenerate = math.random(1, 5)
	for i = 1, numberOfRowsToGenerate do
		local rng = math.random()

		G_RLF:LogDebug("Random number generated: " .. rng, addonName)

		if rng >= 0.8 then
			local experienceGained = math.random(100, 10000)
			local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Experience) --[[@as RLF_Experience]]
			local payload = module:BuildPayload(experienceGained)
			if payload then
				G_RLF.LootElementBase:fromPayload(payload):Show()
			end
			G_RLF:LogDebug("Experience gained: " .. experienceGained, addonName)
		end

		if rng <= 0.2 then
			local copper = math.random(1, 100000000)
			local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Money) --[[@as RLF_Money]]
			local payload = module:BuildPayload(copper)
			if not payload then
				G_RLF:LogError("Failed to create Money payload", addonName)
			else
				G_RLF.LootElementBase:fromPayload(payload):Show()
				module:PlaySoundIfEnabled()
				G_RLF:LogDebug("Copper gained: " .. copper, addonName)
			end
		end

		-- 50% chance to show items
		if rng > 0.2 and rng <= 0.7 then
			local info = TestMode.testItems[math.random(#TestMode.testItems)]
			local amountLooted = math.random(1, 5)
			local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.ItemLoot) --[[@as RLF_ItemLoot]]
			local payload = module:BuildPayload(info, amountLooted)
			if payload then
				G_RLF.LootElementBase:fromPayload(payload):Show(info.itemName, info.itemQuality)
				if module.PlaySoundIfEnabled then
					module:PlaySoundIfEnabled(payload)
				end
				G_RLF:LogDebug("Item looted: " .. info.itemName, addonName)
			end

			-- 10% chance of item loot to show up as a party member
			if rng < 0.3 then
				local unit = "player"
				local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.PartyLoot) --[[@as RLF_PartyLoot]]
				local payload = module:BuildPayload(info, amountLooted, unit)
				if payload then
					G_RLF.LootElementBase:fromPayload(payload):Show(info.itemName, info.itemQuality)
					G_RLF:LogDebug("Party Item looted: " .. info.itemName, addonName)
				end
			end

			-- 15% chance to show currency
		elseif rng > 0.7 and rng <= 0.85 then
			if GetExpansionLevel() >= G_RLF.Expansion.WOTLK then
				local currency = TestMode.testCurrencies[math.random(#TestMode.testCurrencies)]
				local amountLooted = math.random(1, 500)
				local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Currency) --[[@as RLF_Currency]]
				local payload = module:BuildPayload(currency.link, currency.info, currency.basicInfo)
				if not payload then
					G_RLF:LogError("Failed to create Currency payload", addonName)
				else
					G_RLF.LootElementBase:fromPayload(payload):Show()
					G_RLF:LogDebug("Currency looted: " .. currency.info.name, addonName)
				end
			end

			-- 10% chance to show reputation (least frequent)
		elseif rng > 0.85 then
			local reputationGained = math.random(10, 100)
			local factionName = TestMode.testFactions[math.random(#TestMode.testFactions)]
			local module = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Reputation) --[[@as RLF_Reputation]]
			local msg = string.format(_G["FACTION_STANDING_INCREASED"], factionName, reputationGained)
			module:CHAT_MSG_COMBAT_FACTION_CHANGE("CHAT_MSG_COMBAT_FACTION_CHANGE", msg)
			G_RLF:LogDebug("Reputation gained: " .. reputationGained, addonName)
		end
	end
end

function TestMode:InitializeTestData()
	G_RLF:fn(initializeTestItems)
	G_RLF:fn(initializeTestCurrencies)
	G_RLF:fn(initializeTestFactions)
end

function TestMode:ToggleTestMode()
	if not logger then
		logger = G_RLF.RLF:GetModule(G_RLF.SupportModule.Logger)
	end
	if not isLootDisplayReady then
		error("LootDisplay did not signal it was ready (or we didn't receive the signal) - cannot start TestMode")
	end
	if self.testMode then
		-- Stop test mode
		self.testMode = false
		if self.testTimer then
			self.testTimer:Cancel()
			self.testTimer = nil
		end
		G_RLF:Print(G_RLF.L["Test Mode Disabled"])
		G_RLF:LogDebug("Test Mode Disabled", addonName)
	else
		-- Start test mode
		self.testMode = true
		G_RLF:Print(G_RLF.L["Test Mode Enabled"])
		G_RLF:LogDebug("Test Mode Enabled", addonName)
		self.testTimer = C.Timer.NewTicker(1.5, function()
			G_RLF:fn(generateRandomLoot)
		end)
	end
end
