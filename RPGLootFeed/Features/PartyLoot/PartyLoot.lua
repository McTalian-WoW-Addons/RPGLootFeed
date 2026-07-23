---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_PartyLoot: RLF_Module, AceEvent-3.0
local PartyLoot = G_RLF.FeatureBase:new("PartyLoot", {
	di = {
		lootElementBase = "LootElementBase",
		itemQualEnum = "ItemQualEnum",
		itemInfo = "ItemInfo",
		partyLootApi = "WoWAPI.PartyLoot",
		isRetail = "IsRetail",
	},
	logging = true,
}, "AceEvent-3.0")

local onlyEpicPartyLoot = false

--- Builds a uniform payload table for a party loot event.
--- Filtering (quality, ignore list) must be applied by the caller before
--- invoking this method.  Returns nil when the module is disabled.
---@param info RLF_ItemInfo
---@param amount number
---@param unit string
---@return RLF_ElementPayload?
function PartyLoot:BuildPayload(info, amount, unit)
	if not PartyLoot:IsEnabled() then
		return nil
	end

	local payload = {}

	payload.key = info.itemLink
	payload.type = G_RLF.FeatureModule.PartyLoot
	payload.isLink = true
	payload.unit = unit
	-- Filter metadata evaluated per-frame by LootDisplayFrame:PassesPerFrameFilters
	payload.filterItemId = info.itemId
	payload.filterItemQuality = info.itemQuality

	payload.icon = info.itemTexture
	local partyConfig = G_RLF.DbAccessor:AnyFeatureConfig("partyLoot") or {}
	if not partyConfig.enableIcon or G_RLF.db.global.misc.hideAllIcons then
		payload.icon = nil
	end

	if info.keystoneInfo ~= nil then
		payload.quality = self.itemQualEnum.Epic
	end

	local itemLink = info.itemLink
	payload.textFn = function(existingQuantity, truncatedLink)
		if not truncatedLink then
			return itemLink
		end
		return truncatedLink
	end

	payload.quantity = amount
	payload.amountTextFn = function(existingQuantity)
		local effectiveQuantity = (existingQuantity or 0) + amount
		if effectiveQuantity == 1 and not G_RLF.db.global.misc.showOneQuantity then
			return ""
		end
		return "x" .. effectiveQuantity
	end

	payload.secondaryText = "A former party member"
	local name, server = self.partyLootApi.UnitName(unit)
	if name then
		local pConfig = G_RLF.DbAccessor:AnyFeatureConfig("partyLoot") or {}
		if server and pConfig.hideServerNames == false then
			payload.secondaryText = "    " .. name .. "-" .. server
		else
			payload.secondaryText = "    " .. name
		end
	end

	local equipmentTypeText = info:GetEquipmentTypeText()
	if equipmentTypeText then
		payload.secondaryText = payload.secondaryText .. equipmentTypeText
	end

	payload.secondaryTextFn = function()
		return payload.secondaryText
	end

	if self.partyLootApi.GetExpansionLevel() >= G_RLF.Expansion.BFA then
		payload.secondaryTextColor = self.partyLootApi.GetClassColor(select(2, self.partyLootApi.UnitClass(unit)))
	else
		payload.secondaryTextColor = self.partyLootApi.GetRaidClassColor(select(2, self.partyLootApi.UnitClass(unit)))
	end

	payload.moduleRef = PartyLoot

	return payload
end

function PartyLoot:OnInitialize()
	self.pendingItemRequests = {}
	self.pendingPartyRequests = {}
	self.nameUnitMap = {}
	if G_RLF.DbAccessor:IsFeatureNeededByAnyFrame("partyLoot") then
		self:Enable()
	else
		self:Disable()
	end
end

function PartyLoot:OnDisable()
	self:UnregisterEvent("CHAT_MSG_LOOT")
	self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
	self:UnregisterEvent("GROUP_ROSTER_UPDATE")
end

function PartyLoot:OnEnable()
	self:RegisterEvent("CHAT_MSG_LOOT")
	self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	self:SetNameUnitMap()
	self:SetPartyLootFilters()
	self:LogDebug("OnEnable", addonName, self.moduleName)
end

