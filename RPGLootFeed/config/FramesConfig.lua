---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local MAX_FRAMES = 5

--- The pending name entered in the "New Frame Name" input before clicking Add Frame.
local pendingNewFrameName = ""

--- Notify AceConfig that the options table changed so the UI rebuilds.
local function notifyChange()
	LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
end

local frameAtlas = ""

if G_RLF:IsRetail() then
	frameAtlas = CreateAtlasMarkup("Crosshair_lootall_32", 24, 24)
else
	frameAtlas = CreateAtlasMarkup("Banker", 24, 24)
end

--- Recursively wrap every `set` callback in an options table so that changing
--- any option also refreshes the sample rows preview (when visible).
--- @param args table AceConfig args table
local function wrapSettersWithRefresh(args)
	for _, opt in pairs(args) do
		if type(opt) == "table" then
			if type(opt.set) == "function" then
				local origSet = opt.set
				opt.set = function(...)
					origSet(...)
					G_RLF.LootDisplay:RefreshSampleRowsIfShown()
				end
			end
			if opt.args then
				wrapSettersWithRefresh(opt.args)
			end
		end
	end
end

--- Build the full per-frame group (appearance sub-group,
--- loot feeds sub-group) for the given frame ID.
--- @param id integer
--- @return table
local function buildFrameGroup(id)
	local frameConfig = G_RLF.db.global.frames[id]
	local frameName = (frameConfig and frameConfig.name) or tostring(id)

	local stylingHandler = G_RLF.Styling.MakeHandler(id)

	local group = {
		type = "group",
		name = frameAtlas .. frameName,
		desc = string.format(G_RLF.L["FMT_FRAME_DESC"], frameName),
		order = 10 + id,
		childGroups = "tree",
		args = {
			appearance = {
				type = "group",
				name = G_RLF.L["Appearance"],
				desc = string.format(G_RLF.L["FMT_APPEARANCE_DESC"], frameName),
				order = 1,
				childGroups = "tree",
				args = {
					appearanceHeader = {
						type = "header",
						name = G_RLF.L["Appearance"],
						order = 0,
					},
					appearanceDesc = {
						type = "description",
						name = string.format(G_RLF.L["FMT_APPEARANCE_DESC"], frameName),
						order = 1,
						fontSize = "medium",
					},
					positioning = G_RLF.BuildPositioningArgs(id, 2),
					sizing = G_RLF.BuildSizingArgs(id, 3),
					styling = G_RLF.ConfigCommon.StylingBase.CreateStylingGroup(stylingHandler, 4),
					animations = G_RLF.BuildAnimationsArgs(id, 5),
				},
			},
			lootFeeds = {
				type = "group",
				name = G_RLF.L["Loot Feeds"],
				desc = string.format(G_RLF.L["FMT_LOOT_FEEDS_DESC"], frameName),
				order = 2,
				childGroups = "tree",
				args = {
					lootFeedsHeader = {
						type = "header",
						name = G_RLF.L["Loot Feeds"],
						order = 0,
					},
					lootFeedsDesc = {
						type = "description",
						name = string.format(G_RLF.L["FMT_LOOT_FEEDS_DESC"], frameName),
						order = 1,
						fontSize = "medium",
					},
					itemLoot = G_RLF.BuildItemLootArgs(id, 2),
					partyLoot = G_RLF.BuildPartyLootArgs(id, 3),
					currency = G_RLF.BuildCurrencyArgs(id, 4),
					money = G_RLF.BuildMoneyArgs(id, 5),
					experience = G_RLF.BuildExperienceArgs(id, 6),
					reputation = G_RLF.BuildReputationArgs(id, 7),
					profession = G_RLF.BuildProfessionArgs(id, 8),
					travelPoints = G_RLF.BuildTravelPointsArgs(id, 9),
					transmog = G_RLF.BuildTransmogArgs(id, 10),
					lootRolls = G_RLF.BuildLootRollsArgs(id, 11),
				},
			},
		},
	}
	wrapSettersWithRefresh(group.args)
	return group
end

--- Build the dynamic per-frame rename/delete controls for the Manage Frames group.
--- @return table args
local function buildManageFrameArgs()
	local args = {}
	local ids = {}
	for id in pairs(G_RLF.db.global.frames) do
		table.insert(ids, id)
	end
	table.sort(ids)

	for i, id in ipairs(ids) do
		local baseOrder = (i - 1) * 2 + 1
		args["rename_" .. id] = {
			type = "input",
			name = G_RLF.L["Frame Name"],
			desc = G_RLF.L["FrameNameDesc"],
			order = baseOrder,
			width = 1.8,
			get = function()
				local cfg = G_RLF.db.global.frames[id]
				return cfg and cfg.name or ""
			end,
			set = function(_, value)
				local cfg = G_RLF.db.global.frames[id]
				if cfg then
					cfg.name = value
					G_RLF.FramesConfig:RebuildArgs()
					notifyChange()
				end
			end,
		}
		if id ~= G_RLF.Frames.MAIN then
			args["delete_" .. id] = {
				type = "execute",
				name = function()
					local cfg = G_RLF.db.global.frames[id]
					local name = cfg and cfg.name or tostring(id)
					return string.format(G_RLF.L["FMT_DELETE_FRAME"], name)
				end,
				order = baseOrder + 1,
				width = 1.8,
				confirm = true,
				confirmText = G_RLF.L["DeleteFrameConfirm"],
				func = function()
					G_RLF.LootDisplay:DestroyFrame(id)
					G_RLF.FramesConfig:RebuildArgs()
					notifyChange()
				end,
			}
		else
			args["delete_" .. id] = {
				type = "execute",
				name = function()
					local cfg = G_RLF.db.global.frames[id]
					local name = cfg and cfg.name or tostring(id)
					return string.format(G_RLF.L["FMT_DELETE_FRAME"], name)
				end,
				order = baseOrder + 1,
				width = 1.8,
				disabled = true,
				func = function() end,
			}
		end
	end
	return args
