local busted = require("busted")
local stub = busted.stub
local spy = busted.spy

local wowGlobals = {}

--#region:bit
-- WoW Bitlib mock implementation
-- Pure Lua implementation of bitwise operations
local function bnot(a)
	return bit.bnot(a)
end

local function bxor(a1, ...)
	local result = a1
	for _, a in ipairs({ ... }) do
		result = bit.bxor(result, a)
	end
	return result
end

local function lshift(a, n)
	return a * (2 ^ n)
end

local function rshift(a, n)
	return math.floor(a / (2 ^ n))
end

local function arshift(a, n)
	return math.floor(a / (2 ^ n))
end

local function bmod(a, n)
	return a % n
end

-- Helper function to implement bitwise AND without bit32
local function bitwiseAnd(a, b)
	local result = 0
	local bitPos = 1
	while a > 0 or b > 0 do
		if (a % 2 == 1) and (b % 2 == 1) then
			result = result + bitPos
		end
		a = math.floor(a / 2)
		b = math.floor(b / 2)
		bitPos = bitPos * 2
	end
	return result
end

-- Helper function to implement bitwise OR without bit32
local function bitwiseOr(a, b)
	local result = 0
	local bitPos = 1
	while a > 0 or b > 0 do
		if (a % 2 == 1) or (b % 2 == 1) then
			result = result + bitPos
		end
		a = math.floor(a / 2)
		b = math.floor(b / 2)
		bitPos = bitPos * 2
	end
	return result
end

_G.bit = {
	bnot = bnot,
	band = function(a1, ...)
		local result = a1
		for _, a in ipairs({ ... }) do
			result = bitwiseAnd(result, a)
		end
		return result
	end,
	bor = function(a1, ...)
		local result = a1
		for _, a in ipairs({ ... }) do
			result = bitwiseOr(result, a)
		end
		return result
	end,
	bxor = bxor,
	lshift = lshift,
	rshift = rshift,
	arshift = arshift,
	mod = bmod,
}
--#endregion

--#region:BossBanner
---@diagnostic disable-next-line: missing-fields
_G.BossBanner = {}
wowGlobals.BossBanner = {}
wowGlobals.BossBanner.OnEvent = stub(_G.BossBanner, "OnEvent")
--#endregion

--#region:C_ChatInfo
_G.C_ChatInfo = {}
stub(_G.C_ChatInfo, "GetGeneralChannelID").returns(1)
--#endregion

--#region:C_CVar
_G.C_CVar = {}
stub(_G.C_CVar, "SetCVar")
--#endregion

--#region:EditModeManagerFrame
---@diagnostic disable-next-line: missing-fields
_G.EditModeManagerFrame = {}
stub(_G.EditModeManagerFrame, "IsInMode")
--#endregion

--#region:EventRegistry
---@diagnostic disable-next-line: missing-fields
_G.EventRegistry = {}
stub(_G.EventRegistry, "RegisterCallback")
stub(_G.EventRegistry, "SecureInsertEvent")
stub(_G.EventRegistry, "UnregisterEvents")
stub(_G.EventRegistry, "TriggerEvent")
stub(_G.EventRegistry, "HasRegistrantsForEvent", function()
	return false
end)
stub(_G.EventRegistry, "GetCallbackTable", function()
	return {}
end)
stub(_G.EventRegistry, "GetCallbackTables", function()
	return {}
end)
stub(_G.EventRegistry, "GetCallbacksByEvent", function()
	return {}
end)
stub(_G.EventRegistry, "SetUndefinedEventsAllowed")
stub(_G.EventRegistry, "DoesFrameHaveEvent", function()
	return false
end)
stub(_G.EventRegistry, "UnregisterCallback")
stub(_G.EventRegistry, "OnLoad")
stub(_G.EventRegistry, "RegisterCallbackWithHandle")
stub(_G.EventRegistry, "GenerateCallbackEvents")
--#endregion

--#region:LootAlertSystem
---@diagnostic disable-next-line: missing-fields
_G.LootAlertSystem = {}
wowGlobals.LootAlertSystem = {}
wowGlobals.LootAlertSystem.AddAlert = stub(_G.LootAlertSystem, "AddAlert")
--#endregion

