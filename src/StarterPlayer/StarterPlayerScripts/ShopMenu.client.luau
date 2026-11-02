-- Shop menu: opens from a shopkeeper's prompt and lists the ShopConfig items
-- of that shopkeeper's shop (its ShopId attribute) with their yen prices.
-- Skill sets show their tier; placeholders for sets still to come show as
-- COMING SOON. Buying goes through the ShopServer script, which does all
-- the checking. The Power Dealer's rows (briefcase items) also have SELL,
-- for a briefcase you carry, and LIFETIME R$ where the power has a Robux
-- product (PowerSources prompts the purchase). Closes when you walk away, or when another menu opens (Menus).
-- It fills the screen in the title menu's look: black bars along the top and bottom (E LEAVE and
-- your yen in the bottom one), the camera closed in on the shopkeeper on the right, and down the
-- left, over a dark fading off the edge, the shop's line, its name big and the keeper's name on a
-- chip in the shop's colour (their ShopSubtitle, ShopTitle and ShopkeeperName attributes; their
-- overhead tag now shows only their own name, dressTag), then the items. The keeper's lines are
-- subtitles under them. The player's own character is hidden and their controls are off until it
-- closes (ShopFocus does all that, and makes E leave).
-- It won't open while you're fighting other players (not enemies), and closes if you start while it's open.
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CombatRules = require(ReplicatedStorage:WaitForChild("CombatRules"))
local ConsumableConfig = require(ReplicatedStorage:WaitForChild("ConsumableConfig"))
local FactionConfig = require(ReplicatedStorage:WaitForChild("FactionConfig"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local MenuFooter = require(script.Parent:WaitForChild("MenuFooter"))
local ShopFocus = require(script.Parent:WaitForChild("ShopFocus"))
local UiSfx = require(script.Parent:WaitForChild("UiSfx"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local buyItem = ReplicatedStorage:WaitForChild("BuyItem")
local sellItem = ReplicatedStorage:WaitForChild("SellItem")
local buyLifetime = ReplicatedStorage:WaitForChild("BuyLifetime")
local player = Players.LocalPlayer

-- the yen price the player pays: the listed price less their faction rank's discount
local function priceOf(item)
	if not item.price then
		return nil
	end
	return FactionConfig.DiscountedPrice(item.price, player:GetAttribute("FactionDiscount") or 0)
end

local PAD = 64 -- the screen's left edge to the column (as on the title menu)
local COLUMN_WIDTH = 460
local COLUMN_GAP = 26 -- between the top bar and the column, and the column and the bottom bar
local HEADER = 150 -- the column's top: the shop's line, its name big, the keeper on a chip
local BOTTOM_BAR = 44 -- the black bar along the bottom; the top one is as tall as Roblox's band
local ROBLOX_BAR_FALLBACK = 58 -- Roblox's band across the top, while GetGuiInset still says 0
local SHADE_SHARE = 0.62 -- how far across the screen the dark fades off the left edge
local SPEECH_AT = 0.72 -- the middle of the keeper's subtitles, across the screen (ShopFocus sets them right of centre)
local OPEN_TIME = 0.45 -- the bars closing in, the column sliding in
local HOVER_TIME = 0.15
local PREVIEW_GAP = 28 -- between the column and the chosen item's preview
local PREVIEW_MAX = 240 -- the preview's width at most; it shrinks to the room left of the shopkeeper
local PREVIEW_MIN = 150 -- narrower than this, it isn't shown
local PREVIEW_CAPTION = 52 -- under the preview's box: the item's number and name
local PREVIEW_TURN = 0.6 -- radians a second a model in the preview turns
local SHOPKEEPER_HALF = 230 -- about how far left of their middle (SPEECH_AT) the shopkeeper reaches
local NUMBER_WIDTH = 28 -- a row's number, at its left
local ITEM_HEIGHT = 76
local CONSUMABLE_HEIGHT = 108 -- name, uses, detail (two lines), owned
local POWER_HEIGHT = 122 -- a power's row: picture, name, tier, detail (three lines), owned
local IMAGE_SIZE = 84 -- a power's picture, a square
local BADGE_SIZE = 30 -- a set's tier letter
local Style = HudConfig.Style
local Theme = HudConfig.HubTheme
local BACKGROUND = Style.Glass -- Modern Warfare's smoked glass; the text on a filled button
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
	props.Font = props.Font or Enum.Font.Highway
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local function formatYen(amount)
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "¥" .. grouped
end

local function formatRobux(amount)
	return (formatYen(amount):gsub("¥", "R$ "))
end

-- an item's tier: its own, or its skill set's
local function tierOf(item)
	local set = item.set and SkillSetConfig.Sets[item.set]
	return item.tier or (set and set.tier)
end

local TIER_ORDER = { S = 1, A = 2, B = 3, C = 4 }

-- a shop's items in menu order: as listed, except the Power Dealer's, which go
-- by tier (S first), made powers before unmade ones before coming-soon ones
local function shopItems(shopId)
	local items = {}
	for index, item in ipairs(ShopConfig.Items) do
		if ShopConfig.ShopOf(item) == shopId then
			local set = item.set and SkillSetConfig.Sets[item.set]
			local made = item.comingSoon and 3 or (set and set.placeholder) and 2 or 1
			table.insert(items, { item = item, index = index, tier = TIER_ORDER[tierOf(item)] or 99, made = made })
		end
	end
	if shopId == "Powers" then
		table.sort(items, function(a, b)
			if a.tier ~= b.tier then
				return a.tier < b.tier
			elseif a.made ~= b.made then
				return a.made < b.made
			end
			return a.index < b.index
		end)
	end
	local sorted = {}
	for _, entry in ipairs(items) do
		table.insert(sorted, entry.item)
	end
	return sorted
end

local gui = make("ScreenGui", {
	Name = "ShopMenu",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 30,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local function tween(instance, time, props)
	local tweenObject = TweenService:Create(instance, TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tweenObject:Play()
	return tweenObject
end

-- the colour to write on a fill of `color`
local function onColor(color)
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B > 0.4 and BACKGROUND or TEXT
end

-- the title menu's look: black bars along the top and the bottom, the dark fading off the left
-- edge for the column, the right left clear for the shopkeeper. The frame over the whole screen
-- is Active, so a click anywhere is taken by the menu and never punches or shoots.
local backdrop = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = true })
local shade = make("Frame", { Parent = backdrop, Size = UDim2.fromScale(SHADE_SHARE, 1), BackgroundColor3 = Theme.Nav, BorderSizePixel = 0 })
make("UIGradient", {
	Parent = shade,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	}),
})
local topBar = make("Frame", { Parent = backdrop, Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 4 })
local bottomBar = make("Frame", {
	Parent = backdrop,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 4,
})
for _, edge in ipairs({ { topBar, 1 }, { bottomBar, 0 } }) do
	make("Frame", {
		Parent = edge[1],
		AnchorPoint = Vector2.new(0, edge[2]),
		Position = UDim2.fromScale(0, edge[2]),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Edge,
		BackgroundTransparency = Theme.EdgeTransparency,
		BorderSizePixel = 0,
		ZIndex = 4,
	})
end
-- the player's yen, on the right of the bottom bar (E LEAVE is on its left)
local balance = label(bottomBar, {
	Text = "",
	RichText = true,
	Font = Style.MonoFont,
	TextSize = 12,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -PAD, 0.5, 0),
	Size = UDim2.new(0.5, -PAD, 0, 16),
	ZIndex = 5,
})

-- the column down the left: the shop's line with the accent before it, the shop's name big, the
-- keeper's name on an accent chip with a rule running on, then the items (they scroll on a short screen)
local column = make("Frame", { Parent = backdrop, BackgroundTransparency = 1, ZIndex = 5 })
local kickerBar = make("Frame", { Parent = column, Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(24, 2), BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 5 })
local subtitle = label(column, { Text = "", Font = Style.MonoFont, TextSize = 12, TextColor3 = MUTED, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -34, 0, 14), ZIndex = 5 })
local title = label(column, {
	Text = "SHOP",
	Font = Style.TitleFont,
	TextScaled = true,
	Position = UDim2.fromOffset(-2, 18),
	Size = UDim2.new(1, 0, 0, 72),
	ZIndex = 5,
})
make("UITextSizeConstraint", { Parent = title, MaxTextSize = 72 })
local chip = make("TextLabel", {
	Parent = column,
	Font = Style.TitleFont,
	TextSize = 20,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(1, 102),
	Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 5,
})
local chipRule = make("Frame", { Parent = column, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = MUTED, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 5 })
local panel = make("ScrollingFrame", {
	Parent = column,
	Position = UDim2.fromOffset(0, HEADER),
	Size = UDim2.new(1, 0, 1, -HEADER),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = MUTED,
	ScrollBarImageTransparency = 0.4,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 5,
})
-- the items, as tall as they need
local list = make("Frame", { Parent = panel, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0 })
make("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder })

local rows = {}
local selectedRow -- the row lit and in the preview: the last one under the mouse (or pressed)

-- the chosen item's preview, between the column and the shopkeeper: its picture (a power's
-- `image`), its model turning (the server's copy in ReplicatedStorage.ShopPreviews) or its tier
-- letter or initial, in a dark box with corner brackets, its number and name under it. It only
-- shows when there's room left of the shopkeeper.
local preview = make("Frame", { Parent = backdrop, BackgroundTransparency = 1, Visible = false, ZIndex = 5 })
local previewBox = make("Frame", {
	Parent = preview,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, -PREVIEW_CAPTION / 2),
	Size = UDim2.new(1, 0, 1, -PREVIEW_CAPTION),
	BackgroundColor3 = Theme.Nav,
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	ZIndex = 5,
})
local previewWash = make("Frame", { Parent = previewBox, Size = UDim2.fromScale(1, 1), BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 5 })
make("UIGradient", {
	Parent = previewWash,
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.6, 0.88),
		NumberSequenceKeypoint.new(1, 0.72),
	}),
})
local previewPop = make("UIScale", { Parent = previewBox })
local previewBrackets = {}
for _, corner in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
	for _, size in ipairs({ Vector2.new(16, 2), Vector2.new(2, 16) }) do
		table.insert(previewBrackets, make("Frame", {
			Parent = previewBox,
			AnchorPoint = Vector2.new(corner[1], corner[2]),
			Position = UDim2.fromScale(corner[1], corner[2]),
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			ZIndex = 7,
		}))
	end
