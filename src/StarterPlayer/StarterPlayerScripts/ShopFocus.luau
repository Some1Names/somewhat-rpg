-- The full-screen close-up the shop-like menus (the shops, the smith) share. Begin(model, options)
-- tweens the camera to a front view of the NPC, with them on the right of the screen and room on
-- the left for the menu; switches the player's controls, their character, the HUD (every other
-- ScreenGui and the billboards over characters), the NPCs' "press E" prompts and the NPC's
-- overhead name tag off; puts the held tool away; and makes E (a moment after it opened) call options.onLeave. End()
-- puts all of it back (only what Begin turned off is turned on again). Step() runs every frame
-- while it's open (Begin binds it to the render step itself; the camera's own fade keeps
-- un-hiding the player's character and the skill bar switches itself back on).
--   options.ignoreGui: the menu's own ScreenGui, which stays on
--   options.onLeave: what E does (close the menu)
--   options.shift: studs the NPC sits right of centre (CLOSEUP_SHIFT; a wider menu needs more)
-- The camera sits straight in front of the NPC, or at the first angle to either side with a clear
-- view of them (an NPC standing in front doesn't hide them), nearer if a wall is behind it.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ReforgeConfig = require(ReplicatedStorage:WaitForChild("ReforgeConfig"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))

local player = Players.LocalPlayer

local CLOSEUP_DISTANCE = 9 -- studs in front of the NPC the camera sits
local CLOSEUP_MIN_DISTANCE = 4.5 -- nearest the camera comes when a wall is in the way
local CLOSEUP_ANGLES = { 0, 20, -20, 40, -40, 60, -60, 80, -80 } -- degrees off straight-on to try
local CLOSEUP_DROP = 1.4 -- studs below the head the camera looks at
local CLOSEUP_SHIFT = 2.2 -- studs the NPC sits right of centre, clear of the menu
local CLOSEUP_FOV = 35
local CLOSEUP_TIME = 0.5
local LEAVE_DELAY = 0.4 -- seconds before E leaves, so the E that opened the menu doesn't also close it
local PROMPT_TAGS = { ShopConfig.Tag, ReforgeConfig.Tag } -- the NPCs whose prompts are hidden meanwhile

local ShopFocus = {}

local state -- nil, or { camera, tween, tag, hiddenGuis, hiddenPrompts, onLeave, openedAt }

local function setControls(enabled)
	local ok, controls = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 2)):GetControls()
	end)
	if ok and controls then
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end
end

local function setCharacterHidden(hidden)
	local character = player.Character
	for _, part in ipairs(character and character:GetDescendants() or {}) do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

