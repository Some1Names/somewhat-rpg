-- Background music (SoundConfig.Music), through the Music volume setting (AudioMix's Music
-- group). The menu theme loops while the title menu is up (TitleMenu's gui, gone once PLAY
-- has faded in); then, after a quiet stretch, the game tracks play shuffled, one after
-- another (never the same one twice in a row), each fading in and out with a quiet stretch
-- of `gap` seconds between them. A track that won't load is skipped. One Sound in
-- SoundService. While any menu but the title is open (Menus: the hub, settings, a shop...)
-- it's muffled: the highs cut and a little quieter, as if from the next room.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundConfig = require(ReplicatedStorage:WaitForChild("SoundConfig"))
local AudioMix = require(script.Parent:WaitForChild("AudioMix"))
local Menus = require(script.Parent:WaitForChild("Menus"))

local MUSIC = SoundConfig.Music
local LOAD_TIMEOUT = 10 -- seconds to wait for a track before skipping it
local TITLE_WAIT = 10 -- seconds to wait for the title menu to show up on join
local UNMUFFLED_MENUS = { Title = true } -- the menus the music stays clear in
local MUFFLE = { HighGain = -30, MidGain = -12, LowGain = -2 } -- dB while muffled
local MUFFLE_TIME = 0.35

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

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

-- loads `track` into the Sound; false (with a warning) if it won't load
local function load(track)
	sound.SoundId = "rbxassetid://" .. track.id
	local waited = 0
	while not sound.IsLoaded and waited < LOAD_TIMEOUT do
		waited += task.wait(0.25)
	end
	if not sound.IsLoaded or sound.TimeLength <= 0 then
		warn("[Music] couldn't load " .. track.name .. " (" .. track.id .. "), skipping")
		return false
	end
	return true
end

local function silence()
	task.wait(math.random(MUSIC.gap[1], MUSIC.gap[2]))
end

-- the menu theme, looping for as long as the title menu is up
local title = playerGui:WaitForChild("TitleMenu", TITLE_WAIT)
if title and title.Parent and load(MUSIC.menuTheme) then
	sound.Looped = true
	sound.TimePosition = 0
	sound:Play()
	fade(MUSIC.volume)
	while title.Parent do
		task.wait(0.25)
	end
	fade(0)
	sound:Stop()
	sound.Looped = false
	silence()
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
	if not load(track) then
		return
	end
	sound.Volume = 0
	sound.TimePosition = 0
	sound:Play()
	fade(MUSIC.volume)
	task.wait(math.max(0, sound.TimeLength - 2 * MUSIC.fade))
	fade(0)
	sound:Stop()
	silence()
end

local last
while true do
	for _, track in ipairs(shuffled(last)) do
		play(track)
		last = track
	end
end
