-- Background ambience (SoundConfig.Ambience) under the music: city sounds, or nature
-- sounds in the ZoneConfig zones marked `ambience = "nature"` (the Upper Shrine and the
-- Training Grounds), by where the camera is (so the title menu's drift has it
-- too). A kind's tracks play in turn, back to back; walking into the other kind of area
-- cross-fades to it. Through its own volume setting, Ambience (AudioMix).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local HudRules = require(ReplicatedStorage:WaitForChild("HudRules"))
local SoundConfig = require(ReplicatedStorage:WaitForChild("SoundConfig"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local AudioMix = require(script.Parent:WaitForChild("AudioMix"))

local AMBIENCE = SoundConfig.Ambience
local DEFAULT = "city"
local CHECK = 0.5 -- seconds between looks at the area

local function newSound(name)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.Volume = 0
	sound.SoundGroup = AudioMix.Group("Ambience")
	sound.Parent = SoundService
	return sound
end
-- two, so one area's sound fades out while the next fades in
local sounds = { newSound("AmbienceA"), newSound("AmbienceB") }
local current = 0 -- index in `sounds` of the one playing, 0 before the first
local kind = nil -- the kind playing
local turn = {} -- kind -> index of its last track

local function fadeTo(sound, volume)
	TweenService:Create(sound, TweenInfo.new(AMBIENCE.fade), { Volume = volume }):Play()
end

-- the next track of `wanted` on the other Sound, cross-faded in
local function start(wanted)
	local tracks = AMBIENCE[wanted]
	turn[wanted] = (turn[wanted] or 0) % #tracks + 1
	local old = sounds[current]
	current = current % 2 + 1
	local sound = sounds[current]
	sound.SoundId = "rbxassetid://" .. tracks[turn[wanted]].id
	sound.Looped = #tracks == 1
	sound.TimePosition = 0
	sound:Play()
	fadeTo(sound, AMBIENCE.volume)
	if old then
		fadeTo(old, 0)
		task.delay(AMBIENCE.fade, function()
			if sounds[current] ~= old then
				old:Stop()
			end
		end)
	end
	kind = wanted
end

-- a kind with more than one track moves on when its track ends
for _, sound in ipairs(sounds) do
	sound.Ended:Connect(function()
		if sounds[current] == sound and kind then
			start(kind)
		end
	end)
end

while true do
	local camera = workspace.CurrentCamera
	if camera then
		-- the camera itself: Focus stays put while a script drives the camera
		local at = camera.CFrame.Position
		local wanted = HudRules.AmbienceAt(ZoneConfig.Zones, at.X, at.Z, DEFAULT)
		if wanted ~= kind and AMBIENCE[wanted] then
			start(wanted)
		end
	end
	task.wait(CHECK)
end
