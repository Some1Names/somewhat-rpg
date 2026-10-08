-- Status effects on the body: while a character (anyone, you included) has
-- one, its prefab from ReplicatedStorage.VFXPrefabs.Status (embers for Burnt,
-- drips for Bleeding, bubbles for Poisoned, haze for Weakened) rides on its
-- torso, emitting faster with more stacks. Driven by the Status_ attributes
-- (StatusConfig), so it needs no remote. Each emitter's BaseRate attribute is
-- its rate at one stack.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))
local VFX = require(ReplicatedStorage:WaitForChild("VFX"))

local prefabs = ReplicatedStorage:WaitForChild("VFXPrefabs"):WaitForChild("Status")

local CHECK_INTERVAL = 0.15 -- seconds between looking for effects starting or ending

local characters = {} -- humanoid -> { model, holders = { effect name -> holder } }

local function torsoOf(model)
	return model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart")
end

local function setRate(holder, stacks)
	local quality = VFX.Quality()
	for _, emitter in ipairs(holder:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then
			emitter.Rate = (emitter:GetAttribute("BaseRate") or emitter.Rate) * stacks * quality
		end
	end
end

local function start(name, stacks)
	local prefab = prefabs:FindFirstChild(name)
	if not prefab then
		return nil
	end
	local holder = prefab:Clone()
	setRate(holder, stacks)
	holder.Parent = VFX.Folder
	for _, emitter in ipairs(holder:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then
			emitter.Enabled = true
		end
	end
	holder:SetAttribute("Stacks", stacks)
	return holder
end

-- stops emitting and goes once the last particle has
local function stop(holder)
	local longest = 0
	for _, emitter in ipairs(holder:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then
			emitter.Enabled = false
			longest = math.max(longest, emitter.Lifetime.Max)
		end
	end
	Debris:AddItem(holder, longest + 0.1)
end

local function forget(humanoid)
	local entry = characters[humanoid]
	if entry then
		characters[humanoid] = nil
		for _, holder in pairs(entry.holders) do
			stop(holder)
		end
	end
end

local function consider(instance)
	if instance:IsA("Humanoid") and not characters[instance] and instance.Parent and instance.Parent:IsA("Model") then
		characters[instance] = { model = instance.Parent, holders = {} }
		instance.AncestryChanged:Connect(function()
			if not instance:IsDescendantOf(workspace) then
				forget(instance)
			end
		end)
	end
end
for _, descendant in ipairs(workspace:GetDescendants()) do
	consider(descendant)
end
workspace.DescendantAdded:Connect(consider)

-- effects starting, stacking up and running out
local sinceCheck = 0
local function check()
	for humanoid, entry in pairs(characters) do
		local alive = humanoid.Health > 0
		for name in pairs(StatusConfig.Effects) do
			local stacks = alive and StatusConfig.Stacks(entry.model, name) or 0
			local holder = entry.holders[name]
			if stacks > 0 and not holder then
				entry.holders[name] = start(name, stacks)
			elseif stacks > 0 and holder:GetAttribute("Stacks") ~= stacks then
				holder:SetAttribute("Stacks", stacks)
				setRate(holder, stacks)
			elseif stacks == 0 and holder then
				entry.holders[name] = nil
				stop(holder)
			end
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	sinceCheck += dt
	if sinceCheck >= CHECK_INTERVAL then
		sinceCheck = 0
		check()
	end
	-- each holder rides on its character's torso
	for _, entry in pairs(characters) do
		if next(entry.holders) then
			local torso = torsoOf(entry.model)
			if torso then
				for _, holder in pairs(entry.holders) do
					holder.CFrame = torso.CFrame
				end
			end
		end
	end
end)
