---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- LootElementBase is a mixin table whose :new() method stamps all default fields
--- and shared methods onto a fresh element table.  No metatables are used – each
--- returned element is a fully-independent flat table suitable for direct mutation.
---@class LootElementBase
G_RLF.LootElementBase = {}

--- Creates a new loot element table with all RLF_BaseLootElement defaults populated.
--- Feature modules should call this to start building an element, then override
--- any fields they need before calling element:Show().
---@return RLF_BaseLootElement
function G_RLF.LootElementBase:new()
	---@class RLF_BaseLootElement
	---@field public customBehavior? fun(): nil
	---@field public colorFn (fun(netQuantity: number): number, number, number)?
	local element = {}

	-- ── Identity / routing ─────────────────────────────────────────────────────
	element.key = nil
	element.type = nil
	element.eventChannel = "RLF_NEW_LOOT"

	-- ── Presentation flags ─────────────────────────────────────────────────────
	element.isLink = false
	element.isCustomLink = nil
	element.highlight = false
	element.customBehavior = nil
	element.isSampleRow = false

	-- ── Visuals ────────────────────────────────────────────────────────────────
	element.icon = nil
	element.quality = nil
	element.sellPrice = nil

	-- ── Quantity / count tracking ──────────────────────────────────────────────
	element.quantity = nil
	element.totalCount = nil
	element.itemCount = nil
	element.unit = nil

	-- ── Text providers ─────────────────────────────────────────────────────────
	element.textFn = nil
	element.secondaryTextFn = nil
	element.secondaryText = nil
	element.topLeftText = nil
	element.topLeftColor = nil

	-- ── Coin display providers (real-texture coin icons) ─────────────────────
	-- When set, the row creates a CoinDisplay / SecondaryCoinDisplay frame so that
	-- coin icons are real Texture children (not |T| markup), which travel correctly
	-- with Translation animations.
	-- coinDataFn(existingCopper) → gold, silver, copper  (primary line)
	-- secondaryCoinDataFn(existingCopper) → gold, silver, copper, prefixAtlas, prefixSize
	element.coinDataFn = nil
	element.secondaryCoinDataFn = nil

	-- ── RGBA color (default: opaque white) ─────────────────────────────────────
	element.r = 1
	element.g = 1
	element.b = 1
	element.a = 1
	element.colorFn = nil

	-- ── Per-frame filter metadata ────────────────────────────────────────────
	-- Carried forward so LootDisplayFrame:PassesPerFrameFilters can evaluate
	-- per-frame quality tiers and deny lists without knowing the source module.
	element.filterItemId = nil -- Item ID for deny list checks (ItemLoot, PartyLoot)
	element.filterItemQuality = nil -- Quality tier for quality-filter checks
	element.filterCurrencyId = nil -- Currency ID for deny list checks (Currency)

	-- ── Display timing ─────────────────────────────────────────────────────────
	-- Left nil so each row reads its own frame's configured delay in Init().
	-- Feature modules may set payload.showForSeconds for a per-element override.
	element.showForSeconds = nil

	-- ── Capability stubs (feature modules must override) ──────────────────────
	--- Returns true if the feature module is currently enabled.
	element.IsEnabled = function()
		return false
	end

	-- ── Shared methods ─────────────────────────────────────────────────────────

	--- Override to restrict which display rows are shown.
	--- Returns true if this element should be displayed.
	---@param _itemName string
	---@param _itemQuality number
	---@return boolean
	function element:isPassingFilter(_itemName, _itemQuality)
		return true
	end

	--- Sends this element to the LootDisplay engine via the AceMessage bus.
	---@param itemName? string
	---@param itemQuality? number
	function element:Show(itemName, itemQuality)
		if self:isPassingFilter(itemName, itemQuality) then
			G_RLF:LogDebug("Show", addonName, self.type, self.key, nil, self.quantity)
			G_RLF:SendMessage(self.eventChannel, self)
		else
			G_RLF:LogDebug(
				"Skip Show, isPassingFilter returned false",
				addonName,
				self.type,
				self.key,
				tostring(itemName) .. " " .. tostring(itemQuality),
				self.quantity
			)
		end
	end

	--- Standard logging helper; called from LootDisplay when a row is shown.
	--- Kept as a plain function (not a method) to match the RLF_BaseLootElement type annotation.
	---@param text string
	---@param amount number
	---@param new boolean
	element.logFn = function(text, amount, new)
		local amountLogText = tostring(amount)
		local sign = "+"
		if element.quantity ~= nil and element.quantity < 0 then
			sign = "-"
		end
		if not new and amount ~= nil then
			amountLogText = format("%s (diff: %s%s)", amount, sign, math.abs(element.quantity))
		end
		G_RLF:LogInfo(element.type .. "Shown", addonName, element.type, element.key, text, amountLogText, new)
	end

	return element
