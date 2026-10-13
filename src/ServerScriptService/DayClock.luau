-- The daylight cycle's clock (see ReplicatedStorage.DayCycleConfig). The
-- server keeps an anchor: the hour it was at one moment of server time, and
-- whether it's frozen. They live as attributes on ReplicatedStorage
-- (DayAnchorTime, DayAnchorServerTime, DayFrozen) so every client works out
-- the same hour and animates the lighting itself (DayCycleClient). Here the
-- server sets Lighting.ClockTime once a second, so its sun and moon checks
-- (SkyLight) are right, and keeps ReplicatedStorage's Phase attribute
-- (Dawn, Day, Dusk, Night) up to date for anything that wants it.
-- Freezing and resuming re-anchor at the current hour, so the time never jumps.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DayCycleConfig = require(ReplicatedStorage:WaitForChild("DayCycleConfig"))

local APPLY_INTERVAL = 1 -- seconds between setting Lighting.ClockTime

local started = false

local DayClock = {}

function DayClock.IsFrozen()
	return ReplicatedStorage:GetAttribute("DayFrozen") == true
end

-- the hour of day now, 0 up to 24
function DayClock.Hour()
	local anchorHour = ReplicatedStorage:GetAttribute("DayAnchorTime")
	local anchorServerTime = ReplicatedStorage:GetAttribute("DayAnchorServerTime")
	if not anchorHour or not anchorServerTime then
		return DayCycleConfig.StartHour
	end
	return DayCycleConfig.HourAt(anchorHour, anchorServerTime, workspace:GetServerTimeNow(), DayClock.IsFrozen())
end

local function setAnchor(hour, frozen)
	ReplicatedStorage:SetAttribute("DayAnchorTime", hour)
	ReplicatedStorage:SetAttribute("DayAnchorServerTime", workspace:GetServerTimeNow())
	ReplicatedStorage:SetAttribute("DayFrozen", frozen)
end

local function apply()
	local hour = DayClock.Hour()
	Lighting.ClockTime = hour
	local phase = DayCycleConfig.PhaseAt(hour)
	if ReplicatedStorage:GetAttribute("Phase") ~= phase then
		ReplicatedStorage:SetAttribute("Phase", phase)
	end
end

-- jumps to this hour (already cleaned by DayCycleConfig.CleanHour); stays
-- frozen if it was
function DayClock.SetHour(hour)
	setAnchor(hour, DayClock.IsFrozen())
	apply()
end

function DayClock.SetFrozen(frozen)
	setAnchor(DayClock.Hour(), frozen)
	apply()
end

function DayClock.Start()
	if started then
		return
	end
	started = true
	setAnchor(DayCycleConfig.StartHour, false)
	apply()
	task.spawn(function()
		while true do
			task.wait(APPLY_INTERVAL)
			apply()
		end
	end)
end

return DayClock
