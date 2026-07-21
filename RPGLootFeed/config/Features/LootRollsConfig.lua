---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local LootRollsConfig = {}

function G_RLF.BuildLootRollsArgs(frameId, order)
	local function fc()
		return G_RLF.db.global.frames[frameId].features.lootRolls
	end
	return {
		type = "group",
		handler = LootRollsConfig,
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
		},
	}
end
