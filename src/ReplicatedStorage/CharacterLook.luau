-- Paints a character's look (SlotConfig) onto an R15 rig: skin on the head, arms and hands, the
-- outfit colours on the torso and legs, hair, a face, an accessory, and a shirt, tee and pants,
-- the last four from ReplicatedStorage.CharacterParts (Hair_<n>, Acc_<n> accessories, Face_<n>
-- decals, Shirt_<n>, Tee_<n> and Pants_<n>, made in Studio). Used by the server for the real
-- character (Slots) and by the customizer for its previews. Hair is recoloured flat: its texture
-- is dropped and the part takes the colour, because a textured hair can't be made to any
-- colour (a dark one stays dark). Things the player wears are marked SlotLook, so Slots can
-- tell them from the avatar's own, which it removes.
local CharacterLook = {}

local DEFAULT_FACE = "rbxasset://textures/face.png" -- Roblox's smile

-- the parts each colour goes on (R15 names; the R6 rigs of NPCs are painted by the same lists)
local SKIN_PARTS = { "Head", "LeftHand", "RightHand", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }
local TOP_PARTS = { "UpperTorso", "Torso" }
local BOTTOM_PARTS = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }

local function colorOf(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- whether a style can be picked: style 1 is "none"/"default" and needs no part
function CharacterLook.Has(parts, prefix, index)
	return index == 1 or (parts ~= nil and parts:FindFirstChild(prefix .. "_" .. index) ~= nil)
end

function CharacterLook.HasHair(parts, index)
	return CharacterLook.Has(parts, "Hair", index)
end

function CharacterLook.HasFace(parts, index)
	return CharacterLook.Has(parts, "Face", index)
end

-- AddAccessory welds an accessory on, but only physics moves it into place: sit it on the head
-- now, for an anchored copy (the customizer's previews) that is never stepped. An accessory is
-- matched to the head by the attachment its Handle carries (HairAttachment, HatAttachment,
-- FaceFrontAttachment...); an old Hat without one hangs from its AttachmentPoint on the head's
-- top.
local function place(character, accessory)
	local handle = accessory:FindFirstChild("Handle")
	local head = character:FindFirstChild("Head")
	if not handle or not head or not handle:IsA("BasePart") then
		return
	end
	local own = handle:FindFirstChildOfClass("Attachment")
	local target = own and head:FindFirstChild(own.Name)
	if own and target then
		handle.CFrame = head.CFrame * target.CFrame * own.CFrame:Inverse()
	else
		local hat = head:FindFirstChild("HatAttachment")
		local base = hat and hat.CFrame or CFrame.new(0, 0.6, 0)
		handle.CFrame = head.CFrame * base * accessory.AttachmentPoint:Inverse()
	end
end

-- hair in one flat colour: no texture, the part's colour
local function flatten(accessory, color)
	local handle = accessory:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end
	local mesh = handle:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		mesh.TextureId = ""
		mesh.VertexColor = Vector3.new(1, 1, 1)
	end
	if handle:IsA("MeshPart") then
		handle.TextureID = ""
	end
	handle.Color = color
end

-- adds style `index` of an accessory-like part (hair or an accessory) to the character
local function wear(character, humanoid, parts, prefix, index, color)
	if index <= 1 or not parts then
		return
	end
	local template = parts:FindFirstChild(prefix .. "_" .. index)
	if not template or not template:IsA("Accoutrement") then
		return
	end
	local item = template:Clone()
	item:SetAttribute("SlotLook", true)
	if color then
		flatten(item, color)
	end
	humanoid:AddAccessory(item)
	place(character, item)
end

-- adds style `index` of a clothing part (Shirt_, Tee_ or Pants_) to the character
local function dress(character, parts, prefix, index)
	if index <= 1 or not parts then
		return
	end
	local template = parts:FindFirstChild(prefix .. "_" .. index)
	if template then
		local item = template:Clone()
		item:SetAttribute("SlotLook", true)
		item.Parent = character
	end
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

	local skin = colorOf(look.skin)
	local top = colorOf(look.top)
	local bottom = colorOf(look.bottom)
	local function paint(name, color)
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = color
		end
	end
	for _, name in ipairs(SKIN_PARTS) do
		paint(name, skin)
	end
	for _, name in ipairs(TOP_PARTS) do
		paint(name, top)
	end
	for _, name in ipairs(BOTTOM_PARTS) do
		paint(name, bottom)
	end
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.HeadColor3 = skin
		bodyColors.LeftArmColor3 = skin
		bodyColors.RightArmColor3 = skin
		bodyColors.TorsoColor3 = top
		bodyColors.LeftLegColor3 = bottom
		bodyColors.RightLegColor3 = bottom
	end

	wear(character, humanoid, parts, "Hair", look.hair or 1, colorOf(look.hairColor))
	wear(character, humanoid, parts, "Acc", look.accessory or 1, nil)
	dress(character, parts, "Shirt", look.shirt or 1)
	dress(character, parts, "Tee", look.tee or 1)
	dress(character, parts, "Pants", look.pants or 1)

	-- the head is Roblox's default round one, not the avatar's shape; face 1 is its default
	-- face, the others come from CharacterParts
	local head = character:FindFirstChild("Head")
	if head then
		-- (an R6 head is a Part with a SpecialMesh, an R15 one a MeshPart already round)
		local mesh = head:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			mesh.MeshType = Enum.MeshType.Head
			mesh.MeshId = ""
			mesh.TextureId = ""
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
			mesh.Offset = Vector3.zero
		end
		local texture = DEFAULT_FACE
		if (look.face or 1) > 1 and parts then
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
