---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- ── External dependency locals ────────────────────────────────────────────────
-- Every reference to the addon namespace is captured here so the module's full
-- dependency surface on G_RLF / ns is visible in one place.  Tests pass a
-- minimal mock ns to loadfile("Currency.lua") to control these at injection
-- time without the full nsMocks framework.
-- NOTE: G_RLF.db and G_RLF.hiddenCurrencies are intentionally absent –
-- they must remain runtime lookups so per-test overrides work correctly.
local LootElementBase = G_RLF.LootElementBase
local FeatureBase = G_RLF.FeatureBase
local FeatureModule = G_RLF.FeatureModule
local Expansion = G_RLF.Expansion
local LogDebug = function(...)
	G_RLF:LogDebug(...)
end
local LogInfo = function(...)
	G_RLF:LogInfo(...)
end
local LogWarn = function(...)
	G_RLF:LogWarn(...)
end
local IsRetail = function()
	return G_RLF:IsRetail()
end
local IsForever = function()
	return G_RLF:IsForever()
end
local RGBAToHexFormat = function(...)
	return G_RLF:RGBAToHexFormat(...)
end
local ExtractCurrencyID = function(msg)
	return G_RLF:ExtractCurrencyID(msg)
end

-- ── WoW API / Global abstraction adapters ────────────────────────────────────
-- The shared adapter lives in WoWAPIAdapters.lua (G_RLF.WoWAPI.Currency).
-- Tests replace Currency._currencyAdapter with a mock after loadfile.

---@class RLF_Currency: RLF_Module, AceEvent-3.0
local Currency = FeatureBase:new(FeatureModule.Currency, "AceEvent-3.0")

Currency._currencyAdapter = G_RLF.WoWAPI.Currency

--- @param content string
--- @param message string
--- @param id? string
--- @param amount? string|number
function Currency:LogDebug(content, message, id, amount)
	LogDebug(message, addonName, self.moduleName, id, content, amount)
end

local ETHEREAL_STRANDS_CURRENCY_ID = 3278

