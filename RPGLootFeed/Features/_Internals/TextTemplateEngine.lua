---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_TextElement
---@field type "primary" | "context" | "quantity" | "totalCount" | "topLeft" | "spacer"
---@field template string -- Template with placeholders like "{amount}", "{name}", "{total}"
---@field order? number -- Left-to-right ordering within the row (1, 2, 3, etc.)
---@field color? table -- RGBA color array
---@field formatting? table -- Additional formatting options
---@field conditions? table -- When to show this element
---@field truncatable? boolean -- Whether this element can be truncated (usually only item links)
---@field spacerCount? number -- For spacer type: number of spaces to insert

---@class RLF_LootElementData
---@field key string
---@field quantity number
---@field textElements table<number, table<string, RLF_TextElement>> -- Row-indexed: [row][elementKey] = element
---@field icon? number
---@field isLink? boolean
---@field quality? number
---@field type string
---@field showForSeconds? number

---@class RLF_TextTemplateEngine
local TextTemplateEngine = {}

-- Registry for type-specific context providers
---@type table<string, fun(context: table, data: table): nil>
TextTemplateEngine.contextProviders = {}

--- Register a context provider for a specific element type
---@param elementType string The type of element (e.g., "Money", "Currency", "ItemLoot")
---@param providerFunction fun(context: table, data: table): nil Function that adds context for this type
function TextTemplateEngine:RegisterContextProvider(elementType, providerFunction)
	self.contextProviders[elementType] = providerFunction
end

--- Process a template string by replacing placeholders with actual data
---@param template string The template string with placeholders like "{amount}", "{total}", etc.
---@param data table The data context containing values for placeholders
---@param existingQuantity? number Optional existing quantity for cumulative displays
---@param truncatedItemLink? string Optional pre-truncated item link for link placeholders
---@return string processedText The processed template with placeholders replaced
function TextTemplateEngine:ProcessTemplate(template, data, existingQuantity, truncatedItemLink)
	if not template or template == "" then
		return ""
	end

	-- Create a context for placeholder replacement
	local context = self:CreateTemplateContext(data, existingQuantity, truncatedItemLink)

	-- Replace placeholders in the template
	local result = template
	for placeholder, value in pairs(context) do
		-- Replace {placeholder} with the actual value
		local pattern = "{" .. placeholder .. "}"
		result = result:gsub(pattern, tostring(value))
	end

	return result
end

--- Create a context table with all available placeholders for template processing
---@param data table The element data
---@param existingQuantity? number Optional existing quantity
---@param truncatedItemLink? string Optional pre-truncated item link for link placeholders
---@return table context Table of placeholder names to values
function TextTemplateEngine:CreateTemplateContext(data, existingQuantity, truncatedItemLink)
	local context = {}

	-- Basic placeholders
	context.amount = data.quantity or 0
	context.total = (existingQuantity or 0) + (data.quantity or 0)
	context.existingQuantity = existingQuantity or 0

	-- Sign-related placeholders
	local total = context.total
	context.sign = total >= 0 and "" or "-"
	context.absTotal = math.abs(total)
	context.absAmount = math.abs(context.amount)

	-- Quantity text placeholders (for the "x5" type display)
	context.quantityPrefix = self:GetQuantityPrefix(data.type)
	context.quantityText = self:FormatQuantityText(context.total, data.type)
	context.quantityDisplay = self:FormatQuantityDisplay(context.total, data.type)

	-- Total count placeholders (for the "(15)" type display showing inventory total)
	context.totalCount = data.itemCount or 0
	context.totalCountText = self:FormatTotalCountText(data.itemCount, data.type)

	-- Item link placeholders (for items/currencies)
	context.itemLink = data.link or ""
	context.truncatedLink = truncatedItemLink or data.link or ""
	context.itemName = self:ExtractItemName(context.truncatedLink)

	-- Add type-specific context using registered providers
	local provider = self.contextProviders[data.type]
	if provider then
		provider(context, data)
	end

	return context
end

--- Abbreviate large numbers (thousands, millions, billions)
---@param number number The number to abbreviate
---@return string abbreviated The abbreviated string
function TextTemplateEngine:AbbreviateNumber(number)
	if number >= 1000000000 then
		return string.format("%.2f" .. (G_RLF.L["BillionAbbrev"] or "B"), number / 1000000000)
	elseif number >= 1000000 then
		return string.format("%.2f" .. (G_RLF.L["MillionAbbrev"] or "M"), number / 1000000)
	elseif number >= 1000 then
		return string.format("%.2f" .. (G_RLF.L["ThousandAbbrev"] or "K"), number / 1000)
	end
	return tostring(number)
end

--- Apply a text color to a string using hex format
--- @param text string? The text to color
--- @param color table? The color as an RGBA table
function TextTemplateEngine:ApplyTextColor(text, color)
	if not text or text == "" then
		return ""
	end
	if not color or #color < 3 then
		return text -- No color specified, return original text
	end

	-- Convert RGB to hex format and apply color
	local hexColor = G_RLF:RGBAToHexFormat(unpack(color))
	return hexColor .. text .. "|r" -- Append reset color code at the end
