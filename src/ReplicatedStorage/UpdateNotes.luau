-- The "What's new" modal (UpdateNotes client): shown once to each player the
-- first time they join after `Version` changes. To announce an update, change
-- Version and the Sections below; everyone sees it again. The version a player
-- last saw is the saved SeenUpdate text (UpdateNotesServer).
local UpdateNotes = {}

UpdateNotes.Version = "wip 0.0.2"
UpdateNotes.Title = "WHAT'S NEW"

-- { heading, { lines } }
UpdateNotes.Sections = {
	{
		"NEW",
		{
			"Spawn Keeper: hold the prompt on the Spawn Keeper beside the spawn to respawn there.",
			"Enemy drops: enemies drop material orbs for the players who hurt them. Pick them up and spend them at the smith.",
			"Powers: hold one power, keep two in storage. Roll the Power Gacha (a free roll every 2 hours) or buy from the Power Dealer.",
			"Reforge: the smith levels up your skill sets and rerolls their modifiers.",
			"Bounties and mastery challenges: find a Bounty Hunter, open Quests with J.",
			"Aido (Deus Ex Machina): a new glass cannon power. Huge blasts, Final Cut (press F again to end it) and Atomic Breath, but it takes 35% more damage.",
			"Talismans: wear up to 3 (slots open at levels 0, 15 and 40). Find them in yen chests; see them in Backpack > Talisman.",
			"Yen chests: chests are out in the world. Walk over one for yen, and sometimes a talisman. They come back after 45 seconds.",
			"Consumables: items you can use, kept in your Backpack and equipped onto the hotbar slots. Buy them at the shop.",
			"Sound effects: melee, the revolver, every power's moves, menus, equipping, the shop and critical hits.",
			"Deaths: players and enemies now fade away in a burst of particles.",
			"Leaderboard: the player list shows each player's yen. The grey team is gone.",
		},
	},
	{
		"POWERS AND COMBAT",
		{
			"Mandela: V is a shockwave that mutes, marks and erases skills, and F applies Weakened.",
			"Out-of-combat timer: the last 10 seconds show on screen.",
			"Photoshop and Iridescent Requiem: new domes and effects, a reworked Kaleidoscope, new bursts and buffs.",
			"Prism Form: a trail of spectrum light follows the body and burns anyone in it.",
			"Melee: swings aim where the camera looks, and the hitboxes are bigger.",
			"Block and posture are switched off for now.",
		},
	},
	{
		"WORLD",
		{
			"Day and night: the sky now cycles through the day, with a brighter dawn, dusk and moonlit night.",
			"Swimming: the water is deep enough to swim in.",
		},
	},
	{
		"INTERFACE",
		{
			"The hub: one full-screen menu for Profile, Backpack (B), Quests (J), Stats (M) and Updates, in a new dark style with a new font.",
			"Menu button in Roblox's top bar, next to the chat button.",
			"Menus hold you still: you can't walk, jump or fight while one is open.",
			"Shop: a close-up on the shopkeeper, and the BUY button greys out and says FULL when you can't carry more of an item.",
			"New layout: equipment cards bottom left, tool grid bottom right, key hints along the bottom.",
			"Settings (P): rebind your keys and switch effects and hints on or off.",
		},
	},
	{
		"FIXES",
		{
			"You could punch while a menu was open. Not any more.",
			"Spending a stat point on a maxed stat now plays the error sound.",
		},
	},
}

UpdateNotes.Footer = "This game is a work in progress. Things will change and break."

return UpdateNotes
