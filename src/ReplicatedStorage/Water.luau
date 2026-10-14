-- The map's water is Parts, not Terrain, so swimming in it is scripted (the
-- client's Swim script). Every water part is tagged "Water" in Studio and
-- made non-solid. This module answers whether a point is inside one of them
-- and where its surface is. The first two functions are plain maths
-- (tests/Water.spec.luau runs them outside Roblox); Find and IsIn read the
-- tagged parts and only run in the game.
local CFrame = CFrame or require("@lune/roblox").CFrame
local Vector3 = Vector3 or require("@lune/roblox").Vector3

local Water = {
	Tag = "Water", -- CollectionService tag on every water part
	SwimSpeed = 16, -- studs per second in water (normal walk speed)
	SurfaceOffset = 1.2, -- studs the root floats below the surface, head above
	RiseSpeed = 10, -- studs per second upwards while Space is held
}

-- whether `point` is inside the box of `size` at `cframe` (turned parts too),
-- the box grown by `grow` studs all round when given (a swimmer's exit margin)
function Water.inside(cframe, size, point, grow)
	local local_ = cframe:PointToObjectSpace(point)
	local half = size / 2 + Vector3.one * (grow or 0)
	return math.abs(local_.X) <= half.X and math.abs(local_.Y) <= half.Y and math.abs(local_.Z) <= half.Z
end

-- the height of the part's top face over `point`. The top face is whichever of
-- the six faces looks most upwards (a flipped or rolled part has its top on a
-- different side; the part's own top wins a tie); a tilted part's top slopes.
function Water.surfaceY(cframe, size, point)
	local best, bestLength
	for _, axis in ipairs({ { cframe.UpVector, size.Y }, { cframe.RightVector, size.X }, { cframe.LookVector, size.Z } }) do
		if not best or math.abs(axis[1].Y) > math.abs(best.Y) + 1e-4 then
			best, bestLength = axis[1], axis[2]
		end
	end
	local normal = best.Y >= 0 and best or -best
	local top = cframe.Position + normal * (bestLength / 2)
	if normal.Y < 1e-3 then
		return top.Y
	end
	return top.Y - (normal.X * (point.X - top.X) + normal.Z * (point.Z - top.Z)) / normal.Y
end

-- the part tagged Water that contains `point` (grown by `grow` studs, if given),
-- the one with the highest surface where two overlap; nil if none
function Water.Find(point, grow)
	local best, bestY
	for _, part in ipairs(game:GetService("CollectionService"):GetTagged(Water.Tag)) do
		if part:IsA("BasePart") and part:IsDescendantOf(workspace) and Water.inside(part.CFrame, part.Size, point, grow) then
			local y = Water.surfaceY(part.CFrame, part.Size, point)
			if not bestY or y > bestY then
				best, bestY = part, y
			end
		end
	end
	return best
end

-- whether the character's root is in water
function Water.IsIn(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and Water.Find(root.Position) ~= nil
end

return Water
