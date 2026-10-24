-- Enemy drops, client side. Orbs that aren't yours stay hidden while only their
-- owner can take them (the server enforces that either way; this just keeps
-- you from seeing loot you can't take), and a sound plays when a material in your
-- bag goes up (PickupFeed shows "+2 Scrap" above the yen).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DropConfig = require(ReplicatedStorage:WaitForChild("DropConfig"))
local UiSfx = require(script.Parent:WaitForChild("UiSfx"))

local player = Players.LocalPlayer

-- hiding others' orbs

local function setVisible(orb, visible)
	orb.LocalTransparencyModifier = visible and 0 or 1
	for _, descendant in ipairs(orb:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") or descendant:IsA("Light") or descendant:IsA("BillboardGui") then
			descendant.Enabled = visible
		end
	end
end

local function apply(orb)
	if not orb:IsA("BasePart") then
		return
	end
	local ownerId, publicAt = orb:GetAttribute("OwnerUserId"), orb:GetAttribute("PublicAt")
	if ownerId == player.UserId or not publicAt then
		return
	end
	local wait = publicAt - workspace:GetServerTimeNow()
	if wait <= 0 then
		return
	end
	setVisible(orb, false)
	task.delay(wait, function()
		if orb.Parent then
			setVisible(orb, true)
		end
	end)
end

task.spawn(function()
	local folder = workspace:WaitForChild(DropConfig.FolderName)
	folder.ChildAdded:Connect(apply)
	for _, orb in ipairs(folder:GetChildren()) do
		apply(orb)
	end
end)

-- yen chests: the sound plays as your body touches one, without waiting for the
-- server to hand over the yen
task.spawn(function()
	local chests = workspace:WaitForChild("Chests")
	local function watch(chest)
		if not chest:IsA("BasePart") then
			return
		end
		local played = false
		chest.Touched:Connect(function(hit)
			local character = player.Character
			if not played and character and hit:IsDescendantOf(character) then
				played = true
				UiSfx.Play("getYen")
			end
		end)
	end
	chests.ChildAdded:Connect(watch)
	for _, chest in ipairs(chests:GetChildren()) do
		watch(chest)
	end
end)

-- the pickup sound as a material in your bag goes up (PickupFeed shows the line); the
-- first value we see for one is the load from the save: no sound
for key, material in pairs(DropConfig.Materials) do
	local attribute = DropConfig.Attribute(key)
	local last = player:GetAttribute(attribute)
	player:GetAttributeChangedSignal(attribute):Connect(function()
		local value = player:GetAttribute(attribute)
		if typeof(value) == "number" and typeof(last) == "number" and value > last then
			UiSfx.Play(material.tier == "Common" and "collectOrb" or "rareDrop")
		end
		last = value
	end)
end
