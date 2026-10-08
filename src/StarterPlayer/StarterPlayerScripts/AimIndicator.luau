-- Aim previews for skills, drawn on the ground while a skill key is held
-- (SkillBar casts when it's let go). The shape comes from a skill's `aim` spec
-- in SkillSetConfig: a line, a lock-on, a circle at the mouse, tornado paths,
-- a fan of beams, a dash, or a ring around you. Only this player sees them.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local AimIndicator = {}

local FILL_TRANSPARENCY = 0.8
local EDGE_TRANSPARENCY = 0.2
local FAINT_TRANSPARENCY = 0.75 -- a lock-on with nothing to lock onto
local LINE_WIDTH = 0.5
local EDGE_WIDTH = 0.3
local MAX_RING_SEGMENTS = 36
local LOCK_RING_RADIUS = 3
local TORNADO_START = 9 -- studs ahead a tornado spawns, as in Skills.Tornado

local folder = Instance.new("Folder")
folder.Name = "AimIndicator"
folder.Parent = workspace

-- parts are reused frame to frame: Draw counts what it uses and hides the rest
local pool = {}
local used = 0

local function nextPart(shape)
	used += 1
	local part = pool[used]
	if not part then
		part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Parent = folder
		pool[used] = part
	end
	part.Shape = shape
	return part
end

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

-- characters and effects aren't ground
local function refreshGroundFilter()
	local ignore = { folder }
	local effects = workspace:FindFirstChild("SkillEffects")
	if effects then
		table.insert(ignore, effects)
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	for _, enemy in ipairs(CollectionService:GetTagged("Enemy")) do
		table.insert(ignore, enemy)
	end
	groundParams.FilterDescendantsInstances = ignore
end

-- just above the ground under a point
local function groundAt(position)
	local hit = workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -60, 0), groundParams)
	return (hit and hit.Position or position - Vector3.new(0, 3, 0)) + Vector3.new(0, 0.12, 0)
end

local function bar(from, to, color, width, transparency)
	local offset = to - from
	if offset.Magnitude < 0.05 then
		return
	end
	local part = nextPart(Enum.PartType.Block)
	part.Color = color
	part.Transparency = transparency
	part.Size = Vector3.new(width, 0.08, offset.Magnitude)
	part.CFrame = CFrame.lookAt(from + offset / 2, to)
end

local function disc(center, radius, color, transparency)
	local part = nextPart(Enum.PartType.Cylinder)
	part.Color = color
	part.Transparency = transparency
	part.Size = Vector3.new(0.06, radius * 2, radius * 2)
	part.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
end

-- a faint filled circle with a bright edge
local function circle(center, radius, color)
	disc(center, radius, color, FILL_TRANSPARENCY)
	local segments = math.clamp(math.floor(radius * 2), 12, MAX_RING_SEGMENTS)
	local lift = Vector3.new(0, 0.02, 0)
	for i = 1, segments do
		local a0 = (i - 1) / segments * math.pi * 2
		local a1 = i / segments * math.pi * 2
		bar(
			center + lift + Vector3.new(math.cos(a0) * radius, 0, math.sin(a0) * radius),
			center + lift + Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius),
			color,
			EDGE_WIDTH,
			EDGE_TRANSPARENCY
		)
	end
end

-- The character (enemy or another player) nearest the direction of `aim`,
-- within `range` studs and `cone` degrees. Skills.SpineLash picks the same way.
function AimIndicator.LockTarget(character, aim, range, cone)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local wanted = flat(aim - root.Position)
	if wanted.Magnitude < 0.1 then
		wanted = flat(root.CFrame.LookVector)
	end
	wanted = wanted.Unit
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local best, bestAngle
	for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, range, params)) do
		local model = part.Parent
		local humanoid = part.Name == "HumanoidRootPart" and model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not model:GetAttribute("Invulnerable") then
			local toward = flat(part.Position - root.Position)
			if toward.Magnitude > 0.1 then
				local angle = math.deg(math.acos(math.clamp(toward.Unit:Dot(wanted), -1, 1)))
				if angle <= cone and (not bestAngle or angle < bestAngle) then
					best, bestAngle = part, angle
				end
			end
		end
	end
	return best
end

-- draws `spec` for `character` aiming at `aim`; call every frame while held
function AimIndicator.Draw(spec, character, aim, color)
	used = 0
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and spec then
		refreshGroundFilter()
		local origin = groundAt(root.Position)
		local ahead = flat(aim - root.Position)
		if ahead.Magnitude < 0.1 then
			ahead = flat(root.CFrame.LookVector)
		end
		ahead = ahead.Unit

		if spec.kind == "line" then
			local tip = origin + ahead * spec.length
			bar(origin, tip, color, LINE_WIDTH, EDGE_TRANSPARENCY)
			disc(tip, 1.2, color, 0.4)
		elseif spec.kind == "lock" then
			local target = AimIndicator.LockTarget(character, aim, spec.range, spec.cone)
			if target then
				local feet = groundAt(target.Position)
				bar(origin, Vector3.new(feet.X, origin.Y, feet.Z), color, LINE_WIDTH, EDGE_TRANSPARENCY)
				circle(feet, LOCK_RING_RADIUS, color)
			else
				bar(origin, origin + ahead * spec.range, color, LINE_WIDTH, FAINT_TRANSPARENCY)
			end
		elseif spec.kind == "circle" then
			local reach = flat(aim - root.Position)
			if reach.Magnitude > spec.range then
				reach = reach.Unit * spec.range
			end
			circle(groundAt(root.Position + reach), spec.radius, color)
		elseif spec.kind == "path" then
			local count = spec.count or 1
			for i = 1, count do
				local turn = math.rad((i - (count + 1) / 2) * (spec.spread or 0))
				local direction = (CFrame.Angles(0, turn, 0) * CFrame.new(Vector3.zero, ahead)).LookVector
				local start = origin + direction * TORNADO_START
				bar(start, start + direction * (spec.length - TORNADO_START), color, LINE_WIDTH * 1.6, EDGE_TRANSPARENCY)
				disc(start, 2, color, 0.5)
			end
			if spec.radius then
				circle(origin, spec.radius, color)
			end
		elseif spec.kind == "fan" then
			for i = 1, spec.count do
				local turn = math.rad((i - (spec.count + 1) / 2) * spec.spread)
				local direction = (CFrame.Angles(0, turn, 0) * CFrame.new(Vector3.zero, ahead)).LookVector
				bar(origin, origin + direction * spec.length, color, LINE_WIDTH * 0.7, EDGE_TRANSPARENCY)
			end
		elseif spec.kind == "dash" then
			local reach = flat(aim - root.Position)
			if reach.Magnitude > spec.range then
				reach = reach.Unit * spec.range
			end
			local landing = groundAt(root.Position + reach)
			bar(origin, Vector3.new(landing.X, origin.Y, landing.Z), color, LINE_WIDTH, EDGE_TRANSPARENCY)
			circle(landing, 2, color)
		elseif spec.kind == "self" then
			circle(origin, spec.radius, color)
		end
	end
	for i = used + 1, #pool do
		pool[i].Transparency = 1
	end
end

function AimIndicator.Hide()
	used = 0
	for _, part in ipairs(pool) do
		part.Transparency = 1
	end
end

return AimIndicator
