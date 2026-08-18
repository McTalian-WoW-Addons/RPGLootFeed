---@type string
local addonName = select(1, ...)
---@class G_RLF
local G_RLF = select(2, ...)

---@class RLF_RepUtils
local RepUtils = {}

---@enum RepType
local RepType = {
	Unknown = 0x0000,
	-- Unique Classifications of Factions
	BaseFaction = 0x0001,
	MajorFaction = 0x0002,
	DelveCompanion = 0x0004,
	Friendship = 0x0008,
	Guild = 0x0010,
	DelversJourney = 0x0020,
	-- Additional flags, can be combined with any of the above classifications
	Paragon = 0x1000,
	Warband = 0x2000,
}

--- Use C_MajorFactions.GetMajorFactionIDs(LE_EXPANSION_WAR_WITHIN) to get the major faction IDs
--- Use C_MajorFactions.GetMajorFactionData to get the textureKit (the key)
--- Search Wago Files for "interface/icons/ui_majorfactions_interface/icons/ui_majorfactions_" to find the icons
--- https://wago.tools/files?search=interface%2Ficons%2Fui_majorfaction
--- The format of the string could change from expansion to expansion (it was "ui_majorfaction_" in DF)
local majorFactionTextureKitIconMap = {
	["centaur"] = 4687627, -- Maruuk Centaur
	["expedition"] = 4687628, -- Dragonscale Expedition
	["tuskarr"] = 4687629, -- Iskaara Tuskarr
	["valdrakken"] = 4687630, -- Valdrakken Accord
	["niffen"] = 5140835, -- Loamm Niffen
	["dream"] = 5244643, -- Dream Wardens
	["storm"] = 5891369, -- Council of Dornogal
	["candle"] = 5891367, -- The Assembly of the Deeps
	["flame"] = 5891368, -- Hallowfall Arathi
	["web"] = 5891370, -- Severed Threads
	["rocket"] = 6252691, -- The Cartels of Undermine
	["stars"] = 6351805, -- Gallagio Loyalty Rewards Club
	["nightfall"] = 6694197, -- Flame's Radiance
	["karesh"] = 6937965, -- The K'aresh Trust
	["origin"] = 7505698, -- Amani Tribe
	["sky"] = 7505702, -- The Singularity
	["root"] = 7505704, -- Hara'ti
	["light"] = 7505700, -- Silvermoon Court
	["delves"] = 6025441, -- Delves
	["delve"] = 6025441, -- Delves
	["prey"] = 7493985, -- Prey
	["zuljarra"] = 7903180, -- Zul'jarra's Forces
}

--- A bit of a grab bag
--- Search wago files for "interface/icons/ui_notoriety" and get the Azh-Kahet factions
--- Search wago files for "interface/icons reputationcurrencies" and you get the Goblin factions
local factionIdIconMap = {
	[2601] = 5862764, -- The Weaver
	[2605] = 5862762, -- The General
	[2607] = 5862763, -- The Vizier
	[2669] = 6439629, -- Darkfuse Solutions
	[2671] = 6439631, -- Venture Company
	[2673] = 6439627, -- Bilgewater Cartel
	[2675] = 6439628, -- Blackwater Cartel
	[2677] = 6439630, -- Steamwheedle Cartel
}

function RepUtils.IsBaseFaction(repType)
	return bit.band(repType, RepType.BaseFaction) ~= 0
end

function RepUtils.IsMajorFaction(repType)
	return bit.band(repType, RepType.MajorFaction) ~= 0
end

function RepUtils.IsDelveCompanion(repType)
	return bit.band(repType, RepType.DelveCompanion) ~= 0
end

function RepUtils.IsFriendship(repType)
	return bit.band(repType, RepType.Friendship) ~= 0
end

function RepUtils.IsGuild(repType)
	return bit.band(repType, RepType.Guild) ~= 0
end

function RepUtils.IsParagon(repType)
	return bit.band(repType, RepType.Paragon) ~= 0
end

function RepUtils.IsWarband(repType)
	return bit.band(repType, RepType.Warband) ~= 0
end

local guildFactionId = 1168 -- Guild

