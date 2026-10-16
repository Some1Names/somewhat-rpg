-- Where the hotbar's item slots (the grid on the right, keys 4 to 9) put their
-- Tools. A Tool can carry a HotbarSlot attribute (1 to 6) that claims a slot;
-- the Backpack's EQUIP sets it when you pick a free slot. Tools without one fill
-- the empty slots in the order they came. Pure rules (tests/HotbarRules.spec.luau
-- runs them outside Roblox); the Hotbar draws the layout, the Backpack shows the
-- free slots, and the server checks a claim against it.
local HotbarRules = {}

HotbarRules.Slots = 6
HotbarRules.Attribute = "HotbarSlot" -- on a Tool: the slot it claims

local function validSlot(slot, slots)
	return type(slot) == "number" and slot == math.floor(slot) and slot >= 1 and slot <= slots
end

-- `entries` is a list of { id =, slot = } in the order the Tools came (slot is nil
-- or a claimed slot). Returns a table slot -> id, with nils where it's empty. A
-- claimed slot is kept (the first claim wins a slot claimed twice); the rest
-- fill the empty slots from the first, and any that don't fit are left out.
function HotbarRules.Layout(entries, slots)
	slots = slots or HotbarRules.Slots
	local layout, placed = {}, {}
	for _, entry in ipairs(entries) do
		if validSlot(entry.slot, slots) and layout[entry.slot] == nil then
			layout[entry.slot] = entry.id
			placed[entry] = true
		end
	end
	local nextSlot = 1
	for _, entry in ipairs(entries) do
		if not placed[entry] then
			while nextSlot <= slots and layout[nextSlot] ~= nil do
				nextSlot += 1
			end
			if nextSlot > slots then
				break
			end
			layout[nextSlot] = entry.id
		end
	end
	return layout
end

-- the empty slots, in order
function HotbarRules.FreeSlots(entries, slots)
	slots = slots or HotbarRules.Slots
	local layout = HotbarRules.Layout(entries, slots)
	local free = {}
	for slot = 1, slots do
		if layout[slot] == nil then
			table.insert(free, slot)
		end
	end
	return free
end

-- whether a Tool of a skill set of this kind sits in the item grid (powers and weapons have
-- their own cards; `kind` is nil for a Tool that isn't a set's)
function HotbarRules.InGrid(kind)
	return kind ~= "power" and kind ~= "weapon"
end

return HotbarRules
