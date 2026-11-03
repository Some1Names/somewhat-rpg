-- Gear (numbers and rules: ReplicatedStorage.GearConfig). The bag and the worn
-- pieces are the saved GearBag / GearWorn attributes (PlayerStats). Crafting and the
-- dungeon chest hand out pieces with Gear.Grant, which refuses when the bag is full
-- (a paid craft is never thrown away); drops that must not stall use GrantOrSalvage.
-- The Backpack wears, takes off and salvages through the GearAction remote
-- (GearServer). Effects are read where they apply: damage and kill yen (Damage), max
-- HP (PlayerStats), regen (Health), chest yen (Chests); the heal on each kill is here.
-- OnChanged callbacks run after a worn piece changes (GearVisuals).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Damage = require(script.Parent:WaitForChild("Damage"))
local DropConfig = require(ReplicatedStorage:WaitForChild("DropConfig"))
local GearConfig = require(ReplicatedStorage:WaitForChild("GearConfig"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))

local Gear = {}

local listeners = {}

-- calls `callback(player)` after a worn piece changes
function Gear.OnChanged(callback)
	table.insert(listeners, callback)
end

local function changed(player)
	for _, callback in ipairs(listeners) do
		task.spawn(callback, player)
	end
end

local function loaded(player)
	return player:GetAttribute(GearConfig.BagAttribute) ~= nil and player:GetAttribute(GearConfig.WornAttribute) ~= nil
end

local function levelOf(player)
	return player:GetAttribute("Level") or 0
end

-- adds salvaged materials to the player's bag, up to the cap
local function giveMaterials(player, yield)
	for _, entry in ipairs(yield) do
		local attribute = DropConfig.Attribute(entry.material)
		local current = player:GetAttribute(attribute) or 0
		local taken = DropConfig.Fit(current, entry.amount)
		player:SetAttribute(attribute, current + taken)
	end
end

-- rolls a piece and puts it in the bag: true, or false and why (the bag is full)
function Gear.Grant(player, slot, rarity, level, seed, affixHint)
	if not loaded(player) then
		return false, "Still loading"
	end
	if not table.find(GearConfig.Slots, slot) or not GearConfig.Rarity(rarity) or typeof(level) ~= "number" or typeof(seed) ~= "number" then
		return false, "Bad piece"
	end
	local bag = player:GetAttribute(GearConfig.BagAttribute)
	local id = GearConfig.NewId(bag, player:GetAttribute(GearConfig.WornAttribute))
	local piece = GearConfig.Roll(slot, rarity, level, seed, affixHint, id)
	local added, why = GearConfig.Add(bag, piece)
	if not added then
		return false, why
	end
	player:SetAttribute(GearConfig.BagAttribute, added)
	return true
end

-- like Grant, but a full bag turns the piece into its salvage materials instead
function Gear.GrantOrSalvage(player, slot, rarity, level, seed, affixHint)
	local ok, why = Gear.Grant(player, slot, rarity, level, seed, affixHint)
	if ok or why ~= "Gear bag is full" then
		return ok, why
	end
	giveMaterials(player, GearConfig.Rarity(rarity).salvage)
	return true
end

-- wears bag piece `id` (swapping with the one in its slot)
function Gear.Equip(player, id)
	if not loaded(player) then
		return false, "Still loading"
	end
	local bag, worn, why = GearConfig.Equip(player:GetAttribute(GearConfig.BagAttribute), player:GetAttribute(GearConfig.WornAttribute), id, levelOf(player))
	if not bag then
		return false, why
	end
	player:SetAttribute(GearConfig.BagAttribute, bag)
	player:SetAttribute(GearConfig.WornAttribute, worn)
	changed(player)
	return true
end

-- takes the piece in `slot` off, into the bag
function Gear.Unequip(player, slot)
	if not loaded(player) then
		return false, "Still loading"
	end
	local bag, worn, why = GearConfig.Unequip(player:GetAttribute(GearConfig.BagAttribute), player:GetAttribute(GearConfig.WornAttribute), slot)
	if not bag then
		return false, why
	end
	player:SetAttribute(GearConfig.BagAttribute, bag)
	player:SetAttribute(GearConfig.WornAttribute, worn)
	changed(player)
	return true
end

-- turns bag piece `id` into materials
function Gear.Salvage(player, id)
	if not loaded(player) then
		return false, "Still loading"
	end
	local bag, yield, why = GearConfig.Salvage(player:GetAttribute(GearConfig.BagAttribute), id)
	if not bag then
		return false, why
	end
	player:SetAttribute(GearConfig.BagAttribute, bag)
	giveMaterials(player, yield)
	return true
end

-- worn pieces change a player's max HP (also on load, when the saved text arrives)
local function watchPlayer(player)
	player:GetAttributeChangedSignal(GearConfig.WornAttribute):Connect(function()
		PlayerStats.RefreshHealth(player)
	end)
end
for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)

-- a heal on every kill from worn gear (beside Second Wind's)
Damage.OnKill(function(killer, victim)
	local heal = GearConfig.Total(killer:GetAttribute(GearConfig.WornAttribute), "healOnKill")
	local character = killer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if heal > 0 and humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * heal * StatusConfig.HealMultiplier(character))
	end
end)

return Gear
