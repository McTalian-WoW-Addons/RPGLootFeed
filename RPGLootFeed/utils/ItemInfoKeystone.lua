---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_KeystoneInfo
---@field itemId number
---@field dungeonId number
---@field dungeonName string
---@field level number
---@field affixId1? number
---@field affixId2? number
---@field affixId3? number
---@field affixId4? number
---@field link string

--- Parse keystone data from an item link and stamp keystoneInfo on the item.
--- Called from ItemInfo:new() when the item is detected as a keystone.
function G_RLF.ItemInfo:populateKeystoneInfo()
	self.keystoneInfo = nil
	if not self.itemLink then
		return
	end

	if not (C_Item.IsItemKeystoneByID and C_Item.IsItemKeystoneByID(self.itemId)) then
		return
	end

	local itemLink = self.itemLink
	-- "|cffa335ee|Hitem:180653::::::::60:250::::6:17:381:18:13:19:9:20:7:21:124:22:121:::::|h[Mythic Keystone]|h|r"
	-- Strip off everything before and including |Hitem:
	local start, stop = string.find(itemLink, "|Hitem:")
	if not start then
		return
	end
	local fieldString = string.sub(itemLink, stop + 1)
	start, stop = string.find(fieldString, "|h")
	fieldString = string.sub(fieldString, 1, start - 1)
	-- 180653::::::::60:250::::6:17:381:18:13:19:9:20:7:21:124:22:121:::::
	local fields = {}
	for field in string.gmatch(fieldString, "(.-)" .. ":") do
		table.insert(fields, field)
	end

	local keystoneInfo = {}
	local itemId = tonumber(fields[1])
	if not itemId then
		return
	end
	keystoneInfo.itemId = itemId
	local numModifiers = tonumber(fields[14]) or 0
	for i = 1, numModifiers do
		local modifierValue = tonumber(fields[14 + i * 2])
		if modifierValue then
			if i == 1 then
				keystoneInfo.dungeonId = modifierValue
				keystoneInfo.dungeonName = C_ChallengeMode.GetMapUIInfo(keystoneInfo.dungeonId)
			elseif i == 2 then
				keystoneInfo.level = modifierValue
			elseif i == 3 then
				keystoneInfo.affixId1 = modifierValue
			elseif i == 4 then
				keystoneInfo.affixId2 = modifierValue
			elseif i == 5 then
				keystoneInfo.affixId3 = modifierValue
			elseif i == 6 then
				keystoneInfo.affixId4 = modifierValue
			end
		end
	end
	self.keystoneInfo = keystoneInfo
	local linkPrefix = string.format(
		"|cnIQ4:|Hkeystone:%d:%d:%d:%d:%d:%d:%d|h[",
		self.keystoneInfo.itemId,
		self.keystoneInfo.dungeonId,
		self.keystoneInfo.level,
		self.keystoneInfo.affixId1 or 0,
		self.keystoneInfo.affixId2 or 0,
		self.keystoneInfo.affixId3 or 0,
		self.keystoneInfo.affixId4 or 0
	)
	local linkText =
		string.format(CHALLENGE_MODE_KEYSTONE_NAME, keystoneInfo.dungeonName .. " (" .. keystoneInfo.level .. ")")
	local linkPostFix = "]|h|r"
	self.keystoneInfo.link = linkPrefix .. linkText .. linkPostFix

	self.itemLink = self.keystoneInfo.link
	self.itemName = linkText
	self.itemLevel = keystoneInfo.level
end

return {}
