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
HudConfig.HintsHeight = 24 -- the key hints line along the bottom edge
-- the bottom-left cards and bottom-right grid share one footprint
HudConfig.SideWidth = 168
HudConfig.SideHeight = 168
HudConfig.SideGap = 6
HudConfig.CardWidth = (HudConfig.SideWidth - 2 * HudConfig.SideGap) / 3 -- three tall cards
HudConfig.SlotWidth = (HudConfig.SideWidth - HudConfig.SideGap) / 2 -- a 2x3 grid
HudConfig.SlotHeight = (HudConfig.SideHeight - 2 * HudConfig.SideGap) / 3
-- px from the screen's bottom to the top of the key hints line, below everything else
HudConfig.BottomReserve = HudConfig.EdgeMargin + HudConfig.HintsHeight + 6

HudConfig.Icons = {
	Settings = { image = "", glyph = "⚙" },
	Inventory = { image = "", glyph = "B" },
	Stats = { image = "", glyph = "M" },
	Quests = { image = "", glyph = "J" },
	Admin = { image = "", glyph = "A" },
}

return HudConfig