--- Builds a uniform payload for LootElementBase:fromPayload().
--- @param currencyLink string
--- @param currencyInfo CurrencyInfo
--- @param basicInfo CurrencyDisplayInfo
--- @return RLF_ElementPayload?
function Currency:BuildPayload(currencyLink, currencyInfo, basicInfo)
	if not currencyLink or not currencyInfo or not basicInfo then
		Currency:LogDebug(
			"Skip showing currency",
			"SKIP: Missing currencyLink, currencyInfo, or basicInfo - " .. tostring(currencyLink)
		)
		return nil
	end

	local currencyID = currencyInfo.currencyID
	local key = "CURRENCY_" .. currencyID
	local cappedQuantity = currencyInfo.maxQuantity
	local totalEarned = currencyInfo.totalEarned
	local itemCount = currencyInfo.quantity

	-- Honor currency special case
	if currencyID == Currency._currencyAdapter.GetAccountWideHonorCurrencyID() then
		itemCount = Currency._currencyAdapter.GetUnitHonorLevel("player")
		cappedQuantity = Currency._currencyAdapter.GetUnitHonorMax("player")
		totalEarned = Currency._currencyAdapter.GetUnitHonor("player")
		---@diagnostic disable-next-line: undefined-field
		currencyLink = currencyLink:gsub(currencyInfo.name, _G.LIFETIME_HONOR)
	end

	---@type RLF_ElementPayload
	local payload = {
		-- Routing
		key = key,
		type = FeatureModule.Currency,

		-- Icon
		icon = (G_RLF.DbAccessor:AnyFeatureConfig("currency") or {}).enableIcon
				and not G_RLF.db.global.misc.hideAllIcons
				and currencyInfo.iconFileID
			or nil,
		quality = currencyInfo.quality,

		-- Primary line
		isLink = true,
		isCustomLink = currencyID == ETHEREAL_STRANDS_CURRENCY_ID,
		quantity = basicInfo.displayAmount,

		textFn = function(existingQuantity, truncatedLink)
			if not truncatedLink then
				return currencyLink
			end
			return truncatedLink
		end,

		amountTextFn = function(existingQuantity)
			local effectiveQuantity = (existingQuantity or 0) + basicInfo.displayAmount
			if effectiveQuantity == 1 and not G_RLF.db.global.misc.showOneQuantity then
				return ""
			end
			return "x" .. effectiveQuantity
		end,

		-- Item count display (replaces legacy type-switch in UpdateItemCount)
		itemCountFn = function()
			local currencyDb = G_RLF.DbAccessor:AnyFeatureConfig("currency") or {}
			if not currencyDb.currencyTotalTextEnabled then
				return nil
			end
			return itemCount,
				{
					color = RGBAToHexFormat(unpack(currencyDb.currencyTotalTextColor)),
					wrapChar = currencyDb.currencyTotalTextWrapChar,
				}
		end,

		-- Secondary line
		secondaryTextFn = function()
			if cappedQuantity and cappedQuantity > 0 then
				local percentage, numerator
				if totalEarned > 0 then
					numerator = totalEarned
					percentage = totalEarned / cappedQuantity
				else
					numerator = itemCount
					percentage = itemCount / cappedQuantity
				end
				local currencyDb = G_RLF.DbAccessor:AnyFeatureConfig("currency") or {}
				local lowThreshold = currencyDb.lowerThreshold
				local upperThreshold = currencyDb.upperThreshold
				local lowestColor = currencyDb.lowestColor
				local midColor = currencyDb.midColor
				local upperColor = currencyDb.upperColor
				local color = RGBAToHexFormat(unpack(lowestColor))
				if currencyID ~= Currency._currencyAdapter.GetAccountWideHonorCurrencyID() then
					if percentage < lowThreshold then
						color = RGBAToHexFormat(unpack(lowestColor))
					elseif percentage >= lowThreshold and percentage < upperThreshold then
						color = RGBAToHexFormat(unpack(midColor))
					else
						color = RGBAToHexFormat(unpack(upperColor))
					end
				end

				local secondaryText = "    " .. color .. numerator .. " / " .. cappedQuantity .. "|r"
				local idStr = key:match("CURRENCY_(%d+)")
				if idStr and idStr ~= "" and tonumber(idStr) == ETHEREAL_STRANDS_CURRENCY_ID then
					secondaryText = secondaryText .. "    (" .. G_RLF.L["ClickToOpenCloakTree"] .. ")"
				end
				return secondaryText
			end

			return ""
		end,

		-- Lifecycle
		IsEnabled = function()
			return Currency:IsEnabled()
		end,
		-- Filter metadata evaluated per-frame by LootDisplayFrame:PassesPerFrameFilters
		filterCurrencyId = currencyID,
	}

	if currencyID == ETHEREAL_STRANDS_CURRENCY_ID then
		payload.customBehavior = function()
			local idStr = key:match("CURRENCY_(%d+)")
			if idStr == nil or idStr == "" then
				Currency:LogDebug("Custom behavior", "SKIP: No ID found in custom currency link")
				return
			end
			local customCurrencyId = tonumber(idStr)

			if customCurrencyId == ETHEREAL_STRANDS_CURRENCY_ID then
				Currency._currencyAdapter.GenericTraitToggle()
			else
				Currency:LogDebug("Custom behavior", "SKIP: unhandled custom currency link", key)
			end
		end
	end

	return payload
end

local function isHiddenCurrency(id)
	return G_RLF.hiddenCurrencies[id] == true
end

local function extractAmount(message, patterns)
	for _, segments in ipairs(patterns) do
		local prePattern, postPattern = unpack(segments)
		local preMatchStart, _ = string.find(message, prePattern, 1, true)
		if not preMatchStart then
			-- If the prePattern is not found, skip to the next pattern
		else
			local subString = string.sub(message, preMatchStart)
			local amount = string.match(subString, prePattern .. "(%d+)" .. postPattern)
			if amount and amount ~= "" and tonumber(amount) > 0 then
				return tonumber(amount)
			end
		end
	end
	return nil
end