end

--- Creates a new loot element from a uniform payload table.
--- This is the preferred way for feature modules to construct elements.
--- The payload maps directly to row visual components (icon, primary line,
--- secondary line, etc.) without requiring per-module Element constructors.
---@param payload RLF_ElementPayload
---@return RLF_BaseLootElement
function G_RLF.LootElementBase:fromPayload(payload)
	local element = self:new()

	-- ── Routing ────────────────────────────────────────────────────────────────
	element.key = payload.key
	element.type = payload.type
	if payload.eventChannel then
		element.eventChannel = payload.eventChannel
	end

	-- ── Icon ───────────────────────────────────────────────────────────────────
	element.icon = payload.icon
	element.quality = payload.quality
	element.topLeftText = payload.topLeftText
	element.topLeftColor = payload.topLeftColor

	-- ── Primary line ───────────────────────────────────────────────────────────
	element.textFn = payload.textFn
	element.quantity = payload.quantity
	element.isLink = payload.isLink or false
	element.amountTextFn = payload.amountTextFn
	element.itemCountFn = payload.itemCountFn

	-- ── Secondary line ─────────────────────────────────────────────────────────
	element.secondaryTextFn = payload.secondaryTextFn
	element.secondaryText = payload.secondaryText
	element.secondaryTextColor = payload.secondaryTextColor

	-- ── Coin display providers ────────────────────────────────────────────────
	element.coinDataFn = payload.coinDataFn
	element.secondaryCoinDataFn = payload.secondaryCoinDataFn

	-- ── Color ──────────────────────────────────────────────────────────────────
	if payload.r then
		element.r = payload.r
	end
	if payload.g then
		element.g = payload.g
	end
	if payload.b then
		element.b = payload.b
	end
	if payload.a then
		element.a = payload.a
	end
	element.colorFn = payload.colorFn

	-- ── Effects ────────────────────────────────────────────────────────────────
	element.highlight = payload.highlight or false
	element.sound = payload.sound

	-- ── Interaction ────────────────────────────────────────────────────────────
	element.isCustomLink = payload.isCustomLink
	element.customBehavior = payload.customBehavior

	-- ── Party ──────────────────────────────────────────────────────────────────
	element.unit = payload.unit

	-- ── Lifecycle ──────────────────────────────────────────────────────────────
	if payload.showForSeconds then
		element.showForSeconds = payload.showForSeconds
	end
	element.isSampleRow = payload.isSampleRow or false
	element.sampleTooltipText = payload.sampleTooltipText or nil
	if payload.logFn then
		element.logFn = payload.logFn
	end
	-- Auto-inject IsEnabled from moduleRef so features don't repeat the closure.
	-- Explicit payload.IsEnabled still takes precedence when set.
	if payload.moduleRef then
		local ref = payload.moduleRef
		element.IsEnabled = function()
			return ref:IsEnabled()
		end
	elseif payload.IsEnabled then
		element.IsEnabled = payload.IsEnabled
	end

	-- ── Per-frame filter metadata ─────────────────────────────────────────────
	element.filterItemId = payload.filterItemId
	element.filterItemQuality = payload.filterItemQuality
	element.filterCurrencyId = payload.filterCurrencyId

	-- ── LootRolls-specific fields ──────────────────────────────────────────────
	-- Used directly by the row mixin; nil for non-roll types
	element.rollID = payload.rollID
	element.rollDuration = payload.rollDuration
	element.itemLink = payload.itemLink
	-- Eligibility overrides used by sample rows (avoids GetLootRollItemInfo call)
	element.canNeed = payload.canNeed
	element.canGreed = payload.canGreed
	element.canTransmog = payload.canTransmog
	element.reasonNeed = payload.reasonNeed
	element.reasonGreed = payload.reasonGreed
	element.mockDropInfo = payload.mockDropInfo

	-- ── Backwards compatibility: keep itemCount for modules not yet migrated ──
	element.itemCount = payload.itemCount

	return element
