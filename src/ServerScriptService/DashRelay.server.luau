-- Tells every other player when someone dashes so their clients draw the trail.
-- Allows as many dashes in a row as the player's dodge charges, refilling at
-- the same rate as the DodgeCharges module. A skill set with its own dash
-- (Iridescent Requiem's Lightstep) spends a charge the same way, then sends
-- where it went from and to, and its handler in ServerScriptService.Skills
-- takes over. Every dash is also a dodge: it breaks a hold on the player
-- (CrowdControl.Dodge).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CrowdControl = require(ServerScriptService:WaitForChild("CrowdControl"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local dashEffect = ReplicatedStorage:WaitForChild("DashEffect")
local skillModules = ServerScriptService:WaitForChild("Skills")

local RECHARGE_TIME = 1 -- seconds per charge; matches the DodgeCharges module
local TOLERANCE = 0.1 -- network jitter between client and server timing

local buckets = {} -- player -> { charges, at }

local function isPoint(value)
	return typeof(value) == "Vector3"
		and value == value
		and math.abs(value.X) < 1e5
		and math.abs(value.Y) < 1e5
		and math.abs(value.Z) < 1e5
end

dashEffect.OnServerEvent:Connect(function(player, from, to)
	local now = os.clock()
	local max = StatConfig.DodgeCharges(player:GetAttribute("Level") or 0)
	local bucket = buckets[player] or { charges = max, at = now }
	buckets[player] = bucket
	bucket.charges = math.min(bucket.charges + (now - bucket.at) / RECHARGE_TIME, max)
	bucket.at = now
	if bucket.charges < 1 - TOLERANCE then
		return
	end
	bucket.charges -= 1
	local character = player.Character
	if character then
		CrowdControl.Dodge(character)
	end
	local _, setName = SkillSetConfig.Equipped(character)
	local dash = setName and SkillSetConfig.Sets[setName].dash
	if dash then
		if isPoint(from) and isPoint(to) then
			require(skillModules:WaitForChild(dash.handler)).Dash(player, character, from, to)
		end
		return
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			dashEffect:FireClient(other, player)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)
