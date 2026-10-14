-- The daylight cycle's look. The server keeps the time as an anchor in
-- attributes on ReplicatedStorage (ServerScriptService.DayClock); every frame
-- this works out the hour from it and sets Lighting.ClockTime and the blended
-- look (DayCycleConfig.Sample) on the Lighting instances that exist: the
-- Lighting service and its Atmosphere, Sky, Bloom, SunRays and the
-- ColorCorrection named "ColorCorrection" (the grades skills add have other
-- names, so they sit on top). Nothing in Lighting is created; a missing
-- instance is skipped.
-- The sky's textures change with the phase (DayCycleConfig.PhaseAt): the
-- Sky objects named Dawn, Day, Dusk and Night in ReplicatedStorage.Skies hold
-- each look. A Sky can't crossfade, so when the phase changes the screen fades
-- through black (DayCycleConfig.SkyFade), the textures swap while it's dark, and
-- it fades back. The first sky on joining is set at once. A phase with no Sky
-- there keeps the current one, with no fade.
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayCycleConfig = require(ReplicatedStorage:WaitForChild("DayCycleConfig"))

-- the instance class of each group's Lighting child, where it isn't the same name
local CLASS_OF = {
	ColorCorrection = "ColorCorrectionEffect",
	Bloom = "BloomEffect",
	SunRays = "SunRaysEffect",
}

-- what a phase's Sky hands over to the one in Lighting
local SKY_PROPERTIES = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId" }

local appliedPhase -- the phase whose sky is showing
local fadeStart -- os.clock() when the fade began; nil when not fading
local swapped = false -- whether this fade has swapped the textures yet
local fadeFrame -- the black frame, made when first needed

-- {r, g, b} in 0 to 255 is a colour
local function toValue(value)
	if type(value) == "table" then
		return Color3.fromRGB(value[1], value[2], value[3])
	end
	return value
end

local function phaseSky(phase)
	local skies = ReplicatedStorage:FindFirstChild("Skies")
	local sky = skies and skies:FindFirstChild(phase)
	return sky and sky:IsA("Sky") and sky or nil
end

local function applySky(phase)
	appliedPhase = phase
	local source, sky = phaseSky(phase), Lighting:FindFirstChildOfClass("Sky")
	if source and sky then
		for _, property in ipairs(SKY_PROPERTIES) do
			sky[property] = source[property]
		end
	end
end

-- a black frame under the other UI
local function getFadeFrame()
	if fadeFrame then
		return fadeFrame
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "DaySkyFade"
	gui.DisplayOrder = -100
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	fadeFrame = Instance.new("Frame")
	fadeFrame.Size = UDim2.fromScale(1, 1)
	fadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	fadeFrame.BackgroundTransparency = 1
	fadeFrame.BorderSizePixel = 0
	fadeFrame.Parent = gui
	gui.Parent = playerGui
	return fadeFrame
end

local function updateSky(phase)
	if fadeStart then
		local elapsed = os.clock() - fadeStart
		local alpha, done = DayCycleConfig.FadeAt(elapsed)
		local frame = getFadeFrame()
		if frame then
			frame.BackgroundTransparency = 1 - alpha
		end
		if not swapped and elapsed >= DayCycleConfig.SkyFade.out then
			swapped = true
			applySky(phase) -- whatever phase it is by now
		end
		if done then
			fadeStart = nil
		end
	elseif appliedPhase == nil or not phaseSky(phase) then
		applySky(phase) -- the first sky, or a phase with no Sky of its own: no fade
	elseif phase ~= appliedPhase then
		fadeStart, swapped = os.clock(), false
	end
end

local function update()
	local anchorHour = ReplicatedStorage:GetAttribute("DayAnchorTime")
	local anchorServerTime = ReplicatedStorage:GetAttribute("DayAnchorServerTime")
	if not anchorHour or not anchorServerTime then
		return -- the server's clock hasn't replicated yet
	end
	local hour = DayCycleConfig.HourAt(anchorHour, anchorServerTime, workspace:GetServerTimeNow(), ReplicatedStorage:GetAttribute("DayFrozen") == true)
	Lighting.ClockTime = hour
	updateSky(DayCycleConfig.PhaseAt(hour))
	for group, properties in pairs(DayCycleConfig.Sample(hour)) do
		local target = if group == "Lighting" then Lighting else Lighting:FindFirstChild(group)
		if target and target:IsA(CLASS_OF[group] or group) then
			for property, value in pairs(properties) do
				target[property] = toValue(value)
			end
		end
	end
end

-- load every phase's textures now so the swap doesn't stall
task.spawn(function()
	local skies = ReplicatedStorage:WaitForChild("Skies", 10)
	if skies then
		ContentProvider:PreloadAsync(skies:GetChildren())
	end
end)

-- last, so this beats the server's once-a-second ClockTime in the same frame
RunService:BindToRenderStep("DayCycle", Enum.RenderPriority.Last.Value, update)
