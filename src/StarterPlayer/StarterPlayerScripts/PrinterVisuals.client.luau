-- The 3D printer's machine, on the client. A printer that's a model (tagged "Printer") with a
-- Scanner model and trays Slot1..Slot3 comes alive for the player looking at it: the scanner's
-- light plane rides up and down inside the glass (slowly while idle, fast while one of your prints
-- runs), and each tray shows your print in that slot (the PrintJobs attribute, CraftConfig, so
-- everyone sees their own): a cyan hologram growing layer by layer with the print's progress, a
-- bright layer and sparks where it's printing, the tray's light pulsing cyan. Done, it turns green,
-- floats and turns until you collect it. A new print, a finished one and a collect each burst at
-- the tray. Placeholders (parts built here, the Shared prefabs) until the owner's printing effects.
-- Its PointLights are off in the daytime (DayCycleConfig's Day phase), and while the player is in
-- range of its "Print" prompt the whole printer is outlined.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CraftConfig = require(ReplicatedStorage:WaitForChild("CraftConfig"))
local DayCycleConfig = require(ReplicatedStorage:WaitForChild("DayCycleConfig"))
local VFX = require(ReplicatedStorage:WaitForChild("VFX"))
local player = Players.LocalPlayer

local ACCENT = Color3.fromRGB(60, 224, 230) -- the printer's cyan (PrinterMenu)
local GOOD = Color3.fromRGB(90, 200, 120)
local VIEW_RANGE = 200 -- studs from the camera a printer is animated within
local SCAN_IDLE = 7 -- seconds for the scanner's trip up and back while idle
local SCAN_BUSY = 2.4 -- and while one of your prints runs
local SCAN_LOW = 0.35 -- studs over the trays the scanner comes down to
local SCAN_HIGH = 1.6 -- studs under the machine's top it goes up to
local HOLO_SIZE = 1.5 -- studs: the hologram's width, and its height when done
local LAYER_MARGIN = 0.3 -- studs the printing layer sticks out past the hologram
local SPARK_INTERVAL = 0.45 -- seconds between sparks at the layer being printed
local PULSE_SPEED = 4 -- radians per second of the tray light's pulse while printing
local SPIN = 0.6 -- radians per second a finished print turns
local BOB = 0.12 -- studs a finished print floats up and down
local FLOAT = 0.25 -- studs a finished print hovers over the tray
local RETRY = 2 -- seconds between looks for printers not set up yet (streamed in later)
local LIGHT_CHECK = 1 -- seconds between checks of the time of day for the lights
local OUTLINE_FADE = 0.2 -- seconds the outline takes to show

local states = {} -- printer -> { scanner, base, low, high, phase, slots }
local jobs = {} -- the player's prints (CraftConfig.ParseJobs)

local function isDaytime()
	return DayCycleConfig.PhaseAt(Lighting.ClockTime) == "Day"
end

local function readJobs()
	jobs = CraftConfig.ParseJobs(player:GetAttribute(CraftConfig.JobsAttribute))
end
readJobs()
player:GetAttributeChangedSignal(CraftConfig.JobsAttribute):Connect(readJobs)

local function makePart(name, parent, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material
	part.Transparency = transparency
	part.Color = ACCENT
	part.Parent = parent
	return part
end

local function clearHologram(slot)
	if slot.holo then
		slot.holo:Destroy()
		slot.layer:Destroy()
		slot.holo, slot.layer, slot.light = nil, nil, nil
	end
	if slot.neon then
		slot.neon.Color = slot.color
	end
end

local function burst(path, slot, color, scale)
	VFX.Play(path, slot.top.Position + Vector3.new(0, HOLO_SIZE / 2, 0), { color = color, scale = scale })
end

local function setup(printer)
	if states[printer] or not printer:IsA("Model") or not printer:IsDescendantOf(workspace) then
		return
	end
	local scanner = printer:FindFirstChild("Scanner")
	if not scanner then
		return
	end
	local box, size = printer:GetBoundingBox()
	local state = { scanner = scanner, base = scanner:GetPivot(), phase = 0, slots = {} }
	local lowest = math.huge
	for index = 1, #CraftConfig.JobSlotLevels do
		local model = printer:FindFirstChild("Slot" .. index)
		if model then
			local trayBox, traySize = model:GetBoundingBox()
			-- the tray's top middle, turned the way the tray is (upright)
			local look = trayBox.LookVector
			local at = trayBox.Position + Vector3.new(0, traySize.Y / 2, 0)
			local top = CFrame.lookAt(at, at + Vector3.new(look.X, 0, look.Z))
			local neon
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") and part.Material == Enum.Material.Neon then
					neon = part
				end
			end
			state.slots[index] = { model = model, top = top, neon = neon, color = neon and neon.Color, seen = false, spin = 0 }
			lowest = math.min(lowest, at.Y)
		end
	end
	if lowest == math.huge then
		lowest = box.Position.Y - size.Y / 2
	end
	state.low = lowest + SCAN_LOW - state.base.Position.Y
	state.high = math.max(box.Position.Y + size.Y / 2 - SCAN_HIGH - state.base.Position.Y, state.low)
	states[printer] = state
end

local function forget(printer)
	local state = states[printer]
	if not state then
		return
	end
	for _, slot in pairs(state.slots) do
		clearHologram(slot)
	end
	states[printer] = nil
end

-- one tray: the print in that slot, if any
local function updateSlot(slot, job, now, dt)
	local key = job and (job.recipe .. "|" .. job.seed)
	local ready = job ~= nil and CraftConfig.IsReady(job, now)
	if key ~= slot.key then
		-- a new print bursts cyan; a finished one gone (collected) bursts green
		if slot.seen and job then
			burst("Shared/Sparks", slot, ACCENT, 0.8)
		elseif slot.seen and slot.ready then
			burst("Shared/AuraBurst", slot, GOOD, 0.6)
		end
		clearHologram(slot)
		slot.key = key
		slot.ready = ready
		slot.sparkAt = 0
	elseif ready and not slot.ready then
		burst("Shared/AuraBurst", slot, GOOD, 0.5)
		slot.ready = true
	end
	slot.seen = true
	if not job then
		return
	end
	local recipe = CraftConfig.Get(job.recipe)
	if not slot.holo then
		slot.holo = makePart("PrintHologram", slot.model, Enum.Material.ForceField, 0)
		slot.layer = makePart("PrintLayer", slot.model, Enum.Material.Neon, 0.35)
		slot.light = Instance.new("PointLight")
		slot.light.Range = 6
		slot.light.Brightness = 1.5
		slot.light.Enabled = not isDaytime()
		slot.light.Parent = slot.holo
	end
	local color = ready and GOOD or ACCENT
	local progress = ready and 1 or math.clamp(1 - (job.finishAt - now) / recipe.seconds, 0, 1)
	local height = math.max(HOLO_SIZE * progress, 0.05)
	local lift = 0
	if ready then
		slot.spin += SPIN * dt
		lift = FLOAT + math.sin(now * 2) * BOB
	end
	slot.holo.Color = color
	slot.light.Color = color
	slot.holo.Size = Vector3.new(HOLO_SIZE, height, HOLO_SIZE)
	slot.holo.CFrame = slot.top * CFrame.new(0, height / 2 + lift, 0) * CFrame.Angles(0, slot.spin, 0)
	-- the bright layer where it's printing, and its sparks
	local layerAt = slot.top * CFrame.new(0, height, 0)
	slot.layer.Size = Vector3.new(HOLO_SIZE + LAYER_MARGIN, 0.06, HOLO_SIZE + LAYER_MARGIN)
	slot.layer.CFrame = layerAt
	slot.layer.Transparency = ready and 1 or 0.35
	if slot.neon then
		slot.neon.Color = ready and GOOD or ACCENT:Lerp(slot.color, 0.5 + 0.5 * math.sin(now * PULSE_SPEED))
	end
	if not ready and now >= slot.sparkAt then
		slot.sparkAt = now + SPARK_INTERVAL
		VFX.Play("Shared/Sparks", layerAt.Position, { color = ACCENT, scale = 0.35 })
	end
end

RunService.Heartbeat:Connect(function(dt)
	local camera = workspace.CurrentCamera
	local now = workspace:GetServerTimeNow() -- the server's os.time(), give or take (CraftConfig's finishAt)
	local busy = false
	for _, job in ipairs(jobs) do
		if not CraftConfig.IsReady(job, now) then
			busy = true
		end
	end
	for printer, state in pairs(states) do
		if not printer:IsDescendantOf(workspace) or not state.scanner:IsDescendantOf(printer) then
			forget(printer)
		elseif (camera.CFrame.Position - state.base.Position).Magnitude <= VIEW_RANGE then
			-- the scanner rides up and back, smoothly turning at each end
			state.phase += dt * 2 * math.pi / (busy and SCAN_BUSY or SCAN_IDLE)
			local t = (1 - math.cos(state.phase)) / 2
			state.scanner:PivotTo(state.base + Vector3.new(0, state.low + (state.high - state.low) * t, 0))
			for index, slot in pairs(state.slots) do
				updateSlot(slot, jobs[index], now, dt)
			end
		end
	end
end)

-- the printer that holds a prompt, if it's a printer's
local function printerOf(prompt)
	local printer = prompt.Name == "PrinterPrompt" and prompt.Parent
	while printer and not CollectionService:HasTag(printer, CraftConfig.Tag) do
		printer = printer.Parent
	end
	return printer
end

-- in range of the prompt: the printer is outlined in its cyan
ProximityPromptService.PromptShown:Connect(function(prompt)
	local printer = printerOf(prompt)
	if not printer or printer:FindFirstChild("PrinterOutline") then
		return
	end
	local outline = Instance.new("Highlight")
	outline.Name = "PrinterOutline"
	outline.Adornee = printer
	outline.FillTransparency = 1
	outline.OutlineColor = ACCENT
	outline.OutlineTransparency = 1
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = printer
	TweenService:Create(outline, TweenInfo.new(OUTLINE_FADE), { OutlineTransparency = 0 }):Play()
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	local printer = printerOf(prompt)
	local outline = printer and printer:FindFirstChild("PrinterOutline")
	if outline then
		outline:Destroy()
	end
end)

-- the printers' own lights (and the holograms') are off in the daytime
task.spawn(function()
	while true do
		local on = not isDaytime()
		for printer in pairs(states) do
			for _, light in ipairs(printer:GetDescendants()) do
				if light:IsA("PointLight") then
					light.Enabled = on
				end
			end
		end
		task.wait(LIGHT_CHECK)
	end
end)

CollectionService:GetInstanceAddedSignal(CraftConfig.Tag):Connect(setup)
CollectionService:GetInstanceRemovedSignal(CraftConfig.Tag):Connect(forget)
-- a printer streamed in after the tag (or its scanner after it) is set up on the next look
task.spawn(function()
	while true do
		for _, printer in ipairs(CollectionService:GetTagged(CraftConfig.Tag)) do
			setup(printer)
		end
		task.wait(RETRY)
	end
end)
