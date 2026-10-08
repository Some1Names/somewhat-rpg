-- What each player carries: one power and one weapon at most
-- (SkillSetConfig.CarryLimit), kept as the PowerSet and WeaponSet attributes
-- on the player. Their tools (from ServerStorage.SkillSetTools) are handed
-- out every spawn; everyone starts with DEFAULT_POWER. A set bought in the
-- shop (a ShopConfig item with `set`, like the Revolver) is carried as soon
-- as it's owned, unless something of its kind already is. Players swap sets
-- through the inventory (client Inventory -> EquipSet remote), only for sets
-- they own (Loadout.Owns); the OwnedSets attribute lists those for the
-- client. For now the choice lasts the session: saving it comes with
-- deciding how sets are earned (shop ownership itself is saved by
-- PlayerStats).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local tools = ServerStorage:WaitForChild("SkillSetTools")
local equipRemote = ReplicatedStorage:WaitForChild("EquipSet")

local DEFAULT_POWER = "Mandela"
local ATTRIBUTES = { power = "PowerSet", weapon = "WeaponSet" }
local EQUIP_INTERVAL = 0.3 -- seconds between a player's swaps

local Loadout = {}

-- takes away any set of this kind the player is holding or carrying
local function removeKind(player, kind)
	local containers = { player.Character }
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end
	for _, container in ipairs(containers) do
		for _, child in ipairs(container:GetChildren()) do
			local setName = child:IsA("Tool") and child:GetAttribute("SkillSet")
			local set = setName and SkillSetConfig.Sets[setName]
			if set and set.kind == kind then
				child:Destroy()
			end
		end
	end
end

-- whether the player already has the set's tool, held or in the backpack
local function hasTool(player, setName)
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ player.Character, backpack }) do
		for _, child in ipairs(container and container:GetChildren() or {}) do
			if child:IsA("Tool") and child:GetAttribute("SkillSet") == setName then
				return true
			end
		end
	end
	return false
end

local function giveTool(player, setName)
	local template = tools:FindFirstChild(SkillSetConfig.Sets[setName].tool)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if hasTool(player, setName) then
		return
	end
	if template and backpack then
		template:Clone().Parent = backpack
	elseif not template then
		warn("[Loadout] no tool for " .. setName .. " in ServerStorage.SkillSetTools")
	end
end

-- swaps the player's power or weapon (whichever kind the set is) for this one
function Loadout.Give(player, setName)
	local set = SkillSetConfig.Sets[setName]
	if not set then
		return false
	end
	removeKind(player, set.kind)
	player:SetAttribute(ATTRIBUTES[set.kind], setName)
	giveTool(player, setName)
	return true
end

-- empties the player's power or weapon slot
function Loadout.Remove(player, kind)
	removeKind(player, kind)
	player:SetAttribute(ATTRIBUTES[kind], nil)
end

-- whether the player owns the set: the starting power, a set bought in the
-- shop, or any set while SkillSetConfig.OwnAllSets is on (testing)
function Loadout.Owns(player, setName)
	if not SkillSetConfig.Sets[setName] then
		return false
	end
	if SkillSetConfig.OwnAllSets or setName == DEFAULT_POWER then
		return true
	end
	for _, item in ipairs(ShopConfig.Items) do
		if item.set == setName and player:GetAttribute(ShopConfig.OwnedAttribute(item.id)) == 1 then
			return true
		end
	end
	return false
end

-- the OwnedSets attribute the inventory lists
local function refreshOwned(player)
	local owned = {}
	for setName in pairs(SkillSetConfig.Sets) do
		if Loadout.Owns(player, setName) then
			table.insert(owned, setName)
		end
	end
	table.sort(owned)
	player:SetAttribute(SkillSetConfig.OwnedSetsAttribute, table.concat(owned, ","))
end

-- the inventory asking to carry a set (setName), or to empty a slot (nil, kind)
local lastEquip = {}
local function onEquip(player, setName, kind)
	local now = os.clock()
	if now - (lastEquip[player] or 0) < EQUIP_INTERVAL then
		return false, "Slow down"
	end
	lastEquip[player] = now
	if setName == nil then
		if typeof(kind) ~= "string" or not ATTRIBUTES[kind] then
			return false, "Unknown slot"
		end
		Loadout.Remove(player, kind)
		return true
	end
	if typeof(setName) ~= "string" or not Loadout.Owns(player, setName) then
		return false, "You don't own that"
	end
	if player:GetAttribute(ATTRIBUTES[SkillSetConfig.Sets[setName].kind]) ~= setName then
		Loadout.Give(player, setName)
	end
	return true
end

-- sets bought in the shop, carried once owned if that kind's slot is free
local function carryOwned(player)
	for _, item in ipairs(ShopConfig.Items) do
		local set = item.set and SkillSetConfig.Sets[item.set]
		if set and player:GetAttribute(ShopConfig.OwnedAttribute(item.id)) == 1 and player:GetAttribute(ATTRIBUTES[set.kind]) == nil then
			Loadout.Give(player, item.set)
		end
	end
end

local function onCharacterAdded(player)
	-- each spawn brings a fresh backpack
	player:WaitForChild("Backpack")
	task.defer(function()
		for _, attribute in pairs(ATTRIBUTES) do
			local setName = player:GetAttribute(attribute)
			if setName and SkillSetConfig.Sets[setName] then
				giveTool(player, setName)
			end
		end
	end)
end

function Loadout.Start()
	local function onPlayerAdded(player)
		if player:GetAttribute(ATTRIBUTES.power) == nil then
			player:SetAttribute(ATTRIBUTES.power, DEFAULT_POWER)
		end
		-- ownership arrives when the save loads, or on buying it
		for _, item in ipairs(ShopConfig.Items) do
			if item.set then
				player:GetAttributeChangedSignal(ShopConfig.OwnedAttribute(item.id)):Connect(function()
					refreshOwned(player)
					carryOwned(player)
				end)
			end
		end
		refreshOwned(player)
		carryOwned(player)
		player.CharacterAdded:Connect(function()
			onCharacterAdded(player)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player)
		end
	end
	equipRemote.OnServerInvoke = onEquip
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		lastEquip[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

return Loadout