function PartyLoot:SetNameUnitMap()
	local units = {}
	local groupMembers = self.partyLootApi.GetNumGroupMembers()
	if self.partyLootApi.IsInRaid() then
		for i = 1, groupMembers do
			table.insert(units, "raid" .. i)
		end
	else
		table.insert(units, "player")

		for i = 2, groupMembers do
			table.insert(units, "party" .. (i - 1))
		end
	end

	self.nameUnitMap = {}
	for _, unit in ipairs(units) do
		local name, server = self.partyLootApi.UnitName(unit)
		if name then
			self.nameUnitMap[name] = unit
		else
			self:LogError("Failed to get name for unit: " .. unit, addonName, self.moduleName)
		end
	end
end

function PartyLoot:SetPartyLootFilters()
	local plConfig = G_RLF.DbAccessor:AnyFeatureConfig("partyLoot") or {}
	if self.partyLootApi.IsInRaid() and plConfig.onlyEpicAndAboveInRaid then
		onlyEpicPartyLoot = true
		return
	end

	if self.partyLootApi.IsInInstance() and plConfig.onlyEpicAndAboveInInstance then
		onlyEpicPartyLoot = true
		return
	end

	onlyEpicPartyLoot = false
end

function PartyLoot:OnPartyReadyToShow(info, amount, unit)
	if not unit then
		return
	end
	if onlyEpicPartyLoot and info.itemQuality < self.itemQualEnum.Epic then
		return
	end
	-- Quality filter and deny list have moved to LootDisplayFrame:PassesPerFrameFilters
	-- so they are evaluated per-frame rather than against a single "any" config.
	self.pendingPartyRequests[info.itemId] = nil

	local payload = PartyLoot:BuildPayload(info, amount, unit)
	if not payload then
		return
	end
	local e = self.lootElementBase:fromPayload(payload)
	e:Show(info.itemName, info.itemQuality)
end

function PartyLoot:ShowPartyLoot(msg, itemLink, unit)
	local amount = tonumber(msg:match("r ?x(%d+)") or 1)
	local itemId = itemLink:match("Hitem:(%d+)")
	self.pendingPartyRequests[itemId] = { itemLink, amount, unit }
	local info = self.itemInfo:new(itemId, self.partyLootApi.GetItemInfo(itemLink))
	if info ~= nil then
		self:OnPartyReadyToShow(info, amount, unit)
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

function PartyLoot:CHAT_MSG_LOOT(eventName, ...)
	if not G_RLF.DbAccessor:IsFeatureNeededByAnyFrame("partyLoot") then
		return
	end

	local msg, playerName, _, _, playerName2, _, _, _, _, _, _, guid = ...
	if self.partyLootApi.IssecretValue(msg) then
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
		return
	end

	local me = false
	if self.isRetail() then
		me = guid == self.partyLootApi.GetPlayerGuid()
	-- So far, MoP Classic and below doesn't work with GetPlayerGuid()
	else
		me = playerName2 == self.partyLootApi.UnitName("player")
	end

	if me then
		-- Ignore our own loot, handled by ItemLoot
		return
	end

	local name = playerName
	if name == "" or name == nil then
		name = playerName2
	end
	local sanitizedPlayerName = name:gsub("%-.+", "")
	local unit = self.nameUnitMap[sanitizedPlayerName]
	if not unit then
		self:LogDebug(
			"Party Loot Ignored - no matching party member (" .. sanitizedPlayerName .. ")",
			"WOWEVENT",
			self.moduleName,
			"",
			msg
		)
		return
	end

	local itemLinks = extractItemLinks(msg)
	local itemLink = itemLinks[1]

	if #itemLinks == 2 then
		-- Item upgrades are not supported for party members currently
		self:LogDebug(
			"Party item upgrades are apparently captured in CHAT_MSG_LOOT. TODO: may need to support this.",
			addonName,
			self.moduleName
		)
		return
	end

	if itemLink then
		self.ShowPartyLoot(self, msg, itemLink, unit)
	end
end

function PartyLoot:GET_ITEM_INFO_RECEIVED(eventName, itemID, success)
	if self.pendingPartyRequests[itemID] then
		local itemLink, amount, unit = unpack(self.pendingPartyRequests[itemID])

		if not success then
			error("Failed to load item: " .. itemID .. " " .. itemLink .. " x" .. amount .. " for " .. unit)
		else
			local info = self.itemInfo:new(itemID, self.partyLootApi.GetItemInfo(itemLink))
			self:OnPartyReadyToShow(info, amount, unit)
		end
	end
end

function PartyLoot:GROUP_ROSTER_UPDATE(eventName, ...)
	self:LogInfo(eventName, "WOWEVENT", self.moduleName, nil, eventName)
	self:SetNameUnitMap()
	self:SetPartyLootFilters()
end

return PartyLoot
