-- The crosshair's styles (Preferences' Crosshair: X, DOT, CROSS, NONE), drawn in code: white
-- bars over slightly bigger dark ones, so they read on any background and a crossing stays
-- clean, square ends. ShiftLock draws the one in use; Settings shows them in its preview.
-- Crosshair.Build(parent, style) fills `parent` (centred in it) and returns nothing.
local Crosshair = {}

local WIDTH = 2 -- px, a bar's thickness
local EDGE = 1 -- px of dark round each bar
local EDGE_TRANSPARENCY = 0.4

-- one bar through the middle of `parent`, `length` long, `offset` px from the middle,
-- turned `rotation` degrees; the dark one behind it (ZIndex 1) and the white (2)
local function bar(parent, width, length, offset, rotation)
	for _, layer in ipairs({ { EDGE * 2, Color3.new(0, 0, 0), EDGE_TRANSPARENCY, 1 }, { 0, Color3.new(1, 1, 1), 0, 2 } }) do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
		frame.Size = UDim2.fromOffset(width + layer[1], length + layer[1])
		frame.Rotation = rotation
		frame.BackgroundColor3 = layer[2]
		frame.BackgroundTransparency = layer[3]
		frame.BorderSizePixel = 0
		frame.ZIndex = layer[4]
		frame.Parent = parent
	end
end

local STYLES = {
	X = function(parent)
		bar(parent, WIDTH, 10, Vector2.zero, 45)
		bar(parent, WIDTH, 10, Vector2.zero, -45)
	end,
	DOT = function(parent)
		bar(parent, 4, 4, Vector2.zero, 0)
	end,
	CROSS = function(parent)
		local length, gap = 6, 4
		local reach = gap + length / 2
		bar(parent, WIDTH, length, Vector2.new(0, -reach), 0)
		bar(parent, WIDTH, length, Vector2.new(0, reach), 0)
		bar(parent, WIDTH, length, Vector2.new(-reach, 0), 90)
		bar(parent, WIDTH, length, Vector2.new(reach, 0), 90)
	end,
	NONE = function() end,
}

function Crosshair.Build(parent, style)
	parent:ClearAllChildren()
	local draw = STYLES[style] or STYLES.X
	draw(parent)
end

return Crosshair
