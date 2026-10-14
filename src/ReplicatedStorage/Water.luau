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

-- whether `point` is inside the box of `size` at `cframe` (turned parts too)
function Water.inside(cframe, size, point)
	local local_ = cframe:PointToObjectSpace(point)
	local half = size / 2
	return math.abs(local_.X) <= half.X and math.abs(local_.Y) <= half.Y and math.abs(local_.Z) <= half.Z
end

-- the height of the part's top face over `point` (a tilted part's top slopes)
function Water.surfaceY(cframe, size, point)
	local up = cframe.UpVector
	local top = cframe.Position + up * (size.Y / 2)
	if up.Y < 1e-3 then
		return top.Y
	end
	return top.Y - (up.X * (point.X - top.X) + up.Z * (point.Z - top.Z)) / up.Y
end

-- a part tagged Water that contains `point`, if any
function Water.Find(point)
	for _, part in ipairs(game:GetService("CollectionService"):GetTagged(Water.Tag)) do
		if part:IsA("BasePart") and part:IsDescendantOf(workspace) and Water.inside(part.CFrame, part.Size, point) then
			return part
		end
	end
	return nil
end

-- whether the character's root is in water
function Water.IsIn(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and Water.Find(root.Position) ~= nil
end

return Water
