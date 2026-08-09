---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

local IconSkin = {}

--- Which skinners can be used right now.
---
--- Availability is deliberately not the same thing as applicability.  For
--- EllesmereUI in particular, "installed" and "usable" are different states:
--- the facade only arrives when EllesmereUI dispatches our RegisterSkin
--- callback at PLAYER_LOGIN, and it never arrives at all if the user turned
--- third-party skinning off in EllesmereUI's own options.  Call sites still
--- need to nil-check the handle they actually use.
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

--- Collapse a configured value into the skinner that should actually run.
--- Never returns AUTO.  A configured skinner that is no longer available
--- (its addon was disabled after the setting was saved) falls back to NONE
--- rather than silently jumping to a different skinner -- the saved
--- preference stays in the DB and takes effect again on re-enable.
---@param configured G_RLF.IconSkin?
---@return G_RLF.IconSkin
function IconSkin:Resolve(configured)
	local available = self:Available()

	if configured == nil or configured == G_RLF.IconSkin.AUTO then
		if available[G_RLF.IconSkin.MASQUE] then
			return G_RLF.IconSkin.MASQUE
		end
		if available[G_RLF.IconSkin.ELVUI] then
			return G_RLF.IconSkin.ELVUI
		end
		if available[G_RLF.IconSkin.ELLESMERE] then
			return G_RLF.IconSkin.ELLESMERE
		end
		return G_RLF.IconSkin.NONE
	end

	if not available[configured] then
		return G_RLF.IconSkin.NONE
	end

	return configured
end

G_RLF.IconSkinResolver = IconSkin

return IconSkin
