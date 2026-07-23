---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_Logger: RLF_Module, AceBucket-3.0, AceEvent-3.0
local Logger = G_RLF.RLF:NewModule(G_RLF.SupportModule.Logger, "AceBucket-3.0", "AceEvent-3.0")

-- ── Log storage ───────────────────────────────────────────────────────────────

local logger = nil
local initialized = false
function Logger:getLogger()
	if not initialized then
		initialized = true
		G_RLF.db.global.logger = {}
	end
	if logger == nil then
		logger = G_RLF.db.global.logger or {}
	end
	return logger
end

-- ── Log entry formatting ─────────────────────────────────────────────────────

local WOWEVENT = G_RLF.LogEventSource.WOWEVENT

local levelColors = {
	[G_RLF.LogLevel.debug] = "|cFF808080{D}|r",
	[G_RLF.LogLevel.info] = "|cFFADD8E6{I}|r",
	[G_RLF.LogLevel.warn] = "|cFFFFD700{W}|r",
	[G_RLF.LogLevel.error] = "|cFFFF0000{E}|r",
}

-- typeColors populated dynamically from G_RLF.FeatureLogMetadata
-- (registered by each feature module via FeatureRegistry:Register)

local sourceStrings = {
	[addonName] = "(" .. addonName .. ")",
	[WOWEVENT] = "(WOW)",
}

---@class LogEntry
---@field timestamp string|osdate
---@field level string
---@field message string
---@field source string
---@field type string
---@field id string
---@field content string
---@field amount string|number
---@field new boolean

function Logger:FormatLogEntry(logEntry)
	local timeOnly = logEntry.timestamp:match("%d%d:%d%d:%d%d")
	local ts = "|cFF808080" .. timeOnly .. "|r"
	local level = levelColors[logEntry.level] or ""
	local src = sourceStrings[logEntry.source] or ""
	local meta = G_RLF.FeatureLogMetadata and G_RLF.FeatureLogMetadata[logEntry.type]
	local typ = meta and meta.color or ""
	local content = logEntry.content == "" and logEntry.message or logEntry.content .. " MSG: " .. logEntry.message
	local amount = logEntry.amount ~= "" and format(" (tot: %s)", logEntry.amount) or ""
	local update = logEntry.new == false and " ~UPDATE~" or ""
	local id = logEntry.id ~= "" and format(" [%s]", logEntry.id) or ""
	return format("[%s]%s%s%s: %s%s%s%s\n", ts, level, src, typ, content, amount, update, id)
end

-- ── UI-overridable methods ──────────────────────────────────────────────────
-- LoggerUI.lua overrides these when loaded.  The no-op stubs ensure the core
-- module works standalone (e.g. in tests).

--- Rebuild displayed log text.  Overridden by LoggerUI when the frame exists.
function Logger:UpdateContent() end

--- Create the logger frame.  Overridden by LoggerUI to build AceGUI widgets.
function Logger:InitializeFrame() end

-- ── Core API ─────────────────────────────────────────────────────────────────

---Add a log entry to the log table
---@param level string
---@param message string
---@param source? string
---@param type? string
---@param id? string
---@param content? string
---@param amount? string | number
---@param isNew? boolean
---@return nil
function Logger:addLogEntry(level, message, source, type, id, content, amount, isNew)
	if issecretvalue then
		if issecretvalue(message) then
			message = "<SECRET MESSAGE>"
		end
		if issecretvalue(id) then
			id = "<SECRET ID>"
		end
		if issecretvalue(content) then
			content = "<SECRET CONTENT>"
		end
		if issecretvalue(amount) then
			amount = "<SECRET AMOUNT>"
		end
	end
	local entry = {
		timestamp = date("%Y-%m-%d %H:%M:%S"),
		level = level,
		source = source or addonName,
		type = type or "General",
		id = id or "",
		content = content or "",
		amount = amount or "",
		new = isNew or true,
		message = message,
	}
	local logTable = self:getLogger()
	if not logTable then
		return
	end
	table.insert(logTable, entry)
	--[===[@non-alpha@
	while #logTable > 100 do
		table.remove(logTable, 1)
	end
	--@end-non-alpha@]===]
	if self.frame and self.frame:IsShown() then
		self:UpdateContent()
	end
end

---Process a table of logs
---@param logs table<LogEntry, number>
function Logger:ProcessLogs(logs)
	for log, _ in pairs(logs) do
		RunNextFrame(function()
			self:addLogEntry(unpack(log))
		end)
	end
end

function Logger:Trace(type, traceSize)
	local trace = ""
	traceSize = traceSize or 10
	local count = 0
	local logs = self:getLogger()
	for i = #logs, 1, -1 do
		if logs[i].type == type then
			count = count + 1
			trace = trace .. self:FormatLogEntry(logs[i])
		end
		if count >= traceSize then
			break
		end
	end
	return trace
end

function Logger:ClearLog()
	logger = {}
	if self.UpdateContent then
		self:UpdateContent()
	end
end

function Logger:Show()
	if self.frame and self.frame:IsShown() then
		self:Hide()
	else
		self:UpdateContent()
		RunNextFrame(function()
			if self.frame then
				self.frame:Show()
			end
		end)
	end
end

function Logger:Hide()
	if self.frame then
		self.frame:Hide()
	end
end

-- ── Lifecycle ────────────────────────────────────────────────────────────────

function Logger:OnInitialize()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_LEAVING_WORLD")
	self:RegisterBucketMessage("RLF_LOG", 0.5, "ProcessLogs")
	RunNextFrame(function()
		self:InitializeFrame()
	end)
end

function Logger:PLAYER_ENTERING_WORLD(_, isLogin, isReload)
	if isLogin then
		if not initialized then
			initialized = true
			G_RLF.db.global.logger = {}
		end
	else
		logger = G_RLF.db.global.logger or {}
	end
end

function Logger:PLAYER_LEAVING_WORLD()
	G_RLF.db.global.logger = logger
end

return Logger
