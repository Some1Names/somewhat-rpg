-- A soft dark vignette round the screen's edges, always on while playing. Four black edge
-- strips with gradients easing off inward, so the corners, where two overlap, come out
-- darkest. A placeholder until there's a vignette image (an upload is the owner's call).
-- Under everything else (LowHealth's red sits on top); the hub and title menu hide it
-- with the rest of the HUD. The Vignette setting (Preferences) scales how dark it is; at
-- 0 it's off.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))

local player = Players.LocalPlayer

local OPACITY = 0.45 -- at the very edge, at the setting's 100% (it starts at 50%)
local DEPTH = 0.22 -- how far in from each edge it reaches, a share of the screen
-- how dark it is going inward, as a share of OPACITY: falling off fast, then fading out
local FALLOFF = { { 0, 1 }, { 0.3, 0.45 }, { 0.65, 0.12 }, { 1, 0 } }

local gui = Instance.new("ScreenGui")
gui.Name = "Vignette"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true -- the whole screen, under Roblox's top bar too
gui.DisplayOrder = -2 -- under LowHealth and the rest of the HUD
gui.Parent = player:WaitForChild("PlayerGui")

-- { size, position, gradient rotation } with the dark at the gradient's start
local EDGES = {
	{ UDim2.fromScale(1, DEPTH), UDim2.fromScale(0, 0), 90 }, -- top
	{ UDim2.fromScale(1, DEPTH), UDim2.fromScale(0, 1 - DEPTH), 270 }, -- bottom
	{ UDim2.fromScale(DEPTH, 1), UDim2.fromScale(0, 0), 0 }, -- left
	{ UDim2.fromScale(DEPTH, 1), UDim2.fromScale(1 - DEPTH, 0), 180 }, -- right
}
local gradients = {}
for _, edge in ipairs(EDGES) do
	local strip = Instance.new("Frame")
	strip.Size = edge[1]
	strip.Position = edge[2]
	strip.BackgroundColor3 = Color3.new(0, 0, 0)
	strip.BorderSizePixel = 0
	strip.Active = false
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = edge[3]
	gradient.Parent = strip
	strip.Parent = gui
	table.insert(gradients, gradient)
end

-- the fade at the setting's strength
local function paint()
	local opacity = OPACITY * Preferences.Get("Vignette") / 100
	gui.Enabled = opacity > 0
	local keypoints = {}
	for _, point in ipairs(FALLOFF) do
		table.insert(keypoints, NumberSequenceKeypoint.new(point[1], 1 - point[2] * opacity))
	end
	local fade = NumberSequence.new(keypoints)
	for _, gradient in ipairs(gradients) do
		gradient.Transparency = fade
	end
end
Preferences.Changed(paint)
paint()