function RepUtils.DetermineRepType(factionId)
	local repType = RepType.Unknown
	if factionId == guildFactionId then
		repType = RepType.Guild
	elseif C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(factionId) then
		repType = RepType.MajorFaction
	elseif C_DelvesUI and C_DelvesUI.GetFactionForCompanion and factionId == C_DelvesUI.GetFactionForCompanion() then
		repType = RepType.DelveCompanion
	else
		local friendInfo = C_GossipInfo.GetFriendshipReputation(factionId)
		if friendInfo and friendInfo.friendshipFactionID and friendInfo.friendshipFactionID > 0 then
			repType = RepType.Friendship
		else
			repType = RepType.BaseFaction
		end
	end

	if C_Reputation.IsFactionParagonForCurrentPlayer and C_Reputation.IsFactionParagonForCurrentPlayer(factionId) then
		repType = bit.bor(repType, RepType.Paragon)
	end

	if C_Reputation.IsAccountWideReputation and C_Reputation.IsAccountWideReputation(factionId) then
		repType = bit.bor(repType, RepType.Warband)
	end

	return repType
end

---@class UnifiedFactionData
---@field delta number|nil
---@field factionId number
---@field name string
---@field icon integer
---@field quality integer
---@field standing number
---@field rank integer|string|nil
---@field rankStandingMin integer?
---@field rankStandingMax integer?
---@field contextInfo string?
---@field color colorRGBA?
---@field paragonIconAtlas string?   Atlas name for the paragon reward bag icon (no |A| markup)
---@field paragonIconSize  number?   Pixel size for the paragon reward bag icon

local rewardIcon = "ParagonReputation_Bag"

---@diagnostic disable: inject-field

