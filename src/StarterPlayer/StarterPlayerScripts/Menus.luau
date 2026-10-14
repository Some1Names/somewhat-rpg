-- The one-menu rule: Inventory, Stats, Settings, Shop, Gallery, Quests and
-- Admin register here when they open (Menus.Open(name, closeFn)), which
-- closes whichever menu was open first. A menu calls Menus.Close(name)
-- whenever it closes itself (key, ×, Esc), so the next open starts clean.
-- The top bar's icons toggle a menu by name (Menus.Toggle) through the
-- function the menu gave Menus.Register, and watch Menus.OnChange to enlarge
-- the icon of the open one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))

local Menus = {}

local FIT_TOP = HudConfig.KillFeedTop -- under the icon row
local FIT_BOTTOM = 280 -- the skill bar's top edge (116 px up, 96 px tall, its header)
local FIT_MIN_SCALE = 0.5

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

-- Keeps a centred menu panel (automatic height) in the space between the icon
-- row and the skill bar, shrinking it on short screens so it never covers
-- the bar. Call once after making the panel. `rightEdge` is for a panel too
-- tall for that (Admin): it sits at the right edge, under the icon row and
-- the kill feed's top, and shrinks to the screen's height instead.
function Menus.Fit(panel, rightEdge)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	panel.AnchorPoint = rightEdge and Vector2.new(1, 0.5) or Vector2.new(0.5, 0.5)
	local gui = panel:FindFirstAncestorOfClass("ScreenGui")
	local function update()
		local natural = panel.AbsoluteSize.Y / scale.Scale
		if natural <= 0 then
			return
		end
		local available = gui.AbsoluteSize.Y - FIT_TOP - (rightEdge and HudConfig.EdgeMargin or FIT_BOTTOM)
		local fitted = math.clamp(available / natural, FIT_MIN_SCALE, 1)
		if math.abs(fitted - scale.Scale) > 0.001 then
			scale.Scale = fitted
		end
		if rightEdge then
			panel.Position = UDim2.new(1, -HudConfig.EdgeMargin, 0, FIT_TOP + available / 2)
		else
			panel.Position = UDim2.new(0.5, 0, 0, FIT_TOP + available / 2)
		end
	end
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
end

return Menus
