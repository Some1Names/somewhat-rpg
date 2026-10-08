-- Mandela Z, Axe Boomerang: the axe leaves the caster's right hand spinning
-- flat, flies out toward where they aimed, up or down (stopping short of walls),
-- then homes back to their hand. It hits everyone it passes once on the way
-- out (leaving them Bleeding) and once on the way back, and the return hit drags them a little
-- toward the caster and leaves them exposed to the caster's next axe finisher. Until it's caught the worn axe is hidden and axe swings
-- are off (the character's WeaponThrown attribute). Pressing Z again while
-- it's flying out recalls it (Recast): it turns back from where it is. Clients
-- draw the flight from the SkillEffects "AxeThrow" event along the same path
-- (WeaponRecalled tells them it turned early). While Mandela is overcharged,
-- Z is Spine Lash instead (Skills.SpineLash).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CrowdControl = require(ServerScriptService:WaitForChild("CrowdControl"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local StatusEffects = require(ServerScriptService:WaitForChild("StatusEffects"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Range = 42, -- studs out
	OutSpeed = 55, -- average studs per second out: quick off the hand, slowing at the far end
	ReturnSpeed = 85, -- studs per second back to the hand
	MaxFlightTime = 4, -- seconds before it's back in hand regardless
	CatchDistance = 2.5, -- studs from the hand that count as caught
	WallMargin = 1.5, -- studs it stops short of a wall
	HitRadius = 4,
	Damage = 16, -- per pass, before the caster's Superliminal bonus
	DragSpeed = 35, -- studs per second toward the caster on the return hit
	DragTime = 0.2,
	ReleaseDelay = 0.12, -- lines the throw up with the cast animation's release
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "Mandela" }
local THROWN_ATTRIBUTE = "WeaponThrown"
local RECALLED_ATTRIBUTE = "WeaponRecalled"
local RECALL_ATTRIBUTE = SkillSetConfig.RecastAttribute("Mandela", "Z") -- on the player, for the skill bar
local WEAPON_NAME = "Axe"
local WEARABLES_FOLDER = "SkillSetWearables"
local COLOR = SkillSetConfig.Sets.Mandela.color
local LINKS = SkillSetConfig.Sets.Mandela.links

local flights = {} -- character -> { recalled } while its axe is in the air

-- the out leg, shared with the client: quick off the hand, easing to a stop
local function outPosition(from, to, progress)
	return from + (to - from) * (1 - (1 - progress) ^ 2)
end

-- first thing in the way that isn't a character (it flies through those)
local function firstWall(from, offset, character)
	local ignore = { character }
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

-- hides the worn axe while it's in the air, remembering how it looked
local function setWornHidden(character, hidden)
	local folder = character:FindFirstChild(WEARABLES_FOLDER)
	local axe = folder and folder:FindFirstChild(WEAPON_NAME)
	if not axe then
		return
	end
	for _, instance in ipairs({ axe, table.unpack(axe:GetDescendants()) }) do
		if instance:IsA("BasePart") then
			if hidden then
				instance:SetAttribute("ShownTransparency", instance:GetAttribute("ShownTransparency") or instance.Transparency)
				instance.Transparency = 1
			elseif instance:GetAttribute("ShownTransparency") then
				instance.Transparency = instance:GetAttribute("ShownTransparency")
			end
		elseif instance:IsA("ParticleEmitter") or instance:IsA("Light") then
			if hidden then
				if instance:GetAttribute("ShownEnabled") == nil then
					instance:SetAttribute("ShownEnabled", instance.Enabled)
				end
				instance.Enabled = false
			elseif instance:GetAttribute("ShownEnabled") ~= nil then
				instance.Enabled = instance:GetAttribute("ShownEnabled")
			end
		end
	end
end

local function drag(root, toward)
	local flat = Vector3.new(toward.X - root.Position.X, 0, toward.Z - root.Position.Z)
	if flat.Magnitude < 3 then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "AxeDrag"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "AxeDrag"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = flat.Unit * CONFIG.DragSpeed
	velocity.Parent = root
	Debris:AddItem(velocity, CONFIG.DragTime)
	Debris:AddItem(attachment, CONFIG.DragTime)
end

-- everyone within reach of the axe that this pass hasn't hit yet
local function hitAround(position, overlap, alreadyHit, onHit)
	for _, part in ipairs(workspace:GetPartBoundsInRadius(position, CONFIG.HitRadius, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid and not alreadyHit[humanoid] and humanoid.Health > 0 then
			alreadyHit[humanoid] = true
			onHit(humanoid)
		end
	end
end

-- puts everything back once the axe is in hand (or the throw went wrong)
local function caught(player, character)
	flights[character] = nil
	player:SetAttribute(RECALL_ATTRIBUTE, nil)
	character:SetAttribute(RECALLED_ATTRIBUTE, nil)
	character:SetAttribute(THROWN_ATTRIBUTE, nil)
	setWornHidden(character, false)
end

local function fly(player, character, from, to, outTime)
	local flight = { recalled = false }
	flights[character] = flight
	player:SetAttribute(RECALL_ATTRIBUTE, true)
	local hand = character:FindFirstChild("RightHand")
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local hitOut, hitBack = {}, {}
	local ok, err = pcall(function()
		local startedAt = os.clock()
		local position = from
		local dt = 0
		while character.Parent and hand and hand.Parent do
			local t = os.clock() - startedAt
			if t >= CONFIG.MaxFlightTime then
				break
			end
			if t < outTime and not flight.recalled then
				position = outPosition(from, to, t / outTime)
				hitAround(position, overlap, hitOut, function(humanoid)
					if Damage.Deal(player, humanoid, CONFIG.Damage, DAMAGE_OPTIONS) > 0 then
						-- the out hit cuts
						StatusEffects.Apply(humanoid, "Bleeding", { source = player, stat = "Superliminal", skillSet = "Mandela" })
					end
				end)
			else
				-- homing back to wherever the hand is now (from where it was, if recalled)
				local offset = hand.Position - position
				if offset.Magnitude <= CONFIG.CatchDistance then
					break
				end
				position += offset.Unit * math.min(CONFIG.ReturnSpeed * dt, offset.Magnitude)
				hitAround(position, overlap, hitBack, function(humanoid)
					Damage.Deal(player, humanoid, CONFIG.Damage, DAMAGE_OPTIONS)
					local model = humanoid.Parent
					Damage.Expose(player, model, LINKS.exposedDuration)
					if humanoid.RootPart and not humanoid.RootPart.Anchored and CrowdControl.CanControl(model) then
						drag(humanoid.RootPart, hand.Position)
						CrowdControl.Apply(model, CONFIG.DragTime)
					end
				end)
			end
			dt = RunService.Heartbeat:Wait()
		end
	end)
	caught(player, character)
	if not ok then
		warn("[Skills.AxeBoomerang] " .. tostring(err))
	end
end

local function throw(player, character, aim)
	task.wait(CONFIG.ReleaseDelay)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	local hand = character:FindFirstChild("RightHand")
	if not root or not hand or humanoid.Health <= 0 then
		character:SetAttribute(THROWN_ATTRIBUTE, nil)
		return
	end
	local from = hand.Position
	-- toward where they aimed (SkillBar raises a point on the floor to chest
	-- height), or straight ahead if that's right at the hand
	local toward = aim - from
	if Vector3.new(toward.X, 0, toward.Z).Magnitude < 2 then
		toward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	local direction = toward.Unit
	local distance = CONFIG.Range
	local wall = firstWall(from, direction * CONFIG.Range, character)
	if wall then
		distance = math.max((wall - from).Magnitude - CONFIG.WallMargin, 0)
	end
	local to = from + direction * distance
	local outTime = math.max(distance / CONFIG.OutSpeed, 0.15)
	skillEffects:FireAllClients("AxeThrow", character, from, to, workspace:GetServerTimeNow(), outTime, CONFIG.ReturnSpeed, COLOR)
	setWornHidden(character, true)
	fly(player, character, from, to, outTime)
end

local AxeBoomerang = {}

-- returns false while the axe is still out (or not worn), so no cooldown is spent
function AxeBoomerang.Cast(player, character, aim)
	local folder = character:FindFirstChild(WEARABLES_FOLDER)
	if character:GetAttribute(THROWN_ATTRIBUTE) or not (folder and folder:FindFirstChild(WEAPON_NAME)) then
		return false
	end
	if not character:FindFirstChild("RightHand") then
		return false
	end
	-- swings stop from the moment of the throw, not just the release
	character:SetAttribute(THROWN_ATTRIBUTE, true)
	task.spawn(function()
		local ok, err = pcall(throw, player, character, aim)
		if not ok then
			-- never leave the axe stuck out of reach
			caught(player, character)
			warn("[Skills.AxeBoomerang] " .. tostring(err))
		end
	end)
	return true
end

-- Z again while it's out: it turns back for the hand from where it is
function AxeBoomerang.Recast(player, character)
	local flight = flights[character]
	if flight and not flight.recalled then
		flight.recalled = true
		character:SetAttribute(RECALLED_ATTRIBUTE, true)
	end
end

return AxeBoomerang
