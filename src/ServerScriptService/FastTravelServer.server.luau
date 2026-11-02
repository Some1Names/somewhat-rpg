-- Fast travel's server side: every trip is decided here, with FastTravelConfig's numbers and rules.
-- The travel points are the models tagged FastTravelConfig.Tag (the Spawn Keepers): a point's id is
-- its TravelId attribute or its spot (FastTravelConfig.PointId), its name its PlaceName attribute,
-- else the named area it stands in (ZoneConfig), else "Spawn Keeper". The FastTravel remote (a
-- RemoteFunction made here) takes ("Points"), answered with the points as the asking player sees
-- them (which one they're at, which they may go to) and the seconds left on their cooldown, and
-- ("Travel", id), which checks the trip (at a keeper, a real and unlocked point, not the one they're
-- at, out of PvP combat, off cooldown), streams the destination's area in for them and puts them in
-- front of its keeper. Both answer { ok, reason? }. The client's map is FastTravelMenu.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatRules = require(ReplicatedStorage:WaitForChild("CombatRules"))
local FastTravelConfig = require(ReplicatedStorage:WaitForChild("FastTravelConfig"))
local HudRules = require(ReplicatedStorage:WaitForChild("HudRules"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))

local remote = ReplicatedStorage:FindFirstChild("FastTravel")
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = "FastTravel"
	remote.Parent = ReplicatedStorage
end

local MIN_INTERVAL = 0.3 -- seconds between a player's calls
local NOT_AT_KEEPER = "Talk to a keeper to travel"
local lastCall = {} -- player -> os.clock() of their last call
local lastTrip = {} -- player -> os.clock() of their last trip
local travelling = {} -- player -> true while their destination streams in

-- the travel points as they stand now: { id, name, model }
local function travelPoints()
	local list = {}
	for _, model in ipairs(CollectionService:GetTagged(FastTravelConfig.Tag)) do
		if model:IsA("Model") and model:IsDescendantOf(workspace) then
			local at = model:GetPivot().Position
			table.insert(list, {
				id = FastTravelConfig.PointId(model:GetAttribute("TravelId"), at.X, at.Z),
				name = FastTravelConfig.PlaceName(model:GetAttribute("PlaceName"), HudRules.ZoneAt(ZoneConfig.Zones, at.X, at.Z)),
				model = model,
			})
		end
	end
	return list
end

-- the player's root part while they're alive, else nil
local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root
	end
	return nil
end

-- the point whose keeper the player stands at (the nearest within Range), or nil
local function pointAt(list, root)
	local best, bestDistance = nil, FastTravelConfig.Range
	for _, point in ipairs(list) do
		local distance = (point.model:GetPivot().Position - root.Position).Magnitude
		if distance <= bestDistance then
			best, bestDistance = point, distance
		end
	end
	return best
end

local function findPoint(list, id)
	for _, point in ipairs(list) do
		if point.id == id then
			return point
		end
	end
	return nil
end

-- why the player can't go to point `id` right now (FastTravelConfig.Refusal), or nil; then the point
local function refusal(player, root, id)
	local list = travelPoints()
	local here, there = pointAt(list, root), findPoint(list, id)
	local character = player.Character
	return FastTravelConfig.Refusal({
		from = here and here.id,
		to = there and there.id,
		unlocked = there ~= nil and FastTravelConfig.IsUnlocked(there.id, player:GetAttribute(FastTravelConfig.UnlockAttribute)),
		combatLeft = CombatRules.SecondsLeft(character and character:GetAttribute(CombatRules.PvPAttribute), workspace:GetServerTimeNow()),
		cooldownLeft = FastTravelConfig.CooldownLeft(lastTrip[player], os.clock()),
	}), there
end

-- in front of the keeper, facing the way they face (where SpawnServer puts a saved spawn)
local function landing(model)
	local pivot = model:GetPivot()
	local spot = (pivot * CFrame.new(0, 0, -FastTravelConfig.LandAhead)).Position + Vector3.new(0, FastTravelConfig.Lift, 0)
	local look = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
	return look.Magnitude > 0.01 and CFrame.lookAt(spot, spot + look) or CFrame.new(spot)
end

local function pointsFor(player)
	local root = rootOf(player)
	local list = travelPoints()
	local here = root and pointAt(list, root)
	if not here then
		return { ok = false, reason = NOT_AT_KEEPER }
	end
	local unlocked = player:GetAttribute(FastTravelConfig.UnlockAttribute)
	local sent = {}
	for _, point in ipairs(list) do
		table.insert(sent, {
			id = point.id,
			name = point.name,
			position = point.model:GetPivot().Position,
			here = point == here,
			unlocked = FastTravelConfig.IsUnlocked(point.id, unlocked),
		})
	end
	return { ok = true, points = sent, cooldown = FastTravelConfig.CooldownLeft(lastTrip[player], os.clock()) }
end

local function travel(player, id)
	if travelling[player] then
		return { ok = false, reason = "Already on the way" }
	end
	local root = rootOf(player)
	if not root then
		return { ok = false, reason = NOT_AT_KEEPER }
	end
	local reason, there = refusal(player, root, id)
	if reason then
		return { ok = false, reason = reason }
	end
	-- the destination's area streams in for them first, so they don't land in nothing
	travelling[player] = true
	pcall(player.RequestStreamAroundAsync, player, landing(there.model).Position, FastTravelConfig.StreamTimeout)
	travelling[player] = nil
	-- anything can change while it streams (a hit, a death, the keeper gone): checked again
	root = rootOf(player)
	if not root or not player.Parent then
		return { ok = false, reason = NOT_AT_KEEPER }
	end
	reason, there = refusal(player, root, id)
	if reason then
		return { ok = false, reason = reason }
	end
	lastTrip[player] = os.clock()
	root.AssemblyLinearVelocity = Vector3.zero
	player.Character:PivotTo(landing(there.model))
	return { ok = true }
end

local function onInvoke(player, action, id)
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < MIN_INTERVAL then
		return { ok = false, reason = "Slow down" }
	end
	lastCall[player] = now
	if action == "Points" then
		return pointsFor(player)
	elseif action == "Travel" and typeof(id) == "string" then
		return travel(player, id)
	end
	return { ok = false, reason = "Invalid request" }
end

remote.OnServerInvoke = onInvoke
Players.PlayerRemoving:Connect(function(player)
	lastCall[player], lastTrip[player], travelling[player] = nil, nil, nil
end)