--#region:MoneyWonAlertSystem
---@diagnostic disable-next-line: missing-fields
_G.MoneyWonAlertSystem = {}
wowGlobals.MoneyWonAlertSystem = {}
wowGlobals.MoneyWonAlertSystem.AddAlert = stub(_G.MoneyWonAlertSystem, "AddAlert")
--#endregion

--#region:UIParent
---@diagnostic disable-next-line: missing-fields
_G.UIParent = {
	firstTimeLoaded = 0,
	variablesLoaded = true,
}
stub(_G.UIParent, "CreateFontString", function()
	local fontString = {}
	stub(fontString, "SetFontObject")
	-- SetFont reports success in-game; the default stub returns nil, which
	-- reads as "this client does not report", so probes fail closed.
	stub(fontString, "SetFont")
	stub(fontString, "SetText")
	stub(fontString, "SetPoint")
	stub(fontString, "Hide")
	return fontString
end)
stub(_G.UIParent, "RotateTextures")
stub(_G.UIParent, "GetClampRectInsets")
stub(_G.UIParent, "EnableGamePadButton")
stub(_G.UIParent, "IsClampedToScreen")
stub(_G.UIParent, "IsResizable")
stub(_G.UIParent, "GetHyperlinksEnabled")
stub(_G.UIParent, "StartSizing")
stub(_G.UIParent, "SetUserPlaced")
stub(_G.UIParent, "SetIgnoreParentAlpha")
stub(_G.UIParent, "GetDontSavePosition")
stub(_G.UIParent, "HookScript")
stub(_G.UIParent, "IsEventRegistered")
stub(_G.UIParent, "GetFrameStrata")
stub(_G.UIParent, "Show")
stub(_G.UIParent, "StartMoving")
stub(_G.UIParent, "GetRegions")
stub(_G.UIParent, "GetEffectiveAlpha")
stub(_G.UIParent, "SetMovable")
stub(_G.UIParent, "GetRaisedFrameLevel")
stub(_G.UIParent, "SetHitRectInsets")
stub(_G.UIParent, "IsUserPlaced")
stub(_G.UIParent, "GetFrameLevel")
stub(_G.UIParent, "IsVisible")
stub(_G.UIParent, "EnableDrawLayer")
stub(_G.UIParent, "IsShown")
stub(_G.UIParent, "SetFlattensRenderLayers")
stub(_G.UIParent, "IsGamePadStickEnabled")
stub(_G.UIParent, "SetResizeBounds")
stub(_G.UIParent, "GetHitRectInsets")
stub(_G.UIParent, "GetEffectiveScale")
stub(_G.UIParent, "Hide")
stub(_G.UIParent, "HasFixedFrameStrata")
stub(_G.UIParent, "RegisterEvent")
stub(_G.UIParent, "IsToplevel")
stub(_G.UIParent, "GetEffectivelyFlattensRenderLayers")
stub(_G.UIParent, "IsObjectLoaded")
stub(_G.UIParent, "AbortDrag")
stub(_G.UIParent, "UnregisterAllEvents")
stub(_G.UIParent, "ExecuteAttribute")
stub(_G.UIParent, "GetNumChildren")
stub(_G.UIParent, "SetIgnoreParentScale")
stub(_G.UIParent, "SetScale")
stub(_G.UIParent, "IsIgnoringParentScale")
stub(_G.UIParent, "SetClampedToScreen")
stub(_G.UIParent, "GetScale")
stub(_G.UIParent, "StopMovingOrSizing")
stub(_G.UIParent, "SetIsFrameBuffer")
stub(_G.UIParent, "SetShown")
stub(_G.UIParent, "HasScript")
stub(_G.UIParent, "InterceptStartDrag")
stub(_G.UIParent, "UnregisterEvent")
stub(_G.UIParent, "CreateTexture")
stub(_G.UIParent, "SetAlpha")
stub(_G.UIParent, "GetParent")
stub(_G.UIParent, "SetToplevel")
stub(_G.UIParent, "GetScript")
stub(_G.UIParent, "IsGamePadButtonEnabled")
stub(_G.UIParent, "DoesClipChildren")
stub(_G.UIParent, "IsKeyboardEnabled")
stub(_G.UIParent, "DesaturateHierarchy")
stub(_G.UIParent, "SetResizable")
stub(_G.UIParent, "RegisterUnitEvent")
stub(_G.UIParent, "GetBoundsRect")
stub(_G.UIParent, "SetID")
stub(_G.UIParent, "EnableKeyboard")
stub(_G.UIParent, "SetHyperlinksEnabled")
stub(_G.UIParent, "Lower")
stub(_G.UIParent, "GetAlpha")
stub(_G.UIParent, "GetChildren")
stub(_G.UIParent, "SetScript")
stub(_G.UIParent, "SetClampRectInsets")
stub(_G.UIParent, "SetFixedFrameLevel")
stub(_G.UIParent, "CreateLine")
stub(_G.UIParent, "GetResizeBounds")
stub(_G.UIParent, "SetDrawLayerEnabled")
stub(_G.UIParent, "GetAttribute")
stub(_G.UIParent, "GetPropagateKeyboardInput")
stub(_G.UIParent, "DisableDrawLayer")
stub(_G.UIParent, "HasFixedFrameLevel")
stub(_G.UIParent, "UnlockHighlight")
stub(_G.UIParent, "IsMovable")
stub(_G.UIParent, "Raise")
stub(_G.UIParent, "GetNumRegions")
stub(_G.UIParent, "IsIgnoringParentAlpha")
stub(_G.UIParent, "EnableGamePadStick")
stub(_G.UIParent, "SetFrameStrata")
stub(_G.UIParent, "CanChangeAttribute")
stub(_G.UIParent, "SetFrameLevel")
stub(_G.UIParent, "SetPropagateKeyboardInput")
stub(_G.UIParent, "RegisterAllEvents")
stub(_G.UIParent, "SetAttributeNoHandler")
stub(_G.UIParent, "SetAttribute")
stub(_G.UIParent, "SetFixedFrameStrata")
stub(_G.UIParent, "SetClipsChildren")
stub(_G.UIParent, "SetDontSavePosition")
stub(_G.UIParent, "RegisterForDrag")
stub(_G.UIParent, "GetFlattensRenderLayers")
stub(_G.UIParent, "LockHighlight")
stub(_G.UIParent, "CreateMaskTexture")
stub(_G.UIParent, "GetID")
stub(_G.UIParent, "SetDrawLayer")
stub(_G.UIParent, "GetDrawLayer")
stub(_G.UIParent, "SetVertexColor")
stub(_G.UIParent, "GetVertexColor")
stub(_G.UIParent, "SetMouseMotionEnabled")
stub(_G.UIParent, "SetParent")
stub(_G.UIParent, "EnableMouse")
stub(_G.UIParent, "GetBottom")
stub(_G.UIParent, "GetRight")
stub(_G.UIParent, "SetPassThroughButtons")
stub(_G.UIParent, "IsProtected")
stub(_G.UIParent, "GetRect")
stub(_G.UIParent, "IsMouseEnabled")
stub(_G.UIParent, "CanChangeProtectedState")
stub(_G.UIParent, "GetHeight")
stub(_G.UIParent, "GetWidth")
stub(_G.UIParent, "IsAnchoringRestricted")
stub(_G.UIParent, "SetCollapsesLayout")
stub(_G.UIParent, "IsDragging")
stub(_G.UIParent, "SetMouseClickEnabled")
stub(_G.UIParent, "IsMouseMotionFocus")
stub(_G.UIParent, "AdjustPointsOffset")
stub(_G.UIParent, "IsMouseMotionEnabled")
stub(_G.UIParent, "IsRectValid")
stub(_G.UIParent, "GetCenter")
stub(_G.UIParent, "EnableMouseWheel")
stub(_G.UIParent, "CollapsesLayout")
stub(_G.UIParent, "IsMouseClickEnabled")
stub(_G.UIParent, "GetSourceLocation")
stub(_G.UIParent, "IsMouseWheelEnabled")
stub(_G.UIParent, "GetTop")
stub(_G.UIParent, "GetLeft")
stub(_G.UIParent, "GetScaledRect")
stub(_G.UIParent, "IsMouseOver")
stub(_G.UIParent, "EnableMouseMotion")
stub(_G.UIParent, "GetSize")
stub(_G.UIParent, "IsCollapsed")
stub(_G.UIParent, "GetParentKey")
stub(_G.UIParent, "GetDebugName")
stub(_G.UIParent, "SetParentKey")
stub(_G.UIParent, "ClearParentKey")
stub(_G.UIParent, "GetObjectType")
stub(_G.UIParent, "IsForbidden")
stub(_G.UIParent, "IsObjectType")
stub(_G.UIParent, "SetForbidden")
stub(_G.UIParent, "GetName")
stub(_G.UIParent, "SetWidth")
stub(_G.UIParent, "SetSize")
stub(_G.UIParent, "ClearAllPoints")
stub(_G.UIParent, "GetNumPoints")
stub(_G.UIParent, "SetAllPoints")
stub(_G.UIParent, "GetPointByName")
stub(_G.UIParent, "ClearPoint")
stub(_G.UIParent, "ClearPointsOffset")
stub(_G.UIParent, "SetPoint")
stub(_G.UIParent, "SetHeight")
stub(_G.UIParent, "GetPoint")
stub(_G.UIParent, "GetAnimationGroups")
stub(_G.UIParent, "CreateAnimationGroup")
stub(_G.UIParent, "StopAnimating")
--#endregion

