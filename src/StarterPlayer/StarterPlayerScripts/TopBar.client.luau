-- The HUD's icons, up in Roblox's top bar and dressed like its own buttons
-- (dark see-through pills, white icons). Top right, one pill: Settings (P),
-- and Admin (`) for admins. Top left, just right of Roblox's chat button: the
-- Menu button (its own gui, above the hub, so it can close it too). Bottom
-- left, above the Hotbar's equipment cards: the player's yen as gold text.
-- Menu opens the hub (Hub) on Profile; B, J and M open it on Backpack, Quests
-- and Stats. The icon whose menu is open is a little larger, and a label with
-- its key shows under whichever is hovered (or held, on touch). Each
-- icon toggles its menu through Menus exactly as the key does; the menus
-- register themselves there. Icon images come from HudConfig.Icons; until the
-- owner picks them each shows its text glyph. A gold number on Menu counts
-- unspent stat points.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))

local player = Players.LocalPlayer

local ICON_GAP = 10
local YEN_TEXT_SIZE = 16
local TEXT = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 60)
local STROKE = Color3.new(0, 0, 0)
local STROKE_TRANSPARENCY = 0.4
-- Roblox's own top-bar buttons (read from its TopBarApp): their size, colour,
-- distance from the top of the screen, the gap between them and the screen's edge
local BUTTON_HEIGHT = 44
local BUTTON_COLOR = Color3.fromRGB(18, 18, 21)
local BUTTON_TRANSPARENCY = 0.08
local BUTTON_TOP = 12
local BUTTON_GAP = 8
local BUTTON_EDGE = 16

-- left to right within each group (`top` = beside Roblox's buttons at the top
-- left, else the top-right row); Admin appears only for admins
local ICONS = {
	{ name = "Admin", title = "Admin", key = "`" },
	{ name = "Settings", title = "Settings", key = "P" },
	{ name = "Hub", title = "Menu", top = true }, -- no key of its own: B, J and M open its tabs
}

local function make(className, props)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local gui = make("ScreenGui", {
	Name = "TopBar",
	ResetOnSpawn = false,
	IgnoreGuiInset = true, -- up in Roblox's top bar, above its player list
	DisplayOrder = 6,
	Parent = player:WaitForChild("PlayerGui"),
})

-- a dark see-through pill like Roblox's buttons (the one place the HUD rounds its corners)
local function pill(frame)
	frame.BackgroundColor3 = BUTTON_COLOR
	frame.BackgroundTransparency = BUTTON_TRANSPARENCY
	frame.BorderSizePixel = 0
	make("UICorner", { Parent = frame, CornerRadius = UDim.new(1, 0) })
	return frame
end

-- one pill as wide as its icons, right-aligned; the layout skips hidden icons, so no gap is left
local row = pill(make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Size = UDim2.fromOffset(0, BUTTON_HEIGHT),
	AutomaticSize = Enum.AutomaticSize.X,
}))
make("UIListLayout", {
	Parent = row,
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
})

-- bottom left, above the cards: the yen
local cluster = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, HudConfig.EdgeMargin, 1, -(HudConfig.BottomReserve + HudConfig.CardHeight + HudConfig.ClusterGap)),
	Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundTransparency = 1,
})
make("UIListLayout", {
	Parent = cluster,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, ICON_GAP),
})

-- the Menu button: in Roblox's bar right of its buttons, in a gui of its own drawn
-- over the hub (DisplayOrder 8), so it shows and closes the hub while it's open
local MENU_FALLBACK_X = 164 -- where Roblox's buttons end, if it hasn't said yet
local menuGui = make("ScreenGui", {
	Name = "MenuButton",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 9,
	Parent = player:WaitForChild("PlayerGui"),
})
local menuSlot = pill(make("Frame", {
	Parent = menuGui,
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.fromOffset(BUTTON_HEIGHT, BUTTON_HEIGHT),
}))
-- in line with Roblox's buttons: Menu just after them, the pill at the far right
local function placeButtons()
	local inset = GuiService.TopbarInset
	local left = inset.Min.X > 0 and inset.Min.X or MENU_FALLBACK_X
	local right = inset.Max.X > 0 and inset.Max.X or workspace.CurrentCamera.ViewportSize.X
	local middle = inset.Min.Y + BUTTON_TOP + BUTTON_HEIGHT / 2
	menuSlot.Position = UDim2.fromOffset(left + BUTTON_GAP, middle)
	row.Position = UDim2.fromOffset(right - BUTTON_EDGE, middle)
