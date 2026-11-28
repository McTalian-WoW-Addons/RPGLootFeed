---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

-- ── OpenContainers ──────────────────────────────────────────
-- Opt-in support module that opens clams, sacks, crates and other keyless
-- containers sitting in the player's bags. It produces no feed entries; the
-- opened loot arrives through the normal loot pipeline.
--
-- Base item data is ported from Open Sesame (MIT, Gogo1951); see ATTRIBUTIONS.
-- Settings live in db.global.openContainers (see OpenContainersConfig.lua).
-- There are no hidden rules: the allow and block lists decide everything.

---@class RLF_OpenContainers: RLF_Module, AceEvent-3.0
local OpenContainers = G_RLF.FeatureBase:new(G_RLF.SupportModule.OpenContainers, {
	di = {
		api = "WoWAPI.OpenContainers",
	},
	logging = true,
}, "AceEvent-3.0")

-- ── Tunables ────────────────────────────────────────────────
local SCAN_DEBOUNCE = 0.5
local OPEN_TICK_INTERVAL = 0.25
local OPEN_ANSWER_TIMEOUT = 1 -- seconds an open waits for its loot before it counts as refused
local OPEN_REFUSAL_LIMIT = 3 -- unanswered opens in a row before an item is set aside until relog/level-up
local NAME_REQUEST_BATCH = 25
local NAME_REQUEST_INTERVAL = 0.2
local NAME_REFRESH_DELAY = 0.5

-- Events that can clear whatever blocked an open, so nothing has to poll: while the player
-- is blocked (a window open, casting, stealthed, bags nearly full, in combat) the module is
-- idle until one of these fires. Registered only where the client has them.
local RESCAN_EVENTS = {
	"BAG_UPDATE_DELAYED", -- bag space freed, or new containers arrived
	"PLAYER_REGEN_ENABLED", -- combat ended
	"PLAYER_ENTERING_WORLD",
}
local UNBLOCK_EVENTS = {
	"UPDATE_STEALTH",
	"PLAYER_INTERACTION_MANAGER_FRAME_HIDE", -- any NPC window closed (modern clients)
	"MERCHANT_CLOSED",
	"MAIL_CLOSED",
	"BANKFRAME_CLOSED",
	"TRADE_CLOSED",
	"AUCTION_HOUSE_CLOSED",
	"GOSSIP_CLOSED",
	"QUEST_FINISHED",
}

-- ── State ───────────────────────────────────────────────────
local queue = {}
local scanPending = false
local tickLive = false
local pendingItem = nil
local openSeq = 0
local castListener
local refusedCounts = {}
local refusedItems = {}

-- ── Config ──────────────────────────────────────────────────

---@return RLF_ConfigOpenContainers
local function config()
	return G_RLF.db.global.openContainers
end

-- ── Flavor data ─────────────────────────────────────────────

--- The base item data set for this client, or nil where the feature is not available.
--- WoW Forever only for now: it is the only client this has been run on. The Classic
--- Era ("era") and TBC ("tbc") data tables stay in OpenContainersData, so turning one
--- on later is a matter of mapping it here and testing it there. Retail and Mists have
--- no data: until UseContainerItem is verified from addon code there, the module stays
--- off on those clients.
---@return string?
function OpenContainers:GetFlavorKey()
	if G_RLF:IsForever() then
		return "forever"
	end
	return nil
end

---@return RLF_OpenContainersFlavorData?
function OpenContainers:GetFlavorData()
	local data = G_RLF.OpenContainersData
	local key = self:GetFlavorKey()
	return data and key and data[key] or nil
end

--- Add the IDs a data release introduced to the player's lists. Run by the
--- migration for that release (see the recipe in OpenContainersData.lua). Players who have never
--- been seeded are skipped: Seed() reads the current data. Items already on
--- either list are left alone, so the player's choices are never overridden.
---@param version number The migration version that introduced the additions
---@return number added How many IDs were added
function OpenContainers:ApplyAdditions(version)
	local cfg = config()
	local key = self:GetFlavorKey()
	local data = G_RLF.OpenContainersData
	local additions = cfg.seeded and key and data and data.additions[version] and data.additions[version][key]
	if not additions then
		return 0
	end
	local added = 0
	for _, listKey in ipairs({ "allowList", "blockList" }) do
		for _, itemId in ipairs(additions[listKey] or {}) do
			if not cfg.allowList[itemId] and not cfg.blockList[itemId] then
				cfg[listKey][itemId] = true
				added = added + 1
			end
		end
	end
	return added
end

function OpenContainers:IsSupported()
	return self:GetFlavorData() ~= nil
end

-- ── Item rules ──────────────────────────────────────────────

