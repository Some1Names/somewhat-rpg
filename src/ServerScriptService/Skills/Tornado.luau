-- Mandela C, the tornado: it spins up a few studs in front of the caster and
-- wanders off the way they aimed. Anyone it reaches is dragged into a rising
-- spiral around it and hurt every few moments, and when it bursts at the end
-- they're all flung outward. While Mandela is overcharged the cast first
-- blasts everyone near the caster away, then splits into three red-tinged
-- tornadoes fanning out. Players protected by CrowdControl aren't carried or
-- thrown, only hurt as it passes, and a carried player is dropped after
-- CrowdControl's MaxHold or as soon as they dodge. Clients draw them from the same path (see
-- the template's ClientEffect). SkillSetServer checks the tool, mastery and
-- cooldown before calling Cast.
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local CrowdControl = require(ServerScriptService:WaitForChild("CrowdControl"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Overcharge = require(ServerScriptService:WaitForChild("Overcharge"))

local skillEffects = game:GetService("ReplicatedStorage"):WaitForChild("SkillEffects")

local CONFIG = {
	Duration = 5, -- seconds
	GrowTime = 0.5,
	StartDistance = 9, -- studs in front of the caster
	Speed = 16, -- studs per second
	WobbleAmplitude = 4, -- studs it sways side to side
	WobbleFrequency = 2.2, -- radians per second
	SizeFraction = 0.5, -- of the template's size
	CatchRadius = 15, -- studs from its middle that it grabs
	CatchHeight = 24, -- studs above its base that it grabs
	OrbitRadius = 7, -- studs from its middle that caught targets circle
	OrbitSpeed = 30, -- studs per second round
	RiseRate = 6, -- studs per second the orbit climbs
	MaxLift = 15, -- studs above the base
	DamagePerTick = 5, -- before the caster's Superliminal bonus
	DamageInterval = 0.4,
	BurstDamage = 15,
	FlingSpeed = 75, -- studs per second outward when it bursts
	FlingLift = 45,
	FlingTime = 0.35,
	CleanupDelay = 0.6, -- seconds the model stays after so clients can play the burst
}
-- overcharged: three smaller tornadoes in a fan, after a blast around the caster
local OVERCHARGED = {
	Count = 3,
	SpreadDegrees = 35, -- between neighbouring tornadoes
	SizeFraction = 0.42,
	DamagePerTick = 6,
	BurstDamage = 20,
	Tint = Color3.fromRGB(255, 70, 80),
	TintAmount = 0.35, -- how far the funnel's grey shifts toward the tint
	BlastRadius = 20,
	BlastDamage = 30,
	BlastSpeed = 65,
	BlastLift = 50,
	BlastTime = 0.3,
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "Mandela" }
local SPIN_SIGN = 1 -- matches the spin of the template's layers

local template = ServerStorage:WaitForChild("SkillSets"):WaitForChild("Mandela"):WaitForChild("Tornado")

local function groundBelow(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 10, 0), Vector3.new(0, -200, 0), params)
	return hit and hit.Position or position - Vector3.new(0, 3, 0)
end

local function attachPull(root)
	local attachment = Instance.new("Attachment")
	attachment.Name = "TornadoPull"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "TornadoPull"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	-- a hold a player can dodge out of: their client lets go of it at once (Dash)
	velocity:SetAttribute("Hold", true)
	velocity.Parent = root
	return { attachment = attachment, velocity = velocity }
end

local function fling(root, from, speed, lift, time)
	local flat = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
	local outward = flat.Magnitude > 0.1 and flat.Unit or Vector3.xAxis
	local attachment = Instance.new("Attachment")
	attachment.Name = "TornadoFling"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "TornadoFling"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = outward * speed + Vector3.new(0, lift, 0)
	velocity.Parent = root
	Debris:AddItem(velocity, time)
	Debris:AddItem(attachment, time)
end

-- `settings`: sizeFraction, damagePerTick, burstDamage and an optional tint.
-- `claimed` is shared between tornadoes cast together, so each target is
-- only ever carried by one of them.
local function runTornado(caster, casterCharacter, start, direction, settings, claimed)
	local side = Vector3.new(direction.Z, 0, -direction.X)
	-- the client draws the same path
	local function basePosition(t)
		return start + direction * CONFIG.Speed * t + side * math.sin(t * CONFIG.WobbleFrequency) * CONFIG.WobbleAmplitude
	end
	local function baseVelocity(t)
		return direction * CONFIG.Speed + side * math.cos(t * CONFIG.WobbleFrequency) * CONFIG.WobbleFrequency * CONFIG.WobbleAmplitude
	end

	local model = template:Clone()
	local templateScale = model:GetScale()
	model:SetAttribute("StartedAt", workspace:GetServerTimeNow())
	model:SetAttribute("Duration", CONFIG.Duration)
	model:SetAttribute("GrowTime", CONFIG.GrowTime)
	model:SetAttribute("StartPosition", start)
	model:SetAttribute("Direction", direction)
	model:SetAttribute("Speed", CONFIG.Speed)
	model:SetAttribute("WobbleAmplitude", CONFIG.WobbleAmplitude)
	model:SetAttribute("WobbleFrequency", CONFIG.WobbleFrequency)
	model:SetAttribute("TemplateScale", templateScale)
	model:SetAttribute("FullScale", templateScale * settings.sizeFraction)
	-- clients show the caster an impact frame when it bursts
	model:SetAttribute("CasterUserId", caster.UserId)
	if settings.tint then
		model:SetAttribute("Tint", settings.tint)
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Color = part.Color:Lerp(settings.tint, OVERCHARGED.TintAmount)
			end
		end
	end
	-- starts tiny where it spawns; each client grows and moves it from there
	model:ScaleTo(templateScale * settings.sizeFraction * 0.05)
	model:PivotTo(CFrame.new(start))
	model.Parent = workspace

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { model, casterCharacter }

	local caught = {}
	local ok, err = pcall(function()
		local startedAt = os.clock()
		local nextDamageAt = startedAt + CONFIG.DamageInterval
		while true do
			local now = os.clock()
			local t = now - startedAt
			if t >= CONFIG.Duration then
				break
			end
			local base = basePosition(t)
			local growth = math.clamp(t / CONFIG.GrowTime, 0, 1)

			-- grab anyone new within reach (its reach grows with it)
			local reach = CONFIG.CatchRadius * growth * settings.sizeFraction / CONFIG.SizeFraction
			local middle = base + Vector3.new(0, CONFIG.CatchHeight / 2, 0)
			local grazing = {} -- protected players in reach this frame: hurt, not carried
			for _, part in ipairs(workspace:GetPartBoundsInRadius(middle, reach + CONFIG.CatchHeight / 2, overlap)) do
				local character = part:FindFirstAncestorOfClass("Model")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = humanoid and humanoid.RootPart
				if root and not caught[humanoid] and not claimed[humanoid] and humanoid.Health > 0 then
					local offset = root.Position - base
					if Vector3.new(offset.X, 0, offset.Z).Magnitude <= reach and offset.Y > -4 and offset.Y < CONFIG.CatchHeight then
						if CrowdControl.CanControl(character) then
							claimed[humanoid] = true
							caught[humanoid] = { root = root, caughtAt = now, pull = not root.Anchored and attachPull(root) or nil }
							CrowdControl.Begin(character)
						else
							grazing[humanoid] = true
						end
					end
				end
			end

			-- carry everyone caught round and up the funnel
			local travel = baseVelocity(t)
			for humanoid, entry in pairs(caught) do
				if not entry.root.Parent then
					caught[humanoid] = nil
					CrowdControl.End(humanoid.Parent)
				elseif not CrowdControl.Holding(humanoid.Parent) then
					-- a player whose hold is up (CrowdControl.MaxHold) or who dodged
					-- out drops from wherever they've got to; it can still graze them
					if entry.pull then
						entry.pull.velocity:Destroy()
						entry.pull.attachment:Destroy()
					end
					caught[humanoid] = nil
					claimed[humanoid] = nil
					CrowdControl.End(humanoid.Parent)
				elseif entry.pull then
					local offset = entry.root.Position - base
					local flat = Vector3.new(offset.X, 0, offset.Z)
					local distance = flat.Magnitude
					local outward = distance > 0.1 and flat.Unit or Vector3.xAxis
					local around = Vector3.new(outward.Z, 0, -outward.X) * SPIN_SIGN
					local lift = math.min(CONFIG.MaxLift, 3 + (now - entry.caughtAt) * CONFIG.RiseRate)
					local climb = math.clamp((lift - offset.Y) * 3, -10, 20)
					entry.pull.velocity.VectorVelocity = around * CONFIG.OrbitSpeed
						+ outward * (CONFIG.OrbitRadius - distance) * 4
						+ Vector3.new(0, climb, 0)
						+ travel
				end
			end

			if now >= nextDamageAt then
				nextDamageAt += CONFIG.DamageInterval
				for humanoid in pairs(caught) do
					Damage.Deal(caster, humanoid, settings.damagePerTick, DAMAGE_OPTIONS)
				end
				for humanoid in pairs(grazing) do
					Damage.Deal(caster, humanoid, settings.damagePerTick, DAMAGE_OPTIONS)
				end
			end
			RunService.Heartbeat:Wait()
		end
	end)

	-- the burst: one last hit and everyone thrown clear
	local finalBase = basePosition(CONFIG.Duration)
	for humanoid, entry in pairs(caught) do
		if entry.pull then
			entry.pull.velocity:Destroy()
			entry.pull.attachment:Destroy()
		end
		local flung = false
		if entry.root.Parent then
			Damage.Deal(caster, humanoid, settings.burstDamage, DAMAGE_OPTIONS)
			if not entry.root.Anchored then
				fling(entry.root, finalBase, CONFIG.FlingSpeed, CONFIG.FlingLift, CONFIG.FlingTime)
				flung = true
			end
		end
		if flung then
			CrowdControl.Apply(humanoid.Parent, CONFIG.FlingTime)
		else
			CrowdControl.End(humanoid.Parent)
		end
		claimed[humanoid] = nil
	end
	task.wait(CONFIG.CleanupDelay)
	model:Destroy()
	if not ok then
		warn("[Skills.Tornado] " .. tostring(err))
	end
end

local Tornado = {}

function Tornado.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root then
		return false
	end
	-- toward where they aimed, or straight ahead if that's right underfoot
	local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	if flat.Magnitude < 2 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	local direction = flat.Unit
	local claimed = {}

	if not Overcharge.IsActive(player, "Mandela") then
		local start = groundBelow(root.Position + direction * CONFIG.StartDistance, { character })
		local settings = { sizeFraction = CONFIG.SizeFraction, damagePerTick = CONFIG.DamagePerTick, burstDamage = CONFIG.BurstDamage }
		task.spawn(runTornado, player, character, start, direction, settings, claimed)
		return true
	end

	-- overcharged: blast everyone close by away first
	local feet = groundBelow(root.Position, { character })
	skillEffects:FireAllClients("Shockwave", feet, OVERCHARGED.BlastRadius, OVERCHARGED.Tint)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local blasted = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, OVERCHARGED.BlastRadius, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local target = model and model:FindFirstChildOfClass("Humanoid")
		if target and not blasted[target] and target.Health > 0 and target.RootPart then
			blasted[target] = true
			Damage.Deal(player, target, OVERCHARGED.BlastDamage, DAMAGE_OPTIONS)
			if not target.RootPart.Anchored and CrowdControl.CanControl(model) then
				fling(target.RootPart, root.Position, OVERCHARGED.BlastSpeed, OVERCHARGED.BlastLift, OVERCHARGED.BlastTime)
				CrowdControl.Apply(model, OVERCHARGED.BlastTime)
			end
		end
	end

	-- then three tornadoes fanning out
	local settings = {
		sizeFraction = OVERCHARGED.SizeFraction,
		damagePerTick = OVERCHARGED.DamagePerTick,
		burstDamage = OVERCHARGED.BurstDamage,
		tint = OVERCHARGED.Tint,
	}
	for i = 1, OVERCHARGED.Count do
		local turn = math.rad((i - (OVERCHARGED.Count + 1) / 2) * OVERCHARGED.SpreadDegrees)
		local fanned = (CFrame.Angles(0, turn, 0) * CFrame.new(Vector3.zero, direction)).LookVector
		local start = groundBelow(root.Position + fanned * CONFIG.StartDistance, { character })
		task.spawn(runTornado, player, character, start, fanned, settings, claimed)
	end
	return true
end

return Tornado
