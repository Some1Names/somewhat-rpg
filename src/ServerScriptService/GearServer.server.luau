-- The Backpack's gear remote: GearAction:InvokeServer("equip" | "unequip" | "salvage", idOrSlot)
-- returns ok, why. Equip and salvage name a bag piece's id, unequip a slot. Made here (by
-- script, like TalismanAction); Gear checks and does the work.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Gear = require(script.Parent:WaitForChild("Gear"))
local GearConfig = require(ReplicatedStorage:WaitForChild("GearConfig"))

local remote = Instance.new("RemoteFunction")
remote.Name = GearConfig.Remote
remote.Parent = ReplicatedStorage

local busy = {}

remote.OnServerInvoke = function(player, action, target)
	if typeof(target) ~= "string" or (action ~= "equip" and action ~= "unequip" and action ~= "salvage") then
		return false, "Bad request"
	end
	if busy[player] then
		return false, "Busy"
	end
	busy[player] = true
	local ok, result, why
	if action == "equip" then
		ok, result, why = pcall(Gear.Equip, player, target)
	elseif action == "unequip" then
		ok, result, why = pcall(Gear.Unequip, player, target)
	else
		ok, result, why = pcall(Gear.Salvage, player, target)
	end
	busy[player] = nil
	if not ok then
		warn("[GearServer] " .. action .. " failed: " .. tostring(result))
		return false, "Something went wrong"
	end
	return result, why
end

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)
