-- Photoshop Z, Snapshot: a camera flash locks onto the enemy nearest where
-- she aimed (within Range and Cone; the skill bar's preview picks the same
-- one), hurts them and Frames them (Framed). While someone she Framed is
-- still framed, Z again is Step In (Recast): she's cut out of where she
-- stands and pasted BehindDistance studs behind them, facing them, or in
-- front of them when a wall is at their back. Over a drop, or beside
-- someone flying, she's put at their height rather than at the bottom.
-- Landing, she throws three quick punches (ComboHits) at whoever is in front
-- of her at each one, so a target who dashes off makes the rest miss; the
-- last knocks back. Clients draw it from the SkillEffects "Snapshot",
-- "StepIn" and "PhotoshopPunchHit" events, and the caster's arms from
-- "StepInCombo". SkillSetServer checks the tool, mastery and cooldown
-- before calling Cast.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CrowdControl = require(ServerScriptService:WaitForChild("CrowdControl"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Framed = require(ServerScriptService:WaitForChild("Framed"))
local PhotoshopUtil = require(ServerScriptService:WaitForChild("PhotoshopUtil"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Range = 100, -- studs, the lock's reach (SkillSetConfig's aim shows the same)
	Cone = 30, -- degrees either side of the aim it locks onto a target in
	Damage = 12, -- before the caster's Superliminal bonus
	StepRange = 110, -- studs from her a framed target can be for Step In (past Range, so anyone she framed)
	BehindDistance = 4, -- studs behind them she lands
	MaxDrop = 6, -- studs below them the ground there may be; past that (a cliff edge, a flier) she stays at their height
	WatchInterval = 0.1, -- seconds between checks that the frame is still on
	-- Step In's punches, before the Superliminal bonus; the last is a critical
	ComboHits = { 8, 8, 14 },
	ComboInterval = 0.15, -- seconds before each punch
	ComboReach = 6, -- studs in front of her a punch reaches
	ComboWidth = 5, -- studs across
	ComboKnockback = 40, -- studs per second the last punch throws them
	ComboKnockbackTime = 0.3, -- seconds the throw lasts
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "Photoshop" }
local RECAST = SkillSetConfig.RecastAttribute("Photoshop", "Z")

local watching = setmetatable({}, { __mode = "k" }) -- player -> the frame being watched

-- Step In stays on Z for as long as the frame does (Shutter can stretch it)
local function watchFrame(player, model)
	local token = {}
	watching[player] = token
	player:SetAttribute(RECAST, true)
	task.spawn(function()
		while watching[player] == token and player.Parent and Framed.Has(player, model) do
			task.wait(CONFIG.WatchInterval)
		end
		if watching[player] == token then
			watching[player] = nil
			player:SetAttribute(RECAST, nil)
		end
	end)
end

-- the first living character in front of her, within a punch's reach
local function inFront(character, root)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local box = root.CFrame * CFrame.new(0, 0, -CONFIG.ComboReach / 2)
	for _, part in ipairs(workspace:GetPartBoundsInBox(box, Vector3.new(CONFIG.ComboWidth, 6, CONFIG.ComboReach), overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local target = model and model:FindFirstChildOfClass("Humanoid")
		if target and target.Health > 0 and target.RootPart then
			return model, target
		end
	end
	return nil
end

-- thrown along `direction` for a moment (a constraint, so it moves players too)
local function knockBack(root, direction)
	local attachment = Instance.new("Attachment")
	attachment.Name = "StepInKnockback"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "StepInKnockback"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = direction * CONFIG.ComboKnockback
	velocity.Parent = root
	Debris:AddItem(velocity, CONFIG.ComboKnockbackTime)
	Debris:AddItem(attachment, CONFIG.ComboKnockbackTime)
end

-- Step In's punches, each ComboInterval after the last, while she's still
-- standing with Photoshop out
local function combo(player, character, humanoid)
	for i, amount in ipairs(CONFIG.ComboHits) do
		task.wait(CONFIG.ComboInterval)
		local root = humanoid.RootPart
		if not root or not PhotoshopUtil.alive(player, character, humanoid) then
			return
		end
		local last = i == #CONFIG.ComboHits
		local model, target = inFront(character, root)
		if target then
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			local direction = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
			skillEffects:FireAllClients("PhotoshopPunchHit", target.RootPart.Position - direction * 0.8, last)
			local landed = Damage.Deal(player, target, amount, { stat = "Superliminal", skillSet = "Photoshop", melee = true, critical = last })
			-- a hit a passive erased doesn't throw them; players only without hold protection
			if last and landed > 0 and target.Health > 0 and not target.RootPart.Anchored and CrowdControl.CanControl(model) then
				knockBack(target.RootPart, direction)
				CrowdControl.Apply(model, CONFIG.ComboKnockbackTime)
			end
		end
	end
end

local Snapshot = {}

-- returns false with nobody to lock onto, so no cooldown is spent
function Snapshot.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return false
	end
	local targetRoot = PhotoshopUtil.lockOn(character, root, aim, CONFIG.Range, CONFIG.Cone)
	if not targetRoot then
		return false
	end
	local model = targetRoot.Parent
	skillEffects:FireAllClients("Snapshot", character, model)
	Damage.Deal(player, model:FindFirstChildOfClass("Humanoid"), CONFIG.Damage, DAMAGE_OPTIONS)
	if Framed.Mark(player, model) then
		watchFrame(player, model)
	end
	return true
end

-- Step In: behind the framed target nearest her
function Snapshot.Recast(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return
	end
	local model = Framed.Nearest(player, root.Position, CONFIG.StepRange)
	local targetRoot = model and model:FindFirstChildOfClass("Humanoid") and model:FindFirstChildOfClass("Humanoid").RootPart
	if not targetRoot then
		return
	end
	local look = targetRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, model }
	params.RespectCanCollide = true
	-- behind them, else in front; a side with a wall in the way is out
	local sides = {}
	for _, side in ipairs({ -look, look }) do
		local spot = targetRoot.Position + side * CONFIG.BehindDistance
		if not workspace:Raycast(targetRoot.Position, spot - targetRoot.Position, params) then
			table.insert(sides, spot)
		end
	end
	if #sides == 0 then
		return -- walled in on both sides
	end
	-- ground near their height on the first side that has it; over a drop
	-- (or beside someone flying) she lands in the air beside them and falls
	local landing = sides[1]
	for _, spot in ipairs(sides) do
		local ground = PhotoshopUtil.groundAt(spot, { character, model })
		if ground and ground.Y >= targetRoot.Position.Y - CONFIG.MaxDrop then
			landing = ground
			break
		end
	end
	local from = root.Position
	local facing = Vector3.new(targetRoot.Position.X, landing.Y, targetRoot.Position.Z)
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(CFrame.lookAt(landing, facing))
	skillEffects:FireAllClients("StepIn", character, from, landing)
	watching[player] = nil
	player:SetAttribute(RECAST, nil)
	-- her arms throw the punches on her own screen
	skillEffects:FireClient(player, "StepInCombo", character, #CONFIG.ComboHits, CONFIG.ComboInterval)
	task.spawn(combo, player, character, humanoid)
end

return Snapshot
