-- The hub's MAIN MENU: the ReturnToMenu remote (a RemoteFunction made here) saves the player
-- and rejoins them to this place, so they come back through the title menu and the slot
-- screen. Not while in PvP combat. Answers { ok, reason? }. The button is client MainMenu.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local CombatRules = require(ReplicatedStorage:WaitForChild("CombatRules"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))

local remote = ReplicatedStorage:FindFirstChild("ReturnToMenu")
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = "ReturnToMenu"
	remote.Parent = ReplicatedStorage
end

local MIN_INTERVAL = 2 -- seconds between a player's calls
local lastCall = {}

remote.OnServerInvoke = function(player)
	local now = os.clock()
	if now - (lastCall[player] or 0) < MIN_INTERVAL then
		return { ok = false, reason = "Wait a moment" }
	end
	lastCall[player] = now
	if RunService:IsStudio() then
		return { ok = false, reason = "Not in Studio" } -- (a place can't teleport to itself here)
	end
	local character = player.Character
	if CombatRules.SecondsLeft(character and character:GetAttribute(CombatRules.PvPAttribute), workspace:GetServerTimeNow()) then
		return { ok = false, reason = "Not while in combat" }
	end
	PlayerStats.SaveNow(player)
	local ok, err = pcall(TeleportService.Teleport, TeleportService, game.PlaceId, player)
	if not ok then
		warn("[MenuServer] couldn't send " .. player.Name .. " to the menu: " .. tostring(err))
		return { ok = false, reason = "Couldn't leave" }
	end
	return { ok = true }
end

Players.PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
end)