-- Precompute pattern segments to optimize runtime message parsing
local function precomputeAmountPatternSegments(patterns)
	local computedPatterns = {}
	for _, pattern in ipairs(patterns) do
		local _, stringPlaceholderEnd = string.find(pattern, "%%s")
		if stringPlaceholderEnd then
			local numberPlaceholderStart, numberPlaceholderEnd = string.find(pattern, "%%d", stringPlaceholderEnd + 1)
			if numberPlaceholderEnd then
				local midPattern = string.sub(pattern, stringPlaceholderEnd + 1, numberPlaceholderStart - 1)
				local postPattern = string.sub(pattern, numberPlaceholderEnd + 1)
				table.insert(computedPatterns, { midPattern, postPattern })
			else
				Currency:LogDebug("Invalid pattern", "No number placeholder found in pattern " .. pattern)
			end
		end
	end
	return computedPatterns
end

-- WoW Forever reports expansion 0 but ships the Mainline currency system
-- (C_CurrencyInfo + CURRENCY_DISPLAY_UPDATE with quantityChange).
local function IsCurrencySupported()
	return IsForever() or Currency._currencyAdapter.GetExpansionLevel() >= Expansion.WOTLK
end

local function UsesChatCurrencyEvents()
	return not IsForever() and Currency._currencyAdapter.GetExpansionLevel() < Expansion.BFA
end

-- Trading Post (Blizzard_PerksProgram) is excluded from WoW Forever.
local function HasPerksProgram()
	return IsRetail() and not IsForever()
end

local classicCurrencyPatterns
function Currency:OnInitialize()
	if G_RLF.DbAccessor:IsFeatureNeededByAnyFrame("currency") and IsCurrencySupported() then
		self:Enable()
	else
		self:Disable()
	end

	if UsesChatCurrencyEvents() then
		local currencyConsts = {
			Currency._currencyAdapter.GetCurrencyGainedMultiplePattern(),
			Currency._currencyAdapter.GetCurrencyGainedMultipleBonusPattern(),
		}
		classicCurrencyPatterns = precomputeAmountPatternSegments(currencyConsts)
	else
		classicCurrencyPatterns = nil
	end
end

function Currency:OnDisable()
	if not IsCurrencySupported() then
		self:LogDebug("OnEnable", "Disabled because expansion is below WOTLK")
		return
	end
	if UsesChatCurrencyEvents() then
		self:UnregisterEvent("CHAT_MSG_CURRENCY")
	else
		self:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")
	end
	if HasPerksProgram() then
		self:UnregisterEvent("PERKS_PROGRAM_CURRENCY_AWARDED")
		self:UnregisterEvent("PERKS_PROGRAM_CURRENCY_REFRESH")
	end
end

function Currency:OnEnable()
	if not IsCurrencySupported() then
		self:LogDebug("OnEnable", "Disabled because expansion is below WOTLK")
		return
	end
	if UsesChatCurrencyEvents() then
		self:RegisterEvent("CHAT_MSG_CURRENCY")
	else
		self:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
	end
	if HasPerksProgram() then
		self:RegisterEvent("PERKS_PROGRAM_CURRENCY_AWARDED")
	end
	self:LogDebug("OnEnable", "Currency module is enabled")
end

function Currency:Process(eventName, currencyType, quantityChange)
	LogInfo(eventName, "WOWEVENT", self.moduleName, currencyType, eventName, quantityChange)

	if currencyType == nil or not quantityChange or quantityChange == 0 then
		self:LogDebug(
			"Skip showing currency",
			"SKIP: Something was missing, don't display",
			currencyType,
			quantityChange
		)
		return
	end

	if isHiddenCurrency(currencyType) then
		self:LogDebug(
			"Skip showing currency",
			"SKIP: This is a known hidden currencyType",
			currencyType,
			quantityChange
		)
		return
	end

	---@type CurrencyInfo
	local info = Currency._currencyAdapter.GetCurrencyInfo(currencyType)
	if info == nil or info.description == "" or info.iconFileID == nil then
		self:LogDebug("Skip showing currency", "SKIP: Description or icon was empty", currencyType, quantityChange)
		return
	end

	---@type CurrencyDisplayInfo
	local basicInfo = Currency._currencyAdapter.GetBasicCurrencyInfo(currencyType, quantityChange)
	local link
	if Currency._currencyAdapter.HasGetCurrencyLinkAPI() then
		link = Currency._currencyAdapter.GetCurrencyLinkFromLib(currencyType)
	else
		-- Fallback for pre-SL clients
		link = Currency._currencyAdapter.GetCurrencyLinkFromGlobal(currencyType, quantityChange)
	end
	local payload = self:BuildPayload(link, info, basicInfo)
	if payload then
		LootElementBase:fromPayload(payload):Show()
	else
		self:LogDebug("Skip showing currency", "SKIP: Payload was nil", currencyType, quantityChange)
	end