end
local previewCount = label(preview, { Text = "", Font = Style.MonoFont, TextSize = 11, TextColor3 = MUTED, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, 0, 0, 14), ZIndex = 5 })
local previewName = label(preview, { Text = "", Font = Style.TitleFont, TextSize = 22, TextTruncate = Enum.TextTruncate.AtEnd, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 26), ZIndex = 5 })
local previewFits = false -- whether there's room for it on this screen
local previewContent -- what's in the box: an ImageLabel, a ViewportFrame or the letter
local previewModel -- the model turning in it, if any
local previewAngle = 0

-- the top bar is as tall as Roblox's band; the column fills the room between the bars
local band = ROBLOX_BAR_FALLBACK
local function place()
	band = GuiService:GetGuiInset().Y / UIScale.Get() -- Roblox's band is in real pixels
	band = band > 0 and band or ROBLOX_BAR_FALLBACK / UIScale.Get()
	column.Position = UDim2.fromOffset(PAD, band + COLUMN_GAP)
	column.Size = UDim2.new(0, COLUMN_WIDTH, 1, -(band + BOTTOM_BAR + 2 * COLUMN_GAP))
	if topBar.Size.Y.Offset > 0 then
		topBar.Size = UDim2.new(1, 0, 0, band)
	end
	-- the preview takes the room between the column and the shopkeeper, level with the keeper's chip
	local view = workspace.CurrentCamera
	local left = PAD + COLUMN_WIDTH + PREVIEW_GAP
	local size = math.min(PREVIEW_MAX, SPEECH_AT * (view and view.ViewportSize.X or 1371) / UIScale.Get() - SHOPKEEPER_HALF - left)
	previewFits = size >= PREVIEW_MIN
	preview.Position = UDim2.fromOffset(left, band + COLUMN_GAP + 102)
	preview.Size = UDim2.fromOffset(math.max(size, 0), math.max(size, 0) + PREVIEW_CAPTION)
	preview.Visible = previewFits and selectedRow ~= nil
