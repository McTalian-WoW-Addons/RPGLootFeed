---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- LootDisplay module is already registered by LootDisplay.lua which is included first.
---@class LootDisplay: RLF_Module, AceBucket-3.0, AceEvent-3.0, AceHook-3.0
local LootDisplay = G_RLF.LootDisplay

local SAMPLE_ITEM_LINK = "|cff0070dd|Hitem:14344::::::::60:::::|h[Large Brilliant Shard]|h|r"
local SAMPLE_TRANSMOG_LINK = "|cff9d9d9d|Htransmogappearance:285269|h[Sample Transmog]|h|r"

--- Build and show one representative sample row per enabled feature type.
--- Iterates _featureSampleRows registered in FeatureRegistry so features
--- self-register their sample rows via co-located Sample.lua files.
--- Called from LootDisplay:ShowSampleRows() — the caller already guards that the
--- loot frame exists, so no lootFrames check is needed here.
--- @param frame G_RLF.Frames
function LootDisplay:CreateSampleRows(frame)
	-- Look up the frame's subscription config so we only show samples for
	-- features routed to this specific frame.
	local frameConfig = G_RLF.db.global.frames and G_RLF.db.global.frames[frame]
	local features = frameConfig and frameConfig.features or {}

	-- Delegate to each registered sample row factory from the FeatureRegistry.
	if G_RLF._featureSampleRows then
		for _, sampleFn in pairs(G_RLF._featureSampleRows) do
			sampleFn(frame, features)
		end
	end
end

return {}
