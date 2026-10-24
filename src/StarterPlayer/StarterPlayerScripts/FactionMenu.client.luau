-- Faction menu: opens from a recruiter's prompt (a model tagged "FactionRecruiter") over a
-- full-screen close-up of the recruiter (ShopFocus, which also makes E leave). Your current
-- faction and rank at the top, then a card for each faction the recruiter offers
-- (FactionConfig.Offered): its name in its colour, what it stands for, its rank ladder, its
-- shop discount and a JOIN button (MEMBER for your own, LOCKED while the switch cooldown
-- runs). JOIN goes through the FactionAction remote (FactionServer), which does all the
-- checking. Square. Closes when you walk away, or when another menu opens (Menus).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FactionConfig = require(ReplicatedStorage:WaitForChild("FactionConfig"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local ShopFocus = require(script.Parent:WaitForChild("ShopFocus"))
local remote = ReplicatedStorage:WaitForChild(FactionConfig.Remote)
local player = Players.LocalPlayer

local PANEL_WIDTH = 460
local PADDING = 14
local CARD_HEIGHT = 118
local CAMERA_SHIFT = 2.8 -- studs the recruiter sits right of centre, clear of the panel
local PROMPT_NAME = "FactionPrompt" -- the prompt FactionServer puts on a recruiter
local Style = HudConfig.Style
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

-- darkens the left of the screen for the menu; the right stays clear for the recruiter.
-- Active, so a click anywhere on the screen is taken by the menu and never punches or shoots.
local backdrop = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Active = true })
make("UIGradient", {
	Parent = backdrop,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(0.85, 1),
		NumberSequenceKeypoint.new(1, 1),
	}),
})

local panel = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 40, 0.5, 0),
	Size = UDim2.new(0, PANEL_WIDTH, 1, -120),
	BackgroundColor3 = Style.Glass,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
})
make("UIStroke", { Parent = panel, Color = TEXT, Transparency = Style.EdgeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
make("UIPadding", {
	Parent = panel,
	PaddingTop = UDim.new(0, PADDING),
	PaddingBottom = UDim.new(0, PADDING),
	PaddingLeft = UDim.new(0, PADDING),
	PaddingRight = UDim.new(0, PADDING),
})

-- header: the recruiter's role big with the line above it (like a shop's), close
label(panel, { Text = "FACTIONS", Font = Style.MonoFont, TextSize = 11, TextColor3 = MUTED, Size = UDim2.new(1, -30, 0, 16) })
local title = label(panel, {
	Text = "RECRUITER",
	Font = Style.TitleFont,
	TextSize = 36,
	Position = UDim2.fromOffset(0, 18),
	Size = UDim2.new(1, -30, 0, 38),
	TextTruncate = Enum.TextTruncate.AtEnd,
})
local closeButton = make("TextButton", {
	Parent = panel,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.Highway,
	Text = "×",
	TextSize = 20,
	TextColor3 = MUTED,
})

-- your faction now, and what switching costs
local current = label(panel, { Text = "", RichText = true, TextSize = 14, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 18) })
local warning = label(panel, {
	Text = "",
	TextSize = 12,
	TextColor3 = MUTED,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(0, 82),
	Size = UDim2.new(1, 0, 0, 30),
})

-- the bottom: a status line and the leave button
local leave = make("TextButton", {
	Parent = panel,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.4,
	BorderSizePixel = 0,
	Font = Enum.Font.Highway,
	Text = "LEAVE [E]",
	TextSize = 13,
	TextColor3 = TEXT,
})
local status = label(panel, {
	Text = "",
	TextSize = 12,
	TextColor3 = MUTED,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -40),
	Size = UDim2.new(1, 0, 0, 16),
})
local function setStatus(text, failed)
	status.Text = text
	status.TextColor3 = failed and DANGER or GOLD
end

