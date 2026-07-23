---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- logging and DI injected via FeatureBase

---@class RLF_ItemLoot: RLF_Module, AceEvent-3.0, AceBucket-3.0
local ItemLoot = G_RLF.FeatureBase:new("ItemLoot", {
	di = {
		lootElementBase = "LootElementBase",
		itemQualEnum = "ItemQualEnum",
		itemInfo = "ItemInfo",
		itemLootApi = "WoWAPI.ItemLoot",
		textTemplateEngine = "TextTemplateEngine",
		isRetail = "IsRetail",
		soundService = "SoundService",
	},
	logging = true,
}, "AceEvent-3.0", "AceBucket-3.0")

--- Decompose a copper price amount into denomination parts.
--- Returns gold, silver, copper, plus the resolved atlas icon and its size.
--- Used by secondaryCoinDataFn so the row's SecondaryCoinDisplay renders
--- real Textures instead of |T|/|A| markup.
---@param icon string Atlas name for the vendor / AH icon
---@param fontSize number Secondary font size (used to scale the icon)
---@param price number Price in copper
---@return number, number, number, string, number  -- gold, silver, copper, prefixAtlas, prefixSize
local function getPriceParts(icon, fontSize, price)
	if not price or price <= 0 then
		return 0, 0, 0, icon or "", fontSize or 0
	end
	local sizeCoeff = G_RLF.AtlasIconCoefficients[icon] or 1
	local iconSize = fontSize * sizeCoeff
	local gold = math.floor(price / 10000)
	local silver = math.floor((price % 10000) / 100)
	local copper = price % 100
	return gold, silver, copper, icon or "", iconSize
end

-- ── Context provider ──────────────────────────────────────────────────────────

local function createItemLootContextProvider()
	return function(context, data)
		-- Quest color override for the item link (Row 1)
		if data.linkOverrides then
			for _, override in ipairs(data.linkOverrides) do
				if override.condition then
					context.truncatedLink = context.truncatedLink:gsub("|c.-|", override.colorHex .. "|")
					break
				end
			end
		end

		-- Secondary text (Row 2) — full branching logic
		context.secondaryText = ""
		local info = data.info
		local fromInfo = data.fromInfo
		local fromLink = data.fromLink
		local quantity = data.quantity

		if not info then
			return
		end

		local stylingDb = G_RLF.DbAccessor:Styling(G_RLF.Frames.MAIN)
		local secondaryFontSize = stylingDb.secondaryFontSize

		if fromLink and fromLink ~= "" and fromInfo then
			context.secondaryText = info:GetUpgradeText(fromInfo, secondaryFontSize)
			return
		end

		if info:IsEquippableItem() then
			local secondaryText = ""
			if info:HasItemRollBonus() then
				secondaryText = info:GetItemRollText()
			end
			local equipmentTypeText = info:GetEquipmentTypeText()
			if equipmentTypeText then
				context.secondaryText = secondaryText .. equipmentTypeText
				return
			end
			context.secondaryText = secondaryText
			return
		end

		-- Non-equippable: price display
		local effectiveQuantity = context.total
		local itemCfg = G_RLF.DbAccessor:AnyFeatureConfig("itemLoot") or {}
		local vendorPrice, auctionPrice = 0, 0
		local pricesForSellableItems = itemCfg.pricesForSellableItems
		if info.sellPrice and info.sellPrice > 0 then
			vendorPrice = info.sellPrice
		end
		local marketPrice = ItemLoot.itemLootApi.GetAHPrice(data.itemLink)
		if marketPrice and marketPrice > 0 then
			auctionPrice = marketPrice
		end
		local showVendorPrice = vendorPrice > 0
		local showAuctionPrice = auctionPrice > 0

		-- Single-price: return spacer so SecondaryCoinDisplay renders real textures
		if pricesForSellableItems == G_RLF.PricesEnum.Vendor and showVendorPrice then
			context.secondaryText = " "
			return
		elseif pricesForSellableItems == G_RLF.PricesEnum.AH and showAuctionPrice then
			context.secondaryText = " "
			return
		elseif pricesForSellableItems == G_RLF.PricesEnum.Highest then
			if showAuctionPrice or showVendorPrice then
				context.secondaryText = " "
				return
			end
		end

		-- Multi-price: plain text
		local function plainPrice(copper)
			local g = math.floor(copper / 10000)
			local s = math.floor((copper % 10000) / 100)
			local c = copper % 100
			local parts = {}
			if g > 0 then
				table.insert(parts, g .. "g")
			end
			if s > 0 or g > 0 then
				table.insert(parts, s .. "s")
			end
			table.insert(parts, c .. "c")
			return table.concat(parts, " ")
		end

		local str = ""
		if pricesForSellableItems == G_RLF.PricesEnum.VendorAH then
			if showVendorPrice then
				str = str .. plainPrice(vendorPrice * effectiveQuantity)
			end
			if showVendorPrice and showAuctionPrice then
				str = str .. "    "
			end
			if showAuctionPrice then
				str = str .. plainPrice(auctionPrice * effectiveQuantity)
			end
		elseif pricesForSellableItems == G_RLF.PricesEnum.AHVendor then
			if showAuctionPrice then
				str = str .. plainPrice(auctionPrice * effectiveQuantity)
			end
			if showAuctionPrice and showVendorPrice then
				str = str .. "    "
			end
			if showVendorPrice then
				str = str .. plainPrice(vendorPrice * effectiveQuantity)
			end
		end
		context.secondaryText = str
	end
