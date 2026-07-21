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
--- Called from LootDisplay:ShowSampleRows() — the caller already guards that the
--- loot frame exists, so no lootFrames check is needed here.
--- All rows carry isSampleRow = true so they never expire, and are re-enqueued
--- on right-click dismiss (see processRow in LootDisplay.lua) so the user can
--- cycle through all preview rows when maxRows < total sample count.
--- @param frame G_RLF.Frames
function LootDisplay:CreateSampleRows(frame)
	local LootElementBase = G_RLF.LootElementBase
	local ItemQualEnum = G_RLF.ItemQualEnum
	local FeatureModule = G_RLF.FeatureModule
	local DefaultIcons = G_RLF.DefaultIcons
	local TextTemplateEngine = G_RLF.TextTemplateEngine

	-- Fetch item icon safely; falls back to nil (row renders fine without one)
	local sampleItemIcon = nil
	local itemFeature = G_RLF.DbAccessor:Feature(frame, "itemLoot") or {}
	if itemFeature.enableIcon and not G_RLF.db.global.misc.hideAllIcons then
		local ok, icon = pcall(function()
			return GetItemIcon(14344)
		end)
		sampleItemIcon = ok and icon or nil
	end

	-- Look up the frame's subscription config so we only show samples for
	-- features routed to this specific frame.
	local frameConfig = G_RLF.db.global.frames and G_RLF.db.global.frames[frame]
	local features = frameConfig and frameConfig.features or {}

	-- ── PartyLoot ──────────────────────────────────────────────────────────────
	if features.partyLoot and features.partyLoot.enabled then
		local partyModule = G_RLF.RLF:GetModule(FeatureModule.PartyLoot)
		if partyModule and partyModule:IsEnabled() then
			LootElementBase:fromPayload({
				key = "sample_party_loot",
				type = "PartyLoot",
				isLink = true,
				unit = "player",
				icon = sampleItemIcon,
				quality = ItemQualEnum.Rare,
				quantity = 2,
				textFn = function(_, truncatedLink)
					return truncatedLink or SAMPLE_ITEM_LINK
				end,
				amountTextFn = function(existingQuantity)
					local effectiveQuantity = (existingQuantity or 0) + 2
					if effectiveQuantity == 1 and not G_RLF.db.global.misc.showOneQuantity then
						return ""
					end
					return "x" .. effectiveQuantity
				end,
				secondaryText = "    Adventurer",
				secondaryTextFn = function()
					return "    Adventurer"
				end,
				isSampleRow = true,
				sampleTooltipText = G_RLF.L["Party Loot"],
				IsEnabled = function()
					return true
				end,
			}):Show()
		end
	end

	-- ── ItemLoot ───────────────────────────────────────────────────────────────
	if features.itemLoot and features.itemLoot.enabled then
		local itemModule = G_RLF.RLF:GetModule(FeatureModule.ItemLoot)
		if itemModule and itemModule:IsEnabled() then
			local itemDb = G_RLF.DbAccessor:Feature(frame, "itemLoot") or {}
			LootElementBase:fromPayload({
				key = "sample_item_loot",
				type = FeatureModule.ItemLoot,
				isLink = true,
				icon = sampleItemIcon,
				quality = ItemQualEnum.Rare,
				quantity = 2,
				textFn = function(_, truncatedLink)
					return truncatedLink or SAMPLE_ITEM_LINK
				end,
				amountTextFn = function(existingQuantity)
					local effectiveQuantity = (existingQuantity or 0) + 2
					if effectiveQuantity == 1 and not G_RLF.db.global.misc.showOneQuantity then
						return ""
					end
					return "x" .. effectiveQuantity
				end,
				itemCountFn = function()
					if not itemDb.itemCountTextEnabled then
						return nil
					end
					return 14,
						{
							color = G_RLF:RGBAToHexFormat(unpack(itemDb.itemCountTextColor)),
							wrapChar = itemDb.itemCountTextWrapChar,
						}
				end,
				isSampleRow = true,
				sampleTooltipText = G_RLF.L["Item Loot"],
				IsEnabled = function()
					return true
				end,
			}):Show()
		end
	end

	-- ── Money ──────────────────────────────────────────────────────────────────
	if features.money and features.money.enabled then
		local moneyModule = G_RLF.RLF:GetModule(FeatureModule.Money)
		if moneyModule and moneyModule:IsEnabled() then
			local quantity = 12345
			local moneyTextElements = moneyModule:GenerateTextElements(quantity)
			local moneyFeature = G_RLF.DbAccessor:Feature(frame, "money") or {}
			local moneyElementData = {
				key = "sample_money_loot",
				type = FeatureModule.Money,
				textElements = moneyTextElements,
				quantity = quantity,
				icon = (moneyFeature.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and DefaultIcons.MONEY
					or nil,
				quality = ItemQualEnum.Poor,
			}
			LootElementBase:fromPayload({
				key = "sample_money_loot",
				type = FeatureModule.Money,
				icon = moneyElementData.icon,
				quality = ItemQualEnum.Poor,
				quantity = quantity,
				textFn = function(existingCopper)
					return TextTemplateEngine:ProcessRowElements(1, moneyElementData, existingCopper)
				end,
				secondaryTextFn = function()
					local mc = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
					if mc.showMoneyTotal then
						return " "
					end
					return ""
				end,
				amountTextFn = function(existingCopper)
					local mc = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
					if mc.accountantMode then
						local net = (existingCopper or 0) + quantity
						if net < 0 then
							return ")"
						end
					end
					return ""
				end,
				coinDataFn = function(existingCopper)
					local total = math.abs((existingCopper or 0) + quantity)
					local gold = math.floor(total / 10000)
					local silver = math.floor((total % 10000) / 100)
					local copper = total % 100
					return gold, silver, copper
				end,
				secondaryCoinDataFn = function()
					local mc = G_RLF.DbAccessor:AnyFeatureConfig("money") or {}
					if not mc.showMoneyTotal then
						return nil
					end
					-- Use a fixed representative wallet total for the sample row.
					local sampleTotal = 1234567 -- ~123g 45s 67c
					local gold = math.floor(sampleTotal / 10000)
					local silver = math.floor((sampleTotal % 10000) / 100)
					local copper = sampleTotal % 100
					local goldText = nil
					if mc.abbreviateTotal and gold >= 1000 then
						goldText = TextTemplateEngine:AbbreviateNumber(gold)
					end
					return gold, silver, copper, nil, nil, goldText
				end,
				isSampleRow = true,
				sampleTooltipText = G_RLF.L["Money"],
				IsEnabled = function()
					return true
				end,
			}):Show()
		end
	end

	-- ── Currency ───────────────────────────────────────────────────────────────
	if features.currency and features.currency.enabled then
		local currencyModule = G_RLF.RLF:GetModule(FeatureModule.Currency)
		if currencyModule and currencyModule:IsEnabled() then
			local currencyDb = G_RLF.DbAccessor:Feature(frame, "currency") or {}
			local currencyLink = "|cff00aaff|Hcurrency:2|h[Sample Currency]|h|r"
			LootElementBase:fromPayload({
				key = "sample_currency",
				type = "Currency",
				isLink = true,
				icon = (currencyDb.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and DefaultIcons.MONEY or nil,
				quality = ItemQualEnum.Rare,
				quantity = 50,
				textFn = function(_, truncatedLink)
					return truncatedLink or currencyLink
				end,
				amountTextFn = function(existingQuantity)
					local effectiveQuantity = (existingQuantity or 0) + 50
					if effectiveQuantity == 1 and not G_RLF.db.global.misc.showOneQuantity then
						return ""
					end
					return "x" .. effectiveQuantity
				end,
				itemCountFn = function()
					if not currencyDb.currencyTotalTextEnabled then
						return nil
					end
					return 1500,
						{
							color = G_RLF:RGBAToHexFormat(unpack(currencyDb.currencyTotalTextColor)),
							wrapChar = currencyDb.currencyTotalTextWrapChar,
						}
				end,
				secondaryTextFn = function()
					local color = G_RLF:RGBAToHexFormat(unpack(currencyDb.lowestColor))
					return "    " .. color .. "1500 / 3000|r"
				end,
				isSampleRow = true,
				sampleTooltipText = G_RLF.L["Currency"],
				IsEnabled = function()
					return true
				end,
			}):Show()
		end
	end

	-- ── Reputation ─────────────────────────────────────────────────────────────
	if features.reputation and features.reputation.enabled then
		local repModule = G_RLF.RLF:GetModule(FeatureModule.Reputation)
		if repModule and repModule:IsEnabled() then
			local repDb = G_RLF.DbAccessor:Feature(frame, "reputation") or {}
			local r, g, b, a = 1, 0.82, 0, 1
			LootElementBase:fromPayload({
				key = "sample_rep",
				type = "Reputation",
				icon = (repDb.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and DefaultIcons.REPUTATION or nil,
				quality = ItemQualEnum.Rare,
				quantity = 668,
				r = r,
				g = g,
				b = b,
				a = a,
				textFn = function(existingRep)
					local rep = (existingRep or 0) + 668
					local sign = rep >= 0 and "+" or "-"
					return sign .. math.abs(rep) .. " Stormwind"
				end,
				itemCountFn = function()
					if not repDb.enableRepLevel then
						return nil
					end
					return "Honored",
						{
							color = G_RLF:RGBAToHexFormat(unpack(repDb.repLevelColor)),
							wrapChar = repDb.repLevelTextWrapChar,
						}
				end,
				secondaryTextFn = function()
					local color = G_RLF:RGBAToHexFormat(r, g, b, repDb.secondaryTextAlpha)
					return "    " .. color .. "21000 / 42000|r"
				end,
				isSampleRow = true,
				sampleTooltipText = G_RLF.L["Reputation"],
				IsEnabled = function()
					return true
				end,
			}):Show()
		end
	end

	-- ── Experience ─────────────────────────────────────────────────────────────
	if features.experience and features.experience.enabled then
		local xpModule = G_RLF.RLF:GetModule(FeatureModule.Experience)
		if xpModule and xpModule:IsEnabled() then
			local xpDb = G_RLF.DbAccessor:Feature(frame, "experience") or {}
			local quantity = 1500
			local xpTextElements = xpModule:GenerateTextElements(quantity)
			local xpElementData = {
				key = "sample_xp",
				type = "Experience",
				textElements = xpTextElements,
				quantity = quantity,
				icon = (xpDb.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and DefaultIcons.XP or nil,
				quality = ItemQualEnum.Epic,
			}
			LootElementBase:fromPayload({
				key = "sample_xp",
				type = "Experience",
				icon = xpElementData.icon,
				quality = ItemQualEnum.Epic,
				quantity = quantity,
				textFn = function(existingXP)
					return TextTemplateEngine:ProcessRowElements(1, xpElementData, existingXP)
				end,
				secondaryTextFn = function(existingXP)
					return TextTemplateEngine:ProcessRowElements(2, xpElementData, existingXP)
				end,
				itemCountFn = function()
					if not xpDb.showCurrentLevel then
						return nil
					end
					return 80,
						{
							color = G_RLF:RGBAToHexFormat(unpack(xpDb.currentLevelColor)),
							wrapChar = xpDb.currentLevelTextWrapChar,
						}
				end,
				isSampleRow = true,
				sampleTooltipText = G_RLF.L["Experience"],
				IsEnabled = function()
					return true
				end,
			}):Show()
		end
	end

	-- ── Professions ────────────────────────────────────────────────────────────
	if features.profession and features.profession.enabled then
		local profModule = G_RLF.RLF:GetModule(FeatureModule.Profession)
		if profModule and profModule:IsEnabled() then
			local profDb = G_RLF.DbAccessor:Feature(frame, "profession") or {}
			local profColor = G_RLF:RGBAToHexFormat(unpack(profDb.skillColor))
			LootElementBase:fromPayload({
				key = "sample_professions",
				type = "Professions",
				icon = (profDb.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and DefaultIcons.PROFESSION or nil,
				quality = ItemQualEnum.Rare,
				quantity = 5,
				textFn = function()
					return profColor .. "Cooking 300|r"
				end,
				secondaryTextFn = function()
					return ""
				end,
				itemCountFn = function()
					if not profDb.showSkillChange then
						return nil
					end
					return 5,
						{
							color = G_RLF:RGBAToHexFormat(unpack(profDb.skillColor)),
							wrapChar = profDb.skillTextWrapChar,
							showSign = true,
						}
				end,
				isSampleRow = true,
				sampleTooltipText = G_RLF.L["Profession Skills"],
				IsEnabled = function()
					return true
				end,
			}):Show()
		end
	end

	-- ── TravelPoints ───────────────────────────────────────────────────────────
	if features.travelPoints and features.travelPoints.enabled then
		local travelModule = G_RLF.RLF:GetModule(FeatureModule.TravelPoints)
		if travelModule and travelModule:IsEnabled() then
			local tpDb = G_RLF.DbAccessor:Feature(frame, "travelPoints") or {}
			local r, g, b, a = unpack(tpDb.textColor)
			LootElementBase:fromPayload({
				key = "sample_travel_points",
				type = "TravelPoints",
				icon = (tpDb.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and DefaultIcons.TRAVELPOINTS or nil,
				quality = ItemQualEnum.Common,
				quantity = 500,
				r = r,
				g = g,
				b = b,
				a = a,
				textFn = function(existingAmount)
					return "Travel Points + " .. ((existingAmount or 0) + 500)
				end,
				secondaryTextFn = function()
					local color = G_RLF:RGBAToHexFormat(r, g, b, a)
					return "    " .. color .. "1250/2000|r"
				end,
				isSampleRow = true,
				sampleTooltipText = G_RLF.L["Travel Points"],
				IsEnabled = function()
					return true
				end,
			}):Show()
		end
	end

	-- ── Transmog (Retail only) ─────────────────────────────────────────────────
	if features.transmog and features.transmog.enabled then
		local transmogModule = G_RLF.RLF:GetModule(FeatureModule.Transmog)
		if transmogModule and transmogModule:IsEnabled() then
			local transmogFeature = G_RLF.DbAccessor:Feature(frame, "transmog") or {}
			LootElementBase:fromPayload({
				key = "sample_transmog",
				type = "Transmog",
				isLink = true,
				icon = (transmogFeature.enableIcon and not G_RLF.db.global.misc.hideAllIcons) and DefaultIcons.TRANSMOG
					or nil,
				quality = ItemQualEnum.Epic,
				quantity = 1,
				highlight = true,
				textFn = function(_, truncatedLink)
					return truncatedLink or SAMPLE_TRANSMOG_LINK
				end,
				secondaryTextFn = function()
					return "Appearance Collected"
				end,
				isSampleRow = true,
				sampleTooltipText = G_RLF.L["Transmog"],
				IsEnabled = function()
					return true
				end,
			}):Show()
		end
	end

	-- ── LootRolls ───────────────────────────────────────────────────────────────
	if features.lootRolls and features.lootRolls.enabled then
		local lootRollsModule = G_RLF.RLF:GetModule(FeatureModule.LootRolls)
		if lootRollsModule and lootRollsModule:IsEnabled() then
			LootElementBase:fromPayload({
				key = "sample_loot_roll",
				type = FeatureModule.LootRolls,
				isLink = true,
				icon = sampleItemIcon,
				quality = ItemQualEnum.Rare,
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
				IsEnabled = function()
					return true
				end,
			}):Show()
		end
	end
end

return {}