end

---@class RLF_ElementPayload
---@field key string Unique row identity
---@field type string|number Module enum value or type string
---@field eventChannel? string Message bus channel (default: "RLF_NEW_LOOT")
---@field icon? number|string Texture ID or path
---@field quality? number Item quality / rarity
---@field topLeftText? string Text overlayed on icon corner
---@field topLeftColor? table RGBA table for topLeftText
---@field textFn fun(existingQty?: number, truncatedLink?: string): string Primary text provider
---@field quantity number The delta being applied
---@field isLink? boolean If true, textFn() returns a link on first call
---@field amountTextFn? fun(existingQty: number): string Amount suffix provider (e.g. "x2")
---@field itemCountFn? fun(): (number|nil, table|nil) Count display provider; returns (value, options)
---@field secondaryTextFn? fun(currentAmount: number): string Secondary line text provider
---@field secondaryText? string Static secondary text override
---@field secondaryTextColor? table ColorMixin with .r, .g, .b
---@field coinDataFn? fun(existingCopper?: number): number, number, number Primary coin display (gold, silver, copper); replaces |T| markup for money rows
---@field secondaryCoinDataFn? fun(existingCopper?: number): number, number, number, string?, number?, string? Secondary coin display (gold, silver, copper, prefixAtlas?, prefixSize?, goldText?)
---@field r? number Red channel (0-1, default 1)
---@field g? number Green channel (0-1, default 1)
---@field b? number Blue channel (0-1, default 1)
---@field a? number Alpha channel (0-1, default 1)
---@field colorFn? fun(netQty: number): number, number, number, number Dynamic color recomputer
---@field highlight? boolean Border glow / entry animation
---@field sound? string Sound file path
---@field isCustomLink? boolean Custom tooltip behavior flag
---@field sampleTooltipText? string Label shown on row hover in the options preview (sample rows only)
---@field customBehavior? fun() Click handler for custom links
---@field unit? string Unit token for portrait display
---@field filterItemId? number Item ID for per-frame deny list filtering (ItemLoot, PartyLoot)
---@field filterItemQuality? number Item quality for per-frame quality-tier filtering (ItemLoot, PartyLoot)
---@field filterCurrencyId? number Currency ID for per-frame deny list filtering (Currency)
---@field showForSeconds? number Override fade timer
---@field isSampleRow? boolean Test mode flag, never expires
---@field logFn? fun(text: string, amount: number, new: boolean) Logging hook
---@field moduleRef? table Module reference; fromPayload auto-injects IsEnabled from this when set
---@field IsEnabled? fun(): boolean Permission gate
---@field itemCount? number Backwards compat: raw count for non-migrated modules

--- Union of all concrete loot element types used by the LootDisplay engine.
--- @alias RLF_LootElement RLF_BaseLootElement

-- ── Self-register in DI container ─────────────────────────────────────────────
if G_RLF.DI then
	G_RLF.DI:Register("LootElementBase", G_RLF.LootElementBase)
end

return {}
