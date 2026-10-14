-- The HUD's plain icons. Top right, right to left: Settings (P), and Admin (`)
-- for admins. Bottom left, above the Hotbar's equipment cards: the player's
-- yen as gold text, and under it Quests (J), Stats (M) and Inventory (B). No
-- boxes: white icons with a dark stroke, the one whose menu is open a little
-- larger, a label with its key beside whichever is hovered (or held, on touch). Each icon toggles its
-- menu through Menus exactly as the key does; the menus register themselves
-- there. Icon images come from HudConfig.Icons; until the owner picks them
-- each shows its text glyph. A gold number on Stats counts unspent points.
local Players = game:GetService("Players")
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

-- left to right within each group (`left` = the bottom-left cluster, else the top-right row);
-- Quests and Admin appear only when they apply
local ICONS = {
	{ name = "Admin", title = "Admin", key = "`" },
	{ name = "Settings", title = "Settings", key = "P" },
	{ name = "Quests", title = "Quests", key = "J", left = true },
	{ name = "Stats", title = "Stats", key = "M", left = true },
	{ name = "Inventory", title = "Inventory", key = "B", left = true },
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

-- as wide as its contents, right-aligned; the layout skips hidden icons, so no gap is left
local row = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -HudConfig.EdgeMargin, 0, HudConfig.TopMargin),
	Size = UDim2.fromOffset(0, HudConfig.IconSizeOpen),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
})
make("UIListLayout", {
	Parent = row,
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, ICON_GAP),
})

-- bottom left, above the cards: the yen, and the three menu icons under it
local cluster = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, HudConfig.EdgeMargin, 1, -(HudConfig.BottomReserve + HudConfig.CardHeight + HudConfig.ClusterGap)),
	Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = cluster, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, HudConfig.SideGap) })
local leftRow = make("Frame", {
	Parent = cluster,
	LayoutOrder = 2,
	Size = UDim2.fromOffset(0, HudConfig.IconSizeOpen),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
})
make("UIListLayout", {
	Parent = leftRow,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, ICON_GAP),
})

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
		Parent = icon.left and leftRow or row,
		LayoutOrder = order,
		Size = UDim2.fromOffset(HudConfig.IconSizeOpen, HudConfig.IconSizeOpen),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = icon.name ~= "Admin" and icon.name ~= "Quests",
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
			TextStrokeTransparency = STROKE_TRANSPARENCY,
			TextStrokeColor3 = STROKE,
		})
	end

	-- the hover label hangs under a top-right icon, ending at its right edge so it stays on screen;
	-- over a bottom-left icon it sits above it
	local hover = make("TextLabel", {
		Parent = holder,
		Visible = false,
		AnchorPoint = icon.left and Vector2.new(0, 1) or Vector2.new(1, 0),
		Position = icon.left and UDim2.new(0, 0, 0, -2) or UDim2.new(1, 0, 1, 2),
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = string.format("%s  [%s]", icon.title, icon.key),
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

-- unspent stat points, as a gold count on the Stats icon
local badge = make("TextLabel", {
	Parent = holders.Stats.holder,
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
	-- the Quests menu is built by Quests, which waits for the server's Quest remote
	holders.Quests.holder.Visible = ReplicatedStorage:FindFirstChild("Quest") ~= nil
end
refresh()
player.AttributeChanged:Connect(refresh)
ReplicatedStorage.ChildAdded:Connect(function(child)
	if child.Name == "Quest" then
		refresh()
	end
end)
