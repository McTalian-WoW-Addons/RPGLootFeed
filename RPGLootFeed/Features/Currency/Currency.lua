---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local ETHEREAL_STRANDS_CURRENCY_ID = 3278

---@class RLF_Currency: RLF_Module, AceEvent-3.0
local Currency = G_RLF.FeatureBase:new("Currency", {
	di = {
		lootElementBase = "LootElementBase",
		currencyApi = "WoWAPI.Currency",
		textTemplateEngine = "TextTemplateEngine",
		isRetail = "IsRetail",
	},
	logging = true,
}, "AceEvent-3.0")

-- ── Context provider ──────────────────────────────────────────────────────────

local function createCurrencyContextProvider()
	return function(context, data)
		local cappedQuantity = data.cappedQuantity
		local totalEarned = data.totalEarned
		local itemCount = data.itemCount
		local currencyID = data.currencyID

		if not cappedQuantity or cappedQuantity <= 0 then
			context.capDisplay = ""
			return
		end

		local percentage, numerator
		if totalEarned and totalEarned > 0 then
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
		local color = G_RLF:RGBAToHexFormat(unpack(lowestColor))

		if currencyID ~= Currency.currencyApi.GetAccountWideHonorCurrencyID() then
			if percentage < lowThreshold then
				color = G_RLF:RGBAToHexFormat(unpack(lowestColor))
			elseif percentage >= lowThreshold and percentage < upperThreshold then
				color = G_RLF:RGBAToHexFormat(unpack(midColor))
			else
				color = G_RLF:RGBAToHexFormat(unpack(upperColor))
			end
		end

		local display = color .. numerator .. " / " .. cappedQuantity .. "|r"

		-- Ethereal Strands: append cloak tree hint
		if currencyID == ETHEREAL_STRANDS_CURRENCY_ID then
			display = display .. "    (" .. G_RLF.L["ClickToOpenCloakTree"] .. ")"
		end

		context.capDisplay = display
	end
end

-- ── Text elements ─────────────────────────────────────────────────────────────

--- Generate text elements for Currency type.
--- Row 1: currency link
--- Row 2: cap display (spacer + capped quantity info)
function Currency:GenerateTextElements()
	local elements = {}

	elements[1] = {}
	elements[1].primary = {
		type = "primary",
		template = "{truncatedLink}",
		order = 1,
	}

	elements[2] = {}
	elements[2].contextSpacer = {
		type = "spacer",
		spacerCount = 4,
		order = 1,
	}
	elements[2].context = {
		type = "context",
		template = "{capDisplay}",
		order = 2,
	}

	return elements
end

-- ── BuildPayload ──────────────────────────────────────────────────────────────

