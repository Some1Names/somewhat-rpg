-- Background music: the tracks in SoundConfig.Music, shuffled, one after another (never the
-- same one twice in a row), through the Music volume setting (AudioMix's Music group). Each
-- fades in and out, with a short quiet between them. A track that won't load is skipped.
-- One Sound in SoundService, so it plays everywhere, the title menu too. While any other
-- menu is open (Menus: the hub, settings, a shop...) it's muffled: the highs cut and a
-- little quieter, as if from the next room.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundConfig = require(ReplicatedStorage:WaitForChild("SoundConfig"))
local AudioMix = require(script.Parent:WaitForChild("AudioMix"))
local Menus = require(script.Parent:WaitForChild("Menus"))

local MUSIC = SoundConfig.Music
local LOAD_TIMEOUT = 10 -- seconds to wait for a track before skipping it
local UNMUFFLED_MENUS = { Title = true } -- the menus the music stays clear in
local MUFFLE = { HighGain = -30, MidGain = -12, LowGain = -2 } -- dB while muffled
local MUFFLE_TIME = 0.35

local sound = Instance.new("Sound")
sound.Name = "Music"
sound.Volume = 0
sound.SoundGroup = AudioMix.Group("Music")
sound.Parent = SoundService
local muffler = Instance.new("EqualizerSoundEffect")
muffler.HighGain, muffler.MidGain, muffler.LowGain = 0, 0, 0
muffler.Parent = sound

Menus.OnChange(function(openName)
	local muffled = openName ~= nil and not UNMUFFLED_MENUS[openName]
	TweenService:Create(muffler, TweenInfo.new(MUFFLE_TIME), {
		HighGain = muffled and MUFFLE.HighGain or 0,
		MidGain = muffled and MUFFLE.MidGain or 0,
		LowGain = muffled and MUFFLE.LowGain or 0,
	}):Play()
end)

local function fade(to)
	local tween = TweenService:Create(sound, TweenInfo.new(MUSIC.fade), { Volume = to })
	tween:Play()
	tween.Completed:Wait()
end

-- the tracks in a new random order, not starting with `last`
local function shuffled(last)
	local order = table.clone(MUSIC.tracks)
	for i = #order, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end
	if #order > 1 and order[1] == last then
		order[1], order[#order] = order[#order], order[1]
	end
	return order
end

local function play(track)
	sound.SoundId = "rbxassetid://" .. track.id
	local waited = 0
	while not sound.IsLoaded and waited < LOAD_TIMEOUT do
		waited += task.wait(0.25)
	end
	if not sound.IsLoaded or sound.TimeLength <= 0 then
		warn("[Music] couldn't load " .. track.name .. " (" .. track.id .. "), skipping")
		return
	end
	sound.Volume = 0
	sound.TimePosition = 0
	sound:Play()
	fade(MUSIC.volume)
	task.wait(math.max(0, sound.TimeLength - 2 * MUSIC.fade))
	fade(0)
	sound:Stop()
	task.wait(MUSIC.gap)
end

local last
while true do
	for _, track in ipairs(shuffled(last)) do
		play(track)
		last = track
	end
end
