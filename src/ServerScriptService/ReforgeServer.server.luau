-- Server side of the smith: a request to level up, reroll or keep a reroll only
-- goes through for a player standing next to a smith (a model tagged "Smith"),
-- and Reforge does all the checking and spending. Also gives reforged hits their
-- extras: the chance to apply a status and lifesteal. (That lives here and not
-- in Damage because StatusEffects needs Damage.)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Damage = require(script.Parent:WaitForChild("Damage"))
local Reforge = require(script.Parent:WaitForChild("Reforge"))
local StatusEffects = require(script.Parent:WaitForChild("StatusEffects"))
local ReforgeConfig = require(ReplicatedStorage:WaitForChild("ReforgeConfig"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))
local remote = ReplicatedStorage:WaitForChild(ReforgeConfig.Remote)

local ACTION_INTERVAL = 0.3 -- seconds between a player's requests
local RANGE_TOLERANCE = 4 -- a little more than the menu's range, for movement while the request travels
local STATUSES = { "Burnt", "Bleeding", "Poisoned", "Weakened" } -- what the modifiers can apply

local lastAction = setmetatable({}, { __mode = "k" })

local function nearSmith(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	for _, smith in ipairs(CollectionService:GetTagged(ReforgeConfig.Tag)) do
		if smith:IsA("Model") and smith:IsDescendantOf(workspace) then
			if (smith:GetPivot().Position - root.Position).Magnitude <= ReforgeConfig.Range + RANGE_TOLERANCE then
				return true
			end
		end
	end
	return false
end

-- (action, set, extra) -> ok, message, candidate
--   "level"   (set)        one more level
--   "reroll"  (set, slot)  pay for a new roll of the slot; the candidate comes back
--   "resolve" (set, keep)  keep (true) or drop (false) the waiting candidate
--   "pending" (set)        the waiting candidate, if any (free; the menu reopened)
remote.OnServerInvoke = function(player, action, setName, extra)
	if action ~= "level" and action ~= "reroll" and action ~= "resolve" and action ~= "pending" then
		return false, "Unknown request"
	end
	if action ~= "pending" then
		local now = os.clock()
		if now - (lastAction[player] or 0) < ACTION_INTERVAL then
			return false, "Slow down"
		end
		lastAction[player] = now
	end
	if not nearSmith(player.Character) then
		return false, "Too far from the smith"
	end
	if action == "level" then
		return Reforge.LevelUp(player, setName)
	elseif action == "reroll" then
		return Reforge.Reroll(player, setName, extra)
	elseif action == "resolve" then
		return Reforge.Resolve(player, setName, extra)
	end
	return true, "", typeof(setName) == "string" and Reforge.Pending(player, setName) or nil
end

-- when each victim last caught each status from a reforged hit
local lastProc = setmetatable({}, { __mode = "k" })

Damage.OnDealt(function(attacker, humanoid, dealt, options)
	if not attacker or options.dot or not options.skillSet then
		return
	end
	local character = attacker.Character
	local attackerHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not attackerHumanoid or attackerHumanoid.Health <= 0 or humanoid.Parent == character then
		return
	end
	local now = os.clock()
	for _, status in ipairs(STATUSES) do
		local chance = Reforge.StatusChance(attacker, options.skillSet, status)
		local procs = lastProc[humanoid]
		if chance > 0 and (not procs or now - (procs[status] or 0) >= ReforgeConfig.ProcCooldown) and math.random() < chance then
			procs = procs or {}
			lastProc[humanoid] = procs
			procs[status] = now
			StatusEffects.Apply(humanoid, status, { source = attacker, stat = options.stat, skillSet = options.skillSet })
		end
	end
	local steal = Reforge.Lifesteal(attacker, options.skillSet)
	if steal > 0 then
		attackerHumanoid.Health = math.min(attackerHumanoid.MaxHealth, attackerHumanoid.Health + dealt * steal * StatusConfig.HealMultiplier(character))
	end
end)

Reforge.Start()
