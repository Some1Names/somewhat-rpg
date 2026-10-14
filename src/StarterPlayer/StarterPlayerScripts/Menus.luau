-- The one-menu rule: Inventory, Stats, Settings, Shop, Gallery, Quests and
-- Admin register here when they open (Menus.Open(name, closeFn)), which
-- closes whichever menu was open first. A menu calls Menus.Close(name)
-- whenever it closes itself (key, ×, Esc), so the next open starts clean.
-- The top bar's icons toggle a menu by name (Menus.Toggle) through the
-- function the menu gave Menus.Register, and watch Menus.OnChange to enlarge
-- the icon of the open one.
local Menus = {}

local openName, openClose
local togglers = {} -- name -> function that toggles that menu like its key does
local listeners = {}

local function changed()
	for _, callback in ipairs(listeners) do
		task.spawn(callback, openName)
	end
end

-- opens `name`; the menu already open (if another) is closed by its own function
function Menus.Open(name, close)
	if openName and openName ~= name then
		local previous = openClose
		openName, openClose = nil, nil
		if previous then
			previous()
		end
	end
	openName, openClose = name, close
	changed()
end

-- `name` closed (itself or by Open): forget it, if it's the one registered
function Menus.Close(name)
	if openName == name then
		openName, openClose = nil, nil
		changed()
	end
end

function Menus.IsOpen(name)
	return openName == name
end

-- `toggle()` opens or closes the menu, exactly as its key does
function Menus.Register(name, toggle)
	togglers[name] = toggle
end

function Menus.Toggle(name)
	local toggle = togglers[name]
	if toggle then
		toggle()
	end
end

-- true once a menu has registered its toggle (TopBar shows only those icons)
function Menus.Has(name)
	return togglers[name] ~= nil
end

-- calls `callback(openName or nil)` whenever the open menu changes
function Menus.OnChange(callback)
	table.insert(listeners, callback)
end

return Menus
