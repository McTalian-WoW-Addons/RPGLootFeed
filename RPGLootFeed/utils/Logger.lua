---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_Logger: RLF_Module, AceBucket-3.0, AceEvent-3.0
local Logger = G_RLF.RLF:NewModule(G_RLF.SupportModule.Logger, "AceBucket-3.0", "AceEvent-3.0")

local gui = LibStub("AceGUI-3.0") --[[@as AceGUI-3.0]]

local updateContent
local logger = nil
local initialized = false
local function getLogger()
	if not initialized then
		initialized = true
		G_RLF.db.global.logger = {}
	end
	if logger == nil then
		logger = G_RLF.db.global.logger or {}
	end

	return logger
end
local WOWEVENT = G_RLF.LogEventSource.WOWEVENT

local eventSource = {
	[G_RLF.LogEventSource.ADDON] = true,
	[WOWEVENT] = true,
}
local function OnEventSourceChange(_, _, k, v)
	eventSource[k] = v
	updateContent()
end

local debug = G_RLF.LogLevel.debug
local info = G_RLF.LogLevel.info
local warn = G_RLF.LogLevel.warn
local error = G_RLF.LogLevel.error
local eventLevel = {
	[debug] = true,
	[info] = true,
	[warn] = true,
	[error] = true,
}
local function OnEventLevelChange(_, _, k, v)
	eventLevel[k] = v
	updateContent()
end

local ItemLoot = G_RLF.FeatureModule.ItemLoot
local Currency = G_RLF.FeatureModule.Currency
local Money = G_RLF.FeatureModule.Money
local Reputation = G_RLF.FeatureModule.Reputation
local Experience = G_RLF.FeatureModule.Experience
local Profession = G_RLF.FeatureModule.Profession
local PartyLoot = G_RLF.FeatureModule.PartyLoot
local TravelPoints = G_RLF.FeatureModule.TravelPoints
local Transmog = G_RLF.FeatureModule.Transmog
local LootRolls = G_RLF.FeatureModule.LootRolls
local eventType = {
	[ItemLoot] = true,
	[Currency] = true,
	[Money] = true,
	[Reputation] = true,
	[Experience] = true,
	[Profession] = true,
	[PartyLoot] = true,
	[TravelPoints] = true,
	[Transmog] = true,
	[LootRolls] = true,
}
local function OnEventTypeChange(_, _, k, v)
	eventType[k] = v
	updateContent()
end

local function OnClearLog()
	logger = {}
	updateContent()
end

function Logger:ClearLog()
	OnClearLog()
end

local createLoggerFrames
local createFilterBar
local createContentBox
local createFilterBarComponents

function Logger:createLoggerFrames()
	if not self.frame then
		---@class LoggerFrame: AceGUIFrame
		---@field contentBox LoggerContentBox
		---@field filterBar LoggerFilterBox
		self.frame = gui:Create("Frame") --[[@as AceGUIFrame]]
		self.frame:Hide()
		self.frame:SetLayout("Flow")
		self.frame:SetTitle("Loot Log")
		self.frame:EnableResize(false)
	end

	RunNextFrame(function()
		self:createFilterBar()
		self:createContentBox()
	end)
end

---@private
function Logger:createContentBox()
	local f = self.frame
	if not f.contentBox then
		---@class LoggerContentBox: AceGUIMultiLineEditBox
		f.contentBox = gui:Create("MultiLineEditBox") --[[@as AceGUIMultiLineEditBox]]
		f:AddChild(f.contentBox)
		f.contentBox:SetLabel("Logs")
		f.contentBox:DisableButton(true)
		f.contentBox:SetFullWidth(true)
		f.contentBox:SetNumLines(23)
	end
end

---@private
function Logger:createFilterBar()
	local f = self.frame
	if not f.filterBar then
		---@class LoggerFilterBox: AceGUISimpleGroup
		---@field logSources AceGUIDropdown
		---@field logLevels AceGUIDropdown
		---@field logTypes AceGUIDropdown
		---@field clearButton AceGUIButton
		f.filterBar = gui:Create("SimpleGroup") --[[@as AceGUISimpleGroup]]
		f:AddChild(f.filterBar)
		f.filterBar:SetFullWidth(true)
		f.filterBar:SetLayout("Flow")
	end
	RunNextFrame(function()
		self:createFilterBarComponents()
	end)
