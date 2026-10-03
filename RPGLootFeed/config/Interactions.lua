---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local function getInteractionToggles()
	local L = G_RLF.L
	return {
		{ key = "tooltips", name = L["Show Tooltips"], desc = L["ShowTooltipsDesc"] },
		{ key = "itemClicks", name = L["Item Clicks"], desc = L["ItemClicksDesc"] },
		{ key = "rightClickDismiss", name = L["Right Click To Dismiss"], desc = L["RightClickToDismissDesc"] },
		{ key = "hoverHighlight", name = L["Hover Highlight"], desc = L["HoverHighlightDesc"] },
		{ key = "pinOnHover", name = L["Pin Rows On Hover"], desc = L["PinRowsOnHoverDesc"] },
		{ key = "rollButtons", name = L["Roll Buttons"], desc = L["RollButtonsDesc"] },
	}
end

--- Build the AceConfig interactions group args for the given frame ID.
--- Returns the full type="group" table ready to embed in a per-frame group.
--- @param id integer frame ID
--- @param order number position order within the parent group
--- @return table
function G_RLF.BuildInteractionsArgs(id, order)
	local args = {
		interactionsDesc = {
			type = "description",
			name = G_RLF.L["FrameInteractionsDesc"],
			order = 0,
			fontSize = "medium",
		},
	}
	for i, toggle in ipairs(getInteractionToggles()) do
		args[toggle.key] = {
			type = "toggle",
			name = toggle.name,
			desc = toggle.desc,
			width = "full",
			order = i,
			disabled = function()
				return G_RLF.db.global.interactions.disableAllInteraction
			end,
			get = function()
				return G_RLF.DbAccessor:Interactions(id)[toggle.key]
			end,
			set = function(_, value)
				G_RLF.DbAccessor:Interactions(id)[toggle.key] = value
				G_RLF.LootDisplay:UpdateInteractions(id)
			end,
		}
	end
	return {
		type = "group",
		name = G_RLF.L["Interactions"],
		desc = G_RLF.L["InteractionsDesc"],
		order = order,
		args = args,
	}
end
