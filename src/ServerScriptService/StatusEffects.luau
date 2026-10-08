-- Puts status effects (Burnt, Bleeding, Poisoned, Weakened, Desaturated; numbers in
-- ReplicatedStorage.StatusConfig) on players and NPCs and runs them: damage
-- over time ticks go through Damage.Deal for whoever applied the effect (kill
-- credit, their stat bonus, mastery), can't crit and no passive erases them.
-- An effect lives as attributes on the character model (StatusConfig), so
-- clients draw it without a remote. Everything clears when the character
-- dies or leaves the workspace.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Damage = require(script.Parent:WaitForChild("Damage"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))

local STEP = 0.1 -- seconds between checks

local StatusEffects = {}

-- model -> effect name -> { source, stat, skillSet, nextTickAt }
local active = {}

local function modelOf(target)
	if typeof(target) ~= "Instance" then
		return nil
	end
	if target:IsA("Humanoid") then
		return target.Parent
	end
	return target:IsA("Model") and target or nil
end

local function clearEffect(model, name)
	model:SetAttribute(StatusConfig.EndsAttribute(name), nil)
	model:SetAttribute(StatusConfig.StacksAttribute(name), nil)
	local effects = active[model]
	if effects then
		effects[name] = nil
		if next(effects) == nil then
			active[model] = nil
		end
	end
end

-- Applies `name` to a character (its model or Humanoid). Applying it again
-- refreshes the time and adds stacks, up to the effect's maxStacks.
-- opts.source: the Player who caused it (gets the kill credit and scales the
--   damage with opts.stat; nil for none)
-- opts.stat, opts.skillSet: as in Damage.Deal
-- opts.stacks: stacks to add (default 1)
-- opts.duration: seconds instead of the effect's own
-- Returns whether it took hold.
function StatusEffects.Apply(target, name, opts)
	opts = opts or {}
	local effect = StatusConfig.Effects[name]
	local model = modelOf(target)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not effect or not humanoid or humanoid.Health <= 0 or model:GetAttribute("Invulnerable") or not model:IsDescendantOf(workspace) then
		return false
	end
	local now = workspace:GetServerTimeNow()
	local stacks = math.min(effect.maxStacks, StatusConfig.Stacks(model, name) + (opts.stacks or 1))
	model:SetAttribute(StatusConfig.EndsAttribute(name), now + (opts.duration or effect.duration))
	model:SetAttribute(StatusConfig.StacksAttribute(name), stacks)

	active[model] = active[model] or {}
	local entry = active[model][name]
	if not entry then
		entry = { nextTickAt = now + (effect.tick or 0) }
		active[model][name] = entry
	end
	-- the latest one to apply it gets the credit
	entry.source = opts.source
	entry.stat = opts.stat
	entry.skillSet = opts.skillSet
	return true
end

-- removes one effect, or all of them with no name
function StatusEffects.Clear(target, name)
	local model = modelOf(target)
	if not model then
		return
	end
	for effectName in pairs(StatusConfig.Effects) do
		if name == nil or name == effectName then
			clearEffect(model, effectName)
		end
	end
end

function StatusEffects.Has(target, name)
	return StatusConfig.Stacks(modelOf(target), name) > 0
end

function StatusEffects.Stacks(target, name)
	return StatusConfig.Stacks(modelOf(target), name)
end

local function moving(model, humanoid)
	if model:GetAttribute("Dashing") then
		return true
	end
	local root = humanoid.RootPart
	if not root then
		return false
	end
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude > StatusConfig.MovingSpeed
end

local function tick(model, name, entry, humanoid, now)
	local effect = StatusConfig.Effects[name]
	if not effect.damage or not effect.tick or now < entry.nextTickAt then
		return
	end
	entry.nextTickAt += effect.tick
	local amount = effect.damage * (model:GetAttribute(StatusConfig.StacksAttribute(name)) or 1)
	if effect.movingMultiplier and moving(model, humanoid) then
		amount *= effect.movingMultiplier
	end
	-- whoever caused it may have left since
	local source = entry.source
	if source and source.Parent ~= Players then
		source = nil
	end
	Damage.Deal(source, humanoid, amount, {
		stat = entry.stat,
		skillSet = source and entry.skillSet or nil,
		unerasable = true,
		dot = true,
	})
end

task.spawn(function()
	while true do
		task.wait(STEP)
		local now = workspace:GetServerTimeNow()
		for model, effects in pairs(active) do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 or not model:IsDescendantOf(workspace) then
				StatusEffects.Clear(model)
			else
				for name, entry in pairs(effects) do
					local endsAt = model:GetAttribute(StatusConfig.EndsAttribute(name))
					if typeof(endsAt) ~= "number" then
						-- cleared from outside
						clearEffect(model, name)
					else
						-- the last tick lands as it runs out
						if entry.nextTickAt <= endsAt + 0.05 then
							local ok, err = pcall(tick, model, name, entry, humanoid, now)
							if not ok then
								warn("[StatusEffects] " .. tostring(err))
							end
						end
						if now >= endsAt then
							clearEffect(model, name)
						end
					end
				end
			end
		end
	end
end)

return StatusEffects
