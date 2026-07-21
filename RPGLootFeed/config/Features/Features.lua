---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local Features = {}

---@class RLF_DBGlobal
G_RLF.defaults.global = G_RLF.defaults.global or {}

---@class RLF_ConfigMisc
G_RLF.defaults.global.misc = {
	showOneQuantity = false,
	hideAllIcons = false,
}

---@class RLF_ConfigLootHistory
G_RLF.defaults.global.lootHistory = {
	enabled = true,
	hideTab = false,
	historyLimit = 100,
	tabSize = 14,
	tabFreePosition = false,
	tabXOffset = 0,
	tabYOffset = 0,
}
---@class RLF_ConfigTooltips
G_RLF.defaults.global.tooltips = {
	hover = {
		enabled = true,
		onShift = false,
	},
}
---@class RLF_ConfigInteractions
---@field disableMouseInCombat boolean
---@field pinOnHover boolean
G_RLF.defaults.global.interactions = {
	disableMouseInCombat = true,
	pinOnHover = true,
}
---@class RLF_ConfigMinimap : LibDBIcon.button.DB
---@field hide boolean
---@field lock boolean
---@field minimapPos integer
G_RLF.defaults.global.minimap = {
	hide = true,
	lock = false,
	minimapPos = 220,
}

G_RLF.mainFeatureOrder = {
	ItemLoot = 1,
	PartyLoot = 2,
	Currency = 3,
	Money = 4,
	Experience = 5,
	Reputation = 6,
	Profession = 7,
	TravelPoints = 8,
	Transmog = 9,
	LootRolls = 10,
}

return Features
