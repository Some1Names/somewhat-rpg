-- What the map tab (MapMenu) can't see for itself with streaming on, since far-off parts
-- aren't on the client: where the NPCs it marks stand, as ReplicatedStorage.MapMarkers (a
-- Vector3Value each, named by its label, with a Kind attribute: Quest, Service or Spawn),
-- and where every player is, as their MapPosition attribute (party mates far away), and
-- the nearest living enemy their bounty asks for, as their QuestTarget attribute (the
-- compass). All are refreshed every second, as is exploring: the map cells around each player join
-- their Explored text (MapRules), which PlayerStats saves; nothing is revealed until
-- PlayerStats has set it, so a late load can't overwrite what was found.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapRules = require(ReplicatedStorage:WaitForChild("MapRules"))
local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))

local REFRESH = 1 -- s
local MOVED = 2 -- studs something moves before it's sent again
local ENEMY_TAG = "Enemy"

-- tag -> its marker; with no label the model's own name ("PowerDealer" spaced out)
local TAGS = {
	QuestGiver = { kind = "Quest", label = "Bounty Hunter" },
	Smith = { kind = "Service", label = "Smith" },
	FactionRecruiter = { kind = "Service", label = "Recruiter" },
	Shop = { kind = "Service" },
	PowerGacha = { kind = "Service", label = "Power Gacha" },
	SpawnSetter = { kind = "Spawn", label = "Spawn Keeper" },
}

local folder = Instance.new("Folder")
folder.Name = "MapMarkers"
folder.Parent = ReplicatedStorage

local markers = {} -- instance -> its Vector3Value

local function where(instance)
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	elseif instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

local function add(instance, kind, label)
	if markers[instance] or not instance:IsDescendantOf(workspace) then
		return
	end
	local position = where(instance)
	if not position then
		return
	end
	local value = Instance.new("Vector3Value")
	value.Name = label or (instance.Name:gsub("(%l)(%u)", "%1 %2"))
	value.Value = position
	value:SetAttribute("Kind", kind)
	value.Parent = folder
	markers[instance] = value
end

local function remove(instance)
	if markers[instance] then
		markers[instance]:Destroy()
		markers[instance] = nil
	end
end

for tag, info in pairs(TAGS) do
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		add(instance, info.kind, info.label)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		add(instance, info.kind, info.label)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end
for _, item in ipairs(workspace:GetDescendants()) do
	if item:IsA("SpawnLocation") then
		add(item, "Spawn", "Spawn")
	end
end

-- the nearest living enemy of `enemyType` to `from`, or nil
local function nearestEnemy(enemyType, from)
	local best, bestDistance = nil, math.huge
	for _, model in ipairs(CollectionService:GetTagged(ENEMY_TAG)) do
		local humanoid = model:GetAttribute("EnemyType") == enemyType and model:FindFirstChildOfClass("Humanoid")
		local position = humanoid and humanoid.Health > 0 and model:IsDescendantOf(workspace) and where(model)
		if position and (position - from).Magnitude < bestDistance then
			best, bestDistance = position, (position - from).Magnitude
		end
	end
	return best
end

-- each player's last Explored text and its cells, so it's decoded only when it changes
local exploredCache = {} -- player -> { text, explored }
Players.PlayerRemoving:Connect(function(player)
	exploredCache[player] = nil
end)

while true do
	task.wait(REFRESH)
	for instance, value in pairs(markers) do
		local position = instance.Parent and where(instance)
		if position and (position - value.Value).Magnitude > MOVED then
			value.Value = position
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local last = player:GetAttribute("MapPosition")
		if root and (typeof(last) ~= "Vector3" or (root.Position - last).Magnitude > MOVED) then
			player:SetAttribute("MapPosition", root.Position)
		end
		local _, quest = QuestConfig.parseQuestId(player:GetAttribute("QuestId"))
		local target = root and quest and nearestEnemy(quest.enemyType, root.Position) or nil
		local lastTarget = player:GetAttribute("QuestTarget")
		if not target then
			if lastTarget ~= nil then
				player:SetAttribute("QuestTarget", nil)
			end
		elseif typeof(lastTarget) ~= "Vector3" or (target - lastTarget).Magnitude > MOVED then
			player:SetAttribute("QuestTarget", target)
		end
		local text = player:GetAttribute("Explored")
		if root and typeof(text) == "string" then
			local cached = exploredCache[player]
			if not cached or cached.text ~= text then
				cached = { text = text, explored = MapRules.DecodeExplored(text) }
				exploredCache[player] = cached
			end
			local found = false
			for _, cell in ipairs(MapRules.CellsNear(root.Position.X, root.Position.Z)) do
				if not cached.explored[cell] then
					cached.explored[cell], found = true, true
				end
			end
			if found then
				cached.text = MapRules.EncodeExplored(cached.explored)
				player:SetAttribute("Explored", cached.text)
			end
		end
	end
end
