-- Swimming in the map's water parts (tagged Water, see ReplicatedStorage.Water;
-- Roblox only swims in Terrain water). While the local character's root is
-- inside one, this puts the Humanoid in the Swimming state (so the rig's own
-- swim animation plays), cancels gravity with a VectorForce and drives the
-- character with a LinearVelocity: it floats with its head above the surface
-- and swims level with the movement keys, locked to the surface (no diving, no
-- rising). At the surface next to a ledge Space climbs out; with no ledge it
-- just floats. The camera is kept above the surface (nobody sees under water).
-- The client runs its own character's physics, so everyone sees it swim. It leaves everything alone while the
-- character is flying (Iridescent Requiem), dead, anchored, or being held by a skill
-- (a mover with the Hold attribute): then it lets go for that moment and the
-- skill moves them; a Dash drives the character itself, so this waits for it
-- too. Leaving the water, dying and respawning give back normal physics and
-- every Humanoid state it switched off. Sets the character's local Swimming
-- attribute for Sprint and DoubleJump.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Water = require(ReplicatedStorage:WaitForChild("Water"))

local player = Players.LocalPlayer
local controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()

local SWIM_ACCEL = 60 -- studs/s² the swim drive may apply (its force is this times the mass)
local SPRING = 4 -- per second: how hard swimmers settle to the float height
local IDLE_RISE = 5 -- studs per second an idle swimmer's buoyancy lifts them, however deep
local SPLASH_SPEED = 12 -- studs per second: the fastest a swimmer sinks when they hit the water
local EXIT_GROW = 1.5 -- studs past the water's edge a swimmer is still counted in it, so skimming the surface doesn't flicker
local STILL = 0.1 -- move input weaker than this counts as idle
local LEDGE_REACH = 3.5 -- studs ahead at the surface where a ledge counts
local LEDGE_HEIGHT = 4.2 -- studs above the surface of the highest ledge it climbs onto
local CLIMB_PUSH = 14 -- studs per second forward when climbing out
local CLIMB_EXTRA = 1.5 -- studs of clearance above the ledge top
local CAMERA_CLEARANCE = 0.5 -- studs the camera stays above the water's surface
local REENTER_DELAY = 0.6 -- seconds after climbing out before the water can take hold again
-- every state that would fight the swimming one; all are switched back on afterwards
local DISABLED_STATES = {
	Enum.HumanoidStateType.Freefall,
	Enum.HumanoidStateType.Running,
	Enum.HumanoidStateType.RunningNoPhysics,
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.Landed,
	Enum.HumanoidStateType.GettingUp,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Jumping,
}

local swim -- { humanoid, root, attachment, velocity, force } while swimming
local noEntryUntil = 0

local function setStates(humanoid, enabled)
	for _, state in ipairs(DISABLED_STATES) do
		humanoid:SetStateEnabled(state, enabled)
	end
end

-- puts everything back: the movers go, the states come back, and a swimmer
-- left in the air starts to fall
local function stop(landingState)
	local current = swim
	swim = nil
	if not current then
		return
	end
	for _, instance in ipairs({ current.velocity, current.force, current.attachment }) do
		if instance.Parent then
			instance:Destroy()
		end
	end
	if current.humanoid.Parent then
		setStates(current.humanoid, true)
		if current.humanoid.Health > 0 and current.humanoid:GetState() == Enum.HumanoidStateType.Swimming then
			current.humanoid:ChangeState(landingState or Enum.HumanoidStateType.Freefall)
		end
		current.humanoid.Parent:SetAttribute("Swimming", nil)
	end
end

