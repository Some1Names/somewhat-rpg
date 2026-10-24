-- The game's volume settings (Preferences' SOUND section) as SoundGroups in SoundService:
-- Master, and inside it Effects (SkillEffects' Sfx: hits, swings, shots, powers, heard in
-- the world), Interface (UiSfx: menus, equipping, pickups, crits) and Music (Music). A sound plays through
-- one by setting its SoundGroup to AudioMix.Group(name). Sounds that aren't ours (a
-- prefab's own sounds, Roblox's footsteps) don't go through them. Sample(name) plays a
-- short clip through a group, for the Settings preview.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))
local SoundConfig = require(ReplicatedStorage:WaitForChild("SoundConfig"))

local AudioMix = {}

-- group -> its volume setting
local SETTINGS = { Master = "VolMaster", Effects = "VolFx", Interface = "VolUi", Music = "VolMusic" }
-- the clip each group's sample plays (SoundConfig ids)
local SAMPLES = {
	Master = SoundConfig.UI.itemSelect.id,
	Effects = SoundConfig.Sounds.punchHit.ids[1],
	Interface = SoundConfig.UI.menuSelect.id,
}

local groups = {}
local function group(name, parent)
	local soundGroup = SoundService:FindFirstChild("Mix_" .. name) or Instance.new("SoundGroup")
	soundGroup.Name = "Mix_" .. name
	soundGroup.Parent = parent
	groups[name] = soundGroup
	return soundGroup
end
local master = group("Master", SoundService)
group("Effects", master)
group("Interface", master)
group("Music", master)

local function apply()
	for name, id in pairs(SETTINGS) do
		groups[name].Volume = Preferences.Get(id) / 100
	end
end
Preferences.Changed(apply)
apply()

function AudioMix.Group(name)
	return groups[name]
end

-- a short clip through `name`'s group, as loud as the game would play it
function AudioMix.Sample(name)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. SAMPLES[name]
	sound.Volume = 0.6 * SoundConfig.MasterVolume
	sound.SoundGroup = groups[name]
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

return AudioMix
