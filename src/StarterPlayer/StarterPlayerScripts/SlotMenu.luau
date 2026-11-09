-- The slot screen PLAY opens (TitleMenu): three character cards over the title shot. A used
-- slot shows its character from the head to about the waist across the top (dressed in the
-- look it wears, fading out below), its codename, level, yen, power and when it was last
-- played; pressing the card continues, and a three-dot menu in its corner offers RECUSTOMIZE
-- (the customizer, on this character), RANDOMIZE (the customizer, starting from a random look)
-- and DELETE (which asks for the codename first). An empty slot opens the Customizer. A card
-- takes its colour from the power its character holds. The cards slide up one after another,
-- and the one under the mouse lifts, with an accent line sweeping across its top and corner
-- brackets lighting up. BACK is plain text at the bottom left. Everything goes through the
-- SlotAction remote (see Customizer.Call), and the server decides; this only shows the answer.
-- Square everything; the accent is the hub's.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HubRules = require(ReplicatedStorage:WaitForChild("HubRules"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local SlotConfig = require(ReplicatedStorage:WaitForChild("SlotConfig"))
local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))
local Customizer = require(script.Parent:WaitForChild("Customizer"))
local FirstSetup = require(script.Parent:WaitForChild("FirstSetup"))
local Hub = require(script.Parent:WaitForChild("Hub"))

local player = Players.LocalPlayer
local Theme = HudConfig.HubTheme
local make, label, button, tween = Customizer.Make, Customizer.Label, Customizer.Button, Customizer.Tween

local CARD_WIDTH = 316
local CARD_HEIGHT = 500
local CARD_GAP = 18
local HEADER = 76 -- the chip, the title and the rule above the cards
local CARDS_TOP = HEADER + 22 -- the cards start this far down: a gap under the header
local PREVIEW_HEIGHT = 350 -- the character's top half across the top of a used card, fading out below
local LIFT = 8 -- px the card under the mouse rises
local ENTRANCE_RISE = 40 -- px a card slides up from
local ENTRANCE_STAGGER = 0.09 -- s between one card's entrance and the next
local STAGE_WIDTH = 3 * CARD_WIDTH + 2 * CARD_GAP
local STAGE_HEIGHT = CARDS_TOP + CARD_HEIGHT + 14 + 20 -- header, gap, cards, status line
local ERROR_COLOR = Color3.fromRGB(235, 90, 90)

-- where a used card's text sits (the content is padded 20px, so these are card y minus 20)
local NAME_Y = PREVIEW_HEIGHT - 48
local STAT_Y = NAME_Y + 52
local CHIP_Y = NAME_Y + 110

local SlotMenu = {}

local setupShown = false -- the quick setup is offered once a session

-- no character in any slot yet
local function allEmpty(slots)
	for slot = 1, SlotConfig.SlotCount do
		if type(slots) == "table" and type(slots[slot]) == "table" then
			return false
		end
	end
	return true
end

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

-- the colour to write on a fill of `color`
local function onColor(color)
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B > 0.4 and Theme.Nav or Color3.new(1, 1, 1)
end