---@return UnifiedFactionData|nil
function RepUtils.GetFactionData(factionId, repType)
	if repType == RepType.Unknown then
		return nil
	end

	---@type UnifiedFactionData
	local factionData = {
		delta = nil,
		factionId = factionId,
		name = G_RLF.L["Unknown Faction"],
		contextInfo = nil,
		standing = 0,
		icon = G_RLF.DefaultIcons.REPUTATION,
		quality = G_RLF.ItemQualEnum.Rare,
	}

	if RepUtils.IsWarband(repType) then
		factionData.color = ACCOUNT_WIDE_FONT_COLOR
	end

	if factionIdIconMap[factionId] then
		factionData.icon = factionIdIconMap[factionId]
	end

	if RepUtils.IsMajorFaction(repType) then
		local renownInfo = C_MajorFactions.GetMajorFactionRenownInfo(factionId)
		local mfd = C_MajorFactions.GetMajorFactionData(factionId)
		if mfd and mfd.factionFontColor then
			factionData.color = mfd.factionFontColor.color
		end
		if mfd and mfd.name then
			factionData.name = mfd.name
		end
		if mfd and mfd.textureKit then
			local iconId = majorFactionTextureKitIconMap[mfd.textureKit:lower()]
			if iconId then
				factionData.icon = iconId
			end
		end
		factionData.quality = G_RLF.ItemQualEnum.Heirloom
		factionData.rank = renownInfo and renownInfo.renownLevel or 0

		if renownInfo and renownInfo.renownReputationEarned then
			factionData.standing = renownInfo.renownReputationEarned

			if renownInfo.renownLevelThreshold then
				factionData.rankStandingMin = 0
				factionData.rankStandingMax = renownInfo.renownLevelThreshold
				factionData.contextInfo =
					string.format("%d / %d", renownInfo.renownReputationEarned, renownInfo.renownLevelThreshold)
			end
		end
	elseif RepUtils.IsDelveCompanion(repType) then
		local fd = C_Reputation.GetFactionDataByID(factionId)
		if not fd then
			return nil
		end
		factionData.name = fd.name
		if fd.factionID == 2640 then
			factionData.icon = 5315246 -- interface/icons/inv_cape_special_explorer_b_03
		elseif fd.factionID == 2744 then
			factionData.icon = 236270 -- interface/icons/ability_rogue_deadlybrew.blp
		end
		factionData.color = FACTION_GREEN_COLOR -- Delve companions are always green, maybe one day I'll get fancy

		local ranks = C_GossipInfo.GetFriendshipReputationRanks(factionId)
		local info = C_GossipInfo.GetFriendshipReputation(factionId)
		if not ranks or not info then
			return nil
		end

		factionData.rank = ranks.currentLevel
		factionData.standing = info.standing

		-- Once we hit max level, the thresholds are no longer valid
		if factionData.rank < ranks.maxLevel then
			local currentXp = info.standing - info.reactionThreshold
			if info.nextThreshold and info.nextThreshold > 1 then
				local nextLevelAt = info.nextThreshold - info.reactionThreshold
				factionData.rankStandingMin = info.reactionThreshold
				factionData.rankStandingMax = info.nextThreshold
				factionData.contextInfo = math.floor((currentXp / nextLevelAt) * 10000) / 100 .. "%"
			end
		end
	else
		local fd
		if RepUtils.IsGuild(repType) then
			fd = C_Reputation.GetGuildFactionData()
		elseif G_RLF:IsRetail() then
			fd = C_Reputation.GetFactionDataByID(factionId)
		-- So far up through MoP Classic, there is no C_Reputation.GetFactionDataByID
		else
			fd = G_RLF.ClassicToRetail:ConvertFactionInfoByID(factionId)
		end
		if not fd then
			return nil
		end
		factionData.name = fd.name
		if fd.reaction then
			factionData.color = FACTION_BAR_COLORS[fd.reaction]
		end
		if RepUtils.IsFriendship(repType) then
			local friendInfo = C_GossipInfo.GetFriendshipReputation(factionId)
			local ranks = C_GossipInfo.GetFriendshipReputationRanks(factionId)
			if friendInfo then
				if friendInfo.reaction then
					factionData.rank = friendInfo.reaction
				end
				if friendInfo.texture and friendInfo.texture > 0 then
					factionData.icon = friendInfo.texture
				end
				-- Friendship factions report Neutral via fd.reaction; default to Friendly (green)
				factionData.color = FACTION_BAR_COLORS[5]
				local standing = friendInfo.standing - friendInfo.reactionThreshold
				factionData.rankStandingMin = friendInfo.reactionThreshold
				factionData.rankStandingMax = friendInfo.nextThreshold
				factionData.standing = standing
				factionData.contextInfo = tostring(standing)
				if
					friendInfo.nextThreshold
					and friendInfo.nextThreshold > 0
					and friendInfo.reactionThreshold
					and friendInfo.reactionThreshold > 0
				then
					local repDenominator = friendInfo.nextThreshold - friendInfo.reactionThreshold
					if repDenominator > standing then
						factionData.contextInfo = factionData.contextInfo .. " / " .. repDenominator
					end
				end
			end
		else
			local gender = UnitSex("player")
			---@diagnostic disable-next-line: missing-parameter -- GetText only has one required parameter
			factionData.rank = GetText("FACTION_STANDING_LABEL" .. fd.reaction, gender)
			local standing = fd.currentStanding - fd.currentReactionThreshold
			factionData.standing = standing
			factionData.rankStandingMin = fd.currentReactionThreshold
			factionData.rankStandingMax = fd.nextReactionThreshold
			factionData.contextInfo = tostring(standing)
			local denominator = fd.nextReactionThreshold - fd.currentReactionThreshold
			if factionData.contextInfo and denominator and denominator > 1 then
				factionData.contextInfo = factionData.contextInfo .. " / " .. denominator
			end
		end
	end

	if RepUtils.IsParagon(repType) then
		factionData.color = factionData.color or FACTION_GREEN_COLOR
		local currentValue, threshold, rewardQuestId, hasRewardPending, tooLowLevelForParagon =
			C_Reputation.GetFactionParagonInfo(factionId)
		if currentValue and threshold and threshold > 0 then
			factionData.contextInfo = string.format("%d / %d", currentValue % threshold, threshold)
		else
			factionData.contextInfo = ""
		end
		if hasRewardPending then
			local stylingDb = G_RLF.DbAccessor:Styling(G_RLF.Frames.MAIN)
			local sizeCoeff = G_RLF.AtlasIconCoefficients[rewardIcon] or 1
			local atlasIconSize = stylingDb.fontSize * sizeCoeff
			-- Store as data fields instead of injecting |A| markup into contextInfo.
			-- Inline atlas markup does not receive Translation animation offsets and
			-- causes visual jank; the row layer renders the icon via SecondaryCoinDisplay.
			factionData.paragonIconAtlas = rewardIcon
			factionData.paragonIconSize = atlasIconSize
		end
	end

	return factionData
