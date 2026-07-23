---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local SAMPLE_ITEM_LINK = "|cff0070dd|Hitem:14344::::::::60:::::|h[Large Brilliant Shard]|h|r"

--- Build sample rows for the LootRolls feature in the options preview.
---@param frame integer Frame ID
---@param features table Per-frame feature config
function G_RLF.LootRolls:GetSampleRows(frame, features)
	if not features.lootRolls or not features.lootRolls.enabled then
		return
	end
	if not self:IsEnabled() then
		return
	end
	local lootDb = G_RLF.DbAccessor:Feature(frame, "lootRolls") or {}
	local sampleIcon = nil
	if lootDb.enableIcon ~= false and not G_RLF.db.global.misc.hideAllIcons then
		local ok, icon = pcall(C_Item.GetItemIconByID, 14344)
		sampleIcon = ok and icon or nil
	end

	G_RLF.LootElementBase
		:fromPayload({
			key = "sample_loot_roll",
			type = G_RLF.FeatureModule.LootRolls,
			isLink = true,
			icon = sampleIcon,
			quality = G_RLF.ItemQualEnum.Rare,
			quantity = 1,
			textFn = function(_, truncatedLink)
				return truncatedLink or SAMPLE_ITEM_LINK
			end,
			rollID = nil,
			rollDuration = 60,
			canNeed = true,
			canGreed = true,
			canTransmog = false,
			reasonNeed = nil,
			reasonGreed = nil,
			isSampleRow = true,
			sampleTooltipText = G_RLF.L["Loot Rolls Config"],
			moduleRef = self,
			mockDropInfo = {
				lootListID = 1,
				itemHyperlink = SAMPLE_ITEM_LINK,
				rollInfos = {
					{
						playerName = "PlayerA",
						playerClass = "WARRIOR",
						state = 0,
						roll = 87,
						isWinner = false,
						isSelf = false,
					},
					{
						playerName = "PlayerB",
						playerClass = "MAGE",
						state = 3,
						roll = nil,
						isWinner = false,
						isSelf = false,
					},
					{
						playerName = "PlayerC",
						playerClass = "PRIEST",
						state = 5,
						roll = nil,
						isWinner = false,
						isSelf = false,
					},
					{
						playerName = "You",
						playerClass = "HUNTER",
						state = 4,
						roll = nil,
						isWinner = false,
						isSelf = true,
					},
				},
				currentLeader = { playerName = "PlayerA", playerClass = "WARRIOR", roll = 87 },
				winner = nil,
				allPassed = false,
				startTime = 0,
				duration = 60,
			},
		})
		:Show()
end

return {}
