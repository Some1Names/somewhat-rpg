-- The camera and screen settings (Preferences): Field of view and the Colour filter. The
-- field of view is set when the setting changes or a new camera comes in, and only then,
-- so a gun's zoom (Ranged) and the shop's close-up (ShopFocus), which go back to whatever
-- it was, aren't fought. The filter is a ColorCorrection in Lighting on this client alone
-- (HudConfig.ColourFilters; OFF turns it off).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))

local filter = Instance.new("ColorCorrectionEffect")
filter.Name = "SettingsColourFilter"
filter.Enabled = false
filter.Parent = Lighting

local appliedFov
local function apply(force)
	local fov = Preferences.Get("Fov")
	local camera = workspace.CurrentCamera
	if camera and (force or fov ~= appliedFov) then
		appliedFov = fov
		camera.FieldOfView = fov
	end
	local look = HudConfig.ColourFilters[Preferences.Choice("Filter")]
	filter.Enabled = look ~= nil
	if look then
		filter.TintColor = look.tint
		filter.Saturation = look.saturation
		filter.Contrast = look.contrast
	end
end

Preferences.Changed(function()
	apply(false)
end)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	apply(true)
end)
apply(true)
