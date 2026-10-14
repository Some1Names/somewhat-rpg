-- The one-menu rule: Inventory, Stats, Settings, Shop, Gallery, Quests and
-- Admin register here when they open (Menus.Open(name, closeFn)), which
-- closes whichever menu was open first. A menu calls Menus.Close(name)
-- whenever it closes itself (key, ×, Esc), so the next open starts clean.
-- The top bar's icons toggle a menu by name (Menus.Toggle) through the
-- function the menu gave Menus.Register, and watch Menus.OnChange to enlarge
-- the icon of the open one.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))

local Menus = {}

local FIT_TOP = 12 -- px from the top of the screen below the top bar (the icon row is up in the bar)
local FIT_BOTTOM = 172 -- the skill bar's top edge (16 px up, 96 px tall, its header)
local FIT_MIN_HEIGHT = 160 -- a panel never gets shorter than this, however short the screen

local openName, openClose
local togglers = {} -- name -> function that toggles that menu like its key does
local listeners = {}

local function changed()
	for _, callback in ipairs(listeners) do
		task.spawn(callback, openName)
	end
end

-- opens `name`; the menu already open (if another) is closed by its own function
function Menus.Open(name, close)
	if openName and openName ~= name then
		local previous = openClose
		openName, openClose = nil, nil
		if previous then
			previous()
		end
	end
	openName, openClose = name, close
	changed()
end

-- `name` closed (itself or by Open): forget it, if it's the one registered
function Menus.Close(name)
	if openName == name then
		openName, openClose = nil, nil
		changed()
	end
end

function Menus.IsOpen(name)
	return openName == name
end

-- `toggle()` opens or closes the menu, exactly as its key does
function Menus.Register(name, toggle)
	togglers[name] = toggle
end

function Menus.Toggle(name)
	local toggle = togglers[name]
	if toggle then
		toggle()
	end
end

-- true once a menu has registered its toggle (TopBar shows only those icons)
function Menus.Has(name)
	return togglers[name] ~= nil
end

-- calls `callback(openName or nil)` whenever the open menu changes
function Menus.OnChange(callback)
	table.insert(listeners, callback)
end

-- the height of the screen below the top bar (a disabled ScreenGui reports 0, so ask the camera)
local function screenHeight(gui)
	if gui.AbsoluteSize.Y > 0 then
		return gui.AbsoluteSize.Y
	end
	return workspace.CurrentCamera.ViewportSize.Y - GuiService:GetGuiInset().Y
end

-- Keeps a menu panel (a ScrollingFrame holding a UIListLayout, optionally a
-- UIPadding, its width in Size.X.Offset) in the space between the icon row
-- and the skill bar: as tall as its content, or, when the screen is too short
-- for that, as tall as the space allows, and it scrolls. `rightEdge` puts it at
-- the right edge instead of centred, and lets it run down to the screen's
-- bottom edge (Admin, which is too tall to sit above the skill bar). Call once
-- after making the panel.
function Menus.Fit(panel, rightEdge)
	local layout = panel:FindFirstChildOfClass("UIListLayout")
	local padding = panel:FindFirstChildOfClass("UIPadding")
	local width = panel.Size.X.Offset
	local gui = panel:FindFirstAncestorOfClass("ScreenGui")
	panel.AnchorPoint = rightEdge and Vector2.new(1, 0.5) or Vector2.new(0.5, 0.5)
	local function update()
		local extra = padding and (padding.PaddingTop.Offset + padding.PaddingBottom.Offset) or 0
		local available = screenHeight(gui) - FIT_TOP - (rightEdge and HudConfig.EdgeMargin or FIT_BOTTOM)
		panel.Size = UDim2.fromOffset(width, math.min(layout.AbsoluteContentSize.Y + extra, math.max(available, FIT_MIN_HEIGHT)))
		local x = rightEdge and UDim2.new(1, -HudConfig.EdgeMargin, 0, 0) or UDim2.fromScale(0.5, 0)
		panel.Position = UDim2.new(x.X.Scale, x.X.Offset, 0, FIT_TOP + available / 2)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
end

return Menus
