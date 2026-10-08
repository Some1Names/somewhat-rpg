-- Luminance and flight, for skill sets that have them (Iridescent Requiem).
-- While the set is equipped, its Luminance (the player's <Set>Luminance
-- attribute, 0 to 1) fills in sunlight, much faster above the set's
-- cloudHeight. In shade it can hold only the passive's shadeCap: above it
-- it drains down to it, below it slowly gathers up to it (the player's
-- ShadedAttribute tells the skill bar). Flying and Prism Form
-- (Skills.PrismForm) burn it instead of gathering it. ToggleFlight asks
-- to take off or land, and the character's Flying attribute tells every
-- client (the Flight script does the moving). Flight ends when Luminance runs
-- out or the set is put away. Passives reads Luminance for its damage cut.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local toggleFlight = ReplicatedStorage:WaitForChild("ToggleFlight")

local TICK = 0.2 -- seconds
local SUN_RAY_LENGTH = 1000 -- studs
local SEE_THROUGH = 0.5 -- parts at least this transparent let the light through
local FLYING = "Flying"

-- the equipped set, if its passive is Luminance
local function luminanceSet(character)
	local _, setName = SkillSetConfig.Equipped(character)
	local set = setName and SkillSetConfig.Sets[setName]
	if set and set.passive and set.passive.name == "Luminance" then
		return setName, set
	end
	return nil, nil
end

-- whether sunlight reaches this point; characters don't count as shade
local function inSunlight(position)
	local sun = Lighting:GetSunDirection()
	if sun.Y <= 0 then
		return false -- the sun's down
	end
	local ignore = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, 4 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(position, sun * SUN_RAY_LENGTH, params)
		if not hit then
			return true
		end
		if hit.Instance.Transparency < SEE_THROUGH then
			return false
		end
		table.insert(ignore, hit.Instance)
	end
	return false
end

local function setFlying(character, flying)
	character:SetAttribute(FLYING, flying or nil)
end

toggleFlight.OnServerEvent:Connect(function(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if character:GetAttribute(FLYING) then
		setFlying(character, false)
		return
	end
	local setName, set = luminanceSet(character)
	if not set or not set.flight then
		return
	end
	-- it takes some light to get off the ground
	if (player:GetAttribute(SkillSetConfig.LuminanceAttribute(setName)) or 0) < set.flight.minimumToStart then
		return
	end
	setFlying(character, true)
end)

task.spawn(function()
	while true do
		local dt = task.wait(TICK)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = humanoid and humanoid.RootPart
			if root and humanoid.Health > 0 then
				local setName, set = luminanceSet(character)
				local flying = character:GetAttribute(FLYING) == true
				if not setName then
					-- put away mid-air: back down
					if flying then
						setFlying(character, false)
					end
				else
					local passive = set.passive
					local key = SkillSetConfig.LuminanceAttribute(setName)
					local luminance = player:GetAttribute(key) or 0
					local shaded = false
					if SkillSetConfig.InForm(character, setName) then
						-- the form spends the light; sunlight doesn't top it up meanwhile
						luminance -= set.form.drainPerSecond * dt
					elseif flying and set.flight then
						-- nor while flying (drained below), or flight above the
						-- clouds would never end
					elseif inSunlight(root.Position + Vector3.new(0, 2, 0)) then
						local aboveClouds = root.Position.Y >= passive.cloudHeight
						luminance += passive.chargePerSecond * (aboveClouds and passive.cloudMultiplier or 1) * dt
					else
						-- shade holds only so much: down to the cap, or slowly up to it
						shaded = true
						if luminance > passive.shadeCap then
							luminance = math.max(luminance - passive.shadeDrainPerSecond * dt, passive.shadeCap)
						else
							luminance = math.min(luminance + passive.shadeChargePerSecond * dt, passive.shadeCap)
						end
					end
					if flying and set.flight then
						luminance -= set.flight.drainPerSecond * dt
					end
					luminance = math.clamp(luminance, 0, 1)
					player:SetAttribute(key, luminance)
					if player:GetAttribute(SkillSetConfig.ShadedAttribute) ~= shaded then
						player:SetAttribute(SkillSetConfig.ShadedAttribute, shaded)
					end
					if flying and luminance <= 0 then
						setFlying(character, false)
					end
				end
			end
		end
	end
end)
