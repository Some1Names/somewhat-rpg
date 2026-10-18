-- A small square mouse drawn from frames (no image): an outline, the two buttons on top
-- split by a line, and the pressed button filled. Used for LMB / RMB in the key hints
-- and the power details.
local MouseIcon = {}

local WIDTH, HEIGHT = 12, 18
local BUTTONS_HEIGHT = 8 -- the top part holding the two buttons

-- "Left" or "Right" for the key text "LMB" / "RMB", else nil
function MouseIcon.Side(key)
	if key == "LMB" then
		return "Left"
	elseif key == "RMB" then
		return "Right"
	end
	return nil
end

-- draws the icon centred in `parent`, its pressed button on `side` ("Left" or "Right")
function MouseIcon.Make(parent, side, color)
	local function box(props)
		local frame = Instance.new("Frame")
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = color
		for key, value in pairs(props) do
			frame[key] = value
		end
		return frame
	end
	local icon = box({
		Name = "MouseIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Parent = icon
	local half = WIDTH // 2
	box({ -- the pressed button
		Position = UDim2.fromOffset(side == "Right" and half or 0, 0),
		Size = UDim2.fromOffset(half, BUTTONS_HEIGHT),
		Parent = icon,
	})
	box({ -- under the buttons
		Position = UDim2.fromOffset(0, BUTTONS_HEIGHT),
		Size = UDim2.fromOffset(WIDTH, 1),
		Parent = icon,
	})
	box({ -- between the buttons
		Position = UDim2.fromOffset(half - 1, 0),
		Size = UDim2.fromOffset(1, BUTTONS_HEIGHT),
		Parent = icon,
	})
	icon.Parent = parent
	return icon
end

return MouseIcon