end

-- ── Text elements ─────────────────────────────────────────────────────────────

--- Generate text elements for ItemLoot type.
--- Row 1: item link (with optional quest color override from context provider)
--- Row 2: secondary text (upgrade / equipment / prices via context provider)
function ItemLoot:GenerateTextElements()
	local elements = {}

	elements[1] = {}
	elements[1].primary = {
		type = "primary",
		template = "{truncatedLink}",
		order = 1,
	}

	elements[2] = {}
	elements[2].context = {
		type = "context",
		template = "{secondaryText}",
		order = 1,
	}

	return elements
end

function ItemLoot:ItemQualityName(enumValue)
	for k, v in pairs(Enum.ItemQuality) do
		if v == enumValue then
			return k
		end
	end
	return nil
end

local function IsBetterThanEquipped(info)
	if info:IsEligibleEquipment() then
		local equippedLink
		local slot = G_RLF.equipSlotMap[info.itemEquipLoc]
		if type(slot) == "table" then
			for _, s in ipairs(slot) do
				equippedLink = ItemLoot.itemLootApi.GetInventoryItemLink("player", s)
				if equippedLink then
					break
				end
			end
		else
			equippedLink = ItemLoot.itemLootApi.GetInventoryItemLink("player", slot)
		end

		if not equippedLink then
			return false
		end

		local equippedId = ItemLoot.itemLootApi.GetItemIDForItemInfo(equippedLink)
		local equippedInfo = ItemLoot.itemInfo:new(equippedId, ItemLoot.itemLootApi.GetItemInfo(equippedLink))
		if not equippedInfo then
			return false
		end

		if equippedInfo.itemQuality > ItemLoot.itemQualEnum.Poor and info.itemQuality == ItemLoot.itemQualEnum.Poor then
			-- If the equipped item is better than poor and the new item is poor, we don't consider it an upgrade
			return false
		end
		if
			equippedInfo.itemQuality > ItemLoot.itemQualEnum.Common
			and info.itemQuality == ItemLoot.itemQualEnum.Common
		then
			-- If the equipped item is better than common and the new item is common, we don't consider it an upgrade
			return false
		end
		if equippedInfo.itemLevel and equippedInfo.itemLevel < info.itemLevel then
			return true
		elseif equippedInfo.itemLevel == info.itemLevel then
			local statDelta = ItemLoot.itemLootApi.GetItemStatDelta(equippedLink, info.itemLink)
			for k, v in pairs(statDelta) do
				-- Has a Tertiary Stat
				if k:find("ITEM_MOD_CR_") and v > 0 then
					return true
				end
				-- Has a Gem Socket
				if k:find("EMPTY_SOCKET_") and v > 0 then
					return true
				end
			end
		end
	end

	return false
