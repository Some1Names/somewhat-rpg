-- The 3D printer's menu: opens from a prompt this script puts on everything
-- tagged "Printer" (a part or a model). Down the left the recipes (ones still
-- to learn are greyed); beside them the picked one: what it makes, the
-- materials it needs against what you hold, the yen and print time, and PRINT,
-- or for a recipe to learn, a button per way to learn it. Along the bottom your
-- print slots, each counting down, with COLLECT once done and CANCEL while it
-- runs. Every action goes through the CraftAction remote (CraftServer), which
-- does all the checking; its reply shows on the status line. Rebuilt when the
-- saved PrintJobs / RecipesKnown, yen or materials change. Closes with E, the
-- X, walking away, or another menu opening (Menus). Square, in the shops' glass.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CraftConfig = require(ReplicatedStorage:WaitForChild("CraftConfig"))
local DropConfig = require(ReplicatedStorage:WaitForChild("DropConfig"))
local FactionConfig = require(ReplicatedStorage:WaitForChild("FactionConfig"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local TalismanConfig = require(ReplicatedStorage:WaitForChild("TalismanConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local remote = ReplicatedStorage:WaitForChild(CraftConfig.Remote)
local player = Players.LocalPlayer

local PANEL_WIDTH = 760
local PANEL_HEIGHT = 480
local LIST_WIDTH = 250
local ROW_HEIGHT = 44
local JOBS_HEIGHT = 92 -- the print slots along the bottom
local PROMPT_DISTANCE = CraftConfig.Range - 2
local OPEN_GRACE = 0.3 -- seconds after opening before E closes (the prompt's own E press)
local Style = HudConfig.Style
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local LOCKED = Color3.fromRGB(110, 110, 120)
local GOLD = Color3.fromRGB(255, 205, 60)
local ACCENT = Color3.fromRGB(60, 224, 230) -- the printer's cyan
local DANGER = Color3.fromRGB(226, 75, 74)
local GOOD = Color3.fromRGB(90, 200, 120)

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
	props.Font = props.Font or Style.LabelFont
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

-- a square button filled in `color`
local function button(parent, text, color, props)
	props.Parent = parent
	props.Text = text
	props.Font = Style.TitleFont
	props.TextSize = props.TextSize or 15
	props.AutoButtonColor = true
	props.BorderSizePixel = 0
	props.BackgroundColor3 = color
	props.TextColor3 = props.TextColor3 or Color3.new(0, 0, 0)
	return make("TextButton", props)
end

local function edge(parent, transparency)
	make("UIStroke", { Parent = parent, Color = TEXT, Transparency = transparency or Style.EdgeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function clear(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function formatYen(amount)
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "¥" .. grouped
end

local function formatTime(seconds)
	seconds = math.max(math.ceil(seconds), 0)
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function now()
	return workspace:GetServerTimeNow() -- the server's os.time(), give or take, so countdowns match
end

local function held(key)
	return player:GetAttribute(DropConfig.Attribute(key)) or 0
end

local function materialName(key)
	local material = DropConfig.Materials[key]
	return material and material.display or key
end

-- what a recipe makes, in a line
local function outputText(recipe)
	if recipe.output.kind == "talisman" then
		local item = TalismanConfig.Get(recipe.output.key)
		return item and ("Talisman. " .. item.description) or "Talisman"
	end
	local rarities = {}
	for rarity in pairs(recipe.rarityWeights or {}) do
		table.insert(rarities, rarity)
	end
	table.sort(rarities)
	return string.format("%s gear, up to level %d. Rolls %s.", recipe.output.slot, recipe.maxLevel or 1, table.concat(rarities, " or "))
end

local function routeText(route)
	if route.kind == "buy" then
		return "Buy for " .. formatYen(route.yen)
	elseif route.kind == "drop" then
		return "Spend a " .. materialName(route.blueprint)
	elseif route.kind == "quest" then
		local _, quest = QuestConfig.parseQuestId(route.id)
		return "Finish the bounty " .. (quest and quest.title or route.id)
	end
	local rank = FactionConfig.Ranks[route.rank]
	local who = route.faction == "Any" and "any faction" or ((FactionConfig.Get(route.faction) or {}).name or route.faction)
	return string.format("Reach %s in %s", rank and rank.name or ("rank " .. route.rank), who)
end

local gui = make("ScreenGui", {
	Name = "PrinterMenu",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 30,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

-- the whole screen dimmed and Active, so a click anywhere is the menu's
local backdrop = make("Frame", {
	Parent = gui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.5,
	BorderSizePixel = 0,
	Active = true,
})
local panel = make("Frame", {
	Parent = backdrop,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
	BackgroundColor3 = Style.Glass,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
})
edge(panel)

label(panel, { Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(300, 30), Font = Style.TitleFont, Text = "3D PRINTER", TextSize = 26 })
local slotsLabel = label(panel, { Position = UDim2.fromOffset(20, 40), Size = UDim2.fromOffset(400, 16), Font = Style.MonoFont, TextSize = 12, TextColor3 = MUTED, Text = "" })
local yenLabel = label(panel, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -60, 0, 16),
	Size = UDim2.fromOffset(200, 24),
	Font = Style.MonoFont,
	TextSize = 16,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "",
})
local closeButton = button(panel, "X", TEXT, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(30, 30),
	BackgroundTransparency = 1,
	TextColor3 = TEXT,
	TextSize = 18,
})
edge(closeButton, 0.6)

local list = make("ScrollingFrame", {
	Parent = panel,
	Position = UDim2.fromOffset(20, 68),
	Size = UDim2.new(0, LIST_WIDTH, 1, -(68 + JOBS_HEIGHT + 30)),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
})
make("UIListLayout", { Parent = list, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })

local detail = make("Frame", {
	Parent = panel,
	Position = UDim2.fromOffset(20 + LIST_WIDTH + 20, 68),
	Size = UDim2.new(1, -(LIST_WIDTH + 60), 1, -(68 + JOBS_HEIGHT + 30)),
	BackgroundTransparency = 1,
})

local status = label(panel, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 20, 1, -(JOBS_HEIGHT + 6)),
	Size = UDim2.new(1, -40, 0, 18),
	TextSize = 14,
	Text = "",
})

local jobsStrip = make("Frame", {
	Parent = panel,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 20, 1, -12),
	Size = UDim2.new(1, -40, 0, JOBS_HEIGHT - 12),
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = jobsStrip, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) })

local selected = CraftConfig.Recipes[1].id
local busy = false
local openAt, openedAt
local countdowns = {} -- { label, finishAt } of the running prints, ticked while open

local function setStatus(text, failed)
	status.Text = text or ""
	status.TextColor3 = failed and DANGER or GOLD
end

local render

local function ask(...)
	if busy then
		return
	end
	busy = true
	local ok, ok2, message = pcall(remote.InvokeServer, remote, ...)
	busy = false
	if not ok then
		setStatus("The printer didn't answer", true)
	else
		setStatus(message or "", not ok2)
	end
	render()
end

local function knownText()
	return player:GetAttribute(CraftConfig.KnownAttribute)
end

local function renderList()
	clear(list)
	for index, recipe in ipairs(CraftConfig.Recipes) do
		local known = CraftConfig.IsKnown(knownText(), recipe.id)
		local picked = recipe.id == selected
		local row = make("TextButton", {
			Parent = list,
			LayoutOrder = index,
			Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
			BackgroundColor3 = picked and ACCENT or Color3.new(1, 1, 1),
			BackgroundTransparency = picked and 0.75 or 0.95,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
		})
		if picked then
			make("Frame", { Parent = row, Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = ACCENT, BorderSizePixel = 0 })
		end
		label(row, {
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -20, 0, 20),
			Font = Style.TitleFont,
			TextSize = 16,
			Text = string.upper(recipe.name),
			TextColor3 = known and TEXT or LOCKED,
		})
		label(row, {
			Position = UDim2.fromOffset(12, 23),
			Size = UDim2.new(1, -20, 0, 16),
			TextSize = 12,
			Text = (known and "" or "LOCKED  ·  ") .. recipe.tier .. "  ·  " .. (recipe.output.kind == "talisman" and "Talisman" or recipe.output.slot),
			TextColor3 = known and MUTED or LOCKED,
		})
		row.Activated:Connect(function()
			selected = recipe.id
			setStatus("")
			render()
		end)
	end
end

local function renderDetail()
	clear(detail)
	local recipe = CraftConfig.Get(selected)
	local known = CraftConfig.IsKnown(knownText(), recipe.id)
	label(detail, { Size = UDim2.new(1, 0, 0, 30), Font = Style.TitleFont, TextSize = 24, Text = string.upper(recipe.name) })
	label(detail, {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = MUTED,
		Text = outputText(recipe),
	})
	local y = 76
	label(detail, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 16), Font = Style.MonoFont, TextSize = 11, TextColor3 = MUTED, Text = "NEEDS" })
	y += 20
	for _, cost in ipairs(recipe.materials) do
		local have = held(cost.material)
		label(detail, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, -90, 0, 18), TextSize = 14, Text = materialName(cost.material) })
		label(detail, {
			Position = UDim2.new(1, -90, 0, y),
			Size = UDim2.fromOffset(90, 18),
			Font = Style.MonoFont,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = have >= cost.amount and GOOD or DANGER,
			Text = string.format("%d / %d", have, cost.amount),
		})
		y += 20
	end
	local yen = player:GetAttribute("Yen") or 0
	label(detail, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, -90, 0, 18), TextSize = 14, Text = "Yen" })
	label(detail, {
		Position = UDim2.new(1, -90, 0, y),
		Size = UDim2.fromOffset(90, 18),
		Font = Style.MonoFont,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = yen >= recipe.yen and GOOD or DANGER,
		Text = formatYen(recipe.yen),
	})
	y += 20
	label(detail, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, -90, 0, 18), TextSize = 14, Text = "Print time" })
	label(detail, {
		Position = UDim2.new(1, -90, 0, y),
		Size = UDim2.fromOffset(90, 18),
		Font = Style.MonoFont,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = formatTime(recipe.seconds),
	})
	y += 30

	if known then
		local affordable = CraftConfig.CanAfford(recipe, held, yen)
		local printButton = button(detail, "PRINT", affordable and ACCENT or LOCKED, { Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(160, 36), TextSize = 18 })
		printButton.Activated:Connect(function()
			ask("start", recipe.id)
		end)
		return
	end
	label(detail, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 16), Font = Style.MonoFont, TextSize = 11, TextColor3 = MUTED, Text = "TO LEARN" })
	y += 20
	if #(recipe.routes or {}) == 0 then
		label(detail, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = LOCKED, Text = "Given at events" })
	end
	for _, route in ipairs(recipe.routes or {}) do
		label(detail, { Position = UDim2.fromOffset(0, y + 4), Size = UDim2.new(1, -100, 0, 18), TextSize = 14, Text = routeText(route) })
		if route.kind ~= "quest" then
			local learn = button(detail, "LEARN", GOLD, { Position = UDim2.new(1, -90, 0, y), Size = UDim2.fromOffset(90, 26) })
			learn.Activated:Connect(function()
				ask("learn", recipe.id, route.kind)
			end)
		end
		y += 32
	end
