---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local C = LibStub("C_Everywhere")

--@alpha@
-- trunk-ignore-begin(no-invalid-prints/invalid-print)
---@type RLF_TestMode
local TestMode = G_RLF.RLF:GetModule(G_RLF.SupportModule.TestMode) --[[@as RLF_TestMode]]
local runner = G_RLF.GameTestRunner:new("Smoke Test", {
	printHeader = function(msg)
		G_RLF:Print(msg)
	end,
	printLine = print,
	raiseError = error,
})

local function testGetItemInfo(id)
	local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expansionID, _, isCraftingReagent =
		C.Item.GetItemInfo(id)
	runner:assertEqual(itemName ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").itemName")
	runner:assertEqual(itemLink ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").itemLink")
	runner:assertEqual(itemQuality ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").itemQuality")
	runner:assertEqual(itemLevel ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").itemLevel")
	runner:assertEqual(itemMinLevel ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").itemMinLevel")
	runner:assertEqual(itemType ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").itemType")
	runner:assertEqual(itemSubType ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").itemSubType")
	runner:assertEqual(itemStackCount ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").itemStackCount")
	runner:assertEqual(itemEquipLoc ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").itemEquipLoc")
	runner:assertEqual(itemTexture ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").itemTexture")
	runner:assertEqual(sellPrice ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").sellPrice")
	runner:assertEqual(classID ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").classID")
	runner:assertEqual(subclassID ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").subclassID")
	runner:assertEqual(bindType ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").bindType")
	runner:assertEqual(expansionID ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").expansionID")
	runner:assertEqual(isCraftingReagent ~= nil, true, "Global: C.Item.GetItemInfo(" .. id .. ").isCraftingReagent")
end

