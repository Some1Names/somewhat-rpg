-- Shop menu: opens from a shopkeeper's prompt and lists the ShopConfig items
-- of that shopkeeper's shop (its ShopId attribute) with their yen prices.
-- Skill sets show their tier; placeholders for sets still to come show as
-- COMING SOON. Buying goes through the ShopServer script, which does all
-- the checking. The Power Dealer's rows (briefcase items) also have SELL,
-- for a briefcase you carry, and LIFETIME R$ where the power has a Robux
-- product (PowerSources prompts the purchase). Closes when you walk away, or when another menu opens (Menus).
-- It fills the screen: the camera closes in on the shopkeeper (on the right, the list on the
-- left), the player's own character is hidden and their controls are off until it closes
-- (ShopFocus does all that, and makes E leave). The
-- header shows what the shopkeeper's overhead tag used to say (their ShopTitle and ShopSubtitle
-- attributes); the tag itself now shows only their own name (ShopkeeperName, dressTag).
-- It won't open while you're fighting other players (not enemies), and closes if you start while it's open.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CombatRules = require(ReplicatedStorage:WaitForChild("CombatRules"))
local ConsumableConfig = require(ReplicatedStorage:WaitForChild("ConsumableConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local ShopFocus = require(script.Parent:WaitForChild("ShopFocus"))
local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local buyItem = ReplicatedStorage:WaitForChild("BuyItem")
local sellItem = ReplicatedStorage:WaitForChild("SellItem")
local buyLifetime = ReplicatedStorage:WaitForChild("BuyLifetime")
local player = Players.LocalPlayer

local PANEL_WIDTH = 440
local PADDING = 14
local ITEM_HEIGHT = 70
local CONSUMABLE_HEIGHT = 104 -- name, uses, detail (two lines), owned
local POWER_HEIGHT = 116 -- a power's row: picture, name, tier, detail (three lines), owned
local IMAGE_SIZE = 84 -- a power's picture, a square
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

-- darkens the left of the screen for the list; the right stays clear for the shopkeeper.
-- Active, so a click anywhere on the screen is taken by the menu and never punches or shoots.
local backdrop = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Active = true })
make("UIGradient", {
	Parent = backdrop,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.45, 0.5),
		NumberSequenceKeypoint.new(0.8, 1),
		NumberSequenceKeypoint.new(1, 1),
	}),
})

local panel = make("ScrollingFrame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 40, 0.5, 0),
	Size = UDim2.new(0, PANEL_WIDTH, 1, -120),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	ScrollingDirection = Enum.ScrollingDirection.Y,
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

-- header: what the shopkeeper's overhead tag used to say (the role big, the shop's line above), close
local header = section(58)
local subtitle = label(header, { Text = "", Font = Enum.Font.GothamBold, TextSize = 13, Size = UDim2.new(1, -30, 0, 16) })
local title = label(header, {
	Text = "SHOP",
	Font = Enum.Font.GothamBlack,
	TextSize = 30,
	Position = UDim2.fromOffset(0, 18),
	Size = UDim2.new(1, -30, 0, 38),
})
-- the player's yen, top right of the screen
local balanceBox = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -40, 0, 28),
	Size = UDim2.fromOffset(240, 40),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
})
make("UIStroke", { Parent = balanceBox, Color = GOLD, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
label(balanceBox, { Text = "CASH", TextSize = 12, TextColor3 = MUTED, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.4, 0, 1, 0) })
local balance = label(balanceBox, {
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Right,
	Size = UDim2.new(1, -12, 1, 0),
})
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
})

