-- Mandela F, Place Where Dream Ends: the ultimate, only while overcharged.
-- The caster slams the axe down and a huge dome of mirror glass closes over
-- them (Radius): the wrong timeline. For Duration seconds every hit the
-- caster lands on anyone caught inside (or inside when it lands) is written
-- down. Then reality rewrites itself: everyone hit takes everything written
-- down on them again (times RewriteShare) in one critical hit no passive can
-- erase, plus OverchargeDamagePerSecond for every second of overcharge left,
-- which the Rewrite spends. The overcharge runs on until then, so
-- overcharged skills can fill the record. Hits written down on someone who
-- got out still count.
-- The glass is a real wall (tagged WallTag): walking or being knocked into
-- it stops you, but a dodge goes through (client Dash switches its collision
-- off for the dash and leaves it out of its wall checks; Lightstep flashes
-- past it). Being solid, it still stops raycasts and projectiles, like glass
-- would (CanQuery can't be turned off on a part that collides).
-- Clients draw it from the SkillEffects "Rewrite", "RewriteHit" and
-- "RewriteSnap" events.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Overcharge = require(ServerScriptService:WaitForChild("Overcharge"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Radius = 87.5, -- studs from the caster to the glass, every way
	Duration = 5, -- seconds of recording before the Rewrite
	ReleaseDelay = 0.35, -- lines the glass up with the axe slam
	RewriteShare = 1, -- of the recorded damage, dealt again
	OverchargeDamagePerSecond = 4, -- extra per target for each second of overcharge spent
	DomeRings = 5, -- rings of panes from the ground to the top
	PaneWidth = 26, -- studs, roughly; each ring gets as many panes as that needs
	SkirtDepth = 16, -- studs of glass straight down from the rim, for ground that dips
	WallThickness = 1,
	GhostsPerTarget = 3, -- frozen reflections a target can leave
}
local WALL_TAG = "RewriteWall"
local SET = SkillSetConfig.Sets.Mandela
local REWRITE_OPTIONS = { skillSet = "Mandela", critical = true, unerasable = true, rewrite = true }

local castCount = 0

local function groundBelow(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -100, 0), params)
	return hit and hit.Position or position - Vector3.new(0, 3, 0)
end

local function insideDome(position, center)
	return (position - center).Magnitude <= CONFIG.Radius
end

-- everyone alive inside when the glass closes
local function caughtInside(character, center)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local caught = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, CONFIG.Radius, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if root and not caught[humanoid] and humanoid.Health > 0 and insideDome(root.Position, center) then
			caught[humanoid] = true
		end
	end
	return caught
end

-- The dome of glass: a skirt going straight down from the rim (for ground
-- that dips), then DomeRings rings of flat panes up to the top, each pane
-- facing the middle and each ring offset half a pane from the one below.
-- Panes are as wide as their ring's lower edge, so they overlap rather than
-- leave gaps. Invisible here (clients draw the mirror), but solid.
local function buildDome(center)
	local wall = Instance.new("Model")
	wall.Name = "RewriteWall"
	wall.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local radius = CONFIG.Radius
	local frames, sizes = {}, {}
	local function addPane(frame, size)
		local pane = Instance.new("Part")
		pane.Name = "Pane"
		pane.Anchored = true
		pane.CanCollide = true
		pane.CanTouch = false
		pane.CastShadow = false
		pane.Transparency = 1
		pane.Size = size
		pane.CFrame = frame
		CollectionService:AddTag(pane, WALL_TAG)
		pane.Parent = wall
		table.insert(frames, frame)
		table.insert(sizes, size)
	end

	local skirtCount = math.ceil(2 * math.pi * radius / CONFIG.PaneWidth)
	for j = 1, skirtCount do
		local theta = j / skirtCount * math.pi * 2
		local out = Vector3.new(math.cos(theta), 0, math.sin(theta))
		local base = center + out * radius
		addPane(
			CFrame.lookAt(base, base - out) * CFrame.new(0, -CONFIG.SkirtDepth / 2, 0),
			Vector3.new(2 * math.pi * radius / skirtCount * 1.08, CONFIG.SkirtDepth, CONFIG.WallThickness)
		)
	end

	local step = (math.pi / 2) / CONFIG.DomeRings
	local height = 2 * radius * math.sin(step / 2) * 1.08 -- the chord across a ring, and a bit
	for i = 1, CONFIG.DomeRings do
		local low = (i - 1) * step
		local mid = low + step / 2
		local around = 2 * math.pi * radius * math.cos(low)
		local count = math.max(3, math.ceil(around / CONFIG.PaneWidth))
		local size = Vector3.new(around / count * 1.08, height, CONFIG.WallThickness)
		for j = 1, count do
			local theta = (j + (i % 2) * 0.5) / count * math.pi * 2
			local point = center
				+ Vector3.new(math.cos(mid) * math.cos(theta), math.sin(mid), math.cos(mid) * math.sin(theta)) * radius
			addPane(CFrame.lookAt(point, center), size)
		end
	end
	wall.Parent = workspace
	return wall, frames, sizes
end

local function run(player, character, state)
	task.wait(CONFIG.ReleaseDelay)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return
	end
	local color = SET.overcharge.color
	local center = groundBelow(root.Position, { character })
	local caught = caughtInside(character, center)
	local wall, frames, sizes = buildDome(center)
	state.wall = wall
	Debris:AddItem(wall, CONFIG.Duration + 5)
	castCount += 1
	local castId = castCount
	skillEffects:FireAllClients("Rewrite", castId, character, center, CONFIG.Radius, CONFIG.Duration, frames, sizes, color)

	-- the record: every hit the caster lands on someone caught, or on anyone inside
	local records = {}
	state.disconnect = Damage.OnDealt(function(attacker, target, dealt, options)
		if attacker ~= player or options.rewrite then
			return
		end
		local model = target.Parent
		local targetRoot = target.RootPart
		if not model or not targetRoot or not (caught[target] or insideDome(targetRoot.Position, center)) then
			return
		end
		local record = records[target]
		if not record then
			record = { model = model, total = 0, ghosts = 0 }
			records[target] = record
		end
		record.total += dealt
		if record.ghosts < CONFIG.GhostsPerTarget then
			record.ghosts += 1
			skillEffects:FireAllClients("RewriteHit", castId, model, color)
		end
	end)
	task.wait(CONFIG.Duration)
	state.disconnect()
	state.disconnect = nil

	-- reality rewrites itself (unless the caster didn't live to see it)
	local positions, models = {}, {}
	if humanoid.Health > 0 and character.Parent then
		local bonus = Overcharge.Spend(player, "Mandela") * CONFIG.OverchargeDamagePerSecond
		for target, record in pairs(records) do
			local targetRoot = target.RootPart
			if record.model.Parent and targetRoot and target.Health > 0 then
				Damage.Deal(player, target, record.total * CONFIG.RewriteShare + bonus, REWRITE_OPTIONS)
				table.insert(positions, targetRoot.Position)
				table.insert(models, record.model)
			end
		end
	end
	wall:Destroy()
	state.wall = nil
	skillEffects:FireAllClients("RewriteSnap", castId, center, CONFIG.Radius, positions, models, color)
end

local PlaceWhereDreamEnds = {}

PlaceWhereDreamEnds.WallTag = WALL_TAG

function PlaceWhereDreamEnds.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not humanoid.RootPart or not SkillSetConfig.IsOvercharged(player, "Mandela") then
		return false
	end
	task.spawn(function()
		local state = {}
		local ok, err = pcall(run, player, character, state)
		if not ok then
			warn("[Skills.PlaceWhereDreamEnds] " .. tostring(err))
		end
		-- never leave the wall standing or the record running
		if state.disconnect then
			state.disconnect()
		end
		if state.wall then
			state.wall:Destroy()
		end
	end)
	return true
end

return PlaceWhereDreamEnds
