---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local FeatureBase = G_RLF.FeatureBase
local FeatureModule = G_RLF.FeatureModule
local DbAccessor = G_RLF.DbAccessor

local LogDebug = function(...)
	G_RLF:LogDebug(...)
end
local LogInfo = function(...)
	G_RLF:LogInfo(...)
end
local LogWarn = function(...)
	G_RLF:LogWarn(...)
end

-- ── WoW API / Global abstraction adapters ────────────────────────────────────
-- The shared adapter lives in WoWAPIAdapters.lua (G_RLF.WoWAPI.ItemLoot).
-- Captured here at module-load time so tests can override _itemLootAdapter
-- without patching _G directly.

---@class RLF_LootRolls: RLF_Module, AceEvent-3.0, AceBucket-3.0
local LootRolls = FeatureBase:new(FeatureModule.LootRolls, "AceEvent-3.0", "AceBucket-3.0")

LootRolls._itemLootAdapter = G_RLF.WoWAPI.LootRolls

function LootRolls:OnInitialize()
	LogDebug("LootRolls:OnInitialize()", addonName, self.moduleName)
	if DbAccessor:IsFeatureNeededByAnyFrame("lootRolls") then
		self:Enable()
	else
		self:Disable()
	end
end

function LootRolls:OnDisable() end

function LootRolls:OnEnable()
	LogDebug("OnEnable", addonName, self.moduleName)
end
