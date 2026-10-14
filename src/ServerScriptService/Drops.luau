-- Enemy drops. When an enemy (a model tagged "Enemy") dies, every player who
-- dealt at least DropConfig.ContributionShare of its max health rolls their
-- own drops (DropConfig.Rolls) and gets an orb for each, in workspace.Drops.
-- An orb is the owner's alone for OwnerWindow seconds, then anyone's for
-- PublicWindow more. Walking close takes it into the Mat_<key> bag
-- (PlayerStats saves it). All decided here; the client only hides orbs that
-- aren't yours (DropClient).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Damage = require(script.Parent:WaitForChild("Damage"))
local DropConfig = require(ReplicatedStorage:WaitForChild("DropConfig"))

local Drops = {}

local started = false
local folder
local orbs = {} -- every orb in the world, oldest first
local damageBy = setmetatable({}, { __mode = "k" }) -- enemy model -> { [player] = damage dealt }
local warned = {}

local function warnOnce(reason)
	if not warned[reason] then
		warned[reason] = true
		warn("Drops: " .. reason)
	end
end

local function isEnemy(model)
	return model ~= nil and CollectionService:HasTag(model, DropConfig.EnemyTag) and Players:GetPlayerFromCharacter(model) == nil
end

local function track(attacker, humanoid, dealt)
	local model = humanoid.Parent
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Player") or not isEnemy(model) then
		return
	end
	local ledger = damageBy[model]
	if not ledger then
		ledger = setmetatable({}, { __mode = "k" })
		damageBy[model] = ledger
	end
	ledger[attacker] = (ledger[attacker] or 0) + dealt
end

local function orbPart(material)
	local info = DropConfig.Materials[material]
	if not info then
		warnOnce("unknown material " .. tostring(material))
		return nil
	end
	local prefabs = ReplicatedStorage:FindFirstChild("VFXPrefabs")
	local prefab = prefabs and prefabs:FindFirstChild(DropConfig.PrefabPath)
	if not prefab then
		warnOnce("ReplicatedStorage.VFXPrefabs." .. DropConfig.PrefabPath .. " is missing")
		return nil
	end
	local orbName = DropConfig.Tiers[info.tier].orb
	local choices = {}
	for _, child in ipairs(prefab:GetChildren()) do
		if child.Name == orbName and child:IsA("BasePart") then
			table.insert(choices, child)
		end
	end
	if #choices == 0 then
		warnOnce("the orb prefab has no part named " .. orbName)
		return nil
	end
	return choices[math.random(#choices)], info
end

local function labelText(material, amount)
	return string.format("%s x%d", DropConfig.Materials[material].display, amount)
end

local function removeOrb(orb)
	local index = table.find(orbs, orb)
	if index then
		table.remove(orbs, index)
	end
	orb:Destroy()
end

-- an orb for `player` near `position`, dropped onto the ground
local function spawnOrb(player, material, amount, position, enemy)
	local template, info = orbPart(material)
	if not template then
		return
	end
	local angle = math.random() * 2 * math.pi
	local radius = DropConfig.ScatterRadius * math.sqrt(math.random())
	local x, z = position.X + math.cos(angle) * radius, position.Z + math.sin(angle) * radius

	local exclude = { folder, enemy }
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(Vector3.new(x, position.Y + 5, z), Vector3.new(0, -60, 0), params)
	local y = (hit and hit.Position.Y or position.Y) + DropConfig.HoverHeight

	local orb = template:Clone()
	orb.Name = "Orb"
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.Position = Vector3.new(x, y, z)

	local color = DropConfig.TierColor(info.tier)
	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.AlwaysOnTop = true
	label.Size = UDim2.fromOffset(120, 20)
	label.StudsOffset = Vector3.new(0, 2, 0)
	label.Parent = orb
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 14
	text.TextColor3 = color
	text.TextStrokeTransparency = 0
	text.Text = labelText(material, amount)
	text.Parent = label

	local publicAt = workspace:GetServerTimeNow() + DropConfig.OwnerWindow
	orb:SetAttribute("OwnerUserId", player.UserId)
	orb:SetAttribute("Material", material)
	orb:SetAttribute("Amount", amount)
	orb:SetAttribute("PublicAt", publicAt)
	orb:SetAttribute("ExpiresAt", publicAt + DropConfig.PublicWindow)
	orb.Parent = folder

	table.insert(orbs, orb)
	while #orbs > DropConfig.MaxDrops do
		removeOrb(orbs[1])
	end
end

local function onKill(_killer, character, _hit, victimIsPlayer)
	if victimIsPlayer or not isEnemy(character) then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	-- read now, the model may be gone by the time the rolls run
	local position = character:GetPivot().Position
	local maxHealth = humanoid.MaxHealth
	local level = character:GetAttribute("Level")
	local tableName = character:GetAttribute(DropConfig.TableAttribute)
	-- the killing blow's Damage.OnDealt may not have run yet: wait for it
	task.defer(function()
		local ledger = damageBy[character]
		damageBy[character] = nil
		if not ledger then
			return
		end
		for player, damage in pairs(ledger) do
			if player.Parent and DropConfig.IsHelper(damage, maxHealth) then
				for _, drop in ipairs(DropConfig.Rolls(level, tableName, math.random)) do
					spawnOrb(player, drop.material, drop.amount, position, character)
				end
			end
		end
	end)
end

-- expires old orbs, then lets each living player take what they may
local function tick()
	local now = workspace:GetServerTimeNow()
	for i = #orbs, 1, -1 do
		local orb = orbs[i]
		if not orb.Parent then
			table.remove(orbs, i)
		elseif now >= orb:GetAttribute("ExpiresAt") then
			removeOrb(orb)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			for i = #orbs, 1, -1 do
				local orb = orbs[i]
				local material = orb.Parent and orb:GetAttribute("Material")
				local attribute = material and DropConfig.Attribute(material)
				local bag = attribute and player:GetAttribute(attribute)
				if typeof(bag) == "number" and DropConfig.CanPickUp(orb:GetAttribute("OwnerUserId"), player.UserId, now, orb:GetAttribute("PublicAt")) then
					local offset = orb.Position - root.Position
					if DropConfig.InRange(Vector3.new(offset.X, 0, offset.Z).Magnitude, offset.Y) then
						local taken, left = DropConfig.Fit(bag, orb:GetAttribute("Amount"))
						if taken > 0 then
							-- the orb goes (or shrinks) before the bag is credited
							if left == 0 then
								removeOrb(orb)
							else
								orb:SetAttribute("Amount", left)
								orb.Label.Text.Text = labelText(material, left)
							end
							player:SetAttribute(attribute, bag + taken)
						end
					end
				end
			end
		end
	end
end

function Drops.Start()
	if started then
		return
	end
	started = true
	folder = workspace:FindFirstChild(DropConfig.FolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = DropConfig.FolderName
		folder.Parent = workspace
	end
	Damage.OnDealt(track)
	Damage.OnKill(onKill)
	task.spawn(function()
		while true do
			task.wait(DropConfig.PickupInterval)
			local ok, err = pcall(tick)
			if not ok then
				warn("Drops: " .. tostring(err))
			end
		end
	end)
end

return Drops
