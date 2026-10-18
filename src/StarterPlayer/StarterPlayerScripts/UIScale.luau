-- One scale for the whole UI, so it isn't tiny on a big monitor. Every ScreenGui's
-- frames live in a "UIScaleRoot" frame that is 1/scale of the screen with a UIScale
-- of `scale`, so scripts keep laying out in a smaller "virtual screen" (Scale
-- positions still fit, offsets come out bigger). Anything that mixes real pixels
-- (AbsoluteSize, the GuiInset, mouse positions) with UI pixels divides by UIScale.Get().
local Players = game:GetService("Players")

local UIScale = {}

local REFERENCE_HEIGHT = 1080 -- the screen height where the UI is its normal size
local MAX_SCALE = 2

-- guis (by name) that keep real pixels: the MenuButton lines up with Roblox's own bar,
-- the crosshair follows the mouse
UIScale.SkipGui = { MenuButton = true, RangedCrosshair = true }
-- frames (by name) that stay out of the scaling, in an otherwise scaled gui (TopBar's pill sits in Roblox's bar)
UIScale.SkipChild = { ButtonRow = true, UIScaleRoot = true }

local scale = 1
local roots = {} -- gui -> its root frame
local changed = Instance.new("BindableEvent")

local function compute()
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end
	local value = math.clamp(camera.ViewportSize.Y / REFERENCE_HEIGHT, 1, MAX_SCALE)
	return math.floor(value * 20 + 0.5) / 20 -- steps of 0.05, so tiny resizes don't reflow everything
end

function UIScale.Get()
	return scale
end

-- calls `callback()` after the scale changes
function UIScale.OnChange(callback)
	return changed.Event:Connect(callback)
end

local function apply(root)
	root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	root:FindFirstChildOfClass("UIScale").Scale = scale
end

-- the frame a gui's contents belong in (the gui itself when it is skipped)
function UIScale.Root(gui)
	if UIScale.SkipGui[gui.Name] then
		return gui
	end
	local root = roots[gui]
	if root and root.Parent == gui then
		return root
	end
	root = Instance.new("Frame")
	root.Name = "UIScaleRoot"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Active = false
	Instance.new("UIScale").Parent = root
	apply(root)
	root.Parent = gui
	roots[gui] = root
	return root
end

local function adopt(gui)
	local root = UIScale.Root(gui)
	if root == gui then
		return
	end
	local function move(child)
		if child:IsA("GuiObject") and not UIScale.SkipChild[child.Name] then
			child.Parent = root
		end
	end
	for _, child in ipairs(gui:GetChildren()) do
		move(child)
	end
	gui.ChildAdded:Connect(function(child)
		task.defer(function()
			if child.Parent == gui then
				move(child)
			end
		end)
	end)
end

scale = compute()
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
for _, child in ipairs(playerGui:GetChildren()) do
	if child:IsA("ScreenGui") then
		adopt(child)
	end
end
playerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") then
		adopt(child)
	end
end)

local function refresh()
	local value = compute()
	if value == scale then
		return
	end
	scale = value
	for gui, root in pairs(roots) do
		if root.Parent then
			apply(root)
		else
			roots[gui] = nil
		end
	end
	changed:Fire()
end
local function watch()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	refresh()
end
watch()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)

return UIScale
