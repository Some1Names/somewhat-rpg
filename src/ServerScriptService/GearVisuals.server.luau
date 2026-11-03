-- Shows worn gear on the character: an Accessory cloned from ReplicatedStorage.GearModels/<base
-- model> for each worn piece (the owner's models; a base without one just shows nothing). A model
-- with a HidesHair attribute hides the painted hair (CharacterLook's Hair_<n>) while it is worn.
-- Redrawn when the worn text changes (equip, unequip, a slot loading) and when the character spawns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GearConfig = require(ReplicatedStorage:WaitForChild("GearConfig"))

local TAG = "GearVisual" -- attribute on the accessories this script adds
local HIDDEN = "GearHiddenTransparency" -- attribute on a hair handle: what it looked like before

local function setHairHidden(character, hidden)
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Accoutrement") and item:GetAttribute("SlotLook") and string.find(item.Name, "^Hair_") then
			local handle = item:FindFirstChild("Handle")
			if handle then
				if hidden and item:GetAttribute(HIDDEN) == nil then
					item:SetAttribute(HIDDEN, handle.Transparency)
					handle.Transparency = 1
				elseif not hidden and item:GetAttribute(HIDDEN) ~= nil then
					handle.Transparency = item:GetAttribute(HIDDEN)
					item:SetAttribute(HIDDEN, nil)
				end
			end
		end
	end
end

local function redraw(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	for _, item in ipairs(character:GetChildren()) do
		if item:GetAttribute(TAG) then
			item:Destroy()
		end
	end
	local models = ReplicatedStorage:FindFirstChild(GearConfig.ModelsFolder)
	local hidesHair = false
	local worn = GearConfig.ParseWorn(player:GetAttribute(GearConfig.WornAttribute))
	for _, slot in ipairs(GearConfig.Slots) do
		local piece = worn[slot]
		local base = piece and GearConfig.Base(piece.base)
		local template = base and models and models:FindFirstChild(base.model)
		if template and template:IsA("Accoutrement") then
			local item = template:Clone()
			item:SetAttribute(TAG, true)
			humanoid:AddAccessory(item)
			hidesHair = hidesHair or item:GetAttribute("HidesHair") == true
		end
	end
	setHairHidden(character, hidesHair)
	character:SetAttribute("GearHidesHair", hidesHair)
end

local function watchPlayer(player)
	player:GetAttributeChangedSignal(GearConfig.WornAttribute):Connect(function()
		redraw(player)
	end)
	local function onCharacter(character)
		task.defer(redraw, player)
		-- the painted look arrives after the character does; hide its hair if a worn model asks
		character.ChildAdded:Connect(function(child)
			if child:GetAttribute("SlotLook") and character:GetAttribute("GearHidesHair") then
				task.defer(setHairHidden, character, true)
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)