-- whether something you can see stands on the line between two points (parts that are
-- see-through, like an NPC's invisible root, don't count)
local function lineBlocked(from, to, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, 8 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(from, to - from, params)
		if not hit then
			return false
		end
		if hit.Instance.Transparency <= 0.8 then
			return true
		end
		table.insert(ignore, hit.Instance)
	end
	return false
end

-- the camera for the close-up (nil if the NPC has no head or facing)
local function closeUpFrame(npc, shift)
	local head = npc:FindFirstChild("Head")
	local root = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso") or npc.PrimaryPart
	if not head or not root then
		return nil
	end
	local look = root.CFrame.LookVector
	local front = Vector3.new(look.X, 0, look.Z)
	if front.Magnitude < 0.1 then
		return nil
	end
	front = front.Unit
	local focus = head.Position - Vector3.new(0, CLOSEUP_DROP, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local best
	for _, degrees in ipairs(CLOSEUP_ANGLES) do
		local direction = CFrame.Angles(0, math.rad(degrees), 0) * front
		-- only solid map geometry pulls the camera in: other characters and see-through parts are skipped
		local ignore = { npc, player.Character }
		local distance = CLOSEUP_DISTANCE
		for _ = 1, 8 do
			params.FilterDescendantsInstances = ignore
			local hit = workspace:Raycast(focus, direction * distance, params)
			if not hit then
				break
			end
			local part = hit.Instance
			local character = part:FindFirstAncestorOfClass("Model")
			if not part.CanCollide or part.Transparency > 0.8 or (character and character:FindFirstChildOfClass("Humanoid")) then
				table.insert(ignore, character or part)
			else
				distance = math.max(CLOSEUP_MIN_DISTANCE, hit.Distance - 0.5)
				break
			end
		end
		local position = focus + direction * distance
		best = best or CFrame.lookAt(position, focus)
		if not lineBlocked(position, focus, { npc, player.Character }) then
			best = CFrame.lookAt(position, focus)
			break
		end
	end
	return best * CFrame.new(-(shift or CLOSEUP_SHIFT), 0, 0)
end

-- turns off every other ScreenGui and billboard over a character (their own HP and stamina, everyone's
-- health boxes); returns what it turned off
local function hideHud(ignoreGui)
	local hidden = {}
	for _, other in ipairs(player.PlayerGui:GetChildren()) do
		if (other:IsA("ScreenGui") or other:IsA("BillboardGui")) and other ~= ignoreGui and other.Enabled then
			other.Enabled = false
			table.insert(hidden, other)
		end
	end
	return hidden
end

-- turns off the "press E" prompts of the shopkeepers and smiths; returns what it turned off
local function hidePrompts()
	local hidden = {}
	for _, tag in ipairs(PROMPT_TAGS) do
		for _, npc in ipairs(CollectionService:GetTagged(tag)) do
			for _, descendant in ipairs(npc:GetDescendants()) do
				if descendant:IsA("ProximityPrompt") and descendant.Enabled then
					descendant.Enabled = false
					table.insert(hidden, descendant)
				end
			end
		end
	end
	return hidden
end

-- whether the close-up is on
function ShopFocus.Active()
	return state ~= nil
end

-- starts the close-up on the NPC; false (and nothing changes) if it can't be framed. Called
-- while it's already on it does nothing and says true.
function ShopFocus.Begin(npc, options)
	if state then
		return true
	end
	options = options or {}
	local frame = closeUpFrame(npc, options.shift)
	if not frame then
		return false
	end
	local camera = workspace.CurrentCamera
	state = {
		camera = { type = camera.CameraType, fov = camera.FieldOfView },
		onLeave = options.onLeave,
		openedAt = os.clock(),
		ignoreGui = options.ignoreGui,
	}
	camera.CameraType = Enum.CameraType.Scriptable
	state.tween = TweenService:Create(camera, TweenInfo.new(CLOSEUP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = frame,
		FieldOfView = CLOSEUP_FOV,
	})
	state.tween:Play()
	setControls(false)
	state.hiddenGuis = hideHud(options.ignoreGui)
	state.hiddenSet = {}
	for _, gui in ipairs(state.hiddenGuis) do
		state.hiddenSet[gui] = true
	end
	state.hiddenPrompts = hidePrompts()
	state.tag = npc:FindFirstChild("NameTag", true)
	if state.tag then
		state.tag.Enabled = false
	end
	-- last in every frame, after the HUD scripts have run (the skill bar switches itself on while
	-- a power is held), so what's drawn never shows it
	RunService:BindToRenderStep("ShopFocus", Enum.RenderPriority.Last.Value + 1, function()
		ShopFocus.Step()
	end)
	return true
end

-- puts everything Begin changed back
function ShopFocus.End()
	if not state then
		return
	end
	local closing = state
	state = nil
	RunService:UnbindFromRenderStep("ShopFocus")
	if closing.tween then
		closing.tween:Cancel()
	end
	if closing.tag then
		closing.tag.Enabled = true
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = closing.camera.type
	camera.FieldOfView = closing.camera.fov
	setControls(true)
	setCharacterHidden(false)
	for _, gui in ipairs(closing.hiddenGuis) do
		if gui.Parent then
			gui.Enabled = true
		end
	end
	for _, prompt in ipairs(closing.hiddenPrompts) do
		prompt.Enabled = true
	end
end

-- every frame while the close-up is on
function ShopFocus.Step()
	if not state then
		return
	end
	setCharacterHidden(true) -- the camera's own fade resets it every frame
	-- the held power or tool is put away, and the number keys can't bring it back out
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and character:FindFirstChildOfClass("Tool") then
		humanoid:UnequipTools()
	end
	-- a HUD that switches itself back on (the skill bar while a power is held, a new popup) goes off
	-- again, and is switched back on when the close-up ends
	for _, other in ipairs(player.PlayerGui:GetChildren()) do
		if (other:IsA("ScreenGui") or other:IsA("BillboardGui")) and other ~= state.ignoreGui and other.Enabled then
			other.Enabled = false
			if not state.hiddenSet[other] then
				state.hiddenSet[other] = true
				table.insert(state.hiddenGuis, other)
			end
		end
	end
end

-- E again leaves
UserInputService.InputBegan:Connect(function(input, processed)
	if state and state.onLeave and not processed and input.KeyCode == Enum.KeyCode.E and os.clock() - state.openedAt > LEAVE_DELAY then
		state.onLeave()
	end
end)

return ShopFocus
