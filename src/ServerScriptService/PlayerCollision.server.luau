-- Players walk through each other: every part of a character goes in the "Players" collision group,
-- which doesn't collide with itself (enemies, the map and projectiles still do).
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local GROUP = "Players"

if not PhysicsService:IsCollisionGroupRegistered(GROUP) then
	PhysicsService:RegisterCollisionGroup(GROUP)
end
PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)

local function setGroup(part)
	if part:IsA("BasePart") then
		part.CollisionGroup = GROUP
	end
end

local function onCharacter(character)
	for _, descendant in character:GetDescendants() do
		setGroup(descendant)
	end
	character.DescendantAdded:Connect(setGroup)
end

local function onPlayer(player)
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end