local function testWoWGlobals()
	runner:assertEqual(type(EventRegistry), "table", "Global: EventRegistry")
	runner:assertEqual(type(C.CVar.SetCVar), "function", "Global C.CVar.SetCVar")
	local value, defaultValue, isStoredServerAccount, isStoredServerCharacter, isLockedFromUser, isSecure, isReadonly =
		C.CVar.GetCVarInfo("autoLootDefault")
	runner:assertEqual(value ~= nil, true, "Global: C.CVar.GetCVarInfo autoLootDefault value")
	runner:assertEqual(defaultValue ~= nil, true, "Global: C.CVar.GetCVarInfo autoLootDefault defaultValue")
	runner:assertEqual(
		isStoredServerAccount ~= nil,
		true,
		"Global: C.CVar.GetCVarInfo autoLootDefault isStoredServerAccount"
	)
	runner:assertEqual(
		isStoredServerCharacter ~= nil,
		true,
		"Global: C.CVar.GetCVarInfo autoLootDefault isStoredServerCharacter"
	)
	runner:assertEqual(isLockedFromUser ~= nil, true, "Global: C.CVar.GetCVarInfo autoLootDefault isLockedFromUser")
	runner:assertEqual(isSecure ~= nil, true, "Global: C.CVar.GetCVarInfo autoLootDefault isSecure")
	runner:assertEqual(isReadonly ~= nil, true, "Global: C.CVar.GetCVarInfo autoLootDefault isReadonly")
	runner:assertEqual(type(ChatFrameUtil.ForEachChatFrame), "function", "Global: ChatFrameUtil.ForEachChatFrame")
	runner:assertEqual(type(ChatFrame_RemoveMessageGroup), "function", "Global: ChatFrame_RemoveMessageGroup")
	runner:assertEqual(type(Enum.ItemQuality), "table", "Global: Enum.ItemQuality")
	runner:assertEqual(type(GetFonts), "function", "Global: GetFonts")

	if GetExpansionLevel() > G_RLF.Expansion.CLASSIC then
		runner:assertEqual(type(GetPlayerGuid), "function", "Global: GetPlayerGuid")
	end

	if GetExpansionLevel() >= G_RLF.Expansion.DF then
		runner:assertEqual(type(GetNameAndServerNameFromGUID), "function", "Global: GetNameAndServerNameFromGUID")
	end

	if GetExpansionLevel() >= G_RLF.Expansion.WOD then
		runner:assertEqual(type(BossBanner), "table", "Global: BossBanner")
	end

	runner:assertEqual(type(LootAlertSystem.AddAlert), "function", "Global: LootAlertSystem.AddAlert")

	if GetExpansionLevel() >= G_RLF.Expansion.WOTLK then
		runner:assertEqual(type(C.CurrencyInfo.GetCurrencyInfo), "function", "Global: C.CurrencyInfo.GetCurrencyInfo")
		local info = C.CurrencyInfo.GetCurrencyInfo(241)
		runner:assertEqual(info ~= nil, true, "Global: C.CurrencyInfo.GetCurrencyInfo(241)")
		runner:assertEqual(info.description ~= nil, true, "Global: C.CurrencyInfo.GetCurrencyInfo(241).description")
		runner:assertEqual(info.iconFileID ~= nil, true, "Global: C.CurrencyInfo.GetCurrencyInfo(241).iconFileID")
		runner:assertEqual(info.currencyID ~= nil, true, "Global: C.CurrencyInfo.GetCurrencyInfo(241).currencyID")
	end
	if GetExpansionLevel() >= G_RLF.Expansion.SL then
		runner:assertEqual(C.CurrencyInfo.GetCurrencyLink(1813) ~= nil, true, "Global: C.CurrencyInfo.GetCurrencyLink")
	end

	runner:assertEqual(type(UnitXP), "function", "Global: UnitXP")
	runner:assertEqual(type(UnitXPMax), "function", "Global: UnitXPMax")
	runner:assertEqual(type(UnitLevel), "function", "Global: UnitLevel")
	runner:assertEqual(type(C.Item.GetItemInfo), "function", "Global: C.Item.GetItemInfo")
	runner:assertEqual(type(GetInventoryItemLink), "function", "Global: GetInventoryItemLink")
	local legSlot = G_RLF.equipSlotMap["INVTYPE_LEGS"] --[[@as number]]
	local link = GetInventoryItemLink("player", legSlot)
	local isCached = C.Item.GetItemInfo(link) ~= nil
	if not isCached then
		G_RLF:Print("Item not cached, skipping GetItemInfo test")
	else
		testGetItemInfo(link)
	end
	runner:assertEqual(type(GetMoney), "function", "Global: GetMoney")
	runner:assertEqual(
		type(C.CurrencyInfo.GetCoinTextureString),
		"function",
		"Global: C.CurrencyInfo.GetCoinTextureString"
	)
	runner:assertEqual(type(FACTION_STANDING_INCREASED), "string", "Global: FACTION_STANDING_INCREASED")
	runner:assertEqual(
		type(FACTION_STANDING_INCREASED_ACH_BONUS),
		"string",
		"Global: FACTION_STANDING_INCREASED_ACH_BONUS"
	)
	runner:assertEqual(type(FACTION_STANDING_INCREASED_BONUS), "string", "Global: FACTION_STANDING_INCREASED_BONUS")
	runner:assertEqual(
		type(FACTION_STANDING_INCREASED_DOUBLE_BONUS),
		"string",
		"Global: FACTION_STANDING_INCREASED_DOUBLE_BONUS"
	)
	runner:assertEqual(type(FACTION_STANDING_DECREASED), "string", "Global: FACTION_STANDING_DECREASED")

	if GetExpansionLevel() >= G_RLF.Expansion.SL then
		runner:assertEqual(
			type(FACTION_STANDING_INCREASED_ACCOUNT_WIDE),
			"string",
			"Global: FACTION_STANDING_INCREASED_ACCOUNT_WIDE"
		)
		runner:assertEqual(
			type(FACTION_STANDING_DECREASED_ACCOUNT_WIDE),
			"string",
			"Global: FACTION_STANDING_DECREASED_ACCOUNT_WIDE"
		)
	end

	if GetExpansionLevel() >= G_RLF.Expansion.TWW then
		runner:assertEqual(
			type(FACTION_STANDING_INCREASED_ACH_BONUS_ACCOUNT_WIDE),
			"string",
			"Global: FACTION_STANDING_INCREASED_ACH_BONUS_ACCOUNT_WIDE"
		)
	end

	runner:assertEqual(type(C.Reputation), "table", "Global: C.Reputation")

	if GetExpansionLevel() >= G_RLF.Expansion.DF then
		runner:assertEqual(type(C.Reputation.IsMajorFaction), "function", "Global: C.Reputation.IsMajorFaction")
		runner:assertEqual(type(ACCOUNT_WIDE_FONT_COLOR), "table", "Global: ACCOUNT_WIDE_FONT_COLOR")
	end

	if GetExpansionLevel() >= G_RLF.Expansion.LEGION then
		runner:assertEqual(type(C.Reputation.IsFactionParagon), "function", "Global: C.Reputation.IsFactionParagon")
	end

	if GetExpansionLevel() >= G_RLF.Expansion.TWW then
		runner:assertEqual(type(C.Reputation.GetFactionDataByID), "function", "Global: C.Reputation.GetFactionDataByID")
	end

	runner:assertEqual(type(FACTION_GREEN_COLOR), "table", "Global: FACTION_GREEN_COLOR")
	runner:assertEqual(type(FACTION_BAR_COLORS), "table", "Global: FACTION_BAR_COLORS")
