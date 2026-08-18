---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local ReputationConfig = {}

--- Build the AceConfig options group for Reputation on the given frame.
--- @param frameId integer
--- @param order number
--- @return table
function G_RLF.BuildReputationArgs(frameId, order)
	local function fc()
		return G_RLF.db.global.frames[frameId].features.reputation
	end
	return {
		type = "group",
		handler = ReputationConfig,
		name = G_RLF.L["Reputation Config"],
		order = order,
		args = {
			enableRep = {
				type = "toggle",
				name = G_RLF.L["Enable Reputation in Feed"],
				desc = G_RLF.L["EnableRepDesc"],
				width = "double",
				get = function()
					return fc().enabled
				end,
				set = function(_, value)
					fc().enabled = value
					G_RLF.DbAccessor:UpdateFeatureModuleState("reputation")
					G_RLF.LootDisplay:RefreshSampleRowsIfShown()
				end,
				order = 1,
			},
			repOptions = {
				type = "group",
				inline = true,
				name = G_RLF.L["Reputation Options"],
				disabled = function()
					return not fc().enabled
				end,
				order = 1.1,
				args = {
					backgroundOverride = G_RLF.ConfigCommon.CreateFeatureBackgroundOverrideGroup({
						frameId = frameId,
						featureKey = "reputation",
						order = 0.75,
						isFeatureEnabled = function()
							return fc().enabled
						end,
					}),
					showIcon = {
						type = "toggle",
						name = G_RLF.L["Show Reputation Icon"],
						desc = G_RLF.L["ShowRepIconDesc"],
						width = "double",
						disabled = function()
							return not fc().enabled or G_RLF.db.global.misc.hideAllIcons
						end,
						get = function()
							return fc().enableIcon
						end,
						set = function(_, value)
							fc().enableIcon = value
							G_RLF.LootDisplay:RefreshSampleRowsIfShown()
						end,
						order = 0.5,
					},
					repIconTexture = {
						type = "input",
						name = G_RLF.L["Reputation Icon Texture"],
						desc = G_RLF.L["RepIconTextureDesc"],
						width = "double",
						disabled = function()
							return not fc().enabled or G_RLF.db.global.misc.hideAllIcons or not fc().enableIcon
						end,
						get = function()
							return fc().repIconTexture
						end,
						set = function(_, value)
							fc().repIconTexture = value
							G_RLF.LootDisplay:RefreshSampleRowsIfShown()
						end,
						validate = "ValidateRepIcon",
						order = 0.6,
					},
					testRepIcon = {
						type = "description",
						name = function()
							return ReputationConfig:TestIcon(frameId, fc().repIconTexture)
						end,
						width = "normal",
						order = 0.61,
					},
					revertRepIconToDefault = {
						type = "execute",
						name = CreateAtlasMarkup("common-icon-undo", 16, 16),
						desc = G_RLF.L["RevertRepIconToDefaultDesc"],
						func = function()
							fc().repIconTexture =
								G_RLF.db.defaults.global.frames["**"].features.reputation.repIconTexture
							G_RLF.LootDisplay:RefreshSampleRowsIfShown()
						end,
						width = 0.35,
						order = 0.62,
					},
					defaultRepColor = {
						type = "color",
						hasAlpha = true,
						name = G_RLF.L["Default Rep Text Color"],
						desc = G_RLF.L["RepColorDesc"],
						get = function()
							return unpack(fc().defaultRepColor)
						end,
						set = function(_, r, g, b)
							fc().defaultRepColor = { r, g, b }
						end,
						order = 1,
					},
					secondaryTextAlpha = {
						type = "range",
						name = G_RLF.L["Secondary Text Alpha"],
						desc = G_RLF.L["SecondaryTextAlphaDesc"],
						min = 0,
						max = 1,
						step = 0.1,
						get = function()
							return fc().secondaryTextAlpha
						end,
						set = function(_, value)
							fc().secondaryTextAlpha = value
						end,
						order = 2,
					},
					repLevelOptions = {
						type = "group",
						inline = true,
						name = G_RLF.L["Reputation Level Options"],
						order = 3,
						args = {
							enableRepLevel = {
								type = "toggle",
								name = G_RLF.L["Enable Reputation Level"],
								desc = G_RLF.L["EnableRepLevelDesc"],
								width = "double",
								get = function()
									return fc().enableRepLevel
								end,
								set = function(_, value)
									fc().enableRepLevel = value
								end,
								order = 1,
							},
							repLevelColor = {
								type = "color",
								name = G_RLF.L["Reputation Level Color"],
								desc = G_RLF.L["RepLevelColorDesc"],
								disabled = function()
									return not fc().enabled or not fc().enableRepLevel
								end,
								width = "double",
								hasAlpha = true,
								get = function()
									return unpack(fc().repLevelColor)
								end,
								set = function(_, r, g, b, a)
									fc().repLevelColor = { r, g, b, a }
								end,
								order = 2,
							},
							repLevelWrapChar = {
								type = "select",
								name = G_RLF.L["Reputation Level Wrap Character"],
								desc = G_RLF.L["RepLevelWrapCharDesc"],
								disabled = function()
									return not fc().enabled or not fc().enableRepLevel
								end,
								values = G_RLF.WrapCharOptions,
								get = function()
									return fc().repLevelTextWrapChar
								end,
								set = function(_, value)
									fc().repLevelTextWrapChar = value
								end,
								order = 3,
							},
						},
					},
				},
			},
		},
	}
end

--- Render a preview of the resolved reputation icon (override, or the flavor default when unset).
--- The reputation icon is applied via SetItemButtonTexture (FileDataID or texture path), never an
--- Atlas, so this cannot reuse ItemConfig:TestIcon's CreateAtlasMarkup preview.
function ReputationConfig:TestIcon(frameId, icon)
	local styleDb = G_RLF.DbAccessor:Styling(frameId)
	local secondaryFontSize = styleDb.secondaryFontSize
	local resolvedIcon = (icon ~= nil and icon ~= "") and icon or G_RLF.DefaultIcons.REPUTATION
	local markup = string.format("|T%s:%d:%d|t", resolvedIcon, secondaryFontSize, secondaryFontSize)
	return string.format(G_RLF.L["Chosen Icon"], markup)
end

--- Accept an empty value (meaning "use the flavor default"), a numeric FileDataID, or a texture
--- file path. Reject anything else, most notably Atlas names, since SetItemButtonTexture cannot
--- render an Atlas.
function ReputationConfig:ValidateRepIcon(_, value)
	if value == nil or value == "" then
		return true
	end

	if tonumber(value) then
		return true
	end

	if type(value) == "string" and (value:find("/", 1, true) or value:find("\\", 1, true)) then
		return true
	end

	return string.format(G_RLF.L["InvalidRepIconTexture"], value)
end
