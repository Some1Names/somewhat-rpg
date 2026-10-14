-- The Headhunter's head tag: a red square HEADHUNTER sign over the head of
-- whoever holds the mark (ReplicatedStorage's Headhunter attribute, set by
-- ServerScriptService.Headhunter), seen from any distance and through walls.
-- It sits just above their OverheadHealth bar, follows them when they
-- respawn and goes when the mark ends. Nothing else shows on screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TAG_WIDTH = 116 -- pixels
local TAG_HEIGHT = 24 -- pixels
local LIFT = 92 -- pixels of billboard below the tag, so it clears the OverheadHealth bar
local HEIGHT_ABOVE_HEAD = 2 -- studs, where OverheadHealth centres its bar
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local RED = Color3.fromRGB(226, 75, 74)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local tag -- the BillboardGui, while someone holds the mark
local holderConnection
local current -- a token for the latest update, so a slow head lookup can't tag the wrong holder

local function clear()
	if tag then
		tag:Destroy()
		tag = nil
	end
	if holderConnection then
		holderConnection:Disconnect()
		holderConnection = nil
	end
end

local function tagCharacter(character, token)
	local head = character:WaitForChild("Head", 10)
	if not head or token ~= current then
		return
	end
	if tag then
		tag:Destroy()
	end
	tag = Instance.new("BillboardGui")
	tag.Name = "HeadhunterTag"
	tag.Adornee = head
	tag.AlwaysOnTop = true
	tag.MaxDistance = math.huge
	tag.LightInfluence = 0
	tag.ResetOnSpawn = false
	tag.Size = UDim2.fromOffset(TAG_WIDTH, (TAG_HEIGHT + LIFT) * 2)
	tag.StudsOffset = Vector3.new(0, HEIGHT_ABOVE_HEAD, 0)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0)
	frame.Size = UDim2.fromOffset(TAG_WIDTH, TAG_HEIGHT)
	frame.BackgroundColor3 = BACKGROUND
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = tag
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = RED
	stroke.Thickness = 2
	stroke.Parent = frame
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 14
	text.TextColor3 = RED
	text.Text = "HEADHUNTER"
	text.Parent = frame
	tag.Parent = playerGui
end

local function update()
	clear()
	local token = {}
	current = token
	local id = ReplicatedStorage:GetAttribute("Headhunter")
	local holder = id and Players:GetPlayerByUserId(id)
	if not holder then
		return
	end
	holderConnection = holder.CharacterAdded:Connect(function(character)
		tagCharacter(character, token)
	end)
	if holder.Character then
		task.spawn(tagCharacter, holder.Character, token)
	end
end

ReplicatedStorage:GetAttributeChangedSignal("Headhunter"):Connect(update)
-- joining a server whose Headhunter's player hasn't reached this client yet
Players.PlayerAdded:Connect(function(added)
	if added.UserId == ReplicatedStorage:GetAttribute("Headhunter") then
		update()
	end
end)
update()
