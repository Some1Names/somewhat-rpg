-- Plays the sound effects in ReplicatedStorage.SoundConfig, 3D, where an effect
-- happens. SkillEffects hands every event it draws to Sfx.ForEffect, which
-- looks the kind up in SoundConfig.Effects and finds a place in the event's
-- arguments (the first position, character, model or part). Sfx.Attach loops
-- a clip on a model for as long as it lasts (the tornado's wind, the black
-- hole's hum). A clip that fails to load plays nothing and costs nothing; all
-- of them are preloaded when the game starts.
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage:WaitForChild("SoundConfig"))

local DEFAULT_VOLUME = 0.6
local DEFAULT_PITCH = { 0.95, 1.05 }
local DEFAULT_RANGE = 120
local MIN_DISTANCE = 12 -- studs it is at full volume within
local TAIL = 1 -- seconds a finished sound is kept before it is cleared

local Sfx = {}

local random = Random.new()

-- the first place an event's arguments name: a position, or where a model or part stands
local function positionIn(...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		local kind = typeof(value)
		if kind == "Vector3" then
			return value
		elseif kind == "CFrame" then
			return value.Position
		elseif kind == "Instance" then
			if value:IsA("BasePart") then
				return value.Position
			elseif value:IsA("Model") then
				return value:GetPivot().Position
			end
		end
	end
	return nil
end

local function build(key)
	local entry = SoundConfig.Sounds[key]
	if not entry then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. SoundConfig.PickId(entry, function(low, high)
		return random:NextInteger(low, high)
	end)
	sound.Volume = entry.volume or DEFAULT_VOLUME
	local pitch = entry.pitch or DEFAULT_PITCH
	sound.PlaybackSpeed = pitch[1] + random:NextNumber() * (pitch[2] - pitch[1])
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = MIN_DISTANCE
	sound.RollOffMaxDistance = entry.range or DEFAULT_RANGE
	sound.Looped = entry.loop == true
	return sound
end

-- plays clip `key` at `position` once
function Sfx.Play(key, position)
	local sound = build(key)
	if not sound then
		return nil
	end
	local holder = Instance.new("Part")
	holder.Name = "SfxHolder"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.1
	holder.Position = position
	sound.Parent = holder
	holder.Parent = workspace
	sound.Ended:Once(function()
		holder:Destroy()
	end)
	-- (a clip that never loads is cleared too)
	Debris:AddItem(holder, math.max(sound.TimeLength, 6) + TAIL)
	sound:Play()
	return sound
end

-- the event `kind` just happened with these arguments
function Sfx.ForEffect(kind, ...)
	local key = SoundConfig.KeyFor(kind, ...)
	if not key then
		return
	end
	local position = positionIn(...)
	if position then
		Sfx.Play(key, position)
	end
end

-- plays clip `key` on `model` (looping if the clip loops) until the model is gone
function Sfx.Attach(model, key)
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local sound = part and build(key)
	if not sound then
		return nil
	end
	sound.Parent = part
	sound:Play()
	return sound
end

-- the clip a model's ClientEffect attribute loops, if it has one
function Sfx.AttachFor(model)
	local key = SoundConfig.ModelLoops[model:GetAttribute("ClientEffect") or ""]
	if key then
		return Sfx.Attach(model, key)
	end
	return nil
end

-- every clip is fetched at startup, so the first hit of a fight is not silent
task.spawn(function()
	local assets = {}
	for _, entry in pairs(SoundConfig.Sounds) do
		for _, id in ipairs(entry.ids or { entry.id }) do
			table.insert(assets, "rbxassetid://" .. id)
		end
	end
	ContentProvider:PreloadAsync(assets)
end)

return Sfx
