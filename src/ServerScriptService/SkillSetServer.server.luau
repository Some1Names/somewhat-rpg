-- Server side of skill sets (like Mandela). While a set's tool is equipped the
-- character wears the set's pieces (ServerStorage.SkillSets.<set>.Wearables;
-- ones marked OverchargeOnly only while the set is overcharged, along with an
-- aura) and can cast its Z/X/C/V skills. Every cast is checked here: the tool is
-- equipped, the skill exists and is unlocked by the player's mastery in the
-- set, and it's off cooldown. The skills themselves live in
-- ServerScriptService.Skills. The overcharge key (ActivateOvercharge) also
-- comes through here, for the set in hand.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Overcharge = require(ServerScriptService:WaitForChild("Overcharge"))
local SkillCooldowns = require(ServerScriptService:WaitForChild("SkillCooldowns"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")
local useSkill = ReplicatedStorage:WaitForChild("UseSkill")
local activateOvercharge = ReplicatedStorage:WaitForChild("ActivateOvercharge")
local skillModules = ServerScriptService:WaitForChild("Skills")
local assets = ServerStorage:WaitForChild("SkillSets")

local COOLDOWN_TOLERANCE = 0.15 -- network jitter between client and server timing
local WEARABLES_FOLDER = "SkillSetWearables"
local AURA_NAME = "OverchargeAura"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local handlers = {}

-- a set that breaks the tier rules is reported in the output, not hidden
for setName, set in pairs(SkillSetConfig.Sets) do
	if not SkillSetConfig.CarryLimit[set.kind] then
		warn(string.format("[SkillSetServer] %s has kind %q; use power or weapon", setName, tostring(set.kind)))
	elseif not SkillSetConfig.Tiers[set.tier] then
		warn(string.format("[SkillSetServer] %s has tier %q; use S, A, B or C", setName, tostring(set.tier)))
	else
		local moves = 0
		for _ in pairs(set.skills) do
			moves += 1
		end
		local limit = SkillSetConfig.SlotLimit(setName)
		if moves > limit then
			warn(string.format("[SkillSetServer] %s has %d moves; a %s-tier %s gets %d", setName, moves, set.tier, set.kind, limit))
		end
	end
end

local function handlerFor(name)
	if not handlers[name] then
		handlers[name] = require(skillModules:WaitForChild(name))
	end
	return handlers[name]
end

local function isFiniteVector(v)
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e5 and math.abs(v.Y) < 1e5 and math.abs(v.Z) < 1e5
end

-- Puts one piece on the body part its attributes name: AttachTo (body part),
-- AttachAttachment (optional attachment in it) and AttachOffset (CFrame).
local function wear(character, piece, folder)
	local primary = piece:IsA("Model") and piece.PrimaryPart or piece
	local bodyPart = character:FindFirstChild(primary:GetAttribute("AttachTo"))
	if not bodyPart then
		return
	end
	local anchorName = primary:GetAttribute("AttachAttachment")
	local anchor = anchorName and bodyPart:FindFirstChild(anchorName)
	local copy = piece:Clone()
	local weld = Instance.new("Weld")
	weld.Part0 = bodyPart
	weld.Part1 = copy:IsA("Model") and copy.PrimaryPart or copy
	weld.C0 = (anchor and anchor.CFrame or CFrame.identity) * primary:GetAttribute("AttachOffset")
	weld.Parent = weld.Part1
	copy.Parent = folder
end

-- red-and-green haze rising off an overcharged character, seen by everyone
local function setAura(character, setName, on)
	local root = character:FindFirstChild("HumanoidRootPart")
	local aura = root and root:FindFirstChild(AURA_NAME)
	if not on then
		if aura then
			aura:Destroy()
		end
		return
	end
	if not root or aura then
		return
	end
	local settings = SkillSetConfig.Sets[setName].overcharge
	aura = Instance.new("Attachment")
	aura.Name = AURA_NAME
	aura.Parent = root
	local haze = Instance.new("ParticleEmitter")
	haze.Texture = SMOKE_TEXTURE
	haze.Color = ColorSequence.new(settings.color, Color3.fromRGB(40, 0, 10))
	haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	haze.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 4.5) })
	haze.Lifetime = NumberRange.new(0.7, 1.1)
	haze.Speed = NumberRange.new(2, 4)
	haze.SpreadAngle = Vector2.new(25, 25)
	haze.Acceleration = Vector3.new(0, 6, 0)
	haze.LightEmission = 0.6
	haze.Rate = 22
	haze.Parent = aura
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARKLE_TEXTURE
	sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), settings.color)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.5, 0.9)
	sparks.Speed = NumberRange.new(3, 7)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Acceleration = Vector3.new(0, 8, 0)
	sparks.LightEmission = 1
	sparks.Rate = 30
	sparks.Parent = aura
	local light = Instance.new("PointLight")
	light.Color = settings.color
	light.Range = 14
	light.Brightness = 2
	light.Parent = aura
end

