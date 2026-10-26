-- Background music (SoundConfig.Music), through the Music volume setting (AudioMix's Music
-- group), in three moods:
--   title    the menu theme, looping while the title menu is up (TitleMenu's gui, gone once
--            PLAY has faded in)
--   boss     the boss theme, looping while you're near a living raid boss (RaidConfig: within
--            its arena radius); it beats combat
--   combat   while you're fighting another player (CombatRules' PvP attribute on your
--            character, the same 30 s as the shops): the combat tracks in turn, back to back
--   explore  otherwise: the game tracks shuffled (never the same one twice in a row), each
--            fading in and out with a quiet stretch of `gap` seconds after it
-- A change of mood fades the playing track out (combat and boss cut in quickly, even mid-silence),
-- and leaving combat or the title is followed by a quiet stretch. A track that won't load
-- is skipped. One Sound in SoundService. While any menu but the title is open (Menus: the
-- hub, settings, a shop...) it's muffled: the highs cut and a little quieter.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local CombatRules = require(ReplicatedStorage:WaitForChild("CombatRules"))
local RaidConfig = require(ReplicatedStorage:WaitForChild("RaidConfig"))
local SoundConfig = require(ReplicatedStorage:WaitForChild("SoundConfig"))
local AudioMix = require(script.Parent:WaitForChild("AudioMix"))
local Menus = require(script.Parent:WaitForChild("Menus"))

local MUSIC = SoundConfig.Music
local LOAD_TIMEOUT = 10 -- seconds to wait for a track before skipping it
local TITLE_WAIT = 10 -- seconds to wait for the title menu to show up on join
local CHECK = 0.25 -- seconds between looks at the mood
local UNMUFFLED_MENUS = { Title = true } -- the menus the music stays clear in
local MUFFLE = { HighGain = -30, MidGain = -12, LowGain = -2 } -- dB while muffled
local MUFFLE_TIME = 0.35

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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

local title = playerGui:WaitForChild("TitleMenu", TITLE_WAIT)

-- near a living raid boss
local function nearBoss()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, model in ipairs(CollectionService:GetTagged(RaidConfig.Tag)) do
		local boss = RaidConfig.Get(model:GetAttribute("BossKey"))
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local bossRoot = humanoid and humanoid.RootPart
		if boss and bossRoot and humanoid.Health > 0 and (bossRoot.Position - root.Position).Magnitude <= boss.arenaRadius then
			return true
		end
	end
	return false
end

-- combat and the boss cut in, rather than waiting out a quiet stretch
local URGENT = { combat = true, boss = true }

local function mood()
	if title and title.Parent then
		return "title"
	end
	if nearBoss() then
		return "boss"
	end
	local character = player.Character
	local at = character and character:GetAttribute(CombatRules.PvPAttribute)
	if not CombatRules.OutOfCombat(at, workspace:GetServerTimeNow()) then
		return "combat"
	end
	return "explore"
end

local function fade(to, seconds)
	local tween = TweenService:Create(sound, TweenInfo.new(seconds or MUSIC.fade), { Volume = to })
	tween:Play()
	tween.Completed:Wait()
end

-- loads `track` into the Sound; false (with a warning) if it won't load
local function load(track)
	sound.SoundId = "rbxassetid://" .. track.id
	local waited = 0
	while not sound.IsLoaded and waited < LOAD_TIMEOUT do
		waited += task.wait(CHECK)
	end
	if not sound.IsLoaded or sound.TimeLength <= 0 then
		warn("[Music] couldn't load " .. track.name .. " (" .. track.id .. "), skipping")
		return false
	end
	return true
end

-- plays `track` (looping, if `looped`) while the mood stays `want`; fades it out at its end
-- or when the mood changes (quickly into combat or the boss)
local function play(track, want, looped)
	if not load(track) then
		return
	end
	sound.Looped = looped == true
	sound.Volume = 0
	sound.TimePosition = 0
	sound:Play()
	fade(MUSIC.volume)
	local endAt = os.clock() + sound.TimeLength - 2 * MUSIC.fade
	while mood() == want and (looped or os.clock() < endAt) do
		task.wait(CHECK)
	end
	fade(0, URGENT[mood()] and MUSIC.combatFade or MUSIC.fade)
	sound:Stop()
	sound.Looped = false
end

-- a quiet stretch, cut short if combat or a boss starts
local function silence()
	local untilAt = os.clock() + math.random(MUSIC.gap[1], MUSIC.gap[2])
	while os.clock() < untilAt and not URGENT[mood()] do
		task.wait(CHECK)
	end
end

-- the explore tracks in a new random order, not starting with `last`
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

local queue, nextInQueue, lastExplore = {}, 1, nil
local combatTurn = 0
while true do
	local now = mood()
	if now == "title" then
		play(MUSIC.menuTheme, "title", true)
		silence()
	elseif now == "boss" then
		play(MUSIC.bossTheme, "boss", true)
		if not URGENT[mood()] then
			silence()
		end
	elseif now == "combat" then
		combatTurn = combatTurn % #MUSIC.combat + 1
		play(MUSIC.combat[combatTurn], "combat")
		if not URGENT[mood()] then
			silence()
		end
	else
		if nextInQueue > #queue then
			queue, nextInQueue = shuffled(lastExplore), 1
		end
		lastExplore = queue[nextInQueue]
		nextInQueue += 1
		play(lastExplore, "explore")
		silence()
	end
end
