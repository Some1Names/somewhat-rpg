-- Which powers a player holds, keeps and carries (the rules are in PowerConfig).
-- State is three saved attributes (PlayerStats): CurrentPower (the one power
-- held; its tool is handed out every spawn), PowerStorage (spares, up to
-- PowerConfig.StorageSlots) and LifetimePowers (bought with Robux, never lost).
-- While SkillSetConfig.OwnAllSets is on, every power counts as lifetime. The
-- PowerSet attribute mirrors CurrentPower for the older scripts that read it.
--
-- A new power arrives as a briefcase: a Tool with the PowerBriefcase attribute
-- (from ServerStorage.TestBriefcase, later Briefcase, else a plain box). A
-- briefcase is one Tool; it's destroyed the moment it's used, stored, sold or dropped, in the same step as the check, so remotes racing each other
-- can't spend it twice. Carried briefcases aren't saved: on death they drop
-- where you died for PowerConfig.DeathDropTime seconds, on leaving they're
-- lost. The inventory acts through the PowerAction remote; each action
-- returns ok, message (and a third value, true, when it needs the player's
-- confirm because a power would be lost).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local tools = ServerStorage:WaitForChild("SkillSetTools")

local ACTION_INTERVAL = 0.3 -- seconds between a player's actions
local ATTR = { current = "CurrentPower", storage = "PowerStorage", lifetime = "LifetimePowers" }
local PICKUP_REACH = 10 -- studs a briefcase pickup can be grabbed from

local Powers = {}

local actionRemote = ReplicatedStorage:FindFirstChild("PowerAction")
if not actionRemote then
	actionRemote = Instance.new("RemoteFunction")
	actionRemote.Name = "PowerAction"
	actionRemote.Parent = ReplicatedStorage
end

-- a power that can be held, stored and owned for life (not a placeholder)
local function isPower(setName)
	local set = SkillSetConfig.Sets[setName]
	return set ~= nil and set.kind == "power" and not set.placeholder
end

-- any power that can come as a briefcase, placeholders included (those can only be sold)
local function hasBriefcase(setName)
	local set = SkillSetConfig.Sets[setName]
	return set ~= nil and set.kind == "power"
end

-- "IridescentRequiem" -> "Iridescent Requiem"
function Powers.DisplayName(setName)
	return (string.gsub(setName, "(%l)(%u)", "%1 %2"))
end

local function ready(player)
	return player:GetAttribute(ATTR.current) ~= nil
end

-- the held power, or nil
function Powers.Current(player)
	local name = player:GetAttribute(ATTR.current)
	if typeof(name) == "string" and isPower(name) then
		return name
	end
	return nil
end

local function stored(player)
	return PowerConfig.decodeList(player:GetAttribute(ATTR.storage), isPower)
end

local function setStored(player, list)
	player:SetAttribute(ATTR.storage, PowerConfig.encodeList(list))
end

function Powers.Storage(player)
	return stored(player)
end

function Powers.IsLifetime(player, setName)
	if not isPower(setName) then
		return false
	end
	if SkillSetConfig.OwnAllSets then
		return true
	end
	return table.find(PowerConfig.decodeList(player:GetAttribute(ATTR.lifetime), isPower), setName) ~= nil
end

-- whether the power is held, in storage or owned for life
function Powers.Owns(player, setName)
	return Powers.Current(player) == setName or table.find(stored(player), setName) ~= nil or Powers.IsLifetime(player, setName)
end

-- the tools -----------------------------------------------------------------

local function eachTool(player, callback)
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ player.Character, backpack }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") then
					callback(child)
				end
			end
		end
	end
end

local function isPowerTool(tool)
	local setName = tool:GetAttribute("SkillSet")
	return setName ~= nil and isPower(setName)
end

-- makes the player carry exactly the current power's tool (and no other power's)
local function syncTool(player)
	local current = Powers.Current(player)
	local has = false
	eachTool(player, function(tool)
		if isPowerTool(tool) then
			if tool:GetAttribute("SkillSet") == current and not has then
				has = true
			else
				tool:Destroy()
			end
		end
	end)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if has or not current or not backpack then
		return
	end
	local template = tools:FindFirstChild(SkillSetConfig.Sets[current].tool)
	if template then
		template:Clone().Parent = backpack
	else
		warn("[Powers] no tool for " .. current .. " in ServerStorage.SkillSetTools")
	end
end

local function setCurrent(player, setName)
	player:SetAttribute(ATTR.current, setName or "")
end