end

---@param info RLF_ItemInfo
---@param quantity number
---@param fromLink? string
---@return RLF_ElementPayload|nil
function ItemLoot:BuildPayload(info, quantity, fromLink)
	-- Quality filter and deny list have moved to LootDisplayFrame:PassesPerFrameFilters
	-- so they are evaluated per-frame rather than against a single "any" config.
	local itemConfig = G_RLF.DbAccessor:AnyFeatureConfig("itemLoot") or {}
	-- Quality duration overrides are resolved per-frame in LootDisplayRow:BootstrapFromElement
	-- using the frame's own itemQualitySettings, not a single shared config.

	local itemLink = info.itemLink
	local key = itemLink
	local fromInfo = nil
	if fromLink then
		key = "UPGRADE_" .. key
		fromInfo = ItemLoot.itemInfo:new(
			ItemLoot.itemLootApi.GetItemIDForItemInfo(fromLink),
			ItemLoot.itemLootApi.GetItemInfo(fromLink)
		)
	end

	local icon = info.itemTexture
	if not itemConfig.enableIcon or G_RLF.db.global.misc.hideAllIcons then
		icon = nil
	end

	-- Keystone: force display quality to Epic
	local quality = nil
	if info:IsKeystone() then
		quality = info:GetDisplayQuality()
	end

	local topLeftText = nil
	local topLeftColor = nil
	if info:IsEquippableItem() and info.itemQuality > ItemLoot.itemQualEnum.Poor then
		topLeftText = tostring(info.itemLevel)
		local r, g, b = ItemLoot.itemLootApi.GetItemQualityColor(info.itemQuality)
		topLeftColor = { r, g, b }
	end

	-- ── Compute item flags ────────────────────────────────────────────────────
	local isMount = info:IsMount()
	local isLegendary = info:IsLegendary()
	local isBetterThanEquipped = IsBetterThanEquipped(info)
	local hasTertiaryOrSocket = info:HasItemRollBonus()
	local isQuestItem = info:IsQuestItem()
	local isNewTransmog = not info:IsAppearanceCollected()

	-- ── Highlight ────────────────────────────────────────────────────────────
	local itemHighlights = itemConfig.itemHighlights or {}
	local highlightReason = (isMount and itemHighlights.mounts and "Mount")
		or (isLegendary and itemHighlights.legendary and "Legendary")
		or (isBetterThanEquipped and itemHighlights.betterThanEquipped and "Better than Equipped")
		or (isQuestItem and itemHighlights.quest and "Quest Item")
		or (hasTertiaryOrSocket and itemHighlights.tertiaryOrSocket and "Tertiary or Socket")
		or (isNewTransmog and itemHighlights.transmog and "New Transmog")
	local highlight = highlightReason and true or false
	if highlight then
		self:LogDebug("Highlighted because of " .. highlightReason, addonName, self.moduleName, key)
	end

	-- ── Quest color override ─────────────────────────────────────────────────
	local r, g, b, a = nil, nil, nil, nil
	local textStyleOverrides = itemConfig.textStyleOverrides or {}
	if isQuestItem and textStyleOverrides.quest and textStyleOverrides.quest.enabled then
		r, g, b, a = unpack(textStyleOverrides.quest.color)
	end

	-- ── Sound: first matching condition wins ─────────────────────────────────
	local soundPath = nil
	local soundsConfig = itemConfig.sounds or {}
	if isMount and soundsConfig.mounts.enabled and soundsConfig.mounts.sound ~= "" then
		soundPath = soundsConfig.mounts.sound
	elseif isLegendary and soundsConfig.legendary.enabled and soundsConfig.legendary.sound ~= "" then
		soundPath = soundsConfig.legendary.sound
	elseif
		isBetterThanEquipped
		and soundsConfig.betterThanEquipped.enabled
		and soundsConfig.betterThanEquipped.sound ~= ""
	then
		soundPath = soundsConfig.betterThanEquipped.sound
	elseif isNewTransmog and soundsConfig.transmog.enabled and soundsConfig.transmog.sound ~= "" then
		soundPath = soundsConfig.transmog.sound
	end

	-- ── Element data (feeds TextTemplateEngine) ─────────────────────────────
	local textElements = self:GenerateTextElements()

	-- Build color override list for the context provider
	local linkOverrides = {}
	local tso = itemConfig.textStyleOverrides or {}
	if isQuestItem and tso.quest and tso.quest.enabled then
		table.insert(linkOverrides, {
			condition = true,
			colorHex = G_RLF:RGBAToHexFormat(unpack(tso.quest.color)),
		})
	end

	---@type RLF_LootElementData
	local elementData = {
		key = key,
		type = "ItemLoot",
		textElements = textElements,
		quantity = quantity,
		icon = icon,
		quality = quality,
		link = itemLink,
		-- Extra fields for context provider
		info = info,
		fromInfo = fromInfo,
		fromLink = fromLink,
		itemLink = itemLink,
		linkOverrides = #linkOverrides > 0 and linkOverrides or nil,
	}

	-- ── Payload ───────────────────────────────────────────────────────────────
	local payload = {
		key = key,
		type = G_RLF.FeatureModule.ItemLoot,
		icon = icon,
		quality = quality,
		topLeftText = topLeftText,
		topLeftColor = topLeftColor,
		isLink = true,
		quantity = quantity,
		highlight = highlight,
		sound = soundPath,
		r = r,
		g = g,
		b = b,
		a = a,
		filterItemId = info.itemId,
		filterItemQuality = info.itemQuality,
		moduleRef = ItemLoot,
	}

	payload.textFn = function(existingQuantity, truncatedLink)
		return self.textTemplateEngine:ProcessRowElements(1, elementData, existingQuantity, truncatedLink)
	end

	payload.amountTextFn = function(existingQuantity)
		local effectiveQuantity = (existingQuantity or 0) + quantity
		if effectiveQuantity == 1 and not G_RLF.db.global.misc.showOneQuantity then
			return ""
		end
		return "x" .. effectiveQuantity
	end

	payload.secondaryTextFn = function(...)
		return self.textTemplateEngine:ProcessRowElements(2, elementData)
	end

	-- secondaryCoinDataFn: drives SecondaryCoinDisplay (real Textures) for
	-- single-price modes.  Returns nil for multi-price modes so they fall back
	-- to the plain-text secondaryTextFn above.
	payload.secondaryCoinDataFn = function(existingQuantity)
		if info:IsEquippableItem() then
			return nil
		end
		local effectiveQuantity = (existingQuantity or 0) + quantity
		if effectiveQuantity <= 0 then
			effectiveQuantity = quantity
		end
		local itemCfg = G_RLF.DbAccessor:AnyFeatureConfig("itemLoot") or {}
		local pricesForSellableItems = itemCfg.pricesForSellableItems
		local vendorPrice = (info.sellPrice and info.sellPrice > 0) and info.sellPrice or 0
		local auctionPrice = 0
		local marketPrice = ItemLoot.itemLootApi.GetAHPrice(itemLink)
		if marketPrice and marketPrice > 0 then
			auctionPrice = marketPrice
		end
		local stylingDb = G_RLF.DbAccessor:Styling(G_RLF.Frames.MAIN)
		local secondaryFontSize = stylingDb.secondaryFontSize
		if pricesForSellableItems == G_RLF.PricesEnum.Vendor and vendorPrice > 0 then
			local g, s, c, atl, sz =
				getPriceParts(itemCfg.vendorIconTexture, secondaryFontSize, vendorPrice * effectiveQuantity)
			return g, s, c, atl, sz
		elseif pricesForSellableItems == G_RLF.PricesEnum.AH and auctionPrice > 0 then
			local g, s, c, atl, sz =
				getPriceParts(itemCfg.auctionHouseIconTexture, secondaryFontSize, auctionPrice * effectiveQuantity)
			return g, s, c, atl, sz
		elseif pricesForSellableItems == G_RLF.PricesEnum.Highest then
			if auctionPrice > vendorPrice and auctionPrice > 0 then
				local g, s, c, atl, sz =
					getPriceParts(itemCfg.auctionHouseIconTexture, secondaryFontSize, auctionPrice * effectiveQuantity)
				return g, s, c, atl, sz
			elseif vendorPrice > 0 then
				local g, s, c, atl, sz =
					getPriceParts(itemCfg.vendorIconTexture, secondaryFontSize, vendorPrice * effectiveQuantity)
				return g, s, c, atl, sz
			end
		end
		return nil
	end

	-- itemCountFn: replaces the ItemLoot branch in RowTextMixin:UpdateItemCount
	payload.itemCountFn = function()
		local itemDb = G_RLF.DbAccessor:AnyFeatureConfig("itemLoot") or {}
		if not itemDb.itemCountTextEnabled then
			return nil
		end
		local success, name = pcall(function()
			return ItemLoot.itemLootApi.GetItemInfo(itemLink)
		end)
		if not success or not name then
			return nil
		end
		local itemCount = ItemLoot.itemLootApi.GetItemCount(itemLink, true, false, true, true)
		return itemCount,
			{
				color = G_RLF:RGBAToHexFormat(unpack(itemDb.itemCountTextColor)),
				wrapChar = itemDb.itemCountTextWrapChar,
			}
	end

	return payload
