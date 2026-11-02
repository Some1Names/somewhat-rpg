-- Faction menu: opens from a recruiter's prompt (a model tagged "FactionRecruiter") over a
-- full-screen close-up of the recruiter (ShopFocus, which also makes E leave). A row for each
-- faction the recruiter offers (FactionConfig.Offered): its name, its rank ladder in its colour,
-- what it stands for, its shop discount and a JOIN button (MEMBER for your own, whose row stays
-- lit; LOCKED while the switch cooldown runs). JOIN goes through the FactionAction remote
-- (FactionServer), which does all the checking. Closes when you walk away, or when another menu
-- opens (Menus).
-- It's in the shops' look (ShopMenu): black bars along the top and bottom (E LEAVE and your faction
-- and rank in the bottom one), the recruiter on the right, and down the left, over a dark fading off
-- the edge, FACTIONS (or their ShopSubtitle), their title big (ShopTitle, else the model's name) and
-- their name on a chip (ShopkeeperName, if set), then the factions. What joining or switching means
-- is the recruiter's line, a subtitle under them, with the server's replies under it.
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local FactionConfig = require(ReplicatedStorage:WaitForChild("FactionConfig"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local MenuFooter = require(script.Parent:WaitForChild("MenuFooter"))
local ShopFocus = require(script.Parent:WaitForChild("ShopFocus"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local remote = ReplicatedStorage:WaitForChild(FactionConfig.Remote)
local player = Players.LocalPlayer

local PAD = 64 -- the screen's left edge to the column (as on the title menu and the shops)
local COLUMN_WIDTH = 460
local COLUMN_GAP = 26 -- between the top bar and the column, and the column and the bottom bar
local HEADER = 150 -- the column's top: FACTIONS, the recruiter's title big, their name on a chip
local BOTTOM_BAR = 44 -- the black bar along the bottom; the top one is as tall as Roblox's band
local ROBLOX_BAR_FALLBACK = 58 -- Roblox's band across the top, while GetGuiInset still says 0
local SHADE_SHARE = 0.62 -- how far across the screen the dark fades off the left edge
local SPEECH_AT = 0.72 -- the middle of the recruiter's subtitles, across the screen (ShopFocus sets them right of centre)
local OPEN_TIME = 0.45 -- the bars closing in, the column sliding in
local HOVER_TIME = 0.15
local NUMBER_WIDTH = 28 -- a row's number, at its left
local ROW_HEIGHT = 108 -- name, ranks, what it stands for (two lines), its discount
local TYPE_SPEED = 0.008 -- seconds per letter of the recruiter's line
local PROMPT_NAME = "FactionPrompt" -- the prompt FactionServer puts on a recruiter
local Style = HudConfig.Style
local Theme = HudConfig.HubTheme
local BACKGROUND = Style.Glass -- Modern Warfare's smoked glass; the text on a filled button
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local GOLD = Color3.fromRGB(255, 205, 60)
local DANGER = Color3.fromRGB(226, 75, 74)
local ACCENT = Color3.fromRGB(236, 236, 238) -- the menu's own, neutral; each faction's row is in its colour

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

local function rgb(list)
	return Color3.fromRGB(list[1], list[2], list[3])
end

local gui = make("ScreenGui", {
	Name = "FactionMenu",
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

-- the shops' look: black bars along the top and the bottom, the dark fading off the left edge for
-- the column, the right left clear for the recruiter. The frame over the whole screen is Active, so
-- a click anywhere is taken by the menu and never punches or shoots.
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
-- your faction now, on the right of the bottom bar (E LEAVE is on its left)
local current = label(bottomBar, {
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

-- the column down the left: FACTIONS with the accent before it, the recruiter's title big, their
-- name on a chip with a rule running on, then the factions (they scroll on a short screen)
local column = make("Frame", { Parent = backdrop, BackgroundTransparency = 1, ZIndex = 5 })
make("Frame", { Parent = column, Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(24, 2), BackgroundColor3 = ACCENT, BorderSizePixel = 0, ZIndex = 5 })
local subtitle = label(column, { Text = "FACTIONS", Font = Style.MonoFont, TextSize = 12, TextColor3 = MUTED, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -34, 0, 14), ZIndex = 5 })
local title = label(column, {
	Text = "RECRUITER",
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
	TextColor3 = onColor(ACCENT),
	BackgroundColor3 = ACCENT,
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
-- the factions, as tall as they need
local list = make("Frame", { Parent = panel, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0 })
make("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder })

local rows = {}
local hoveredRow -- the row under the mouse, lit

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
end
place()
UIScale.OnChange(place)

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

-- the recruiter's line, as subtitles under them (the factions are on the left): their name small
-- over the line typing out (white with a dark edge), and the server's replies under that
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
	TextColor3 = ACCENT,
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
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 0.4,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
	ZIndex = 6,
})
local spoken = "" -- the line on screen, so a re-render doesn't type it out again
local speakCount = 0

-- the recruiter says `line`, typed out letter by letter
local function say(line)
	if line == spoken then
		return
	end
	spoken = line
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
end

-- names the recruiter: FACTIONS (or their ShopSubtitle), their title big (ShopTitle, else the model's
-- name) and their name on the chip (ShopkeeperName; none hides the chip), and over the subtitles
local function paintHeader(recruiter)
	local keeper = recruiter:GetAttribute("ShopkeeperName")
	title.Text = string.upper(recruiter:GetAttribute("ShopTitle") or recruiter.Name)
	subtitle.Text = string.upper(recruiter:GetAttribute("ShopSubtitle") or "Factions")
	chip.Visible = keeper ~= nil
	chip.Text = keeper and (" " .. string.upper(keeper) .. " ") or ""
	local ruleAt = keeper and TextService:GetTextSize(chip.Text, chip.TextSize, chip.Font, Vector2.new(1000, 100)).X + 14 or 0
	chipRule.Position = UDim2.fromOffset(ruleAt, 114)
	chipRule.Size = UDim2.new(1, -ruleAt, 0, 1)
	speakerLabel.Text = string.upper(keeper or title.Text)
end

local openAt -- the recruiter whose menu is open, so walking away can close it
local busy = false
local render

local function join(faction)
	if busy or not openAt then
		return
	end
	busy = true
	local ok, success, message = pcall(remote.InvokeServer, remote, "join", openAt, faction.key)
	busy = false
	if not ok then
		setStatus("Couldn't reach the recruiter", true)
	else
		setStatus(message or "", not success)
	end
	render()
end

-- what a faction's button says, and whether it can be pressed
local function buttonState(faction, key, joinedAt)
	if key == faction.key then
		return "MEMBER", false
	end
	local ok = FactionConfig.CanJoin(key, joinedAt, faction.key, workspace:GetServerTimeNow())
	return ok and "JOIN" or "LOCKED", ok
end

-- one row per faction, as the shops' rows, in the faction's colour: its number, name, rank ladder,
-- what it stands for, its shop discount, and JOIN bottom right. Your own stays lit; under the mouse
-- a row lights the same way: the colour fades in behind it, a bar runs down its left edge and the
-- number lights (hoverRows).
local function factionRow(faction, order, key, joinedAt)
	local color = rgb(faction.color)
	local member = key == faction.key
	local row = make("Frame", { Parent = list, LayoutOrder = order, Size = UDim2.new(1, 0, 0, ROW_HEIGHT), BackgroundTransparency = 1 })
	local highlight = make("Frame", { Parent = row, Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = member and 0.82 or 1, BorderSizePixel = 0 })
	make("UIGradient", { Parent = highlight, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
	local bar = make("Frame", {
		Parent = row,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 3, member and 1 or 0, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	-- the thin rule under each row
	make("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = TEXT, BackgroundTransparency = 0.88, BorderSizePixel = 0 })
	local body = make("Frame", { Parent = row, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 })
	make("UIPadding", { Parent = body, PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) })
	local number = label(body, {
		Text = string.format("%02d", order),
		Font = Style.MonoFont,
		TextSize = 11,
		TextColor3 = member and color or MUTED,
		Size = UDim2.fromOffset(NUMBER_WIDTH, 22),
	})
	local textWidth = UDim2.new(1, -(NUMBER_WIDTH + 96), 0, 0) -- clear of the button
	label(body, {
		Text = string.upper(faction.name),
		Font = Style.TitleFont,
		TextSize = 22,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(NUMBER_WIDTH, 0),
		Size = textWidth + UDim2.fromOffset(0, 22),
	})
	label(body, {
		Text = string.upper(table.concat(faction.rankNames, "  ›  ")),
		Font = Style.MonoFont,
		TextSize = 11,
		TextColor3 = color,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(NUMBER_WIDTH, 25),
		Size = textWidth + UDim2.fromOffset(0, 14),
	})
	label(body, {
		Text = faction.description or "",
		TextSize = 12,
		TextColor3 = MUTED,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(NUMBER_WIDTH, 42),
		Size = textWidth + UDim2.fromOffset(0, 30),
	})
	local discounts = faction.shopDiscount
	local best = discounts and discounts[#discounts] or 0
	label(body, {
		Text = best > 0 and string.format("SHOP DISCOUNT UP TO %d%%", math.floor(best * 100 + 0.5)) or "NO SHOP DISCOUNT",
		Font = Style.MonoFont,
		TextSize = 11,
		TextColor3 = best > 0 and GOLD or MUTED,
		Position = UDim2.fromOffset(NUMBER_WIDTH, 76),
		Size = textWidth + UDim2.fromOffset(0, 14),
	})
	local text, enabled = buttonState(faction, key, joinedAt)
	local button = make("TextButton", {
		Parent = body,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(84, 28),
		BackgroundColor3 = color,
		BackgroundTransparency = enabled and 0 or 0.85,
		BorderSizePixel = 0,
		AutoButtonColor = enabled,
		Font = Style.TitleFont,
		Text = text,
		TextSize = 15,
		TextColor3 = enabled and onColor(color) or (text == "MEMBER" and color or MUTED),
	})
	if enabled then
		button.Activated:Connect(function()
			join(faction)
		end)
	end
	local function paint(over)
		local lit = over or member
		tween(highlight, HOVER_TIME, { BackgroundTransparency = lit and 0.82 or 1 })
		tween(bar, HOVER_TIME, { Size = UDim2.new(0, 3, lit and 1 or 0, 0) })
		tween(number, HOVER_TIME, { TextColor3 = lit and color or MUTED })
	end
	table.insert(rows, { frame = row, paint = paint })
end

function render()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	rows = {}
	hoveredRow = nil
	if not openAt then
		return
	end
	local key, standing, joinedAt = FactionConfig.Parse(player:GetAttribute(FactionConfig.SaveAttribute))
	local mine = key and FactionConfig.Get(key)
	if mine then
		current.Text = string.format(
			'CURRENT  <font color="#%s">%s</font>  ·  <font color="#%s">%s</font>',
			rgb(FactionConfig.RankColor(key, standing)):ToHex(),
			string.upper(mine.name),
			TEXT:ToHex(),
			string.upper(FactionConfig.RankName(standing, key))
		)
		local cooldown = FactionConfig.SwitchCooldown
		say(
			string.format(
				"Switching starts your standing again at 0. You can switch %s after joining.",
				cooldown >= 3600 and string.format("%d h", cooldown // 3600) or string.format("%d min", cooldown // 60)
			)
		)
	else
		current.Text = "YOU AREN'T IN A FACTION YET"
		say("Members rank up from kills: enemies, and players of a rival faction.")
	end
	for i, faction in ipairs(FactionConfig.Offered(openAt:GetAttribute("FactionId"))) do
		factionRow(faction, i, key, joinedAt)
	end
end

player:GetAttributeChangedSignal(FactionConfig.SaveAttribute):Connect(function()
	if gui.Enabled then
		render()
	end
end)

local function close()
	ShopFocus.End()
	gui.Enabled = false
	speakCount += 1 -- stops a line still typing
	spoken = ""
	speech.Visible = false
	openAt = nil
	Menus.Close("Faction")
end
-- E LEAVE, on the left of the bottom bar
MenuFooter.Leave(gui, close, UDim2.new(0, PAD, 1, -(BOTTOM_BAR - HudConfig.HintsHeight) / 2))

-- lights the row under the mouse (polled: a row's button takes the mouse from the row itself)
local function hoverRows()
	local mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset() -- (AbsolutePosition starts under Roblox's band)
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
	if over ~= hoveredRow then
		if hoveredRow then
			hoveredRow.paint(false)
		end
		hoveredRow = over
		if over then
			over.paint(true)
		end
	end
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local recruiter = prompt:FindFirstAncestorOfClass("Model")
	if prompt.Name == PROMPT_NAME and recruiter and CollectionService:HasTag(recruiter, FactionConfig.RecruiterTag) then
		openAt = recruiter
		setStatus("")
		paintHeader(recruiter)
		render()
		panel.CanvasPosition = Vector2.zero
		Menus.Open("Faction", close)
		gui.Enabled = true
		intro()
		-- the full-screen close-up on the recruiter (E leaves)
		ShopFocus.Begin(recruiter, { ignoreGui = gui, onLeave = close })
	end
end)

RunService.Heartbeat:Connect(function()
	if not openAt then
		return
	end
	hoverRows()
	ShopFocus.Step()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not openAt.Parent or (openAt:GetPivot().Position - root.Position).Magnitude > FactionConfig.RecruiterRange then
		close()
	end
end)