--#region:ACCOUNT_WIDE_FONT_COLOR
---@diagnostic disable-next-line: missing-fields
_G.ACCOUNT_WIDE_FONT_COLOR = {
	r = 0,
	g = 0,
	b = 1,
}
stub(_G.ACCOUNT_WIDE_FONT_COLOR, "WrapTextInColorCode", function(text)
	return text
end)
stub(_G.ACCOUNT_WIDE_FONT_COLOR, "GetRGB", function(self)
	return self.r, self.g, self.b
end)
stub(_G.ACCOUNT_WIDE_FONT_COLOR, "IsEqualTo", function(self, other)
	return self.r == other.r and self.g == other.g and self.b == other.b
end)
stub(_G.ACCOUNT_WIDE_FONT_COLOR, "SetRGB", function(self, r, g, b)
	self.r, self.g, self.b = r, g, b
end)
stub(_G.ACCOUNT_WIDE_FONT_COLOR, "GetRGBA", function(self)
	return self.r, self.g, self.b, 1
end)
stub(_G.ACCOUNT_WIDE_FONT_COLOR, "GenerateHexColorMarkup", function(self)
	return string.format("|cff%02x%02x%02x", self.r * 255, self.g * 255, self.b * 255)
end)
stub(_G.ACCOUNT_WIDE_FONT_COLOR, "GenerateHexColor", function(self)
	return string.format("%02x%02x%02x", self.r * 255, self.g * 255, self.b * 255)
end)
stub(_G.ACCOUNT_WIDE_FONT_COLOR, "GetRGBAsBytes", function(self)
	return self.r * 255, self.g * 255, self.b * 255
end)
stub(_G.ACCOUNT_WIDE_FONT_COLOR, "SetRGBA", function(self, r, g, b, a)
	self.r, self.g, self.b, self.a = r, g, b, a or 1
end)
stub(_G.ACCOUNT_WIDE_FONT_COLOR, "GetRGBAAsBytes", function(self)
	return self.r * 255, self.g * 255, self.b * 255, (self.a or 1) * 255
end)
--#endregion