end

--- Feature module name → DB feature key mapping
--- These keys correspond to db.global.frames[frameId].features[key]
local featureDbKeyMap = {
	[G_RLF.FeatureModule.ItemLoot] = "itemLoot",
	[G_RLF.FeatureModule.PartyLoot] = "partyLoot",
	[G_RLF.FeatureModule.Currency] = "currency",
	[G_RLF.FeatureModule.Money] = "money",
	[G_RLF.FeatureModule.Experience] = "experience",
	[G_RLF.FeatureModule.Reputation] = "reputation",
	[G_RLF.FeatureModule.Profession] = "profession",
	[G_RLF.FeatureModule.TravelPoints] = "travelPoints",
	[G_RLF.FeatureModule.Transmog] = "transmog",
	[G_RLF.FeatureModule.LootRolls] = "lootRolls",
}

local function testModuleRegistration()
	for enumKey, moduleName in pairs(G_RLF.FeatureModule) do
		local module = G_RLF.RLF:GetModule(moduleName, true)
		runner:assertEqual(module ~= nil, true, "FeatureModule registered: " .. moduleName)
	end

	for enumKey, moduleName in pairs(G_RLF.SupportModule) do
		local module = G_RLF.RLF:GetModule(moduleName, true)
		runner:assertEqual(module ~= nil, true, "SupportModule registered: " .. moduleName)
	end

	for enumKey, moduleName in pairs(G_RLF.BlizzModule) do
		local module = G_RLF.RLF:GetModule(moduleName, true)
		runner:assertEqual(module ~= nil, true, "BlizzModule registered: " .. moduleName)
	end
end

local function testFeatureEnabledState()
	for moduleName, featureKey in pairs(featureDbKeyMap) do
		local dbEnabled = G_RLF.DbAccessor:IsFeatureNeededByAnyFrame(featureKey)
		local module = G_RLF.RLF:GetModule(moduleName, true)
		if module then
			local moduleEnabled = module:IsEnabled()
			-- Some features have additional guards (e.g., expansion checks)
			-- so moduleEnabled can be false even when dbEnabled is true.
			-- But if dbEnabled is false, moduleEnabled must also be false.
			if not dbEnabled then
				runner:assertEqual(moduleEnabled, false, "Feature disabled in config is disabled: " .. moduleName)
			else
				runner:assertEqual(type(moduleEnabled), "boolean", "Feature enabled state is boolean: " .. moduleName)
			end
		end
	end
end

