---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- ── Feature module ────────────────────────────────────────────────────────────

---@class RLF_Transmog: RLF_Module, AceEvent-3.0
local Transmog = G_RLF.FeatureBase:new("Transmog", {
	di = {
		lootElementBase = "LootElementBase",
		defaultIcons = "DefaultIcons",
		itemQualEnum = "ItemQualEnum",
		transmogApi = "WoWAPI.Transmog",
		textTemplateEngine = "TextTemplateEngine",
		isRetail = "IsRetail",
	},
	logging = true,
}, "AceEvent-3.0")

-- ── Context provider ──────────────────────────────────────────────────────────

local function createTransmogContextProvider()
	return function(context, data)
		local str = string.format(Transmog.transmogApi.GetErrLearnTransmogS(), " "):trim()
		-- Some locales have the string placeholder in the middle of the string
		str = str:gsub("   ", " ")
		-- Remove the trailing period if it exists
		str = str:gsub("%.$", "")
		context.learnMessage = str
	end
end

-- ── Text elements ─────────────────────────────────────────────────────────────

--- Generate text elements for the Transmog type.
--- Row 1: the transmog link (or truncated link)
--- Row 2: the learn-message string
function Transmog:GenerateTextElements()
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
		template = "{learnMessage}",
		order = 1,
	}

	return elements
end

-- ── BuildPayload ──────────────────────────────────────────────────────────────

--- Builds a uniform payload table for a transmog collection event.
--- Returns nil when the module is disabled.
---@param transmogLink string
---@param icon string?
---@return RLF_ElementPayload?
function Transmog:BuildPayload(transmogLink, icon)
	if not Transmog:IsEnabled() then
		return nil
	end

	local textElements = self:GenerateTextElements()

	---@type RLF_LootElementData
	local elementData = {
		key = "TMOG_" .. transmogLink,
		type = "Transmog",
		textElements = textElements,
		quantity = 0,
		icon = icon or self.defaultIcons.TRANSMOG,
		quality = self.itemQualEnum.Epic,
		link = transmogLink,
	}

	local payload = {}

	payload.key = "TMOG_" .. transmogLink
	payload.type = G_RLF.FeatureModule.Transmog
	payload.isLink = true

	payload.icon = elementData.icon
	local transmogConfig = G_RLF.DbAccessor:AnyFeatureConfig("transmog") or {}
	if not transmogConfig.enableIcon or G_RLF.db.global.misc.hideAllIcons then
		payload.icon = nil
	end

	payload.quality = self.itemQualEnum.Epic
	payload.highlight = self.isRetail()

	payload.textFn = function(existingQuantity, truncatedLink)
		return self.textTemplateEngine:ProcessRowElements(1, elementData, existingQuantity, truncatedLink)
	end

	payload.secondaryTextFn = function()
		return self.textTemplateEngine:ProcessRowElements(2, elementData)
	end

	payload.moduleRef = Transmog

	return payload
end

-- ── Module lifecycle ──────────────────────────────────────────────────────────

function Transmog:OnInitialize()
	if G_RLF.DbAccessor:IsFeatureNeededByAnyFrame("transmog") then
		self:Enable()
	else
		self:Disable()
	end
end

function Transmog:OnEnable()
	self:LogDebug("OnEnable")
	self.textTemplateEngine:RegisterContextProvider("Transmog", createTransmogContextProvider())
	self:RegisterEvent("TRANSMOG_COLLECTION_SOURCE_ADDED")
end

function Transmog:OnDisable()
	self.textTemplateEngine.contextProviders["Transmog"] = nil
	self:UnregisterEvent("TRANSMOG_COLLECTION_SOURCE_ADDED")
end

-- ── Event handlers ────────────────────────────────────────────────────────────

function Transmog:TRANSMOG_COLLECTION_SOURCE_ADDED(eventName, itemModifiedAppearanceID)
	self:LogInfo(eventName, "WOWEVENT", nil, itemModifiedAppearanceID)

	local info = self.transmogApi.GetAppearanceSourceInfo(itemModifiedAppearanceID)

	if not info then
		self:LogWarn("Could not get appearance source info")
		return
	end

	local itemLink = info.itemLink
	local transmogLink = info.transmoglink
	local icon = info.icon

	if not transmogLink or transmogLink == "" then
		self:LogWarn("Transmog link is empty for " .. itemModifiedAppearanceID)
		if itemLink and itemLink ~= "" then
			local item = self.transmogApi.CreateItemFromItemLink(itemLink)
			if item then
				item:ContinueOnItemLoad(function()
					info = self.transmogApi.GetAppearanceSourceInfo(itemModifiedAppearanceID)
					if not info then
						self:LogWarn("Could not get appearance source info on item load")
						return
					end

					itemLink = info.itemLink
					transmogLink = info.transmoglink
					icon = info.icon

					if not transmogLink or transmogLink == "" then
						self:LogWarn("Transmog link is still empty for " .. itemModifiedAppearanceID)
						transmogLink = itemLink
					end

					local payload = self:BuildPayload(transmogLink, icon)
					if payload then
						local e = self.lootElementBase:fromPayload(payload)
						e:Show()
					else
						self:LogWarn("Could not create Transmog Element")
					end
				end)
			end
		else
			self:LogWarn("Item link is also empty for " .. itemModifiedAppearanceID)
		end
		return
	end

	local payload = self:BuildPayload(transmogLink, icon)
	if payload then
		local e = self.lootElementBase:fromPayload(payload)
		e:Show()
	else
		self:LogWarn("Could not create Transmog Element")
	end
end

return Transmog
