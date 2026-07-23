---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- ── Feature module ────────────────────────────────────────────────────────────

---@class RLF_Professions: RLF_Module, AceEvent-3.0
local Professions = G_RLF.FeatureBase:new("Professions", {
	di = {
		lootElementBase = "LootElementBase",
		defaultIcons = "DefaultIcons",
		itemQualEnum = "ItemQualEnum",
		professionsApi = "WoWAPI.Professions",
	},
	logging = true,
}, "AceEvent-3.0")

--- Builds a uniform payload for LootElementBase:fromPayload().
---@param key string Unique key for this profession (typically skillName)
---@param name string Profession name to display
---@param icon number|string Profession icon texture ID
---@param level number Current skill level
---@param quantity number Skill level delta (change amount this gain)
---@return RLF_ElementPayload
function Professions:BuildPayload(key, name, icon, level, quantity)
	local profConfig = G_RLF.DbAccessor:AnyFeatureConfig("profession") or {}
	local color = G_RLF:RGBAToHexFormat(unpack(profConfig.skillColor or { 0.333, 0.333, 1.0, 1.0 }))

	---@type RLF_ElementPayload
	local payload = {
		-- Routing
		key = "PROF_" .. key,
		type = G_RLF.FeatureModule.Profession,

		-- Icon
		icon = (profConfig.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and icon or nil,
		quality = self.itemQualEnum.Rare,

		-- Primary line
		quantity = quantity,
		textFn = function()
			return color .. name .. " " .. level .. "|r"
		end,

		-- Secondary line
		secondaryTextFn = function()
			return ""
		end,

		-- Item count display (skill delta)
		itemCountFn = function(netAmount)
			local profCfg = G_RLF.DbAccessor:AnyFeatureConfig("profession") or {}
			if not profCfg.showSkillChange then
				return nil
			end
			return netAmount or quantity,
				{
					color = G_RLF:RGBAToHexFormat(unpack(profCfg.skillColor or { 0.333, 0.333, 1.0, 1.0 })),
					wrapChar = profCfg.skillTextWrapChar,
					showSign = true,
				}
		end,

		-- Lifecycle
		moduleRef = Professions,
	}

	return payload
end

local segments
function Professions:OnInitialize()
	self.professions = {}
	self.profNameIconMap = {}
	self.profLocaleBaseNames = {}
	if G_RLF.DbAccessor:IsFeatureNeededByAnyFrame("profession") then
		self:Enable()
	else
		self:Disable()
	end
	local pattern = self.professionsApi.GetSkillRankUpPattern()
	segments = G_RLF:CreatePatternSegmentsForStringNumber(pattern)
end

function Professions:OnDisable()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("CHAT_MSG_SKILL")
end

function Professions:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("CHAT_MSG_SKILL")
	self:LogDebug("OnEnable")
end

function Professions:InitializeProfessions()
	local primaryId, secondaryId, archId, fishingId, cookingId = self.professionsApi.GetProfessions()
	local profs = { primaryId, secondaryId, archId, fishingId, cookingId }
	for i = 1, #profs do
		if profs[i] then
			local name, icon, skillLevel, maxSkillLevel, numAbilities, spellOffset, skillLine, skillModifier, specializationIndex, specializationOffset, a, b =
				self.professionsApi.GetProfessionInfo(profs[i])
			if name and icon then
				self.profNameIconMap[name] = icon
			end
		end
	end

	for k, v in pairs(self.profNameIconMap) do
		table.insert(self.profLocaleBaseNames, k)
	end
end

function Professions:PLAYER_ENTERING_WORLD()
	Professions:InitializeProfessions()
end

function Professions:CHAT_MSG_SKILL(event, message)
	if self.professionsApi.IssecretValue(message) then
		self:LogWarn(event .. " Secret value detected, ignoring chat message", "WOWEVENT")
		return
	end

	self:LogInfo(event, "WOWEVENT", nil, message)

	local skillName, skillLevel = G_RLF:ExtractDynamicsFromPattern(message, segments)
	if skillName and skillLevel then
		if not self.professions[skillName] then
			self.professions[skillName] = {
				name = skillName,
				lastSkillLevel = skillLevel,
			}
		end
		local icon
		if self.profNameIconMap[skillName] then
			icon = self.profNameIconMap[skillName]
		else
			for i = 1, #self.profLocaleBaseNames do
				if skillName:find(self.profLocaleBaseNames[i]) then
					icon = self.profNameIconMap[self.profLocaleBaseNames[i]]
					self.profNameIconMap[skillName] = icon
					break
				end
			end
		end
		if not icon then
			icon = self.defaultIcons.PROFESSION
		end
		local payload = self:BuildPayload(
			skillName,
			skillName,
			icon,
			skillLevel,
			skillLevel - self.professions[skillName].lastSkillLevel
		)
		self.lootElementBase:fromPayload(payload):Show()
		self.professions[skillName].lastSkillLevel = skillLevel
	end
end

return Professions
