---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

function G_RLF:fn(func, ...)
	---@type G_RLF | RLF_Module
	local s = self
	local function errorhandler(err)
		local suffix = "\n\n==== Addon Info " .. addonName .. " " .. G_RLF.addonVersion .. " ====\n\n"
		local status, trace = pcall(function()
			local logger = G_RLF.RLF:GetModule(G_RLF.SupportModule.Logger) --[[@as RLF_Logger]]
			if s.moduleName then
				return logger:Trace(s.moduleName)
			end
			return nil
		end)
		if status and trace then
			suffix = suffix .. "Log traces related to " .. s.moduleName .. "\n"
			suffix = suffix .. "-------------------------------------------------\n"
			suffix = suffix .. trace
			suffix = suffix .. "-------------------------------------------------\n\n"
		end
		suffix = suffix .. G_RLF.L["Issues"] .. "\n\n"

		return geterrorhandler()(err .. suffix)
	end
	-- Borrowed from AceAddon-3.0
	if type(func) == "function" then
		return xpcall(func, errorhandler, ...)
	else
		error("fn: func is not a function")
	end
end

local acr = LibStub("AceConfigRegistry-3.0")
function G_RLF:NotifyChange(...)
	acr:NotifyChange(...)
end

function G_RLF:Print(...)
	G_RLF.RLF:Print(...)
end

function G_RLF:IsRetail()
	return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
end

function G_RLF:IsClassic()
	return WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
end

function G_RLF:IsTBCClassic()
	return WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
end

function G_RLF:IsCataClassic()
	return WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
end

function G_RLF:IsMoPClassic()
	return WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC
end

--- Check if mouse cursor is truly over a frame considering z-order.
--- Uses GetMouseFoci() on Retail (Dragonflight+) for accurate z-order check.
--- Falls back to IsMouseOver() on Classic where GetMouseFoci is unavailable.
--- @param frame Frame
--- @return boolean
function G_RLF:MouseIsOverFrame(frame)
	if GetMouseFoci then
		local foci = GetMouseFoci()
		for i = 1, #foci do
			local focus = foci[i]
			if focus == frame then
				return true
			end
			local parent = focus:GetParent()
			while parent do
				if parent == frame then
					return true
				end
				parent = parent:GetParent()
			end
		end
		return false
	end
	return frame:IsMouseOver()
end

function G_RLF:SendMessage(...)
	local args = { ... }
	RunNextFrame(function()
		G_RLF.RLF:SendMessage(unpack(args))
	end)
end

function G_RLF:RGBAToHexFormat(r, g, b, a)
	local red = string.format("%02X", math.floor(r * 255))
	local green = string.format("%02X", math.floor(g * 255))
	local blue = string.format("%02X", math.floor(b * 255))
	local alpha = string.format("%02X", math.floor((a or 1) * 255)) -- Default alpha to 1 if not provided

	-- Return in WoW format with |c prefix
	return "|c" .. alpha .. red .. green .. blue
end

local function secretSanitization(value, field)
	if issecretvalue and issecretvalue(value) then
		return "<" .. field .. " secret, ignored>"
	end

	return value
end

local function log(...)
	local message, _, _, id, content, amount = ...
	message = secretSanitization(message, "message")
	id = secretSanitization(id, "id")
	content = secretSanitization(content, "content")
	amount = secretSanitization(amount, "amount")
	local args = { ... }
	RunNextFrame(function()
		G_RLF:SendMessage("RLF_LOG", args)
	end)
end

--- Create debug log
--- @see RLF_Logger.addLogEntry
--- @param message string
--- @param source? string
--- @param type? string
--- @param id? string
--- @param content? string
--- @param amount? number | string
--- @param isNew? boolean
function G_RLF:LogDebug(message, source, type, id, content, amount, isNew)
	log(G_RLF.LogLevel.debug, message, source, type, id, content, amount, isNew)
end

--- Create info log
--- @see RLF_Logger.addLogEntry
--- @param message string
--- @param source? string
--- @param type? string
--- @param id? string
--- @param content? string
--- @param amount? number | string
--- @param isNew? boolean
function G_RLF:LogInfo(message, source, type, id, content, amount, isNew)
	log(G_RLF.LogLevel.info, message, source, type, id, content, amount, isNew)