end

local function renderJobs()
	clear(jobsStrip)
	table.clear(countdowns)
	local level = player:GetAttribute("Level") or 0
	local jobs = CraftConfig.ParseJobs(player:GetAttribute(CraftConfig.JobsAttribute))
	local slots = CraftConfig.JobSlots(level)
	local nextAt = CraftConfig.NextSlotLevel(level)
	slotsLabel.Text = string.format("PRINT SLOTS %d/%d", #jobs, slots) .. (nextAt and string.format("  ·  NEXT AT LV %d", nextAt) or "")
	for index = 1, #CraftConfig.JobSlotLevels do
		local card = make("Frame", {
			Parent = jobsStrip,
			Size = UDim2.new(1 / #CraftConfig.JobSlotLevels, -7, 1, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.95,
			BorderSizePixel = 0,
		})
		edge(card)
		local job = jobs[index]
		if not job then
			local open = index <= slots
			label(card, {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 13,
				TextColor3 = open and MUTED or LOCKED,
				Text = open and "EMPTY" or string.format("OPENS AT LV %d", CraftConfig.JobSlotLevels[index]),
			})
			continue
		end
		local recipe = CraftConfig.Get(job.recipe)
		label(card, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 20), Font = Style.TitleFont, TextSize = 16, Text = string.upper(recipe.name) })
		local timeLabel = label(card, { Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 16), Font = Style.MonoFont, TextSize = 13, TextColor3 = MUTED, Text = "" })
		local ready = CraftConfig.IsReady(job, now())
		if ready then
			timeLabel.Text = "READY"
			timeLabel.TextColor3 = GOOD
			local collect = button(card, "COLLECT", GOOD, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -8), Size = UDim2.new(1, -20, 0, 24) })
			collect.Activated:Connect(function()
				ask("collect", index)
			end)
		else
			table.insert(countdowns, { label = timeLabel, finishAt = job.finishAt })
			timeLabel.Text = formatTime(job.finishAt - now())
			local cancel = button(card, "CANCEL", DANGER, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 10, 1, -8),
				Size = UDim2.new(1, -20, 0, 24),
				BackgroundTransparency = 1,
				TextColor3 = DANGER,
			})
			edge(cancel, 0.4)
			cancel.Activated:Connect(function()
				ask("cancel", index)
			end)
		end
	end