end

--- Get the cached details for the warband faction
--- @param factionId number
--- @return CachedFactionDetails|nil
local function getWarbandCacheDetails(factionId)
	return G_RLF.db.global.warbandFactions.cachedFactionDetailsById[factionId]
end

--- Update the cached details for the faction
--- @param factionId number
--- @param details CachedFactionDetails
local function updateWarbandCacheDetails(factionId, details)
	G_RLF.db.global.warbandFactions.cachedFactionDetailsById[factionId] = details
end

--- Get the count of cached warband factions
--- @return number
local function getWarbandCacheCount()
	return G_RLF.db.global.warbandFactions.count
end

--- Update the count of cached warband factions
--- @param count number
local function updateWarbandCacheCount(count)
	G_RLF.db.global.warbandFactions.count = count
end

--- Get the cached details for the character-specific faction
--- @param factionId number
--- @return CachedFactionDetails|nil
local function getCharCacheDetails(factionId)
	return G_RLF.db.char.repFactions.cachedFactionDetailsById[factionId]
end

--- Update the cached details for the character-specific faction
--- @param factionId number
--- @param details CachedFactionDetails
local function updateCharCacheDetails(factionId, details)
	G_RLF.db.char.repFactions.cachedFactionDetailsById[factionId] = details
end

--- Get the count of cached character-specific factions
--- @return number
local function getCharCacheCount()
	return G_RLF.db.char.repFactions.count
end

--- Update the count of cached character-specific factions
--- @param count number
local function updateCharCacheCount(count)
	G_RLF.db.char.repFactions.count = count
end

local function getDeltaAndUpdateCache(factionId, newStanding, fd, repType, cacheFns)
	local getFn = cacheFns.getFn
	local updateFn = cacheFns.updateFn
	local getCountFn = cacheFns.getCountFn
	local updateCountFn = cacheFns.updateCountFn

	---@type CachedFactionDetails|nil
	local cachedDetails = getFn(factionId)
	if not cachedDetails then
		cachedDetails = {
			repType = repType,
			rank = fd.rank,
			standing = newStanding,
			rankStandingMin = fd.rankStandingMin,
			rankStandingMax = fd.rankStandingMax,
		}
		updateFn(factionId, cachedDetails)
		updateCountFn(getCountFn() + 1)
		G_RLF:LogDebug(
			"New cache entry for factionId "
				.. tostring(factionId)
				.. " standing="
				.. tostring(newStanding)
				.. " rank="
				.. tostring(fd.rank),
			addonName,
			"Reputation.RepUtils"
		)
		return newStanding
	end

	local delta
	local rankChanged = fd.rank ~= cachedDetails.rank
	if newStanding < cachedDetails.standing and rankChanged then
		-- Standing decreased while rank changed — level-up where standing resets
		-- relative to the new rank. Compute overflow delta:
		-- (rank capacity - old progress) + new standing in new rank
		local rankStandingMax = cachedDetails.rankStandingMax or 2500
		local rankStandingMin = cachedDetails.rankStandingMin or 0
		delta = (rankStandingMax - rankStandingMin) - cachedDetails.standing + newStanding
		G_RLF:LogDebug(
			"Level-up detected for factionId "
				.. tostring(factionId)
				.. " oldRank="
				.. tostring(cachedDetails.rank)
				.. " newRank="
				.. tostring(fd.rank)
				.. " oldStanding="
				.. tostring(cachedDetails.standing)
				.. " newStanding="
				.. tostring(newStanding)
				.. " rankRange="
				.. tostring(rankStandingMin)
				.. "-"
				.. tostring(rankStandingMax)
				.. " delta="
				.. tostring(delta),
			addonName,
			"Reputation.RepUtils"
		)
	else
		delta = newStanding - cachedDetails.standing
	end
	cachedDetails.standing = newStanding
	cachedDetails.rank = fd.rank
	cachedDetails.rankStandingMin = fd.rankStandingMin
	cachedDetails.rankStandingMax = fd.rankStandingMax
	updateFn(factionId, cachedDetails)
	return delta
