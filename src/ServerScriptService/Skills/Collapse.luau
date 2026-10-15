-- Aido X, Collapse: an implosion at the aim point. Everyone within Radius is
-- pulled to the centre for PullTime and hurt PullTicks times on the way in (the
-- damage lands on everyone in reach, pulled or not), then a compression blast
-- goes off at the centre. Players are only pulled when CrowdControl allows
-- (held with Begin/End like Event Horizon), and flying characters never are.
-- Every pull is let go of by the end, whatever happens to the caster or the
-- ones pulled. SkillSetServer checks the tool, mastery and cooldown first.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local AidoUtil = require(ServerScriptService:WaitForChild("AidoUtil"))
local CrowdControl = require(ServerScriptService:WaitForChild("CrowdControl"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Quests = require(ServerScriptService:WaitForChild("Quests"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local SET_NAME = "Aido"
local CONFIG = {
	Range = 60, -- studs from the caster
	Radius = 20, -- studs pulled and hurt (times the form's blastScale)
	PullTime = 0.6, -- seconds
	PullTicks = 3, -- damage ticks, evenly through the pull
	TickDamage = 4, -- before the caster's Superliminal bonus
	MaxPullSpeed = 90, -- studs per second
	BlastRadius = 10,
	BlastDamage = 25,
	CentreHeight = 3, -- studs above the ground the pull aims at
}
local TICK_OPTIONS = { stat = "Superliminal", skillSet = SET_NAME, guard = "unblockable", skill = "X" }

local function attachPull(root)
	local attachment = Instance.new("Attachment")
	attachment.Name = "CollapsePull"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "CollapsePull"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	-- a hold a player can dodge out of: their client lets go of it at once (Dash)
	velocity:SetAttribute("Hold", true)
	velocity.Parent = root
	return { attachment = attachment, velocity = velocity, root = root }
end

local function release(humanoid, pull)
	pull.velocity:Destroy()
	pull.attachment:Destroy()
	CrowdControl.End(humanoid.Parent)
end

local function run(player, character, centre, reach)
	local pulls = {}
	local pulled = 0
	for _, target in ipairs(AidoUtil.enemiesWithin(character, centre, reach)) do
		local model = target.model
		if not target.root.Anchored and model:GetAttribute("Flying") ~= true and CrowdControl.CanControl(model) then
			pulls[target.humanoid] = attachPull(target.root)
			CrowdControl.Begin(model)
			pulled += 1
		end
	end
	if player.Parent then
		Quests.Report(player, SET_NAME, "CollapsePull", pulled)
	end
	local ok, err = pcall(function()
		local startedAt = os.clock()
		local ticks = 0
		while true do
			local elapsed = os.clock() - startedAt
			local left = math.max(CONFIG.PullTime - elapsed, 0.05)
			for humanoid, pull in pairs(pulls) do
				local root = pull.root
				if not root.Parent or humanoid.Health <= 0 or not CrowdControl.Holding(humanoid.Parent) then
					release(humanoid, pull)
					pulls[humanoid] = nil
				else
					local toward = centre - root.Position
					if toward.Magnitude > 0.05 then
						pull.velocity.VectorVelocity = toward.Unit * math.min(toward.Magnitude / left, CONFIG.MaxPullSpeed)
					else
						pull.velocity.VectorVelocity = Vector3.zero
					end
				end
			end
			while ticks < CONFIG.PullTicks and elapsed >= CONFIG.PullTime * (ticks + 1) / CONFIG.PullTicks - 1e-3 do
				ticks += 1
				for _, target in ipairs(AidoUtil.enemiesWithin(character, centre, reach)) do
					Damage.Deal(player, target.humanoid, CONFIG.TickDamage, TICK_OPTIONS)
				end
			end
			if elapsed >= CONFIG.PullTime then
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
	for humanoid, pull in pairs(pulls) do
		release(humanoid, pull)
	end
	if not ok then
		warn("[Skills.Collapse] " .. tostring(err))
		return
	end
	AidoUtil.blast(player, character, centre, {
		radius = CONFIG.BlastRadius,
		damage = CONFIG.BlastDamage,
		form = true,
		aftershocks = true,
		guard = "unblockable",
		skill = "X",
		kind = "CollapseBlast",
	})
end

local Collapse = {}

function Collapse.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return false
	end
	local ground = AidoUtil.groundAt(AidoUtil.clampFlat(root.Position, aim, CONFIG.Range), { character })
	local centre = ground + Vector3.new(0, CONFIG.CentreHeight, 0)
	local reach = CONFIG.Radius
	if SkillSetConfig.InForm(character, SET_NAME) then
		reach *= SkillSetConfig.Sets[SET_NAME].form.blastScale
	end
	skillEffects:FireAllClients("CollapsePull", ground, reach, CONFIG.PullTime)
	task.spawn(run, player, character, centre, reach)
	return true
end

return Collapse