end
place()
UIScale.OnChange(place)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
end

-- the bars close in and the column slides in from the left
local function intro()
	topBar.Size = UDim2.fromScale(1, 0)
	bottomBar.Size = UDim2.fromScale(1, 0)
	tween(topBar, OPEN_TIME, { Size = UDim2.new(1, 0, 0, band) })
	tween(bottomBar, OPEN_TIME, { Size = UDim2.new(1, 0, 0, BOTTOM_BAR) })
	shade.BackgroundTransparency = 1
	tween(shade, OPEN_TIME, { BackgroundTransparency = 0 })
	local at = UDim2.fromOffset(PAD, band + COLUMN_GAP)
	column.Position = at - UDim2.fromOffset(PAD + COLUMN_WIDTH, 0)
	tween(column, OPEN_TIME, { Position = at })
end

-- the keeper's lines, as subtitles under them (the list is on the left): their name small in the
-- shop's colour over the line typing out (white with a dark edge), and what the shop has to tell
-- you (not enough yen, a failure) under that
local speech = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(SPEECH_AT, 0, 1, -(BOTTOM_BAR + 24)),
	Size = UDim2.new(0.42, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 6,
})
make("UIListLayout", { Parent = speech, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
local speakerLabel = label(speech, {
	LayoutOrder = 1,
	Text = "",
	Font = Style.MonoFont,
	TextSize = 12,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 0.5,
	Size = UDim2.new(1, 0, 0, 14),
	ZIndex = 6,
})
local speechText = label(speech, {
	LayoutOrder = 2,
	Text = "",
	TextSize = 22,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 0.25,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	ZIndex = 6,
})
local note = label(speech, {
	LayoutOrder = 3,
	Text = "",
	TextSize = 14,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 0.4,
	Size = UDim2.new(1, 0, 0, 16),
	Visible = false,
	ZIndex = 6,
})
local currentShopId = ShopConfig.DefaultShop
local accent = GOLD -- the open shop's colour
local speakCount = 0
local TYPE_SPEED = 0.008 -- seconds per letter

-- names the shop and its keeper, and paints the column and the subtitles in the shop's colour
local function paintShop(shop, info)
	accent = info.color
	local keeper = shop:GetAttribute("ShopkeeperName")
	title.Text = string.upper(shop:GetAttribute("ShopTitle") or info.title)
	subtitle.Text = string.upper(shop:GetAttribute("ShopSubtitle") or "")
	kickerBar.BackgroundColor3 = accent
	chip.Visible = keeper ~= nil
	chip.Text = keeper and (" " .. string.upper(keeper) .. " ") or ""
	chip.BackgroundColor3 = accent
	chip.TextColor3 = onColor(accent)
	local ruleAt = keeper and TextService:GetTextSize(chip.Text, chip.TextSize, chip.Font, Vector2.new(1000, 100)).X + 14 or 0
	chipRule.Position = UDim2.fromOffset(ruleAt, 114)
	chipRule.Size = UDim2.new(1, -ruleAt, 0, 1)
	speakerLabel.TextColor3 = accent
	speakerLabel.Text = string.upper(keeper or title.Text)
end

-- the shopkeeper says a line for a moment (greet, buy, poor, full, fail, sell), typed out letter by letter
local function say(kind, itemName)
	local line = ShopConfig.Line(currentShopId, kind, itemName)
	if line == "" then
		return
	end
	speakCount += 1
	local mine = speakCount
	speech.Visible = true
	speechText.Text = line
	speechText.MaxVisibleGraphemes = 0
	task.spawn(function()
		local total = utf8.len(line) or #line
		for shown = 1, total do
			if mine ~= speakCount then
				return
			end
			speechText.MaxVisibleGraphemes = shown
			task.wait(TYPE_SPEED)
		end
		speechText.MaxVisibleGraphemes = -1
	end)
end

local function setStatus(text, failed)
	note.Text = text
	note.Visible = text ~= ""
	note.TextColor3 = failed and DANGER or GOLD
	if text ~= "" then
		speech.Visible = true
	end
	if failed then
		UiSfx.Play("purchaseFail")
	end
end

-- whether the player has a briefcase of the power: equipped on the hotbar or stored in the Backpack
local function carriesBriefcase(setName)
	if string.find("," .. (player:GetAttribute(PowerConfig.BriefcaseStorageAttribute) or "") .. ",", "," .. setName .. ",", 1, true) then
		return true
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ player.Character, backpack }) do
		for _, tool in ipairs(container and container:GetChildren() or {}) do
			if tool:IsA("Tool") and tool:GetAttribute(PowerConfig.BriefcaseAttribute) == setName then
				return true
			end
		end
	end
	return false
