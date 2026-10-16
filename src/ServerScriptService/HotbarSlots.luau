-- What the server knows about the hotbar's item grid (keys 4 to 9): which Tools
-- are in it and which slots are free, using the same rules as the Hotbar and the
-- Backpack (HotbarRules). Equipping a consumable or briefcase picks a free slot
-- and claims it with the Tool's HotbarSlot attribute.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HotbarRules = require(ReplicatedStorage:WaitForChild("HotbarRules"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local HotbarSlots = {}

-- the Tools in the item grid (not a power or weapon set's), claimed slots first, in a steady order
local function gridTools(player)
	local found = {}
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		for _, tool in ipairs(container and container:GetChildren() or {}) do
			if tool:IsA("Tool") then
				local setName = tool:GetAttribute("SkillSet")
				local set = setName and SkillSetConfig.Sets[setName]
				if HotbarRules.InGrid(set and set.kind) then
					table.insert(found, tool)
				end
			end
		end
	end
	table.sort(found, function(a, b)
		local slotA, slotB = a:GetAttribute(HotbarRules.Attribute) or math.huge, b:GetAttribute(HotbarRules.Attribute) or math.huge
		if slotA ~= slotB then
			return slotA < slotB
		end
		return a.Name < b.Name
	end)
	return found
end

local function entries(player)
	local list = {}
	for _, tool in ipairs(gridTools(player)) do
		table.insert(list, { id = tool, slot = tool:GetAttribute(HotbarRules.Attribute) })
	end
	return list
end

-- the free slots, in order
function HotbarSlots.Free(player)
	return HotbarRules.FreeSlots(entries(player))
end

-- the slot to use: `wanted` if it's free, or the first free one when `wanted` is nil; nil if there is none
function HotbarSlots.Pick(player, wanted)
	local free = HotbarSlots.Free(player)
	if wanted == nil then
		return free[1]
	end
	return table.find(free, wanted) and wanted or nil
end

return HotbarSlots
