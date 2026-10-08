-- Mandela's ranged move, Knife: a knife thrown where he aimed, tumbling end
-- over end into the first person or wall it meets (steering into `target`
-- when aim assist locked it on). RangedServer has already checked the throw
-- and spent a charge.
-- Pinned: StreakHits knives from the same thrower in a row on someone (each
-- within StreakWindow of the last) stun them for StunTime, frozen where they
-- are (in the air too), and leave them Weakened and Bleeding (BleedStacks
-- stacks); then the count starts over. A player still protected by
-- CrowdControl isn't stunned but gets the rest. Clients draw it from the
-- SkillEffects "KnifePin" event.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CrowdControl = require(ServerScriptService:WaitForChild("CrowdControl"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Projectiles = require(ServerScriptService:WaitForChild("Projectiles"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatusEffects = require(ServerScriptService:WaitForChild("StatusEffects"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Damage = 14, -- before the thrower's Superliminal bonus
	StreakHits = 3,
	StreakWindow = 4, -- seconds a hit keeps the count going
	StunTime = 1, -- seconds
	BleedStacks = 2,
}
local STATUS_OPTIONS = { stat = "Superliminal", skillSet = "Mandela" }

-- thrower -> { [humanoid] = { count, at } }
local streaks = setmetatable({}, { __mode = "k" })

-- frozen in place for a moment, mid-air included (anchored roots are left as they were)
local function stun(root)
	if root.Anchored then
		return
	end
	root.Anchored = true
	task.delay(CONFIG.StunTime, function()
		if root.Parent then
			root.Anchored = false
		end
	end)
end

local function pin(player, humanoid)
	local model = humanoid.Parent
	local root = humanoid.RootPart
	if not model or not root then
		return
	end
	local stunned = CrowdControl.CanControl(model)
	if stunned then
		stun(root)
		CrowdControl.Apply(model, CONFIG.StunTime)
	end
	StatusEffects.Apply(humanoid, "Weakened", { source = player, stat = STATUS_OPTIONS.stat, skillSet = STATUS_OPTIONS.skillSet })
	for _ = 1, CONFIG.BleedStacks do
		StatusEffects.Apply(humanoid, "Bleeding", { source = player, stat = STATUS_OPTIONS.stat, skillSet = STATUS_OPTIONS.skillSet })
	end
	skillEffects:FireAllClients("KnifePin", model, stunned and CONFIG.StunTime or 0)
end

-- counts a knife landing on `humanoid`; the StreakHits-th in a row pins them
local function countHit(player, humanoid)
	local mine = streaks[player]
	if not mine then
		mine = setmetatable({}, { __mode = "k" })
		streaks[player] = mine
	end
	local now = os.clock()
	local streak = mine[humanoid]
	if not streak or now - streak.at > CONFIG.StreakWindow then
		streak = { count = 0 }
		mine[humanoid] = streak
	end
	streak.count += 1
	streak.at = now
	if streak.count >= CONFIG.StreakHits then
		mine[humanoid] = nil
		if humanoid.Health > 0 then
			pin(player, humanoid)
		end
	end
end
-- a weapon hit, so physical
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "Mandela", melee = true }
local FLIGHT = SkillSetConfig.Sets.Mandela.ranged.projectile

local KnifeThrow = {}

function KnifeThrow.Fire(player, character, origin, direction, id, target)
	Projectiles.Launch({
		owner = player,
		character = character,
		id = id,
		model = FLIGHT.model,
		origin = origin,
		direction = direction,
		speed = FLIGHT.speed,
		range = FLIGHT.range,
		radius = FLIGHT.radius,
		spin = FLIGHT.spin,
		homing = target and target.RootPart,
		onHit = function(humanoid)
			if Damage.Deal(player, humanoid, CONFIG.Damage, DAMAGE_OPTIONS) > 0 then
				countHit(player, humanoid)
			end
		end,
	})
end

return KnifeThrow
