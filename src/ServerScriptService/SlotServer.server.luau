-- The slot screen's remote: SlotAction (a RemoteFunction) takes ("List"), ("Create", slot,
-- name, look), ("Select", slot) and ("Delete", slot, typedName) and answers
-- { ok, reason?, slots? }. slots is a list of SlotCount entries, false for an empty slot
-- (a table with gaps wouldn't survive the trip). All the rules are in Slots.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Slots = require(script.Parent:WaitForChild("Slots"))
local SlotConfig = require(ReplicatedStorage:WaitForChild("SlotConfig"))

local remote = ReplicatedStorage:FindFirstChild("SlotAction")
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = "SlotAction"
	remote.Parent = ReplicatedStorage
end

local MIN_INTERVAL = 0.5 -- seconds between a player's calls
local lastCall = {}

local function listOf(player)
	local meta, reason = Slots.List(player)
	if not meta then
		return { ok = false, reason = reason }
	end
	local slots = {}
	for slot = 1, SlotConfig.SlotCount do
		slots[slot] = meta[slot] or false
	end
	return { ok = true, slots = slots }
end

local function onInvoke(player, action, first, second, third)
	local now = os.clock()
	if now - (lastCall[player] or 0) < MIN_INTERVAL then
		return { ok = false, reason = "busy" }
	end
	lastCall[player] = now
	if action == "List" then
		return listOf(player)
	elseif action == "Create" then
		if typeof(first) ~= "number" or typeof(second) ~= "string" or typeof(third) ~= "string" then
			return { ok = false, reason = "Invalid request" }
		end
		local ok, reason = Slots.Create(player, first, second, third)
		return { ok = ok, reason = reason }
	elseif action == "Select" then
		if typeof(first) ~= "number" then
			return { ok = false, reason = "Invalid request" }
		end
		local ok, reason = Slots.Select(player, first)
		return { ok = ok, reason = reason }
	elseif action == "Delete" then
		if typeof(first) ~= "number" or typeof(second) ~= "string" then
			return { ok = false, reason = "Invalid request" }
		end
		local ok, reason = Slots.Delete(player, first, second)
		if not ok then
			return { ok = false, reason = reason }
		end
		return listOf(player)
	end
	return { ok = false, reason = "Invalid request" }
end

remote.OnServerInvoke = onInvoke
Players.PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
end)
Slots.Start()
