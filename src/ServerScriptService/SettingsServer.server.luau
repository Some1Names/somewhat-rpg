-- Server side of the Settings menu: a player's own keybinds (Keybinds) and
-- ON/OFF settings (Preferences). The client's Settings sends the whole
-- string on the SetKeybinds or SetPreferences remote (both made here) after
-- a change; it's checked against its module (known entries, allowed values,
-- already in its tidy saved form) and kept as the player's attribute, which
-- PlayerStats saves. At most one save per THROTTLE seconds per player per
-- remote.
-- Quick respawn: a player who has it on is respawned QUICK_RESPAWN_DELAY
-- after dying (just long enough for kill credit, the kill feed and
-- overcharge refills to see the death), skipping the death screen and the
-- ragdoll.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))

local THROTTLE = 0.5 -- seconds between saves a player may make on one remote
local QUICK_RESPAWN_DELAY = 0.1 -- seconds

local lastSave = {} -- player -> remote name -> os.clock() of their last accepted save

-- a remote that saves one module's string for the player who sends it
local function accept(remoteName, module)
	local remote = Instance.new("RemoteEvent")
	remote.Name = remoteName
	remote.Parent = ReplicatedStorage
	remote.OnServerEvent:Connect(function(player, text)
		if typeof(text) ~= "string" or #text > module.MaxLength then
			return
		end
		local saves = lastSave[player] or {}
		lastSave[player] = saves
		local now = os.clock()
		if now - (saves[remoteName] or -math.huge) < THROTTLE then
			return
		end
		local map = module.Parse(text)
		-- Parse cleans up anything wrong; only a string it didn't have to clean is taken
		if not module.Valid(map) or module.Serialize(map) ~= text then
			return
		end
		saves[remoteName] = now
		player:SetAttribute(module.Attribute, text)
	end)
end

accept("SetKeybinds", Keybinds)
accept("SetPreferences", Preferences)

-- Quick respawn, decided at the moment of death
local function watchCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.Died:Once(function()
		if not Preferences.For(player, "QuickRespawn") then
			return
		end
		task.delay(QUICK_RESPAWN_DELAY, function()
			-- not if they left, or something already gave them a new character
			if player.Parent and player.Character == character then
				player:LoadCharacter()
			end
		end)
	end)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastSave[player] = nil
end)