--#region:FACTION_GREEN_COLOR
---@diagnostic disable-next-line: missing-fields
_G.FACTION_GREEN_COLOR = {
	r = 0,
	g = 1,
	b = 0,
}
stub(_G.FACTION_GREEN_COLOR, "WrapTextInColorCode", function(text)
	return text
end)
stub(_G.FACTION_GREEN_COLOR, "GetRGB", function(self)
	return self.r, self.g, self.b
end)
stub(_G.FACTION_GREEN_COLOR, "IsEqualTo", function(self, other)
	return self.r == other.r and self.g == other.g and self.b == other.b
end)
stub(_G.FACTION_GREEN_COLOR, "SetRGB", function(self, r, g, b)
	self.r, self.g, self.b = r, g, b
end)
stub(_G.FACTION_GREEN_COLOR, "GetRGBA", function(self)
	return self.r, self.g, self.b, 1
end)
stub(_G.FACTION_GREEN_COLOR, "GenerateHexColorMarkup", function(self)
	return string.format("|cff%02x%02x%02x", self.r * 255, self.g * 255, self.b * 255)
end)
stub(_G.FACTION_GREEN_COLOR, "GenerateHexColor", function(self)
	return string.format("%02x%02x%02x", self.r * 255, self.g * 255, self.b * 255)
end)
stub(_G.FACTION_GREEN_COLOR, "GetRGBAsBytes", function(self)
	return self.r * 255, self.g * 255, self.b * 255
end)
stub(_G.FACTION_GREEN_COLOR, "SetRGBA", function(self, r, g, b, a)
	self.r, self.g, self.b, self.a = r, g, b, a or 1
end)
stub(_G.FACTION_GREEN_COLOR, "GetRGBAAsBytes", function(self)
	return self.r * 255, self.g * 255, self.b * 255, (self.a or 1) * 255
end)
--#endregion