end

-- where the player has the power in their inventory: "equipped" (the held power), "in storage" or
-- "lifetime" (bought with Robux); nil when they don't have it (a briefcase in the backpack isn't
-- the power yet, and the OwnAllSets test switch doesn't count)
local function powerOwnership(setName)
	local function listed(attribute)
		return string.find("," .. (player:GetAttribute(attribute) or "") .. ",", "," .. setName .. ",", 1, true) ~= nil
	end
	if player:GetAttribute("CurrentPower") == setName then
		return "equipped"
	elseif listed("PowerStorage") then
		return "in storage"
	elseif listed("LifetimePowers") then
		return "lifetime"
	end
	return nil
end

-- how many of a consumable the player has: stacks equipped or stored (limited) or 1 if bought (lifetime)
local function consumableCount(item)
	if not item.stack then
		return player:GetAttribute(ShopConfig.OwnedAttribute(item.id)) == 1 and 1 or 0
	end
	-- equipped Tools and the stacks stored in the Backpack
	local count = ConsumableConfig.StoredCount(ConsumableConfig.ParseStorage(player:GetAttribute(ConsumableConfig.StorageAttribute)), item.consumable)
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ player.Character, backpack }) do
		for _, tool in ipairs(container and container:GetChildren() or {}) do
			if tool:IsA("Tool") and tool:GetAttribute(ConsumableConfig.Attribute) == item.consumable then
				count += 1
			end
		end
	end
	return count
end

local function lifetimeOwned(setName)
	return SkillSetConfig.OwnAllSets or string.find("," .. (player:GetAttribute("LifetimePowers") or "") .. ",", "," .. setName .. ",", 1, true) ~= nil
end

local function owns(item)
	return item.starter or (ShopConfig.Ownable(item) and player:GetAttribute(ShopConfig.OwnedAttribute(item.id)) == 1)
end

local function refresh()
	local yen = player:GetAttribute("Yen") or 0
	balance.Text = string.format('CASH  <font color="#%s">%s</font>', GOLD:ToHex(), formatYen(yen))
	for _, row in ipairs(rows) do
		local item = row.item
		if row.ownedLabel then
			if item.briefcase then
				-- only shown once you have the power
				local where = powerOwnership(item.set)
				row.ownedLabel.Visible = where ~= nil
				row.ownedLabel.Text = where and string.upper("owned: " .. where) or ""
			else
				row.ownedLabel.Text = "OWNED: " .. consumableCount(item)
			end
		end
		local owned = owns(item)
		local affordable = yen >= (priceOf(item) or 0)
		-- carrying as many of a consumable as allowed: greyed out, FULL
		local full = item.stack and not ConsumableConfig.CanCarryMore(consumableCount(item))
		if item.comingSoon then
			row.buy.Text = item.briefcase and "NOT FOR SALE" or "COMING SOON"
		elseif owned then
			row.buy.Text = "OWNED"
		elseif full then
			row.buy.Text = "FULL"
		else
			row.buy.Text = item.service and "USE" or "BUY"
		end
		local closed = owned or item.comingSoon or full
		row.buy.AutoButtonColor = not closed
		row.buy.BackgroundTransparency = closed and 0.85 or (affordable and 0 or 0.55)
		row.buy.TextColor3 = closed and MUTED or BACKGROUND
		if row.sell then
			local has = carriesBriefcase(item.set)
			row.sell.AutoButtonColor = has
			row.sell.BackgroundTransparency = has and 0 or 0.7
			row.sell.TextColor3 = has and BACKGROUND or MUTED
		end
		if row.lifetime then
			local have = lifetimeOwned(item.set)
			row.lifetime.Text = have and "LIFETIME OWNED" or ("LIFETIME " .. formatRobux(row.robuxPrice))
			row.lifetime.AutoButtonColor = not have
			row.lifetime.BackgroundTransparency = have and 0.7 or 0
			row.lifetime.TextColor3 = have and MUTED or BACKGROUND
		end
	end
