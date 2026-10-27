-- The slot screen PLAY opens (TitleMenu): three character cards over the title shot. A
-- used slot shows its character in the look it wears (a small preview), its codename,
-- level, power and when it was last played, with CONTINUE and DELETE (which asks for the
-- codename first); an empty slot opens the Customizer. The cards slide up one after
-- another, and the one under the mouse lifts with an accent line sweeping across its top.
-- Everything goes through the SlotAction remote (see Customizer.Call), and the server
-- decides; this only shows the answer. Square everything; the accent is the hub's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HubRules = require(ReplicatedStorage:WaitForChild("HubRules"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local SlotConfig = require(ReplicatedStorage:WaitForChild("SlotConfig"))
local Customizer = require(script.Parent:WaitForChild("Customizer"))
local Hub = require(script.Parent:WaitForChild("Hub"))

local player = Players.LocalPlayer
local Theme = HudConfig.HubTheme
local make, label, button, tween = Customizer.Make, Customizer.Label, Customizer.Button, Customizer.Tween

local CARD_WIDTH = 270
local CARD_HEIGHT = 400
local CARD_GAP = 16
local HEADER = 76 -- the chip, the title and the rule above the cards
local PREVIEW_HEIGHT = 150
local LIFT = 8 -- px the card under the mouse rises
local ENTRANCE_RISE = 40 -- px a card slides up from
local ENTRANCE_STAGGER = 0.09 -- s between one card's entrance and the next
local STAGE_WIDTH = 3 * CARD_WIDTH + 2 * CARD_GAP
local STAGE_HEIGHT = HEADER + CARD_HEIGHT + 14 + 20 + 16 + 36 -- header, cards, status line, BACK
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

-- ¥12,400
local function money(amount)
	local digits = (tostring(math.floor(amount)):reverse():gsub("(%d%d%d)", "%1,")):reverse()
	return "¥" .. (digits:gsub("^,", ""))
end

-- a slot's colour is its held power's, as the hub's accent is (white with none)
local function powerAccent(power)
	local set = SkillSetConfig.Sets[power]
	local color = set and set.color or Theme.NoPower
	local r, g, b = HubRules.Ink(color.R, color.G, color.B)
	return Color3.new(r, g, b)
end