--#region:FACTION_BAR_COLORS
_G.FACTION_BAR_COLORS = {
	[1] = { r = 1, g = 0, b = 0 },
	[8] = { r = 0, g = 1, b = 0 },
}
--#endregion

_G.GUILD = "Guild"

--#region:FACTION_STANDING* Global strings
_G.FACTION_STANDING_INCREASED = "Rep with %s inc by %d."
_G.FACTION_STANDING_INCREASED_ACCOUNT_WIDE = "AccRep with %s inc by %d."
_G.FACTION_STANDING_INCREASED_ACH_BONUS = "Rep with %s inc by %d (+.1f bonus)."
_G.FACTION_STANDING_INCREASED_ACH_BONUS_ACCOUNT_WIDE = "AccRep with %s inc by %d (+.1f bonus)."
_G.FACTION_STANDING_INCREASED_BONUS = "Rep with %s inc by %d (+.1f bonus)."
_G.FACTION_STANDING_INCREASED_DOUBLE_BONUS = "Rep with %s inc by %d (+.1f bonus)."
_G.FACTION_STANDING_DECREASED = "Rep with %s dec by %d."
_G.FACTION_STANDING_DECREASED_ACCOUNT_WIDE = "AccRep with %s dec by %d."
--#endregion

--#region:CURRENCY* Global strings
_G.CURRENCY_GAINED = "You receive currency: %s."
_G.CURRENCY_GAINED_MULTIPLE = "You receive currency: %s x%d."
_G.CURRENCY_GAINED_MULTIPLE_BONUS = "You receive currency: %s x%d. (Bonus Objective)"
--#endregion

--#region:Global consts
_G.LE_PARTY_CATEGORY_INSTANCE = 2
_G.MAX_WOW_CHAT_CHANNELS = 20
_G.MEMBERS_PER_RAID_GROUP = 5
_G.GENERAL = "General"
--#endregion

--#region:RAID_CLASS_COLORS
--- Minimal RAID_CLASS_COLORS used as fallback when expansion < BFA.
--- Only WARRIOR is populated to match the UnitClass stub default.
_G.RAID_CLASS_COLORS = {
	WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
}
--#endregion

--#region:CreateColor
--- Minimal ColorMixin-compatible table returned by CreateColor().
--- Tests primarily care that the return value is non-nil and can be passed
--- to stubbed rendering methods (e.g. SetGradient, SetBackdropBorderColor).
_G.CreateColor = function(r, g, b, a)
	return { r = r, g = g, b = b, a = a or 1 }
end
--#endregion

return wowGlobals
