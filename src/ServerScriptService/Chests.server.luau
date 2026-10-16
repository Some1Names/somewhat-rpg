-- Yen chests (numbers and rules: ReplicatedStorage.ChestConfig). Every part in
-- Workspace named `TestChest` marks a spot a chest can stand on. When the game
-- starts the marker parts are taken out of the map (the first is kept as the
-- chest's look) and ChestConfig.Active chests are cloned onto random spots in
-- workspace.Chests. A player walking onto one gets yen (PlayerStats.AddYen)
-- (Magnate Talisman: more) and it goes, and TalismanConfig.ChestChance of the time
-- they also find a talisman; ChestConfig.RespawnDelay later another appears on a free spot,
-- not the one just collected unless it's the only one free.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChestConfig = require(ReplicatedStorage:WaitForChild("ChestConfig"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local TalismanConfig = require(ReplicatedStorage:WaitForChild("TalismanConfig"))
local Talismans = require(script.Parent:WaitForChild("Talismans"))

local rng = Random.new()
local function roll(a, b)
	if b == nil then
		return rng:NextInteger(1, a)
	end
	return rng:NextInteger(a, b)
end

-- the spots: where the marker parts stand, and a template to clone
local spots, template = {}, nil
for _, child in ipairs(workspace:GetChildren()) do
	if child:IsA("BasePart") and child.Name == ChestConfig.SpotName then
		table.insert(spots, child.CFrame)
		template = template or child:Clone()
		child:Destroy()
	end
end
if #spots == 0 then
	warn("Chests: no part named " .. ChestConfig.SpotName .. " in Workspace, so no chests")
	return
end

template.Name = "Chest"
template.Anchored = true
template.CanCollide = false -- walk over it
template.CanQuery = false
template.CanTouch = true

local folder = Instance.new("Folder")
folder.Name = "Chests"
folder.Parent = workspace

local taken = {} -- spot index -> true while a chest stands there
local spawnChest

local function collect(chest, index, hit)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not player or not humanoid or humanoid.Health <= 0 or chest:GetAttribute("Claimed") then
		return
	end
	chest:SetAttribute("Claimed", true)
	local yen = ChestConfig.yen(roll) * TalismanConfig.YenMultiplier(player:GetAttribute(TalismanConfig.EquippedAttribute))
	PlayerStats.AddYen(player, math.floor(yen))
	-- sometimes a talisman too, one they don't own yet
	if rng:NextNumber() < TalismanConfig.ChestChance then
		Talismans.GrantRandom(player)
	end
	chest:Destroy()
	taken[index] = nil
	task.delay(ChestConfig.RespawnDelay, spawnChest, index)
end

-- `avoid` is the spot a chest was just collected from
function spawnChest(avoid)
	local index = ChestConfig.pickSpot(#spots, taken, avoid, roll)
	if not index then
		return
	end
	taken[index] = true
	local chest = template:Clone()
	chest.CFrame = spots[index]
	chest.Touched:Connect(function(hit)
		collect(chest, index, hit)
	end)
	chest.Parent = folder
end

for _ = 1, ChestConfig.target(#spots) do
	spawnChest(nil)
end
