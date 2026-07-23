---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- FeatureBase is a factory that wraps G_RLF.RLF:NewModule so feature modules
--- do not call Ace directly.  This makes feature tests fully independent of
--- AceAddon plumbing: tests inject a mock ns.FeatureBase that returns a simple
--- stub table instead of a real AceModule.
---
--- Dependency Injection:
--- The new(moduleName, deps, ...) form accepts a deps table with:
---   deps.di = { fieldName = "DepName", ... }  -- resolved from G_RLF.DI
---   deps.logging = true                        -- injects LogDebug/LogInfo/etc
--- The old new(moduleName, ...aceMixins) form still works unchanged.
---
--- Design notes:
---   * fn (the xpcall error-wrapper) is intentionally absent from the prototype.
---     Features should use explicit error handling rather than silent swallowing.
---   * G_RLF.db is NOT captured here; it is nil until AceDB runs in OnInitialize.
---   * Dependency metadata is stored as module.__dependencies for future tooling
---     that cross-references deprecation notices against modules.
---@class RLF_FeatureBase
G_RLF.FeatureBase = {}

--- Creates and returns a new AceModule registered with the addon.
---
--- Two calling conventions:
---   1. FeatureBase:new(moduleName, "AceMixin-3.0", ...)
---      Legacy — identical to the original behavior.
---   2. FeatureBase:new(moduleName, { di = {...}, logging = true }, "AceMixin-3.0", ...)
---      New — resolves DI dependencies and injects logging methods.
---
---@param moduleName string  The unique module name (use G_RLF.FeatureModule.*)
---@param depsOrMixin table|string  Deps declaration table, or first Ace mixin name
---@param ... string                Additional Ace mixin names (e.g. "AceEvent-3.0")
---@return RLF_Module
function G_RLF.FeatureBase:new(moduleName, depsOrMixin, ...)
	local deps = {}
	local mixins = {}

	if type(depsOrMixin) == "table" then
		deps = depsOrMixin
		mixins = { ... }
	else
		mixins = { depsOrMixin, ... }
	end

	local module = G_RLF.RLF:NewModule(moduleName, unpack(mixins))

	-- ── Resolve DI dependencies ──────────────────────────────────────────────
	for fieldName, depName in pairs(deps.di or {}) do
		module[fieldName] = G_RLF.DI:Resolve(depName)
	end

	-- ── Inject logging methods ──────────────────────────────────────────────
	-- Each method auto-fills source=addonName and type=moduleName when omitted.
	-- Callers can override both positional args: self:LogDebug(msg, "WOWEVENT")
	if deps.logging then
		module.LogDebug = function(self, message, source, type, id, content, amount, isNew)
			G_RLF:LogDebug(message, source or addonName, type or self.moduleName, id, content, amount, isNew)
		end
		module.LogInfo = function(self, message, source, type, id, content, amount, isNew)
			G_RLF:LogInfo(message, source or addonName, type or self.moduleName, id, content, amount, isNew)
		end
		module.LogWarn = function(self, message, source, type, id, content, amount, isNew)
			G_RLF:LogWarn(message, source or addonName, type or self.moduleName, id, content, amount, isNew)
		end
		module.LogError = function(self, message, source, type, id, content, amount, isNew)
			G_RLF:LogError(message, source or addonName, type or self.moduleName, id, content, amount, isNew)
		end
	end

	-- ── Store metadata for future tooling ─────────────────────────────────────
	module.__dependencies = deps

	return module
end

return {}