end

function Logger:createFilterBarComponents()
	local fB = self.frame.filterBar
	if not fB.logSources then
		fB.logSources = gui:Create("Dropdown") --[[@as AceGUIDropdown]]
		fB:AddChild(fB.logSources)
		RunNextFrame(function()
			fB.logSources:SetLabel("Log Sources")
			fB.logSources:SetMultiselect(true)
			fB.logSources:SetList({
				[addonName] = addonName,
				[WOWEVENT] = WOWEVENT,
			}, {
				addonName,
				WOWEVENT,
			})
			fB.logSources:SetCallback("OnValueChanged", OnEventSourceChange)
			for k, v in pairs(eventSource) do
				---@diagnostic disable-next-line: param-type-mismatch
				fB.logSources:SetItemValue(k, v)
			end
		end)
	end

	if not fB.logLevels then
		fB.logLevels = gui:Create("Dropdown") --[[@as AceGUIDropdown]]
		fB:AddChild(fB.logLevels)
		RunNextFrame(function()
			fB.logLevels:SetLabel("Log Levels")
			fB.logLevels:SetMultiselect(true)
			fB.logLevels:SetList({
				[debug] = debug,
				[info] = info,
				[warn] = warn,
				[error] = error,
			})
			fB.logLevels:SetCallback("OnValueChanged", OnEventLevelChange)
			for k, v in pairs(eventLevel) do
				---@diagnostic disable-next-line: param-type-mismatch
				fB.logLevels:SetItemValue(k, v)
			end
		end)
	end

	if not fB.logTypes then
		fB.logTypes = gui:Create("Dropdown") --[[@as AceGUIDropdown]]
		fB:AddChild(fB.logTypes)
		RunNextFrame(function()
			fB.logTypes:SetLabel("Log Types")
			fB.logTypes:SetMultiselect(true)
			fB.logTypes:SetList({
				[ItemLoot] = ItemLoot,
				[Currency] = Currency,
				[Money] = Money,
				[Reputation] = Reputation,
				[Experience] = Experience,
				[Profession] = Profession,
				[PartyLoot] = PartyLoot,
				[TravelPoints] = TravelPoints,
				[Transmog] = Transmog,
				[LootRolls] = LootRolls,
			})
			fB.logTypes:SetCallback("OnValueChanged", OnEventTypeChange)
			for k, v in pairs(eventType) do
				---@diagnostic disable-next-line: param-type-mismatch
				fB.logTypes:SetItemValue(k, v)
			end
		end)
	end

	if not fB.clearButton then
		fB.clearButton = gui:Create("Button") --[[@as AceGUIButton]]
		fB:AddChild(fB.clearButton)
		RunNextFrame(function()
			fB.clearButton:SetText("Clear Current Log")
			fB.clearButton:SetCallback("OnClick", OnClearLog)
		end)
	end

	RunNextFrame(function()
		Logger.frame:DoLayout()
	end)
end

--@alpha@
createLoggerFrames = G_RLF:ProfileFunction(createLoggerFrames, "createLoggerFrames")
createContentBox = G_RLF:ProfileFunction(createContentBox, "createContentBox")
createFilterBar = G_RLF:ProfileFunction(createFilterBar, "createFilterBar")
createFilterBarComponents = G_RLF:ProfileFunction(createFilterBarComponents, "createFilterBarComponents")
--@end-alpha@

function Logger:InitializeFrame()
	if not self.frame then
		RunNextFrame(function()
			self:createLoggerFrames()
		end)
	end
end

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

local function getLevel(logEntry)
	local level = logEntry.level
	local levelColors = {
		[debug] = "|cFF808080{D}|r", -- Gray for DEBUG
		[info] = "|cFFADD8E6{I}|r", -- Light blue for INFO (ADD8E6 in hex)
		[warn] = "|cFFFFD700{W}|r", -- Gold for WARN
		[error] = "|cFFFF0000{E}|r", -- Red for ERROR
	}

	-- Return the formatted level or an empty string if the level is not recognized
	return levelColors[level] or ""