local function start(humanoid, root)
	-- hitting the water slows you: a fall in at speed doesn't plunge to the bottom
	local entering = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(entering.X * 0.5, math.max(entering.Y * 0.3, -SPLASH_SPEED), entering.Z * 0.5)
	local attachment = Instance.new("Attachment")
	attachment.Name = "SwimAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "SwimVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.MaxForce = root.AssemblyMass * SWIM_ACCEL
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root
	local force = Instance.new("VectorForce")
	force.Name = "SwimBuoyancy"
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity, 0)
	force.Parent = root
	setStates(humanoid, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
	humanoid.Parent:SetAttribute("Swimming", true)
	swim = { humanoid = humanoid, root = root, attachment = attachment, velocity = velocity, force = force }
end

-- a skill's mover holding the character (BlackHole, Tornado): not ours
local function heldBySkill(root)
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("LinearVelocity") and child:GetAttribute("Hold") and child.Enabled then
			return true
		end
	end
	return false
end

-- whether there's a ledge to climb onto straight ahead at the water's edge:
-- something solid in reach at the surface, with a top within LEDGE_HEIGHT
local function ledgeAhead(root, direction, surface)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.1 then
		return nil
	end
	flat = flat.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true -- reeds and lily pads aren't ledges
	local others = { root.Parent }
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(others, other.Character) -- nor are other swimmers
		end
	end
	params.FilterDescendantsInstances = others
	local origin = Vector3.new(root.Position.X, surface + 0.3, root.Position.Z)
	local wall = workspace:Raycast(origin, flat * LEDGE_REACH, params)
	if not wall then
		return nil
	end
	-- from above, just past the wall, down onto its top
	local over = origin + flat * (wall.Distance + 0.8) + Vector3.new(0, LEDGE_HEIGHT + 1, 0)
	local top = workspace:Raycast(over, Vector3.new(0, -(LEDGE_HEIGHT + 2), 0), params)
	if top and top.Normal.Y > 0.5 and top.Position.Y <= surface + LEDGE_HEIGHT then
		return flat, top.Position.Y
	end
	return nil
end

local function step()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 or character:GetAttribute("Flying") then
		stop()
		return
	end
	local part = Water.Find(root.Position, swim and EXIT_GROW or nil)
	if not part or os.clock() < noEntryUntil then
		stop()
		return
	end
	if swim and (swim.humanoid ~= humanoid or swim.root ~= root) then
		stop() -- a new body
	end
	if not swim then
		start(humanoid, root)
	end

	-- a Dash drives itself; a skill's hold moves us (and an anchored body, pinned
	-- or pasted, isn't ours to move): yield for now
	if player:GetAttribute("Dashing") or heldBySkill(root) or root.Anchored then
		swim.velocity.Enabled = false
		return
	end
	swim.velocity.Enabled = true
	swim.velocity.MaxForce = root.AssemblyMass * SWIM_ACCEL
	swim.force.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity, 0)

	local surface = Water.surfaceY(part.CFrame, part.Size, root.Position)
	local floatY = surface - Water.SurfaceOffset
	local camera = workspace.CurrentCamera.CFrame
	-- a guard break's stun holds a swimmer still, like anyone
	local stunned = (character:GetAttribute("HitstunUntil") or 0) > workspace:GetServerTimeNow()
	local input = stunned and Vector3.zero or controls:GetMoveVector() -- camera-relative: x right, z back
	local direction = camera.LookVector * -input.Z + camera.RightVector * input.X
	local moving = direction.Magnitude > STILL
	if direction.Magnitude > 1 then
		direction = direction.Unit
	end
	local typing = UserInputService:GetFocusedTextBox() ~= nil
	local jumping = not stunned and (humanoid.Jump or (not typing and UserInputService:IsKeyDown(Enum.KeyCode.Space)))
	humanoid.Jump = false
	if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
		humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
	end

	-- at the surface by a ledge, Space climbs out
	local atSurface = root.Position.Y >= floatY - 0.6
	if jumping and atSurface then
		local ahead = moving and direction or camera.LookVector
		local flat, ledgeTop = ledgeAhead(root, ahead, surface)
		if flat then
			-- the feet, not the root, have to clear the ledge
			local feetY = root.Position.Y - (humanoid.HipHeight + root.Size.Y / 2)
			local rise = math.max(ledgeTop - feetY + CLIMB_EXTRA, 2)
			noEntryUntil = os.clock() + REENTER_DELAY
			stop() -- our own velocity is the whole jump (the Jumping state would add its own)
			root.AssemblyLinearVelocity = Vector3.new(flat.X * CLIMB_PUSH, math.sqrt(2 * workspace.Gravity * rise), flat.Z * CLIMB_PUSH)
			return
		end
	end

	-- locked to the surface: swim level (the camera's pitch and Space don't
	-- steer up or down), and buoyancy holds the float height, however deep
	local flat = Vector3.new(direction.X, 0, direction.Z)
	flat = moving and flat.Magnitude > 0.01 and flat.Unit * math.min(direction.Magnitude, 1) or Vector3.zero
	local lift = math.clamp((floatY - root.Position.Y) * SPRING, -Water.RiseSpeed, IDLE_RISE)
	swim.velocity.VectorVelocity = flat * Water.SwimSpeed + Vector3.new(0, lift, 0)
	swim.flat = flat
end

-- The Humanoid swims along the camera's full 3D direction (looking down dives)
-- whatever the LinearVelocity says, so each frame, right after the controls
-- set it, its own move direction is made level.
RunService:BindToRenderStep("SwimLevel", Enum.RenderPriority.Input.Value + 1, function()
	if swim and swim.flat and swim.velocity.Enabled and swim.humanoid.Parent then
		swim.humanoid:Move(swim.flat, false)
	end
end)

-- nobody sees under the water: a camera inside a water part is lifted to just
-- above its surface (after the camera scripts have run each frame)
RunService:BindToRenderStep("WaterCamera", Enum.RenderPriority.Camera.Value + 2, function()
	local camera = workspace.CurrentCamera
	local cframe = camera.CFrame
	local part = Water.Find(cframe.Position)
	if part then
		local surface = Water.surfaceY(part.CFrame, part.Size, cframe.Position)
		camera.CFrame = cframe + Vector3.new(0, surface + CAMERA_CLEARANCE - cframe.Position.Y, 0)
	end
end)

RunService.Heartbeat:Connect(step)

-- a death or a new body ends it at once
local function watchCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Once(function()
			stop()
		end)
	end
end
if player.Character then
	task.spawn(watchCharacter, player.Character)
end
player.CharacterAdded:Connect(function(character)
	stop()
	watchCharacter(character)
end)