end

--- Process all text elements for a loot element data
---@param elementData RLF_LootElementData The loot element data
---@param existingQuantity? number Optional existing quantity
---@param truncatedItemLink? string Optional pre-truncated item link for {truncatedLink} placeholders
---@return table<number, table<string, string>> processedTexts Row-indexed map of element key to processed text
function TextTemplateEngine:ProcessAllTextElements(elementData, existingQuantity, truncatedItemLink)
	local result = {}

	for rowNumber, rowElements in pairs(elementData.textElements or {}) do
		result[rowNumber] = {}
		for elementKey, textElement in pairs(rowElements) do
			if textElement.type == "spacer" then
				result[rowNumber][elementKey] = string.rep(" ", textElement.spacerCount or 1)
			else
				result[rowNumber][elementKey] =
					self:ProcessTemplate(textElement.template, elementData, existingQuantity, truncatedItemLink)
				result[rowNumber][elementKey] = self:ApplyTextColor(result[rowNumber][elementKey], textElement.color)
			end
		end
	end

	return result
end

--- Generate layout for row-indexed text elements
---@param rowIndex number The row index to process
---@param elementData table The element data for processing templates
---@param existingQuantity? number Optional existing quantity
---@param truncatedItemLink? string Optional pre-truncated item link for {truncatedLink} placeholders
---@return string layoutText The combined text for this row
function TextTemplateEngine:ProcessRowElements(rowIndex, elementData, existingQuantity, truncatedItemLink)
	if not elementData.textElements then
		error(elementData.type .. ": textElements row is nil for index: " .. tostring(rowIndex))
	end

	local rowElements = elementData.textElements[rowIndex]
	if not rowElements then
		error(elementData.type .. ": textElements row is nil for index: " .. tostring(rowIndex))
	end

	-- Group elements by order
	local elementsByOrder = {}
	for elementKey, textElement in pairs(rowElements) do
		local order = textElement.order or 1

		-- Handle order conflicts by finding next available order
		while elementsByOrder[order] do
			order = order + 1
		end

		elementsByOrder[order] = {
			key = elementKey,
			element = textElement,
		}
	end

	-- Sort by order and process
	local sortedOrders = {}
	for order in pairs(elementsByOrder) do
		table.insert(sortedOrders, order)
	end
	table.sort(sortedOrders)

	local result = {}
	for _, order in ipairs(sortedOrders) do
		local item = elementsByOrder[order]
		local processedText

		if item.element.type == "spacer" then
			processedText = string.rep(" ", item.element.spacerCount or 1)
		else
			processedText =
				self:ProcessTemplate(item.element.template, elementData, existingQuantity, truncatedItemLink)
			processedText = self:ApplyTextColor(processedText, item.element.color)
		end

		table.insert(result, processedText)
	end

	local finalResult = table.concat(result)

	-- If the result is only whitespace (spacers with no content), return empty string
	if finalResult:match("^%s*$") then
		return ""
	end

	return finalResult
end

--- Get the quantity prefix based on type and configuration
---@param elementType string The type of element (Money, Currency, etc.)
---@return string prefix The prefix to use (e.g., "x", "+", "")
function TextTemplateEngine:GetQuantityPrefix(elementType)
	-- For now, use "x" as default, but this will be configurable per element type
	return "x"
end

--- Format quantity text (e.g., "x5" for items)
---@param total number The total quantity
---@param elementType string The type of element
---@return string formattedText The formatted quantity text
function TextTemplateEngine:FormatQuantityText(total, elementType)
	if total == 1 and not G_RLF.db.global.misc.showOneQuantity then
		return ""
	end
	return self:GetQuantityPrefix(elementType) .. total
end

--- Format quantity display with conditional logic
---@param total number The total quantity
---@param elementType string The type of element
---@return string formattedText The formatted quantity display
function TextTemplateEngine:FormatQuantityDisplay(total, elementType)
	local quantityText = self:FormatQuantityText(total, elementType)
	return quantityText ~= "" and (" " .. quantityText) or ""
end

--- Format total count text (e.g., "(15)" showing inventory total)
---@param totalCount number The total count in inventory
---@param elementType string The type of element
---@return string formattedText The formatted total count text
function TextTemplateEngine:FormatTotalCountText(totalCount, elementType)
	if not totalCount or totalCount == 0 then
		return ""
	end
	-- Different element types may have different formatting
	return "(" .. totalCount .. ")"
end

--- Extract item name from an item link
---@param itemLink string The item link to extract name from
---@return string itemName The extracted item name
function TextTemplateEngine:ExtractItemName(itemLink)
	if not itemLink or itemLink == "" then
		return ""
	end

	-- Extract name from item link format: |cxxxxxxxx|Hitem:...|h[Item Name]|h|r
	local name = itemLink:match("%[(.-)%]")
	return name or itemLink
end

G_RLF.TextTemplateEngine = TextTemplateEngine

-- ── Self-register in DI container ─────────────────────────────────────────────
if G_RLF.DI then
	G_RLF.DI:Register("TextTemplateEngine", TextTemplateEngine)
end

return TextTemplateEngine