local function testDbStructure()
	runner:assertEqual(type(G_RLF.db), "table", "DB: G_RLF.db exists")
	runner:assertEqual(type(G_RLF.db.global), "table", "DB: G_RLF.db.global exists")

	-- Metadata
	runner:assertEqual(type(G_RLF.db.global.migrationVersion), "number", "DB: migrationVersion is number")
	runner:assertEqual(type(G_RLF.db.global.guid), "string", "DB: guid is string")
	runner:assertEqual(#G_RLF.db.global.guid > 0, true, "DB: guid is non-empty")

	-- Required top-level config tables (non-feature globals)
	local requiredGlobalKeys = {
		"misc",
		"lootHistory",
		"tooltips",
		"minimap",
		"blizzOverrides",
	}
	for _, key in ipairs(requiredGlobalKeys) do
		runner:assertEqual(type(G_RLF.db.global[key]), "table", "DB: global." .. key .. " exists")
	end

	-- Per-frame structure
	runner:assertEqual(type(G_RLF.db.global.frames), "table", "DB: global.frames exists")
	runner:assertEqual(type(G_RLF.db.global.frames[1]), "table", "DB: global.frames[1] exists")
	local frame1 = G_RLF.db.global.frames[1]
	runner:assertEqual(type(frame1.positioning), "table", "DB: frames[1].positioning exists")
	runner:assertEqual(type(frame1.sizing), "table", "DB: frames[1].sizing exists")
	runner:assertEqual(type(frame1.styling), "table", "DB: frames[1].styling exists")
	runner:assertEqual(type(frame1.animations), "table", "DB: frames[1].animations exists")
	runner:assertEqual(type(frame1.features), "table", "DB: frames[1].features exists")

	-- Each feature config has an enabled flag under frames[1]
	for moduleName, featureKey in pairs(featureDbKeyMap) do
		local featureConfig = G_RLF.DbAccessor:Feature(1, featureKey)
		runner:assertEqual(featureConfig ~= nil, true, "DB: frames[1].features." .. featureKey .. " exists")
		if featureConfig then
			runner:assertEqual(type(featureConfig.enabled), "boolean", "DB: " .. featureKey .. ".enabled is boolean")
			runner:assertEqual(
				type(featureConfig.backgroundOverride),
				"table",
				"DB: " .. featureKey .. ".backgroundOverride exists"
			)
			if type(featureConfig.backgroundOverride) == "table" then
				local override = featureConfig.backgroundOverride
				runner:assertEqual(
					type(override.enabled),
					"boolean",
					"DB: " .. featureKey .. ".backgroundOverride.enabled is boolean"
				)
				runner:assertEqual(
					type(override.gradientStart),
					"table",
					"DB: " .. featureKey .. ".backgroundOverride.gradientStart exists"
				)
				runner:assertEqual(
					type(override.gradientEnd),
					"table",
					"DB: " .. featureKey .. ".backgroundOverride.gradientEnd exists"
				)
				runner:assertEqual(
					type(override.textureColor),
					"table",
					"DB: " .. featureKey .. ".backgroundOverride.textureColor exists"
				)
			end
		end
	end
end

local function testMigrationIntegrity()
	-- All migration versions 1..N are registered
	local highestVersion = 0
	for version, migration in pairs(G_RLF.migrations) do
		if version > highestVersion then
			highestVersion = version
		end
	end
	runner:assertEqual(highestVersion > 0, true, "Migrations: at least one migration exists")

	for v = 1, highestVersion do
		runner:assertEqual(G_RLF.migrations[v] ~= nil, true, "Migrations: v" .. v .. " registered")
		runner:assertEqual(type(G_RLF.migrations[v].run), "function", "Migrations: v" .. v .. " has run()")
	end

	-- migrationVersion should equal the highest registered version
	runner:assertEqual(
		G_RLF.db.global.migrationVersion,
		highestVersion,
		"Migrations: DB version matches highest migration"
	)
end

local function testLootDisplayFrame()
	-- Main frame must exist
	local mainFrame = G_RLF.RLF_MainLootFrame
	runner:assertEqual(mainFrame ~= nil, true, "LootDisplay: MainLootFrame exists")
	if not mainFrame then
		return
	end

	runner:assertEqual(mainFrame.frameType, G_RLF.Frames.MAIN, "LootDisplay: MainLootFrame.frameType is MAIN")
	runner:assertEqual(type(mainFrame.rowHistory), "table", "LootDisplay: MainLootFrame.rowHistory is table")
	runner:assertEqual(type(mainFrame.rows), "table", "LootDisplay: MainLootFrame.rows is table")
	runner:assertEqual(type(mainFrame.keyRowMap), "table", "LootDisplay: MainLootFrame.keyRowMap is table")

	-- Validate all configured frames have a live widget
	local LootDisplay = G_RLF.RLF:GetModule(G_RLF.SupportModule.LootDisplay, true)
	if LootDisplay then
		for id in pairs(G_RLF.db.global.frames) do
			local frame = LootDisplay:GetFrame(id)
			runner:assertEqual(frame ~= nil, true, "LootDisplay: frame " .. id .. " has a live widget")
			if frame then
				runner:assertEqual(frame.frameType, id, "LootDisplay: frame " .. id .. " has correct frameType")
			end
		end
	end

	-- LootDisplay module should be enabled and registered for messages
	local lootDisplayModule = G_RLF.RLF:GetModule(G_RLF.SupportModule.LootDisplay, true)
	runner:assertEqual(lootDisplayModule ~= nil, true, "LootDisplay: module exists")
	if lootDisplayModule then
		runner:assertEqual(lootDisplayModule:IsEnabled(), true, "LootDisplay: module is enabled")
	end
end

local function testTestModeDataReadiness()
	-- TestMode itself should be accessible
	runner:assertEqual(type(TestMode.testItems), "table", "TestMode: testItems is table")
	runner:assertEqual(type(TestMode.testCurrencies), "table", "TestMode: testCurrencies is table")
	runner:assertEqual(type(TestMode.testFactions), "table", "TestMode: testFactions is table")

	-- At smoke test time (RunNextFrame after OnInitialize), items may still be loading.
	-- Validate structure of any items that ARE already cached.
	for i, item in ipairs(TestMode.testItems) do
		runner:assertEqual(item.itemName ~= nil, true, "TestMode: testItems[" .. i .. "].itemName")
		runner:assertEqual(item.itemLink ~= nil, true, "TestMode: testItems[" .. i .. "].itemLink")
		runner:assertEqual(type(item.itemQuality), "number", "TestMode: testItems[" .. i .. "].itemQuality")
		runner:assertEqual(item.itemTexture ~= nil, true, "TestMode: testItems[" .. i .. "].itemTexture")
	end

	for i, curr in ipairs(TestMode.testCurrencies) do
		runner:assertEqual(curr.link ~= nil, true, "TestMode: testCurrencies[" .. i .. "].link")
		runner:assertEqual(type(curr.info), "table", "TestMode: testCurrencies[" .. i .. "].info")
		runner:assertEqual(curr.info.currencyID ~= nil, true, "TestMode: testCurrencies[" .. i .. "].info.currencyID")
		runner:assertEqual(curr.info.iconFileID ~= nil, true, "TestMode: testCurrencies[" .. i .. "].info.iconFileID")
	end

	for i, factionName in ipairs(TestMode.testFactions) do
		runner:assertEqual(type(factionName), "string", "TestMode: testFactions[" .. i .. "] is string")
		runner:assertEqual(#factionName > 0, true, "TestMode: testFactions[" .. i .. "] is non-empty")
	end
end

local function testElementConstructors()
	-- Test element constructors that don't require async data.
	-- Each should return a table with valid LootElementBase fields.

	-- Experience (migrated: BuildPayload → fromPayload)
	local xpModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Experience, true)
	if xpModule and xpModule:IsEnabled() then
		local payload = xpModule:BuildPayload(1000)
		runner:assertEqual(payload ~= nil, true, "Element: Experience payload created")
		if payload then
			runner:assertEqual(payload.type, "Experience", "Element: Experience payload.type")
			runner:assertEqual(payload.key, "EXPERIENCE", "Element: Experience payload.key")
			runner:assertEqual(payload.quantity, 1000, "Element: Experience payload.quantity")
			runner:assertEqual(type(payload.textFn), "function", "Element: Experience payload.textFn")
			runner:assertEqual(type(payload.itemCountFn), "function", "Element: Experience payload.itemCountFn")
			runner:assertEqual(type(payload.moduleRef), "table", "Element: Experience payload.moduleRef")

			local e = G_RLF.LootElementBase:fromPayload(payload)
			runner:assertEqual(e ~= nil, true, "Element: Experience element created")
			if e then
				runner:assertEqual(e.type, "Experience", "Element: Experience.type")
				runner:assertEqual(e.key, "EXPERIENCE", "Element: Experience.key")
				runner:assertEqual(e.quantity, 1000, "Element: Experience.quantity")
				runner:assertEqual(type(e.textFn), "function", "Element: Experience.textFn")
				runner:assertEqual(type(e.itemCountFn), "function", "Element: Experience.itemCountFn")
				runner:assertEqual(type(e.IsEnabled), "function", "Element: Experience.IsEnabled")
				runner:assertEqual(type(e.Show), "function", "Element: Experience.Show")
			end
		end
	end

	-- Money
	local moneyModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Money, true)
	if moneyModule and moneyModule:IsEnabled() then
		local payload = moneyModule:BuildPayload(12345)
		runner:assertEqual(payload ~= nil, true, "BuildPayload: Money created")
		if payload then
			local e = G_RLF.LootElementBase:fromPayload(payload)
			runner:assertEqual(e.type, "Money", "Element: Money.type")
			runner:assertEqual(e.key, "MONEY_LOOT", "Element: Money.key")
			runner:assertEqual(e.quantity, 12345, "Element: Money.quantity")
			runner:assertEqual(type(e.textFn), "function", "Element: Money.textFn")
			runner:assertEqual(type(e.IsEnabled), "function", "Element: Money.IsEnabled")
			runner:assertEqual(type(e.Show), "function", "Element: Money.Show")
		end
	end

	-- Professions
	local profModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Profession, true)
	if profModule and profModule:IsEnabled() then
		local payload = profModule:BuildPayload("TestCooking", "Cooking", G_RLF.DefaultIcons.PROFESSION, 5, 1)
		runner:assertEqual(payload ~= nil, true, "BuildPayload: Professions created")
		if payload then
			local e = G_RLF.LootElementBase:fromPayload(payload)
			runner:assertEqual(e.type, "Professions", "Element: Professions.type")
			runner:assertEqual(e.key, "PROF_TestCooking", "Element: Professions.key")
			runner:assertEqual(e.quantity, 1, "Element: Professions.quantity")
			runner:assertEqual(type(e.textFn), "function", "Element: Professions.textFn")
			runner:assertEqual(type(e.itemCountFn), "function", "Element: Professions.itemCountFn")
			runner:assertEqual(type(e.IsEnabled), "function", "Element: Professions.IsEnabled")
			runner:assertEqual(type(e.Show), "function", "Element: Professions.Show")
		end
	end

	-- TravelPoints (Retail only)
	if G_RLF:IsRetail() then
		local tpModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.TravelPoints, true)
		if tpModule and tpModule:IsEnabled() then
			local payload = tpModule:BuildPayload(50)
			runner:assertEqual(payload ~= nil, true, "BuildPayload: TravelPoints created")
			if payload then
				local e = G_RLF.LootElementBase:fromPayload(payload)
				runner:assertEqual(e.type, "TravelPoints", "Element: TravelPoints.type")
				runner:assertEqual(e.key, "TRAVELPOINTS", "Element: TravelPoints.key")
				runner:assertEqual(e.quantity, 50, "Element: TravelPoints.quantity")
				runner:assertEqual(type(e.textFn), "function", "Element: TravelPoints.textFn")
				runner:assertEqual(type(e.IsEnabled), "function", "Element: TravelPoints.IsEnabled")
				runner:assertEqual(type(e.Show), "function", "Element: TravelPoints.Show")
			end
		end
	end

	-- ItemLoot — only if test data is already cached (migrated: BuildPayload → fromPayload)
	local itemModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.ItemLoot, true)
	if itemModule and itemModule:IsEnabled() and #TestMode.testItems > 0 then
		local info = TestMode.testItems[1]
		local payload = itemModule:BuildPayload(info, 1)
		runner:assertEqual(payload ~= nil, true, "BuildPayload: ItemLoot created")
		if payload then
			runner:assertEqual(payload.type, "ItemLoot", "BuildPayload: ItemLoot.type")
			runner:assertEqual(payload.isLink, true, "BuildPayload: ItemLoot.isLink")
			runner:assertEqual(payload.quantity, 1, "BuildPayload: ItemLoot.quantity")
			runner:assertEqual(type(payload.textFn), "function", "BuildPayload: ItemLoot.textFn")
			runner:assertEqual(type(payload.moduleRef), "table", "BuildPayload: ItemLoot.moduleRef")
			local e = G_RLF.LootElementBase:fromPayload(payload)
			runner:assertEqual(type(e.Show), "function", "BuildPayload: ItemLoot.Show")
		end
	end

	-- Currency — only if test data is already cached (migrated: BuildPayload → fromPayload)
	if GetExpansionLevel() >= G_RLF.Expansion.WOTLK then
		local currModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Currency, true)
		if currModule and currModule:IsEnabled() and #TestMode.testCurrencies > 0 then
			local testObj = TestMode.testCurrencies[1]
			testObj.basicInfo.displayAmount = 1
			local payload = currModule:BuildPayload(testObj.link, testObj.info, testObj.basicInfo)
			runner:assertEqual(payload ~= nil, true, "BuildPayload: Currency created")
			if payload then
				runner:assertEqual(payload.type, "Currency", "BuildPayload: Currency.type")
				runner:assertEqual(payload.isLink, true, "BuildPayload: Currency.isLink")
				runner:assertEqual(type(payload.textFn), "function", "BuildPayload: Currency.textFn")
				runner:assertEqual(type(payload.moduleRef), "table", "BuildPayload: Currency.moduleRef")
				local e = G_RLF.LootElementBase:fromPayload(payload)
				runner:assertEqual(type(e.Show), "function", "BuildPayload: Currency element.Show")
			end
		end
	end

	-- Reputation (migrated: BuildPayload → fromPayload)
	local repModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Reputation, true)
	if repModule and repModule:IsEnabled() then
		---@type UnifiedFactionData
		local testFactionData = {
			factionId = 99999,
			name = "Test Faction",
			delta = 250,
			icon = 132882,
			rank = "Honored",
			color = nil,
			quality = nil,
			contextInfo = "Test context",
		}
		local payload = repModule:BuildPayload(testFactionData)
		runner:assertEqual(payload ~= nil, true, "Element: Reputation payload created")
		if payload then
			runner:assertEqual(payload.type, "Reputation", "Element: Reputation payload.type")
			runner:assertEqual(payload.key, "REP_99999", "Element: Reputation payload.key")
			runner:assertEqual(payload.quantity, 250, "Element: Reputation payload.quantity")
			runner:assertEqual(type(payload.textFn), "function", "Element: Reputation payload.textFn")
			runner:assertEqual(type(payload.itemCountFn), "function", "Element: Reputation payload.itemCountFn")
			runner:assertEqual(type(payload.secondaryTextFn), "function", "Element: Reputation payload.secondaryTextFn")
			runner:assertEqual(type(payload.moduleRef), "table", "Element: Reputation payload.moduleRef")

			local e = G_RLF.LootElementBase:fromPayload(payload)
			runner:assertEqual(e ~= nil, true, "Element: Reputation element created")
			if e then
				runner:assertEqual(e.type, "Reputation", "Element: Reputation.type")
				runner:assertEqual(e.key, "REP_99999", "Element: Reputation.key")
				runner:assertEqual(e.quantity, 250, "Element: Reputation.quantity")
				runner:assertEqual(type(e.textFn), "function", "Element: Reputation.textFn")
				runner:assertEqual(type(e.itemCountFn), "function", "Element: Reputation.itemCountFn")
				runner:assertEqual(type(e.IsEnabled), "function", "Element: Reputation.IsEnabled")
				runner:assertEqual(type(e.Show), "function", "Element: Reputation.Show")
			end
		end
	end
