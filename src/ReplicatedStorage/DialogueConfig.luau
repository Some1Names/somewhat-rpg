-- Every conversation with an NPC (the Dialogue module draws them). A tree is { speaker,
-- start, nodes }; a node is { text, choices?, next? }. A choice is { label, next?, action? }:
-- `action` is handed to whatever opened the talk (the Spawn Keeper's "set" and "clear" go
-- to SpawnServer, its "travel" opens the travel map), then `next` picks the node to show, or
-- ends the talk when it's missing.
-- A node with no choices shows a continue arrow and moves to its `next` (or ends).
-- A node or a choice can carry an `accent` (a key of DialogueConfig.Accents): a node tints its
-- rule, a choice its number key and, hovered, its words. Text may use <font color="#RRGGBB">
-- for a coloured word. Keep colour for the lines that matter (a spawn being set), not every line.
-- Lines marked PLACEHOLDER are lore stand-ins for the owner to rewrite.
local DialogueConfig = {}

DialogueConfig.Accents = {
	cyan = Color3.fromRGB(60, 224, 230),
}

DialogueConfig.Trees = {
	SpawnKeeper = {
		speaker = "Spawn Keeper",
		start = "greet",
		nodes = {
			greet = {
				text = "Easy there, traveller. You look like someone who keeps waking up in all the wrong places. Shall I fix that?",
				choices = {
					{ label = "Set my spawn here", action = "set", next = "set", accent = "cyan" },
					{ label = "Take me to another keeper", action = "travel" }, -- the map takes over
					{ label = "Clear my spawn", action = "clear", next = "clear" },
					{ label = "Who are you?", next = "lore" },
					{ label = "Goodbye", next = "bye" },
				},
			},
			set = {
				text = '<font color="#3CE0E6">Done.</font> Next time you fall, you\'ll wake up right here, under my watchful eye.',
				accent = "cyan",
				next = "more",
			},
			clear = {
				text = "Forgotten. You'll go back to the old starting grounds, wherever that was.",
				next = "more",
			},
			-- PLACEHOLDER lore
			lore = {
				text = "I keep the flame that remembers the fallen. Anyone who rests beside it gets carried back to it when their luck runs out. Don't ask what it costs.",
				next = "more",
			},
			more = {
				text = "Anything else?",
				choices = {
					{ label = "Set my spawn here", action = "set", next = "set", accent = "cyan" },
					{ label = "Take me to another keeper", action = "travel" },
					{ label = "Clear my spawn", action = "clear", next = "clear" },
					{ label = "Tell me about the flame", next = "lore" },
					{ label = "Goodbye", next = "bye" },
				},
			},
			bye = {
				text = "Stay alive out there. I'd hate to lose a regular.",
			},
		},
	},
}

return DialogueConfig
