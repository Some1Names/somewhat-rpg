-- Press Q to dash the way you're moving (relative to the camera), or
-- forward if no movement key is held. A dash out to the side of where the
-- character faces (shift lock, or mid-turn) keeps facing ahead and plays
-- DashLeft/DashRightAnimation; any other dash turns to face the way it goes
-- and plays DashRollAnimation (right leg leading), or, straight after
-- another one, DashRollMirroredAnimation (left leg), so a run of them
-- alternates legs. Each dash spends a dodge charge (see
-- DodgeCharges) and half a stamina box; in the air too, as long as there are
-- charges. A dash that's about to run into something stops short instead of
-- shoving into it (which can make the physics fling the character upward).
-- Also draws other players' dash trails. A skill set with its own dash does
-- that instead while it's equipped: Iridescent Requiem's Lightstep flashes
-- you there as light (even while flying, where the camera points), hurting
-- whoever it passes through, and the server makes you untouchable on the way
-- (DashRelay, Skills.Lightstep). It spends a dodge charge but no stamina.
-- Either one breaks free of a hold (a black hole's pull, a tornado): this
-- lets go of it at once, and DashRelay tells the skill to let go too. And
-- either one goes through the glass wall of Mandela's ultimate (tagged
-- RewriteWall): a normal dash switches its collision off for us while it
-- lasts, bursting the glass where we cross; Lightstep flashes past it.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local VFX = require(ReplicatedStorage:WaitForChild("VFX"))

local dashEffect = ReplicatedStorage:WaitForChild("DashEffect")
local localSkillEffect = ReplicatedStorage:WaitForChild("LocalSkillEffect")
local DodgeCharges = require(script.Parent:WaitForChild("DodgeCharges"))
local Stamina = require(script.Parent:WaitForChild("Stamina"))
local rollAnimations = {
	ReplicatedStorage:WaitForChild("DashRollAnimation"), -- right leg forward
	ReplicatedStorage:WaitForChild("DashRollMirroredAnimation"), -- left leg forward
}
local sideAnimations = {
	Left = ReplicatedStorage:WaitForChild("DashLeftAnimation"),
	Right = ReplicatedStorage:WaitForChild("DashRightAnimation"),
}
local player = Players.LocalPlayer
local controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()

local DASH_KEY = Enum.KeyCode.Q
local DASH_SPEED = 100 -- studs per second
local DASH_TIME = 0.2 -- seconds
local STAMINA_COST = StatConfig.StaminaPerBox / 2
local WALL_CHECK_SIZE = Vector3.new(2, 3, 1) -- the box swept ahead; clears the ground and low steps
local WALL_MARGIN = 1.5 -- studs short of an obstacle where the dash stops
local START_ROOM = WALL_MARGIN + DASH_SPEED / 30 -- clear space needed ahead to start at all
local MAX_RISE = 15 -- studs per second; anything faster on a ground dash is the physics glitching
local DEFAULT_TINT = Color3.fromRGB(200, 225, 255) -- the dash's colour without a skill set
local TRAIL_LIFETIME = 0.3
local TRAIL_TEXTURE = "rbxassetid://14050983225" -- a soft glowing streak
local STREAK_TEXTURE = "rbxassetid://14191581119" -- fine white speed streaks
local AFTERIMAGE_TIME = 0.3 -- seconds the afterimage left at the start takes to fade
-- The dash animations never ease back to a normal stance, so each plays
-- only until the dash stops (sped up to reach its full pose by then) and
-- then blends back to normal; attacking works again as soon as it stops.
local DASH_ANIM_SPEED = 1.5
local RECOVER_TIME = 0.1 -- seconds to blend back to normal once the dash stops
local SIDE_THRESHOLD = 0.6 -- how far to the side of the facing a dash must point to be a side dash
local ALTERNATE_WINDOW = 2 -- seconds after a forward dash in which the next one leads with the other leg
local LIGHT_WALL_MARGIN = 2 -- studs short of a wall a light dash stops
local REWRITE_WALL_TAG = "RewriteWall" -- Skills.PlaceWhereDreamEnds's glass, which a dash goes through
local LIGHT_MIN_DISTANCE = 2 -- studs; any closer to a wall and it doesn't go
local LIGHT_RAY_HEIGHTS = { 0, 1.5 } -- studs above the root: waist and head

-- the dasher's colour: their equipped skill set's, or a pale blue-white
local function tintOf(character)
	local _, setName = SkillSetConfig.Equipped(character)
	local set = setName and SkillSetConfig.Sets[setName]
	return set and set.color or DEFAULT_TINT