-- Opens the slot screen. onEntered() once a character is chosen or made and the player
-- let in (the screen has hidden itself); onBack() when BACK closes it.
function SlotMenu.Open(onEntered, onBack)
	local busy = false
	local accent = Hub.InkAccent()
	local parts = ReplicatedStorage:FindFirstChild("CharacterParts")

	local gui = make("ScreenGui", {
		Name = "SlotMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 51,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local root = Customizer.Backdrop(gui, 0.35)

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

	label(stage, {
		Text = string.format('[ <font color="#%s">CHARACTER SLOTS</font> ]', accent:ToHex()),
		RichText = true,
		Font = Theme.MonoFont,
		TextSize = 14,
		Size = UDim2.fromOffset(STAGE_WIDTH, 16),
	})
	label(stage, {
		Text = "CHOOSE YOUR CHARACTER",
		Font = Theme.TitleFont,
		TextSize = 40,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.fromOffset(STAGE_WIDTH, 44),
	})
	make("Frame", {
		Parent = stage,
		Position = UDim2.fromOffset(0, HEADER - 8),
		Size = UDim2.fromOffset(STAGE_WIDTH, 1),
		BackgroundColor3 = Theme.Muted,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
	})
	make("Frame", {
		Parent = stage,
		Position = UDim2.fromOffset(0, HEADER - 8),
		Size = UDim2.fromOffset(120, 2),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	})

	local cards = make("Frame", {
		Parent = stage,
		Position = UDim2.fromOffset(0, HEADER),
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
		Position = UDim2.fromOffset(0, HEADER + CARD_HEIGHT + 14),
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

	-- the card under the mouse lifts. Polled, because a card's buttons take the mouse
	-- from the card itself (its MouseEnter/Leave would flicker).
	local entries = {} -- { slotFrame, card, sweep, stroke, hover }
	local hoverWatch = RunService.RenderStepped:Connect(function()
		if not gui.Enabled then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		for _, entry in ipairs(entries) do
			local position, size = entry.slotFrame.AbsolutePosition, entry.slotFrame.AbsoluteSize
			local over = mouse.X >= position.X and mouse.X <= position.X + size.X and mouse.Y >= position.Y and mouse.Y <= position.Y + size.Y
			if over ~= entry.hover then
				entry.hover = over
				tween(entry.card, 0.2, { Position = over and UDim2.fromOffset(0, -LIFT) or UDim2.new() })
				tween(entry.sweep, 0.25, { Size = UDim2.new(over and 1 or 0, 0, 0, 3) })
				tween(entry.stroke, 0.2, { Color = over and entry.accent or Theme.Edge, Transparency = over and 0.2 or 0.6 })
			end
		end
	end)
	gui.Destroying:Once(function()
		hoverWatch:Disconnect()
		if viewportWatch then
			viewportWatch:Disconnect()
		end
	end)

	local render -- (slots), below

	local function clearCards()
		entries = {}
		for _, child in ipairs(cards:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function refresh()
		status.Text = ""
		clearCards()
		label(cards, { Text = "LOADING...", Font = Theme.MonoFont, TextSize = 14, TextColor3 = Theme.Muted, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
		local result = Customizer.Call("List")
		if not gui.Parent then
			return -- BACK was pressed while it loaded
		end
		if not result.ok then
			clearCards()
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

	-- a card's frame: the slot (which the list lays out), the card in it (which moves), a
	-- line along its top and the big faint number behind everything, both in `color` (the
	-- slot's power colour)
	local function cardFrame(order, color)
		local slotFrame = make("Frame", { Parent = cards, LayoutOrder = order, Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT), BackgroundTransparency = 1 })
		local card = make("Frame", {
			Parent = slotFrame,
			Position = UDim2.fromOffset(0, ENTRANCE_RISE),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Nav,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
		})
		local stroke = make("UIStroke", { Parent = card, Color = Theme.Edge, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		label(card, {
			Text = string.format("%02d", order),
			Font = Theme.TitleFont,
			TextSize = 150,
			TextColor3 = color,
			TextTransparency = 0.86,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -4),
			Size = UDim2.fromOffset(CARD_WIDTH, 150),
		})
		make("Frame", { Parent = card, Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = color, BackgroundTransparency = 0.45, BorderSizePixel = 0 })
		local sweep = make("Frame", { Parent = card, Size = UDim2.fromOffset(0, 3), BackgroundColor3 = color, BorderSizePixel = 0 })
		local content = make("Frame", { Parent = card, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
		make("UIPadding", { Parent = content, PaddingTop = UDim.new(0, 20), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingBottom = UDim.new(0, 20) })
		label(content, { Text = string.format("%02d", order), Font = Theme.MonoFont, TextSize = 12, TextColor3 = Theme.Muted, Size = UDim2.new(1, 0, 0, 14) })
		local entry = { slotFrame = slotFrame, card = card, sweep = sweep, stroke = stroke, accent = color, hover = false }
		table.insert(entries, entry)
		-- slides up after the cards before it, the accent line flashing across as it lands
		task.delay((order - 1) * ENTRANCE_STAGGER, function()
			if not card.Parent then
				return
			end
			tween(card, 0.5, { Position = UDim2.new() })
			tween(sweep, 0.35, { Size = UDim2.new(1, 0, 0, 3) }).Completed:Connect(function()
				if card.Parent and not entry.hover then
					tween(sweep, 0.35, { Size = UDim2.new(0, 0, 0, 3) })
				end
			end)
		end)
		return content
	end

	function render(slots)
		clearCards()
		for slot = 1, SlotConfig.SlotCount do
			local entry = type(slots) == "table" and slots[slot] or nil
			local used = type(entry) == "table"
			local color = used and powerAccent(entry.power) or accent
			local content = cardFrame(slot, color)
			if used then
				-- the character, dressed in the look this slot wears
				local previewHolder = make("Frame", { Parent = content, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, PREVIEW_HEIGHT), BackgroundTransparency = 1 })
				local model = Customizer.BuildPreview(previewHolder, 17.5, color)
				if model then
					Customizer.Dress(model, SlotConfig.ParseLook(entry.look), parts)
				end
				label(content, { Text = string.upper(entry.name), Font = Theme.TitleFont, TextSize = 26, Position = UDim2.fromOffset(0, 176), Size = UDim2.new(1, 0, 0, 30), TextTruncate = Enum.TextTruncate.AtEnd })
				label(content, {
					Text = string.format('<font color="#%s">LV %d</font>  ·  %s', color:ToHex(), entry.level, money(entry.yen or 0)),
					RichText = true,
					Font = Theme.MonoFont,
					TextSize = 14,
					Position = UDim2.fromOffset(0, 208),
					Size = UDim2.new(1, 0, 0, 18),
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
				label(content, {
					Text = entry.power ~= "" and string.upper((SkillSetConfig.Sets[entry.power] or {}).tool or entry.power) or "NO POWER",
					Font = Theme.MonoFont,
					TextSize = 13,
					TextColor3 = entry.power ~= "" and color or Theme.Muted,
					Position = UDim2.fromOffset(0, 228),
					Size = UDim2.new(1, 0, 0, 16),
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
				label(content, { Text = "PLAYED " .. string.upper(ago(entry.playedAt)), Font = Theme.MonoFont, TextSize = 12, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(0, 246), Size = UDim2.new(1, 0, 0, 16) })
				local bottom = make("Frame", { Parent = content, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 84), BackgroundTransparency = 1 })
				button(bottom, { Text = "CONTINUE", Filled = true, Accent = color, Size = UDim2.new(1, 0, 0, 42) }, function()
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
				label(content, { Text = "EMPTY SLOT", Font = Theme.MonoFont, TextSize = 12, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 16) })
				label(content, { Text = "+", Font = Theme.TitleFont, TextSize = 96, TextColor3 = accent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(120, 110), TextXAlignment = Enum.TextXAlignment.Center })
				label(content, { Text = "NEW CHARACTER", Font = Theme.TitleFont, TextSize = 20, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center })
				-- the whole card is the button
				local create = make("TextButton", { Parent = content, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 })
				create.Activated:Connect(function()
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
			end
		end
	end

	refresh()
end

return SlotMenu