end
player.AttributeChanged:Connect(function()
	if gui.Enabled then
		refresh()
	end
end)

-- why the shop would turn the player away before it even asks the server (too
-- poor, or already carrying all of a consumable they can), or nil; the second value is the
-- shopkeeper's line for it ("poor" or "full")
local function refusal(item)
	local yen = player:GetAttribute("Yen")
	local price = priceOf(item)
	if yen and price and yen < price then
		return string.format("You need ¥%d more", price - yen), "poor"
	end
	if item.stack and not ConsumableConfig.CanCarryMore(consumableCount(item)) then
		return "You can't carry more " .. item.name, "full"
	end
	return nil
end
local pressedPoorAt = -math.huge -- when a press already told the player they can't afford it
local pressedBuyAt = -math.huge -- when a press that could pay already played the buy sound
local buySound -- that sound, so a refusal can cut it off

local function buy(item)
	if item.comingSoon or owns(item) then
		return
	end
	-- too poor: say so (and sound it) now rather than after the trip to the server
	local why, kind = refusal(item)
	if why then
		if os.clock() - pressedPoorAt > 1 then -- (pressing the button already said it)
			setStatus(why, true)
			say(kind, item.name)
		end
		return
	end
	local ok, success, message = pcall(buyItem.InvokeServer, buyItem, item.id)
	if not ok then
		setStatus("Couldn't reach the shop", true)
		say("fail", item.name)
		return
	end
	if not success and buySound and os.clock() - pressedBuyAt < 5 then
		buySound:Stop() -- the server said no (a full Backpack, say): not a bought sound, just the failed one
	end
	buySound = nil
	setStatus(message, not success)
	if success and os.clock() - pressedBuyAt > 5 then -- (a press that could pay already sounded)
		UiSfx.Play("buy")
	end
	say(success and "buy" or "fail", item.name)
	refresh() -- a bought briefcase can now be sold
end

local function sell(item)
	if not carriesBriefcase(item.set) then
		setStatus("You aren't carrying a " .. item.name .. " briefcase", true)
		say("fail", item.name)
		return
	end
	local ok, success, message = pcall(sellItem.InvokeServer, sellItem, item.set)
	if not ok then
		setStatus("Couldn't reach the shop", true)
		say("fail", item.name)
		return
	end
	setStatus(message, not success)
	say(success and "sell" or "fail", item.name)
	refresh()
end

-- the item's model for the preview: a copy of the server's (ReplicatedStorage.ShopPreviews, by the
-- item's id) with its middle at the origin, or nil
local function previewModelOf(item)
	local folder = ReplicatedStorage:FindFirstChild("ShopPreviews")
	local source = folder and folder:FindFirstChild(item.id)
	if not source then
		return nil
	end
	local model = source:Clone()
	model.WorldPivot = model:GetBoundingBox()
	model:PivotTo(CFrame.new())
	return model
end

-- puts `entry`'s item in the preview (its picture, its model turning, or its letter), popping in
local function showPreview(entry)
	if previewContent then
		previewContent:Destroy()
		previewContent, previewModel = nil, nil
	end
	if not entry then
		return
	end
	local item = entry.item
	previewWash.BackgroundColor3 = accent
	for _, bracket in ipairs(previewBrackets) do
		bracket.BackgroundColor3 = accent
	end
	previewCount.Text = string.format("ITEM %02d / %02d", table.find(rows, entry) or 0, #rows)
	previewName.Text = string.upper(item.name)
	local model = not item.image and previewModelOf(item)
	if item.image then
		previewContent = make("ImageLabel", {
			Parent = previewBox,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.86, 0.86),
			BackgroundTransparency = 1,
			Image = item.image,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 6,
		})
	elseif model then
		local viewport = make("ViewportFrame", {
			Parent = previewBox,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(170, 170, 170),
			LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-1, -1, -1),
			ZIndex = 6,
		})
		local _, size = model:GetBoundingBox()
		local reach = size.Magnitude / 2
		local camera = make("Camera", { Parent = viewport, FieldOfView = 30 })
		camera.CFrame = CFrame.lookAt(Vector3.new(0, reach * 0.25, reach / math.tan(math.rad(15)) * 1.05), Vector3.zero)
		viewport.CurrentCamera = camera
		model.Parent = viewport
		previewContent, previewModel, previewAngle = viewport, model, 0
	else
		-- nothing to show yet: its tier letter (in the tier's colour) or its name's first letter, big and faint
		local tier = tierOf(item)
		local tierInfo = tier and SkillSetConfig.Tiers[tier]
		previewContent = label(previewBox, {
			Text = tier or string.upper(string.sub(item.name, 1, 1)),
			Font = Style.TitleFont,
			TextScaled = true,
			TextColor3 = tierInfo and tierInfo.color or accent,
			TextTransparency = 0.35,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.5, 0.5),
			ZIndex = 6,
		})
	end
	previewPop.Scale = 0.94
	tween(previewPop, 0.3, { Scale = 1 })
