---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class ClassicToRetail
---@field ConvertFactionInfoByID fun(s: ClassicToRetail, id: number): table | nil
---@field ConvertFactionInfoByIndex fun(s: ClassicToRetail, index: number): table | nil
---@field InstallItemButtonFallbacks fun(s: ClassicToRetail)
G_RLF.ClassicToRetail = {}

---Convert faction info from Classic to Retail format
---@param t table
---@return table | nil
local function convertFactionInfo(t)
	if not t[1] then
		return nil
	end
	return {
		name = t[1],
		description = t[2],
		reaction = t[3],
		currentReactionThreshold = t[4],
		nextReactionThreshold = t[5],
		currentStanding = t[6],
		atWarWith = t[7],
		canToggleAtWar = t[8],
		isHeader = t[9],
		isCollapsed = t[10],
		isHeaderWithRep = t[11],
		isWatched = t[12],
		isChild = t[13],
		factionID = t[14],
		canSetInactive = false,
		hasBonusRepGain = false,
		isAccountWide = false,
	}
end

function G_RLF.ClassicToRetail:ConvertFactionInfoByID(id)
	local legacyFactionData = { GetFactionInfoByID(id) }
	return convertFactionInfo(legacyFactionData)
end

function G_RLF.ClassicToRetail:ConvertFactionInfoByIndex(index)
	local legacyFactionData = { GetFactionInfo(index) }
	return convertFactionInfo(legacyFactionData)
end

--- Define ItemButtonMixin:SetItemButtonTexture/SetItemButtonQuality only where
--- the client lacks them (Classic flavors through MoP Classic). Existing
--- implementations are never replaced: ItemButtonMixin is shared with every
--- addon's item buttons (e.g. Baganator), so overriding it globally breaks
--- their quality borders.
function G_RLF.ClassicToRetail:InstallItemButtonFallbacks()
	if not ItemButtonMixin then
		return
	end

	if not ItemButtonMixin.SetItemButtonTexture then
		ItemButtonMixin.SetItemButtonTexture = function(button, texture)
			button.icon:SetTexture(texture)
		end
	end

	if not ItemButtonMixin.SetItemButtonQuality then
		ItemButtonMixin.SetItemButtonQuality = function(button, quality, itemIDOrLink)
			if quality and button.IconBorder then
				local r, g, b = C_Item.GetItemQualityColor(quality)
				button.IconBorder:SetVertexColor(r, g, b)
			end
		end
	end
end

-- So far up through MoP Classic, ClearItemButtonOverlay is not defined (but is called by Blizzard code)
if not ClearItemButtonOverlay then
	function ClearItemButtonOverlay(button)
		-- Dummy function to avoid errors
	end
end

return G_RLF.ClassicToRetail
