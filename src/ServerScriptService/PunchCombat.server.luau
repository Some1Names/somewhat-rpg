-- Server side of melee (fists, or the Mandela axe while it's equipped): keeps
-- count of each player's combo, finds what's in front of them when a hit
-- lands and damages it. The last hit of the combo is a critical that knocks
-- the target back (players protected by CrowdControl, and anyone of a higher
-- level than the puncher, still take the critical but aren't thrown). Every
-- hit staggers an enemy NPC for a moment (its HitstunUntil attribute, which
-- EnemyAI respects) until it's been staggered nonstop for its StaggerLimit;
-- then it shrugs it off for a while. Skill-set weapons also light up their
-- swing trail and flash a slash on everything they hit (fists burst on it
-- instead); their finisher does
-- extra to a target the set's Z exposed; and while their set is overcharged
-- they heal a little per hit and their finisher bursts bone spikes out
-- around the target.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CrowdControl = require(ServerScriptService:WaitForChild("CrowdControl"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Overcharge = require(ServerScriptService:WaitForChild("Overcharge"))
local PunchConfig = require(ReplicatedStorage:WaitForChild("PunchConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))

local SCALING_STAT = "Strength" -- every weapon here is melee

local punchEvent = ReplicatedStorage:WaitForChild("Punch")
local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	KnockbackSpeed = 35, -- studs per second along the punch
	KnockbackLift = 14, -- studs per second upward
	KnockbackTime = 0.2, -- seconds the push lasts (about 7 studs)
	Tolerance = 0.1, -- network jitter between client and server timing
}

local combos = {}
local staggerChains = setmetatable({}, { __mode = "k" }) -- enemy model -> when its unbroken stagger began

-- Staggers an enemy, unless it's been staggered nonstop for its limit: then
-- it shrugs it off and can't be staggered again for a while.
local function stagger(model)
	local now = workspace:GetServerTimeNow()
	if (model:GetAttribute("StaggerImmuneUntil") or 0) > now then
		return
	end
	local stillStaggered = (model:GetAttribute("HitstunUntil") or 0) > now
	local chainStart = stillStaggered and staggerChains[model] or now
	staggerChains[model] = chainStart
	if now - chainStart >= (model:GetAttribute("StaggerLimit") or PunchConfig.StaggerLimit) then
		staggerChains[model] = nil
		model:SetAttribute("HitstunUntil", 0)
		model:SetAttribute("StaggerImmuneUntil", now + PunchConfig.StaggerImmunity)
		skillEffects:FireAllClients("PoiseBreak", model)
		return
	end
	model:SetAttribute("HitstunUntil", now + PunchConfig.Hitstun)
end

-- a skill-set weapon's colour: the set's own, or its overcharge colour
local function weaponColor(player, weapon)
	local set = SkillSetConfig.Sets[weapon.skillSet]
	if set.overcharge and Overcharge.IsActive(player, weapon.skillSet) then
		return set.overcharge.color
	end
	return set.color
end

-- lights the wielded weapon's swing trails for one swing: SwingTrail takes
-- the weapon's colour (white at the blade), any other SwingTrail* (the
-- bright SwingTrailCore along the edge) keeps its own
local function showTrail(player, character, weapon, swingLength)
	local worn = character:FindFirstChild("SkillSetWearables")
	local trails = {}
	for _, descendant in ipairs(worn and worn:GetDescendants() or {}) do
		if descendant:IsA("Trail") and descendant.Name:sub(1, 10) == "SwingTrail" then
			table.insert(trails, descendant)
		end
	end
	if #trails == 0 then
		return
	end
	local swing = (worn:GetAttribute("Swing") or 0) + 1
	worn:SetAttribute("Swing", swing)
	for _, trail in ipairs(trails) do
		if trail.Name == "SwingTrail" then
			trail.Color = ColorSequence.new(Color3.new(1, 1, 1), weaponColor(player, weapon))
		end
		trail.Enabled = true
	end
	task.delay(swingLength * 0.75, function()
		-- unless the next swing has started
		if worn:GetAttribute("Swing") == swing then
			for _, trail in ipairs(trails) do
				trail.Enabled = false
			end
		end
	end)
end

-- Fists: a short streak of light behind each hand while a punch is thrown,
-- white fading to the colour of whatever skill set is equipped (pale
-- blue-white without one). Made on the hands the first time they punch.
-- The same colour tints the burst where a punch lands.
local FIST_TINT = Color3.fromRGB(200, 225, 255)
local FIST_HANDS = { "RightHand", "LeftHand", "Right Arm", "Left Arm" }

local function fistColor(character)
	local _, setName = SkillSetConfig.Equipped(character)
	local set = setName and SkillSetConfig.Sets[setName]
	return set and set.color or FIST_TINT
end

local function fistTrail(hand)
	local trail = hand:FindFirstChild("FistTrail")
	if trail then
		return trail
	end
	local top = Instance.new("Attachment")
	top.Name = "FistTrailTop"
	top.Position = Vector3.new(0, 0.3, 0)
	top.Parent = hand
	local bottom = Instance.new("Attachment")
	bottom.Name = "FistTrailBottom"
	bottom.Position = Vector3.new(0, -0.3, 0)
	bottom.Parent = hand
	trail = Instance.new("Trail")
	trail.Name = "FistTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Texture = "rbxassetid://14191603094"
	trail.TextureMode = Enum.TextureMode.Stretch
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.25) })
	trail.Lifetime = 0.16
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Brightness = 1.5
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = hand
	return trail
end

local function showFistTrails(character, swingLength)
	local color = ColorSequence.new(Color3.new(1, 1, 1), fistColor(character))
	local trails = {}
	for _, name in ipairs(FIST_HANDS) do
		local hand = character:FindFirstChild(name)
		if hand and hand:IsA("BasePart") then
			local trail = fistTrail(hand)
			trail.Color = color
			trail.Enabled = true
			table.insert(trails, trail)
		end
	end
	local swing = (character:GetAttribute("FistSwing") or 0) + 1
	character:SetAttribute("FistSwing", swing)
	task.delay(swingLength * 0.75, function()
		-- unless the next punch has started
		if character:GetAttribute("FistSwing") == swing then
			for _, trail in ipairs(trails) do
				trail.Enabled = false
			end
		end
	end)
end

-- a finisher only throws targets no higher level than the puncher: an NPC's
-- Level attribute, or its player's; anything without a level can be thrown
local function canThrow(player, model)
	local owner = Players:GetPlayerFromCharacter(model)
	local level = (owner or model):GetAttribute("Level")
	return level == nil or level <= (player:GetAttribute("Level") or 0)
end

local function knockBack(root, direction)
	local attachment = Instance.new("Attachment")
	attachment.Name = "PunchKnockback"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "PunchKnockback"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = direction * CONFIG.KnockbackSpeed + Vector3.new(0, CONFIG.KnockbackLift, 0)
	velocity.Parent = root
	Debris:AddItem(velocity, CONFIG.KnockbackTime)
	Debris:AddItem(attachment, CONFIG.KnockbackTime)
end

-- overcharged finisher: bone spikes tear out around `center`; returns the damage dealt
local function spikeBurst(player, character, center, weapon)
	local settings = weapon.overcharged
	local color = weaponColor(player, weapon)
	skillEffects:FireAllClients("BoneSpikes", center, color, 1.4)
	skillEffects:FireAllClients("Shockwave", center - Vector3.new(0, 2.5, 0), settings.spikeRadius * 0.8, color)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local options = { stat = SCALING_STAT, skillSet = weapon.skillSet, melee = true }
	local dealt = 0
	local struck = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, settings.spikeRadius, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local target = model and model:FindFirstChildOfClass("Humanoid")
		if target and not struck[target] and target.Health > 0 then
			struck[target] = true
			dealt += Damage.Deal(player, target, settings.spikeDamage, options)
		end
	end
	return dealt
end

local function land(player, character, weapon, finisher)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	-- the puncher may have died or respawned during the wind-up
	if not root or humanoid.Health <= 0 or player.Character ~= character then
		return
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local box = root.CFrame * CFrame.new(0, 0, -weapon.hitboxForward)

	local damage = weapon.baseDamage * (finisher and PunchConfig.CritMultiplier or 1)
	local options = { stat = SCALING_STAT, critical = finisher, skillSet = weapon.skillSet, melee = true }
	local look = root.CFrame.LookVector
	local direction = Vector3.new(look.X, 0, look.Z).Unit

	local slashColor = weapon.skillSet and weaponColor(player, weapon)
	local punchColor = not weapon.skillSet and fistColor(character)
	local hit = {}
	local dealt = 0
	local firstRoot
	for _, part in ipairs(workspace:GetPartBoundsInBox(box, weapon.hitboxSize, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local target = model and model:FindFirstChildOfClass("Humanoid")
		if target and not hit[target] and target.Health > 0 then
			hit[target] = true
			firstRoot = firstRoot or target.RootPart
			if slashColor and target.RootPart then
				skillEffects:FireAllClients("Slash", target.RootPart.Position, direction, finisher, slashColor)
			elseif punchColor and target.RootPart then
				-- on the side of the body the fist struck
				skillEffects:FireAllClients("FistHit", target.RootPart.Position - direction * 0.8, direction, finisher, punchColor)
			end
			-- someone the set's Z pulled in takes extra from the finisher
			local links = weapon.skillSet and SkillSetConfig.Sets[weapon.skillSet].links
			local hitDamage = damage
			if finisher and links and Damage.ConsumeExposed(player, model) then
				hitDamage *= 1 + links.exposedFinisherBonus
			end
			local landed = Damage.Deal(player, target, hitDamage, options)
			dealt += landed
			if not Players:GetPlayerFromCharacter(model) then
				stagger(model)
			end
			-- a hit a passive erased or let pass through doesn't throw them either
			if finisher and landed > 0 and target.RootPart and not target.RootPart.Anchored and canThrow(player, model) and CrowdControl.CanControl(model) then
				knockBack(target.RootPart, direction)
				CrowdControl.Apply(model, CONFIG.KnockbackTime)
			end
		end
	end

	if weapon.overcharged and Overcharge.IsActive(player, weapon.skillSet) then
		if finisher and firstRoot then
			dealt += spikeBurst(player, character, firstRoot.Position, weapon)
		end
		if dealt > 0 and humanoid.Health > 0 then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + dealt * weapon.overcharged.lifesteal * StatusConfig.HealMultiplier(character))
		end
	end
end

-- The client says which hit of the combo it threw. The server only lets it
-- carry on a combo the server saw too, so a finisher always needs the hits
-- before it.
punchEvent.OnServerEvent:Connect(function(player, index)
	if typeof(index) ~= "number" or index ~= index then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- a gun's left click shoots instead (RangedServer)
	local _, heldSet = SkillSetConfig.Equipped(character)
	local ranged = heldSet and SkillSetConfig.Sets[heldSet].ranged
	if ranged and ranged.primary then
		return
	end

	local now = os.clock()
	local weaponName, weapon = PunchConfig.WeaponFor(character)
	-- a thrown weapon (Axe Boomerang) can't swing until it's caught
	if weapon.skillSet and character:GetAttribute("WeaponThrown") then
		return
	end
	local combo = combos[player]
	-- switching weapons starts a fresh combo
	if not combo or combo.weapon ~= weaponName then
		combo = { weapon = weaponName, count = 0, lastAt = combo and combo.lastAt or -math.huge }
		combos[player] = combo
	end
	local since = now - combo.lastAt
	local rest = combo.count == PunchConfig.ComboLength and weapon.finisherCooldown or 0
	if since < weapon.minInterval + rest - CONFIG.Tolerance then
		return
	end
	local continues = combo.count < PunchConfig.ComboLength and since <= PunchConfig.ComboWindow + CONFIG.Tolerance
	local hitIndex = continues and math.clamp(math.floor(index), 1, combo.count + 1) or 1
	combo.count = hitIndex
	combo.lastAt = now

	if weapon.skillSet then
		showTrail(player, character, weapon, weapon.hits[hitIndex].length)
	elseif weaponName == "Fists" then
		showFistTrails(character, weapon.hits[hitIndex].length)
	end
	task.delay(weapon.hits[hitIndex].impact, land, player, character, weapon, hitIndex == PunchConfig.ComboLength)
end)

Players.PlayerRemoving:Connect(function(player)
	combos[player] = nil
end)