end

local function getType(logEntry)
	local type = logEntry.type
	local typeColors = {
		[ItemLoot] = "|cFF00FF00[ITEM]|r", -- Green for item loot
		[Currency] = "|cFFFFD700[CURR]|r", -- Gold for currency
		[Money] = "|cFFC0C0C0[GOLD]|r", -- Silver/Gray for money
		[Reputation] = "|cFF1E90FF[REPU]|r", -- Blue for reputation
		[Experience] = "|cFF9932CC[EXPR]|r", -- Purple for experience
		[Profession] = "|cFF8B4513[PROF]|r", -- Brown for profession
		[PartyLoot] = "|cFF00FFFF[PRTY]|r", -- Cyan for party loot
		[TravelPoints] = "|cFF8A2BE2[TRVL]|r", -- BlueViolet for travel points
		[Transmog] = "|cFFFF69B4[TMOG]|r", -- Pink for transmog
		[LootRolls] = "|cFFFF8C00[ROLL]|r", -- Orange for loot rolls
	}

	-- Return an empty string for "General" and the corresponding value for others
	return typeColors[type] or ""
end

local function getSource(logEntry)
	local source = logEntry.source
	local sourceStrings = {
		[addonName] = "(" .. addonName .. ")",
		[WOWEVENT] = "(WOW)",
	}
	return sourceStrings[source] or ""
end

local function getTimestamp(logEntry)
	-- Extract the time portion from the timestamp using pattern matching
	local timeOnly = logEntry.timestamp:match("%d%d:%d%d:%d%d")

	-- Return the formatted timestamp with dark gray color
	return "|cFF808080" .. timeOnly .. "|r"
end

local function getContent(logEntry)
	if logEntry.content == "" then
		return logEntry.message
	end
	return logEntry.content .. " MSG: " .. logEntry.message
end

local function getAmount(logEntry)
	if logEntry.amount == "" then
		return ""
	end
	return format(" (tot: %s)", logEntry.amount)
end

local function isUpdatedRow(logEntry)
	if logEntry.new == false then
		return " ~UPDATE~"
	end
	return ""
end

local function getId(logEntry)
	if logEntry.id == "" then
		return ""
	end
	return format(" [%s]", logEntry.id)
end

function Logger:FormatLogEntry(logEntry)
	return format(
		"[%s]%s%s%s: %s%s%s%s\n",
		getTimestamp(logEntry),
		getLevel(logEntry),
		getSource(logEntry),
		getType(logEntry),
		getContent(logEntry),
		getAmount(logEntry),
		isUpdatedRow(logEntry),
		getId(logEntry)
	)
end

updateContent = function()
	local text = ""

	local function addText(logEntry)
		text = Logger:FormatLogEntry(logEntry) .. text
	end

	for i, logEntry in ipairs(getLogger()) do
		if eventSource[logEntry.source] then
			if eventLevel[logEntry.level] then
				if eventType[logEntry.type] or logEntry.type == "General" then
					addText(logEntry)
				end
			end
		end
	end
	RunNextFrame(function()
		Logger.frame.contentBox:SetText(text)
	end)
end

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
	---@type LogEntry
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
	local logTable = getLogger()
	if not logTable then
		-- error("Log Table not ready")
		return
	end
	table.insert(logTable, entry)
	--[===[@non-alpha@
	while #logTable > 100 do
		table.remove(logTable, 1)
	end
	--@end-non-alpha@]===]
	if self.frame and self.frame:IsShown() then
		updateContent()
	end
end

---Process a table of logs
---@param logs table<LogEntry, number>
---@return nil
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
	local logs = getLogger()
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

function Logger:Show()
	if self.frame:IsShown() then
		self:Hide()
	else
		updateContent()
		RunNextFrame(function()
			self.frame:Show()
		end)
	end
end

function Logger:Hide()
	self.frame:Hide()
end

return Logger
