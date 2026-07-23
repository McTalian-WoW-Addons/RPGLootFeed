---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- Build the AceConfig options group for Loot Rolls on the given frame.
--- Called from the config system by function name.
---@param frameId integer
---@param order number
---@return table
function G_RLF.LootRolls:BuildConfigArgs(frameId, order)
	local function fc()
		return G_RLF.db.global.frames[frameId].features.lootRolls
	end
	return {
		type = "group",
		name = G_RLF.L["Loot Rolls Config"],
		order = order,
		args = {
			enableLootRolls = {
				type = "toggle",
				name = G_RLF.L["Enable Loot Rolls in Feed"],
				desc = G_RLF.L["EnableLootRollsDesc"],
				width = "double",
				get = function()
					return fc().enabled
				end,
				set = function(_, value)
					fc().enabled = value
					G_RLF.DbAccessor:UpdateFeatureModuleState("lootRolls")
					G_RLF.LootDisplay:RefreshSampleRowsIfShown()
				end,
				order = 1,
			},
			rollButtonSize = {
				type = "range",
				name = G_RLF.L["Roll Button Size"],
				desc = G_RLF.L["RollButtonSizeDesc"],
				min = 12,
				max = 32,
				step = 1,
				get = function()
					return fc().buttonSize
				end,
				set = function(_, value)
					fc().buttonSize = value
					G_RLF.LootDisplay:RefreshSampleRowsIfShown()
				end,
				order = 2,
			},
		},
	}
end

return {}