end

--- Get the delta to display and update the warband cache for the faction
--- @param factionId number
--- @param newStanding number
--- @param fd table faction data with rank, rankStandingMin, rankStandingMax
--- @param repType RepType
--- @return number|nil
local function getDeltaAndUpdateWarbandCache(factionId, newStanding, fd, repType)
	local cacheFns = {
		getFn = getWarbandCacheDetails,
		updateFn = updateWarbandCacheDetails,
		getCountFn = getWarbandCacheCount,
		updateCountFn = updateWarbandCacheCount,
	}

	return getDeltaAndUpdateCache(factionId, newStanding, fd, repType, cacheFns)
end

--- Get the delta to display and update the character-specific cache for the faction
--- @param factionId number
--- @param newStanding number
--- @param fd table faction data with rank, rankStandingMin, rankStandingMax
--- @param repType RepType
--- @return number|nil
local function getDeltaAndUpdateCharCache(factionId, newStanding, fd, repType)
	local cacheFns = {
		getFn = getCharCacheDetails,
		updateFn = updateCharCacheDetails,
		getCountFn = getCharCacheCount,
		updateCountFn = updateCharCacheCount,
	}

	return getDeltaAndUpdateCache(factionId, newStanding, fd, repType, cacheFns)
end

local function isWarbandFactionPresent(factionId)
	local cacheDetails = getWarbandCacheDetails(factionId)
	return cacheDetails ~= nil
end

local function isCharFactionPresent(factionId)
	local cacheDetails = getCharCacheDetails(factionId)
	return cacheDetails ~= nil
end

function RepUtils.IsFactionCached(factionId, repType)
	if RepUtils.IsWarband(repType) then
		return isWarbandFactionPresent(factionId)
	else
		return isCharFactionPresent(factionId)
	end
end

function RepUtils.InsertNewCacheEntry(factionId, cacheDetails, repType)
	if RepUtils.IsFactionCached(factionId, repType) then
		return
	end

	if RepUtils.IsWarband(repType) then
		updateWarbandCacheDetails(factionId, cacheDetails)
		updateWarbandCacheCount(getWarbandCacheCount() + 1)
	else
		updateCharCacheDetails(factionId, cacheDetails)
		updateCharCacheCount(getCharCacheCount() + 1)
	end
end

--- Get the delta to display and update the appropriate cache for the faction
--- @param factionId number
--- @param newStanding number
--- @param fd table faction data with rank, rankStandingMin, rankStandingMax
--- @param repType RepType
--- @return number|nil
function RepUtils.GetDeltaAndUpdateCache(factionId, newStanding, fd, repType)
	if C_Reputation.IsAccountWideReputation and C_Reputation.IsAccountWideReputation(factionId) then
		return getDeltaAndUpdateWarbandCache(factionId, newStanding, fd, repType)
	else
		return getDeltaAndUpdateCharCache(factionId, newStanding, fd, repType)
	end
end

function RepUtils.GetCachedFactionDetails(factionId, repType)
	if RepUtils.IsWarband(repType) then
		return getWarbandCacheDetails(factionId)
	else
		return getCharCacheDetails(factionId)
	end
end

--- Get the count of cached factions, optionally filtered by AccountWide vs Char repType
--- @param repType RepType|nil
--- @return number
function RepUtils.GetCount(repType)
	if not repType then
		return getCharCacheCount() + getWarbandCacheCount()
	end

	if RepUtils.IsWarband(repType) then
		return getWarbandCacheCount()
	else
		return getCharCacheCount()
	end
end

function RepUtils.UpdateCacheEntry(factionId, cachedDetails, repType)
	if not RepUtils.IsFactionCached(factionId, repType) then
		RepUtils.InsertNewCacheEntry(factionId, cachedDetails, repType)
		return
	end

	if RepUtils.IsWarband(repType) then
		updateWarbandCacheDetails(factionId, cachedDetails)
	else
		updateCharCacheDetails(factionId, cachedDetails)
	end
end

RepUtils.RepType = RepType
G_RLF.RepUtils = RepUtils
