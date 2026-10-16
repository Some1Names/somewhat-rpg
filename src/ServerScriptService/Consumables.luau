-- Runs the consumable items (ConsumableConfig): hands the Tools over, and
-- uses them when the player clicks with one held (Tool.Activated fires on the
-- server) or presses USE in the Backpack (the ConsumableAction remote). A use
-- needs a live, unlocked character and a ready cooldown, and only counts when
-- the effect did something (a heal at full HP is free). A limited stack loses a
-- charge and is gone at 0, in the same step as the check, so clicks racing each
-- other can't spend it twice.
-- A stack is either equipped (a Tool on the hotbar, at most HotbarSlots of
-- them) or stored (an entry in the saved ConsumableStorage attribute, kept
-- through death and rejoining; the Backpack stores, equips and uses them).
-- An equipped limited Tool is lost on death like any Tool in the backpack. A
-- lifetime item is owned through the shop's Owns<id> attribute (saved by
-- PlayerStats): it goes into storage when bought or when its Tool is lost on death.
-- Nothing equips itself: bought and found items go to storage, and the Backpack's EQUIP
-- puts one on a free hotbar slot (HotbarSlots).
-- Effects must not yield before they return.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ActionLock = require(ReplicatedStorage:WaitForChild("ActionLock"))
local ConsumableConfig = require(ReplicatedStorage:WaitForChild("ConsumableConfig"))
local CrowdControl = require(script.Parent:WaitForChild("CrowdControl"))
local HotbarRules = require(ReplicatedStorage:WaitForChild("HotbarRules"))
local HotbarSlots = require(script.Parent:WaitForChild("HotbarSlots"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local StatusEffects = require(script.Parent:WaitForChild("StatusEffects"))

local Consumables = {}

local HEAL_STEP = 0.5 -- seconds between Rift Suture's ticks
local GRAPPLE_STOP = 2 -- studs short of a wall the grapple lands

local actionRemote = ReplicatedStorage:FindFirstChild("ConsumableAction")
if not actionRemote then
	actionRemote = Instance.new("RemoteFunction")
	actionRemote.Name = "ConsumableAction"
	actionRemote.Parent = ReplicatedStorage
end

-- player -> item key -> when its cooldown ends (server time)
local readyAt = {}
local nextStackId = 0

local function aliveHumanoid(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- the saved data has come in (stored stacks written before that would be overwritten by it);
-- Studio never saves, so there it needn't wait (without DataStore access it never loads)
local function loaded(player)
	return player:GetAttribute("Level") ~= nil or RunService:IsStudio()
end

-- effects: item, player, character, humanoid -> whether it did something
local effects = {}

function effects.Heal(item, _, _, humanoid)
	local amount = ConsumableConfig.HealAmount(item.heal, humanoid.MaxHealth, humanoid.Health)
	if amount <= 0 then
		return false
	end
	humanoid.Health += amount
	return true
end

function effects.Purge(_, _, character)
	local cleared = false
	for _, name in ipairs({ "Poisoned", "Bleeding", "Burnt" }) do
		if StatusEffects.Has(character, name) then
			StatusEffects.Clear(character, name)
			cleared = true
		end
	end
	return cleared
end

function effects.Overclock(item, _, character)
	local now = workspace:GetServerTimeNow()
	character:SetAttribute("OverclockUntil", now + item.duration)
	character:SetAttribute("CrashUntil", now + item.duration + item.crash)
	return true
end

-- heals a little each step; a hit that lowers health cancels the rest
function effects.Suture(item, _, character, humanoid)
	if humanoid.Health >= humanoid.MaxHealth then
		return false
	end
	local steps = math.floor(item.duration / HEAL_STEP)
	task.spawn(function()
		local last = humanoid.Health
		for _ = 1, steps do
			task.wait(HEAL_STEP)
			if humanoid.Health <= 0 or not character:IsDescendantOf(workspace) or humanoid.Health < last - 0.01 then
				return
			end
			humanoid.Health += ConsumableConfig.HealAmount(item.heal / steps, humanoid.MaxHealth, humanoid.Health)
			last = humanoid.Health
		end
	end)
	return true
end

-- moves the player toward where they face, stopping short of a wall
function effects.Grapple(item, _, character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not CrowdControl.CanControl(character) then
		return false
	end
	local direction = root.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(root.Position, direction * item.distance, params)
	local distance = hit and math.max(0, hit.Distance - GRAPPLE_STOP) or item.distance
	if distance < 3 then
		return false
	end
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(character:GetPivot() + direction * distance)
	return true
end

-- the stored stacks -------------------------------------------------------------

local function getStored(player)
	return ConsumableConfig.ParseStorage(player:GetAttribute(ConsumableConfig.StorageAttribute))
end

local function setStored(player, list)
	player:SetAttribute(ConsumableConfig.StorageAttribute, ConsumableConfig.SerializeStorage(list))
end

-- the Tool ---------------------------------------------------------------------

local function carriedTools(player, key)
	local found = {}
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		for _, tool in ipairs(container and container:GetChildren() or {}) do
			if tool:IsA("Tool") then
				local toolKey = tool:GetAttribute(ConsumableConfig.Attribute)
				if toolKey and (key == nil or toolKey == key) then
					table.insert(found, tool)
				end
			end
		end
	end
	return found
end

-- how many stacks of the item the player has, equipped and stored (nil: of any item, equipped only)
function Consumables.Carried(player, key)
	if key == nil then
		return #carriedTools(player)
	end
	return #carriedTools(player, key) + ConsumableConfig.StoredCount(getStored(player), key)
end

-- uses an item's effect: the checks every use shares (alive, not locked, off cooldown, the
-- effect did something); starts the cooldown. Returns whether it went through, and why not
local function perform(player, item)
	local character = player.Character
	local humanoid = aliveHumanoid(player)
	if not humanoid or ActionLock.Locked(character) then
		return false, "Not now"
	end
	local now = workspace:GetServerTimeNow()
	local ready = readyAt[player] or {}
	local left = ConsumableConfig.CooldownLeft(ready[item.key], now)
	if left > 0 then
		return false, string.format("Ready in %d s", math.ceil(left))
	end
	if not effects[item.effect](item, player, character, humanoid) then
		return false, "That would do nothing now"
	end
	ready[item.key] = now + item.cooldown
	readyAt[player] = ready
	player:SetAttribute("ConsumableReadyAt_" .. item.key, now + item.cooldown)
	return true
end

local function use(player, tool)
	local key = typeof(tool) == "Instance" and tool:GetAttribute(ConsumableConfig.Attribute)
	local item = key and ConsumableConfig.Get(key)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if not item or (tool.Parent ~= character and tool.Parent ~= backpack) then
		return false, "You don't have that"
	end
	local ok, why = perform(player, item)
	if not ok then
		return false, why
	end
	if item.kind == "limited" then
		local uses = ConsumableConfig.Spend(item, tool:GetAttribute(ConsumableConfig.UsesAttribute) or 0)
		if ConsumableConfig.Spent(item, uses) then
			tool:Destroy()
		else
			tool:SetAttribute(ConsumableConfig.UsesAttribute, uses)
			tool.Name = ConsumableConfig.Label(item, uses)
			tool.ToolTip = tool.Name
		end
	end
	return true
end

local function makeTool(item, uses)
	local tool = Instance.new("Tool")
	tool.Name = ConsumableConfig.Label(item, uses)
	tool.ToolTip = item.description
	tool.CanBeDropped = false -- the shop and death decide where it goes
	tool.RequiresHandle = true
	-- placeholder until the owner makes the final model
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 1, 0.5)
	handle.Color = item.kind == "lifetime" and Color3.fromRGB(60, 224, 230) or Color3.fromRGB(255, 154, 60)
	handle.Material = Enum.Material.Neon
	handle.Parent = tool
	nextStackId += 1
	tool:SetAttribute(ConsumableConfig.Attribute, item.key)
	tool:SetAttribute(ConsumableConfig.StackAttribute, nextStackId)
	if item.kind == "limited" then
		tool:SetAttribute(ConsumableConfig.UsesAttribute, uses)
	end
	return tool
end

-- puts a Tool in the player's backpack on a hotbar slot (full charges when limited unless `uses`
-- says how many); the Tool, or nil
function Consumables.Give(player, key, uses, slot)
	local item = ConsumableConfig.Get(key)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not item or not backpack then
		return nil
	end
	local tool = makeTool(item, uses or item.maxUses or 0)
	tool:SetAttribute(HotbarRules.Attribute, slot)
	tool.Activated:Connect(function()
		use(player, tool)
	end)
	tool.Parent = backpack
	return tool
end

-- what a purchase hands over: a stored stack, never equipped (the Backpack equips it onto a slot
-- the player picks). Returns whether it worked
function Consumables.Grant(player, key)
	local item = ConsumableConfig.Get(key)
	if not item or not loaded(player) then
		return false
	end
	local list = getStored(player)
	if not ConsumableConfig.CanStore(#list) then
		return false
	end
	table.insert(list, { key = key, uses = item.maxUses })
	setStored(player, list)
	return true
end

-- the Backpack's actions ---------------------------------------------------------

-- moves an equipped Tool into storage
function Consumables.Store(player, tool)
	local key = typeof(tool) == "Instance" and tool:IsA("Tool") and tool:GetAttribute(ConsumableConfig.Attribute)
	local item = key and ConsumableConfig.Get(key)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not item or (tool.Parent ~= player.Character and tool.Parent ~= backpack) then
		return false, "You don't have that"
	end
	if not loaded(player) then
		return false, "Still loading"
	end
	local list = getStored(player)
	if not ConsumableConfig.CanStore(#list) then
		return false, "Storage is full"
	end
	table.insert(list, { key = key, uses = item.kind == "limited" and (tool:GetAttribute(ConsumableConfig.UsesAttribute) or item.maxUses) or nil })
	tool:Destroy()
	setStored(player, list)
	return true
end

-- takes a stored stack out onto a free hotbar slot (`slot`, or the first free one if nil)
function Consumables.Equip(player, index, slot)
	if not loaded(player) then
		return false, "Still loading"
	end
	local list = getStored(player)
	local entry = list[index]
	local item = entry and ConsumableConfig.Get(entry.key)
	if not item then
		return false, "That's gone"
	end
	local picked = HotbarSlots.Pick(player, slot)
	if not picked then
		return false, slot and "That slot is taken" or "The hotbar is full"
	end
	if #carriedTools(player, entry.key) > 0 and item.kind == "lifetime" then
		return false, "You already have it equipped"
	end
	table.remove(list, index)
	if not Consumables.Give(player, entry.key, entry.uses, picked) then
		return false, "Not now"
	end
	setStored(player, list)
	return true
end

-- uses a stored stack where it is
function Consumables.UseStored(player, index)
	if not loaded(player) then
		return false, "Still loading"
	end
	local list = getStored(player)
	local entry = list[index]
	local item = entry and ConsumableConfig.Get(entry.key)
	if not item then
		return false, "That's gone"
	end
	local ok, why = perform(player, item)
	if not ok then
		return false, why
	end
	if item.kind == "limited" then
		local uses = ConsumableConfig.Spend(item, entry.uses)
		if ConsumableConfig.Spent(item, uses) then
			table.remove(list, index)
		else
			entry.uses = uses
		end
		setStored(player, list)
	end
	return true
end

actionRemote.OnServerInvoke = function(player, action, target, slot)
	if action == "use" then
		if typeof(target) == "Instance" then
			return use(player, target)
		elseif typeof(target) == "number" and target == target then
			return Consumables.UseStored(player, math.floor(target))
		end
	elseif action == "store" and typeof(target) == "Instance" then
		return Consumables.Store(player, target)
	elseif action == "equip" and typeof(target) == "number" and target == target then
		return Consumables.Equip(player, math.floor(target), typeof(slot) == "number" and slot == math.floor(slot) and slot or nil)
	end
	return false, "Not allowed"
end

-- a lifetime item the player owns goes into storage if it is neither equipped nor stored already
-- (bought, or lost with the Tool on death); it never equips itself
local function storeOwned(player)
	if not loaded(player) then
		return
	end
	local list = getStored(player)
	local added = false
	for _, item in ipairs(ConsumableConfig.Items) do
		local owned = player:GetAttribute(ShopConfig.OwnedAttribute(ConsumableConfig.ShopId(item))) == 1
		if item.kind == "lifetime" and owned and #carriedTools(player, item.key) == 0 and ConsumableConfig.StoredCount(list, item.key) == 0 and ConsumableConfig.CanStore(#list) then
			table.insert(list, { key = item.key })
			added = true
		end
	end
	if added then
		setStored(player, list)
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.defer(storeOwned, player)
	end)
	-- the saved Owns<id> and stored stacks load a moment after the player joins
	player.AttributeChanged:Connect(function(name)
		if (string.sub(name, 1, 4) == "Owns" or name == ConsumableConfig.StorageAttribute) and player.Character then
			task.defer(storeOwned, player)
		end
	end)
	if player.Character then
		task.defer(storeOwned, player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
Players.PlayerRemoving:Connect(function(player)
	readyAt[player] = nil
end)

return Consumables
