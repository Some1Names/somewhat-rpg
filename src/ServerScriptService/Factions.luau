-- Factions: joining at a recruiter and earning standing. The saved, replicated
-- `FactionData` text ("<key>:<standing>:<joinedAt>", PlayerStats saves it) is the
-- truth; FactionConfig has the numbers and rules. Mirrored as the Faction,
-- FactionStanding, FactionRank and FactionDiscount attributes for the UI. Standing comes from a
-- Damage.OnKill listener: NPC enemies, and players of a rival faction.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Damage = require(script.Parent:WaitForChild("Damage"))
local FactionConfig = require(ReplicatedStorage:WaitForChild("FactionConfig"))

local Factions = {}

local function read(player)
	return FactionConfig.Parse(player:GetAttribute(FactionConfig.SaveAttribute))
end

local function mirror(player)
	local key, standing = read(player)
	player:SetAttribute("Faction", key or "")
	player:SetAttribute("FactionStanding", standing)
	player:SetAttribute("FactionRank", key and FactionConfig.RankName(standing, key) or "")
	player:SetAttribute("FactionDiscount", FactionConfig.ShopDiscount(key, standing))
end

-- the share off shop prices this player gets from their faction rank
function Factions.ShopDiscount(player)
	local key, standing = read(player)
	return FactionConfig.ShopDiscount(key, standing)
end

function Factions.Get(player)
	local key, standing = read(player)
	return key, standing
end

-- joins `newKey`; returns ok, reason. Switching starts again at 0 standing.
function Factions.Join(player, newKey)
	if player:GetAttribute(FactionConfig.SaveAttribute) == nil then
		return false, "Still loading"
	end
	local key, _, joinedAt = read(player)
	local ok, reason = FactionConfig.CanJoin(key, joinedAt, newKey, os.time())
	if not ok then
		return false, reason
	end
	player:SetAttribute(FactionConfig.SaveAttribute, FactionConfig.Encode(newKey, 0, os.time()))
	return true, ""
end

function Factions.AddStanding(player, amount)
	local key, standing, joinedAt = read(player)
	if not key or amount <= 0 then
		return
	end
	player:SetAttribute(FactionConfig.SaveAttribute, FactionConfig.Encode(key, standing + amount, joinedAt))
end

Damage.OnKill(function(killer, victim, _hit, victimIsPlayer)
	local killerKey = read(killer)
	local victimPlayer = victimIsPlayer and Players:GetPlayerFromCharacter(victim) or nil
	local victimKey = victimPlayer and read(victimPlayer) or nil
	Factions.AddStanding(killer, FactionConfig.KillStanding(victimIsPlayer, killerKey, victimKey))
end)

local function onPlayer(player)
	player:GetAttributeChangedSignal(FactionConfig.SaveAttribute):Connect(function()
		mirror(player)
	end)
	if player:GetAttribute(FactionConfig.SaveAttribute) ~= nil then
		mirror(player)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end

return Factions
