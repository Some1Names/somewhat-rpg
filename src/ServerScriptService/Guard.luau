-- Block and posture (rules and numbers: ReplicatedStorage.GuardConfig). A
-- player holds E: the client's Block script sends true/false on the Block
-- remote (made here) and the character's Blocking attribute follows. Every
-- hit on a player goes through Guard.Resolve (Damage.Deal and EnemyAI's
-- swing call it): a hit from the front is cut by its kind and the damage
-- the block prevented is added to the blocker's Posture; a full bar is a
-- guard break (the block drops, a stun, then no blocking for a while).
-- Posture drains back down in the loop at the bottom once the blocker stops
-- being hit. Everything the HUDs and input scripts need is an attribute on
-- the character: Blocking, Posture, HitstunUntil (the stun of a guard
-- break, also EnemyAI's hitstun), GuardBrokenUntil (when blocking is back)
-- and LastCombatAt (the last time they dealt or took damage, which hides
-- the shop prompt). Times are workspace:GetServerTimeNow().
-- A skill set or melee weapon with its own `block` table brings its own
-- cuts (GuardConfig.cut); none does yet. Visuals: SkillEffects "Block" and
-- "GuardBreak".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionLock = require(ReplicatedStorage:WaitForChild("ActionLock"))
local GuardConfig = require(ReplicatedStorage:WaitForChild("GuardConfig"))
local PunchConfig = require(ReplicatedStorage:WaitForChild("PunchConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local PRESS_THROTTLE = 0.05 -- seconds between block presses a player may make
local DRAIN_TICK = 0.1 -- seconds between posture updates
local HIT_HEIGHT = 1 -- studs above the blocker's root where the spark shows
local HIT_REACH = 1.5 -- studs towards the attacker

local Guard = {}

-- character -> { lastAt = when they last pressed, were hit while blocking, or let go (server time),
-- resetAt = when a guard break's stun ends and posture goes back to 0, if one is running }
local states = setmetatable({}, { __mode = "k" })
local lastPress = setmetatable({}, { __mode = "k" }) -- player -> os.clock() of their last accepted press

local function stateOf(character)
	local state = states[character]
	if not state then
		state = { lastAt = 0 }
		states[character] = state
	end
	return state
end

local function setBlocking(character, on)
	character:SetAttribute("Blocking", on)
	stateOf(character).lastAt = workspace:GetServerTimeNow()
end

-- they dealt or took damage just now (the client hides prompts while it's recent)
function Guard.MarkCombat(character)
	if character then
		character:SetAttribute("LastCombatAt", workspace:GetServerTimeNow())
	end
end

-- the cuts the equipped set or melee weapon brings, if it has its own block
local function ownBlock(character)
	local _, setName = SkillSetConfig.Equipped(character)
	if setName then
		return SkillSetConfig.Sets[setName].block
	end
	local _, weapon = PunchConfig.WeaponFor(character)
	return weapon and weapon.block
end

local function guardBreak(character, now)
	setBlocking(character, false)
	character:SetAttribute("Posture", GuardConfig.MaxPosture)
	character:SetAttribute("HitstunUntil", now + GuardConfig.BreakStun)
	character:SetAttribute("GuardBrokenUntil", now + GuardConfig.BreakStun + GuardConfig.BreakLockout)
	stateOf(character).resetAt = now + GuardConfig.BreakStun
	skillEffects:FireAllClients("GuardBreak", character)
end

-- What a hit of `amount` does to `target` (a character) once it's blocking:
-- the amount to actually deal. `kind` is the hit's guard kind ("melee",
-- "ranged", "skill" or "unblockable"); nil, a damage-over-time tick, passes
-- straight through. `source` is where the hit comes from (nil counts as the
-- front) and `attacker` the model that made it. Never deals damage itself.
function Guard.Resolve(target, amount, kind, source, attacker)
	if kind == nil or amount <= 0 or target:GetAttribute("Blocking") ~= true then
		return amount
	end
	local root = target:FindFirstChild("HumanoidRootPart")
	if not root then
		return amount
	end
	local away = source and (source - root.Position) or Vector3.zero
	if not GuardConfig.isFront(root.CFrame.LookVector, away) then
		return amount
	end
	local cut = GuardConfig.cut(kind, ownBlock(target))
	if cut <= 0 then
		return amount
	end
	local prevented = amount * cut
	local now = workspace:GetServerTimeNow()
	local flat = Vector3.new(away.X, 0, away.Z)
	local toward = flat.Magnitude > 1e-4 and flat.Unit or root.CFrame.LookVector
	skillEffects:FireAllClients("Block", target, root.Position + toward * HIT_REACH + Vector3.new(0, HIT_HEIGHT, 0))
	local posture, broke = GuardConfig.postureAfter(target:GetAttribute("Posture") or 0, prevented)
	target:SetAttribute("Posture", posture)
	stateOf(target).lastAt = now
	if broke then
		guardBreak(target, now)
	end
	return amount - prevented
end

-- The Block remote: true when E goes down, false when it comes up
local blockRemote = Instance.new("RemoteEvent")
blockRemote.Name = "Block"
blockRemote.Parent = ReplicatedStorage

blockRemote.OnServerEvent:Connect(function(player, down)
	if typeof(down) ~= "boolean" then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if not down then
		-- letting go is always taken, so a block can never get stuck on
		setBlocking(character, false)
		return
	end
	local now = os.clock()
	if now - (lastPress[player] or -math.huge) < PRESS_THROTTLE then
		return
	end
	lastPress[player] = now
	-- no blocking while dead, already blocking, rewinding, stunned or just guard-broken
	if
		humanoid.Health <= 0
		or ActionLock.Locked(character)
		or (character:GetAttribute("GuardBrokenUntil") or 0) > workspace:GetServerTimeNow()
	then
		return
	end
	setBlocking(character, true)
end)

local function watchCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	-- a death leaves nothing for the respawn to inherit or the HUDs to keep drawing
	humanoid.Died:Once(function()
		states[character] = nil
		character:SetAttribute("Blocking", false)
		character:SetAttribute("Posture", 0)
		character:SetAttribute("HitstunUntil", 0)
		character:SetAttribute("GuardBrokenUntil", 0)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(watchCharacter)
end)
Players.PlayerRemoving:Connect(function(player)
	lastPress[player] = nil
	if player.Character then
		states[player.Character] = nil
	end
end)

-- Posture drains back down; a guard break's posture stays full through its stun
task.spawn(function()
	while true do
		local dt = task.wait(DRAIN_TICK)
		local now = workspace:GetServerTimeNow()
		for character, state in pairs(states) do
			if not character.Parent then
				states[character] = nil
			elseif state.resetAt then
				if now >= state.resetAt then
					state.resetAt = nil
					character:SetAttribute("Posture", 0)
				end
			else
				local posture = character:GetAttribute("Posture") or 0
				if posture > 0 then
					local blocking = character:GetAttribute("Blocking") == true
					local after = GuardConfig.drain(posture, now - state.lastAt, blocking, dt)
					if after ~= posture then
						character:SetAttribute("Posture", after)
					end
				end
			end
		end
	end
end)

return Guard
