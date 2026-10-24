-- The hub's Party tab. Left: your party as four square slots (name, level, a live
-- HP bar, a LEADER mark; the leader gets PROMOTE and KICK on the others) and LEAVE
-- PARTY. Right: an open invite to you (ACCEPT / DECLINE with a countdown), then the
-- other players in the server with INVITE. Everything comes from the PartyId /
-- PartyLeader / PartyIndex / PartyInvite attributes (Party, on the server); the
-- buttons call the PartyAction remote. The page is only rebuilt when who is where
-- changes, so HP bars and the countdown update in place. An INVITE badge shows in
-- the nav while an invite is open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PartyRules = require(ReplicatedStorage:WaitForChild("PartyRules"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local action = ReplicatedStorage:WaitForChild("PartyAction") -- made by PartyServer

local player = Players.LocalPlayer
local Theme = Hub.Theme

local GAP = 8
local SLOT_HEIGHT = 62
local RIGHT_WIDTH = 300
local GOOD = Color3.fromRGB(110, 205, 130)
local BAD = Color3.fromRGB(226, 90, 90)

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
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.Font = props.Font or Theme.LabelFont
	props.TextColor3 = props.TextColor3 or Theme.Ink
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

-- an ink chip of microtext
local function chip(parent, text, order)
	return label(parent, {
		LayoutOrder = order,
		Text = " " .. text .. " ",
		TextSize = 11,
		TextColor3 = Theme.Paper,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Ink,
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
	})
end

local frame = Hub.Tab("Party", { order = 5, title = "PARTY" })

local status -- the line under the page: the last answer from the server
local function send(kind, userId)
	task.spawn(function()
		local ok, message = action:InvokeServer(kind, userId)
		if status then
			status.Text = message or ""
			status.TextColor3 = ok and GOOD or BAD
		end
	end)
end

-- a square text button; `fill` true is the ink-filled (main) kind
local function button(parent, text, props, onClick, fill)
	props.Parent = parent
	props.Text = text
	props.Font = Theme.LabelFont
	props.TextSize = 11
	props.BorderSizePixel = 0
	props.AutoButtonColor = false
	props.BackgroundColor3 = fill and Theme.Ink or Theme.BarBack
	props.TextColor3 = fill and Theme.Paper or Theme.Ink
	local b = make("TextButton", props)
	b.Activated:Connect(onClick)
	return b
end

local left = make("Frame", { Parent = frame, Size = UDim2.new(1, -(RIGHT_WIDTH + 24), 1, -24), BackgroundTransparency = 1 })
local right = make("Frame", { Parent = frame, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, RIGHT_WIDTH, 1, -24), BackgroundTransparency = 1 })
status = label(frame, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 18), TextSize = 12, Text = "" })

local leftList = make("UIListLayout", { Parent = left, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) })
local rightList = make("UIListLayout", { Parent = right, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) })

local live = {} -- things to update in place: { kind = "hp", player, fill } / { kind = "countdown", label, expires }
local inkItems = {} -- parts drawn in the held power's colour

-- members of my party, leader first, or an empty list
local function myParty()
	local id = player:GetAttribute("PartyId")
	local list = {}
	if id then
		for _, other in ipairs(Players:GetPlayers()) do
			if other:GetAttribute("PartyId") == id then
				table.insert(list, other)
			end
		end
		table.sort(list, function(a, b)
			return (a:GetAttribute("PartyIndex") or 99) < (b:GetAttribute("PartyIndex") or 99)
		end)
	end
	return list
end

local function openInvite()
	local fromId, expires = PartyRules.DecodeInvite(player:GetAttribute("PartyInvite"))
	if fromId and PartyRules.InviteOpen(expires, workspace:GetServerTimeNow()) then
		return Players:GetPlayerByUserId(fromId), expires
	end
	return nil
end

local function hpFraction(member)
	local humanoid = member.Character and member.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MaxHealth > 0 then
		return math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
	end
	return 0
end

-- who is where, as text: the page is rebuilt only when it changes
local function signature(members, invitedBy)
	local parts = { tostring(player:GetAttribute("PartyLeader")), invitedBy and tostring(invitedBy.UserId) or "-" }
	for _, member in ipairs(members) do
		table.insert(parts, member.UserId)
	end
	table.insert(parts, "|")
	for _, other in ipairs(Players:GetPlayers()) do
		table.insert(parts, other.UserId .. (other:GetAttribute("PartyId") and "p" or "") .. (other:GetAttribute("PartyInvite") and "i" or ""))
	end
	return table.concat(parts, ",")
end

local function slotCard(order)
	local card = make("Frame", { Parent = left, LayoutOrder = order, Size = UDim2.new(1, 0, 0, SLOT_HEIGHT), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0 })
	local bar = make("Frame", { Parent = card, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, BackgroundColor3 = Theme.Muted, BackgroundTransparency = 0.6 })
	return card, bar
end

