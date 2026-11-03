-- The phone's way to press the keyboard actions. TouchControls draws the buttons and calls
-- Press/Release; each action's script (Dash, Block, Punch, Ranged, SkillBar) listens with
-- OnDown/OnUp, next to its key handler, so a button does exactly what the key does.
-- Actions: "Attack", "Dash", "Block", "Special", "Reload", "SkillZ".."SkillF".
local UserInputService = game:GetService("UserInputService")

local TouchInput = {}

local downListeners = {} -- action -> { callback }
local upListeners = {}
local held = {} -- action -> true while a button is down

-- a touch screen with no keyboard: a phone or tablet (a laptop with a touch screen keeps its keys)
function TouchInput.Active()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function TouchInput.OnDown(action, callback)
	downListeners[action] = downListeners[action] or {}
	table.insert(downListeners[action], callback)
end

function TouchInput.OnUp(action, callback)
	upListeners[action] = upListeners[action] or {}
	table.insert(upListeners[action], callback)
end

function TouchInput.Press(action)
	if held[action] then
		return
	end
	held[action] = true
	for _, callback in ipairs(downListeners[action] or {}) do
		task.spawn(callback)
	end
end

function TouchInput.Release(action)
	if not held[action] then
		return
	end
	held[action] = nil
	for _, callback in ipairs(upListeners[action] or {}) do
		task.spawn(callback)
	end
end

function TouchInput.IsHeld(action)
	return held[action] == true
end

return TouchInput