end

function ItemLoot:OnInitialize()
	self.pendingItemRequests = {}
	if G_RLF.DbAccessor:IsFeatureNeededByAnyFrame("itemLoot") then
		self:Enable()
	else
		self:Disable()
	end
end

function ItemLoot:OnDisable()
	self.textTemplateEngine.contextProviders["ItemLoot"] = nil
	self:UnregisterEvent("CHAT_MSG_LOOT")
	self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
end

function ItemLoot:OnEnable()
	self.textTemplateEngine:RegisterContextProvider("ItemLoot", createItemLootContextProvider())
	self:RegisterEvent("CHAT_MSG_LOOT")
	self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	self:LogDebug("OnEnable", addonName, self.moduleName)
	if
		ItemLoot.itemLootApi.GetExpansionLevel() >= G_RLF.Expansion.CATA
		and ItemLoot.itemLootApi.GetExpansionLevel() <= G_RLF.Expansion.MOP
	then
		self:SetEquippableArmorClass()
	end
end

function ItemLoot:SetEquippableArmorClass()
	local _, playerClass = ItemLoot.itemLootApi.UnitClass("player")

	if
		playerClass == "ROGUE"
		or playerClass == "DRUID"
		or playerClass == "PRIEST"
		or playerClass == "MAGE"
		or playerClass == "WARLOCK"
	then
		return
	end

	local playerLevel = ItemLoot.itemLootApi.UnitLevel("player")
	if playerLevel < 40 then
		if not self.armorLevelListener then
			self.armorLevelListener = self:RegisterBucketEvent("PLAYER_LEVEL_UP", 1, "SetEquippableArmorClass")
		end
		G_RLF.armorClassMapping = G_RLF.legacyArmorClassMappingLowLevel
		return
	end

	if self.armorLevelListener then
		self:UnregisterBucket(self.armorLevelListener)
		self.armorLevelListener = nil
	end

	G_RLF.armorClassMapping = G_RLF.standardArmorClassMapping