local function rebuild(members, invitedBy, expires)
	live = {}
	inkItems = {}
	for _, child in ipairs(left:GetChildren()) do
		if child ~= leftList then
			child:Destroy()
		end
	end
	for _, child in ipairs(right:GetChildren()) do
		if child ~= rightList then
			child:Destroy()
		end
	end

	local inParty = #members > 0
	local amLeader = inParty and player:GetAttribute("PartyLeader") == player.UserId
	local full = #members >= PartyRules.MaxMembers
	local canInvite = (not inParty or amLeader) and not full

	-- left: the party
	chip(left, string.format("YOUR PARTY  %d / %d", #members, PartyRules.MaxMembers), 0)
	for slot = 1, PartyRules.MaxMembers do
		local member = members[slot]
		local card, bar = slotCard(slot)
		if member then
			local leader = member:GetAttribute("PartyLeader") == member.UserId
			bar.BackgroundTransparency = 0
			bar.BackgroundColor3 = leader and Hub.InkAccent() or Theme.Muted
			if leader then
				table.insert(inkItems, bar)
			end
			label(card, { Text = member.DisplayName, Font = Theme.BodyFont, TextSize = 16, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -150, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
			label(card, {
				Text = string.format("LV %d%s", member:GetAttribute("Level") or 1, leader and "  ·  LEADER" or ""),
				TextSize = 10,
				TextColor3 = Theme.Muted,
				Position = UDim2.fromOffset(14, 28),
				Size = UDim2.new(1, -150, 0, 12),
			})
			local back = make("Frame", { Parent = card, Position = UDim2.new(0, 14, 1, -14), Size = UDim2.new(1, -28, 0, 5), BackgroundColor3 = Theme.BarBack, BorderSizePixel = 0 })
			local fill = make("Frame", { Parent = back, Size = UDim2.fromScale(hpFraction(member), 1), BackgroundColor3 = Color3.fromRGB(226, 75, 74), BorderSizePixel = 0 })
			table.insert(live, { kind = "hp", player = member, fill = fill })
			if amLeader and member ~= player then
				button(card, "KICK", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(52, 22) }, function()
					send("kick", member.UserId)
				end)
				button(card, "PROMOTE", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -68, 0, 8), Size = UDim2.fromOffset(70, 22) }, function()
					send("promote", member.UserId)
				end)
			end
		else
			label(card, { Text = "EMPTY SLOT", TextSize = 12, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0) })
		end
	end
	if inParty then
		button(left, "LEAVE PARTY", { LayoutOrder = 10, Size = UDim2.fromOffset(120, 26) }, function()
			send("leave")
		end)
	end

	-- right: an invite to me, then the players to invite
	if invitedBy then
		local card = make("Frame", { Parent = right, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 78), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0 })
		local bar = make("Frame", { Parent = card, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, BackgroundColor3 = Hub.InkAccent() })
		table.insert(inkItems, bar)
		label(card, { Text = "PARTY INVITE", TextSize = 10, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 0, 12) })
		local timer = label(card, { TextSize = 10, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 0, 12) })
		table.insert(live, { kind = "countdown", label = timer, expires = expires })
		label(card, { Text = invitedBy.DisplayName, Font = Theme.BodyFont, TextSize = 15, Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -24, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
		button(card, "ACCEPT", { Position = UDim2.new(0, 12, 1, -30), Size = UDim2.fromOffset(84, 22) }, function()
			send("accept")
		end, true)
		button(card, "DECLINE", { Position = UDim2.new(0, 104, 1, -30), Size = UDim2.fromOffset(84, 22) }, function()
			send("decline")
		end)
	end
	chip(right, "INVITE A PLAYER", 1)
	local listFrame = make("ScrollingFrame", {
		Parent = right,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 1, -(invitedBy and 140 or 50)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Muted,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
	make("UIListLayout", { Parent = listFrame, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
	local shown = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and not other:GetAttribute("PartyId") then
			shown += 1
			local row = make("Frame", { Parent = listFrame, LayoutOrder = shown, Size = UDim2.new(1, -6, 0, 30), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0 })
			label(row, { Text = other.DisplayName, Font = Theme.BodyFont, TextSize = 14, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -90, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
			local pending = other:GetAttribute("PartyInvite") ~= nil
			if canInvite and not pending then
				button(row, "INVITE", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(64, 22) }, function()
					send("invite", other.UserId)
				end, true)
			else
				label(row, {
					Text = pending and "INVITED" or (full and "FULL" or "LEADER ONLY"),
					TextSize = 10,
					TextColor3 = Theme.Muted,
					TextXAlignment = Enum.TextXAlignment.Right,
					Position = UDim2.new(1, -90, 0, 0),
					Size = UDim2.new(0, 84, 1, 0),
				})
			end
		end
	end
	if shown == 0 then
		label(listFrame, { Text = "NO ONE ELSE IS FREE TO INVITE.", TextSize = 11, TextColor3 = Theme.Muted, Size = UDim2.new(1, 0, 0, 20) })
	end
end

Hub.OnAccent(function(_, ink)
	for _, item in ipairs(inkItems) do
		item.BackgroundColor3 = ink
	end
end)

local lastSignature
local function refresh()
	local members = myParty()
	local invitedBy, expires = openInvite()
	Hub.Badge("Party", invitedBy and "INVITE" or nil)
	if not Hub.IsOpen("Party") then
		lastSignature = nil -- rebuilt fresh the next time it shows
		return
	end
	local current = signature(members, invitedBy)
	if current ~= lastSignature then
		lastSignature = current
		rebuild(members, invitedBy, expires)
	end
	for _, item in ipairs(live) do
		if item.kind == "hp" then
			item.fill.Size = UDim2.fromScale(hpFraction(item.player), 1)
		else
			item.label.Text = string.format("%ds", math.max(0, math.ceil(item.expires - workspace:GetServerTimeNow())))
		end
	end
end

Hub.OnShown("Party", function()
	lastSignature = nil
	status.Text = ""
	refresh()
end)

local sinceRefresh = 0
RunService.Heartbeat:Connect(function(dt)
	sinceRefresh += dt
	if sinceRefresh >= 0.2 then
		sinceRefresh = 0
		refresh()
	end
end)
