-- Plain (not 3D) sounds for the interface and the feel of the game: menu
-- clicks, equipping, picking things up. The clips are SoundConfig.UI;
-- UiSfx.Play(key) plays one. Each clip is built once when the game starts and
-- loaded ahead (PreloadAsync on the Sound itself), and a play is a copy of that
-- loaded Sound, so it starts the moment it is asked for instead of fetching the
-- clip first. A clip that fails to load plays nothing and costs nothing.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundConfig = require(ReplicatedStorage:WaitForChild("SoundConfig"))

local UiSfx = {}

-- key -> a loaded Sound that is only ever copied, never played itself
local templates = {}
for key, entry in pairs(SoundConfig.UI) do
	local sound = Instance.new("Sound")
	sound.Name = "UiSfx_" .. key
	sound.SoundId = "rbxassetid://" .. entry.id
	sound.Volume = entry.volume * SoundConfig.MasterVolume
	sound.Parent = SoundService
	templates[key] = sound
end

function UiSfx.Play(key)
	local template = templates[key]
	if not template then
		return nil
	end
	local sound = template:Clone()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound.Parent = SoundService
	sound:Play()
	return sound
end

task.spawn(function()
	ContentProvider:PreloadAsync(SoundService:GetChildren())
end)

return UiSfx