end

---@param info RLF_ItemInfo
---@param amount number
---@param fromLink? string
function ItemLoot:OnItemReadyToShow(info, amount, fromLink)
	self.pendingItemRequests[info.itemId] = nil
	local payload = self:BuildPayload(info, amount, fromLink)
	if not payload then
		return
	end
	self.lootElementBase:fromPayload(payload):Show(info.itemName, info.itemQuality)
	if payload.sound then
		self.soundService:PlaySound(payload.sound)
	end
end

function ItemLoot:GET_ITEM_INFO_RECEIVED(eventName, itemID, success)
	self:LogInfo(eventName, "WOWEVENT", self.moduleName, nil, eventName .. " " .. itemID)
	if self.pendingItemRequests[itemID] then
		local itemLink, amount, fromLink = unpack(self.pendingItemRequests[itemID])

		if not success then
			error("Failed to load item: " .. itemID .. " " .. itemLink .. " x" .. amount)
		else
			local info = self.itemInfo:new(itemID, self.itemLootApi.GetItemInfo(itemLink))
			if info == nil then
				self:LogDebug("ItemInfo is nil for " .. itemLink, addonName, self.moduleName)
				return
			end
			self:OnItemReadyToShow(info, amount, fromLink)
		end
	end
end

function ItemLoot:ShowItemLoot(msg, itemLink, fromLink)
	local amount = tonumber(msg:match("r ?x(%d+)") or 1) or 1
	local itemId = self.itemLootApi.GetItemIDForItemInfo(itemLink)
	self.pendingItemRequests[itemId] = { itemLink, amount, fromLink }
	local info = self.itemInfo:new(itemId, self.itemLootApi.GetItemInfo(itemLink))
	if info ~= nil then
		self:OnItemReadyToShow(info, amount, fromLink)
	end
