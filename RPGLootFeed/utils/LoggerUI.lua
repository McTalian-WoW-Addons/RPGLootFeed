---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- Loaded after Logger.lua — overrides InitializeFrame and UpdateContent.

local gui = LibStub("AceGUI-3.0") --[[@as AceGUI-3.0]]
local Logger = G_RLF.RLF:GetModule(G_RLF.SupportModule.Logger) --[[@as RLF_Logger]]

-- ── Filter state ──────────────────────────────────────────────────────────────

local WOWEVENT = G_RLF.LogEventSource.WOWEVENT

local eventSource = {
	[G_RLF.LogEventSource.ADDON] = true,
	[WOWEVENT] = true,
}
local eventLevel = {
	[G_RLF.LogLevel.debug] = true,
	[G_RLF.LogLevel.info] = true,
	[G_RLF.LogLevel.warn] = true,
	[G_RLF.LogLevel.error] = true,
}
local eventType = {}
for _, key in ipairs({
	"ItemLoot",
	"Currency",
	"Money",
	"Reputation",
	"Experience",
	"Professions",
	"PartyLoot",
	"TravelPoints",
	"Transmog",
	"LootRolls",
}) do
	local v = G_RLF.FeatureModule[key]
	if v then
		eventType[v] = true
	end
end

-- ── Filter callbacks ─────────────────────────────────────────────────────────

local function OnEventSourceChange(_, _, k, v)
	eventSource[k] = v
	Logger:UpdateContent()
end

local function OnEventLevelChange(_, _, k, v)
	eventLevel[k] = v
	Logger:UpdateContent()
end

local function OnEventTypeChange(_, _, k, v)
	eventType[k] = v
	Logger:UpdateContent()
end

local function OnClearLog()
	Logger:ClearLog()
	Logger:UpdateContent()
end

-- ── Content rebuild ──────────────────────────────────────────────────────────

function Logger:UpdateContent()
	local text = ""
	local function addText(logEntry)
		text = self:FormatLogEntry(logEntry) .. text
	end
	for i, logEntry in ipairs(self:getLogger() or {}) do
		if eventSource[logEntry.source] then
			if eventLevel[logEntry.level] then
				if eventType[logEntry.type] or logEntry.type == "General" then
					addText(logEntry)
				end
			end
		end
	end
	RunNextFrame(function()
		if self.frame and self.frame.contentBox then
			self.frame.contentBox:SetText(text)
		end
	end)
end

-- ── Frame construction ───────────────────────────────────────────────────────

local createFilterBarComponents
local createLoggerFrames

function createFilterBarComponents()
	local fB = Logger.frame.filterBar
	if not fB then
		return
	end

	if not fB.logSources then
		fB.logSources = gui:Create("Dropdown")
		fB:AddChild(fB.logSources)
		RunNextFrame(function()
			fB.logSources:SetLabel("Log Sources")
			fB.logSources:SetMultiselect(true)
			fB.logSources:SetList({
				[addonName] = addonName,
				[WOWEVENT] = WOWEVENT,
			}, { addonName, WOWEVENT })
			fB.logSources:SetCallback("OnValueChanged", OnEventSourceChange)
			for k, v in pairs(eventSource) do
				---@diagnostic disable-next-line: param-type-mismatch
				fB.logSources:SetItemValue(k, v)
			end
		end)
	end

	if not fB.logLevels then
		fB.logLevels = gui:Create("Dropdown")
		fB:AddChild(fB.logLevels)
		RunNextFrame(function()
			fB.logLevels:SetLabel("Log Levels")
			fB.logLevels:SetMultiselect(true)
			fB.logLevels:SetList({
				[G_RLF.LogLevel.debug] = G_RLF.LogLevel.debug,
				[G_RLF.LogLevel.info] = G_RLF.LogLevel.info,
				[G_RLF.LogLevel.warn] = G_RLF.LogLevel.warn,
				[G_RLF.LogLevel.error] = G_RLF.LogLevel.error,
			})
			fB.logLevels:SetCallback("OnValueChanged", OnEventLevelChange)
			for k, v in pairs(eventLevel) do
				---@diagnostic disable-next-line: param-type-mismatch
				fB.logLevels:SetItemValue(k, v)
			end
		end)
	end

	if not fB.logTypes then
		fB.logTypes = gui:Create("Dropdown")
		fB:AddChild(fB.logTypes)
		RunNextFrame(function()
			fB.logTypes:SetLabel("Log Types")
			fB.logTypes:SetMultiselect(true)
			local list = {}
			for key in pairs(eventType) do
				list[key] = key
			end
			fB.logTypes:SetList(list)
			fB.logTypes:SetCallback("OnValueChanged", OnEventTypeChange)
			for k, v in pairs(eventType) do
				---@diagnostic disable-next-line: param-type-mismatch
				fB.logTypes:SetItemValue(k, v)
			end
		end)
	end

	if not fB.clearButton then
		fB.clearButton = gui:Create("Button")
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

function createLoggerFrames()
	if not Logger.frame then
		Logger.frame = gui:Create("Frame")
		Logger.frame:Hide()
		Logger.frame:SetLayout("Flow")
		Logger.frame:SetTitle("Loot Log")
		Logger.frame:EnableResize(false)
	end

	RunNextFrame(function()
		local f = Logger.frame
		if not f.filterBar then
			f.filterBar = gui:Create("SimpleGroup")
			f:AddChild(f.filterBar)
			f.filterBar:SetFullWidth(true)
			f.filterBar:SetLayout("Flow")
		end
		RunNextFrame(function()
			createFilterBarComponents()
		end)

		if not f.contentBox then
			f.contentBox = gui:Create("MultiLineEditBox")
			f:AddChild(f.contentBox)
			f.contentBox:SetLabel("Logs")
			f.contentBox:DisableButton(true)
			f.contentBox:SetFullWidth(true)
			f.contentBox:SetNumLines(23)
		end
	end)
end

--@alpha@
createLoggerFrames = G_RLF:ProfileFunction(createLoggerFrames, "createLoggerFrames")
createFilterBarComponents = G_RLF:ProfileFunction(createFilterBarComponents, "createFilterBarComponents")
--@end-alpha@

--- Override the core stub — builds the AceGUI frame on first call.
function Logger:InitializeFrame()
	if not self.frame then
		RunNextFrame(function()
			createLoggerFrames()
		end)
	end
end

return {}
