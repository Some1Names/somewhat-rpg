-- Photoshop Z, Snapshot: a camera flash locks onto the enemy nearest where
-- she aimed (within Range and Cone; the skill bar's preview picks the same
-- one), hurts them and Frames them (Framed). While someone she Framed is
-- still framed, Z again is Step In (Recast): she's cut out of where she
-- stands and pasted BehindDistance studs behind them, facing them, or in
-- front of them when a wall is at their back. Over a drop, or beside
-- someone flying, she's put at their height rather than at the bottom. Clients draw it from the
-- SkillEffects "Snapshot" and "StepIn" events. SkillSetServer checks the
-- tool, mastery and cooldown before calling Cast.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

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
end

return Snapshot
