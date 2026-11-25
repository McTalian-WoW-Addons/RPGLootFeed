---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local OpenContainersConfig = {}

---@class RLF_ConfigOpenContainers
---@field enabled boolean
---@field minFreeSlots number
---@field skipBindOnPickup boolean
---@field allowList table<number, boolean>
---@field blockList table<number, boolean>
---@field seeded boolean
---@field itemNames table<number, string>
---@field itemNamesLocale string?
---@class RLF_DBGlobal
G_RLF.defaults.global = G_RLF.defaults.global or {}

--- Opt-in: disabled until the player turns it on.
G_RLF.defaults.global.openContainers = {
	enabled = false,
	minFreeSlots = 4,
	skipBindOnPickup = true,
	allowList = {},
	blockList = {},
	-- Lists are seeded from the base data once, on first load (not via AceDB defaults,
	-- which would resurrect entries the player removes).
	seeded = false,
	-- Item name cache (per locale) so the options page never shows bare IDs once seen.
	itemNames = {},
	itemNamesLocale = nil,
}

local function module()
	return G_RLF.RLF:GetModule(G_RLF.SupportModule.OpenContainers) --[[@as RLF_OpenContainers]]
end

local function cfg()
	return G_RLF.db.global.openContainers
end

--- Build the "uncheck to remove" entries for a list.
---@param list table<number, boolean>
---@return table<number, string>
local function listValues(list)
	local values = {}
	for itemId in pairs(list) do
		local name = module():GetItemName(itemId)
		values[itemId] = name and (name .. " (" .. itemId .. ")") or ("Item " .. itemId)
	end
	return values
end

--- Build the list-editing controls (add box + removable entries) for a list.
---@param listKey string "allowList" | "blockList"
---@param order number
---@param name string
---@param desc string
local function buildListGroup(listKey, order, name, desc)
	return {
		type = "group",
		inline = true,
		name = name,
		desc = desc,
		order = order,
		args = {
			add = {
				type = "input",
				name = G_RLF.L["Add Item"],
				desc = G_RLF.L["AddItemDesc"],
				width = "full",
				get = function()
					return ""
				end,
				set = function(_, value)
					local itemId = module().ParseItemId(value)
					if not itemId then
						G_RLF:Print(G_RLF.L["InvalidItemId"])
						return
					end
					module():MoveItem(itemId, listKey)
					G_RLF:NotifyChange(addonName)
				end,
				order = 1,
			},
			entries = {
				type = "multiselect",
				name = "",
				width = "full",
				values = function()
					return listValues(cfg()[listKey])
				end,
				get = function()
					return true
				end,
				set = function(_, itemId, value)
					if not value then
						module():RemoveItem(itemId)
						G_RLF:NotifyChange(addonName)
					end
				end,
				hidden = function()
					return next(cfg()[listKey]) == nil
				end,
				order = 2,
			},
		},
	}
end

G_RLF.options.args.openContainers = {
	type = "group",
	handler = OpenContainersConfig,
	name = G_RLF.L["Open Containers"],
	desc = G_RLF.L["OpenContainersDesc"],
	order = 3,
	args = {
		unsupported = {
			type = "description",
			name = G_RLF.L["OpenContainersUnsupported"],
			fontSize = "medium",
			hidden = function()
				return module():IsSupported()
			end,
			order = 0,
		},
		enabled = {
			type = "toggle",
			name = G_RLF.L["Enable Open Containers"],
			desc = G_RLF.L["EnableOpenContainersDesc"],
			width = "full",
			disabled = function()
				return not module():IsSupported()
			end,
			get = function()
				return cfg().enabled
			end,
			set = function(_, value)
				cfg().enabled = value
				module():Refresh()
			end,
			order = 1,
		},
		minFreeSlots = {
			type = "range",
			name = G_RLF.L["Minimum Free Bag Slots"],
			desc = G_RLF.L["MinimumFreeBagSlotsDesc"],
			min = 0,
			max = 20,
			step = 1,
			get = function()
				return cfg().minFreeSlots
			end,
			set = function(_, value)
				cfg().minFreeSlots = value
			end,
			order = 2,
		},
		skipBindOnPickup = {
			type = "toggle",
			name = G_RLF.L["Skip Bind on Pickup"],
			desc = G_RLF.L["SkipBindOnPickupDesc"],
			get = function()
				return cfg().skipBindOnPickup
			end,
			set = function(_, value)
				cfg().skipBindOnPickup = value
			end,
			order = 3,
		},
		allowList = buildListGroup("allowList", 4, G_RLF.L["Allow List"], G_RLF.L["AllowListDesc"]),
		blockList = buildListGroup("blockList", 5, G_RLF.L["Block List"], G_RLF.L["BlockListDesc"]),
	},
}

OpenContainersConfig.listValues = listValues
G_RLF.OpenContainersConfig = OpenContainersConfig

return OpenContainersConfig