end

---@class RLF_FramesConfig
local FramesConfig = {}

--- Rebuild per-frame args and frame management groups in the root options table.
--- Call this after any frame is created, deleted, or renamed, then call notifyChange().
function FramesConfig:RebuildArgs()
	local rootArgs = G_RLF.options.args

	-- Remove old per-frame entries and management groups before rebuilding.
	for key in pairs(rootArgs) do
		if key:match("^frame_") or key == "manageFrames" then
			rootArgs[key] = nil
		end
	end

	-- Per-frame groups — sorted by ID for stable ordering
	local ids = {}
	for id in pairs(G_RLF.db.global.frames) do
		table.insert(ids, id)
	end
	table.sort(ids)

	for _, id in ipairs(ids) do
		rootArgs["frame_" .. id] = buildFrameGroup(id)
	end

	-- Build manage frames args (rename/delete rows), then append "+ New Frame" controls
	local manageArgs = buildManageFrameArgs()

	local frameCount = 0
	for _ in pairs(G_RLF.db.global.frames) do
		frameCount = frameCount + 1
	end
	local nextBaseOrder = frameCount * 2 + 2

	manageArgs.newFrameHeader = {
		type = "header",
		name = G_RLF.L["+ New Frame"],
		order = nextBaseOrder,
	}
	manageArgs.newFrameGroupDesc = {
		type = "description",
		name = G_RLF.L["NewFrameGroupDesc"],
		order = nextBaseOrder + 0.5,
		fontSize = "medium",
	}
	manageArgs.newFrameName = {
		type = "input",
		name = G_RLF.L["New Frame Name"],
		desc = G_RLF.L["NewFrameNameDesc"],
		order = nextBaseOrder + 1,
		get = function()
			return pendingNewFrameName
		end,
		set = function(_, value)
			pendingNewFrameName = value
		end,
	}
	manageArgs.addFrame = {
		type = "execute",
		name = G_RLF.L["Add Frame"],
		desc = G_RLF.L["AddFrameDesc"],
		order = nextBaseOrder + 2,
		disabled = function()
			local count = 0
			for _ in pairs(G_RLF.db.global.frames) do
				count = count + 1
			end
			return count >= MAX_FRAMES
		end,
		func = function()
			local count = 0
			for _ in pairs(G_RLF.db.global.frames) do
				count = count + 1
			end
			if count >= MAX_FRAMES then
				G_RLF.Notifications:AddNotification(G_RLF.L["Frames"], G_RLF.L["MaxFramesReached"], "info")
				return
			end

			local newId = G_RLF.db.global.nextFrameId
			G_RLF.db.global.nextFrameId = newId + 1

			local name = (pendingNewFrameName ~= "") and pendingNewFrameName or (G_RLF.L["Frames"] .. " " .. newId)
			pendingNewFrameName = ""

			local mainCfg = G_RLF.db.global.frames[G_RLF.Frames.MAIN]
			local function deepCopy(t)
				if type(t) ~= "table" then
					return t
				end
				local out = {}
				for k, v in pairs(t) do
					out[k] = deepCopy(v)
				end
				return out
			end
			local newFeatures = deepCopy(mainCfg.features)
			for _, featureCfg in pairs(newFeatures) do
				featureCfg.enabled = false
			end

			G_RLF.db.global.frames[newId] = {
				name = name,
				positioning = deepCopy(mainCfg.positioning),
				sizing = deepCopy(mainCfg.sizing),
				styling = deepCopy(mainCfg.styling),
				animations = deepCopy(mainCfg.animations),
				features = newFeatures,
			}

			G_RLF.LootDisplay:InitFrame(newId)
			self:RebuildArgs()
			notifyChange()
		end,
	}

	-- "Manage Frames" group (order 98, last before About)
	rootArgs.manageFrames = {
		type = "group",
		name = G_RLF.L["Manage Frames"],
		desc = G_RLF.L["ManageFramesDesc"],
		order = 98,
		args = manageArgs,
	}
end

--- Called from Core:OnInitialize after the DB is ready.
function FramesConfig:OnInitialize()
	self:RebuildArgs()
end

G_RLF.FramesConfig = FramesConfig

return FramesConfig