--- Builds a uniform payload for LootElementBase:fromPayload().
---@param currencyLink string
---@param currencyInfo CurrencyInfo
---@param basicInfo CurrencyDisplayInfo
---@return RLF_ElementPayload?
function Currency:BuildPayload(currencyLink, currencyInfo, basicInfo)
	if not currencyLink or not currencyInfo or not basicInfo then
		Currency:LogDebug(
			"SKIP: Missing currencyLink, currencyInfo, or basicInfo - " .. tostring(currencyLink),
			nil,
			nil,
			nil,
			"Skip showing currency"
		)
		return nil
	end

	local currencyID = currencyInfo.currencyID
	local key = "CURRENCY_" .. currencyID
	local cappedQuantity = currencyInfo.maxQuantity
	local totalEarned = currencyInfo.totalEarned
	local itemCount = currencyInfo.quantity

	-- Honor currency special case
	if currencyID == Currency.currencyApi.GetAccountWideHonorCurrencyID() then
		itemCount = Currency.currencyApi.GetUnitHonorLevel("player")
		cappedQuantity = Currency.currencyApi.GetUnitHonorMax("player")
		totalEarned = Currency.currencyApi.GetUnitHonor("player")
		---@diagnostic disable-next-line: undefined-field
		currencyLink = currencyLink:gsub(currencyInfo.name, _G.LIFETIME_HONOR)
	end

	local textElements = self:GenerateTextElements()

	---@type RLF_LootElementData
	local elementData = {
		key = key,
		type = "Currency",
		textElements = textElements,
		quantity = basicInfo.displayAmount,
		icon = currencyInfo.iconFileID,
		quality = currencyInfo.quality,
		link = currencyLink,
		-- Extra fields for context provider
		currencyID = currencyID,
		cappedQuantity = cappedQuantity,
		totalEarned = totalEarned,
		itemCount = itemCount,
	}

	---@type RLF_ElementPayload
	local payload = {
		-- Routing
		key = key,
		type = G_RLF.FeatureModule.Currency,

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
			return self.textTemplateEngine:ProcessRowElements(1, elementData, existingQuantity, truncatedLink)
		end,

		amountTextFn = function(existingQuantity)
			local effectiveQuantity = (existingQuantity or 0) + basicInfo.displayAmount
			if effectiveQuantity == 1 and not G_RLF.db.global.misc.showOneQuantity then
				return ""
			end
			return "x" .. effectiveQuantity
		end,

		-- Item count display
		itemCountFn = function()
			local currencyDb = G_RLF.DbAccessor:AnyFeatureConfig("currency") or {}
			if not currencyDb.currencyTotalTextEnabled then
				return nil
			end
			return itemCount,
				{
					color = G_RLF:RGBAToHexFormat(unpack(currencyDb.currencyTotalTextColor)),
					wrapChar = currencyDb.currencyTotalTextWrapChar,
				}
		end,

		-- Secondary line
		secondaryTextFn = function()
			return self.textTemplateEngine:ProcessRowElements(2, elementData)
		end,

		-- Lifecycle
		moduleRef = Currency,
		-- Filter metadata evaluated per-frame by LootDisplayFrame:PassesPerFrameFilters
		filterCurrencyId = currencyID,
	}

	if currencyID == ETHEREAL_STRANDS_CURRENCY_ID then
		payload.customBehavior = function()
			local idStr = key:match("CURRENCY_(%d+)")
			if idStr == nil or idStr == "" then
				Currency:LogDebug("SKIP: No ID found in custom currency link", nil, nil, nil, "Custom behavior")
				return
			end
			local customCurrencyId = tonumber(idStr)

			if customCurrencyId == ETHEREAL_STRANDS_CURRENCY_ID then
				Currency.currencyApi.GenericTraitToggle()
			else
				Currency:LogDebug("SKIP: unhandled custom currency link", nil, nil, key, "Custom behavior")
			end
		end
	end

	return payload
end

-- ── Module lifecycle ──────────────────────────────────────────────────────────

local function isHiddenCurrency(id)
	return G_RLF.hiddenCurrencies[id] == true
end

local function extractAmount(message, patterns)
	for _, segments in ipairs(patterns) do
		local prePattern, postPattern = unpack(segments)
		local preMatchStart, _ = string.find(message, prePattern, 1, true)
		if not preMatchStart then
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
				Currency:LogDebug(
					"No number placeholder found in pattern " .. pattern,
					nil,
					nil,
					nil,
					"Invalid pattern"
				)
			end
		end
	end
	return computedPatterns
end

local classicCurrencyPatterns

function Currency:OnInitialize()
	if
		G_RLF.DbAccessor:IsFeatureNeededByAnyFrame("currency")
		and Currency.currencyApi.GetExpansionLevel() >= G_RLF.Expansion.WOTLK
	then
		self:Enable()
	else
		self:Disable()
	end

	if Currency.currencyApi.GetExpansionLevel() < G_RLF.Expansion.BFA then
		local currencyConsts = {
			Currency.currencyApi.GetCurrencyGainedMultiplePattern(),
			Currency.currencyApi.GetCurrencyGainedMultipleBonusPattern(),
		}
		classicCurrencyPatterns = precomputeAmountPatternSegments(currencyConsts)
	else
		classicCurrencyPatterns = nil
	end
