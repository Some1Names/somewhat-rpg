-- The player list, in place of Roblox's own: Tab shows and hides it, top right just under
-- Roblox's top bar, as wide as the tool grid (over the kill feed while it's open). A dark
-- panel, square, no header: one row per player sorted by level, "Name [level]" on the left
-- (the name in its faction's rank colour, ★ for your party) and the yen on the right.
-- Hidden while a menu is open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local FactionConfig = require(ReplicatedStorage:WaitForChild("FactionConfig"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))

local player = Players.LocalPlayer

local TOGGLE_KEY = Enum.KeyCode.Tab
local WIDTH = HudConfig.SideWidth -- as wide as the tool grid below it
local TOP = 6 -- px under Roblox's top bar
local ROW_HEIGHT = 22
local PAD = 4 -- px above the first row and below the last
local BACKGROUND_TRANSPARENCY = 0.2
local REFRESH = 0.5 -- seconds between redraws while it's open
local NO_FACTION = Color3.new(1, 1, 1)
local DIM = Color3.fromRGB(200, 200, 206)

-- Roblox's own list goes; CoreGui may not be ready right away
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false) then
			return
		end
		task.wait(0.5)
	end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "Leaderboard"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = HudConfig.Style.LabelFont
	l.TextSize = 13
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	for key, value in pairs(props) do
		l[key] = value
	end
	l.Parent = parent
	return l
end

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -HudConfig.EdgeMargin, 0, TOP)
panel.Size = UDim2.fromOffset(WIDTH, 2 * PAD)
panel.BackgroundColor3 = HudConfig.Style.Glass
panel.BackgroundTransparency = BACKGROUND_TRANSPARENCY
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.new(1, 1, 1)
stroke.Transparency = HudConfig.Style.EdgeTransparency
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = panel

-- rows, made as more players join and kept for reuse
local rows = {}
local function rowAt(i)
	if rows[i] then
		return rows[i]
	end
	local row = Instance.new("Frame")
	row.Position = UDim2.fromOffset(0, PAD + (i - 1) * ROW_HEIGHT)
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Color3.new(1, 1, 1)
	row.BorderSizePixel = 0
	row.Parent = panel
	local slot = {
		row = row,
		name = text(row, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -80, 1, 0), RichText = true }),
		yen = text(row, {
			Position = UDim2.new(1, -70, 0, 0),
			Size = UDim2.new(0, 60, 1, 0),
			Font = HudConfig.Style.MonoFont,
			TextSize = 12,
			TextColor3 = DIM,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	}
	rows[i] = slot
	return slot
end

local function shortYen(amount)
	if amount >= 1e6 then
		return string.format("%.1fM", amount / 1e6)
	elseif amount >= 1e4 then
		return string.format("%dK", amount // 1e3)
	end
	return tostring(amount)
end

local function sorted()
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		local la, lb = a:GetAttribute("Level") or 0, b:GetAttribute("Level") or 0
		if la ~= lb then
			return la > lb
		end
		return a.DisplayName < b.DisplayName
	end)
	return list
end

local function escape(s)
	return (string.gsub(s, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

local function redraw()
	local list = sorted()
	local partyId = player:GetAttribute("PartyId")
	for i, other in ipairs(list) do
		local slot = rowAt(i)
		slot.row.Visible = true
		local mine = other == player
		slot.row.BackgroundTransparency = mine and 0.9 or 1
		local mate = not mine and partyId ~= nil and other:GetAttribute("PartyId") == partyId

		local faction = other:GetAttribute("Faction") or ""
		local color = faction ~= "" and FactionConfig.RankColor(faction, other:GetAttribute("FactionStanding") or 0) or NO_FACTION
		slot.name.Text = string.format(
			'%s<font color="#%s">%s</font> <font color="#%s">[%d]</font>',
			mate and "★ " or "",
			color:ToHex(),
			escape(other.DisplayName),
			DIM:ToHex(),
			other:GetAttribute("Level") or 0
		)
		slot.yen.Text = shortYen(other:GetAttribute("Yen") or 0) .. "¥"
	end
	for i = #list + 1, #rows do
		rows[i].row.Visible = false
	end
	panel.Size = UDim2.fromOffset(WIDTH, 2 * PAD + #list * ROW_HEIGHT)
end

local open = false
local function show()
	panel.Visible = open and not Menus.AnyOpen()
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= TOGGLE_KEY then
		return
	end
	open = not open
	if open then
		redraw()
	end
	show()
end)

while true do
	show()
	if panel.Visible then
		redraw()
	end
	task.wait(REFRESH)
end
