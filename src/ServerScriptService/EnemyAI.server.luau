-- Enemies: NPCs tagged "Enemy". Each stays around the spot it spawned in:
-- knocked more than WANDER_RANGE away, it walks back. One with the FightsBack
-- attribute also turns on whoever hurts it: it chases them and swings at them
-- when in reach, until they leave its territory (LeashRange around its spot),
-- it's drawn out of it itself, it can't get any closer, or it loses them;
-- then it runs home without stopping to fight. Back home, a hurt enemy slowly
-- regains health until it's full or something hits it.
-- It waits while a skill is moving it, it's stunned, it's staggered by a melee
-- hit (HitstunUntil, which also cancels a quick swing it's winding up) or it's in
-- the air.
-- An enemy with a Level attribute gets its health and hit from that level
-- (StatConfig.EnemyHealth / EnemyDamage) when it spawns. One above
-- DASH_ABOVE_LEVEL also dashes at whoever it's chasing, once every
-- DASH_COOLDOWN seconds, when they're a few strides away.
-- An enemy whose EnemyType has an entry in EnemyConfig takes its settings from
-- there (a model's own attribute still wins). One with an AggroRange also goes
-- for any player who walks that close, inside its leash, without being hit; one
-- with an `attacks` combo swings those in order instead of rolling quick or heavy,
-- resting comboPause after the last, and a step with a `lunge` closes in on them.
-- Optional attributes on the model: EnemyType, FightsBack, MaxHealth, AttackDamage
-- (both otherwise from its Level), AttackRange, AttackCooldown, LeashRange,
-- ChaseSpeed, AggroRange, HeavyChance (0 to 1, the share of its swings that are slow heavy ones).
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatFeel = require(ReplicatedStorage:WaitForChild("CombatFeel"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Guard = require(ServerScriptService:WaitForChild("Guard"))
local Passives = require(ServerScriptService:WaitForChild("Passives"))
local EnemyAttackConfig = require(ReplicatedStorage:WaitForChild("EnemyAttackConfig"))
local EnemyConfig = require(ReplicatedStorage:WaitForChild("EnemyConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))
local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local TAG = "Enemy"
local TICK = 0.15 -- seconds between decisions
local WANDER_RANGE = 10 -- studs from its spot before an idle enemy walks back
local ARRIVE_DISTANCE = 1.5 -- studs from its spot that count as home
local STUCK_TIME = 12 -- seconds heading home before it's put back instead
local RETURN_SPEED = 26 -- studs per second running home after giving up a chase
local REGEN_PER_SECOND = 0.08 -- share of max health regained per second once back home
local GIVE_UP_DISTANCE = 70 -- studs between it and its target
local CHASE_STUCK_TIME = 3 -- seconds chasing without getting anywhere before it gives up
local REACH_TOLERANCE = 1.5 -- extra studs the target may have moved during the wind-up
local DASH_ABOVE_LEVEL = 25 -- enemies above this level can dash
local DASH_COOLDOWN = 30 -- seconds between dashes
local DASH_SPEED = 80 -- studs per second
local DASH_TIME = 0.4 -- longest a dash lasts, in seconds
local DASH_MIN_DISTANCE = 12 -- studs to the target; any closer it just walks
local DASH_MAX_DISTANCE = 40
local DEFAULTS = {
	AttackRange = 5, -- studs between it and its target
	AttackCooldown = 1.4, -- seconds between swings
	LeashRange = 45, -- studs from its spot it will chase to
	ChaseSpeed = 15, -- a little slower than a player walking
}
-- used when the model's own Animate script has none
local WALK_ANIMATIONS = {
	[Enum.HumanoidRigType.R6] = "rbxassetid://180426354",
	[Enum.HumanoidRigType.R15] = "rbxassetid://507777826",
}
local SLASH_ANIMATIONS = {
	[Enum.HumanoidRigType.R6] = "rbxassetid://129967390",
	[Enum.HumanoidRigType.R15] = "rbxassetid://522635514",
}

local function setting(model, key)
	return EnemyConfig.Setting(model:GetAttribute(key), model:GetAttribute("EnemyType"), key, DEFAULTS[key])
end

local function attackDamage(model)
	return model:GetAttribute("AttackDamage") or StatConfig.EnemyDamage(model:GetAttribute("Level") or 1)
end

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

-- from the model's own Animate script (which doesn't run on an NPC), or the default
local function animationFor(model, humanoid, childName, defaults)
	local animate = model:FindFirstChild("Animate")
	local holder = animate and animate:FindFirstChild(childName)
	local source = holder and holder:FindFirstChildOfClass("Animation")
	local animation = Instance.new("Animation")
	animation.AnimationId = source and source.AnimationId ~= "" and source.AnimationId or defaults[humanoid.RigType]
	return animation
end

local function run(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root then
		return
	end
	local home = root.CFrame
	local baseSpeed = humanoid.WalkSpeed
	local enemyType = model:GetAttribute("EnemyType")
	local entry = EnemyConfig.Get(enemyType)
	local aggroRange = EnemyConfig.Setting(model:GetAttribute("AggroRange"), enemyType, "AggroRange", nil)
	local aggroEntry = aggroRange and { AggroRange = aggroRange }
	-- as tough as its level says, unless it sets its own
	local level = model:GetAttribute("Level")
	local maxHealth = model:GetAttribute("MaxHealth") or (level and StatConfig.EnemyHealth(level))
	if maxHealth then
		humanoid.MaxHealth = maxHealth
		humanoid.Health = maxHealth
	end
	-- the server steers it, so the server simulates it
	pcall(root.SetNetworkOwner, root, nil)

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local walkTrack = animator:LoadAnimation(animationFor(model, humanoid, "walk", WALK_ANIMATIONS))
	walkTrack.Looped = true
	walkTrack.Priority = Enum.AnimationPriority.Movement
	local slashTrack = animator:LoadAnimation(animationFor(model, humanoid, "toolslash", SLASH_ANIMATIONS))
	slashTrack.Priority = Enum.AnimationPriority.Action

	local state = "idle" -- "idle", "chasing" or "returning"
	local target -- the player it's after while chasing
	local retreating = false -- running home after giving up, deaf to hits
	local returningSince = 0
	local nextAttackAt = 0
	local lastProgressAt = 0 -- while chasing: when it last got somewhere
	local lastPosition = root.Position
	local regenerating = false -- healing up at home; any hit stops it
	local lastTickAt = os.clock()
	local nextDashAt = 0
	local comboIndex = 1 -- the next step of its combo, if it has one

	-- a burst along the ground at the target, ending about in reach of them
	local function dashAt(direction, distance)
		local time = math.clamp((distance - setting(model, "AttackRange") + 1) / DASH_SPEED, 0.1, DASH_TIME)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
		local attachment = Instance.new("Attachment")
		attachment.Name = "EnemyDash"
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Name = "EnemyDash"
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		-- sideways only, so it stays on the ground
		velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		velocity.MaxAxesForce = Vector3.new(math.huge, 0, math.huge)
		velocity.VectorVelocity = direction * DASH_SPEED
		velocity.Parent = root
		Debris:AddItem(velocity, time)
		Debris:AddItem(attachment, time)
		skillEffects:FireAllClients("EnemyDash", root, time)
	end

	local function goHome(retreat)
		state = "returning"
		target = nil
		retreating = retreat
		comboIndex = 1
		returningSince = os.clock()
		humanoid.WalkSpeed = retreat and RETURN_SPEED or baseSpeed
		humanoid:MoveTo(home.Position)
	end

	local function arrive(placeAt)
		state = "idle"
		humanoid.WalkSpeed = baseSpeed
		humanoid:MoveTo(root.Position)
		root.AssemblyLinearVelocity = Vector3.zero
		-- facing the way it started
		root.CFrame = placeAt or CFrame.new(root.Position) * home.Rotation
		regenerating = humanoid.Health < humanoid.MaxHealth
		retreating = false
	end

	local function staggered()
		return (model:GetAttribute("HitstunUntil") or 0) > workspace:GetServerTimeNow()
	end

	-- the next step of its combo, or else quick or heavy (EnemyAttackConfig) with
	-- no heavy after a heavy. Returns whether this swing ends its combo.
	local lastWasHeavy = false
	local function swingAt(targetHumanoid, targetRoot)
		local step, nextIndex, finishes = EnemyConfig.NextAttack(entry, comboIndex)
		local attackType
		if step then
			comboIndex = nextIndex
			attackType = step.type
		else
			local chance = EnemyAttackConfig.Chance(EnemyConfig.Setting(model:GetAttribute("HeavyChance"), enemyType, "HeavyChance", nil))
			attackType = EnemyAttackConfig.Choose(math.random(), chance, lastWasHeavy)
			lastWasHeavy = attackType == "heavy"
		end
		local attack = EnemyAttackConfig.Get(attackType)
		-- a lunge closes the gap during the wind-up
		if step and step.lunge then
			local gap = flat(targetRoot.Position - root.Position)
			if gap.Magnitude > 3 then
				dashAt(gap.Unit, step.lunge + setting(model, "AttackRange") - 1)
			end
		end
		slashTrack:Play(0.1)
		skillEffects:FireAllClients("Telegraph", model, attackType, attack.windUp)
		task.delay(attack.windUp, function()
			-- it may have been stunned, staggered or killed, or the target got away, during the wind-up
			local ownRoot = humanoid.RootPart
			if not ownRoot or ownRoot.Anchored or humanoid.Health <= 0 or targetHumanoid.Health <= 0 or not targetRoot.Parent then
				return
			end
			-- (a heavy swing can't be staggered out of)
			if staggered() and not attack.uninterruptible then
				slashTrack:Stop(0.05)
				return
			end
			-- nothing lands on someone untouchable right now (Lightstep)
			if targetHumanoid.Parent and targetHumanoid.Parent:GetAttribute("Invulnerable") then
				return
			end
			-- nor on someone in the i-frames of a dash
			if targetHumanoid.Parent and CombatFeel.InDodge(targetHumanoid.Parent:GetAttribute("DodgeUntil"), workspace:GetServerTimeNow()) then
				skillEffects:FireAllClients("Dodge", targetHumanoid.Parent)
				return
			end
			if (targetRoot.Position - ownRoot.Position).Magnitude <= setting(model, "AttackRange") + REACH_TOLERANCE then
				-- a player's passive may erase the hit
				local amount = attackDamage(model) * attack.damage * (step and step.damage or 1) * StatusConfig.OutgoingMultiplier(model) -- softer while Weakened
				local victim = Players:GetPlayerFromCharacter(targetHumanoid.Parent)
				if victim then
					Guard.MarkCombat(victim.Character)
					-- a block cuts it first, then the passive
					amount = Guard.Resolve(victim.Character, amount, "melee", ownRoot.Position, model)
					amount = Passives.Absorb(victim, amount, true) -- a swing is physical
				end
				if amount > 0 then
					targetHumanoid:TakeDamage(amount)
				end
			end
		end)
		return finishes == true
	end

	-- the nearest living player inside its aggro range and its territory
	local function findAggroTarget()
		local best, bestDistance
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local theirHumanoid = character and character:FindFirstChildOfClass("Humanoid")
			local theirRoot = theirHumanoid and theirHumanoid.RootPart
			if theirRoot and theirHumanoid.Health > 0 and not character:GetAttribute("Invulnerable") then
				local distance = (theirRoot.Position - root.Position).Magnitude
				if
					EnemyConfig.InAggro(aggroEntry, distance)
					and flat(theirRoot.Position - home.Position).Magnitude <= setting(model, "LeashRange")
					and (not bestDistance or distance < bestDistance)
				then
					best, bestDistance = player, distance
				end
			end
		end
		return best
	end

	-- turning on whoever hurt it
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		local hurt = health < lastHealth
		lastHealth = health
		if hurt then
			regenerating = false
		end
		if not hurt or health <= 0 or retreating or not model:GetAttribute("FightsBack") then
			return
		end
		local attacker = Damage.LastAttacker(humanoid)
		if attacker and attacker.Character then
			if state ~= "chasing" then
				lastProgressAt = os.clock()
			end
			if target ~= attacker then
				comboIndex = 1
			end
			target = attacker
			state = "chasing"
			humanoid.WalkSpeed = setting(model, "ChaseSpeed")
		end
	end)

	while model.Parent and humanoid.Health > 0 do
		task.wait(TICK)
		root = humanoid.RootPart
		if not root or not model.Parent or humanoid.Health <= 0 then
			break
		end
		local now = os.clock()
		local dt = now - lastTickAt
		lastTickAt = now
		if regenerating then
			if state ~= "idle" or humanoid.Health >= humanoid.MaxHealth then
				regenerating = false
			else
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * REGEN_PER_SECOND * StatusConfig.HealMultiplier(model) * dt)
			end
		end
		local hitstun = staggered()
		if hitstun then
			humanoid:MoveTo(root.Position) -- stops where it stands
		end
		local busy = hitstun
			or root.Anchored
			or root:FindFirstChildWhichIsA("LinearVelocity") ~= nil
			or humanoid.FloorMaterial == Enum.Material.Air
		local awayFromHome = flat(home.Position - root.Position).Magnitude

		if state == "chasing" then
			local character = target and target.Parent and target.Character
			local targetHumanoid = character and character:FindFirstChildOfClass("Humanoid")
			local targetRoot = targetHumanoid and targetHumanoid.RootPart
			local leash = setting(model, "LeashRange")
			if not targetRoot
				or targetHumanoid.Health <= 0
				or awayFromHome > leash
				-- they've left its territory
				or flat(targetRoot.Position - home.Position).Magnitude > leash + setting(model, "AttackRange")
				or (targetRoot.Position - root.Position).Magnitude > GIVE_UP_DISTANCE
				or now - lastProgressAt > CHASE_STUCK_TIME
			then
				goHome(true)
			elseif busy then
				-- being thrown around isn't being stuck
				lastProgressAt = now
			else
				local offset = flat(targetRoot.Position - root.Position)
				if (root.Position - lastPosition).Magnitude > 0.5 then
					lastPosition = root.Position
					lastProgressAt = now
				end
				if offset.Magnitude <= setting(model, "AttackRange") then
					-- in reach: stand, face them and swing when ready
					lastProgressAt = now
					humanoid:MoveTo(root.Position)
					if offset.Magnitude > 0.1 then
						root.CFrame = CFrame.lookAt(root.Position, root.Position + offset)
					end
					if now >= nextAttackAt then
						nextAttackAt = now + setting(model, "AttackCooldown")
						if swingAt(targetHumanoid, targetRoot) then
							-- the end of a combo: a longer rest
							nextAttackAt = now + EnemyConfig.Setting(nil, enemyType, "comboPause", setting(model, "AttackCooldown"))
						end
					end
				elseif
					(model:GetAttribute("Level") or 0) > DASH_ABOVE_LEVEL
					and now >= nextDashAt
					and offset.Magnitude >= DASH_MIN_DISTANCE
					and offset.Magnitude <= DASH_MAX_DISTANCE
				then
					nextDashAt = now + DASH_COOLDOWN
					lastProgressAt = now
					dashAt(offset.Unit, offset.Magnitude)
				else
					humanoid:MoveTo(targetRoot.Position)
				end
			end
		elseif state == "returning" then
			if awayFromHome <= ARRIVE_DISTANCE then
				arrive()
			elseif now - returningSince > STUCK_TIME then
				arrive(home)
			elseif not busy then
				-- MoveTo gives up after 8 seconds, so keep asking
				humanoid:MoveTo(home.Position)
			end
		elseif awayFromHome > WANDER_RANGE and not busy then
			goHome(false)
		end

		-- or on whoever walked up to it
		if aggroEntry and not busy and (state == "idle" or (state == "returning" and not retreating)) then
			local found = findAggroTarget()
			if found then
				target = found
				state = "chasing"
				comboIndex = 1
				lastProgressAt = now
				regenerating = false
				humanoid.WalkSpeed = setting(model, "ChaseSpeed")
			end
		end

		-- the walk plays at however fast it's actually moving
		local speed = flat(root.AssemblyLinearVelocity).Magnitude
		if speed > 1 and not busy then
			if not walkTrack.IsPlaying then
				walkTrack:Play(0.2)
			end
			walkTrack:AdjustSpeed(speed / 16)
		elseif walkTrack.IsPlaying then
			walkTrack:Stop(0.2)
		end
	end
	walkTrack:Stop()
end

local active = {}
local function start(model)
	if active[model] or not model:IsA("Model") or not model:IsDescendantOf(workspace) then
		return
	end
	active[model] = true
	task.spawn(function()
		local ok, err = pcall(run, model)
		active[model] = nil
		if not ok then
			warn("[EnemyAI] " .. model:GetFullName() .. ": " .. tostring(err))
		end
	end)
end

for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	start(model)
end
-- respawned copies keep the tag
CollectionService:GetInstanceAddedSignal(TAG):Connect(start)