-- the items; the panel itself scrolls when the screen is too short for them (one scroll bar)
order += 1
local list = make("Frame", {
	Parent = panel,
	LayoutOrder = order,
	Size = UDim2.new(1, 0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
})
local listLayout = make("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })
-- as tall as the items need
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	list.Size = UDim2.new(1, 0, 0, listLayout.AbsoluteContentSize.Y)
end)

local status = label(section(14), { Text = "", TextSize = 11, TextColor3 = MUTED, Size = UDim2.fromScale(1, 1) })

local leave = make("TextButton", {
	Parent = section(34),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.4,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = "LEAVE SHOP",
	TextSize = 13,
	TextColor3 = TEXT,
})

local rows = {}

local function setStatus(text, failed)
	status.Text = text
	status.TextColor3 = failed and DANGER or GOLD
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
	balance.Text = formatYen(yen)
	for _, row in ipairs(rows) do
		local item = row.item
		if row.ownedLabel then
			if item.briefcase then
				-- only shown once you have the power
				local where = powerOwnership(item.set)
				row.ownedLabel.Visible = where ~= nil
				row.ownedLabel.Text = where and ("owned: " .. where) or ""
			else
				row.ownedLabel.Text = "owned: " .. consumableCount(item)
			end
		end
		local owned = owns(item)
		local affordable = yen >= (item.price or 0)
		if item.comingSoon then
			row.buy.Text = item.briefcase and "NOT FOR SALE" or "COMING SOON"
		elseif owned then
			row.buy.Text = "OWNED"
		else
			row.buy.Text = item.service and "USE" or "BUY"
		end
		local closed = owned or item.comingSoon
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
	refresh() -- a bought briefcase can now be sold
end

local function sell(item)
	if not carriesBriefcase(item.set) then
		setStatus("You aren't carrying a " .. item.name .. " briefcase", true)
		return
	end
	local ok, success, message = pcall(sellItem.InvokeServer, sellItem, item.set)
	if not ok then
		setStatus("Couldn't reach the shop", true)
		return
	end
	setStatus(message, not success)
	refresh()
end

-- one row per item the shop sells
local function buildRows(shopId)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	rows = {}
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
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.6,
			})
			make("UIPadding", { Parent = row, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) })
			local textLeft = 0
			local tier = tierOf(item)
			if item.briefcase then
				-- a power's picture goes here (an `image` on its ShopConfig item); until there is one the
				-- tier letter holds the place
				local tierColor = tier and SkillSetConfig.Tiers[tier] and SkillSetConfig.Tiers[tier].color or SkillSetConfig.NoTierColor
				local picture = make("ImageLabel", {
					Parent = row,
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
						Font = Enum.Font.GothamBlack,
						TextSize = 34,
						TextColor3 = tierColor,
						TextTransparency = 0.4,
						TextXAlignment = Enum.TextXAlignment.Center,
						Size = UDim2.fromScale(1, 1),
					})
				end
				textLeft = IMAGE_SIZE + 12
			elseif tier then
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
				Size = UDim2.new(1, -(rightMargin + textLeft), 0, 16),
			})
			local descriptionTop = 19
			local infoLine = item.uses or (item.briefcase and tier and (tier .. "-tier power"))
			if infoLine then
				label(row, {
					Text = infoLine,
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					TextColor3 = GOLD,
					Position = UDim2.fromOffset(textLeft, 19),
					Size = UDim2.new(1, -(rightMargin + textLeft), 0, 14),
				})
				descriptionTop = 36
			end
			label(row, {
				Text = item.briefcase and string.gsub(item.description, "^%a%-tier power%.%s*", "") or item.description,
				TextSize = 11,
				TextColor3 = MUTED,
				TextTransparency = dim and 0.3 or 0,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(textLeft, descriptionTop),
				Size = UDim2.new(1, -(rightMargin + textLeft), 0, item.briefcase and 42 or item.consumable and 30 or ITEM_HEIGHT - 16 - 19),
			})
			local ownedLabel
			if item.consumable or item.briefcase then
				ownedLabel = label(row, {
					Text = "owned: 0",
					TextSize = 11,
					TextColor3 = TEXT,
					Position = UDim2.fromOffset(textLeft, item.briefcase and 82 or 70),
					Size = UDim2.new(1, -(rightMargin + textLeft), 0, 14),
				})
			end
			-- the price sits top right, the BUY button bottom right
			if item.price and not item.comingSoon then
				label(row, {
					Text = item.price == 0 and "FREE" or formatYen(item.price),
					Font = Enum.Font.GothamBold,
					TextSize = 15,
					TextColor3 = GOLD,
					TextXAlignment = Enum.TextXAlignment.Right,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(90, 18),
				})
			end
			local button = make("TextButton", {
				Parent = row,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 0, 0, bodyHeight - 16 - (item.briefcase and 28 * (robuxPrice and 2 or 1) or 0)),
				Size = item.briefcase and UDim2.fromOffset(112, 24) or UDim2.fromOffset(84, 28),
				BackgroundColor3 = GOLD,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				TextSize = item.comingSoon and 10 or 12,
				TextColor3 = BACKGROUND,
			})
			button.Activated:Connect(function()
				buy(item)
			end)
			local entry = { item = item, buy = button, ownedLabel = ownedLabel }
			if item.briefcase then
				-- in the column under the price: BUY (yen), the Robux lifetime copy, and sell a carried briefcase
				local set = SkillSetConfig.Sets[item.set]
				entry.sell = make("TextButton", {
					Parent = row,
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, 0, 0, bodyHeight - 16),
					Size = UDim2.fromOffset(112, 24),
					BackgroundColor3 = GOLD,
					BorderSizePixel = 0,
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					TextColor3 = BACKGROUND,
					Text = "SELL " .. formatYen(PowerConfig.sellPrice(item.set, set.tier)),
				})
				entry.sell.Activated:Connect(function()
					sell(item)
				end)
				if robuxPrice then
					entry.robuxPrice = robuxPrice
					entry.lifetime = make("TextButton", {
						Parent = row,
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, 0, 0, bodyHeight - 16 - 28),
						Size = UDim2.fromOffset(112, 24),
						BackgroundColor3 = GOLD,
						BorderSizePixel = 0,
						Font = Enum.Font.GothamBold,
						TextSize = 10,
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
	Font = Enum.Font.GothamBold,
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
	gui.Enabled = false
	openAt = nil
	Menus.Close("Shop")
end
closeButton.Activated:Connect(close)
leave.Activated:Connect(close)

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
		title.Text = shop:GetAttribute("ShopTitle") or info.title
		subtitle.Text = shop:GetAttribute("ShopSubtitle") or ""
		subtitle.TextColor3 = info.color
		panelStroke.Color = info.color
		buildRows(shopId)
		setStatus("")
		refresh()
		panel.CanvasPosition = Vector2.zero
		Menus.Open("Shop", close)
		gui.Enabled = true
		-- the full-screen close-up on the shopkeeper (E leaves)
		ShopFocus.Begin(shop, { ignoreGui = gui, onLeave = close })
	end
end)

RunService.Heartbeat:Connect(function()
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
	ShopFocus.Step()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not openAt.Parent or (openAt:GetPivot().Position - root.Position).Magnitude > ShopConfig.Range then
		close()
	end
end)