end
placeButtons()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeButtons)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeButtons)

local function formatYen(amount)
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "¥" .. grouped
end

local yenLabel = make("TextLabel", {
	Parent = cluster,
	LayoutOrder = 1,
	Size = UDim2.fromOffset(0, HudConfig.YenHeight),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = YEN_TEXT_SIZE,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextStrokeTransparency = STROKE_TRANSPARENCY,
	TextStrokeColor3 = STROKE,
})

local holders = {} -- name -> { holder, glyph, image, label }

for order, icon in ipairs(ICONS) do
	local config = HudConfig.Icons[icon.name]
	-- a fixed-size slot, so a growing icon doesn't push its neighbours
	local holder = make("TextButton", {
		Name = icon.name,
		Parent = icon.top and menuSlot or row,
		LayoutOrder = order,
		Size = UDim2.fromOffset(BUTTON_HEIGHT, BUTTON_HEIGHT),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = icon.name ~= "Admin",
	})
	local glyph, image
	if config.image ~= "" then
		image = make("ImageLabel", {
			Parent = holder,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(HudConfig.IconSize, HudConfig.IconSize),
			BackgroundTransparency = 1,
			Image = config.image,
		})
	else
		glyph = make("TextLabel", {
			Parent = holder,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = config.glyph,
			TextSize = HudConfig.IconSize - 6,
			TextColor3 = TEXT,
		})
	end

	-- the hover label hangs under its icon: ending at a top-right icon's right edge so it
	-- stays on screen, starting at the Menu icon's left edge
	local hover = make("TextLabel", {
		Parent = holder,
		Visible = false,
		AnchorPoint = icon.top and Vector2.new(0, 0) or Vector2.new(1, 0),
		Position = icon.top and UDim2.new(0, 0, 1, 2) or UDim2.new(1, 0, 1, 2),
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = icon.key and string.format("%s  [%s]", icon.title, icon.key) or icon.title,
		TextSize = 12,
		TextColor3 = TEXT,
		TextStrokeTransparency = STROKE_TRANSPARENCY,
		TextStrokeColor3 = STROKE,
	})
	holder.MouseEnter:Connect(function()
		hover.Visible = true
	end)
	holder.MouseLeave:Connect(function()
		hover.Visible = false
	end)
	holder.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			hover.Visible = true
		end
	end)
	holder.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			hover.Visible = false
		end
	end)
	holder.Activated:Connect(function()
		Menus.Toggle(icon.name)
	end)

	holders[icon.name] = { holder = holder, glyph = glyph, image = image }
end

-- the icon of the open menu is a little larger
local function showOpen(openName)
	for name, parts in pairs(holders) do
		local size = name == openName and HudConfig.IconSizeOpen or HudConfig.IconSize
		if parts.image then
			parts.image.Size = UDim2.fromOffset(size, size)
		else
			parts.glyph.TextSize = size - 6
		end
	end
end
Menus.OnChange(showOpen)
showOpen(nil)

-- unspent stat points, as a gold count on the Menu icon
local badge = make("TextLabel", {
	Parent = holders.Hub.holder,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(0, 14),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	TextSize = 10,
	TextColor3 = Color3.fromRGB(20, 20, 28),
	Visible = false,
})
make("UIPadding", { Parent = badge, PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })

local function refresh()
	yenLabel.Text = formatYen(player:GetAttribute("Yen") or 0)
	local points = player:GetAttribute("StatPoints") or 0
	badge.Visible = points > 0
	badge.Text = points > 99 and "99+" or tostring(points)
	holders.Admin.holder.Visible = player:GetAttribute("IsAdmin") == true
end
refresh()
player.AttributeChanged:Connect(refresh)