--- Extract an item ID from a number, numeric string or item link.
---@param input any
---@return number?
function OpenContainers.ParseItemId(input)
	if type(input) == "number" then
		return input > 0 and input or nil
	end
	if type(input) ~= "string" then
		return nil
	end
	local fromLink = input:match("item:(%d+)")
	local id = tonumber(fromLink or input:match("^%s*(%d+)%s*$"))
	return id and id > 0 and id or nil
end

--- Should this item ID be opened, ignoring bag state?
--- The allow and block lists are the only rules: the base data only seeds them
--- (see Seed). An item on neither list is never opened, and block wins.
---@param itemId number
---@return boolean
function OpenContainers:IsEligible(itemId)
	if refusedItems[itemId] then
		return false
	end
	local cfg = config()
	if cfg.blockList[itemId] then
		return false
	end
	return cfg.allowList[itemId] == true
end

--- Fill the allow and block lists from the base data for this client.
--- Keyless containers go on the allow list; the ones the original addon
--- recommended leaving sealed (raid gem sacks, quest/recipe containers, ...)
--- go on the block list. Locked boxes (openable == false) are not seeded.
---@param reset? boolean Replace the current lists instead of only seeding once
---@return boolean seeded
function OpenContainers:Seed(reset)
	local data = self:GetFlavorData()
	local cfg = config()
	if not data or (cfg.seeded and not reset) then
		return false
	end
	cfg.allowList, cfg.blockList = {}, {}
	for itemId, opensWithoutUnlock in pairs(data.openable) do
		if opensWithoutUnlock == true then
			if data.defaultBlocked[itemId] then
				cfg.blockList[itemId] = true
			else
				cfg.allowList[itemId] = true
			end
		end
	end
	cfg.seeded = true
	self:LogInfo("Seeded allow/block lists")
	if reset then
		self:RequestItemNames()
	end
	return true
end

--- Move an item to the other list (or onto a list if it is on neither).
---@param itemId number
---@param toList "allowList"|"blockList"
function OpenContainers:MoveItem(itemId, toList)
	local cfg = config()
	local from = toList == "allowList" and "blockList" or "allowList"
	cfg[from][itemId] = nil
	cfg[toList][itemId] = true
	if not self:GetItemName(itemId) then
		self.api.RequestItemData(itemId)
	end
end

--- Remove an item from both lists.
---@param itemId number
function OpenContainers:RemoveItem(itemId)
	local cfg = config()
	cfg.allowList[itemId] = nil
	cfg.blockList[itemId] = nil
end

--- Move several items to a list at once.
---@param itemIds number[]
---@param toList "allowList"|"blockList"
function OpenContainers:MoveItems(itemIds, toList)
	for _, itemId in ipairs(itemIds) do
		self:MoveItem(itemId, toList)
	end
end

--- Remove several items from both lists at once.
---@param itemIds number[]
function OpenContainers:RemoveItems(itemIds)
	for _, itemId in ipairs(itemIds) do
		self:RemoveItem(itemId)
	end
end

--- The items on a list as display rows, sorted by name (unnamed items last, by ID).
---@param listKey "allowList"|"blockList"
---@return { itemId: number, name: string?, label: string }[]
function OpenContainers:GetSortedList(listKey)
	local rows = {}
	for itemId in pairs(config()[listKey]) do
		local name = self:GetItemName(itemId)
		rows[#rows + 1] = {
			itemId = itemId,
			name = name,
			label = name and (name .. " (" .. itemId .. ")") or ("Item " .. itemId),
		}
	end
	table.sort(rows, function(a, b)
		if (a.name ~= nil) ~= (b.name ~= nil) then
			return a.name ~= nil
		end
		if a.name and a.name:lower() ~= b.name:lower() then
			return a.name:lower() < b.name:lower()
		end
		return a.itemId < b.itemId
	end)
	return rows
end

-- ── Item names ──────────────────────────────────────────────
-- Names are cached in the saved config (per locale) so the options page can
-- always show them. Anything missing is requested from the server in small
-- batches and filled in as GET_ITEM_INFO_RECEIVED arrives.

local namesRefreshPending = false

--- A cached item name, filling the cache from the client when it knows the item.
---@param itemId number
---@return string?
function OpenContainers:GetItemName(itemId)
	local cfg = config()
	local name = cfg.itemNames[itemId]
	if name then
		return name
	end
	name = self.api.GetItemName(itemId)
	if name then
		cfg.itemNames[itemId] = name
	end
	return name
end

--- Wipe the name cache if it was built under a different client locale.
function OpenContainers:ValidateNameCache()
	local cfg = config()
	local locale = self.api.GetLocale()
	if cfg.itemNamesLocale ~= locale then
		cfg.itemNames = {}
		cfg.itemNamesLocale = locale
	end
end

