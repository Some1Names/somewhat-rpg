-- Double jump, once it's been bought from the shop (OwnsDoubleJump): press
-- jump again in midair to leap once more. Spends a dodge charge (see
-- DodgeCharges) and half a stamina box, and works again and again in the air
-- as long as there are charges, like the Q dodge.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local DodgeCharges = require(script.Parent:WaitForChild("DodgeCharges"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local Stamina = require(script.Parent:WaitForChild("Stamina"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))

local player = Players.LocalPlayer

local OWNED_ATTRIBUTE = ShopConfig.OwnedAttribute("DoubleJump")
local JUMP_KEYS = { [Enum.KeyCode.Space] = true, [Enum.KeyCode.ButtonA] = true }
local JUMP_SPEED = 70 -- studs per second straight up (about 12.5 studs high)
local STAMINA_COST = StatConfig.StaminaPerBox / 2
local READY_DELAY = 0.12 -- seconds after leaving the ground before it can be used
local RING_COLOR = Color3.fromRGB(235, 245, 255)
local RING_TIME = 0.3

local leftGroundAt

-- a puff of air under the feet
local function showPuff(position)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = RING_COLOR
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.2, 1.5, 1.5)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(RING_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 7, 7),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, RING_TIME)
end

local function tryDoubleJump()
	if player:GetAttribute(OWNED_ATTRIBUTE) ~= 1 then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	-- while flying, jump means rise (Flight)
	if not root or humanoid.Health <= 0 or humanoid.Sit or character:GetAttribute("Flying") then
		return
	end
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		return
	end
	if not leftGroundAt or os.clock() - leftGroundAt < READY_DELAY then
		return
	end
	if not DodgeCharges.CanUse() or not Stamina.TryConsume(STAMINA_COST) then
		return
	end
	DodgeCharges.TryUse()
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, JUMP_SPEED, velocity.Z)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	showPuff(root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
end

local function watchCharacter(character)
	leftGroundAt = nil
	local humanoid = character:WaitForChild("Humanoid")
	humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		if humanoid.FloorMaterial == Enum.Material.Air then
			leftGroundAt = os.clock()
		else
			leftGroundAt = nil
		end
	end)
end
if player.Character then
	task.spawn(watchCharacter, player.Character)
end
player.CharacterAdded:Connect(watchCharacter)

-- a fresh press only, so holding jump doesn't fire it by itself
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and JUMP_KEYS[input.KeyCode] then
		tryDoubleJump()
	end
end)
