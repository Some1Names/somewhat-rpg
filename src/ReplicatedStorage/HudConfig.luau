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
-- above the cards sit the yen and the Quests / Stats / Inventory icons
HudConfig.YenHeight = 22
HudConfig.ClusterGap = 14 -- px between those icons and the cards
-- px from the screen's bottom to the top of that left column: panels that open on the left stay above it
HudConfig.LeftReserve = HudConfig.BottomReserve + HudConfig.CardHeight + HudConfig.ClusterGap + HudConfig.YenHeight + HudConfig.IconSizeOpen + HudConfig.SideGap + 10

-- the hub menu (Hub and its tabs): grey paper, black ink, one accent (the held
-- power's colour; NoPower when there's none), square everything
HudConfig.HubTheme = {
	Paper = Color3.fromRGB(228, 228, 226),
	Panel = Color3.fromRGB(210, 210, 208),
	BarBack = Color3.fromRGB(200, 200, 198), -- empty part of a progress bar
	Ink = Color3.fromRGB(20, 20, 20),
	Muted = Color3.fromRGB(119, 119, 119),
	Nav = Color3.fromRGB(42, 42, 42),
	NavText = Color3.fromRGB(238, 238, 238),
	NoPower = Color3.new(1, 1, 1),
	TitleFont = Enum.Font.GothamBlack,
	LabelFont = Enum.Font.GothamBold,
	BodyFont = Enum.Font.Gotham,
	NavWidth = 200,
	HeaderHeight = 74,
	FooterHeight = 30,
	PoseShare = 0.3, -- the posed character's strip, as a share of the screen's width
	PoseMinScreen = 1100, -- narrower screens hide the strip
}

HudConfig.Icons = {
	Settings = { image = "", glyph = "⚙" },
	Inventory = { image = "", glyph = "B" },
	Stats = { image = "", glyph = "M" },
	Quests = { image = "", glyph = "J" },
	Admin = { image = "", glyph = "A" },
}

return HudConfig