end

-- a trail down the body, `height` studs above and below the root, kept until
-- its last segment has faded
local function bodyTrail(root, name, height, props)
	local top = Instance.new("Attachment")
	top.Name = name .. "Top"
	top.Position = Vector3.new(0, height, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = name .. "Bottom"
	bottom.Position = Vector3.new(0, -height, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = name
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.FaceCamera = true
	trail.LightInfluence = 0
	trail.MinLength = 0.05
	trail.TextureMode = Enum.TextureMode.Stretch
	for key, value in pairs(props) do
		trail[key] = value
	end
	trail.Parent = root
	for _, instance in ipairs({ trail, top, bottom }) do
		Debris:AddItem(instance, DASH_TIME + trail.Lifetime)
	end
end

-- a see-through copy of the body left where the dash started, fading out
local function afterimage(character, color)
	local ghost = Instance.new("Model")
	ghost.Name = "DashAfterimage"
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
			local ok, copy = pcall(part.Clone, part)
			if ok and copy then
				for _, child in ipairs(copy:GetChildren()) do
					if not child:IsA("DataModelMesh") then
						child:Destroy()
					end
				end
				copy.Anchored = true
				copy.CanCollide = false
				copy.CanQuery = false
				copy.CanTouch = false
				copy.CastShadow = false
				copy.Material = Enum.Material.ForceField
				copy.Color = color
				copy.Transparency = 0.1
				copy.Parent = ghost
				TweenService:Create(copy, TweenInfo.new(AFTERIMAGE_TIME), { Transparency = 1 }):Play()
			end
		end
	end
	ghost.Parent = workspace
	Debris:AddItem(ghost, AFTERIMAGE_TIME + 0.05)
end

-- A dash's look, the same on every client: a soft ribbon in the dasher's
-- colour with fine white speed streaks over it, speed lines streaming off
-- the back, a puff of dust where it left the ground and an afterimage left
-- behind. `direction` is where it's going (worked out from the motion for
-- other players' dashes).
local function showDash(character, direction)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if not direction then
		local v = root.AssemblyLinearVelocity
		local flat = Vector3.new(v.X, 0, v.Z)
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		direction = flat.Magnitude > 5 and flat.Unit or (look.Magnitude > 0.1 and look.Unit or Vector3.zAxis)
	end
	local tint = tintOf(character)
	bodyTrail(root, "DashTrail", 1.7, {
		Color = ColorSequence.new(Color3.new(1, 1, 1), tint),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) }),
		WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.4) }),
		Lifetime = TRAIL_LIFETIME,
		LightEmission = 0.8,
		Texture = TRAIL_TEXTURE,
	})
	bodyTrail(root, "DashStreaks", 1.3, {
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = TRAIL_LIFETIME * 0.6,
		LightEmission = 1,
		Texture = STREAK_TEXTURE,
	})
	-- speed lines fly off the back, the opposite way to the dash
	local backward = CFrame.lookAt(Vector3.zero, -direction)
	VFX.Play("Shared/DashLines", root, { color = tint, offset = root.CFrame.Rotation:Inverse() * backward, duration = DASH_TIME })
	local ground = VFX.Ground(root.Position)
	if ground and root.Position.Y - ground.Y < 5 then
		VFX.Play("Shared/DustPuff", ground, { scale = 1.3 })
	end
	afterimage(character, tint)
end

local dashTracks = setmetatable({}, { __mode = "k" }) -- animator -> { [Animation] = track }
local latestDash = 0 -- a dash chained onto another keeps the animation going
local playingTrack -- the latest dash's track; a chained dash with a different one cuts it off
local lastRoll, lastRollAt = 2, -math.huge -- which forward dash animation played last, and when

-- right leg first; a forward dash soon after another leads with the other leg
local function nextRoll()
	local now = os.clock()
	local index = (lastRoll == 1 and now - lastRollAt <= ALTERNATE_WINDOW) and 2 or 1
	lastRoll, lastRollAt = index, now
	-- the left-leg one only once it's been published (or previewed in Studio)
	if rollAnimations[index].AnimationId == "" then
		return rollAnimations[1]
	end
	return rollAnimations[index]
end

