-- Server side of the Settings menu: a player's own keybinds. The client's
-- Settings sends the whole binding string on the SetKeybinds remote (made
-- here) after every change; it's checked against Keybinds (known actions,
-- allowed keys, no key twice, already in its tidy saved form) and kept as
-- the player's Keybinds attribute, which PlayerStats saves. At most one
-- save per THROTTLE seconds per player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))

local THROTTLE = 0.5 -- seconds between saves a player may make

local remote = Instance.new("RemoteEvent")
remote.Name = "SetKeybinds"
remote.Parent = ReplicatedStorage

local lastSave = {} -- player -> os.clock() of their last accepted save

remote.OnServerEvent:Connect(function(player, text)
	if typeof(text) ~= "string" or #text > Keybinds.MaxLength then
		return
	end
	local now = os.clock()
	if now - (lastSave[player] or -math.huge) < THROTTLE then
		return
	end
	local map = Keybinds.Parse(text)
	-- Parse cleans up anything wrong; only a string it didn't have to clean is taken
	if not Keybinds.Valid(map) or Keybinds.Serialize(map) ~= text then
		return
	end
	lastSave[player] = now
	player:SetAttribute(Keybinds.Attribute, text)
end)

Players.PlayerRemoving:Connect(function(player)
	lastSave[player] = nil
end)
