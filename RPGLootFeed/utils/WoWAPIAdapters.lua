---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local C = LibStub("C_Everywhere")

-- ── Shared WoW API Adapters ──────────────────────────────────────────────────
-- Central namespace for WoW API wrappers used across feature modules.
-- Each adapter is a plain table of functions that wrap a single C_ namespace
-- or family of related globals. Tests mock at this boundary.
if not G_RLF.WoWAPI then
	G_RLF.WoWAPI = {}
end

-- ── Reputation API Adapter ───────────────────────────────────────────────────
-- Wraps C_Reputation, C_MajorFactions, C_DelvesUI, C_EventUtils, and
-- related globals used by the Reputation feature module and RepUtils.
---@class RLF_WoWAPI_Reputation
G_RLF.WoWAPI.Reputation = {
	GetExpansionLevel = function()
		return GetExpansionLevel()
	end,
	RunNextFrame = function(fn)
		return RunNextFrame(fn)
	end,
	IssecretValue = function(msg)
		return issecretvalue and issecretvalue(msg)
	end,
	IsEventValid = function(event)
		return C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid(event)
	end,
	GetFactionForCompanion = function()
		return C_DelvesUI.GetFactionForCompanion()
	end,
	GetFactionDataByID = function(id)
		return C_Reputation.GetFactionDataByID(id)
	end,
	GetDelvesFactionForSeason = function()
		return C_DelvesUI and C_DelvesUI.GetDelvesFactionForSeason and C_DelvesUI.GetDelvesFactionForSeason() or 0
	end,
	GetMajorFactionRenownInfo = function(id)
		return C_MajorFactions.GetMajorFactionRenownInfo(id)
	end,
	GetNumFactions = function()
		return C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetNumFactions() or nil
	end,
	GetFactionDataByIndex = function(i)
		return C_Reputation and C_Reputation.GetFactionDataByIndex and C_Reputation.GetFactionDataByIndex(i) or nil
	end,
	HasRetailReputationAPIAvailable = function()
		return C_Reputation ~= nil and C_Reputation.GetNumFactions ~= nil and C_Reputation.GetFactionDataByIndex ~= nil
	end,
	GetAccountWideFontColor = function()
		return ACCOUNT_WIDE_FONT_COLOR
	end,
	GetDelveReputationBarTitle = function()
		return _G["DELVES_REPUTATION_BAR_TITLE_NO_SEASON"]
	end,
	Strtrim = function(str)
		return strtrim(str)
	end,
}

-- ── Experience API Adapter ────────────────────────────────────────────────────
-- Wraps UnitXP, UnitXPMax, and UnitLevel globals used by the Experience
-- feature module.
---@class RLF_WoWAPI_Experience
G_RLF.WoWAPI.Experience = {
	UnitXP = function(unit)
		return UnitXP(unit)
	end,
	UnitXPMax = function(unit)
		return UnitXPMax(unit)
	end,
	UnitLevel = function(unit)
		return UnitLevel(unit)
	end,
}

-- ── Money API Adapter ─────────────────────────────────────────────────────────
-- Wraps C_CurrencyInfo, GetMoney, and PlaySoundFile so tests can inject mocks
-- without patching _G directly.
---@class RLF_WoWAPI_Money
G_RLF.WoWAPI.Money = {
	GetCoinTextureString = function(amount)
		return C_CurrencyInfo.GetCoinTextureString(amount)
	end,
	GetMoney = function()
		return GetMoney()
	end,
	PlaySoundFile = function(sound)
		return PlaySoundFile(sound)
	end,
}

-- ── TravelPoints API Adapter ──────────────────────────────────────────────────
-- Wraps C_PerksActivities and the MONTHLY_ACTIVITIES_POINTS global string used
-- by the TravelPoints feature module.
---@class RLF_WoWAPI_TravelPoints
G_RLF.WoWAPI.TravelPoints = {
	GetPerksActivitiesInfo = function()
		return C_PerksActivities.GetPerksActivitiesInfo()
	end,
	GetPerksActivityInfo = function(activityID)
		return C_PerksActivities.GetPerksActivityInfo(activityID)
	end,
	GetMonthlyActivitiesPointsLabel = function()
		return _G["MONTHLY_ACTIVITIES_POINTS"]
	end,
}