end

--- Create warning log
--- @see RLF_Logger.addLogEntry
--- @param message string
--- @param source? string
--- @param type? string
--- @param id? string
--- @param content? string
--- @param amount? number | string
--- @param isNew? boolean
function G_RLF:LogWarn(message, source, type, id, content, amount, isNew)
	log(G_RLF.LogLevel.warn, message, source, type, id, content, amount, isNew)
end

--- Create error log
--- @see RLF_Logger.addLogEntry
--- @param message string
--- @param source? string
--- @param type? string
--- @param id? string
--- @param content? string
--- @param amount? number | string
--- @param isNew? boolean
function G_RLF:LogError(message, source, type, id, content, amount, isNew)
	log(G_RLF.LogLevel.error, message, source, type, id, content, amount, isNew)
end

function G_RLF:CreatePatternSegmentsForStringNumber(localeString)
	local preStart, preEnd = string.find(localeString, "%%s")
	if preStart == nil then
		-- Mainly for deDE which uses a slightly different format token
		preStart, preEnd = string.find(localeString, "%%1$s")
	end
	local prePattern = string.sub(localeString, 1, preStart - 1)
	local midStart, midEnd = string.find(localeString, "%%d", preEnd + 1)
	if midStart == nil then
		-- Mainly for deDE which uses a slightly different format token
		midStart, midEnd = string.find(localeString, "%%2$d", preEnd + 1)
	end
	local midPattern = string.sub(localeString, preEnd + 1, midStart - 1)
	local postPattern = string.sub(localeString, midEnd + 1)
	if string.find(postPattern, "%%") then
		-- If the postPattern contains a format token, we need to adjust it
		local postStart, postEnd = string.find(postPattern, "%%")
		if postStart then
			postPattern = string.sub(postPattern, 1, postStart - 1)
		end
	end
	return { prePattern, midPattern, postPattern }
end

--- @return string?, number?
function G_RLF:ExtractDynamicsFromPattern(localeString, segments)
	local prePattern, midPattern, postPattern = unpack(segments)
	local preMatchStart, preMatchEnd = string.find(localeString, prePattern, 1, true)
	if preMatchStart then
		local msgLoop = localeString:sub(preMatchEnd + 1)
		local midMatchStart, midMatchEnd = string.find(msgLoop, midPattern, 1, true)
		if midMatchStart then
			local postMatchStart, postMatchEnd = string.find(msgLoop, postPattern, midMatchEnd, true)
			if postMatchStart then
				local str = msgLoop:sub(1, midMatchStart - 1)
				local num
				if midMatchEnd == postMatchStart then
					num = msgLoop:sub(midMatchEnd + 1)
				else
					num = msgLoop:sub(midMatchEnd + 1, postMatchStart - 1)
				end
				return str, tonumber(num)
			end
		end
	end

	return nil, nil
end

local menu = {
	{ text = addonName, isTitle = true, notCheckable = true },
	{
		text = G_RLF.L["Clear rows"],
		func = function()
			G_RLF.LootDisplay:HideLoot()
		end,
		notCheckable = true,
	},
}
local menuFrame = CreateFrame("Frame", addonName .. "MenuFrame", UIParent, "UIDropDownMenuTemplate")
local LibEasyMenu = LibStub("LibEasyMenu")

function G_RLF:OpenOptions(button)
	if button == "LeftButton" then
		G_RLF.acd:Open(addonName)
	elseif button == "RightButton" then
		local tmpMenu = {}
		for _, item in ipairs(menu) do
			table.insert(tmpMenu, item)
		end
		local unseenNotifications = G_RLF.Notifications:GetNumUnseenNotifications()
		if unseenNotifications > 0 then
			table.insert(tmpMenu, {
				text = string.format(G_RLF.L["View Notifications"], unseenNotifications),
				func = function()
					local notifModule = G_RLF.RLF:GetModule(G_RLF.SupportModule.Notifications) --[[@as RLF_Notifications]]
					if notifModule then
						notifModule:ViewAllNotifications()
					end
				end,
				notCheckable = true,
			})
		end
		if G_RLF.db.global.lootHistory.enabled then
			table.insert(tmpMenu, {
				text = G_RLF.L["Toggle Loot History"],
				func = function()
					G_RLF.HistoryService:ToggleHistoryFrame()
				end,
				notCheckable = true,
			})
		end
		table.insert(tmpMenu, {
			text = G_RLF.L["Close"],
			func = function()
				CloseDropDownMenus()
			end,
			notCheckable = true,
		})
		LibEasyMenu:EasyMenu(tmpMenu, menuFrame, "cursor", 0, 0, "MENU")
	end
