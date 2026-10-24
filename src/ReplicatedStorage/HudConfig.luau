-- Numbers and icon images the HUD scripts share: the top-right icon row
-- (TopBar), the kill feed that sits under it, the one-line key hints along the
-- bottom right, and the Hotbar's equipment cards (left) and tool grid (right).
-- `image` is a Roblox asset id ("rbxassetid://123"); until the owner picks
-- images it stays "" and TopBar shows the text `glyph` instead.
local HudConfig = {}

HudConfig.TopMargin = 12 -- px from the top of the screen to the icon row
HudConfig.EdgeMargin = 16 -- px from the screen's edges
HudConfig.IconSize = 28
HudConfig.IconSizeOpen = 32 -- the icon whose menu is open
HudConfig.KillFeedTop = 56 -- the kill feed starts under the icon row
HudConfig.HintsHeight = 18 -- the key hints line along the bottom edge
-- the bottom-left cards and bottom-right grid share one footprint: the grid is
-- 3 columns of square slots by 2 rows, and the three tall cards fill the same box
HudConfig.SideWidth = 258
HudConfig.SideGap = 6
HudConfig.SlotWidth = (HudConfig.SideWidth - 2 * HudConfig.SideGap) / 3
HudConfig.SlotHeight = HudConfig.SlotWidth
HudConfig.SideHeight = 2 * HudConfig.SlotHeight + HudConfig.SideGap
HudConfig.CardWidth = HudConfig.SlotWidth
HudConfig.CardHeight = HudConfig.SideHeight
-- px from the screen's bottom to the bottom of the cards and grid: the key hints line plus a gap
HudConfig.BottomReserve = HudConfig.EdgeMargin + HudConfig.HintsHeight + 18
-- above the cards sits the yen
HudConfig.YenHeight = 22
HudConfig.ClusterGap = 14 -- px between the yen and the cards
-- px from the screen's bottom to the top of that left column: panels that open on the left stay above it
HudConfig.LeftReserve = HudConfig.BottomReserve + HudConfig.CardHeight + HudConfig.ClusterGap + HudConfig.YenHeight + 10

-- the compass strip up in Roblox's top bar row (Compass): the degrees it shows and its size
HudConfig.CompassSpan = 180
HudConfig.CompassWidth = 420
HudConfig.CompassHeight = 36
-- the combo counter (ComboCounter): seconds after a hit before it ends, the fewest
-- hits it shows, and its colour from each count up
HudConfig.ComboWindow = 3
HudConfig.ComboMin = 2
HudConfig.ComboTiers = {
	{ from = 0, color = Color3.new(1, 1, 1) },
	{ from = 10, color = Color3.fromRGB(255, 205, 60) },
	{ from = 25, color = Color3.fromRGB(255, 80, 70) },
}
-- the red screen edges (LowHealth): they start below this share of max health and
-- pulse below the second
HudConfig.LowHealthStart = 0.3
HudConfig.LowHealthPulse = 0.15

-- the hub menu (Hub and its tabs): near-black paper, light ink, one accent (the held
-- power's colour; NoPower when there's none), square everything
HudConfig.HubTheme = {
	Paper = Color3.fromRGB(20, 20, 23),
	Panel = Color3.fromRGB(50, 50, 58), -- cards
	BarBack = Color3.fromRGB(80, 80, 90), -- empty part of a progress bar
	Ink = Color3.fromRGB(236, 236, 238), -- text, and the fill of an ink button
	Muted = Color3.fromRGB(190, 190, 198),
	Nav = Color3.fromRGB(9, 9, 11),
	NavText = Color3.fromRGB(238, 238, 238),
	NoPower = Color3.new(1, 1, 1),
	TitleFont = Enum.Font.Highway,
	LabelFont = Enum.Font.Highway,
	BodyFont = Enum.Font.Highway,
	NavWidth = 200,
	HeaderHeight = 74,
	FooterHeight = 30,
	PoseShare = 0.3, -- the posed character's strip, as a share of the screen's width
	PoseMinScreen = 1100, -- narrower screens hide the strip
}

HudConfig.Icons = {
	Settings = { image = "", glyph = "⚙" },
	Hub = { image = "", glyph = "▦" }, -- not ≡: that is Roblox's own menu
	Admin = { image = "", glyph = "A" },
}

return HudConfig
