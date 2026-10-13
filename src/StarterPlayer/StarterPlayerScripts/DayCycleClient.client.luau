-- The daylight cycle's look. The server keeps the time as an anchor in
-- attributes on ReplicatedStorage (ServerScriptService.DayClock); every frame
-- this works out the hour from it and sets Lighting.ClockTime and the blended
-- look (DayCycleConfig.Sample) on the Lighting instances that exist: the
-- Lighting service and its Atmosphere, Sky, Bloom, SunRays and the
-- ColorCorrection named "ColorCorrection" (the grades skills add have other
-- names, so they sit on top). Nothing is created; a missing instance is skipped.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayCycleConfig = require(ReplicatedStorage:WaitForChild("DayCycleConfig"))

-- {r, g, b} in 0 to 255 is a colour
local function toValue(value)
	if type(value) == "table" then
		return Color3.fromRGB(value[1], value[2], value[3])
	end
	return value
end

local function update()
	local anchorHour = ReplicatedStorage:GetAttribute("DayAnchorTime")
	local anchorServerTime = ReplicatedStorage:GetAttribute("DayAnchorServerTime")
	if not anchorHour or not anchorServerTime then
		return -- the server's clock hasn't replicated yet
	end
	local hour = DayCycleConfig.HourAt(anchorHour, anchorServerTime, workspace:GetServerTimeNow(), ReplicatedStorage:GetAttribute("DayFrozen") == true)
	Lighting.ClockTime = hour
	for group, properties in pairs(DayCycleConfig.Sample(hour)) do
		local target = if group == "Lighting" then Lighting else Lighting:FindFirstChild(group)
		if target and target:IsA(group) then
			for property, value in pairs(properties) do
				target[property] = toValue(value)
			end
		end
	end
end

-- last, so this beats the server's once-a-second ClockTime in the same frame
RunService:BindToRenderStep("DayCycle", Enum.RenderPriority.Last.Value, update)