end

function G_RLF:TableToCommaSeparatedString(tbl)
	local result = {}
	for key, value in pairs(tbl) do
		if value then
			table.insert(result, key)
		end
	end
	return table.concat(result, ", ")
end

--- Ask the client whether the SLUG font flag is accepted.
---
--- Blizzard exposes Slug rendering declaratively (the `slug` attribute on
--- `<Font>` in UI.xsd) and never passes the token to SetFont in its own Lua,
--- so the flag string cannot be confirmed from the UI source -- TBFFlags is an
--- opaque intrinsic type with no enumerated values.  Probing beats a hardcoded
--- interface-version table, which would only tell us the XML attribute exists.
---
--- Two steps, because not every client reports SetFont success: OUTLINE is
--- accepted everywhere, so if it does not report true this client cannot answer
--- the question at all and we report unsupported rather than guess.
--- @return boolean
function G_RLF:ProbeSlugSupport()
	local lsm = G_RLF.lsm
	local fontPath = lsm and lsm:Fetch(lsm.MediaType.FONT, "Friz Quadrata TT")
	if not fontPath then
		return false
	end

	local probe = UIParent:CreateFontString(nil, "BACKGROUND")
	if not (probe and probe.SetFont) then
		return false
	end

	local reportsSuccess = probe:SetFont(fontPath, 10, G_RLF.FontFlags.OUTLINE) == true
	local slugAccepted = probe:SetFont(fontPath, 10, G_RLF.FontFlags.SLUG) == true
	if probe.Hide then
		probe:Hide()
	end

	return reportsSuccess and slugAccepted
end

--- Get the frame's font flags as a string
---
--- SLUG is derived here rather than picked from the saved flags.  It sharpens
--- an outline and does little on its own, which is how Blizzard uses it too --
--- SystemFont_NamePlate_Outlined pairs slug with an outline
--- (Blizzard_Fonts_Shared/Shared/GameFonts.xml:317) -- so an outline turns it
--- on, styling.disableSlug turns it back off, and the saved table is never
--- written to.  A saved SLUG from an earlier build is ignored for the same
--- reason: the flag has no checkbox of its own any more.
--- @param frame? G_RLF.Frames
--- @return string
function G_RLF:FontFlagsToString(frame)
	frame = frame or G_RLF.Frames.MAIN
	local stylingDb = G_RLF.DbAccessor:Styling(frame)
	local flags = {}
	for key, enabled in pairs(stylingDb.fontFlags) do
		flags[key] = enabled
	end
	flags[G_RLF.FontFlags.SLUG] = nil

	local outlined = flags[G_RLF.FontFlags.OUTLINE] or flags[G_RLF.FontFlags.THICKOUTLINE]
	if outlined and G_RLF.supportsSlug and not stylingDb.disableSlug then
		flags[G_RLF.FontFlags.SLUG] = true
	end

	return self:TableToCommaSeparatedString(flags)
end

