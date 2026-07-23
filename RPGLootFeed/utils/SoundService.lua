---@type string, table
local addonName, ns = ...

---@class G_RLF
local G_RLF = ns

--- RLF SoundService — shared sound playback for all feature modules.
---
--- Encapsulates PlaySoundFile + logging so features don't repeat the
--- "willPlay check → LogWarn" pattern.  Registered in the DI container
--- so tests can inject a mock sound service.
---@class RLF_SoundService
G_RLF.SoundService = {}

--- Play a sound file and log failures.
---@param soundPath string  Path to the sound file (e.g. "Interface\\Sounds\\Custom.ogg")
---@return boolean true if the sound was queued successfully
function G_RLF.SoundService:PlaySound(soundPath)
	if not soundPath or soundPath == "" then
		return false
	end
	local willPlay, handle = PlaySoundFile(soundPath)
	if not willPlay then
		G_RLF:LogWarn("Failed to play sound " .. soundPath, addonName, "SoundService")
	end
	return willPlay
end

-- ── Self-register in DI container ─────────────────────────────────────────────
if G_RLF.DI then
	G_RLF.DI:Register("SoundService", G_RLF.SoundService)
end

return {}