local function makeBriefcase(setName)
	local name = Powers.DisplayName(setName) .. " Briefcase"
	-- the owner's models: TestBriefcase for now, Briefcase when the final one is made
	local template = ServerStorage:FindFirstChild("TestBriefcase") or ServerStorage:FindFirstChild("Briefcase")
	local tool
	if template and template:IsA("Tool") then
		tool = template:Clone()
	else
		-- placeholder until the owner adds a Tool named TestBriefcase or Briefcase to ServerStorage
		tool = Instance.new("Tool")
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(1.4, 1, 0.5)
		handle.Color = SkillSetConfig.Tiers[SkillSetConfig.Sets[setName].tier].color
		handle.Material = Enum.Material.Metal
		handle.Parent = tool
	end
	tool.Name = name
	tool.ToolTip = name
	tool.CanBeDropped = false -- dropping goes through the inventory and death
	tool:SetAttribute(PowerConfig.BriefcaseAttribute, setName)
	return tool
end

-- puts a briefcase for the power in the player's backpack
function Powers.GiveBriefcase(player, setName)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not hasBriefcase(setName) or not backpack then
		return false
	end
	makeBriefcase(setName).Parent = backpack
	return true
end

-- a carried briefcase of the power (nil if none)
local function findBriefcase(player, setName)
	local found
	eachTool(player, function(tool)
		if not found and tool:GetAttribute(PowerConfig.BriefcaseAttribute) == setName then
			found = tool
		end
	end)
	return found
end

-- takes one carried briefcase of the power; whether there was one
function Powers.TakeBriefcase(player, setName)
	local tool = findBriefcase(player, setName)
	if not tool then
		return false
	end
	tool:Destroy()
	return true
end

-- lifetime powers ------------------------------------------------------------

-- makes the power the player's for life (never twice). A copy of it in storage
-- is freed; holding it carries on.
function Powers.GrantLifetime(player, setName)
	if not isPower(setName) or not ready(player) then
		return false
	end
	local list = PowerConfig.decodeList(player:GetAttribute(ATTR.lifetime), isPower)
	if table.find(list, setName) then
		return true
	end
	table.insert(list, setName)
	player:SetAttribute(ATTR.lifetime, PowerConfig.encodeList(list))
	local spares = stored(player)
	local at = table.find(spares, setName)
	if at then
		table.remove(spares, at)
		setStored(player, spares)
	end
	return true
end

-- admin tool: sets the held power outright (the old one is lost unless owned for life)
function Powers.AdminSet(player, setName)
	if not ready(player) or (setName ~= nil and not isPower(setName)) then
		return false
	end
	setCurrent(player, setName)
	return true
end

-- death drops ------------------------------------------------------------------

-- drops a pickup of the power at the position, gone after `lifetime` seconds
-- (DeathDropTime if nil); ownerId (if any) can't take it for DeathPickupDelay seconds
local function dropPickup(setName, position, ownerId, lifetime)
	local part = Instance.new("Part")
	part.Name = Powers.DisplayName(setName) .. " Briefcase"
	part.Size = Vector3.new(1.6, 1.2, 0.6)
	part.Color = SkillSetConfig.Tiers[SkillSetConfig.Sets[setName].tier].color
	part.Material = Enum.Material.Metal
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0))
	part:SetAttribute(PowerConfig.BriefcaseAttribute, setName)
	local droppedAt = os.clock()
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = part.Name
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = PICKUP_REACH
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if part:GetAttribute("Claimed") then
			return
		end
		if player.UserId == ownerId and os.clock() - droppedAt < PowerConfig.DeathPickupDelay then
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or not player:FindFirstChildOfClass("Backpack") then
			return
		end
		part:SetAttribute("Claimed", true) -- claimed and destroyed in one step: no second taker
		part:Destroy()
		Powers.GiveBriefcase(player, setName)
	end)
	part.Parent = workspace
	Debris:AddItem(part, lifetime or PowerConfig.DeathDropTime)
	return part
end

Powers.DropPickup = dropPickup

