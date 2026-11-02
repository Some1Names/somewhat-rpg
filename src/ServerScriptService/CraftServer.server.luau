-- Server side of the 3D printer: makes the CraftAction remote, and a request
-- only goes through for a player standing next to a printer (a part or model
-- tagged "Printer") with no other request of theirs still running; Crafting
-- does all the checking and spending.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CraftConfig = require(ReplicatedStorage:WaitForChild("CraftConfig"))
local Crafting = require(script.Parent:WaitForChild("Crafting"))

local ACTION_INTERVAL = 0.3 -- seconds between a player's requests
local RANGE_TOLERANCE = 4 -- a little more than the menu's range, for movement while the request travels

local remote = Instance.new("RemoteFunction")
remote.Name = CraftConfig.Remote
remote.Parent = ReplicatedStorage

local lastAction = setmetatable({}, { __mode = "k" })
local busy = setmetatable({}, { __mode = "k" })

local function nearPrinter(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	for _, printer in ipairs(CollectionService:GetTagged(CraftConfig.Tag)) do
		if printer:IsA("PVInstance") and printer:IsDescendantOf(workspace) then
			if (printer:GetPivot().Position - root.Position).Magnitude <= CraftConfig.Range + RANGE_TOLERANCE then
				return true
			end
		end
	end
	return false
end

-- (action, arg) -> ok, message
--   "start"   (recipe id)          start a print
--   "collect" (job index)          take a finished print
--   "cancel"  (job index)          stop a running print, half the materials back
--   "learn"   (recipe id, route)   learn a recipe by "buy", "drop" or "faction"
local function handle(player, action, arg, route)
	if action == "start" then
		return Crafting.Start(player, arg)
	elseif action == "collect" then
		return Crafting.Collect(player, arg)
	elseif action == "cancel" then
		return Crafting.Cancel(player, arg)
	end
	return Crafting.Learn(player, arg, route)
end

remote.OnServerInvoke = function(player, action, arg, route)
	local byIndex = action == "collect" or action == "cancel"
	if not (byIndex or action == "start" or action == "learn") then
		return false, "Unknown request"
	end
	if byIndex and (typeof(arg) ~= "number" or arg % 1 ~= 0) then
		return false, "Bad request"
	end
	if not byIndex and typeof(arg) ~= "string" then
		return false, "Bad request"
	end
	if action == "learn" and typeof(route) ~= "string" then
		return false, "Bad request"
	end
	local now = os.clock()
	if busy[player] or now - (lastAction[player] or 0) < ACTION_INTERVAL then
		return false, "Slow down"
	end
	lastAction[player] = now
	if not nearPrinter(player.Character) then
		return false, "Too far from the printer"
	end
	busy[player] = true
	local ok, ok2, message = pcall(handle, player, action, arg, route)
	busy[player] = nil
	if not ok then
		warn("[CraftServer] " .. tostring(ok2))
		return false, "Something went wrong"
	end
	return ok2, message
end

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
	lastAction[player] = nil
end)
