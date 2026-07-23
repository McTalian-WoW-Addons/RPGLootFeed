---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- ── Feature module ────────────────────────────────────────────────────────────

---@class RLF_Experience: RLF_Module, AceEvent-3.0
local Xp = G_RLF.FeatureBase:new("Experience", {
	di = {
		lootElementBase = "LootElementBase",
		defaultIcons = "DefaultIcons",
		itemQualEnum = "ItemQualEnum",
		textTemplateEngine = "TextTemplateEngine",
		xpApi = "WoWAPI.Experience",
		rgbToHex = "RGBAToHexFormat",
	},
	logging = true,
}, "AceEvent-3.0")
local currentXP, currentMaxXP, currentLevel

-- Context provider function to be registered when module is enabled
local function createExperienceContextProvider()
	return function(context, data)
		-- Basic XP display
		context.xpLabel = G_RLF.L["XP"]

		-- Current XP percentage for secondary text
		if currentXP and currentMaxXP and currentMaxXP > 0 then
			local percentage = currentXP / currentMaxXP * 100
			context.currentXPPercentage = string.format("%.2f", percentage) .. "%%" -- need to escape % since it's being used in a gsub later
		else
			-- When XP data is not available, provide empty percentage
			context.currentXPPercentage = ""
		end
	end
end

--- Build a uniform payload from an XP delta.
--- This is the service layer: it transforms the XP gain into the generic
--- RLF_ElementPayload contract that LootElementBase:fromPayload() consumes.
---@param quantity number The XP delta gained
---@return RLF_ElementPayload|nil payload nil if quantity is missing or zero
function Xp:BuildPayload(quantity)
	if not quantity or quantity == 0 then
		return nil
	end

	-- Capture DI-injected services for use inside closures
	local _textTemplateEngine = self.textTemplateEngine
	local _rgbToHex = self.rgbToHex

	-- Generate text elements using the data-driven approach
	local textElements = self:GenerateTextElements(quantity)

	local xpConfig = G_RLF.DbAccessor:AnyFeatureConfig("experience") or {}

	---@type RLF_LootElementData
	local elementData = {
		key = "EXPERIENCE",
		type = G_RLF.FeatureModule.Experience,
		textElements = textElements,
		quantity = quantity,
		icon = (xpConfig.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and self.defaultIcons.XP or nil,
		quality = self.itemQualEnum.Epic,
	}

	---@type RLF_ElementPayload
	local payload = {
		-- Routing
		key = "EXPERIENCE",
		type = G_RLF.FeatureModule.Experience,

		-- Icon
		icon = elementData.icon,
		quality = self.itemQualEnum.Epic,

		-- Primary line
		quantity = quantity,
		textFn = function(existingXP)
			return _textTemplateEngine:ProcessRowElements(1, elementData, existingXP)
		end,

		-- Secondary line
		secondaryTextFn = function(existingXP)
			return _textTemplateEngine:ProcessRowElements(2, elementData, existingXP)
		end,

		-- Item count display (current level)
		itemCountFn = function()
			local xpCfg = G_RLF.DbAccessor:AnyFeatureConfig("experience") or {}
			if not xpCfg.showCurrentLevel then
				return nil
			end
			return currentLevel,
				{
					color = _rgbToHex(unpack(xpCfg.currentLevelColor or { 0.749, 0.737, 0.012, 1 })),
					wrapChar = xpCfg.currentLevelTextWrapChar,
				}
		end,

		-- Lifecycle
		moduleRef = Xp,
	}

	return payload
end

--- Generate text elements for Experience type using the new data-driven approach
---@param quantity number The experience amount
---@return table<number, table<string, RLF_TextElement>> textElements Row-indexed elements: [row][elementKey] = element
function Xp:GenerateTextElements(quantity)
	local elements = {}

	local xpTextColor = (G_RLF.DbAccessor:AnyFeatureConfig("experience") or {}).experienceTextColor or { 1, 0, 1, 0.8 }

	-- Row 1: Primary experience display
	elements[1] = {}
	elements[1].primary = {
		type = "primary",
		template = "{sign}{total} {xpLabel}",
		order = 1,
		color = xpTextColor,
	}

	-- Row 2: Context text element (XP percentage)
	elements[2] = {}
	elements[2].contextSpacer = {
		type = "spacer",
		spacerCount = 4, -- "    " spacing
		order = 1,
	}

	elements[2].context = {
		type = "context",
		template = "{currentXPPercentage}",
		order = 2,
		color = xpTextColor,
	}

	return elements
end

local function initXpValues()
	currentXP = Xp.xpApi.UnitXP("player")
	currentMaxXP = Xp.xpApi.UnitXPMax("player")
	currentLevel = Xp.xpApi.UnitLevel("player")
end

function Xp:OnInitialize()
	if G_RLF.DbAccessor:IsFeatureNeededByAnyFrame("experience") then
		self:Enable()
	else
		self:Disable()
	end
end

function Xp:OnDisable()
	-- Unregister our context provider
	self.textTemplateEngine.contextProviders["Experience"] = nil

	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("PLAYER_XP_UPDATE")
end

function Xp:OnEnable()
	self:LogDebug("OnEnable")

	-- Register our context provider with the TextTemplateEngine
	self.textTemplateEngine:RegisterContextProvider("Experience", createExperienceContextProvider())

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_XP_UPDATE")
	if currentXP == nil then
		initXpValues()
	end
end

function Xp:PLAYER_ENTERING_WORLD(eventName)
	self:LogInfo(eventName, "WOWEVENT")
	initXpValues()
end

function Xp:PLAYER_XP_UPDATE(eventName, unitTarget)
	self:LogInfo(eventName, "WOWEVENT", nil, unitTarget)
	if unitTarget ~= "player" then
		return
	end

	local oldLevel = currentLevel
	local oldCurrentXP = currentXP
	local oldMaxXP = currentMaxXP
	local newLevel = Xp.xpApi.UnitLevel(unitTarget)
	if newLevel == nil then
		self:LogWarn("Could not get player level")
		return
	end
	currentLevel = newLevel
	currentXP = Xp.xpApi.UnitXP(unitTarget)
	currentMaxXP = Xp.xpApi.UnitXPMax(unitTarget)
	local delta = 0
	if newLevel > oldLevel then
		delta = (oldMaxXP - oldCurrentXP) + currentXP
	else
		delta = currentXP - oldCurrentXP
	end

	if delta > 0 then
		local payload = self:BuildPayload(delta)
		if payload then
			local e = self.lootElementBase:fromPayload(payload)
			e:Show()
		end
	else
		self:LogWarn(eventName .. " fired but delta was not positive")
	end
end

return Xp
