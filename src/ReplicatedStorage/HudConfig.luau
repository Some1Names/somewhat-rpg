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
	{ from = 5, color = Color3.fromRGB(255, 238, 140) },
	{ from = 10, color = Color3.fromRGB(255, 205, 60) },
	{ from = 20, color = Color3.fromRGB(255, 140, 50) },
	{ from = 30, color = Color3.fromRGB(255, 80, 70) },
	{ from = 50, color = Color3.fromRGB(255, 70, 190) },
	{ from = 75, color = Color3.fromRGB(190, 110, 255) },
}
-- the red screen edges (LowHealth): they start below this share of max health and
-- pulse below the second
HudConfig.LowHealthStart = 0.3
HudConfig.LowHealthPulse = 0.15

-- the hub menu (Hub and its tabs): Modern Warfare's smoked glass over the blurred world
-- (see-through dark cards with a thin light edge, a narrow rail on the far left, numbered
-- entries, key chips) with the Arknights editorial bits kept (#TITLE and its bar, the
-- swatches, the #SOMEWHAT chip). Light ink, one accent (the held power's colour; NoPower
-- when there's none), square everything
HudConfig.HubTheme = {
	Paper = Color3.fromRGB(12, 13, 15),
	Panel = Color3.fromRGB(30, 32, 36), -- cards: Hub draws every one of these as smoked glass
	PanelTransparency = 0.3,
	Edge = Color3.new(1, 1, 1), -- the thin edge round a card
	EdgeTransparency = 0.82,
	BarBack = Color3.fromRGB(80, 80, 90), -- empty part of a progress bar
	Ink = Color3.fromRGB(236, 236, 238), -- text, and the fill of an ink button
	Muted = Color3.fromRGB(170, 172, 178),
	Nav = Color3.fromRGB(9, 9, 11),
	NavText = Color3.fromRGB(238, 238, 238),
	NoPower = Color3.new(1, 1, 1),
	TitleFont = Enum.Font.Oswald, -- condensed uppercase headings
	LabelFont = Enum.Font.Highway,
	BodyFont = Enum.Font.Highway,
	MonoFont = Enum.Font.RobotoMono, -- numbers: 01, LVL 55, 2/3
	RailWidth = 52, -- the far-left rail (level, swatches, ×); the nav's list is the rest of NavWidth
	NavWidth = 240,
	HeaderHeight = 74,
	FooterHeight = 30,
	PoseShare = 0.3, -- the posed character's strip, as a share of the screen's width
	PoseMinScreen = 1100, -- narrower screens hide the strip
}

-- the HUD's Modern Warfare look, shared by the HUD scripts: condensed uppercase headings
-- and big numbers, mono figures, and key prompts as small see-through boxes with a thin
-- white edge (KeyHints, SkillBar, Hotbar, QuestBoard ...)
HudConfig.Style = {
	TitleFont = Enum.Font.Oswald,
	MonoFont = Enum.Font.RobotoMono,
	LabelFont = Enum.Font.Highway,
	ChipBack = Color3.new(0, 0, 0),
	ChipBackTransparency = 0.55,
	ChipEdgeTransparency = 0.35,
	Glass = Color3.fromRGB(12, 13, 15), -- a HUD panel's smoked glass
	GlassTransparency = 0.45,
	EdgeTransparency = 0.8, -- a panel's thin white edge
}

-- a normal hit's damage number by the Damage number colour setting (Preferences' DmgColor,
-- same order: RED, WHITE, ORANGE, CYAN); critical hits stay gold (HitFeedback)
HudConfig.DamageNumberColors = {
	{ text = Color3.fromRGB(255, 90, 60), outline = Color3.fromRGB(40, 0, 0) },
	{ text = Color3.fromRGB(255, 255, 255), outline = Color3.fromRGB(30, 30, 34) },
	{ text = Color3.fromRGB(255, 150, 40), outline = Color3.fromRGB(50, 20, 0) },
	{ text = Color3.fromRGB(90, 220, 255), outline = Color3.fromRGB(0, 30, 45) },
}

-- numbers for a hit another player (not you) landed (HitFeedback): grey, light yellow on a crit
HudConfig.OtherPlayerDamageColor = { text = Color3.fromRGB(175, 175, 180), outline = Color3.fromRGB(25, 25, 28) }
HudConfig.OtherPlayerCritColor = { text = Color3.fromRGB(255, 240, 160), outline = Color3.fromRGB(60, 50, 0) }

-- the Colour filter setting (Preferences' Filter, same order after OFF): a ColorCorrection
-- over the world (ScreenSettings). Roblox can't remap one colour onto another, so these
-- only lean the balance away from the colours each kind of colourblindness mixes up and
-- push saturation and contrast: an approximation, not a correction
HudConfig.ColourFilters = {
	PROTANOPIA = { tint = Color3.fromRGB(255, 236, 214), saturation = 0.35, contrast = 0.12 },
	DEUTERANOPIA = { tint = Color3.fromRGB(255, 226, 236), saturation = 0.35, contrast = 0.12 },
	TRITANOPIA = { tint = Color3.fromRGB(236, 246, 255), saturation = 0.3, contrast = 0.12 },
}

HudConfig.Icons = {
	Settings = { image = "", glyph = "⚙" },
	Hub = { image = "", glyph = "▦" }, -- not ≡: that is Roblox's own menu
	Admin = { image = "", glyph = "A" },
}

return HudConfig
