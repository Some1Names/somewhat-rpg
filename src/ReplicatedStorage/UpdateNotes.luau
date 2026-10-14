-- The "What's new" modal (UpdateNotes client): shown once to each player the
-- first time they join after `Version` changes. To announce an update, change
-- Version and the Sections below; everyone sees it again. The version a player
-- last saw is the saved SeenUpdate text (UpdateNotesServer).
local UpdateNotes = {}

UpdateNotes.Version = "wip 0.0.1"
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
		},
	},
	{
		"WORLD",
		{
			"Day and night: the sky now cycles through the day.",
			"Swimming: the water is deep enough to swim in.",
		},
	},
	{
		"INTERFACE",
		{
			"New layout: equipment cards bottom left, tool grid bottom right, key hints along the bottom.",
			"Settings (P): rebind your keys and switch effects and hints on or off.",
		},
	},
}

UpdateNotes.Footer = "This game is a work in progress. Things will change and break."

return UpdateNotes
