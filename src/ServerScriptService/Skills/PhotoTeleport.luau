-- Photoshop X, Photo Teleport: she pins a photo of the spot she aimed at (up
-- to Range away, on the ground beneath it) that stays for Lifetime seconds.
-- X again is Paste (Recast): if someone she's Framed (Framed) is within
-- PasteRange of the photo, they're pasted into it, moved there and frozen
-- for PasteHold; otherwise she pastes herself into it. Moving a player
-- follows CrowdControl, and Mandela's Misremembered forgets the paste
-- (Passives.ResistEdit); then she goes herself. A new photo replaces the
-- old one. Clients draw it from the SkillEffects "PhotoPin", "PhotoPaste"
-- and "PhotoGone" events. SkillSetServer checks the tool, mastery and
-- cooldown before calling Cast.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CrowdControl = require(ServerScriptService:WaitForChild("CrowdControl"))
local Framed = require(ServerScriptService:WaitForChild("Framed"))
local Passives = require(ServerScriptService:WaitForChild("Passives"))
local PhotoshopUtil = require(ServerScriptService:WaitForChild("PhotoshopUtil"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Range = 60, -- studs from her the photo can be pinned (SkillSetConfig's aim shows the same)
	Lifetime = 8, -- seconds the photo stays
	PasteRange = 60, -- studs from the photo a framed target can be pasted from
	PasteHold = 0.5, -- seconds a pasted target stays frozen in the photo
}
local RECAST = SkillSetConfig.RecastAttribute("Photoshop", "X")

local photos = setmetatable({}, { __mode = "k" }) -- player -> { id, point }

local function endPhoto(player, photo)
	if photos[player] ~= photo then
		return
	end
	photos[player] = nil
	player:SetAttribute(RECAST, nil)
	skillEffects:FireAllClients("PhotoGone", photo.id)
end

-- frozen where it landed for a moment, like the Knife's pin
local function hold(root, time)
	if root.Anchored then
		return
	end
	root.Anchored = true
	task.delay(time, function()
		if root.Parent then
			root.Anchored = false
		end
	end)
end

local function paste(model, root, point)
	local from = root.Position
	local facing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	facing = facing.Magnitude > 0.1 and facing.Unit or Vector3.new(0, 0, -1)
	root.AssemblyLinearVelocity = Vector3.zero
	model:PivotTo(CFrame.lookAt(point, point + facing))
	return from
end

local PhotoTeleport = {}

-- returns false with no ground under the aim, so no cooldown is spent
function PhotoTeleport.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return false
	end
	local point = PhotoshopUtil.groundAt(PhotoshopUtil.clampFlat(root.Position, aim, CONFIG.Range), { character })
	if not point then
		return false
	end
	if photos[player] then
		endPhoto(player, photos[player])
	end
	local photo = { id = HttpService:GenerateGUID(false), point = point }
	photos[player] = photo
	player:SetAttribute(RECAST, true)
	skillEffects:FireAllClients("PhotoPin", photo.id, character, point, CONFIG.Lifetime)
	task.delay(CONFIG.Lifetime, endPhoto, player, photo)
	-- the photo goes with her
	humanoid.Died:Once(function()
		endPhoto(player, photo)
	end)
	return true
end

-- Paste: the framed target nearest the photo into it, or her
function PhotoTeleport.Recast(player, character)
	local photo = photos[player]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not photo or not root or humanoid.Health <= 0 then
		return
	end
	local target = Framed.Nearest(player, photo.point, CONFIG.PasteRange)
	local targetHumanoid = target and target:FindFirstChildOfClass("Humanoid")
	local targetRoot = targetHumanoid and targetHumanoid.RootPart
	if targetRoot and not targetRoot.Anchored then
		local targetPlayer = PhotoshopUtil.playerOf(target)
		local movable = not targetPlayer or (CrowdControl.CanControl(target) and not Passives.ResistEdit(targetPlayer))
		if movable then
			local from = paste(target, targetRoot, photo.point)
			hold(targetRoot, CONFIG.PasteHold)
			CrowdControl.Apply(target, CONFIG.PasteHold)
			skillEffects:FireAllClients("PhotoPaste", photo.id, target, from, photo.point)
			endPhoto(player, photo)
			return
		end
	end
	local from = paste(character, root, photo.point)
	skillEffects:FireAllClients("PhotoPaste", photo.id, character, from, photo.point)
	endPhoto(player, photo)
end

return PhotoTeleport