-- ── Currency API Adapter ──────────────────────────────────────────────────────
-- Wraps GetExpansionLevel, currency info APIs (C_Everywhere + direct), honor
-- tracking, locale patterns, Constants, and Ethereal-Strands UI behind
-- testable functions so tests can inject mocks without patching _G.
---@class RLF_WoWAPI_Currency
G_RLF.WoWAPI.Currency = {
	GetExpansionLevel = function()
		return GetExpansionLevel()
	end,
	IssecretValue = function(msg)
		return issecretvalue and issecretvalue(msg)
	end,
	-- C_Everywhere unified queries used in Process (CURRENCY_DISPLAY_UPDATE path)
	GetCurrencyInfo = function(currencyType)
		return C.CurrencyInfo.GetCurrencyInfo(currencyType)
	end,
	GetBasicCurrencyInfo = function(currencyType, amount)
		return C.CurrencyInfo.GetBasicCurrencyInfo(currencyType, amount)
	end,
	GetCurrencyLinkFromLib = function(currencyType)
		return C.CurrencyInfo.GetCurrencyLink(currencyType)
	end,
	-- Predicate: does the modern C_CurrencyInfo.GetCurrencyLink API exist?
	HasGetCurrencyLinkAPI = function()
		return C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink ~= nil
	end,
	-- Classic fallback (bare global) for GetCurrencyLink
	GetCurrencyLinkFromGlobal = function(currencyId, quantity)
		return GetCurrencyLink(currencyId, quantity)
	end,
	-- Honor tracking for the Account-Wide Honor currency element
	GetUnitHonorLevel = function(unit)
		return UnitHonorLevel(unit)
	end,
	GetUnitHonorMax = function(unit)
		return UnitHonorMax(unit)
	end,
	GetUnitHonor = function(unit)
		return UnitHonor(unit)
	end,
	-- WoW Constants tables
	GetAccountWideHonorCurrencyID = function()
		return Constants and Constants.CurrencyConsts and Constants.CurrencyConsts.ACCOUNT_WIDE_HONOR_CURRENCY_ID
	end,
	GetPerksProgramCurrencyID = function()
		return Constants
			and Constants.CurrencyConsts
			and Constants.CurrencyConsts.CURRENCY_ID_PERKS_PROGRAM_DISPLAY_INFO
	end,
	-- Classic locale patterns used in OnInitialize to build classicCurrencyPatterns
	GetCurrencyGainedMultiplePattern = function()
		return CURRENCY_GAINED_MULTIPLE
	end,
	GetCurrencyGainedMultipleBonusPattern = function()
		return CURRENCY_GAINED_MULTIPLE_BONUS
	end,
	-- Ethereal Strands UI (3278) custom link handler
	GenericTraitToggle = function()
		GenericTraitUI_LoadUI()
		GenericTraitFrame:SetSystemID(29)
		GenericTraitFrame:SetTreeID(1115)
		ToggleFrame(GenericTraitFrame)
	end,
}

-- ── Professions API Adapter ──────────────────────────────────────────────────
-- Wraps GetProfessions, GetProfessionInfo, issecretvalue, and SKILL_RANK_UP
-- for the Professions feature module.
---@class RLF_WoWAPI_Professions
G_RLF.WoWAPI.Professions = {
	GetProfessions = function()
		return GetProfessions()
	end,
	GetProfessionInfo = function(id)
		return GetProfessionInfo(id)
	end,
	IssecretValue = function(msg)
		return issecretvalue and issecretvalue(msg)
	end,
	GetSkillRankUpPattern = function()
		return _G.SKILL_RANK_UP
	end,
}

-- ── Transmog API Adapter ──────────────────────────────────────────────────────
-- Wraps C_TransmogCollection.GetAppearanceSourceInfo, Item:CreateFromItemLink,
-- and the ERR_LEARN_TRANSMOG_S locale string for the Transmog feature module.
---@class RLF_WoWAPI_Transmog
G_RLF.WoWAPI.Transmog = {
	GetAppearanceSourceInfo = function(itemModifiedAppearanceID)
		return C_TransmogCollection.GetAppearanceSourceInfo(itemModifiedAppearanceID)
	end,
	CreateItemFromItemLink = function(itemLink)
		return Item:CreateFromItemLink(itemLink)
	end,
	GetErrLearnTransmogS = function()
		return _G["ERR_LEARN_TRANSMOG_S"]
	end,
}