end

function Currency:CURRENCY_DISPLAY_UPDATE(eventName, ...)
	local currencyType, _quantity, quantityChange, _quantityGainSource, _quantityLostSource = ...

	self:Process(eventName, currencyType, quantityChange)
end

---@param msg string
---@return number? quantityChange
function Currency:ParseCurrencyChangeMessage(msg)
	if not classicCurrencyPatterns or #classicCurrencyPatterns == 0 then
		self:LogDebug("Skip showing currency", "SKIP: No classic currency patterns available")
		return nil
	end

	local quantityChange = extractAmount(msg, classicCurrencyPatterns)

	quantityChange = quantityChange or 1

	return quantityChange
end

function Currency:CHAT_MSG_CURRENCY(eventName, ...)
	local msg = ...
	if Currency._currencyAdapter.IssecretValue(msg) then
		LogWarn("(" .. eventName .. ") Secret value detected, ignoring chat message", "WOWEVENT", self.moduleName, "")
		return
	end

	LogInfo(eventName, "WOWEVENT", self.moduleName, nil, msg)

	local currencyId = ExtractCurrencyID(msg)
	if currencyId == 0 or currencyId == nil then
		self:LogDebug("Skip showing currency", "SKIP: No currency ID found for links in msg = " .. tostring(msg))
		return
	end

	if currencyId and isHiddenCurrency(currencyId) then
		self:LogDebug(
			"Skip showing currency",
			"SKIP: This is a known hidden currency " .. tostring(msg),
			tostring(currencyId)
		)
		return
	end

	local quantityChange = self:ParseCurrencyChangeMessage(msg)
	if quantityChange == nil or quantityChange <= 0 then
		self:LogDebug(
			"Skip showing currency",
			"SKIP: there was a problem determining the quantity change " .. tostring(msg),
			tostring(currencyId)
		)
		return
	end

	local currencyInfo = Currency._currencyAdapter.GetCurrencyInfo(currencyId)
	if not currencyInfo then
		self:LogDebug("Skip showing currency", "SKIP: No currency info found for msg = " .. msg, tostring(currencyId))
		return
	end

	if currencyInfo.currencyID == 0 then
		self:LogDebug(
			"Currency info has no ID",
			"Overriding " .. tostring(currencyInfo.name) .. " currencyID",
			tostring(currencyId)
		)
		currencyInfo.currencyID = currencyId
	end

	if currencyInfo.quantity == 0 then
		self:LogDebug(
			"Currency info has no quantity",
			"Overriding " .. tostring(currencyInfo.name) .. " quantity to " .. tostring(quantityChange),
			tostring(currencyId)
		)
		currencyInfo.quantity = quantityChange
	end

	local basicInfo = {
		displayAmount = quantityChange,
	}

	local currencyLink = Currency._currencyAdapter.GetCurrencyLinkFromGlobal(currencyId, currencyInfo.quantity)
	local payload = self:BuildPayload(currencyLink, currencyInfo, basicInfo)
	if payload then
		LootElementBase:fromPayload(payload):Show()
	else
		self:LogDebug("Skip showing currency", "SKIP: Payload was nil", tostring(currencyInfo.currencyID))
	end
end

function Currency:PERKS_PROGRAM_CURRENCY_AWARDED(eventName, quantityChange)
	self:RegisterEvent("PERKS_PROGRAM_CURRENCY_REFRESH")
	local currencyType = Currency._currencyAdapter.GetPerksProgramCurrencyID()
	LogInfo(eventName, "WOWEVENT", self.moduleName, tostring(currencyType), eventName, quantityChange)
	self:UnregisterEvent("PERKS_PROGRAM_CURRENCY_AWARDED")
end

function Currency:PERKS_PROGRAM_CURRENCY_REFRESH(eventName, oldQuantity, newQuantity)
	local currencyType = Currency._currencyAdapter.GetPerksProgramCurrencyID()

	local quantityChange = newQuantity - oldQuantity
	if quantityChange == 0 then
		return
	end
	self:Process(eventName, currencyType, quantityChange)
end

return Currency
