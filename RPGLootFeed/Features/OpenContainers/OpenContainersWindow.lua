---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- ── OpenContainers item list editor ─────────────────────────
-- A small AceGUI window with the Allow List on the left and the Block List on
-- the right. Tick items, then use the buttons between the lists to move them
-- or remove them. All list logic lives in OpenContainers; this file is UI only.

---@class RLF_OpenContainersWindow
local Window = {}

local WINDOW_WIDTH, WINDOW_HEIGHT = 900, 660
local BODY_HEIGHT = 440
local LIST_HEIGHT = 400

local frame
local scrolls = {}
-- selected[listKey][itemId] = true
local selected = { allowList = {}, blockList = {} }

local function module()
	return G_RLF.RLF:GetModule(G_RLF.SupportModule.OpenContainers) --[[@as RLF_OpenContainers]]
end

local function selectedIds(listKey)
	local ids = {}
	for itemId in pairs(selected[listKey]) do
		ids[#ids + 1] = itemId
	end
	return ids
end

local function afterChange()
	selected = { allowList = {}, blockList = {} }
	Window:Refresh()
	G_RLF:NotifyChange(addonName)
end

StaticPopupDialogs["RLF_OPEN_CONTAINERS_RESTORE_DEFAULTS"] = {
	text = G_RLF.L["RestoreDefaultsConfirm"],
	button1 = G_RLF.L["Restore Defaults"],
	button2 = CANCEL,
	OnAccept = function()
		module():Seed(true)
		afterChange()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local function fillList(listKey)
	local scroll = scrolls[listKey]
	if not scroll then
		return
	end
	local AceGUI = LibStub("AceGUI-3.0")
	scroll:PauseLayout()
	scroll:ReleaseChildren()
	for _, row in ipairs(module():GetSortedList(listKey)) do
		local check = AceGUI:Create("CheckBox")
		check:SetLabel(row.label)
		check:SetFullWidth(true)
		check:SetValue(selected[listKey][row.itemId] == true)
		check:SetCallback("OnValueChanged", function(_, _, value)
			selected[listKey][row.itemId] = value and true or nil
		end)
		scroll:AddChild(check)
	end
	scroll:ResumeLayout()
	scroll:DoLayout()
end

--- Rebuild both lists if the window is open.
function Window:Refresh()
	if not frame then
		return
	end
	fillList("allowList")
	fillList("blockList")
end

function Window:IsOpen()
	return frame ~= nil
end

function Window:Close()
	if frame then
		-- Hiding fires OnClose, which releases the widget.
		frame.frame:Hide()
	end
end

---@param AceGUI table
---@param listKey string
---@param heading string
---@param relWidth number
local function buildColumn(AceGUI, listKey, heading, relWidth)
	local column = AceGUI:Create("SimpleGroup")
	column:SetLayout("List")
	column:SetRelativeWidth(relWidth)
	column:SetHeight(BODY_HEIGHT)

	local title = AceGUI:Create("Heading")
	title:SetText(heading)
	title:SetFullWidth(true)
	column:AddChild(title)

	local holder = AceGUI:Create("SimpleGroup")
	holder:SetLayout("Fill")
	holder:SetFullWidth(true)
	holder:SetHeight(LIST_HEIGHT)
	column:AddChild(holder)

	local scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("List")
	holder:AddChild(scroll)
	scrolls[listKey] = scroll

	return column
end

local function addButton(AceGUI, parent, text, onClick)
	local button = AceGUI:Create("Button")
	button:SetText(text)
	button:SetFullWidth(true)
	button:SetCallback("OnClick", onClick)
	parent:AddChild(button)
	return button
end

function Window:Open()
	if frame then
		self:Refresh()
		return
	end
	local AceGUI = LibStub("AceGUI-3.0")
	local L = G_RLF.L

	frame = AceGUI:Create("Frame")
	frame:SetTitle(L["Item Lists"])
	frame:SetStatusText(L["ItemListsHelp"])
	frame:SetLayout("Flow")
	frame:SetWidth(WINDOW_WIDTH)
	frame:SetHeight(WINDOW_HEIGHT)
	frame:SetCallback("OnClose", function(widget)
		AceGUI:Release(widget)
		frame = nil
		scrolls = {}
		selected = { allowList = {}, blockList = {} }
	end)

	local addBox = AceGUI:Create("EditBox")
	addBox:SetLabel(L["Add Item"])
	addBox:SetRelativeWidth(0.6)
	addBox:SetCallback("OnEnterPressed", function(widget, _, text)
		local itemId = module().ParseItemId(text)
		if not itemId then
			G_RLF:Print(L["InvalidItemId"])
			return
		end
		module():MoveItem(itemId, "allowList")
		widget:SetText("")
		afterChange()
	end)
	frame:AddChild(addBox)

	local restore = AceGUI:Create("Button")
	restore:SetText(L["Restore Defaults"])
	restore:SetRelativeWidth(0.4)
	restore:SetCallback("OnClick", function()
		StaticPopup_Show("RLF_OPEN_CONTAINERS_RESTORE_DEFAULTS")
	end)
	frame:AddChild(restore)

	local body = AceGUI:Create("SimpleGroup")
	body:SetLayout("Flow")
	body:SetFullWidth(true)
	body:SetHeight(BODY_HEIGHT)
	frame:AddChild(body)

	body:AddChild(buildColumn(AceGUI, "allowList", L["Allow List"], 0.42))

	local middle = AceGUI:Create("SimpleGroup")
	middle:SetLayout("List")
	middle:SetRelativeWidth(0.16)
	local spacer = AceGUI:Create("Label")
	spacer:SetText("\n\n\n\n\n\n")
	spacer:SetFullWidth(true)
	middle:AddChild(spacer)
	addButton(AceGUI, middle, ">>", function()
		module():MoveItems(selectedIds("allowList"), "blockList")
		afterChange()
	end)
	addButton(AceGUI, middle, "<<", function()
		module():MoveItems(selectedIds("blockList"), "allowList")
		afterChange()
	end)
	addButton(AceGUI, middle, L["Remove"], function()
		module():RemoveItems(selectedIds("allowList"))
		module():RemoveItems(selectedIds("blockList"))
		afterChange()
	end)
	body:AddChild(middle)

	body:AddChild(buildColumn(AceGUI, "blockList", L["Block List"], 0.42))

	self:Refresh()
end

G_RLF.OpenContainersWindow = Window

return Window
