-- Paints a character's look (SlotConfig) onto an R6 rig: skin on the head and arms, the
-- outfit colours on the torso and legs, a hair accessory and a face from
-- ReplicatedStorage.CharacterParts (Hair_<n> accessories, Face_<n> decals, made in
-- Studio). Used by the server for the real character (Slots) and by the customizer for
-- its preview. A hair Handle takes the hair colour (a SpecialMesh through its VertexColor)
-- unless it is a textured MeshPart, which keeps its own colours.
local CharacterLook = {}

local SlotConfig = require(script.Parent:WaitForChild("SlotConfig"))

local DEFAULT_FACE = "rbxasset://textures/face.png" -- Roblox's smile

local function colorOf(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- whether a style can be picked: style 1 is "none"/"default" and needs no part
function CharacterLook.HasHair(parts, index)
	return index == 1 or (parts ~= nil and parts:FindFirstChild("Hair_" .. index) ~= nil)
end

function CharacterLook.HasFace(parts, index)
	return index == 1 or (parts ~= nil and parts:FindFirstChild("Face_" .. index) ~= nil)
end

function CharacterLook.Apply(character, look, parts)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	-- the player's own Roblox avatar goes: its hats and hair, clothes and body meshes
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accoutrement") or child:IsA("Clothing") or child:IsA("ShirtGraphic") or child:IsA("CharacterMesh") then
			child:Destroy()
		end
	end

	local skin = colorOf(SlotConfig.SkinTones[look.skin])
	local top = colorOf(SlotConfig.OutfitColors[look.top])
	local bottom = colorOf(SlotConfig.OutfitColors[look.bottom])
	local function paint(name, color)
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = color
		end
	end
	paint("Head", skin)
	paint("Left Arm", skin)
	paint("Right Arm", skin)
	paint("Torso", top)
	paint("Left Leg", bottom)
	paint("Right Leg", bottom)
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.HeadColor3 = skin
		bodyColors.LeftArmColor3 = skin
		bodyColors.RightArmColor3 = skin
		bodyColors.TorsoColor3 = top
		bodyColors.LeftLegColor3 = bottom
		bodyColors.RightLegColor3 = bottom
	end

	if look.hair > 1 and parts then
		local template = parts:FindFirstChild("Hair_" .. look.hair)
		if template and template:IsA("Accoutrement") then
			local hair = template:Clone()
			hair:SetAttribute("SlotLook", true) -- Slots removes avatar items that arrive late, but not this
			local handle = hair:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local tint = colorOf(SlotConfig.HairColors[look.hairColor])
				local mesh = handle:FindFirstChildOfClass("SpecialMesh")
				if mesh then
					mesh.VertexColor = Vector3.new(tint.R, tint.G, tint.B)
				end
				-- a textured MeshPart keeps its own colours
				if not (handle:IsA("MeshPart") and handle.TextureID ~= "") then
					handle.Color = tint
				end
			end
			humanoid:AddAccessory(hair)
		end
	end

	-- the head is Roblox's default round one, not the avatar's shape; face 1 is its default
	-- face, the others come from CharacterParts
	local head = character:FindFirstChild("Head")
	if head then
		local mesh = head:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			mesh.MeshType = Enum.MeshType.Head
			mesh.MeshId = ""
			mesh.TextureId = ""
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
			mesh.Offset = Vector3.zero
		end
		local texture = DEFAULT_FACE
		if look.face > 1 and parts then
			local template = parts:FindFirstChild("Face_" .. look.face)
			if template and template:IsA("Decal") then
				texture = template.Texture
			end
		end
		local face = head:FindFirstChild("face")
		if not face then
			face = Instance.new("Decal")
			face.Name = "face"
			face.Parent = head
		end
		face.Texture = texture
	end
end

return CharacterLook