-- plays a dash animation (returns its track, for stopping it with the dash)
local function playDash(humanoid, animation)
	-- the dash still works before the animation has been published
	if animation.AnimationId == "" then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local tracks = dashTracks[animator]
	if not tracks then
		tracks = {}
		dashTracks[animator] = tracks
	end
	local track = tracks[animation]
	if not track then
		track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false
		tracks[animation] = track
	end
	if playingTrack and playingTrack ~= track and playingTrack.IsPlaying then
		playingTrack:Stop(0.05)
	end
	playingTrack = track
	track:Play(0.05)
	track:AdjustSpeed(DASH_ANIM_SPEED)
	return track
end

-- "Left" or "Right" for a dash out to that side of where the character faces
local function sideOf(root, direction)
	local right = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
	if right.Magnitude < 0.1 then
		return nil
	end
	local side = right.Unit:Dot(direction)
	if side > SIDE_THRESHOLD then
		return "Right"
	elseif side < -SIDE_THRESHOLD then
		return "Left"
	end
	return nil
end

-- the set's Dash animation (like IridescentRequiemAnimations.Dash), once published
local setDashTracks = setmetatable({}, { __mode = "k" })
local function playSetDash(humanoid, setName)
	local folder = ReplicatedStorage:FindFirstChild(setName .. "Animations")
	local animation = folder and folder:FindFirstChild("Dash")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animation or animation.AnimationId == "" or not animator then
		return
	end
	local tracks = setDashTracks[animator]
	if not tracks then
		tracks = {}
		setDashTracks[animator] = tracks
	end
	if not tracks[animation] then
		tracks[animation] = animator:LoadAnimation(animation)
		tracks[animation].Priority = Enum.AnimationPriority.Action
	end
	tracks[animation]:Play(0.05)
end

-- Lets go of whatever is holding the character (movers a skill marked
-- with the Hold attribute). Our client runs our character's physics, so
-- switching them off here frees it straight away; the server removes them.
local function breakFree(root)
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("LinearVelocity") and child:GetAttribute("Hold") then
			child.Enabled = false
		end
	end
end

-- the equipped set's own dash, if it has one
local function setDash(character)
	local _, setName = SkillSetConfig.Equipped(character)
	local set = setName and SkillSetConfig.Sets[setName]
	return set and set.dash, setName
end

-- the ultimate's glass panes, which dashes go through (a solid part can't be
-- left out of raycasts by CanQuery, so the checks below leave these out)
local function rewritePanes()
	return CollectionService:GetTagged(REWRITE_WALL_TAG)
end