-- the cards
local LIST_TOP = 118
local list = make("ScrollingFrame", {
	Parent = panel,
	Position = UDim2.fromOffset(0, LIST_TOP),
	Size = UDim2.new(1, 0, 1, -(LIST_TOP + 62)),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
})
make("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

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

local function card(faction, order, key, joinedAt)
	local color = rgb(faction.color)
	local frame = make("Frame", {
		Parent = list,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, CARD_HEIGHT),
		BackgroundColor3 = Color3.fromRGB(30, 32, 36),
		BackgroundTransparency = key == faction.key and 0.1 or 0.35,
		BorderSizePixel = 0,
	})
	make("UIStroke", {
		Parent = frame,
		Color = key == faction.key and color or TEXT,
		Transparency = key == faction.key and 0.3 or Style.EdgeTransparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	make("Frame", { Parent = frame, Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0 })
	label(frame, {
		Text = string.upper(faction.name),
		Font = Style.TitleFont,
		TextSize = 22,
		TextColor3 = color,
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -28, 0, 24),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	label(frame, {
		Text = faction.description or "",
		TextSize = 13,
		TextColor3 = MUTED,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(16, 34),
		Size = UDim2.new(1, -28, 0, 18),
	})
	label(frame, {
		Text = table.concat(faction.rankNames, "  ›  "),
		Font = Style.MonoFont,
		TextSize = 10,
		TextColor3 = TEXT,
		Position = UDim2.fromOffset(16, 56),
		Size = UDim2.new(1, -28, 0, 14),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local discounts = faction.shopDiscount
	local best = discounts and discounts[#discounts] or 0
	label(frame, {
		Text = best > 0 and string.format("Shop discount up to %d%%", math.floor(best * 100 + 0.5)) or "No shop discount",
		TextSize = 12,
		TextColor3 = best > 0 and GOLD or MUTED,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -12),
		Size = UDim2.new(1, -150, 0, 16),
	})
	local text, enabled = buttonState(faction, key, joinedAt)
	local button = make("TextButton", {
		Parent = frame,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		Size = UDim2.fromOffset(110, 28),
		BackgroundColor3 = enabled and Color3.fromRGB(236, 236, 238) or Color3.fromRGB(40, 40, 46),
		BackgroundTransparency = enabled and 0 or 0.15,
		BorderSizePixel = 0,
		AutoButtonColor = enabled,
		Font = Enum.Font.Highway,
		Text = text,
		TextSize = 13,
		TextColor3 = enabled and Color3.fromRGB(20, 20, 23) or (text == "MEMBER" and color or MUTED),
	})
	if enabled then
		button.Activated:Connect(function()
			join(faction)
		end)
	end
end

function render()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not openAt then
		return
	end
	local key, standing, joinedAt = FactionConfig.Parse(player:GetAttribute(FactionConfig.SaveAttribute))
	local mine = key and FactionConfig.Get(key)
	if mine then
		current.Text = string.format(
			'<font color="#%s">CURRENT</font>  <font color="#%s">%s</font>  ·  %s',
			MUTED:ToHex(),
			rgb(FactionConfig.RankColor(key, standing)):ToHex(),
			mine.name,
			FactionConfig.RankName(standing, key)
		)
		local cooldown = FactionConfig.SwitchCooldown
		warning.Text = string.format(
			"Switching starts your standing again at 0. You can switch %s after joining.",
			cooldown >= 3600 and string.format("%d h", cooldown // 3600) or string.format("%d min", cooldown // 60)
		)
	else
		current.Text = string.format('<font color="#%s">You aren\'t in a faction yet.</font>', MUTED:ToHex())
		warning.Text = "Members rank up from kills: enemies, and players of a rival faction."
	end
	for i, faction in ipairs(FactionConfig.Offered(openAt:GetAttribute("FactionId"))) do
		card(faction, i, key, joinedAt)
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
	openAt = nil
	Menus.Close("Faction")
end
closeButton.Activated:Connect(close)
leave.Activated:Connect(close)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local recruiter = prompt:FindFirstAncestorOfClass("Model")
	if prompt.Name == PROMPT_NAME and recruiter and CollectionService:HasTag(recruiter, FactionConfig.RecruiterTag) then
		openAt = recruiter
		setStatus("")
		title.Text = string.upper(recruiter:GetAttribute("ShopTitle") or recruiter.Name)
		render()
		list.CanvasPosition = Vector2.zero
		Menus.Open("Faction", close)
		gui.Enabled = true
		-- the full-screen close-up on the recruiter (E leaves)
		ShopFocus.Begin(recruiter, { ignoreGui = gui, onLeave = close, shift = CAMERA_SHIFT })
	end
end)

RunService.Heartbeat:Connect(function()
	if not openAt then
		return
	end
	ShopFocus.Step()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not openAt.Parent or (openAt:GetPivot().Position - root.Position).Magnitude > FactionConfig.RecruiterRange then
		close()
	end
end)
