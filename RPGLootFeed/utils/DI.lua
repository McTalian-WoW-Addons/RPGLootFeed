---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- RLF Dependency Injection container.
---
--- Stores named dependencies (WoW API adapters, services, enums) that feature
--- modules declare via FeatureBase:new(name, { di = { field = "DepName" }, ... }).
---
--- Design:
---   * Dependencies are registered by name at load time (or per-test).
---   * FeatureBase:new() resolves declared deps from this container before
---     stamping them on the module table, so feature code accesses them via
---     self.field instead of capturing G_RLF globals as closure locals.
---   * Tests register mock dependencies before loading the module under test,
---     eliminating the need for post-load adapter swaps.
---
--- Future tooling: the declaration table lives on each module as
--- module.__dependencies so a patch-note scanner can cross-reference
--- "WoWAPI.Money.GetMoney deprecated" against all modules that declare it.
---@class RLF_DI
G_RLF.DI = {
	---@type table<string, any>
	registry = {},
}

--- Register a dependency by name.
---@param name string  Unique key (e.g. "WoWAPI.Money", "LootElementBase")
---@param instance any  The dependency value
function G_RLF.DI:Register(name, instance)
	self.registry[name] = instance
end

--- Resolve a previously-registered dependency.
---@param name string
---@return any
function G_RLF.DI:Resolve(name)
	return self.registry[name]
end

--- Clear all registered dependencies (used in test teardown).
function G_RLF.DI:Reset()
	self.registry = {}
end

return {}
