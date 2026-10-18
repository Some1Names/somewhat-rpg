-- Talismans (numbers and rules: ReplicatedStorage.TalismanConfig). The owned and
-- worn lists are the saved TalismanOwned / TalismanEquipped attributes
-- (PlayerStats). The Backpack wears and takes off talismans through the
-- TalismanAction remote (made here): InvokeServer("equip" | "unequip", key)
-- returns ok, why. Effects are read where they apply: max HP (PlayerStats), regen
-- (Health), damage dealt and taken and kill yen (Damage), chest yen (Chests);
-- the heal on each kill is here. Talismans.Grant gives one (a chest drop) and
-- tells the player's toast through the TalismanFound attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TalismanConfig = require(ReplicatedStorage:WaitForChild("TalismanConfig"))
local Damage = require(script.Parent:WaitForChild("Damage"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))

local Talismans = {}

local rng = Random.new()

local function levelOf(player)
	return player:GetAttribute("Level") or 0
end

-- gives a talisman the player doesn't own yet; returns its key, or nil
function Talismans.Grant(player, key)
	local owned = TalismanConfig.Grant(player:GetAttribute(TalismanConfig.OwnedAttribute), key)
	if not owned then
		return nil
	end
	player:SetAttribute(TalismanConfig.OwnedAttribute, owned)
	player:SetAttribute(TalismanConfig.FoundAttribute, key .. ":" .. workspace:GetServerTimeNow())
	return key
end

-- a random one the player doesn't own, given to them; nil when they own them all
function Talismans.GrantRandom(player)
	local key = TalismanConfig.RollNew(player:GetAttribute(TalismanConfig.OwnedAttribute), function(n)
		return rng:NextInteger(1, n)
	end)
	return key and Talismans.Grant(player, key)
end

local remote = Instance.new("RemoteFunction")
remote.Name = "TalismanAction"
remote.Parent = ReplicatedStorage

remote.OnServerInvoke = function(player, action, key)
	if typeof(key) ~= "string" or (action ~= "equip" and action ~= "unequip") then
		return false, "Bad request"
	end
	local owned = player:GetAttribute(TalismanConfig.OwnedAttribute)
	local equipped = player:GetAttribute(TalismanConfig.EquippedAttribute)
	if owned == nil or equipped == nil then
		return false, "Still loading"
	end
	local worn, why
	if action == "equip" then
		worn, why = TalismanConfig.Equip(owned, equipped, key, levelOf(player))
	else
		worn, why = TalismanConfig.Unequip(equipped, key)
	end
	if not worn then
		return false, why
	end
	player:SetAttribute(TalismanConfig.EquippedAttribute, TalismanConfig.Encode(worn))
	PlayerStats.RefreshHealth(player) -- max HP may have changed
	return true
end

-- Second Wind: a heal on every kill
Damage.OnKill(function(killer, victim)
	local heal = TalismanConfig.Total(killer:GetAttribute(TalismanConfig.EquippedAttribute), "healOnKill")
	local character = killer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if heal > 0 and humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * heal * StatusConfig.HealMultiplier(character))
	end
end)

-- a worn talisman the player no longer owns can't stay on (an admin took it, or a bad save)
local function watchPlayer(player)
	player:GetAttributeChangedSignal(TalismanConfig.OwnedAttribute):Connect(function()
		local owned = TalismanConfig.Owned(player:GetAttribute(TalismanConfig.OwnedAttribute))
		local worn = TalismanConfig.Parse(player:GetAttribute(TalismanConfig.EquippedAttribute))
		local kept = {}
		for _, key in ipairs(worn) do
			if table.find(owned, key) then
				table.insert(kept, key)
			end
		end
		if #kept ~= #worn then
			player:SetAttribute(TalismanConfig.EquippedAttribute, TalismanConfig.Encode(kept))
			PlayerStats.RefreshHealth(player)
		end
	end)
end
for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)

return Talismans
