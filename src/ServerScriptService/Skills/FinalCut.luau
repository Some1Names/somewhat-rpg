-- Aido F, Final Cut: he becomes a dragon. It needs Chain Reaction on (the
-- skill bar and SkillSetServer check), starts with a roar blast around him, and
-- lasts form.duration seconds even if Chain Reaction runs out first. While it
-- lasts the character's FinalCut attribute is on (Passives cuts the damage he
-- takes, AidoUtil widens `form` blasts, RangedFor swaps Fuse for Atomic
-- Breath, and clients draw the dragon and limit the camera from it). It ends
-- when F is pressed again (Revert), the time is up, he dies or leaves, or the
-- set is put away: the attribute, the recast mark and the dragon copy all go.
-- The dragon is ServerStorage.SkillSets.Aido.AidoDragon (a Model with a
-- PrimaryPart); without it he keeps his body and clients draw an aura instead.
-- His hitbox stays his own body: the copy can't be hit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local AidoUtil = require(ServerScriptService:WaitForChild("AidoUtil"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local SET_NAME = "Aido"
local FORM = SkillSetConfig.Sets[SET_NAME].form
local RECAST = SkillSetConfig.RecastAttribute(SET_NAME, FORM.key)
local DRAGON_MODEL = "AidoDragon" -- ServerStorage.SkillSets.Aido.AidoDragon
local DRAGON_FOLDER = "FinalCutDragon" -- in the character, holding the welded copy
local DRAGON_FRONT = CFrame.Angles(0, math.pi, 0) -- the model faces +Z; a character faces -Z
local CHECK_INTERVAL = 0.1 -- seconds
local ROAR = {
	Radius = 20, -- studs
	Damage = 40, -- before the caster's Superliminal bonus
}

-- the dragon model, if the owner has made it
local function dragonTemplate()
	local sets = ServerStorage:FindFirstChild("SkillSets")
	local assets = sets and sets:FindFirstChild(SET_NAME)
	local template = assets and assets:FindFirstChild(DRAGON_MODEL)
	return template and template:IsA("Model") and template.PrimaryPart and template or nil
end

-- a welded, harmless copy of the dragon on the character; nothing without the model
local function attachDragon(character, humanoid, root)
	local template = dragonTemplate()
	if not template then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = DRAGON_FOLDER
	local dragon = template:Clone()
	for _, part in ipairs(dragon:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	-- turned to face the way he does, and stood on the ground he stands on
	dragon:PivotTo(root.CFrame * DRAGON_FRONT)
	local boxCFrame, boxSize = dragon:GetBoundingBox()
	local feetY = root.Position.Y - (humanoid.HipHeight + root.Size.Y / 2)
	dragon:PivotTo(dragon:GetPivot() + Vector3.new(0, feetY - (boxCFrame.Position.Y - boxSize.Y / 2), 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = dragon.PrimaryPart
	weld.Parent = dragon.PrimaryPart
	dragon.Parent = folder
	folder.Parent = character
end

-- puts everything back: the attribute, the recast mark, the dragon copy
local function finish(player, character)
	character:SetAttribute(FORM.attribute, nil)
	if player.Parent then
		player:SetAttribute(RECAST, nil)
	end
	local folder = character:FindFirstChild(DRAGON_FOLDER)
	if folder then
		folder:Destroy()
	end
end

-- keeps the form going until something ends it
local function watch(player, character, humanoid)
	local endsAt = os.clock() + FORM.duration
	while character:GetAttribute(FORM.attribute) do
		task.wait(CHECK_INTERVAL)
		local _, setName = SkillSetConfig.Equipped(character)
		if
			os.clock() >= endsAt
			or not player.Parent
			or player.Character ~= character
			or not character:IsDescendantOf(workspace)
			or humanoid.Health <= 0
			or setName ~= SET_NAME
		then
			break
		end
	end
	finish(player, character)
end

local FinalCut = {}

function FinalCut.Cast(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 or character:GetAttribute(FORM.attribute) then
		return false
	end
	character:SetAttribute(FORM.attribute, true)
	player:SetAttribute(RECAST, true)
	attachDragon(character, humanoid, root)
	task.spawn(watch, player, character, humanoid)
	AidoUtil.blast(player, character, root.Position, {
		radius = ROAR.Radius,
		damage = ROAR.Damage,
		aftershocks = true,
		guard = "unblockable",
		skill = "F",
		kind = "FinalCutRoar",
	})
	return true
end

-- F again: back to normal
function FinalCut.Recast(player, character)
	finish(player, character)
end

return FinalCut
