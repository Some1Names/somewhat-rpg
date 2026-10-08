-- Shop menu: opens from a shopkeeper's prompt and lists the ShopConfig items
-- of that shopkeeper's shop (its ShopId attribute) with their yen prices.
-- Skill sets show their tier; placeholders for sets still to come show as
-- COMING SOON. Buying goes through the ShopServer script, which does all
-- the checking. Closes when you walk away.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local buyItem = ReplicatedStorage:WaitForChild("BuyItem")
local player = Players.LocalPlayer

local PANEL_WIDTH = 360
local PADDING = 14
local ITEM_HEIGHT = 70
local MAX_LIST_HEIGHT = 420 -- past this the list scrolls
local BADGE_SIZE = 30 -- a set's tier letter
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local GOLD = Color3.fromRGB(255, 205, 60)
local DANGER = Color3.fromRGB(226, 75, 74)

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

local function label(parent, props)
	props.Parent = parent
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local function formatYen(amount)
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "¥" .. grouped
end

-- an item's tier: its own, or its skill set's
local function tierOf(item)
	local set = item.set and SkillSetConfig.Sets[item.set]
	return item.tier or (set and set.tier)
end

local gui = make("ScreenGui", {
	Name = "ShopMenu",
	ResetOnSpawn = false,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local panel = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
})
local panelStroke = make("UIStroke", { Parent = panel, Color = GOLD, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
make("UIPadding", {
	Parent = panel,
	PaddingTop = UDim.new(0, PADDING),
	PaddingBottom = UDim.new(0, PADDING),
	PaddingLeft = UDim.new(0, PADDING),
	PaddingRight = UDim.new(0, PADDING),
})
make("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) })

local order = 0
local function section(height)
	order += 1
	return make("Frame", { Parent = panel, LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1 })
end

-- header: the shop's title, the player's yen, close
local header = section(22)
local title = label(header, { Text = "SHOP", Font = Enum.Font.GothamBold, TextSize = 16, Size = UDim2.fromScale(0.4, 1) })
local balance = label(header, {
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -30, 0, 0),
	Size = UDim2.new(0.6, -30, 1, 0),
})
-- Modal frees the mouse while the shop is open, even in shift lock
local closeButton = make("TextButton", {
	Parent = header,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "×",
	TextSize = 20,
	TextColor3 = MUTED,
	Modal = true,
})

-- the items, scrolling once there are more than fit
order += 1
local list = make("ScrollingFrame", {
	Parent = panel,
	LayoutOrder = order,
	Size = UDim2.new(1, 0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
})
local listLayout = make("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })
-- only as tall as the items need, up to the cap
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	list.Size = UDim2.new(1, 0, 0, math.min(listLayout.AbsoluteContentSize.Y, MAX_LIST_HEIGHT))
end)

local status = label(section(14), { Text = "", TextSize = 11, TextColor3 = MUTED, Size = UDim2.fromScale(1, 1) })

local rows = {}

local function setStatus(text, failed)
	status.Text = text
	status.TextColor3 = failed and DANGER or GOLD
end

local function owns(item)
	return item.starter or (ShopConfig.Ownable(item) and player:GetAttribute(ShopConfig.OwnedAttribute(item.id)) == 1)
end

local function refresh()
	local yen = player:GetAttribute("Yen") or 0
	balance.Text = formatYen(yen)
	for _, row in ipairs(rows) do
		local item = row.item
		local owned = owns(item)
		local affordable = yen >= (item.price or 0)
		if item.comingSoon then
			row.buy.Text = "COMING SOON"
		elseif owned then
			row.buy.Text = "OWNED"
		else
			row.buy.Text = item.price == 0 and "FREE" or formatYen(item.price)
		end
		local closed = owned or item.comingSoon
		row.buy.AutoButtonColor = not closed
		row.buy.BackgroundTransparency = closed and 0.85 or (affordable and 0 or 0.55)
		row.buy.TextColor3 = closed and MUTED or BACKGROUND
	end
end
player.AttributeChanged:Connect(function()
	if gui.Enabled then
		refresh()
	end
end)

local function buy(item)
	if item.comingSoon or owns(item) then
		return
	end
	local ok, success, message = pcall(buyItem.InvokeServer, buyItem, item.id)
	if not ok then
		setStatus("Couldn't reach the shop", true)
		return
	end
	setStatus(message, not success)
end

-- one row per item the shop sells
local function buildRows(shopId)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	rows = {}
	for _, item in ipairs(ShopConfig.Items) do
		if ShopConfig.ShopOf(item) == shopId then
			local row = make("Frame", {
				Parent = list,
				LayoutOrder = #rows + 1,
				Size = UDim2.new(1, 0, 0, ITEM_HEIGHT),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.6,
			})
			make("UIPadding", { Parent = row, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) })
			local textLeft = 0
			local tier = tierOf(item)
			if tier then
				local tierColor = SkillSetConfig.Tiers[tier] and SkillSetConfig.Tiers[tier].color or SkillSetConfig.NoTierColor
				local badge = label(row, {
					Text = tier,
					Font = Enum.Font.GothamBlack,
					TextSize = 18,
					TextColor3 = tierColor,
					TextXAlignment = Enum.TextXAlignment.Center,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE),
				})
				make("UIStroke", { Parent = badge, Color = tierColor, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
				textLeft = BADGE_SIZE + 10
			end
			local dim = item.comingSoon
			label(row, {
				Text = item.name,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextColor3 = dim and MUTED or TEXT,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(textLeft, 0),
				Size = UDim2.new(1, -(96 + textLeft), 0, 16),
			})
			label(row, {
				Text = item.description,
				TextSize = 11,
				TextColor3 = MUTED,
				TextTransparency = dim and 0.3 or 0,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(textLeft, 19),
				Size = UDim2.new(1, -(96 + textLeft), 1, -19),
			})
			local button = make("TextButton", {
				Parent = row,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(84, 32),
				BackgroundColor3 = GOLD,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				TextSize = item.comingSoon and 10 or 12,
				TextColor3 = BACKGROUND,
			})
			button.Activated:Connect(function()
				buy(item)
			end)
			table.insert(rows, { item = item, buy = button })
		end
	end
end

-- the shopkeeper whose menu is open, so walking away can close it
local openAt

local function close()
	gui.Enabled = false
	openAt = nil
end
closeButton.Activated:Connect(close)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local shop = prompt:FindFirstAncestorOfClass("Model")
	if shop and CollectionService:HasTag(shop, ShopConfig.Tag) then
		local shopId = ShopConfig.ShopIdOf(shop)
		local info = ShopConfig.Shops[shopId] or ShopConfig.Shops[ShopConfig.DefaultShop]
		openAt = shop
		title.Text = info.title
		panelStroke.Color = info.color
		buildRows(shopId)
		setStatus("")
		refresh()
		list.CanvasPosition = Vector2.zero
		gui.Enabled = true
	end
end)

RunService.Heartbeat:Connect(function()
	if not openAt then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not openAt.Parent or (openAt:GetPivot().Position - root.Position).Magnitude > ShopConfig.Range then
		close()
	end
end)
