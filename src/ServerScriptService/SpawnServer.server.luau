-- The Spawn Keeper: an NPC (a model tagged "SpawnSetter" with a ProximityPrompt
-- named "SpawnPrompt" in its root part). Using it saves a spot beside the NPC as
-- the player's spawn (the SpawnPoint text, saved by PlayerStats); every respawn
-- after that starts there. No saved spot means the normal SpawnLocation.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local TAG = "SpawnSetter"
local PROMPT = "SpawnPrompt"
local RANGE = 14 -- studs from the NPC the player must be within (checked on the server)
local SIDE_OFFSET = 5 -- the saved spot is this far in front of the NPC
local LIFT = 3 -- raised a little so the player drops onto the ground, not into it

local function parse(text)
	local x, y, z = string.match(text or "", "^(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)$")
	if x then
		return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
	end
	return nil
end

local function notify(player, text)
	player:SetAttribute("SpawnNotice", text .. "|" .. os.clock()) -- the client shows the text part
end

local function onPrompt(npc, player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if (npc:GetPivot().Position - root.Position).Magnitude > RANGE then
		return
	end
	local spot = (npc:GetPivot() * CFrame.new(0, 0, -SIDE_OFFSET)).Position + Vector3.new(0, LIFT, 0)
	player:SetAttribute("SpawnPoint", string.format("%.1f,%.1f,%.1f", spot.X, spot.Y, spot.Z))
	notify(player, "Spawn set")
end

local function bind(npc)
	if not npc:IsA("Model") then
		return
	end
	local root = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
	local prompt = root and root:FindFirstChild(PROMPT)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT
		prompt.ActionText = "Set spawn"
		prompt.ObjectText = npc.Name
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
	end
	prompt.Triggered:Connect(function(player)
		onPrompt(npc, player)
	end)
end

local function onCharacter(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local spot = parse(player:GetAttribute("SpawnPoint"))
	-- the saved spot loads a moment after the character on a first join
	if not spot then
		for _ = 1, 20 do
			if player:GetAttribute("SpawnPoint") ~= nil then
				break
			end
			task.wait(0.25)
		end
		spot = parse(player:GetAttribute("SpawnPoint"))
	end
	if root and spot and character.Parent then
		character:PivotTo(CFrame.new(spot))
	end
end

for _, npc in ipairs(CollectionService:GetTagged(TAG)) do
	bind(npc)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(bind)

local function onPlayer(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