-- Shifts a worn piece marked TintWhenOvercharged (like the axe) to the
-- overcharge colour, or back to how it came, emitters and all.
local TINT_AMOUNT = 0.85
local function tint(piece, color, on)
	for _, instance in ipairs(piece:IsA("Model") and piece:GetDescendants() or { piece, table.unpack(piece:GetDescendants()) }) do
		if instance:IsA("BasePart") then
			local base = instance:GetAttribute("BaseColor") or instance.Color
			instance:SetAttribute("BaseColor", base)
			instance.Color = on and base:Lerp(color, TINT_AMOUNT) or base
		elseif instance:IsA("ParticleEmitter") or instance:IsA("PointLight") then
			local base = instance:GetAttribute("BaseColor") or instance.Color
			instance:SetAttribute("BaseColor", base)
			if instance:IsA("PointLight") then
				instance.Color = on and color or base
			else
				instance.Color = on and ColorSequence.new(Color3.new(1, 1, 1), color) or base
			end
		end
	end
end

-- Dresses the character for whichever set's tool it holds (or undresses it),
-- adding or removing the overcharge-only pieces as the overcharge comes and goes.
local function updateWearables(character)
	local player = Players:GetPlayerFromCharacter(character)
	local _, setName = SkillSetConfig.Equipped(character)
	local folder = character:FindFirstChild(WEARABLES_FOLDER)
	if folder and folder:GetAttribute("SkillSet") ~= setName then
		setAura(character, folder:GetAttribute("SkillSet"), false)
		folder:Destroy()
		folder = nil
	end
	local pieces = setName and assets:FindFirstChild(setName) and assets[setName]:FindFirstChild("Wearables")
	if not pieces or not player then
		return
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = WEARABLES_FOLDER
		folder:SetAttribute("SkillSet", setName)
		folder.Parent = character
		skillEffects:FireAllClients("Equip", character, SkillSetConfig.Sets[setName].color)
	end
	local overcharged = SkillSetConfig.IsOvercharged(player, setName)
	for _, piece in ipairs(pieces:GetChildren()) do
		local wanted = overcharged or not piece:GetAttribute("OverchargeOnly")
		local worn = folder:FindFirstChild(piece.Name)
		if wanted and not worn then
			wear(character, piece, folder)
		elseif worn and not wanted then
			worn:Destroy()
		end
	end
	local hadAura = character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart:FindFirstChild(AURA_NAME) ~= nil
	if overcharged and not hadAura then
		skillEffects:FireAllClients("Overcharge", character, SkillSetConfig.Sets[setName].overcharge.color)
	end
	for _, worn in ipairs(folder:GetChildren()) do
		local primary = worn:IsA("Model") and worn.PrimaryPart or worn
		if primary and primary:GetAttribute("TintWhenOvercharged") then
			tint(worn, SkillSetConfig.Sets[setName].overcharge.color, overcharged)
		end
	end
	setAura(character, setName, overcharged)
end

local function watchCharacter(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			updateWearables(character)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			updateWearables(character)
		end
	end)
end

useSkill.OnServerEvent:Connect(function(player, key, aim)
	if typeof(key) ~= "string" or typeof(aim) ~= "Vector3" or not isFiniteVector(aim) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local _, setName = SkillSetConfig.Equipped(character)
	local skill = setName and SkillSetConfig.Sets[setName].skills[key]
	if not skill or not skill.handler then
		return
	end
	if (player:GetAttribute(SkillSetConfig.MasteryAttribute(setName)) or 0) < skill.mastery then
		return
	end
	-- an ultimate only works while the set is overcharged
	if skill.overchargedOnly and not SkillSetConfig.IsOvercharged(player, setName) then
		return
	end
	-- the key again while it's still out (Recall, Detonate): no cooldown involved
	if skill.recast and player:GetAttribute(SkillSetConfig.RecastAttribute(setName, key)) then
		local module = handlerFor(skill.handler)
		if module.Recast then
			module.Recast(player, character)
		end
		return
	end
	local id = setName .. "." .. key
	if not SkillCooldowns.Ready(player, id, skill.cooldown, skill.charges, COOLDOWN_TOLERANCE) then
		return
	end
	-- some skills turn into another one while the set is overcharged
	local handlerName = skill.handler
	if skill.overchargedHandler and SkillSetConfig.IsOvercharged(player, setName) then
		handlerName = skill.overchargedHandler
	end
	-- a skill that couldn't go off (nowhere to put it) doesn't spend the cooldown
	if handlerFor(handlerName).Cast(player, character, aim) then
		SkillCooldowns.Spend(player, id, skill.cooldown)
	end
end)

-- the overcharge key: Overcharge checks the stacks are full and it's off cooldown
activateOvercharge.OnServerEvent:Connect(function(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local _, setName = SkillSetConfig.Equipped(character)
	if setName and SkillSetConfig.Sets[setName].overcharge then
		Overcharge.Activate(player, setName)
	end
end)

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
	-- overcharge starting or running out changes what's worn
	for setName in pairs(SkillSetConfig.Sets) do
		player:GetAttributeChangedSignal(SkillSetConfig.OverchargeEndAttribute(setName)):Connect(function()
			if player.Character then
				updateWearables(player.Character)
			end
		end)
	end
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