-- ── ItemLoot API Adapter ──────────────────────────────────────────────────────
-- Wraps WoW API calls used by the ItemLoot feature module: unit queries,
-- C_Item stat/count/info lookups, GetCoinTextureString, CreateAtlasMarkup,
-- PlaySoundFile, and the AuctionIntegrations price hook.
---@class RLF_WoWAPI_ItemLoot
G_RLF.WoWAPI.ItemLoot = {
	GetExpansionLevel = function()
		return GetExpansionLevel()
	end,
	UnitName = function(unit)
		return UnitName(unit)
	end,
	UnitClass = function(unit)
		return UnitClass(unit)
	end,
	UnitLevel = function(unit)
		return UnitLevel(unit)
	end,
	IssecretValue = function(msg)
		return issecretvalue and issecretvalue(msg)
	end,
	GetPlayerGuid = function()
		return GetPlayerGuid()
	end,
	GetInventoryItemLink = function(unit, slot)
		return GetInventoryItemLink(unit, slot)
	end,
	GetItemQualityColor = function(quality)
		return C_Item.GetItemQualityColor(quality)
	end,
	GetCoinTextureString = function(price)
		return C_CurrencyInfo.GetCoinTextureString(price)
	end,
	-- Client-localized gold/silver/copper abbreviations (used by Blizzard's own
	-- MoneyFrame/CoinPickupFrame, WoW Token, and Store UIs across every shipped
	-- flavor), for the plain-text price mode -- so it matches whatever suffix
	-- players already see everywhere else in the game's UI instead of a
	-- hardcoded English "g"/"s"/"c". Falls back to the English literal if a
	-- future client build ever ships without one -- a missing global here must
	-- degrade the suffix, not throw a concat error and blank the price text.
	GetGoldAmountSymbol = function()
		return GOLD_AMOUNT_SYMBOL or "g"
	end,
	GetSilverAmountSymbol = function()
		return SILVER_AMOUNT_SYMBOL or "s"
	end,
	GetCopperAmountSymbol = function()
		return COPPER_AMOUNT_SYMBOL or "c"
	end,
	CreateAtlasMarkup = function(icon, w, h, x, y)
		return CreateAtlasMarkup(icon, w, h, x, y)
	end,
	PlaySoundFile = function(sound)
		return PlaySoundFile(sound)
	end,
	GetAHPrice = function(itemLink)
		local ai = G_RLF.AuctionIntegrations
		if ai and ai.activeIntegration then
			return ai.activeIntegration:GetAHPrice(itemLink)
		end
		return nil
	end,
	GetItemInfo = function(link)
		return C.Item.GetItemInfo(link)
	end,
	GetItemIDForItemInfo = function(link)
		return C.Item.GetItemIDForItemInfo(link)
	end,
	GetItemCount = function(link, ...)
		return C.Item.GetItemCount(link, ...)
	end,
	GetItemStatDelta = function(link1, link2)
		return C.Item.GetItemStatDelta(link1, link2)
	end,
}

-- ── PartyLoot API Adapter ─────────────────────────────────────────────────────
-- Wraps UnitName, UnitClass, IsInRaid, IsInInstance, GetNumGroupMembers,
-- GetExpansionLevel, GetPlayerGuid, C_ClassColor, RAID_CLASS_COLORS,
-- issecretvalue, and the C_Everywhere item query for the PartyLoot feature module.
---@class RLF_WoWAPI_PartyLoot
G_RLF.WoWAPI.PartyLoot = {
	UnitName = function(unit)
		return UnitName(unit)
	end,
	UnitClass = function(unit)
		return UnitClass(unit)
	end,
	IssecretValue = function(msg)
		return issecretvalue and issecretvalue(msg)
	end,
	GetNumGroupMembers = function()
		return GetNumGroupMembers()
	end,
	IsInRaid = function()
		return IsInRaid()
	end,
	IsInInstance = function()
		return IsInInstance()
	end,
	GetExpansionLevel = function()
		return GetExpansionLevel()
	end,
	GetPlayerGuid = function()
		return GetPlayerGuid()
	end,
	GetClassColor = function(className)
		return C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(className)
	end,
	GetRaidClassColor = function(className)
		return RAID_CLASS_COLORS and RAID_CLASS_COLORS[className]
	end,
	GetItemInfo = function(itemLink)
		return C.Item.GetItemInfo(itemLink)
	end,
}

return G_RLF.WoWAPI