-- on death, every carried briefcase drops where the player died
local function dropCarried(player, character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local position = root and root.Position
	if not position then
		return
	end
	local found = {}
	eachTool(player, function(tool)
		local setName = tool:GetAttribute(PowerConfig.BriefcaseAttribute)
		if setName then
			table.insert(found, { tool = tool, setName = setName })
		end
	end)
	for index, item in ipairs(found) do
		item.tool:Destroy()
		-- a little spread so they don't overlap
		local angle = index * 2.4
		dropPickup(item.setName, position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 2, player.UserId)
	end
end

-- the inventory's actions ----------------------------------------------------------

local lastAction = {}

local function slotsFree(player)
	return PowerConfig.StorageSlots - #stored(player)
end

-- whether swapping out the held power would lose it
local function wouldLose(player, current)
	return current ~= nil and not Powers.IsLifetime(player, current)
end

local actions = {}

-- a carried briefcase becomes the held power
function actions.use(player, setName, confirm)
	if Powers.Owns(player, setName) then
		return false, "You already own " .. Powers.DisplayName(setName) .. " (sell the briefcase instead)"
	end
	if not findBriefcase(player, setName) then
		return false, "You aren't carrying that briefcase"
	end
	local current = Powers.Current(player)
	if wouldLose(player, current) and not confirm then
		return false, string.format("Use %s? You'll lose %s.", Powers.DisplayName(setName), Powers.DisplayName(current)), true
	end
	Powers.TakeBriefcase(player, setName)
	setCurrent(player, setName)
	return true, "You now hold " .. Powers.DisplayName(setName)
end

-- a carried briefcase goes into a free storage slot
function actions.store(player, setName)
	if Powers.Owns(player, setName) then
		return false, "You already own " .. Powers.DisplayName(setName) .. " (sell the briefcase instead)"
	end
	if slotsFree(player) <= 0 then
		return false, "Storage is full"
	end
	if not Powers.TakeBriefcase(player, setName) then
		return false, "You aren't carrying that briefcase"
	end
	local list = stored(player)
	table.insert(list, setName)
	setStored(player, list)
	return true, Powers.DisplayName(setName) .. " is in storage"
end

-- a stored power comes back as a briefcase
function actions.takeOut(player, setName)
	local list = stored(player)
	local at = table.find(list, setName)
	if not at then
		return false, "That isn't in storage"
	end
	if not player:FindFirstChildOfClass("Backpack") then
		return false, "Try again in a moment"
	end
	table.remove(list, at)
	setStored(player, list)
	Powers.GiveBriefcase(player, setName)
	return true, Powers.DisplayName(setName) .. " is a briefcase again"
end

-- the held power and a stored one trade places; nothing is lost
function actions.swap(player, setName)
	local list = stored(player)
	local at = table.find(list, setName)
	if not at then
		return false, "That isn't in storage"
	end
	local current = Powers.Current(player)
	table.remove(list, at)
	-- a lifetime power never takes a slot
	if current and not Powers.IsLifetime(player, current) then
		table.insert(list, at, current)
	end
	setStored(player, list)
	setCurrent(player, setName)
	return true, "You now hold " .. Powers.DisplayName(setName)
end

-- switches to a lifetime power; the old one goes to a free slot, or is lost
function actions.switch(player, setName, confirm)
	if not Powers.IsLifetime(player, setName) then
		return false, "That isn't a lifetime power"
	end
	local current = Powers.Current(player)
	if current == setName then
		return false, "You already hold it"
	end
	if wouldLose(player, current) then
		if slotsFree(player) > 0 then
			local list = stored(player)
			table.insert(list, current)
			setStored(player, list)
		elseif not confirm then
			return false, string.format("Switch to %s? You'll lose %s.", Powers.DisplayName(setName), Powers.DisplayName(current)), true
		end
	end
	setCurrent(player, setName)
	return true, "You now hold " .. Powers.DisplayName(setName)
end

local function onAction(player, action, args)
	if typeof(action) ~= "string" or not actions[action] then
		return false, "Unknown action"
	end
	local setName = typeof(args) == "table" and args.set
	if typeof(setName) == "string" and hasBriefcase(setName) and not isPower(setName) then
		return false, Powers.DisplayName(setName) .. " isn't made yet. Sell the briefcase to the Power Dealer."
	end
	if typeof(setName) ~= "string" or not isPower(setName) then
		return false, "Unknown power"
	end
	local now = os.clock()
	if now - (lastAction[player] or 0) < ACTION_INTERVAL then
		return false, "Slow down"
	end
	lastAction[player] = now
	if not ready(player) then
		return false, "Still loading"
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, "Not now"
	end
	return actions[action](player, setName, args.confirm == true)
end

-- wiring -----------------------------------------------------------------------------

local function onPlayerAdded(player)
	player:GetAttributeChangedSignal(ATTR.current):Connect(function()
		local current = Powers.Current(player)
		player:SetAttribute("PowerSet", current)
		syncTool(player)
	end)
	local function onCharacter(character)
		player:WaitForChild("Backpack")
		task.defer(syncTool, player)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				dropCarried(player, character)
			end)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function Powers.Start()
	actionRemote.OnServerInvoke = onAction
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

return Powers
