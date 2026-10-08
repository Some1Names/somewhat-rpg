-- A row of square status effect icons (StatusConfig), used over other
-- characters' names (OverheadHealth) and under your own stamina (StatusHUD).
-- Each icon is the effect's colour with its glyph, the stack count when
-- there's more than one, and a thin bar along the bottom emptying as the
-- effect runs out. Call Update(model) every frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))

local StatusIcons = {}
StatusIcons.__index = StatusIcons

StatusIcons.Size = 16 -- pixels
StatusIcons.Gap = 3

local function outline(parent)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.4
	stroke.LineJoinMode = Enum.LineJoinMode.Miter -- square corners
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

-- `alignment`: Enum.HorizontalAlignment for the row (Center over a name)
function StatusIcons.new(parent, alignment, position)
	local row = Instance.new("Frame")
	row.Name = "StatusIcons"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, StatusIcons.Size + 2)
	row.Position = position or UDim2.new()
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = alignment or Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, StatusIcons.Gap)
	layout.Parent = row
	-- keeps the outlines of the first and last icon inside the row
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 1)
	padding.PaddingRight = UDim.new(0, 1)
	padding.Parent = row

	local icons = {}
	for order, name in ipairs(StatusConfig.Order) do
		local effect = StatusConfig.Effects[name]
		local icon = Instance.new("Frame")
		icon.Name = name
		icon.LayoutOrder = order
		icon.BorderSizePixel = 0
		icon.BackgroundColor3 = effect.color
		icon.BackgroundTransparency = 0.15
		icon.Size = UDim2.fromOffset(StatusIcons.Size, StatusIcons.Size)
		icon.Visible = false
		icon.Parent = row
		outline(icon)

		local glyph = Instance.new("TextLabel")
		glyph.BackgroundTransparency = 1
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.Font = Enum.Font.GothamBold
		glyph.Text = effect.glyph
		glyph.TextSize = 11
		glyph.TextColor3 = Color3.new(1, 1, 1)
		glyph.Parent = icon

		local stacks = Instance.new("TextLabel")
		stacks.BackgroundTransparency = 1
		stacks.AnchorPoint = Vector2.new(1, 1)
		stacks.Position = UDim2.new(1, 2, 1, 1)
		stacks.Size = UDim2.fromOffset(8, 9)
		stacks.Font = Enum.Font.GothamBlack
		stacks.TextSize = 9
		stacks.TextColor3 = Color3.new(1, 1, 1)
		stacks.TextStrokeTransparency = 0
		stacks.TextXAlignment = Enum.TextXAlignment.Right
		stacks.ZIndex = 3
		stacks.Parent = icon

		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromScale(0, 1)
		bar.Size = UDim2.new(1, 0, 0, 2)
		bar.ZIndex = 2
		bar.Parent = icon

		icons[name] = { frame = icon, stacks = stacks, bar = bar, duration = effect.duration }
	end
	return setmetatable({ row = row, icons = icons }, StatusIcons)
end

-- shows what `model` has right now; returns how many icons are up
function StatusIcons:Update(model)
	local shown = 0
	for name, icon in pairs(self.icons) do
		local left = model and StatusConfig.TimeLeft(model, name) or 0
		local visible = left > 0
		icon.frame.Visible = visible
		if visible then
			shown += 1
			local stacks = StatusConfig.Stacks(model, name)
			icon.stacks.Text = stacks > 1 and tostring(stacks) or ""
			icon.bar.Size = UDim2.new(math.clamp(left / icon.duration, 0, 1), 0, 0, 2)
		end
	end
	return shown
end

return StatusIcons