end

local function testLocale()
	runner:assertEqual(G_RLF.L ~= nil, true, "Locale: G_RLF.L exists")
	if not G_RLF.L then
		return
	end

	-- Spot-check critical locale keys used across config and features
	local criticalKeys = {
		"Party Loot Config",
		"Loot History",
		"Blizzard UI",
		"Item Count Text",
		"Pending Items",
		"Enable Currency in Feed",
		"Enable Money in Feed",
		"Enable Item Loot in Feed",
		"Enable Party Loot in Feed",
		"Show Money Total",
	}
	for _, key in ipairs(criticalKeys) do
		runner:assertEqual(G_RLF.L[key] ~= nil, true, "Locale: key '" .. key .. "' exists")
	end
end

--- Feature module → primary event handler map
--- Each entry is { moduleName, expectedEventHandler }
local featureEventHandlers = {
	{ G_RLF.FeatureModule.ItemLoot, "CHAT_MSG_LOOT" },
	{ G_RLF.FeatureModule.Money, "PLAYER_MONEY" },
	{ G_RLF.FeatureModule.Experience, "PLAYER_XP_UPDATE" },
	{ G_RLF.FeatureModule.Profession, "CHAT_MSG_SKILL" },
	{ G_RLF.FeatureModule.PartyLoot, "CHAT_MSG_LOOT" },
}
if G_RLF:IsRetail() then
	table.insert(featureEventHandlers, { G_RLF.FeatureModule.Transmog, "TRANSMOG_COLLECTION_SOURCE_ADDED" })
	table.insert(featureEventHandlers, { G_RLF.FeatureModule.TravelPoints, "PERKS_ACTIVITY_COMPLETED" })