end

-- chooses `entry` (nil: none): lights its row, unlights the last one and shows its item in the preview
local function choose(entry)
	if entry == selectedRow then
		return
	end
	if selectedRow then
		selectedRow.paint(false)
	end
	selectedRow = entry
	if entry then
		entry.paint(true)
	end
	showPreview(entry)
	preview.Visible = previewFits and entry ~= nil
end

-- one row per item the shop sells, as the title menu's buttons: its number, a picture or a tier,
-- the name, uses or tier, detail and owned, and on the right the price and its buttons. The chosen
-- row (under the mouse, or pressed) has the shop's colour fading in behind it, a bar down its left
-- edge and its number lit (hoverRows, choose).
local function buildRows(shopId)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	rows = {}
	selectedRow = nil
	preview.Visible = false
	for _, item in ipairs(shopItems(shopId)) do
		if ShopConfig.ShopOf(item) == shopId then
			-- a consumable's or a power's row: name, uses or tier, detail, owned (the others: name and detail)
			local bodyHeight = item.briefcase and POWER_HEIGHT or item.consumable and CONSUMABLE_HEIGHT or ITEM_HEIGHT
			local rightMargin = item.briefcase and 124 or 96 -- a power's column of buttons is wider
			local robuxPrice = item.briefcase and item.price and not item.comingSoon and PowerConfig.robuxPrice(item.set, tierOf(item)) -- the Robux lifetime copy's price (made up until the products exist)
			local row = make("Frame", {
				Parent = list,
				LayoutOrder = #rows + 1,
				Size = UDim2.new(1, 0, 0, bodyHeight),
				BackgroundTransparency = 1,
			})
			local highlight = make("Frame", { Parent = row, Size = UDim2.fromScale(1, 1), BackgroundColor3 = accent, BackgroundTransparency = 1, BorderSizePixel = 0 })
			make("UIGradient", { Parent = highlight, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
			local bar = make("Frame", {
				Parent = row,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(3, 0),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				ZIndex = 2,
			})
			-- the thin rule under each row
			make("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = TEXT, BackgroundTransparency = 0.88, BorderSizePixel = 0 })
			-- pressing the row anywhere but its buttons chooses it too (touch has no hover). Made before the
			-- body: this gui's ZIndex is global, so the buttons in the body, coming later, take their own clicks
			local selector = make("TextButton", { Parent = row, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false })
			local body = make("Frame", { Parent = row, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 })
			make("UIPadding", { Parent = body, PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) })
			local number = label(body, {
				Text = string.format("%02d", #rows + 1),
				Font = Style.MonoFont,
				TextSize = 11,
				TextColor3 = MUTED,
				Size = UDim2.fromOffset(NUMBER_WIDTH, 22),
			})
			local textLeft = NUMBER_WIDTH
			local tier = tierOf(item)
			if item.briefcase then
				-- a power's picture goes here (an `image` on its ShopConfig item); until there is one the
				-- tier letter holds the place
				local tierColor = tier and SkillSetConfig.Tiers[tier] and SkillSetConfig.Tiers[tier].color or SkillSetConfig.NoTierColor
				local picture = make("ImageLabel", {
					Parent = body,
					Position = UDim2.fromOffset(textLeft, 0),
					Size = UDim2.fromOffset(IMAGE_SIZE, IMAGE_SIZE),
					BackgroundColor3 = Color3.fromRGB(14, 14, 20),
					BorderSizePixel = 0,
					Image = item.image or "",
					ScaleType = Enum.ScaleType.Crop,
				})
				make("UIStroke", { Parent = picture, Color = tierColor, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
				if not item.image then
					label(picture, {
						Text = tier or "?",
						Font = Style.TitleFont,
						TextSize = 34,
						TextColor3 = tierColor,
						TextTransparency = 0.4,
						TextXAlignment = Enum.TextXAlignment.Center,
						Size = UDim2.fromScale(1, 1),
					})
				end
				textLeft += IMAGE_SIZE + 12
			elseif tier then
				local tierColor = SkillSetConfig.Tiers[tier] and SkillSetConfig.Tiers[tier].color or SkillSetConfig.NoTierColor
				local badge = label(body, {
					Text = tier,
					Font = Style.TitleFont,
					TextSize = 18,
					TextColor3 = tierColor,
					TextXAlignment = Enum.TextXAlignment.Center,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, textLeft, 0.5, 0),
					Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE),
				})
				make("UIStroke", { Parent = badge, Color = tierColor, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
				textLeft += BADGE_SIZE + 10
			end
			local dim = item.comingSoon
			label(body, {
				Text = string.upper(item.name),
				Font = Style.TitleFont,
				TextSize = 22,
				TextColor3 = dim and MUTED or TEXT,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(textLeft, 0),
				Size = UDim2.new(1, -(rightMargin + textLeft), 0, 22),
			})
			local descriptionTop = 25
			local infoLine = item.uses or (item.briefcase and tier and (tier .. "-tier power"))
			if infoLine then
				label(body, {
					Text = string.upper(infoLine),
					Font = Style.MonoFont,
					TextSize = 11,
					TextColor3 = accent,
					Position = UDim2.fromOffset(textLeft, 25),
					Size = UDim2.new(1, -(rightMargin + textLeft), 0, 14),
				})
				descriptionTop = 42
			end
			label(body, {
				Text = item.briefcase and string.gsub(item.description, "^%a%-tier power%.%s*", "") or item.description,
				TextSize = 12,
				TextColor3 = MUTED,
				TextTransparency = dim and 0.3 or 0,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(textLeft, descriptionTop),
				Size = UDim2.new(1, -(rightMargin + textLeft), 0, item.briefcase and 42 or item.consumable and 30 or ITEM_HEIGHT - 16 - 25),
			})
			local ownedLabel
			if item.consumable or item.briefcase then
				ownedLabel = label(body, {
					Text = "OWNED: 0",
					Font = Style.MonoFont,
					TextSize = 11,
					TextColor3 = TEXT,
					Position = UDim2.fromOffset(textLeft, item.briefcase and 88 or 76),
					Size = UDim2.new(1, -(rightMargin + textLeft), 0, 14),
				})
			end
			-- the price sits top right, the BUY button bottom right
			if item.price and not item.comingSoon then
				label(body, {
					Text = item.price == 0 and "FREE" or formatYen(priceOf(item)),
					Font = Style.MonoFont,
					TextSize = 16,
					TextColor3 = GOLD,
					TextXAlignment = Enum.TextXAlignment.Right,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(110, 20),
				})
			end
			local button = make("TextButton", {
				Parent = body,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 0, 0, bodyHeight - 16 - (item.briefcase and 28 * (robuxPrice and 2 or 1) or 0)),
				Size = item.briefcase and UDim2.fromOffset(112, 24) or UDim2.fromOffset(84, 28),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				Font = Style.TitleFont,
				TextSize = item.comingSoon and 12 or 15,
				TextColor3 = BACKGROUND,
			})
			button.Activated:Connect(function()
				buy(item)
			end)
			-- the failed sound plays as the button goes down, not when it's let go
			button.MouseButton1Down:Connect(function()
				if item.comingSoon or owns(item) then
					return
				end
				local why, kind = refusal(item)
				if why then
					pressedPoorAt = os.clock()
					setStatus(why, true)
					say(kind, item.name)
				else
					-- nothing to stop it: the buy sound plays now (cut short if the server refuses)
					pressedBuyAt = os.clock()
					buySound = UiSfx.Play("buy")
				end
			end)
			local function paint(over)
				tween(highlight, HOVER_TIME, { BackgroundTransparency = over and 0.82 or 1 })
				tween(bar, HOVER_TIME, { Size = UDim2.new(0, 3, over and 1 or 0, 0) })
				tween(number, HOVER_TIME, { TextColor3 = over and accent or MUTED })
			end
			local entry = { item = item, buy = button, ownedLabel = ownedLabel, frame = row, paint = paint }
			selector.Activated:Connect(function()
				choose(entry)
			end)
			if item.briefcase then
				-- in the column under the price: BUY (yen), the Robux lifetime copy, and sell a carried briefcase
				local set = SkillSetConfig.Sets[item.set]
				entry.sell = make("TextButton", {
					Parent = body,
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, 0, 0, bodyHeight - 16),
					Size = UDim2.fromOffset(112, 24),
					BackgroundColor3 = accent,
					BorderSizePixel = 0,
					Font = Style.TitleFont,
					TextSize = 13,
					TextColor3 = BACKGROUND,
					Text = "SELL " .. formatYen(PowerConfig.sellPrice(item.set, set.tier)),
				})
				entry.sell.Activated:Connect(function()
					sell(item)
				end)
				if robuxPrice then
					entry.robuxPrice = robuxPrice
					entry.lifetime = make("TextButton", {
						Parent = body,
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, 0, 0, bodyHeight - 16 - 28),
						Size = UDim2.fromOffset(112, 24),
						BackgroundColor3 = accent,
						BorderSizePixel = 0,
						Font = Style.TitleFont,
						TextSize = 12,
						TextColor3 = BACKGROUND,
						Text = "LIFETIME " .. formatRobux(robuxPrice),
					})
					entry.lifetime.Activated:Connect(function()
						if lifetimeOwned(item.set) then
							return
						end
						if PowerConfig.RobuxProducts[item.set] then
							buyLifetime:FireServer(item.set)
						else
							setStatus("The lifetime copy isn't on sale yet", true)
							say("fail", item.name)
						end
					end)
				end
			end
			table.insert(rows, entry)
		end
	end
end

-- seconds until you're out of combat with other players (CombatRules.PvPAttribute on your character; enemies and
-- dummies don't count), nil if you are
local function combatLeft()
	local character = player.Character
	return CombatRules.SecondsLeft(character and character:GetAttribute(CombatRules.PvPAttribute), workspace:GetServerTimeNow())
end

-- a line of text near the top of the screen that fades out, for "can't shop in combat"
local noticeGui = make("ScreenGui", { Name = "ShopNotice", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 31, Parent = player:WaitForChild("PlayerGui") })
local notice = label(noticeGui, {
	Text = "",
	Font = Enum.Font.Highway,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextTransparency = 1,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 90),
	Size = UDim2.fromOffset(500, 26),
})
local noticeCount = 0
local function showNotice(text)
	UiSfx.Play("denied")
	noticeCount += 1
	local mine = noticeCount
	notice.Text = text
	notice.TextTransparency = 0
	notice.TextStrokeTransparency = 0.3
	task.delay(2, function()
		if mine == noticeCount then
			TweenService:Create(notice, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- the overhead tag shows only the shopkeeper's own name (ShopkeeperName); the role and the
-- shop's line it used to show are in the menu header. A tag with no ShopkeeperName is left alone.
local function dressTag(shop)
	local name = shop:GetAttribute("ShopkeeperName")
	local tag = shop:FindFirstChild("NameTag", true)
	if not name or not tag then
		return
	end
	local labels = {}
	for _, descendant in ipairs(tag:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			table.insert(labels, descendant)
		end
	end
	table.sort(labels, function(a, b)
		return a.Position.Y.Scale < b.Position.Y.Scale
	end)
	if labels[1] then
		labels[1].Text = name
	end
	if labels[2] then
		labels[2].Visible = false
	end
end
for _, shop in ipairs(CollectionService:GetTagged(ShopConfig.Tag)) do
	dressTag(shop)
end
CollectionService:GetInstanceAddedSignal(ShopConfig.Tag):Connect(function(shop)
	task.defer(dressTag, shop)
end)

-- the shopkeeper whose menu is open, so walking away can close it
local openAt
local lastRefresh = 0 -- when the rows were last refreshed (owned counts follow the backpack)

local function close()
	ShopFocus.End()
	if gui.Enabled then
		UiSfx.Play("shopLeave")
	end
	gui.Enabled = false
	speakCount += 1 -- stops a line still typing
	speech.Visible = false
	choose(nil)
	openAt = nil
	Menus.Close("Shop")
end
-- E LEAVE, on the left of the bottom bar
MenuFooter.Leave(gui, close, UDim2.new(0, PAD, 1, -(BOTTOM_BAR - HudConfig.HintsHeight) / 2))

-- chooses the row under the mouse (polled: a row's buttons take the mouse from the row itself);
-- off the list, the last one chosen stays
local function hoverRows()
	local mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset() -- the mouse counts from the very top, the gui from under Roblox's band
	local function inside(frame)
		local position, size = frame.AbsolutePosition, frame.AbsoluteSize
		return mouse.X >= position.X and mouse.X <= position.X + size.X and mouse.Y >= position.Y and mouse.Y <= position.Y + size.Y
	end
	local over
	if inside(panel) then
		for _, row in ipairs(rows) do
			if inside(row.frame) then
				over = row
				break
			end
		end
	end
	if over then
		choose(over)
	end
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local shop = prompt:FindFirstAncestorOfClass("Model")
	if shop and CollectionService:HasTag(shop, ShopConfig.Tag) then
		local left = combatLeft()
		if left then
			showNotice(string.format("You can't shop while in combat (%ds)", math.ceil(left)))
			return
		end
		local shopId = ShopConfig.ShopIdOf(shop)
		local info = ShopConfig.Shops[shopId] or ShopConfig.Shops[ShopConfig.DefaultShop]
		openAt = shop
		paintShop(shop, info)
		currentShopId = shopId
		buildRows(shopId)
		choose(rows[1])
		setStatus("")
		say("greet")
		refresh()
		panel.CanvasPosition = Vector2.zero
		Menus.Open("Shop", close)
		gui.Enabled = true
		intro()
		UiSfx.Play("shopEnter")
		-- the full-screen close-up on the shopkeeper (E leaves)
		ShopFocus.Begin(shop, { ignoreGui = gui, onLeave = close })
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if not openAt then
		return
	end
	if combatLeft() then
		close()
		showNotice("You can't shop while in combat")
		return
	end
	if os.clock() - lastRefresh > 0.3 then
		lastRefresh = os.clock() -- a bought Tool arrives a moment after the purchase
		refresh()
	end
	hoverRows()
	if previewModel then
		previewAngle += dt * PREVIEW_TURN
		previewModel:PivotTo(CFrame.Angles(0, previewAngle, 0))
	end
	ShopFocus.Step()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not openAt.Parent or (openAt:GetPivot().Position - root.Position).Magnitude > ShopConfig.Range then
		close()
	end
end)
