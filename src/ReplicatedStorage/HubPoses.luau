-- The poses of the character drawn over the hub (HubPose). Each pose turns R6
-- joints by x, y, z degrees in the torso's space, about the joint: +x raises a
-- limb forward, +z swings it toward the character's right, +y turns it to the
-- character's left. Joints left out stay straight. Tune by eye; each tab names
-- its pose in Hub.Tab, and "Random" (Profile) picks one of RandomPool per open.
local HubPoses = {}

HubPoses.Poses = {
	Idle = {},
	-- two arms up as a guard, half turned
	Guard = {
		RootJoint = Vector3.new(0, 15, 0),
		Neck = Vector3.new(0, -15, 0),
		["Right Shoulder"] = Vector3.new(80, 0, -20),
		["Left Shoulder"] = Vector3.new(30, 0, -45),
		["Right Hip"] = Vector3.new(20, 0, 0),
		["Left Hip"] = Vector3.new(-10, 0, 0),
	},
	-- leaning to one side, an arm across
	Lean = {
		RootJoint = Vector3.new(10, 0, 20),
		Neck = Vector3.new(0, 0, -15),
		["Right Shoulder"] = Vector3.new(70, 0, -30),
		["Left Hip"] = Vector3.new(0, 0, -10),
	},
	-- wide stance, one arm out
	Wide = {
		RootJoint = Vector3.new(0, -15, 0),
		Neck = Vector3.new(0, 10, 0),
		["Right Shoulder"] = Vector3.new(0, 0, 80),
		["Left Shoulder"] = Vector3.new(40, 0, 0),
		["Right Hip"] = Vector3.new(0, 0, 15),
		["Left Hip"] = Vector3.new(35, 0, -10),
	},
	-- arms crossed
	Crossed = {
		RootJoint = Vector3.new(0, 20, 0),
		Neck = Vector3.new(-5, 0, 0),
		["Right Shoulder"] = Vector3.new(90, 0, -45),
		["Left Shoulder"] = Vector3.new(110, 0, 40),
	},
}

HubPoses.RandomPool = { "Guard", "Lean", "Wide", "Crossed" }

return HubPoses
