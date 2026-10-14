-- The one-menu rule: Inventory, Stats, Settings, Shop, Gallery, Quests and
-- Admin register here when they open (Menus.Open(name, closeFn)), which
-- closes whichever menu was open first. A menu calls Menus.Close(name)
-- whenever it closes itself (key, ×, Esc), so the next open starts clean.
local Menus = {}

local openName, openClose

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
end

-- `name` closed (itself or by Open): forget it, if it's the one registered
function Menus.Close(name)
	if openName == name then
		openName, openClose = nil, nil
	end
end

function Menus.IsOpen(name)
	return openName == name
end

return Menus
