---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

---@class RLF_RowTooltipMixin
RLF_RowTooltipMixin = {}

function RLF_RowTooltipMixin:SetupTooltip(isHistoryFrame)
	if not self.link then
		return
	end
	-- ClickableButton geometry (anchor + size) is set by LayoutPrimaryLine(),
	-- which is called from ShowText() / ShowItemCountText() before SetupTooltip()
	-- runs in the row lifecycle.  Only Show() is needed here.
	self.ClickableButton:Show()
	-- Add Tooltip
	-- Tooltip logic
	local function showTooltip()
		---@type RLF_ConfigTooltips
		local tooltipDb = G_RLF.db.global.tooltips
		if not tooltipDb.hover.enabled then
			return
		end
		if tooltipDb.hover.onShift and not IsShiftKeyDown() then
			return
		end

		if
			LinkUtil
			and not LinkUtil.IsLinkType(self.link, "item")
			and not LinkUtil.IsLinkType(self.link, "currency")
		then
			-- Transmog links don't provide useful hover tooltips
			return
		end
		GameTooltip:SetOwner(self.ClickableButton, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(self.link) -- Use the item's link to show the tooltip
		GameTooltip:Show()
	end

	local function hideTooltip()
		GameTooltip:Hide()
	end

	-- OnEnter: Show tooltip or listen for Shift changes
	self.ClickableButton:SetScript("OnEnter", function()
		if not isHistoryFrame then
			self.ExitAnimation:Stop()
			self:StopTimerBar()
			self.HighlightAnimation:Stop()
			self:ResetHighlightBorder()
			-- Propagate pin to row (ClickableButton sits on top and intercepts OnEnter)
			local frame = self:GetParent()
			if frame then
				self:PinPosition(frame)
			end
		end
		showTooltip()

		-- Start listening for Shift key changes
		self.ClickableButton:RegisterEvent("MODIFIER_STATE_CHANGED")
	end)

	-- OnLeave: Hide tooltip and stop listening for Shift changes
	self.ClickableButton:SetScript("OnLeave", function()
		if not isHistoryFrame then
			-- Only restart exit animation and release pin if mouse has truly left
			-- the row, not merely moved from button to another part of the row.
			if not self:IsMouseOver() then
				-- Release pin first so isPinned is false before the exit animation
				-- resumes. Prevents ExitAnimation:Play() from firing while pinned.
				local frame = self:GetParent()
				if frame then
					frame:ReleasePin(self)
				end
				self.ExitAnimation:Play()
			end
		end
		hideTooltip()

		-- Stop listening for Shift key changes
		self.ClickableButton:UnregisterEvent("MODIFIER_STATE_CHANGED")
	end)

	-- Handle Shift key changes
	self.ClickableButton:SetScript("OnEvent", function(_, event, key, state)
		---@type RLF_ConfigTooltips
		local tooltipDb = G_RLF.db.global.tooltips
		if not tooltipDb.hover.onShift then
			return
		end

		if event == "MODIFIER_STATE_CHANGED" and (key == "LSHIFT" or key == "RSHIFT") then
			if state == 1 then
				showTooltip()
			else
				hideTooltip()
			end
		end
	end)

	local function handleClick(button)
		if button == "LeftButton" and not IsModifiedClick() then
			if not self.link then
				return
			end

			-- Check for custom behavior first
			if self.isCustomLink and self.customBehavior and type(self.customBehavior) == "function" then
				self.customBehavior()
				return
			end

			local s = self.link:find("transmogappearance:")
			if s then
				-- All this to check if the link is a transmog appearance link
				-- and get the ID to open the Transmog Collection
				-- If we just store the ID as well as the link, we can skip this
				local taS = self.link:find("transmogappearance:")
				if not taS then
					return
				end
				local shortened = self.link:sub(taS)
				local barS = shortened:find("|")
				if not barS then
					barS = #shortened + 1
				end
				shortened = shortened:sub(1, barS - 1)
				local _, id = strsplit(":", shortened)
				if id and TransmogUtil then
					TransmogUtil.OpenCollectionToItem(tonumber(id))
				end
			elseif self.link then
				-- Open the ItemRefTooltip to mimic in-game chat behavior
				SetItemRef(self.link, self.link, button, self.ClickableButton)
			end
		elseif button == "LeftButton" and IsControlKeyDown() then
			DressUpItemLink(self.link)
		elseif button == "LeftButton" and IsShiftKeyDown() then
			-- Custom behavior for right click, if needed
			if ChatEdit_GetActiveWindow() then
				ChatEdit_InsertLink(self.link)
			else
				ChatFrame_OpenChat(self.link)
			end
		elseif button == "RightButton" and not self.isHistoryMode then
			-- Stop any ongoing animation
			if self.ExitAnimation:IsPlaying() then
				self.ExitAnimation:Stop()
			end

			-- Remove the delay for immediate fade-out
			if self.ExitAnimation.noop then
				self.ExitAnimation.noop:SetStartDelay(0)
			elseif self.ExitAnimation.fadeOut then
				self.ExitAnimation.fadeOut:SetStartDelay(0)
			end
			self.bustCacheExitAnimation = true

			-- Start the fade-out animation
			self.ExitAnimation:Play()
		end
	end

	-- Add Click Handling for ItemRefTooltip
	self.ClickableButton:SetScript("OnMouseUp", function(_, button)
		handleClick(button)
	end)

	if self.Icon then
		self.Icon:SetScript("OnEnter", function()
			if not isHistoryFrame then
				self.ExitAnimation:Stop()
				self:StopTimerBar()
				self.HighlightAnimation:Stop()
				self:ResetHighlightBorder()
				-- Propagate pin to row
				local frame = self:GetParent()
				if frame then
					self:PinPosition(frame)
				end
			end
			showTooltip()
			self.Icon:RegisterEvent("MODIFIER_STATE_CHANGED")
		end)
		self.Icon:SetScript("OnLeave", function()
			if not isHistoryFrame then
				-- Only restart exit animation and release pin if mouse has truly left
				-- the row, not merely moved from icon to another part of the row.
				if not self:IsMouseOver() then
					-- Release pin first so isPinned is false before the exit animation
					-- resumes. Prevents ExitAnimation:Play() from firing while pinned.
					local frame = self:GetParent()
					if frame then
						frame:ReleasePin(self)
					end
					self.ExitAnimation:Play()
					self:StartTimerBar()
				end
			end
			hideTooltip()
			self.Icon:UnregisterEvent("MODIFIER_STATE_CHANGED")
		end)
		self.Icon:SetScript("OnEvent", function(_, event, key, state)
			if event == "MODIFIER_STATE_CHANGED" and (key == "LSHIFT" or key == "RSHIFT") then
				if state == 1 then
					showTooltip()
				else
					hideTooltip()
				end
			end
		end)
		self.Icon:SetScript("OnMouseUp", function(_, button)
			handleClick(button)
		end)
	end
end

G_RLF.RLF_RowTooltipMixin = RLF_RowTooltipMixin