local function onNamesChanged()
	if namesRefreshPending then
		return
	end
	namesRefreshPending = true
	OpenContainers.api.After(NAME_REFRESH_DELAY, function()
		namesRefreshPending = false
		if G_RLF.NotifyChange then
			G_RLF:NotifyChange(addonName)
		end
		if G_RLF.OpenContainersWindow then
			G_RLF.OpenContainersWindow:Refresh()
		end
	end)
end

--- Request data for every listed item whose name is not cached yet.
function OpenContainers:RequestItemNames()
	local cfg = config()
	local missing = {}
	for _, listKey in ipairs({ "allowList", "blockList" }) do
		for itemId in pairs(cfg[listKey]) do
			if not self:GetItemName(itemId) then
				missing[#missing + 1] = itemId
			end
		end
	end
	if #missing == 0 then
		return
	end

	local index = 1
	local function requestBatch()
		local last = math.min(index + NAME_REQUEST_BATCH - 1, #missing)
		for i = index, last do
			self.api.RequestItemData(missing[i])
		end
		index = last + 1
		if index <= #missing then
			self.api.After(NAME_REQUEST_INTERVAL, requestBatch)
		end
	end
	requestBatch()
end

function OpenContainers:GET_ITEM_INFO_RECEIVED(_, itemId, success)
	local cfg = config()
	if success == false or not (cfg.allowList[itemId] or cfg.blockList[itemId]) then
		return
	end
	if not cfg.itemNames[itemId] and self:GetItemName(itemId) then
		onNamesChanged()
	end
end

--- Level check that needs the item cache. An uncached item reads nil and is
--- tried anyway; the refusal counter catches it if the game says no.
---@param itemId number
---@return boolean
function OpenContainers:MeetsLevelRequirement(itemId)
	local requiredLevel = self.api.GetItemRequiredLevel(itemId)
	return not (requiredLevel and requiredLevel > self.api.UnitLevel())
end

-- ── Safety ──────────────────────────────────────────────────

--- Free general-purpose bag slots (specialty bags do not count).
---@return number
function OpenContainers:GetFreeSlots()
	local free = 0
	for bag = 0, self.api.GetLastBagIndex() do
		local slots, family = self.api.GetContainerNumFreeSlots(bag)
		if slots and (family == nil or family == 0) then
			free = free + slots
		end
	end
	return free
end

---@return boolean
function OpenContainers:IsSafeToOpen()
	if
		self.api.IsInCombat()
		or self.api.IsPlayerCasting()
		or self.api.IsStealthed()
		or self.api.IsInteractionActive()
	then
		return false
	end
	return self:GetFreeSlots() >= config().minFreeSlots
end

-- ── Queue ───────────────────────────────────────────────────

function OpenContainers:BuildQueue()
	queue = {}
	for bag = 0, self.api.GetLastBagIndex() do
		local slots = self.api.GetContainerNumSlots(bag) or 0
		for slot = 1, slots do
			local itemId = self.api.GetContainerItemID(bag, slot)
			if itemId and self:IsEligible(itemId) and self:MeetsLevelRequirement(itemId) then
				queue[#queue + 1] = { bag = bag, slot = slot, itemId = itemId }
			end
		end
	end
end

local function countRefusal()
	if not pendingItem then
		return
	end
	local count = (refusedCounts[pendingItem] or 0) + 1
	refusedCounts[pendingItem] = count
	if count >= OPEN_REFUSAL_LIMIT then
		refusedItems[pendingItem] = true
		OpenContainers:LogInfo("Setting aside unopenable item " .. tostring(pendingItem))
	end
	pendingItem = nil
end

function OpenContainers:ScheduleTick(interval)
	if tickLive then
		return
	end
	tickLive = true
	self.api.After(interval, function()
		tickLive = false
		self:OpenTick()
	end)
end

--- Go on to the next queued container, or rescan when the queue is empty (opening a stack
--- leaves the slot filled until the last one).
function OpenContainers:ContinueQueue()
	if #queue > 0 then
		self:ScheduleTick(OPEN_TICK_INTERVAL)
	else
		self:ScheduleScan()
	end
end

--- Give an open one chance to be answered with loot. If it is not, count a refusal and
--- move on. One timer per open, ignored if the open was answered or superseded.
---@param seq number
function OpenContainers:StartAnswerTimeout(seq)
	self.api.After(OPEN_ANSWER_TIMEOUT, function()
		if seq ~= openSeq or not pendingItem then
			return
		end
		countRefusal()
		self:ContinueQueue()
	end)
end

--- Opens at most one container. It never polls: when something blocks it, it goes idle and
--- an event restarts it; after an open it waits for LOOT_CLOSED or the answer timeout.
function OpenContainers:OpenTick()
	if not config().enabled then
		return
	end
	-- Protected actions (and, on newer clients, much of the state we would read) are off the
	-- table in combat. PLAYER_REGEN_ENABLED rescans and restarts us.
	if self.api.IsInCombat() then
		return
	end
	if #queue == 0 then
		return
	end
	-- Blocked by a window, a cast, stealth or low bag space: idle until an event clears it.
	if not self:IsSafeToOpen() then
		return
	end
	-- An open is waiting for its loot: LOOT_CLOSED or its timeout continues the queue.
	if pendingItem then
		return
	end

	local entry = table.remove(queue, 1)
	-- The slot may have changed since the scan.
	if
		entry
		and self.api.GetContainerItemID(entry.bag, entry.slot) == entry.itemId
		and self:IsEligible(entry.itemId)
	then
		pendingItem = entry.itemId
		openSeq = openSeq + 1
		self:LogDebug("Opening item " .. tostring(entry.itemId))
		self.api.UseContainerItem(entry.bag, entry.slot)
		self:StartAnswerTimeout(openSeq)
		return
	end
	self:ContinueQueue()
end

--- Something that was blocking an open may have cleared (stealth ended, a window closed, a
--- cast finished). The queue is still valid, so just try it again: no rescan needed.
function OpenContainers:OnUnblocked()
	if #queue > 0 then
		self:ScheduleTick(OPEN_TICK_INTERVAL)
	end
end

function OpenContainers:ScheduleScan()
	if scanPending then
		return
	end
	scanPending = true
	self.api.After(SCAN_DEBOUNCE, function()
		scanPending = false
		self:RunScan()
	end)
end

function OpenContainers:RunScan()
	if not G_RLF.db or not config().enabled then
		return
	end
	if self.api.IsInCombat() then
		return
	end
	self:BuildQueue()
	if #queue > 0 then
		self:ScheduleTick(OPEN_TICK_INTERVAL)
	end
end

-- ── Lifecycle ───────────────────────────────────────────────

--- Apply the saved enabled setting. Called on init and when the option toggles.
function OpenContainers:Refresh()
	if G_RLF.db and self:IsSupported() then
		self:Seed()
	end
	if G_RLF.db and config().enabled and self:IsSupported() then
		if not self:IsEnabled() then
			self:Enable()
		end
	elseif self:IsEnabled() then
		self:Disable()
	end
end

function OpenContainers:OnInitialize()
	if G_RLF.db and self:IsSupported() then
		self:Seed()
		self:ValidateNameCache()
		self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
		self:RequestItemNames()
	end
	if G_RLF.db and config().enabled and self:IsSupported() then
		self:Enable()
	else
		self:Disable()
	end
end

function OpenContainers:OnEnable()
	self:LogDebug("OnEnable")
	for _, event in ipairs(RESCAN_EVENTS) do
		if self.api.IsValidEvent(event) then
			self:RegisterEvent(event, "ScheduleScan")
		end
	end
	for _, event in ipairs(UNBLOCK_EVENTS) do
		if self.api.IsValidEvent(event) then
			self:RegisterEvent(event, "OnUnblocked")
		end
	end
	self:RegisterEvent("LOOT_CLOSED")
	self:RegisterEvent("PLAYER_LEVEL_UP")
	castListener = castListener or self.api.RegisterCastEndListener(function()
		self:OnUnblocked()
	end)
	castListener.Start()
	self:ScheduleScan()
end

function OpenContainers:OnDisable()
	-- GET_ITEM_INFO_RECEIVED stays registered: the options page needs item names even while disabled.
	for _, event in ipairs(RESCAN_EVENTS) do
		self:UnregisterEvent(event)
	end
	for _, event in ipairs(UNBLOCK_EVENTS) do
		self:UnregisterEvent(event)
	end
	self:UnregisterEvent("LOOT_CLOSED")
	self:UnregisterEvent("PLAYER_LEVEL_UP")
	if castListener then
		castListener.Stop()
	end
	queue = {}
end

function OpenContainers:LOOT_CLOSED()
	if pendingItem then
		-- The open was answered with loot: it is not being refused.
		refusedCounts[pendingItem] = nil
		pendingItem = nil
		self:ContinueQueue()
	else
		self:ScheduleScan()
	end
end

function OpenContainers:PLAYER_LEVEL_UP()
	-- A level-up can unlock containers that were refused for level.
	refusedCounts, refusedItems = {}, {}
	self:ScheduleScan()
end

--- Test seam: clear all transient state.
function OpenContainers:ResetState()
	queue = {}
	scanPending = false
	tickLive = false
	namesRefreshPending = false
	pendingItem = nil
	openSeq = openSeq + 1
	refusedCounts, refusedItems = {}, {}
	castListener = nil
end

--- Test seam: the current queue.
function OpenContainers:GetQueue()
	return queue
end

return OpenContainers