--- Apply a frame's custom-font styling to a FontString.
---
--- Shared by the row text elements and the queue ("Pending Items") label so
--- both pick up font flags and shadow settings from the same place.  Only the
--- custom-font path needs this; a FontString driven by SetFontObject carries
--- the object's own flags and shadow.
--- @param fontString FontString
--- @param fontPath string
--- @param fontSize number
--- @param fontFlagsString string
--- @param fontShadowColor number[]
--- @param fontShadowOffsetX? number
--- @param fontShadowOffsetY? number
function G_RLF:ApplyFontStyle(
	fontString,
	fontPath,
	fontSize,
	fontFlagsString,
	fontShadowColor,
	fontShadowOffsetX,
	fontShadowOffsetY
)
	fontString:SetFont(fontPath, fontSize, fontFlagsString)
	fontString:SetShadowColor(
		fontShadowColor[1] or 0,
		fontShadowColor[2] or 0,
		fontShadowColor[3] or 0,
		fontShadowColor[4] or 1
	)
	fontString:SetShadowOffset(fontShadowOffsetX or 1, fontShadowOffsetY or -1)
end

function G_RLF:GenerateGUID()
	local random = math.random
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	return string.gsub(template, "[xy]", function(c)
		local v = (c == "x") and random(0, 15) or random(8, 11)
		return string.format("%x", v)
	end)
end

function G_RLF:IsRLFStableRelease()
	--@alpha@
	if true then
		return false
	end
	--@end-alpha@
	--@beta@
	if true then
		return false
	end
	--@end-beta@
	return true
end

function G_RLF:ParseVersion(version)
	version = version or G_RLF.addonVersion
	local major, minor, patch = string.match(version, "v(%d+)%.(%d+)%.(%d+)")

	if major and minor and patch then
		return tonumber(major), tonumber(minor), tonumber(patch)
	else
		return nil, nil, nil
	end
end

function G_RLF:CompareWithVersion(myVersion, cmpVersion)
	local myVersion = myVersion
	local cmpVersion = cmpVersion
	local major1, minor1, patch1 = self:ParseVersion(cmpVersion)
	local major2, minor2, patch2 = self:ParseVersion(myVersion)

	if major1 and major2 then
		if major1 > major2 then
			return G_RLF.VersionCompare.NEWER
		elseif major1 < major2 then
			return G_RLF.VersionCompare.OLDER
		end

		if minor1 and minor2 then
			if minor1 > minor2 then
				return G_RLF.VersionCompare.NEWER
			elseif minor1 < minor2 then
				return G_RLF.VersionCompare.OLDER
			end

			if patch1 and patch2 then
				if patch1 > patch2 then
					return G_RLF.VersionCompare.NEWER
				elseif patch1 < patch2 then
					return G_RLF.VersionCompare.OLDER
				end
			end
		end
	end

	return G_RLF.VersionCompare.SAME -- Versions are equal or invalid
end

function G_RLF:ExtractItemLinks(message)
	local itemLinks = {}
	for itemLink in message:gmatch("|c.-|Hitem:.-|h%[.-%]|h|r") do
		table.insert(itemLinks, itemLink)
	end
	return itemLinks
end

function G_RLF:ExtractCurrencyLinks(message)
	local currencyLinks = {}
	for currencyLink in message:gmatch("|c.-|Hcurrency:.-|h%[.-%]|h|r") do
		table.insert(currencyLinks, currencyLink)
	end
	return currencyLinks
end

function G_RLF:ExtractCurrencyID(currencyLink)
	-- Currency links have the format: |cffffffff|Hcurrency:currencyID:amount|h[Name]|h|r
	local currencyID = currencyLink:match("|Hcurrency:(%d+):")
	return currencyID and tonumber(currencyID) or nil
end

---@param wrapChar G_RLF.WrapCharEnum
function G_RLF:GetWrapChars(wrapChar)
	local WrapChar = G_RLF.WrapCharEnum
	wrapChar = wrapChar or WrapChar.DEFAULT

	local sChar, eChar
	if wrapChar == WrapChar.SPACE then
		sChar, eChar = " ", " "
	elseif wrapChar == WrapChar.PARENTHESIS then
		sChar, eChar = "(", ")"
	elseif wrapChar == WrapChar.BRACKET then
		sChar, eChar = "[", "]"
	elseif wrapChar == WrapChar.BRACE then
		sChar, eChar = "{", "}"
	elseif wrapChar == WrapChar.ANGLE then
		sChar, eChar = "<", ">"
	elseif wrapChar == WrapChar.BAR then
		sChar, eChar = "|", "|"
	else
		sChar, eChar = "", ""
	end
	return sChar, eChar
end
