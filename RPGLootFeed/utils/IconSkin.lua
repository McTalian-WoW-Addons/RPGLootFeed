---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local IconSkin = {}

--- Which skinners the user may choose.
---
--- Availability is deliberately not the same thing as applicability.  This
--- answers "is the addon installed", which is what the dropdown and
--- SetIconSkin need; whether the skinner can actually do anything right now is
--- IconSkin:IsApplicable's question.  For EllesmereUI the two genuinely
--- differ: the facade only arrives when EllesmereUI dispatches our RegisterSkin
--- callback at PLAYER_LOGIN, and never arrives at all if the user turned
--- third-party skinning off in EllesmereUI's own options.  Keeping EllesmereUI
--- selectable in that state matters -- the user can flip its option back on
--- without having to remember to come back here afterwards.
---@return table<G_RLF.IconSkin, boolean>
function IconSkin:Available()
	return {
		[G_RLF.IconSkin.AUTO] = true,
		[G_RLF.IconSkin.NONE] = true,
		[G_RLF.IconSkin.SQUARE] = true,
		[G_RLF.IconSkin.MASQUE] = G_RLF.Masque ~= nil and G_RLF.iconGroup ~= nil,
		[G_RLF.IconSkin.ELVUI] = G_RLF.ElvSkins ~= nil,
		[G_RLF.IconSkin.ELLESMERE] = G_RLF.EllesmereUI ~= nil,
	}
end

--- Whether a skinner would actually change anything if it ran now.
---
--- Only EllesmereUI can be installed-but-inert; every other skinner is usable
--- the moment its handle exists.
---@param skin G_RLF.IconSkin
---@return boolean
function IconSkin:IsApplicable(skin)
	if skin == G_RLF.IconSkin.ELLESMERE then
		return G_RLF.EUISkin ~= nil
	end
	return self:Available()[skin] == true
end

--- Collapse a configured value into the skinner that should actually run.
--- Never returns AUTO.  A configured skinner that is no longer available
--- (its addon was disabled after the setting was saved) falls back to NONE
--- rather than silently jumping to a different skinner -- the saved
--- preference stays in the DB and takes effect again on re-enable.
---
--- EllesmereUI is the one exception.  When it is installed but its third-party
--- skinning is off, falling back to NONE would leave the user with round icons
--- and no clue why, so SQUARE stands in: it applies the identical texcoord crop
--- EllesmereUI's own SquareIcon would have.  That only holds while EllesmereUI
--- is actually loaded -- uninstalled still degrades to NONE like the rest.
---@param configured G_RLF.IconSkin?
---@return G_RLF.IconSkin
function IconSkin:Resolve(configured)
	local available = self:Available()

	--- Where ELLESMERE lands when the facade never arrived.
	local function ellesmereFallback()
		if available[G_RLF.IconSkin.ELLESMERE] then
			return G_RLF.IconSkin.SQUARE
		end
		return G_RLF.IconSkin.NONE
	end

	if configured == nil or configured == G_RLF.IconSkin.AUTO then
		if available[G_RLF.IconSkin.MASQUE] then
			return G_RLF.IconSkin.MASQUE
		end
		if available[G_RLF.IconSkin.ELVUI] then
			return G_RLF.IconSkin.ELVUI
		end
		if self:IsApplicable(G_RLF.IconSkin.ELLESMERE) then
			return G_RLF.IconSkin.ELLESMERE
		end
		return ellesmereFallback()
	end

	if configured == G_RLF.IconSkin.ELLESMERE and not self:IsApplicable(G_RLF.IconSkin.ELLESMERE) then
		return ellesmereFallback()
	end

	if not available[configured] then
		return G_RLF.IconSkin.NONE
	end

	return configured
end

G_RLF.IconSkinResolver = IconSkin

return IconSkin