end

function Currency:OnDisable()
	if Currency.currencyApi.GetExpansionLevel() < G_RLF.Expansion.WOTLK then
		self:LogDebug("Disabled because expansion is below WOTLK", nil, nil, nil, "OnEnable")
		return
	end
	if Currency.currencyApi.GetExpansionLevel() < G_RLF.Expansion.BFA then
		self:UnregisterEvent("CHAT_MSG_CURRENCY")
	else
		self:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")
	end
	if self.isRetail() then
		self:UnregisterEvent("PERKS_PROGRAM_CURRENCY_AWARDED")
		self:UnregisterEvent("PERKS_PROGRAM_CURRENCY_REFRESH")
	end
	self.textTemplateEngine.contextProviders["Currency"] = nil
end

function Currency:OnEnable()
	if Currency.currencyApi.GetExpansionLevel() < G_RLF.Expansion.WOTLK then
		self:LogDebug("Disabled because expansion is below WOTLK", nil, nil, nil, "OnEnable")
		return
	end
	if Currency.currencyApi.GetExpansionLevel() < G_RLF.Expansion.BFA then
		self:RegisterEvent("CHAT_MSG_CURRENCY")
	else
		self:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
	end
	if self.isRetail() then
		self:RegisterEvent("PERKS_PROGRAM_CURRENCY_AWARDED")
	end
	self.textTemplateEngine:RegisterContextProvider("Currency", createCurrencyContextProvider())
	self:LogDebug("Currency module is enabled", nil, nil, nil, "OnEnable")
end

-- ── Event handlers ────────────────────────────────────────────────────────────

function Currency:Process(eventName, currencyType, quantityChange)
	self:LogInfo(eventName, "WOWEVENT", self.moduleName, currencyType, eventName, quantityChange)

	if currencyType == nil or not quantityChange or quantityChange == 0 then
		self:LogDebug(
			"SKIP: Something was missing, don't display",
			nil,
			nil,
			currencyType,
			"Skip showing currency",
			quantityChange
		)
		return
	end

	if isHiddenCurrency(currencyType) then
		self:LogDebug(
			"SKIP: This is a known hidden currencyType",
			nil,
			nil,
			currencyType,
			"Skip showing currency",
			quantityChange
		)
		return
	end

	local info = Currency.currencyApi.GetCurrencyInfo(currencyType)
	if info == nil or info.description == "" or info.iconFileID == nil then
		self:LogDebug(
			"SKIP: Description or icon was empty",
			nil,
			nil,
			currencyType,
			"Skip showing currency",
			quantityChange
		)
		return
	end

	local basicInfo = Currency.currencyApi.GetBasicCurrencyInfo(currencyType, quantityChange)
	local link
	if Currency.currencyApi.HasGetCurrencyLinkAPI() then
		link = Currency.currencyApi.GetCurrencyLinkFromLib(currencyType)
	else
		link = Currency.currencyApi.GetCurrencyLinkFromGlobal(currencyType, quantityChange)
	end
	local payload = self:BuildPayload(link, info, basicInfo)
	if payload then
		self.lootElementBase:fromPayload(payload):Show()
	else
		self:LogDebug("SKIP: Payload was nil", nil, nil, currencyType, "Skip showing currency", quantityChange)
	end
end

function Currency:CURRENCY_DISPLAY_UPDATE(eventName, ...)
	local currencyType, _quantity, quantityChange, _quantityGainSource, _quantityLostSource = ...
	self:Process(eventName, currencyType, quantityChange)
end

