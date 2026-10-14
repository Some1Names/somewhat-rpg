-- Numbers and icon images the HUD scripts share: the top-right icon row
-- (TopBar), the kill feed that sits under it, the bottom-left key hints, and
-- the Hotbar's equipment cards and tool grid.
-- `image` is a Roblox asset id ("rbxassetid://123"); until the owner picks
-- images it stays "" and TopBar shows the text `glyph` instead.
local HudConfig = {}

HudConfig.TopMargin = 12 -- px from the top of the screen to the icon row
HudConfig.EdgeMargin = 16 -- px from the screen's edges
HudConfig.IconSize = 28
HudConfig.IconSizeOpen = 32 -- the icon whose menu is open
HudConfig.KillFeedTop = 56 -- the kill feed starts under the icon row
HudConfig.SlotSize = 52 -- a square tool slot in the bottom-right grid
HudConfig.CardWidth = 62 -- the three tall equipment cards at the bottom left
HudConfig.CardHeight = 112

HudConfig.Icons = {
	Settings = { image = "", glyph = "⚙" },
	Inventory = { image = "", glyph = "B" },
	Stats = { image = "", glyph = "M" },
	Quests = { image = "", glyph = "J" },
	Admin = { image = "", glyph = "A" },
}

return HudConfig