end

function render()
	if not gui.Enabled then
		return
	end
	yenLabel.Text = formatYen(player:GetAttribute("Yen") or 0)
	renderList()
	renderDetail()
	renderJobs()
end

-- (only what the menu shows: other attributes tick all the time)
local MATERIAL_PREFIX = DropConfig.Attribute("")
player.AttributeChanged:Connect(function(name)
	if
		gui.Enabled
		and (
			name == "Yen"
			or name == "Level"
			or name == CraftConfig.JobsAttribute
			or name == CraftConfig.KnownAttribute
			or string.sub(name, 1, #MATERIAL_PREFIX) == MATERIAL_PREFIX
		)
	then
		render()
	end
end)

local function close()
	gui.Enabled = false
	openAt = nil
	Menus.Close("Printer")
end
closeButton.Activated:Connect(close)

local function open(printer)
	openAt = printer
	openedAt = os.clock()
	setStatus("")
	Menus.Open("Printer", close)
	gui.Enabled = true
	render()
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and openAt and input.KeyCode == Enum.KeyCode.E and os.clock() - openedAt > OPEN_GRACE then
		close()
	end
end)

-- the prompt on each printer (a part, or a model's primary or first part)
local function addPrompt(printer)
	local part = printer:IsA("BasePart") and printer or (printer:IsA("Model") and (printer.PrimaryPart or printer:FindFirstChildWhichIsA("BasePart", true)))
	if not part or part:FindFirstChild("PrinterPrompt") then
		return
	end
	make("ProximityPrompt", {
		Name = "PrinterPrompt",
		Parent = part,
		ActionText = "Print",
		ObjectText = "3D Printer",
		MaxActivationDistance = PROMPT_DISTANCE,
		RequiresLineOfSight = false,
	})
end
for _, printer in ipairs(CollectionService:GetTagged(CraftConfig.Tag)) do
	addPrompt(printer)
end
CollectionService:GetInstanceAddedSignal(CraftConfig.Tag):Connect(addPrompt)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name ~= "PrinterPrompt" then
		return
	end
	local printer = prompt.Parent
	while printer and not CollectionService:HasTag(printer, CraftConfig.Tag) do
		printer = printer.Parent
	end
	if printer then
		open(printer)
	end
end)

-- countdowns tick, a print that finishes turns to COLLECT, and walking away closes
local lastTick = 0
RunService.Heartbeat:Connect(function()
	if not openAt then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not openAt.Parent or (openAt:GetPivot().Position - root.Position).Magnitude > CraftConfig.Range then
		close()
		return
	end
	if os.clock() - lastTick < 0.25 then
		return
	end
	lastTick = os.clock()
	local time = now()
	for _, countdown in ipairs(countdowns) do
		if time >= countdown.finishAt then
			render()
			return
		end
		countdown.label.Text = formatTime(countdown.finishAt - time)
	end
end)
