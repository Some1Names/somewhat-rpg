-- The Handbook's pages (Handbook client): short how-tos for the game's systems. Numbers are
-- copied from the configs they describe (ReforgeConfig, StatConfig, PowerConfig ...), so when
-- one of those changes, change the line here too. Each topic is
--   { id, title, summary, sections = { { heading, { "Name: info", ... } } } }
-- A line "Name: info" shows its Name as a coloured sub-heading; a line without one is plain text.
-- A section can carry a `visual` drawn at the top of its card (Handbook client):
--   keys     { kind, items = { { "Z", "Skill 1" } ... } }       key chips
--   flow     { kind, steps = { "Kill", "Orb" ... } }             boxes joined by arrows
--   bars     { kind, caption, items = { { label, value, max } } } filled bars
--   chips    { kind, items = { { name, info, rgb } ... } }       small labelled tiles
--   ladder   { kind }                                            the reforge levels, from ReforgeConfig
--   stages   { kind }                                            the awakening stages, from ReforgeConfig
--   example  { kind, title, lines = { ... } }                    a worked example in a framed box
local HandbookConfig = {}

HandbookConfig.Topics = {
	{
		id = "Basics",
		title = "GETTING STARTED",
		summary = "Moving, fighting and the menus, in one page.",
		sections = {
			{
				"CONTROLS",
				visual = {
					kind = "keys",
					items = {
						{ "Z", "Skill 1" }, { "X", "Skill 2" }, { "C", "Skill 3" }, { "V", "Skill 4" }, { "T", "Ultimate" },
						{ "G", "Passive" }, { "Q", "Dash" }, { "F", "Block" }, { "M", "Menu" }, { "Tab", "Players" },
						{ "Shift", "Sprint" }, { "Alt", "Free camera" },
					},
				},
				{
					"Skills: Z, X, C and V are your four skills, T casts the ultimate, for sets that have one. G is a set's passive ability. F blocks, for sets and weapons that can. All of them can be moved in Settings.",
					"Dash: press Q to dash the way you are moving (forward if you are standing still), and keep pressing to chain dashes while you have dodge charges. The dash is also your dodge: a hit that lands while you are dashing misses you.",
					"Melee: click to swing. Swings cost stamina and slow your walk while you swing.",
					"Menus: M opens the menu (Q and E switch its tabs), Tab shows the player list. Hold Shift to sprint (Settings can make it a toggle) and hold Alt to free the camera and mouse. Menus hold you still, so close them before a fight.",
				},
			},
			{
				"LEVELLING",
				visual = {
					kind = "flow",
					steps = { "Kill enemies", "Gain XP", "Level up", "Spend points in Stats" },
				},
				{
					"Experience: kill enemies and finish bounties to level up. Each level gives points to spend in Stats.",
					"Yen: the money at the top right. Spend it at the shop and the smith.",
				},
			},
		},
	},
	{
		id = "Powers",
		title = "POWERS",
		summary = "How you get a power and what to do with spares.",
		sections = {
			{
				"HOLDING POWERS",
				visual = {
					kind = "chips",
					items = {
						{ "HELD", "The power you cast. 1 slot.", { 255, 205, 60 } },
						{ "STORAGE 1", "A spare power.", { 170, 170, 175 } },
						{ "STORAGE 2", "A spare power.", { 170, 170, 175 } },
					},
				},
				{
					"One held power: only the power you hold can be cast, and its colour becomes the colour of your menus.",
					"Storage: two spare powers can wait in storage until you want to switch.",
					"Dying: a power can drop when you are defeated, so don't carry what you can't lose.",
				},
			},
			{
				"GETTING THEM",
				visual = {
					kind = "chips",
					items = {
						{ "GACHA", "Free roll every 2 hours", { 170, 110, 230 } },
						{ "DEALER", "Buy with yen", { 255, 205, 60 } },
						{ "WORLD", "Map drops", { 70, 140, 255 } },
						{ "ROBUX", "Lifetime power", { 230, 60, 60 } },
					},
				},
				{
					"Power Gacha: a free roll every 2 hours.",
					"Power Dealer: buy a power with yen.",
					"Lifetime powers: some powers can be bought with Robux and are yours for good.",
				},
			},
			{
				"WEAPONS",
				{
					"Weapons are not powers. The revolver and the katana have their own slots on the hotbar, and some need points in a stat before you can use them.",
				},
			},
		},
	},
	{
		id = "Stats",
		title = "STATS AND TALENTS",
		summary = "Spend level points, then pick talents that fit your build.",
		sections = {
			{
				"STATS",
				visual = {
					kind = "bars",
					caption = "EXAMPLE: LEVEL 100 (75 POINTS IN ONE STAT AT MOST)",
					items = {
						{ "Vitality", 75, 75 }, { "Strength", 75, 75 }, { "Agility", 75, 75 },
						{ "Willpower", 75, 75 }, { "Superliminal", 0, 75 }, { "Firearm", 0, 75 },
					},
				},
				{
					"Six stats: Vitality (health), Strength, Superliminal, Firearm, Agility and Willpower.",
					"The cap: one stat can hold at most a quarter of your level points, so you can max four of the six. Plan your build.",
					"Requirements: some powers and weapons need points in a stat before their skills work.",
				},
			},
			{
				"TALENTS",
				visual = {
					kind = "flow",
					steps = { "15 points: tier 1", "30 points: tier 2", "50 points: tier 3" },
				},
				{
					"Tiers: a talent tier opens at 15, 30 and 50 points in its stat.",
					"Slots: you gain 1 talent point every 5 levels, and equipping a talent costs talent points.",
					"If you drop below a stat's points, talents that need them are taken off.",
				},
			},
		},
	},
	{
		id = "Drops",
		title = "DROPS AND MATERIALS",
		summary = "Where upgrade materials come from.",
		sections = {
			{
				"ORBS",
				visual = {
					kind = "flow",
					steps = { "Enemy dies", "Orb drops", "Yours for 30 s", "Anyone after", "Walk into it" },
				},
				{
					"Enemies drop orbs for every player who dealt at least 10% of their health. Orbs are yours alone for 30 seconds, then anyone can take them.",
					"Walk into an orb to pick it up. The pickup feed above your yen shows what you got.",
				},
			},
			{
				"MATERIALS",
				visual = {
					kind = "chips",
					items = {
						{ "SCRAP", "Common. +1 to +3", "Scrap" },
						{ "CORE", "Rare. +4 to +6", "Core" },
						{ "CRYSTAL", "Gold. +7 to +9", "Crystal" },
						{ "ESSENCE", "Dark. +10 and awakening", "Essence" },
					},
				},
				{
					"Four grades: Scrap, Core, Crystal and Essence, from common to rare. The smith spends them.",
					"Rare drops: tougher enemies and raid bosses drop the better grades, and some drop talismans.",
					"Yen chests: walk over a chest in the world for yen, and sometimes a talisman. They return after 45 seconds.",
				},
			},
			{
				"TALISMANS",
				{
					"Wear up to 3. The slots open at levels 0, 15 and 40. See them in Backpack, Talisman.",
				},
			},
		},
	},
	{
		id = "Reforge",
		title = "REFORGING",
		summary = "Level up a power or weapon at the smith and choose its affinities.",
		sections = {
			{
				"HOW TO",
				visual = {
					kind = "flow",
					steps = { "Gather materials", "Go to the smith", "Pick a skill set", "Pay materials and yen", "+1 level" },
				},
				{
					"Find a smith: stand within 14 studs of the smith and use the prompt to open the Reforge menu.",
					"Pick what to reforge: any skill set you own, power or weapon, has its own level and affinities.",
					"Level up: every level costs materials and yen and adds 4% damage, up to +10.",
				},
			},
			{
				"LEVEL COSTS",
				visual = { kind = "ladder" },
				{
					"+1 to +3: Scrap (10, 15, 20) and 200 yen each.",
					"+4 to +6: Core (5, 8, 12) and 1,000 yen each.",
					"+7 to +9: Crystal (3, 5, 8) and 5,000 yen each.",
					"+10: 3 Essence and 20,000 yen.",
				},
			},
			{
				"AFFINITIES",
				visual = {
					kind = "chips",
					items = {
						{ "MIGHT", "More damage", { 230, 90, 70 } },
						{ "SWIFT", "Shorter cooldowns", { 90, 200, 255 } },
						{ "SEARING", "Burn on hit", { 255, 150, 50 } },
						{ "RENDING", "Bleed on hit", { 210, 40, 70 } },
						{ "VENOM", "Poison on hit", { 120, 220, 90 } },
						{ "SAPPING", "Weaken on hit", { 170, 130, 230 } },
						{ "VAMPIRIC", "Heal from damage", { 240, 80, 160 } },
					},
				},
				{
					"Slots: two. The first opens at +3, the second at +7.",
					"Choosing or changing one costs materials and yen: slot 1 is 3 Core and 500 yen, slot 2 is 3 Crystal and 2,500 yen.",
					"Might: more damage. Swift: shorter skill cooldowns.",
					"Searing, Rending, Venom and Sapping: a chance on a hit to burn, bleed, poison or weaken. Vampiric: heal for a share of the damage.",
					"Their strength grows with the level, from the small value at +0 to the largest at +10.",
					"Against players, the reforge damage bonus counts for half.",
				},
			},
		},
	},
	{
		id = "Awakening",
		title = "AWAKENING",
		summary = "The step after +10: awaken a power up to three times.",
		sections = {
			{
				"REQUIREMENTS",
				{
					"A power at +10: only powers awaken. Weapons can't.",
					"Where: the smith, the same place as reforging.",
				},
			},
			{
				"STAGES",
				visual = { kind = "stages" },
				{
					"Awakening 1: 5 Essence and 50,000 yen.",
					"Awakening 2: 8 Essence and 100,000 yen.",
					"Awakening 3: 12 Essence and 200,000 yen.",
				},
			},
			{
				"WHAT YOU GET",
				visual = {
					kind = "example",
					title = "EXAMPLE: A FULLY BUILT POWER",
					lines = {
						"+10 reforge level: 10 x 4% = +40% damage.",
						"3 awakenings: 3 x 6% = +18% more.",
						"Total: +58% damage, and each affinity 30% stronger.",
						"Total cost: 25 Essence and 350,000 yen for the awakenings alone.",
						"Against players the bonus counts for half.",
					},
				},
				{
					"Damage: +6% for each stage.",
					"Affinities: 10% stronger for each stage.",
					"Essence is the rarest drop, so save it for the power you will keep.",
				},
			},
		},
	},
	{
		id = "Quests",
		title = "BOUNTIES AND MASTERY",
		summary = "Work for rewards and learn a set's moves.",
		sections = {
			{
				"BOUNTIES",
				visual = {
					kind = "flow",
					steps = { "Talk to a Bounty Hunter", "Take a bounty", "Follow the Compass", "Defeat the target", "Collect the reward" },
				},
				{
					"Find a Bounty Hunter NPC and take a bounty. Open Quests with J to follow it. The Compass at the top points to the nearest target.",
				},
			},
			{
				"MASTERY",
				{
					"Every skill set has its own mastery. It grows from hits, kills and training dummies, and unlocks the set's higher skills.",
					"Each set also has mastery challenges in the Quests tab.",
				},
			},
		},
	},
	{
		id = "Groups",
		title = "FACTIONS AND PARTIES",
		summary = "Join a side and team up with friends.",
		sections = {
			{
				"FACTIONS",
				visual = {
					kind = "flow",
					steps = { "Find a Recruiter", "Press JOIN", "Earn standing from kills", "Rank up" },
				},
				{
					"Join: talk to a Faction Recruiter and press JOIN.",
					"Standing: grows from kills. Your rank name shows over your head, and your faction gives a shop discount.",
				},
			},
			{
				"PARTIES",
				{
					"Open the Party tab in the hub to invite players. Party mates show on your Compass and the Map, even from far away.",
				},
			},
		},
	},
	{
		id = "Raids",
		title = "RAID BOSSES",
		summary = "Big fights that need a group.",
		sections = {
			{
				"THE BOSSES",
				visual = {
					kind = "chips",
					items = {
						{ "HIDE SETO", "Mandela. Level 90", { 90, 220, 120 } },
						{ "AYATO YOJI", "Iridescent Requiem. Level 95", { 255, 154, 60 } },
					},
				},
				{
					"Hide Seto: Mandela, level 90. He appears on a timer at his arena.",
					"Ayato Yoji: Iridescent Requiem, level 95. He flies, and his ultimate needs everyone inside the safe domes.",
				},
			},
			{
				"TIPS",
				visual = {
					kind = "flow",
					steps = { "Red warning appears", "Dash out (Q)", "Hit the boss", "Repeat" },
				},
				{
					"Ground warnings: red shapes on the floor show where the next attack lands. Dash out of them.",
					"Grabs: if a boss grabs you, follow the prompt on screen to break out.",
					"Bring a party: bosses have several phases and a lot of health.",
				},
			},
		},
	},
}

function HandbookConfig.Find(id)
	for _, topic in ipairs(HandbookConfig.Topics) do
		if topic.id == id then
			return topic
		end
	end
	return nil
end

return HandbookConfig
