-- Left clicking a power briefcase in hand opens a small box above the skill
-- bar: "Use <Power>?" with USE POWER (the briefcase becomes your power, via
-- the PowerAction remote, see Powers) and CANCEL. If you already own that
-- power the server refuses and the box says so in red; a held power that
-- would be lost asks for one more click (CONFIRM). The box closes when the
-- briefcase is put away, used or gone. Combat is locked while it's in hand
-- (ActionLock).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local powerAction = ReplicatedStorage:WaitForChild("PowerAction")
local player = Players.LocalPlayer

local WIDTH = 300
local PADDING = 12
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
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

local gui = make("ScreenGui", {
	Name = "BriefcaseUse",
	ResetOnSpawn = false,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})
local box = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -260),
	Size = UDim2.fromOffset(WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
})
make("UIStroke", { Parent = box, Color = TEXT, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
make("UIPadding", {
	Parent = box,
	PaddingTop = UDim.new(0, PADDING),
	PaddingBottom = UDim.new(0, PADDING),
	PaddingLeft = UDim.new(0, PADDING),
	PaddingRight = UDim.new(0, PADDING),
})
make("UIListLayout", { Parent = box, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

local function label(order, props)
	props.Parent = box
	props.LayoutOrder = order
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.Highway
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextWrapped = true
	props.TextXAlignment = Enum.TextXAlignment.Left
	props.TextYAlignment = Enum.TextYAlignment.Top
	props.AutomaticSize = Enum.AutomaticSize.Y
	props.Size = UDim2.new(1, 0, 0, 0)
	return make("TextLabel", props)
end
local title = label(1, { Font = Enum.Font.Highway, TextSize = 15 })
local body = label(2, { TextSize = 12, TextColor3 = MUTED })
local errorText = label(3, { TextSize = 12, TextColor3 = DANGER, Visible = false })

local buttons = make("Frame", { Parent = box, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1 })
local function button(text, anchorX, filled)
	local b = make("TextButton", {
		Parent = buttons,
		AnchorPoint = Vector2.new(anchorX, 0),
		Position = UDim2.fromScale(anchorX, 0),
		Size = UDim2.new(0.5, -4, 1, 0),
		BackgroundColor3 = TEXT,
		BackgroundTransparency = filled and 0 or 1,
		Font = Enum.Font.Highway,
		TextSize = 13,
		TextColor3 = filled and BACKGROUND or TEXT,
		Text = text,
	})
	make("UIStroke", { Parent = b, Color = TEXT, Transparency = filled and 0.5 or 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	return b
end
local useButton = button("USE POWER", 0, true)
local cancelButton = button("CANCEL", 1, false)

local current -- the briefcase Tool the box is about
local confirming = false
local busy = false

local function powerName(setName)
	return (string.gsub(setName, "(%l)(%u)", "%1 %2"))
end

local function close()
	current = nil
	confirming = false
	gui.Enabled = false
end

local function open(tool)
	local setName = tool:GetAttribute(PowerConfig.BriefcaseAttribute)
	if not setName or not SkillSetConfig.Sets[setName] then
		return
	end
	current = tool
	confirming = false
	local placeholder = SkillSetConfig.Sets[setName].placeholder
	title.Text = placeholder and (powerName(setName) .. " isn't made yet") or ("Use " .. powerName(setName) .. "?")
	body.Text = placeholder and "This briefcase can only be sold to the Power Dealer." or "It becomes your power and the briefcase is used up."
	errorText.Visible = false
	useButton.Visible = not placeholder
	useButton.Text = "USE POWER"
	gui.Enabled = true
end

useButton.Activated:Connect(function()
	local tool = current
	local setName = tool and tool:GetAttribute(PowerConfig.BriefcaseAttribute)
	if busy or not setName then
		return
	end
	busy = true
	local ok, success, message, needsConfirm = pcall(powerAction.InvokeServer, powerAction, "use", { set = setName, confirm = confirming })
	busy = false
	if current ~= tool then
		return -- closed while waiting
	end
	if not ok then
		errorText.Text = "Couldn't reach the server"
		errorText.Visible = true
	elseif success then
		close()
	elseif needsConfirm then
		confirming = true
		body.Text = message or "Are you sure?"
		errorText.Visible = false
		useButton.Text = "CONFIRM"
	else
		confirming = false
		useButton.Text = "USE POWER"
		errorText.Text = message or "Couldn't do that"
		errorText.Visible = true
	end
end)
cancelButton.Activated:Connect(close)

-- every briefcase Tool the player gets: a left click while it's in hand opens the box
local watched = {}
local function watch(tool)
	if watched[tool] or not tool:IsA("Tool") or tool:GetAttribute(PowerConfig.BriefcaseAttribute) == nil then
		return
	end
	watched[tool] = true
	tool.Activated:Connect(function()
		open(tool)
	end)
	tool.Unequipped:Connect(function()
		if current == tool then
			close()
		end
	end)
	tool.AncestryChanged:Connect(function()
		if not tool:IsDescendantOf(game) then
			watched[tool] = nil
			if current == tool then
				close()
			end
		end
	end)
end

local function watchContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		watch(child)
	end
	container.ChildAdded:Connect(watch)
end
local function watchCharacter(character)
	watchContainer(character)
	watchContainer(player:WaitForChild("Backpack"))
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end