end

-- Function to extract item links from the message
local function extractItemLinks(message)
	local itemLinks = {}
	for itemLink in message:gmatch("|c.-|Hitem:.-|h%[.-%]|h|r") do
		table.insert(itemLinks, itemLink)
	end
	return itemLinks
end

function ItemLoot:CHAT_MSG_LOOT(eventName, ...)
	local msg, playerName, _, _, playerName2, _, _, _, _, _, _, guid = ...
	if self.itemLootApi.IssecretValue(msg) then
		self:LogWarn(
			"(" .. eventName .. ") Secret value detected, ignoring chat message",
			"WOWEVENT",
			self.moduleName,
			""
		)
		return
	end

	self:LogInfo(eventName, "WOWEVENT", self.moduleName, nil, eventName .. " " .. msg)

	local raidLoot = msg:match("HlootHistory:")
	if raidLoot then
		-- Ignore this message as it's a raid loot message
		self:LogDebug("Raid Loot Ignored", "WOWEVENT", self.moduleName, "", msg)
		return
	end

	local me = false
	if self.isRetail() then
		me = guid == self.itemLootApi.GetPlayerGuid()
	-- So far, MoP Classic and below doesn't work with GetPlayerGuid()
	else
		me = playerName2 == self.itemLootApi.UnitName("player")
	end

	-- Only process our own loot now, party loot is handled by PartyLoot module
	if not me then
		self:LogDebug("Loot ignored, not me", "WOWEVENT", self.moduleName, "", msg)
		return
	end

	local itemLink, fromLink = nil, nil
	local itemLinks = extractItemLinks(msg)

	-- Item Upgrades
	if #itemLinks == 2 then
		fromLink = itemLinks[1]
		itemLink = itemLinks[2]
	else
		itemLink = itemLinks[1]
	end

	if itemLink then
		self:ShowItemLoot(msg, itemLink, fromLink)
	end
end

return ItemLoot