-- where the mouse is, in the same pixels as AbsolutePosition: those count from under Roblox's band
-- (even on a screen that ignores the gui inset), the mouse's location from the very top
local function mouseAt()
	return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
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

	-- everything but BACK and the delete box sits in one fixed-size stage, shrunk to fit a
	-- narrow screen
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
			fit.Scale = math.min(1, size.X / (STAGE_WIDTH + 40), size.Y / (STAGE_HEIGHT + 120))
		end
	end
	updateFit()
	local viewportWatch = workspace.CurrentCamera and workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateFit)

	-- the chip, the title and the rule: hidden while the first-time setup shows
	local header = make("Frame", { Parent = stage, Size = UDim2.fromOffset(STAGE_WIDTH, HEADER), BackgroundTransparency = 1 })
	label(header, {
		Text = string.format('[ <font color="#%s">CHARACTER SLOTS</font> ]', accent:ToHex()),
		RichText = true,
		Font = Theme.MonoFont,
		TextSize = 14,
		Size = UDim2.fromOffset(STAGE_WIDTH, 16),
	})
	label(header, {
		Text = "CHOOSE YOUR CHARACTER",
		Font = Theme.TitleFont,
		TextSize = 40,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.fromOffset(STAGE_WIDTH, 44),
	})
	make("Frame", {
		Parent = header,
		Position = UDim2.fromOffset(0, HEADER - 8),
		Size = UDim2.fromOffset(STAGE_WIDTH, 1),
		BackgroundColor3 = Theme.Muted,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
	})
	make("Frame", {
		Parent = header,
		Position = UDim2.fromOffset(0, HEADER - 8),
		Size = UDim2.fromOffset(120, 2),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	})

	local cards = make("Frame", {
		Parent = stage,
		Position = UDim2.fromOffset(0, CARDS_TOP),
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
		Position = UDim2.fromOffset(0, CARDS_TOP + CARD_HEIGHT + 14),
		Size = UDim2.fromOffset(STAGE_WIDTH, 20),
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = ERROR_COLOR,
	})

	-- BACK: plain text, bottom left, no box or outline; it lights up and nudges on hover
	local back = make("TextButton", {
		Parent = root,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 48, 1, -40),
		Size = UDim2.fromOffset(120, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.TitleFont,
		TextSize = 22,
		Text = "< BACK",
		TextColor3 = Theme.NavText,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
	})
	back.MouseEnter:Connect(function()
		tween(back, 0.15, { TextColor3 = accent, Position = UDim2.new(0, 42, 1, -40) })
	end)
	back.MouseLeave:Connect(function()
		tween(back, 0.15, { TextColor3 = Theme.NavText, Position = UDim2.new(0, 48, 1, -40) })
	end)
	back.Activated:Connect(function()
		if busy then
			return
		end
		gui:Destroy()
		onBack()
	end)

	-- the card under the mouse lifts. Polled, because a card's buttons take the mouse
	-- from the card itself (its MouseEnter/Leave would flicker).
	local entries = {} -- { slotFrame, card, sweep, stroke, accent, brackets, hint, hover }
	local hoverWatch = RunService.RenderStepped:Connect(function()
		if not gui.Enabled then
			return
		end
		local mouse = mouseAt()
		for _, entry in ipairs(entries) do
			local position, size = entry.slotFrame.AbsolutePosition, entry.slotFrame.AbsoluteSize
			local over = mouse.X >= position.X and mouse.X <= position.X + size.X and mouse.Y >= position.Y and mouse.Y <= position.Y + size.Y
			if over ~= entry.hover then
				entry.hover = over
				tween(entry.card, 0.2, { Position = over and UDim2.fromOffset(0, -LIFT) or UDim2.new() })
				tween(entry.sweep, 0.25, { Size = UDim2.new(over and 1 or 0, 0, 0, 3) })
				tween(entry.stroke, 0.2, { Color = over and entry.accent or Theme.Edge, Transparency = over and 0.2 or 0.6 })
				for _, bracket in ipairs(entry.brackets) do
					tween(bracket, 0.2, { BackgroundTransparency = over and 0 or 1 })
				end
				if entry.hint then
					tween(entry.hint, 0.2, { TextColor3 = over and entry.accent or Theme.Muted })
				end
			end
		end
	end)

	-- the open three-dot menu, if any: a click outside it closes it
	local openMenu -- the menu Frame
	local menuClosedAt = 0
	local function closeMenu()
		if openMenu then
			openMenu:Destroy()
			openMenu = nil
			menuClosedAt = os.clock()
		end
	end
	local clickAway = UserInputService.InputBegan:Connect(function(input)
		if openMenu and input.UserInputType == Enum.UserInputType.MouseButton1 then
			local mouse = mouseAt()
			local position, size = openMenu.AbsolutePosition, openMenu.AbsoluteSize
			if mouse.X < position.X or mouse.X > position.X + size.X or mouse.Y < position.Y or mouse.Y > position.Y + size.Y then
				closeMenu()
			end
		end
	end)

	gui.Destroying:Once(function()
		hoverWatch:Disconnect()
		clickAway:Disconnect()
		if viewportWatch then
			viewportWatch:Disconnect()
		end
	end)

	local render -- (slots), below

	local function clearCards()
		closeMenu()
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
		-- the first time ever (no character, no setting touched): the quick setup, then the slots
		if not setupShown and allEmpty(result.slots) and (player:GetAttribute(Preferences.Attribute) or "") == "" then
			clearCards()
			header.Visible = false
			local setup = make("Frame", {
				Parent = stage,
				Position = UDim2.fromOffset(0, CARDS_TOP - HEADER / 2),
				Size = UDim2.fromOffset(STAGE_WIDTH, CARD_HEIGHT),
				BackgroundTransparency = 1,
			})
			FirstSetup.Build(setup, accent, function()
				setupShown = true
				header.Visible = true
				setup:Destroy()
				render(result.slots)
			end)
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

	-- the customizer on an existing character; the list is read again when it saves
	local function customize(slot, entry, random)
		gui.Enabled = false
		Customizer.Open(slot, function(saved)
			gui.Enabled = true
			if saved then
				refresh()
			end
		end, { name = entry.name, lookText = entry.look, random = random })
	end

	-- the three-dot menu under a card's corner button
	local function showMenu(cardEntry, slot, entry)
		closeMenu()
		local menu = make("Frame", {
			Parent = cardEntry.card,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 50),
			Size = UDim2.fromOffset(200, 116),
			BackgroundColor3 = Theme.Nav,
			BorderSizePixel = 0,
			ZIndex = 8,
		})
		make("UIStroke", { Parent = menu, Color = cardEntry.accent, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		make("UIPadding", { Parent = menu, PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })
		make("UIListLayout", { Parent = menu, SortOrder = Enum.SortOrder.LayoutOrder })
		local options = {
			{ "RECUSTOMIZE", function() customize(slot, entry, false) end },
			{ "RANDOMIZE", function() customize(slot, entry, true) end },
			{ "DELETE", function() askDelete(slot, entry) end, true },
		}
		for order, option in ipairs(options) do
			local row = make("TextButton", {
				Parent = menu,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = Theme.TitleFont,
				TextSize = 16,
				Text = "  " .. option[1],
				TextColor3 = option[3] and ERROR_COLOR or Theme.NavText,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				ZIndex = 9,
			})
			row.MouseEnter:Connect(function()
				tween(row, 0.1, { BackgroundTransparency = 0.88 })
			end)
			row.MouseLeave:Connect(function()
				tween(row, 0.1, { BackgroundTransparency = 1 })
			end)
			row.Activated:Connect(function()
				if busy then
					return
				end
				closeMenu()
				option[2]()
			end)
		end
		openMenu = menu
	end

	-- a card's frame: the slot (which the list lays out), the card in it (which moves), the
	-- big faint number behind everything, a wash of colour behind the character, a line along
	-- the top and corner brackets that light up on hover, all in `color` (the slot's power
	-- colour). Returns the content frame (padded, over the character) and the card's entry.
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
			TextSize = 180,
			TextColor3 = color,
			TextTransparency = 0.86,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -4),
			Size = UDim2.fromOffset(CARD_WIDTH, 180),
		})
		local wash = make("Frame", { Parent = card, Size = UDim2.new(1, 0, 0, PREVIEW_HEIGHT), BackgroundColor3 = color, BorderSizePixel = 0 })
		make("UIGradient", {
			Parent = wash,
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.55, 0.86),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})
		make("Frame", { Parent = card, Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = color, BackgroundTransparency = 0.45, BorderSizePixel = 0 })
		local sweep = make("Frame", { Parent = card, Size = UDim2.fromOffset(0, 3), BackgroundColor3 = color, BorderSizePixel = 0 })
		local brackets = {}
		for _, corner in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
			local x, y = corner[1], corner[2]
			local anchor = Vector2.new(x, y)
			local position = UDim2.new(x, x == 0 and 8 or -8, y, y == 0 and 8 or -8)
			for _, size in ipairs({ Vector2.new(18, 2), Vector2.new(2, 18) }) do
				table.insert(brackets, make("Frame", {
					Parent = card,
					AnchorPoint = anchor,
					Position = position,
					Size = UDim2.fromOffset(size.X, size.Y),
					BackgroundColor3 = color,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 2,
				}))
			end
		end
		local content = make("Frame", { Parent = card, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 })
		make("UIPadding", { Parent = content, PaddingTop = UDim.new(0, 20), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingBottom = UDim.new(0, 20) })
		label(content, { Text = string.format("%02d", order), Font = Theme.MonoFont, TextSize = 12, TextColor3 = Theme.Muted, Size = UDim2.new(1, 0, 0, 14) })
		local entry = { slotFrame = slotFrame, card = card, sweep = sweep, stroke = stroke, accent = color, brackets = brackets, hover = false }
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
		return content, entry
	end

	-- a small caption over a big value, side by side in a card's stats row
	local function stat(content, x, width, caption, value, valueColor)
		label(content, { Text = caption, Font = Theme.MonoFont, TextSize = 11, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(x, STAT_Y), Size = UDim2.fromOffset(width, 14) })
		label(content, { Text = value, Font = Theme.TitleFont, TextSize = 26, TextColor3 = valueColor, Position = UDim2.fromOffset(x, STAT_Y + 14), Size = UDim2.fromOffset(width, 32), TextTruncate = Enum.TextTruncate.AtEnd })
	end

	function render(slots)
		clearCards()
		for slot = 1, SlotConfig.SlotCount do
			local entry = type(slots) == "table" and slots[slot] or nil
			local used = type(entry) == "table"
			local color = used and powerAccent(entry.power) or accent
			local content, cardEntry = cardFrame(slot, color)
			if used then
				-- the character's top half, dressed in the look this slot wears, across the top
				-- of the card (behind the text) and fading out towards the bottom
				local previewHolder = make("Frame", { Parent = cardEntry.card, Size = UDim2.new(1, 0, 0, PREVIEW_HEIGHT), BackgroundTransparency = 1, ZIndex = 1 })
				local model = Customizer.BuildPreview(previewHolder, 10, false, 0.2)
				if model then
					Customizer.Dress(model, SlotConfig.ParseLook(entry.look), parts)
				end
				local viewport = previewHolder:FindFirstChildOfClass("ViewportFrame")
				if viewport then
					make("UIGradient", {
						Parent = viewport,
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(0.5, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
					})
				end
				label(content, { Text = string.upper(entry.name), Font = Theme.TitleFont, TextSize = 34, Position = UDim2.fromOffset(0, NAME_Y), Size = UDim2.new(1, 0, 0, 40), TextTruncate = Enum.TextTruncate.AtEnd })
				stat(content, 0, 90, "LEVEL", tostring(entry.level), color)
				stat(content, 100, 190, "YEN", money(entry.yen or 0), Theme.NavText)
				-- the held power as a tag in its colour, and when the character last played
				local hasPower = entry.power ~= ""
				local chip = make("Frame", {
					Parent = content,
					Position = UDim2.fromOffset(0, CHIP_Y),
					Size = UDim2.fromOffset(0, 22),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = hasPower and color or Theme.Nav,
					BackgroundTransparency = hasPower and 0 or 0.3,
					BorderSizePixel = 0,
				})
				make("UIStroke", { Parent = chip, Color = hasPower and color or Theme.Edge, Transparency = hasPower and 0 or 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
				make("UIPadding", { Parent = chip, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
				label(chip, {
					Text = hasPower and string.upper((SkillSetConfig.Sets[entry.power] or {}).tool or entry.power) or "NO POWER",
					Font = Theme.MonoFont,
					TextSize = 12,
					TextColor3 = hasPower and onColor(color) or Theme.Muted,
					Size = UDim2.fromOffset(0, 22),
					AutomaticSize = Enum.AutomaticSize.X,
				})
				label(content, { Text = "PLAYED " .. string.upper(ago(entry.playedAt)), Font = Theme.MonoFont, TextSize = 11, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(0, CHIP_Y), Size = UDim2.new(1, 0, 0, 22) })
				cardEntry.hint = label(content, {
					Text = "CLICK TO CONTINUE",
					Font = Theme.MonoFont,
					TextSize = 11,
					TextColor3 = Theme.Muted,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 14),
				})
				-- the whole card continues; the three-dot menu, small in the corner, sits above it
				local wholeCard = make("TextButton", { Parent = cardEntry.card, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 })
				wholeCard.Activated:Connect(function()
					if busy then
						return
					end
					busy = true
					status.Text = ""
					local result = Customizer.Call("Select", slot)
					busy = false
					enterWith(result)
				end)
				local dots = make("TextButton", {
					Parent = cardEntry.card,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -14, 0, 14),
					Size = UDim2.fromOffset(30, 30),
					BackgroundColor3 = Theme.Nav,
					BackgroundTransparency = 0.3,
					BorderSizePixel = 0,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 4,
				})
				local dotsStroke = make("UIStroke", { Parent = dots, Color = Theme.Edge, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
				for dot = 0, 2 do
					make("Frame", { Parent = dots, Position = UDim2.fromOffset(13, 6 + dot * 7), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 5 })
				end
				dots.MouseEnter:Connect(function()
					tween(dotsStroke, 0.15, { Color = color, Transparency = 0 })
				end)
				dots.MouseLeave:Connect(function()
					tween(dotsStroke, 0.15, { Color = Theme.Edge, Transparency = 0.5 })
				end)
				dots.Activated:Connect(function()
					if busy or os.clock() - menuClosedAt < 0.25 then
						return -- (a click on the dots while the menu is open closes it: don't open it again)
					end
					showMenu(cardEntry, slot, entry)
				end)
			else
				local locked = SlotConfig.RobuxSlots[slot] ~= nil
				label(content, { Text = locked and "LOCKED" or "EMPTY SLOT", Font = Theme.MonoFont, TextSize = 12, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 16) })
				label(content, { Text = locked and "R$" or "+", Font = Theme.TitleFont, TextSize = locked and 90 or 120, TextColor3 = locked and Theme.Muted or accent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(160, 140), TextXAlignment = Enum.TextXAlignment.Center })
				label(content, { Text = locked and "ROBUX ONLY" or "NEW CHARACTER", Font = Theme.TitleFont, TextSize = 26, TextColor3 = locked and Theme.Muted or nil, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center })
				-- the whole card is the button (a Robux slot has none until its product exists)
				if not locked then
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
	end

	refresh()
end

return SlotMenu