end

local function testEventHandlers()
	for _, entry in ipairs(featureEventHandlers) do
		local moduleName, handlerName = entry[1], entry[2]
		local module = G_RLF.RLF:GetModule(moduleName, true)
		if module and module:IsEnabled() then
			runner:assertEqual(
				type(module[handlerName]),
				"function",
				"EventHandler: " .. moduleName .. "." .. handlerName
			)
		end
	end

	-- Reputation has expansion-dependent handlers
	local repModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Reputation, true)
	if repModule and repModule:IsEnabled() then
		if
			not G_RLF:IsRetail()
			or not C_EventUtils.IsEventValid
			or not C_EventUtils.IsEventValid("FACTION_STANDING_CHANGED")
		then
			runner:assertEqual(
				type(repModule["CHAT_MSG_COMBAT_FACTION_CHANGE"]),
				"function",
				"EventHandler: Reputation.CHAT_MSG_COMBAT_FACTION_CHANGE"
			)
		end
	end

	-- Currency has expansion-dependent events
	if GetExpansionLevel() >= G_RLF.Expansion.WOTLK then
		local currModule = G_RLF.RLF:GetModule(G_RLF.FeatureModule.Currency, true)
		if currModule and currModule:IsEnabled() then
			runner:assertEqual(
				type(currModule["CURRENCY_DISPLAY_UPDATE"]),
				"function",
				"EventHandler: Currency.CURRENCY_DISPLAY_UPDATE"
			)
		end
	end
end

function TestMode:SmokeTest()
	runner:reset()

	runner:section("WoW Globals")
	testWoWGlobals()

	runner:section("Module Registration")
	testModuleRegistration()

	runner:section("Feature Enabled State")
	testFeatureEnabledState()

	runner:section("DB Structure")
	testDbStructure()

	runner:section("Migration Integrity")
	testMigrationIntegrity()

	runner:section("LootDisplay Frame")
	testLootDisplayFrame()

	runner:section("TestMode Data")
	testTestModeDataReadiness()

	runner:section("Element Constructors")
	testElementConstructors()

	runner:section("Locale")
	testLocale()

	runner:section("Event Handlers")
	testEventHandlers()

	runner:displayResults()
end

-- trunk-ignore-end(no-invalid-prints/invalid-print)
--@end-alpha@
