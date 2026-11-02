-- Two small pieces the full-screen shop-like menus (the shops, the smith, the recruiter, the gacha)
-- share, so none of them needs a leave button or an error line in its own panel:
--   MenuFooter.Leave(gui, onLeave, position?): the small `E LEAVE` key hint, bottom left on the same
--     baseline and look as the key hints line (KeyHints, which sits bottom right; the XP bar and level
--     sit on it too, hidden while a close-up is on). A click on it leaves too; ShopFocus makes E leave;
--   MenuFooter.Toast(gui): returns show(text, failed), which puts a line top centre under the top
--     bar (gold, or red when it failed) that fades after a few seconds; show("") clears it.
local HudConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("HudConfig"))

local TweenService = game:GetService("TweenService")

local Style = HudConfig.Style
local TEXT = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 60)
local DANGER = Color3.fromRGB(226, 75, 74)
local SHOWN = 3.5 -- seconds a toast stays before it fades

local MenuFooter = {}

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

function MenuFooter.Leave(gui, onLeave, position)
	local hint = make("TextButton", {
		Name = "LeaveHint",
		Parent = gui,
		AnchorPoint = Vector2.new(0, 1),
		Position = position or UDim2.new(0, HudConfig.EdgeMargin, 1, -HudConfig.EdgeMargin),
		Size = UDim2.fromOffset(0, HudConfig.HintsHeight),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 20,
	})
	make("UIListLayout", { Parent = hint, FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6) })
	local key = make("TextLabel", {
		Parent = hint,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(15, 15),
		BackgroundColor3 = Style.ChipBack,
		BackgroundTransparency = Style.ChipBackTransparency,
		Font = Style.MonoFont,
		Text = "E",
		TextSize = 9,
		TextColor3 = TEXT,
		ZIndex = 20,
	})
	make("UIStroke", { Parent = key, Color = TEXT, Transparency = Style.ChipEdgeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	make("TextLabel", {
		Parent = hint,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 15),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Style.LabelFont,
		Text = "LEAVE",
		TextSize = 11,
		TextColor3 = TEXT,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.6,
		ZIndex = 20,
	})
	hint.Activated:Connect(onLeave)
	return hint
end

function MenuFooter.Toast(gui)
	local line = make("TextLabel", {
		Name = "Toast",
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Style.TitleFont,
		Text = "",
		TextSize = 20,
		TextColor3 = GOLD,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 1,
		ZIndex = 20,
	})
	local token = 0
	return function(text, failed)
		token += 1
		local mine = token
		if text == nil or text == "" then
			line.Text = ""
			line.TextTransparency = 1
			line.TextStrokeTransparency = 1
			return
		end
		line.Text = text
		line.TextColor3 = failed and DANGER or GOLD
		line.TextTransparency = 0
		line.TextStrokeTransparency = 0.5
		task.delay(SHOWN, function()
			if token == mine then
				TweenService:Create(line, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end)
	end
end

return MenuFooter
