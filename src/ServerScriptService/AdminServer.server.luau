-- Server side of the admin panel: works out who is an admin and carries out
-- their requests (XP, level, points, stats, mastery, cooldowns, heal,
-- respawn, status effects) on any player. Admins can also save their own key binds for
-- panel actions (the AdminKeybinds attribute, saved by PlayerStats).
-- Every request is checked here, so the panel itself grants nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Overcharge = require(script.Parent:WaitForChild("Overcharge"))
local Loadout = require(script.Parent:WaitForChild("Loadout"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local SkillCooldowns = require(script.Parent:WaitForChild("SkillCooldowns"))
local StatusEffects = require(script.Parent:WaitForChild("StatusEffects"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))
local adminAction = ReplicatedStorage:WaitForChild("AdminAction")

-- admins besides the game's owner, by UserId
local ADMIN_USER_IDS = {
	-- 123456789,
}
local GROUP_ADMIN_RANK = 254 -- if the game belongs to a group, this rank and up
local MAX_VALUE = 1e6 -- largest number the panel may send
local KEYBINDS_MAX_LENGTH = 200
local NEAREST_NPC_RANGE = 80 -- studs from the target player a status effect's "nearest NPC" may be
-- actions an admin may only do to themself
local SELF_ONLY = { SetKeybinds = true }

local admins = {}

local function isAdmin(player)
	if RunService:IsStudio() then
		return true -- anyone in a Studio playtest
	end
	if table.find(ADMIN_USER_IDS, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank >= GROUP_ADMIN_RANK
end

local function onPlayerAdded(player)
	admins[player] = isAdmin(player)
	-- the client only uses this to decide whether to show the panel
	player:SetAttribute("IsAdmin", admins[player])
end

local function cleanNumber(value)
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(math.floor(value), 0, MAX_VALUE)
end

local function loadingMessage(target)
	return target.Name .. "'s stats are still loading"
end

local actions = {}

function actions.GiveXP(target, amount)
	amount = cleanNumber(amount)
	if not amount or amount <= 0 then
		return false, "Enter an XP amount above 0"
	end
	if target:GetAttribute("Level") == nil then
		return false, loadingMessage(target)
	end
	PlayerStats.AddXP(target, amount)
	return true, string.format("Gave %s %d XP", target.Name, amount)
end

function actions.GiveYen(target, amount)
	amount = cleanNumber(amount)
	if not amount or amount <= 0 then
		return false, "Enter a yen amount above 0"
	end
	if target:GetAttribute("Yen") == nil then
		return false, loadingMessage(target)
	end
	PlayerStats.AddYen(target, amount)
	return true, string.format("Gave %s ¥%d", target.Name, amount)
end

function actions.SetLevel(target, level)
	level = cleanNumber(level)
	if not level then
		return false, "Enter a level"
	end
	if not PlayerStats.Set(target, "Level", level) then
		return false, loadingMessage(target)
	end
	PlayerStats.Set(target, "XP", 0)
	return true, string.format("Set %s to level %d", target.Name, target:GetAttribute("Level"))
end

function actions.SetPoints(target, points)
	points = cleanNumber(points)
	if not points then
		return false, "Enter a number of points"
	end
	if not PlayerStats.Set(target, "StatPoints", points) then
		return false, loadingMessage(target)
	end
	return true, string.format("Set %s's stat points to %d", target.Name, points)
end

function actions.SetStat(target, key, value)
	value = cleanNumber(value)
	if typeof(key) ~= "string" or not StatConfig.Get(key) then
		return false, "Unknown stat"
	end
	if not value then
		return false, "Enter a number for " .. key
	end
	if not PlayerStats.Set(target, key, value) then
		return false, loadingMessage(target)
	end
	return true, string.format("Set %s's %s to %d", target.Name, key, target:GetAttribute(key))
end

function actions.SetMastery(target, setName, level)
	level = cleanNumber(level)
	if typeof(setName) ~= "string" or not SkillSetConfig.Sets[setName] then
		return false, "Unknown skill set"
	end
	if not level then
		return false, "Enter a mastery level"
	end
	if not PlayerStats.SetMastery(target, setName, level) then
		return false, loadingMessage(target)
	end
	return true, string.format("Set %s's %s mastery to %d", target.Name, setName, target:GetAttribute(SkillSetConfig.MasteryAttribute(setName)))
end

-- swaps the target's power (or weapon) for this skill set
function actions.GiveSet(target, setName)
	if typeof(setName) ~= "string" or not SkillSetConfig.Sets[setName] then
		return false, "Unknown skill set"
	end
	Loadout.Give(target, setName)
	return true, string.format("Gave %s %s", target.Name, SkillSetConfig.Sets[setName].tool)
end

function actions.Overcharge(target, setName)
	local set = typeof(setName) == "string" and SkillSetConfig.Sets[setName]
	if not set or not set.overcharge then
		return false, "That skill set has no overcharge"
	end
	Overcharge.Fill(target, setName)
	return true, string.format("Overcharged %s's %s", target.Name, setName)
end

function actions.ResetCooldowns(target)
	SkillCooldowns.Reset(target)
	Overcharge.ResetCooldowns(target)
	return true, string.format("Reset %s's skill and overcharge cooldowns", target.Name)
end

function actions.ResetStats(target)
	if not PlayerStats.ResetStats(target) then
		return false, loadingMessage(target)
	end
	return true, string.format("Refunded %s's stat points", target.Name)
end

function actions.ResetProgress(target)
	if not PlayerStats.ResetProgress(target) then
		return false, loadingMessage(target)
	end
	return true, string.format("Reset %s to level 1", target.Name)
end

function actions.Heal(target)
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, target.Name .. " has no living character"
	end
	humanoid.Health = humanoid.MaxHealth
	return true, "Healed " .. target.Name
end

function actions.Respawn(target)
	target:LoadCharacter()
	return true, "Respawned " .. target.Name
end

-- the living non-player character nearest the target player
local function nearestNPC(target)
	local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best, bestDistance = nil, NEAREST_NPC_RANGE
	for _, humanoid in ipairs(workspace:GetDescendants()) do
		if humanoid:IsA("Humanoid") and humanoid.Health > 0 and humanoid.RootPart
			and not Players:GetPlayerFromCharacter(humanoid.Parent)
			and not humanoid.Parent:GetAttribute("Invulnerable")
		then
			local distance = (humanoid.RootPart.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = humanoid.Parent, distance
			end
		end
	end
	return best
end

-- `on`: "player" (the target) or "npc" (the NPC nearest them)
local function statusTarget(target, on)
	if on == "npc" then
		local npc = nearestNPC(target)
		if not npc then
			return nil, "No NPC within " .. NEAREST_NPC_RANGE .. " studs of " .. target.Name
		end
		return npc, npc.Name
	end
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, target.Name .. " has no living character"
	end
	return target.Character, target.Name
end

-- one stack, with no attacker behind it (so no stat bonus)
function actions.ApplyStatus(target, effect, on)
	if typeof(effect) ~= "string" or not StatusConfig.Effects[effect] then
		return false, "Unknown status effect"
	end
	local model, name = statusTarget(target, on)
	if not model then
		return false, name
	end
	if not StatusEffects.Apply(model, effect) then
		return false, name .. " can't take status effects right now"
	end
	return true, string.format("%s is %s (x%d)", name, effect, StatusEffects.Stacks(model, effect))
end

-- the player's and the nearest NPC's
function actions.ClearStatus(target)
	local cleared = {}
	for _, on in ipairs({ "player", "npc" }) do
		local model, name = statusTarget(target, on)
		if model then
			StatusEffects.Clear(model)
			table.insert(cleared, name)
		end
	end
	if #cleared == 0 then
		return false, "Nobody to clear"
	end
	return true, "Cleared status effects on " .. table.concat(cleared, " and ")
end

-- binds as "Action=KeyName" pairs separated by commas, e.g. "ResetCooldowns=H"
function actions.SetKeybinds(target, binds)
	if typeof(binds) ~= "string" or #binds > KEYBINDS_MAX_LENGTH or not binds:match("^[%w:=,]*$") then
		return false, "Bad key binds"
	end
	target:SetAttribute("AdminKeybinds", binds)
	return true, "Saved key binds"
end

adminAction.OnServerInvoke = function(player, action, targetUserId, ...)
	if not admins[player] then
		return false, "You're not an admin"
	end
	local handler = typeof(action) == "string" and actions[action]
	if not handler then
		return false, "Unknown action"
	end
	local target = typeof(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	if not target then
		return false, "That player has left"
	end
	if SELF_ONLY[action] and target ~= player then
		return false, "You can only do that for yourself"
	end
	local ok, message = handler(target, ...)
	if ok then
		print(string.format("[Admin] %s: %s", player.Name, message))
	end
	return ok, message
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(function(player)
	admins[player] = nil
end)
