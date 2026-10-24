-- The player list, in place of Roblox's own: Tab shows and hides it, top right under the
-- icon row (over the kill feed while it's open). A smoked-glass panel, square, one row
-- per player sorted by level: name (★ for your party, yours in white, the rest grey),
-- faction title in its rank colour, held power in its colour, level and yen. Hidden
-- while a menu is open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local FactionConfig = require(ReplicatedStorage:WaitForChild("FactionConfig"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))

local player = Players.LocalPlayer

local TOGGLE_KEY = Enum.KeyCode.Tab
local WIDTH = 400
local HEADER_HEIGHT = 30
local ROW_HEIGHT = 24
local REFRESH = 0.5 -- seconds between redraws while it's open
local DIM = Color3.fromRGB(200, 200, 206)
local QUIET = Color3.fromRGB(140, 140, 150)
-- columns: x and width inside a row
local COLUMNS = {
	name = { 10, 128 },
	faction = { 142, 82 },
	power = { 228, 92 },
	level = { 320, 30 },
	yen = { 354, 38 },
}

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

local function cell(row, column, props)
	local spec = COLUMNS[column]
	props.Position = UDim2.fromOffset(spec[1], 0)
	props.Size = UDim2.new(0, spec[2], 1, 0)
	return text(row, props)
end

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -HudConfig.EdgeMargin, 0, HudConfig.KillFeedTop)
panel.Size = UDim2.fromOffset(WIDTH, HEADER_HEIGHT)
panel.BackgroundColor3 = HudConfig.Style.Glass
panel.BackgroundTransparency = HudConfig.Style.GlassTransparency
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.new(1, 1, 1)
stroke.Transparency = HudConfig.Style.EdgeTransparency
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = panel

-- header: PLAYERS and the count, then the column names
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
header.BackgroundTransparency = 1
header.Parent = panel
local title = text(header, {
	Position = UDim2.fromOffset(10, 0),
	Size = UDim2.new(0, 130, 1, 0),
	Font = HudConfig.Style.TitleFont,
	TextSize = 18,
	Text = "PLAYERS",
})
for column, label in pairs({ faction = "FACTION", power = "POWER", level = "LVL", yen = "YEN" }) do
	cell(header, column, {
		Font = HudConfig.Style.MonoFont,
		TextSize = 10,
		TextColor3 = QUIET,
		Text = label,
		TextXAlignment = (column == "level" or column == "yen") and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
	})
end
local rule = Instance.new("Frame")
rule.Position = UDim2.new(0, 10, 1, -1)
rule.Size = UDim2.new(1, -20, 0, 1)
rule.BackgroundColor3 = Color3.new(1, 1, 1)
rule.BackgroundTransparency = 0.8
rule.BorderSizePixel = 0
rule.Parent = header

-- rows, made as more players join and kept for reuse
local rows = {}
local function rowAt(i)
	if rows[i] then
		return rows[i]
	end
	local row = Instance.new("Frame")
	row.Position = UDim2.fromOffset(0, HEADER_HEIGHT + (i - 1) * ROW_HEIGHT)
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Color3.new(1, 1, 1)
	row.BorderSizePixel = 0
	row.Parent = panel
	local slot = {
		row = row,
		name = cell(row, "name", {}),
		faction = cell(row, "faction", { TextSize = 12 }),
		power = cell(row, "power", { TextSize = 12 }),
		level = cell(row, "level", { Font = HudConfig.Style.MonoFont, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right }),
		yen = cell(row, "yen", { Font = HudConfig.Style.MonoFont, TextSize = 12, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right }),
	}
	rows[i] = slot
	return slot
end

-- "IridescentRequiem" -> "Iridescent Requiem"
local function spaced(name)
	return (string.gsub(name, "(%l)(%u)", "%1 %2"))
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

local function redraw()
	local list = sorted()
	local partyId = player:GetAttribute("PartyId")
	title.Text = string.format("PLAYERS  %d", #list)
	for i, other in ipairs(list) do
		local slot = rowAt(i)
		slot.row.Visible = true
		local mine = other == player
		slot.row.BackgroundTransparency = mine and 0.9 or 1
		local mate = not mine and partyId ~= nil and other:GetAttribute("PartyId") == partyId
		slot.name.Text = (mate and "★ " or "") .. other.DisplayName
		slot.name.TextColor3 = (mine or mate) and Color3.new(1, 1, 1) or DIM

		local faction = other:GetAttribute("Faction") or ""
		local standing = other:GetAttribute("FactionStanding") or 0
		slot.faction.Text = faction ~= "" and (other:GetAttribute("FactionRank") or "") or "—"
		slot.faction.TextColor3 = faction ~= "" and (FactionConfig.RankColor(faction, standing) or DIM) or QUIET

		local powerName = other:GetAttribute("CurrentPower")
		local set = typeof(powerName) == "string" and SkillSetConfig.Sets[powerName]
		slot.power.Text = set and spaced(powerName) or "—"
		slot.power.TextColor3 = set and set.color or QUIET

		slot.level.Text = tostring(other:GetAttribute("Level") or 0)
		slot.yen.Text = shortYen(other:GetAttribute("Yen") or 0)
	end
	for i = #list + 1, #rows do
		rows[i].row.Visible = false
	end
	panel.Size = UDim2.fromOffset(WIDTH, HEADER_HEIGHT + #list * ROW_HEIGHT + 6)
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
