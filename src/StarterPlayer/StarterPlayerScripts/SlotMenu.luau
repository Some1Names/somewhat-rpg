-- The slot screen PLAY opens (TitleMenu): three character cards over the title shot. A
-- used slot shows its name, level, power and when it was last played, with CONTINUE and
-- DELETE (which asks for the character's name first); an empty slot opens the
-- Customizer. Everything goes through the SlotAction remote (see Customizer.Call), and
-- the server decides; this only shows the answer. Square everything; the accent is the
-- hub's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local SlotConfig = require(ReplicatedStorage:WaitForChild("SlotConfig"))
local Customizer = require(script.Parent:WaitForChild("Customizer"))

local player = Players.LocalPlayer
local Theme = HudConfig.HubTheme
local make, label, button = Customizer.Make, Customizer.Label, Customizer.Button

local CARD_WIDTH = 270
local CARD_HEIGHT = 380
local CARD_GAP = 16
local STAGE_WIDTH = 3 * CARD_WIDTH + 2 * CARD_GAP
local STAGE_HEIGHT = 60 + CARD_HEIGHT + 14 + 20 + 16 + 36 -- title, cards, status line, BACK
local ERROR_COLOR = Color3.fromRGB(235, 90, 90)

local SlotMenu = {}

-- "just now", "5m ago", "3h ago", "2d ago"
local function ago(time)
	local seconds = os.time() - time
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return math.floor(seconds / 60) .. "m ago"
	elseif seconds < 86400 then
		return math.floor(seconds / 3600) .. "h ago"
	end
	return math.floor(seconds / 86400) .. "d ago"
end

-- Opens the slot screen. onEntered() once a character is chosen or made and the player
-- let in (the screen has hidden itself); onBack() when BACK closes it.
function SlotMenu.Open(onEntered, onBack)
	local busy = false

	local gui = make("ScreenGui", {
		Name = "SlotMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 51,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local root = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Nav, BackgroundTransparency = 0.35, BorderSizePixel = 0 })

	-- everything but the delete box sits in one fixed-size stage, shrunk to fit a narrow screen
	local stage = make("Frame", {
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(STAGE_WIDTH, STAGE_HEIGHT),
		BackgroundTransparency = 1,
	})
	local fit = make("UIScale", { Parent = stage })
	local function updateFit()
		local camera = workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			fit.Scale = math.min(1, size.X / (STAGE_WIDTH + 40), size.Y / (STAGE_HEIGHT + 40))
		end
	end
	updateFit()
	local viewportWatch = workspace.CurrentCamera and workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateFit)
	gui.Destroying:Once(function()
		if viewportWatch then
			viewportWatch:Disconnect()
		end
	end)

	label(stage, {
		Text = "CHOOSE YOUR CHARACTER",
		Font = Theme.TitleFont,
		TextSize = 34,
		Size = UDim2.fromOffset(STAGE_WIDTH, 40),
	})

	local cards = make("Frame", {
		Parent = stage,
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.fromOffset(STAGE_WIDTH, CARD_HEIGHT),
		BackgroundTransparency = 1,
	})
	make("UIListLayout", {
		Parent = cards,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, CARD_GAP),
	})

	local status = label(stage, {
		Position = UDim2.fromOffset(0, 60 + CARD_HEIGHT + 14),
		Size = UDim2.fromOffset(STAGE_WIDTH, 20),
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = ERROR_COLOR,
	})

	button(stage, { Text = "BACK", TextSize = 16, Position = UDim2.fromOffset(STAGE_WIDTH / 2 - 55, STAGE_HEIGHT - 36), Size = UDim2.fromOffset(110, 36) }, function()
		if busy then
			return
		end
		gui:Destroy()
		onBack()
	end)

	local render -- (slots), below

	local function refresh()
		status.Text = ""
		for _, child in ipairs(cards:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		label(cards, { Text = "LOADING...", Font = Theme.MonoFont, TextSize = 14, TextColor3 = Theme.Muted, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
		local result = Customizer.Call("List")
		if not gui.Parent then
			return -- BACK was pressed while it loaded
		end
		if not result.ok then
			for _, child in ipairs(cards:GetChildren()) do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			status.Text = Customizer.Reason(result.reason)
			local retry = button(cards, { Text = "RETRY", Filled = true, Size = UDim2.fromOffset(160, 44) }, refresh)
			retry.AnchorPoint = Vector2.new(0.5, 0.5)
			retry.Position = UDim2.fromScale(0.5, 0.5)
			return
		end
		render(result.slots)
	end

	-- the answer to Continue: in, or why not
	local function enterWith(result)
		if result.ok then
			gui.Enabled = false
			onEntered()
			gui:Destroy()
		else
			status.Text = Customizer.Reason(result.reason)
		end
	end

	local function askDelete(slot, entry)
		local overlay = make("Frame", { Parent = root, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, BorderSizePixel = 0, Active = true, ZIndex = 5 })
		local box = make("Frame", {
			Parent = overlay,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(420, 220),
			BackgroundColor3 = Theme.Nav,
			BorderSizePixel = 0,
			ZIndex = 6,
		})
		make("UIStroke", { Parent = box, Color = Theme.Edge, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		make("UIPadding", { Parent = box, PaddingTop = UDim.new(0, 18), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingBottom = UDim.new(0, 18) })
		label(box, { Text = "DELETE " .. string.upper(entry.name), Font = Theme.TitleFont, TextSize = 24, Size = UDim2.new(1, 0, 0, 30), ZIndex = 6 })
		label(box, { Text = "This can't be undone. Type the codename to confirm.", TextSize = 14, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 18), ZIndex = 6 })
		local typed = make("TextBox", {
			Parent = box,
			Position = UDim2.fromOffset(0, 66),
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = Theme.Nav,
			BorderSizePixel = 0,
			Font = Theme.LabelFont,
			TextSize = 18,
			TextColor3 = Theme.NavText,
			PlaceholderText = entry.name,
			PlaceholderColor3 = Theme.Muted,
			Text = "",
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
		})
		make("UIStroke", { Parent = typed, Color = Theme.Edge, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		make("UIPadding", { Parent = typed, PaddingLeft = UDim.new(0, 10) })
		local failure = label(box, { Position = UDim2.fromOffset(0, 106), Size = UDim2.new(1, 0, 0, 16), Text = "", TextSize = 13, TextColor3 = ERROR_COLOR, ZIndex = 6 })
		local row = make("Frame", { Parent = box, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, ZIndex = 6 })
		local confirm = button(row, { Text = "DELETE", Size = UDim2.new(0.5, -4, 1, 0), ZIndex = 6 }, function()
			if busy then
				return
			end
			busy = true
			local result = Customizer.Call("Delete", slot, typed.Text)
			busy = false
			if result.ok then
				overlay:Destroy()
				render(result.slots)
			else
				failure.Text = Customizer.Reason(result.reason)
			end
		end)
		confirm.Active = false
		confirm.TextTransparency = 0.6
		typed:GetPropertyChangedSignal("Text"):Connect(function()
			local matches = typed.Text:match("^%s*(.-)%s*$"):lower() == entry.name:lower()
			confirm.Active = matches
			confirm.TextTransparency = matches and 0 or 0.6
			confirm.BackgroundColor3 = matches and ERROR_COLOR or Theme.Nav
		end)
		button(row, { Text = "CANCEL", Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), ZIndex = 6 }, function()
			overlay:Destroy()
		end)
	end

	local function cardFrame(order)
		local card = make("Frame", {
			Parent = cards,
			LayoutOrder = order,
			Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
			BackgroundColor3 = Theme.Nav,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
		})
		make("UIStroke", { Parent = card, Color = Theme.Edge, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		make("UIPadding", { Parent = card, PaddingTop = UDim.new(0, 20), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingBottom = UDim.new(0, 20) })
		label(card, { Text = string.format("%02d", order), Font = Theme.MonoFont, TextSize = 12, TextColor3 = Theme.Muted, Size = UDim2.new(1, 0, 0, 14) })
		return card
	end

	function render(slots)
		for _, child in ipairs(cards:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for slot = 1, SlotConfig.SlotCount do
			local entry = type(slots) == "table" and slots[slot] or nil
			local card = cardFrame(slot)
			if type(entry) == "table" then
				label(card, { Text = string.upper(entry.name), Font = Theme.TitleFont, TextSize = 28, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 34), TextTruncate = Enum.TextTruncate.AtEnd })
				label(card, { Text = "LEVEL " .. entry.level, Font = Theme.MonoFont, TextSize = 14, Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 18) })
				label(card, { Text = entry.power ~= "" and string.upper(entry.power) or "NO POWER", Font = Theme.MonoFont, TextSize = 14, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(0, 114), Size = UDim2.new(1, 0, 0, 18) })
				label(card, { Text = "PLAYED " .. string.upper(ago(entry.playedAt)), Font = Theme.MonoFont, TextSize = 12, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(0, 138), Size = UDim2.new(1, 0, 0, 16) })
				local bottom = make("Frame", { Parent = card, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 92), BackgroundTransparency = 1 })
				button(bottom, { Text = "CONTINUE", Filled = true, Size = UDim2.new(1, 0, 0, 42) }, function()
					if busy then
						return
					end
					busy = true
					status.Text = ""
					local result = Customizer.Call("Select", slot)
					busy = false
					enterWith(result)
				end)
				button(bottom, { Text = "DELETE", TextSize = 15, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 34) }, function()
					if not busy then
						askDelete(slot, entry)
					end
				end)
			else
				local create = button(card, { Text = "+", TextSize = 64, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40) }, function()
					if busy then
						return
					end
					gui.Enabled = false
					Customizer.Open(slot, function(entered)
						if entered then
							onEntered()
							gui:Destroy()
						else
							gui.Enabled = true
						end
					end)
				end)
				create.BackgroundTransparency = 0.6
				label(card, { Text = "NEW CHARACTER", Font = Theme.TitleFont, TextSize = 18, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2 })
			end
		end
	end

	refresh()
end

return SlotMenu
