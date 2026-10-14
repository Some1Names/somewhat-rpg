-- Smith menu: opens from a smith's prompt (a model tagged "Smith") and lists
-- the powers and weapons you own. For the one you pick it shows its reforge
-- level, the cost of the next level, and its two modifier slots (opened at
-- levels 3 and 7) with a reroll each. A reroll is paid when it's rolled and
-- shows the new roll beside the old one: keep the new, or keep the old. The
-- level and modifiers are the Reforge_<Set> attributes the server mirrors;
-- every action goes through the ReforgeAction remote (ReforgeServer), which
-- does all the checking. Closes when you walk away.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ReforgeConfig = require(ReplicatedStorage:WaitForChild("ReforgeConfig"))
local ReforgeRules = require(ReplicatedStorage:WaitForChild("ReforgeRules"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local remote = ReplicatedStorage:WaitForChild(ReforgeConfig.Remote)
local player = Players.LocalPlayer

local PANEL_WIDTH = 400
local PADDING = 14
local ROW_HEIGHT = 30
local MAX_LIST_HEIGHT = 120 -- past this the list of sets scrolls
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local GOLD = Color3.fromRGB(255, 205, 60)
local FORGE = Color3.fromRGB(255, 140, 60)
local DANGER = Color3.fromRGB(226, 75, 74)
local TIER_ORDER = { S = 1, A = 2, B = 3, C = 4 }

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

local function clear(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- "IridescentRequiem" -> "Iridescent Requiem"
local function displayName(setName)
	return (string.gsub(setName, "(%l)(%u)", "%1 %2"))
end

-- the sets the player owns, best tier first
local function ownedSets()
	local owned = {}
	local list = player:GetAttribute(SkillSetConfig.OwnedSetsAttribute) or ""
	for setName in string.gmatch(list, "[^,]+") do
		if SkillSetConfig.Sets[setName] then
			table.insert(owned, setName)
		end
	end
	table.sort(owned, function(a, b)
		local tierA = TIER_ORDER[SkillSetConfig.Sets[a].tier] or 99
		local tierB = TIER_ORDER[SkillSetConfig.Sets[b].tier] or 99
		if tierA ~= tierB then
			return tierA < tierB
		end
		return a < b
	end)
	return owned
end

local function stateOf(setName)
	return ReforgeRules.DecodeState(player:GetAttribute(ReforgeConfig.SetAttribute(setName)))
end

-- the materials the player carries, read when asked for
local bag = setmetatable({}, {
	__index = function(_, key)
		return player:GetAttribute(ReforgeConfig.MaterialAttribute(key)) or 0
	end,
})

local function describe(mod)
	local config = ReforgeConfig.Modifier(mod.id)
	local percent = string.format("%.1f%%", mod.value / 10)
	if config.kind == "damage" then
		return string.format("%s: +%s damage", config.name, percent)
	elseif config.kind == "cooldown" then
		return string.format("%s: -%s cooldown", config.name, percent)
	elseif config.kind == "status" then
		return string.format("%s: %s chance to apply %s", config.name, percent, config.status)
	end
	return string.format("%s: heal %s of damage dealt", config.name, percent)
end

local function costText(cost)
	return string.format("%d %s + %s", cost.amount, cost.material, formatYen(cost.yen))
end

local gui = make("ScreenGui", {
	Name = "ReforgeMenu",
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
make("UIStroke", { Parent = panel, Color = FORGE, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
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

-- header: title, the player's yen, close
local header = section(22)
label(header, { Text = "SMITH", Font = Enum.Font.GothamBold, TextSize = 16, Size = UDim2.fromScale(0.4, 1) })
local balance = label(header, {
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -30, 0, 0),
	Size = UDim2.new(0.6, -30, 1, 0),
})
-- Modal frees the mouse while the menu is open, even in shift lock
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

-- the sets you own, scrolling once there are more than fit
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
local listLayout = make("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	list.Size = UDim2.new(1, 0, 0, math.min(listLayout.AbsoluteContentSize.Y, MAX_LIST_HEIGHT))
end)

-- the picked set: level, slots, the reroll waiting to be kept or not
order += 1
local detail = make("Frame", {
	Parent = panel,
	LayoutOrder = order,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = detail, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

local status = label(section(14), { Text = "", TextSize = 11, TextColor3 = MUTED, Size = UDim2.fromScale(1, 1) })
local function setStatus(text, failed)
	status.Text = text
	status.TextColor3 = failed and DANGER or GOLD
end

local selected -- the set picked in the list
local candidate -- the reroll waiting for the picked set: { slot, old, new }
local render

-- one action to the server; returns whether it went through and any candidate
local function request(action, setName, extra)
	local ok, success, message, waiting = pcall(remote.InvokeServer, remote, action, setName, extra)
	if not ok then
		setStatus("Couldn't reach the smith", true)
		return false
	end
	if message and message ~= "" then
		setStatus(message, not success)
	end
	return success, waiting
end

local function pick(setName)
	selected = setName
	candidate = nil
	setStatus("")
	local _, waiting = request("pending", setName)
	candidate = waiting
	render()
end

-- a button in a row of the detail; `enabled` greys it out (the server still checks)
local function button(parent, text, enabled, onClick)
	local b = make("TextButton", {
		Parent = parent,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(110, 30),
		BackgroundColor3 = FORGE,
		BackgroundTransparency = enabled and 0 or 0.6,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = BACKGROUND,
		Text = text,
		AutoButtonColor = enabled,
	})
	b.Activated:Connect(function()
		if enabled then
			onClick()
		end
	end)
	return b
end

local function detailRow(height, order)
	return make("Frame", { Parent = detail, LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6 })
end

render = function()
	local yen = player:GetAttribute("Yen") or 0
	balance.Text = formatYen(yen)

	clear(list)
	local owned = ownedSets()
	if #owned == 0 then
		label(list, { Text = "You own nothing to reforge", TextSize = 12, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, ROW_HEIGHT) })
	end
	for index, setName in ipairs(owned) do
		local row = make("TextButton", {
			Parent = list,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = setName == selected and 0.2 or 0.6,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
		})
		label(row, { Text = displayName(setName), Font = Enum.Font.GothamBold, TextSize = 13, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.7, -10, 1, 0) })
		local level = stateOf(setName).level
		label(row, {
			Text = level > 0 and ("Lv " .. level) or "",
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = FORGE,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -10, 1, 0),
		})
		row.Activated:Connect(function()
			pick(setName)
		end)
	end

	clear(detail)
	if not selected or not table.find(owned, selected) then
		label(detail, { Text = "Pick a power or weapon", TextSize = 12, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 20) })
		return
	end
	local state = stateOf(selected)
	local waiting = candidate ~= nil

	-- the level, and the next one's cost
	local levelRow = detailRow(48, 1)
	label(levelRow, { Text = string.format("Level %d / %d", state.level, ReforgeConfig.MaxLevel), Font = Enum.Font.GothamBold, TextSize = 14, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -130, 0, 18) })
	local canLevel = ReforgeRules.PlanLevelUp(state, bag, yen)
	local costLine = state.level >= ReforgeConfig.MaxLevel and "Highest level" or costText(ReforgeConfig.LevelCosts[state.level + 1])
	label(levelRow, {
		Text = string.format("+%d%% damage   Next: %s", math.floor(state.level * ReforgeConfig.DamagePerLevel * 100 + 0.5), costLine),
		TextSize = 11,
		TextColor3 = (canLevel or state.level >= ReforgeConfig.MaxLevel) and MUTED or DANGER,
		Position = UDim2.fromOffset(10, 24),
		Size = UDim2.new(1, -130, 0, 16),
	})
	button(levelRow, "LEVEL UP", canLevel and not waiting, function()
		request("level", selected)
		render()
	end)

	-- the modifier slots
	local open = ReforgeRules.SlotsUnlocked(state.level)
	for slot = 1, #ReforgeConfig.SlotUnlockLevels do
		local row = detailRow(48, 1 + slot)
		local mod = state.mods[slot]
		local line
		if slot > open then
			line = string.format("Slot %d: locked until level %d", slot, ReforgeConfig.SlotUnlockLevels[slot])
		else
			line = string.format("Slot %d: %s", slot, mod and describe(mod) or "empty")
		end
		label(row, { Text = line, TextSize = 12, TextColor3 = slot > open and MUTED or TEXT, TextWrapped = true, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -130, 1, 0) })
		if slot <= open then
			local canReroll = ReforgeRules.PlanReroll(state, slot, bag, yen)
			local rerollCost = ReforgeConfig.RerollCosts[slot]
			local b = button(row, "REROLL", canReroll and not waiting, function()
				local ok, rolled = request("reroll", selected, slot)
				if ok then
					candidate = rolled
				end
				render()
			end)
			b.Position = UDim2.new(1, 0, 0.5, -8)
			label(row, { Text = costText(rerollCost), TextSize = 10, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 14), Size = UDim2.fromOffset(110, 12) })
			b.Size = UDim2.fromOffset(110, 26)
		end
	end

	-- a reroll waiting: the old roll beside the new one
	if candidate then
		local row = detailRow(84, 4)
		label(row, { Text = string.format("Slot %d reroll", candidate.slot), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = FORGE, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 16) })
		label(row, { Text = "Old: " .. (candidate.old and describe(candidate.old) or "empty"), TextSize = 11, TextColor3 = MUTED, Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 16) })
		label(row, { Text = "New: " .. describe(candidate.new), TextSize = 11, Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 16) })
		local function resolve(keep)
			request("resolve", selected, keep)
			candidate = nil
			render()
		end
		local keepNew = button(row, "KEEP NEW", true, function()
			resolve(true)
		end)
		keepNew.AnchorPoint = Vector2.new(1, 1)
		keepNew.Position = UDim2.new(1, -124, 1, -6)
		local keepOld = button(row, "KEEP OLD", true, function()
			resolve(false)
		end)
		keepOld.AnchorPoint = Vector2.new(1, 1)
		keepOld.Position = UDim2.new(1, -6, 1, -6)
	end
end

player.AttributeChanged:Connect(function()
	if gui.Enabled then
		render()
	end
end)

-- the smith whose menu is open, so walking away can close it
local openAt

local function close()
	gui.Enabled = false
	openAt = nil
end
closeButton.Activated:Connect(close)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local smith = prompt:FindFirstAncestorOfClass("Model")
	if smith and CollectionService:HasTag(smith, ReforgeConfig.Tag) then
		openAt = smith
		setStatus("")
		selected = nil
		candidate = nil
		render()
		list.CanvasPosition = Vector2.zero
		gui.Enabled = true
	end
end)

RunService.Heartbeat:Connect(function()
	if not openAt then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not openAt.Parent or (openAt:GetPivot().Position - root.Position).Magnitude > ReforgeConfig.Range then
		close()
	end
end)