-- first thing in the way that isn't a character (light goes through people, and the glass)
local function firstWall(from, offset, character)
	local ignore = rewritePanes()
	table.insert(ignore, character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	for _ = 1, 6 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(from, offset, params)
		if not hit then
			return nil
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then
			return hit.Position
		end
		table.insert(ignore, model)
	end
	return nil
end

-- Lightstep: straight to the end of the dash as light, stopping short of walls
local function lightDash(character, humanoid, root, spec, setName, flying)
	local direction
	if flying then
		local camera = workspace.CurrentCamera.CFrame
		local input = controls:GetMoveVector() -- camera-relative: x right, z back
		direction = camera.LookVector * -input.Z + camera.RightVector * input.X
		if direction.Magnitude < 0.1 then
			direction = camera.LookVector
		end
	else
		direction = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
		if direction.Magnitude < 0.1 then
			direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		end
	end
	direction = direction.Unit

	local from = root.Position
	local distance = spec.range
	for _, height in ipairs(LIGHT_RAY_HEIGHTS) do
		local start = from + Vector3.new(0, height, 0)
		local wall = firstWall(start, direction * distance, character)
		if wall then
			distance = math.min(distance, (wall - start).Magnitude - LIGHT_WALL_MARGIN)
		end
	end
	-- right up against something that way: no dash, and nothing spent
	if distance < LIGHT_MIN_DISTANCE then
		return
	end
	if not DodgeCharges.TryUse() then
		return
	end
	breakFree(root)

	local to = from + direction * distance
	dashEffect:FireServer(from, to)
	localSkillEffect:Fire("Lightstep", character, from, to, spec.travelTime)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	character:PivotTo(CFrame.lookAt(to, to + flat))
	root.AssemblyLinearVelocity = Vector3.zero
	playSetDash(humanoid, setName)
end

local function dash()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 or humanoid.Sit then
		return
	end
	local spec, setName = setDash(character)
	local flying = character:GetAttribute("Flying") == true
	-- flying has its own movement (Flight); only a set's own dash works up there
	if flying and not spec then
		return
	end
	if spec then
		lightDash(character, humanoid, root, spec, setName, flying)
		return
	end
	local inAir = humanoid.FloorMaterial == Enum.Material.Air
	-- MoveDirection is the camera-relative direction of the held movement keys
	local direction = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
	if direction.Magnitude < 0.1 then
		direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	direction = direction.Unit

	local castParams = RaycastParams.new()
	castParams.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = rewritePanes()
	table.insert(ignore, character)
	castParams.FilterDescendantsInstances = ignore
	castParams.RespectCanCollide = true
	-- right up against something that way: no dash, and nothing spent
	local facing = CFrame.lookAt(root.Position, root.Position + direction)
	if workspace:Blockcast(facing, WALL_CHECK_SIZE, direction * START_ROOM, castParams) then
		return
	end

	if not DodgeCharges.CanUse() or not Stamina.TryConsume(STAMINA_COST) then
		return
	end
	DodgeCharges.TryUse()
	breakFree(root)

	-- the ultimate's glass lets a dodge through: our client runs our physics,
	-- so switching the collision off here is enough
	local openedPanes = {}
	for _, pane in ipairs(rewritePanes()) do
		if pane:IsA("BasePart") and pane.CanCollide then
			pane.CanCollide = false
			table.insert(openedPanes, pane)
		end
	end
	local crossed = {}

	-- a side dash keeps facing ahead (once its animation is published);
	-- otherwise face the way the dash goes (ShiftLock pauses while Dashing is set)
	local sideAnimation = sideAnimations[sideOf(root, direction) or ""]
	latestDash += 1
	local thisDash = latestDash
	player:SetAttribute("Dashing", true)
	local dashTrack
	if sideAnimation and sideAnimation.AnimationId ~= "" then
		dashTrack = playDash(humanoid, sideAnimation)
	else
		root.CFrame = facing
		dashTrack = playDash(humanoid, nextRoll())
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "DashVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	-- on the ground only horizontal force, so gravity and slopes still apply;
	-- in the air it also holds your height so the dash goes straight across
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = Vector3.new(math.huge, inAir and math.huge or 0, math.huge)
	velocity.VectorVelocity = direction * DASH_SPEED
	velocity.Parent = root

	showDash(character, direction)
	dashEffect:FireServer()

	local stopped = false
	local watcher
	local function stop()
		if stopped then
			return
		end
		stopped = true
		watcher:Disconnect()
		velocity:Destroy()
		attachment:Destroy()
		for _, pane in ipairs(openedPanes) do
			if pane.Parent then
				pane.CanCollide = true
			end
		end
		-- straight back to normal: the pose blends out and attacks work again
		-- (unless another dash has already started)
		if thisDash == latestDash then
			if dashTrack then
				dashTrack:Stop(RECOVER_TIME)
			end
			player:SetAttribute("Dashing", false)
		end
		-- stop the slide; walking takes over again if a key is still held
		if root.Parent then
			local fall = root.AssemblyLinearVelocity.Y
			root.AssemblyLinearVelocity = Vector3.new(0, inAir and fall or math.min(fall, 0), 0)
		end
	end
	-- checked before each physics step, so the dash never pushes into anything
	watcher = RunService.PreSimulation:Connect(function(dt)
		if not root.Parent then
			stop()
			return
		end
		-- stop short of whatever is ahead
		if workspace:Blockcast(root.CFrame, WALL_CHECK_SIZE, direction * (DASH_SPEED * dt + WALL_MARGIN), castParams) then
			stop()
			return
		end
		-- going through a pane of the glass: it bursts where we cross
		for _, pane in ipairs(openedPanes) do
			if not crossed[pane] and pane.Parent then
				local localPosition = pane.CFrame:PointToObjectSpace(root.Position)
				if math.abs(localPosition.Z) < pane.Size.Z / 2 + 1.5 and math.abs(localPosition.X) < pane.Size.X / 2 and math.abs(localPosition.Y) < pane.Size.Y / 2 then
					crossed[pane] = true
					VFX.Play("Shared/Impact", root.Position, { color = Color3.new(1, 1, 1), scale = 0.9 })
					VFX.Play("Shared/Sparks", root.Position, { color = Color3.new(1, 1, 1), scale = 1 })
				end
			end
		end
		-- a ground dash never goes up; cancel any launch the physics tries
		local v = root.AssemblyLinearVelocity
		if not inAir and v.Y > MAX_RISE then
			root.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
		end
	end)
	task.delay(DASH_TIME, stop)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == DASH_KEY then
		dash()
	end
end)

dashEffect.OnClientEvent:Connect(function(dasher)
	if typeof(dasher) == "Instance" and dasher:IsA("Player") then
		showDash(dasher.Character)
	end
end)