function Currency:ParseCurrencyChangeMessage(msg)
	if not classicCurrencyPatterns or #classicCurrencyPatterns == 0 then
		self:LogDebug("SKIP: No classic currency patterns available", nil, nil, nil, "Skip showing currency")
		return nil
	end
	local quantityChange = extractAmount(msg, classicCurrencyPatterns)
	quantityChange = quantityChange or 1
	return quantityChange
end

function Currency:CHAT_MSG_CURRENCY(eventName, ...)
	local msg = ...
	if Currency.currencyApi.IssecretValue(msg) then
		self:LogWarn(
			"(" .. eventName .. ") Secret value detected, ignoring chat message",
			"WOWEVENT",
			self.moduleName,
			""
		)
		return
	end

	self:LogInfo(eventName, "WOWEVENT", self.moduleName, nil, msg)

	local currencyId = G_RLF:ExtractCurrencyID(msg)
	if currencyId == 0 or currencyId == nil then
		self:LogDebug(
			"SKIP: No currency ID found for links in msg = " .. tostring(msg),
			nil,
			nil,
			nil,
			"Skip showing currency"
		)
		return
	end

	if currencyId and isHiddenCurrency(currencyId) then
		self:LogDebug(
			"SKIP: This is a known hidden currency " .. tostring(msg),
			nil,
			nil,
			tostring(currencyId),
			"Skip showing currency"
		)
		return
	end

	local quantityChange = self:ParseCurrencyChangeMessage(msg)
	if quantityChange == nil or quantityChange <= 0 then
		self:LogDebug(
			"SKIP: there was a problem determining the quantity change " .. tostring(msg),
			nil,
			nil,
			tostring(currencyId),
			"Skip showing currency"
		)
		return
	end

	local currencyInfo = Currency.currencyApi.GetCurrencyInfo(currencyId)
	if not currencyInfo then
		self:LogDebug(
			"SKIP: No currency info found for msg = " .. msg,
			nil,
			nil,
			tostring(currencyId),
			"Skip showing currency"
		)
		return
	end

	if currencyInfo.currencyID == 0 then
		self:LogDebug(
			"Overriding " .. tostring(currencyInfo.name) .. " currencyID",
			nil,
			nil,
			tostring(currencyId),
			"Currency info has no ID"
		)
		currencyInfo.currencyID = currencyId
	end

	if currencyInfo.quantity == 0 then
		self:LogDebug(
			"Overriding " .. tostring(currencyInfo.name) .. " quantity to " .. tostring(quantityChange),
			nil,
			nil,
			tostring(currencyId),
			"Currency info has no quantity"
		)
		currencyInfo.quantity = quantityChange
	end

	local basicInfo = {
		displayAmount = quantityChange,
	}

	local currencyLink = Currency.currencyApi.GetCurrencyLinkFromGlobal(currencyId, currencyInfo.quantity)
	local payload = self:BuildPayload(currencyLink, currencyInfo, basicInfo)
	if payload then
		self.lootElementBase:fromPayload(payload):Show()
	else
		self:LogDebug("SKIP: Payload was nil", nil, nil, tostring(currencyInfo.currencyID), "Skip showing currency")
	end
end

function Currency:PERKS_PROGRAM_CURRENCY_AWARDED(eventName, quantityChange)
	self:RegisterEvent("PERKS_PROGRAM_CURRENCY_REFRESH")
	local currencyType = Currency.currencyApi.GetPerksProgramCurrencyID()
	self:LogInfo(eventName, "WOWEVENT", self.moduleName, tostring(currencyType), eventName, quantityChange)
	self:UnregisterEvent("PERKS_PROGRAM_CURRENCY_AWARDED")
end

function Currency:PERKS_PROGRAM_CURRENCY_REFRESH(eventName, oldQuantity, newQuantity)
	local currencyType = Currency.currencyApi.GetPerksProgramCurrencyID()
	local quantityChange = newQuantity - oldQuantity
	if quantityChange == 0 then
		return
	end
	self:Process(eventName, currencyType, quantityChange)
end

return Currency
