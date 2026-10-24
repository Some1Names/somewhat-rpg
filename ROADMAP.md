# Roadmap

What's left, as of 2026-10-14. Plans ready to run are listed in `docs/superpowers/plans/README.md`. **Cloud** = code-only, a cloud session can do it.
**Studio** = needs the local Studio connection (looking at effects, prefabs, uploads, playtests).

## Owner's VFX work: Iridescent Requiem revisual (and the Photoshop revisual)

Done: X Prism Form, V Solar Lance, F Below the Stratus / Above the Cumulonimbus (with the new
particle pack, `VFXPrefabs.Iridescent`). Left, one skill at a time, owner picks the look:

- **Z Prism Shot**: hand prism, split beams, Sunmark. (Studio)
- **C Refraction Field**: floating crystals still break with the old shard shatter (`PrismBreak`);
  could use the light slivers (`FORM_SLIVERS`) like Prism Form's exit. (Studio)
- **Q Lightstep** (dash): glimpse/fade and light trail. (Studio)

The workflow so far: describe the current particles and weak spots, the owner says what to change,
reuse `FORM_*` textures, `sunShaft`, `lyingFlat` and pack prefabs, check with frozen screenshots.

## Visual polish still open

- Pack `Workspace."Particle effects".Blood` is unused: candidate for the Knife pin and Bleeding. (Studio)
- VFX redesign part 4: Revolver hits/shots and remaining basic-combat visuals. (Studio)

## New skill sets (owner's manga roster)

Design with the owner first (questions, then a written spec), then build. (Cloud for design and
server code; Studio for visuals, animations, models.)

1. **Aido** (Furukiwa Aido, The Director; his power is named **Deus Ex Machina**; S power, red, atomic): **code built, waiting on Studio** (branch
   `claude/vigilant-rubin-ckqtnn`), spec `docs/superpowers/specs/2026-10-09-aido-design.md`, plan
   `docs/superpowers/plans/2026-10-09-aido.md` (tasks 1-10 done; task 11, applying it to Studio, is left),
   checklist `docs/superpowers/specs/2026-10-09-aido-checklist.md`. Placeholder visuals. Fuse, Z Catastrophe, X Collapse, C Total Destruction, V Ground Zero, F Final Cut
   (dragon form), G Chain Reaction, passive Half-Life (Fallout, Burnt). Later in Studio: the dragon
   model, `AidoAnimations`, VFX packs.
2. **Photoshop** (Nozomi, S power, pink / light blue): **in Studio** from branch
   `claude/vigilant-rubin-ckqtnn` (spec and plans in `docs/superpowers/`), with its `Photoshop`
   Tool in `ServerStorage.SkillSetTools`. Punches (a Superliminal 4-hit combo) and Step In's
   3-punch combo are done and checked in Studio; the rest of
   `docs/superpowers/specs/2026-10-08-photoshop-checklist.md` still needs a playtest. Next: the
   revisual with imported VFX packs (`docs/superpowers/plans/2026-10-09-photoshop-revisual.md`,
   needs the owner's OK on packs). Optional: wearables (`ServerStorage.SkillSets.Photoshop`) and
   `ReplicatedStorage.PhotoshopAnimations` (CastZ, CastX, CastC, CastV, CastF). Later: a "named
   areas" tab for the Gallery once the map has area markers.
3. Later: Himaru (S power), Daemon (A power) + Daemon's katana (A weapon, shop item),
   Kintsugi (B power), Monotwister (Aido's katana, S weapon).

Infrastructure these need: a `weapon` kind with a katana combo, the reserved MELEE inventory slot,
and saved ownership + loadout (`Loadout` is session-only today).

## Combat depth ("deeper than Blox Fruits, simpler than Deepwoken")

- **Block and posture: switched OFF** (owner: too much; `GuardConfig.Enabled = false`, code kept, set it to true to bring it back). Was: on Alt (moved from E; parry dropped for now), **built and in Studio** (synced 2026-10-13), spec
  `docs/superpowers/specs/2026-10-09-block-parry-design.md`, plan `docs/superpowers/plans/2026-10-09-block-parry.md`.
  Waiting on a two-player playtest with
  `docs/superpowers/specs/2026-10-09-block-parry-checklist.md`. Later: a parry layer in `Guard.Resolve`.
- **Death stakes and the Headhunter** (dropped yen, the kill leader mark): **built and in Studio**
  (checked solo); the 2–3 player half of `docs/superpowers/specs/2026-10-09-death-stakes-checklist.md`
  needs a live server.
- **More ways to earn mastery** (PvP, kill bonus, training dummies to 10): **built and in Studio**, spec
  `docs/superpowers/specs/2026-10-09-mastery-sources-design.md`, plan
  `docs/superpowers/plans/2026-10-09-mastery-sources.md`, checklist
  `docs/superpowers/specs/2026-10-09-mastery-sources-checklist.md`. The training dummies carry the `TrainingDummy` tag. Mastery challenges are the quest system's (built); boss mastery belongs to
  the boss and enemy rework.
- **Mastery unlocks per power** (own skill levels; passives, G, Lightstep, the Gallery by mastery):
  **built and in Studio** (synced 2026-10-14), spec `docs/superpowers/specs/2026-10-09-mastery-unlocks-design.md`, plan
  `docs/superpowers/plans/2026-10-09-mastery-unlocks.md`, checklist `docs/superpowers/specs/2026-10-09-mastery-unlocks-checklist.md`.
  Waiting on a playtest. Aido's numbers are in (Half-Life mastery 10, Chain Reaction 25).
- **Quests** (bounties from Bounty Hunters, mastery challenges): **built and in Studio**, spec `docs/superpowers/specs/2026-10-09-quests-design.md`, plan
  `docs/superpowers/plans/2026-10-09-quests.md`, checklist `docs/superpowers/specs/2026-10-09-quests-checklist.md`.
  Three Bounty Hunters stand on the map's `QuestSpawn` parts (GiverIds Training, Frontier, Outpost;
  their bounties are in `QuestConfig.Givers`); enemies carry `EnemyType`. Later on the same system:
  daily challenges, story quests. Later on the same system: daily challenges, story quests. Later: each power, moveset
  or weapon's own block (the `block` hook), NPCs that block. Other areas to deepen after it: builds
  (talents at level milestones), the world (quests, bosses).

## Reforge and spawn

- **Reforge** (smith NPC, level up to 10, reroll 2 modifier slots): **built and in Studio**, plan
  `docs/superpowers/plans/2026-10-14-reforge.md`, checklist `docs/superpowers/specs/2026-10-14-reforge-checklist.md`.
- **Spawn Keeper** (an NPC tagged `SpawnSetter` saves the player's spawn spot): **built and in Studio** (2026-10-14); no plan or checklist (needs a playtest). A `Spawn Keeper` NPC (Power Gacha rig, tagged `SpawnSetter`) stands beside the SpawnLocation.
- **Power aura** (an `Aura` model under `ServerStorage.SkillSets.<Set>` welds to the character while its tool is held; Photoshop uses `PhotoshopAura`): **built and in Studio** (`SkillSetServer`, synced 2026-10-15). The aura models are yours (VFX).
- **Enemy drops** (materials as glowing orbs, per-player, saved bag; spent in Reforge): **built and in Studio** (2026-10-14; a one-hit kill dropped orbs and walking onto them filled the bag)
  (plan `docs/superpowers/plans/2026-10-14-enemy-drops.md`, checklist `docs/superpowers/specs/2026-10-14-enemy-drops-checklist.md`).
  `DroppedItemOrb` is in `ReplicatedStorage.VFXPrefabs`. Left: the checklist (two players, visuals, UI).

- **Yen chests** (walk over a chest for ¥50-150; 4 of the map's `TestChest` parts are out at once on random spots, a new one 45 s after a pickup; `ChestConfig`, `Chests` script): **built and in Studio** (2026-10-16; solo-tested pickup and respawn). Left: a pickup sound/popup (VFX is yours), the numbers, and real chest looks.

- **Talismans** (worn in 3 slots opened at levels 0/15/40: Vigor +15% max HP, Regrowth +2 regen, Bulwark -8% damage taken, Magnate +30% yen, Second Wind heal on kill, Glass Charm +20% dealt / -15% max HP; found in yen chests, 20% chance for one you don't own; `TalismanConfig`, `Talismans`, Backpack TALISMAN tab + equipped lines, Profile lines, a "Found" toast): **built and in Studio** (2026-10-16). Solo-checked: grant, equip rules, max HP 115 with Vigor, Bulwark cut 100 to 92, the Backpack list. Profile lines and the other effects (regen, Glass Charm, Second Wind, Magnate on kills) not yet watched in-game. Later: more sources (enemies, shop, reforge-style reroll), icons, rarity.

- **Factions** (3 factions by theme: good The Lumen Order (placeholder name), bad Umbra Noctis, The Headhunter Clan (placeholder name); join at an NPC model tagged `FactionRecruiter` (no `FactionId` = offers all three, with prompts on E, F and R; or set `FactionId` to `Lumen`, `UmbraNoctis` or `Headhunters` for a single-faction recruiter). One "Faction Recruiter" NPC (a cloned Smith rig) stands next to the Smith at the main hub, switch after a 1 h cooldown, standing from enemy kills (+1) and rival-faction player kills (+5), 5 ranks; rank perk so far: a shop discount (Lumen 0/5/10/15/20%, Headhunters 0/0/5/5/10%, Umbra Noctis none yet) taken off every yen price in `ShopServer`, shown in `ShopMenu`; saved `FactionData` text, mirrored as `Faction`/`FactionStanding`/`FactionRank`/`FactionDiscount`; `FactionConfig` (Lune spec written, not run), `Factions`, `FactionServer`, `FactionNotice`; each faction names its own ranks (Lumen: Initiate, Guardian, Sentinel, Paladin, Archon; Umbra Noctis: Shade, Whisper, Wraith, Nightblade, Umbra Lord; Headhunters: Hound, Tracker, Hunter, Slayer, Warlord); the rank title, e.g. `[Sentinel]`, shows before a player's overhead name in the faction's colour: Lumen blue, Umbra Noctis purple, Headhunter Clan red, each brighter per rank, `FactionConfig.palette`): **applied to Studio 2026-10-20 (all 9 scripts match the repo byte for byte; the rules were checked in Studio, no playtest yet)**. Still to do: final names/lore for Lumen and Headhunters, Umbra Noctis's perk, recruiter NPCs in Studio, a Profile/Hub line, more perks (Headhunter clan: bounty or death-drop perks fit), faction quests, a FACTION card on the Hub Profile tab (rank and name in the rank colour, standing bar to the next rank); not yet checked that the Profile column still fits the screen.

- **Party** (up to 4 players; invite from a hub Party tab, the invite lasts 30 s and also shows as a Y/N prompt on screen; leader can invite, kick and promote; a leaving leader hands the lead on; a party of one disbands; `PartyRules` (Lune spec written, not run), `Party`, `PartyServer` (the `PartyAction` remote), `PartyMenu` (hub tab: 4 slots with live HP, invite list, ACCEPT/DECLINE, LEAVE), `PartyHUD` (mates' HP down the left edge, news line, invite prompt); mirrored as `PartyId`/`PartyLeader`/`PartyIndex`/`PartyInvite`/`PartyNotice` attributes): **applied to Studio 2026-10-20; the scripts load without errors in a solo playtest and the PARTY tab shows in the nav, but the page itself and a real invite between two players are not yet seen.** Not built on purpose: no friendly-fire rule for party members, no shared bounty or kill credit, no party chat, no overhead marker. Later: those, and a Party hotkey.

- **Awakening** (a switchable second kit for powers the owner picks, unlocked and switched at the smith; the universal path for every power is a Reforge level cap that rises per region): **design only** (2026-10-21), spec `docs/superpowers/specs/2026-10-21-awakening-design.md`. Needs the owner's picks, kits and costs first. Cloud for the data, server and menu; Studio for visuals.

- **Henchman enemy** (the first enemy type: `EnemyConfig`, aggro range 50, give-up distance 140, a jab-jab-lunging-heavy combo, loot table with the new Thug Badge material, and the drop-only Thug's Knuckle talisman at 3%): **code built** on branch `claude/vigilant-rubin-ckqtnn`, waiting on the Studio apply and a playtest. Spec `docs/superpowers/specs/2026-10-23-henchman-enemy-design.md`, plan `docs/superpowers/plans/2026-10-23-henchman-enemy.md`, checklist `docs/superpowers/specs/2026-10-23-henchman-enemy-checklist.md`. Nothing to add in Studio (the four Henchman models already carry `EnemyType=Henchman`); new ModuleScript `ReplicatedStorage.EnemyConfig`. Later: bounties and faction hooks, squads, a thrown weapon, own animations and VFX, Thug Badge in a Reforge recipe, turn `TalismanConfig.OwnAll` off so the Knuckle drop does anything.

## Getting powers

- **Briefcases, storage, lifetime, drops, gacha, selling** (and saved powers, no starter power):
  **built and in Studio** (`studio` tag at the gacha commit, 2026-10-14; the gacha roll panel is built, Aido's power is a sell-only placeholder, Deus Ex Machina), spec `docs/superpowers/specs/2026-10-09-power-acquisition-design.md`,
  plan `docs/superpowers/plans/2026-10-09-power-acquisition.md`, checklist
  `docs/superpowers/specs/2026-10-09-power-acquisition-checklist.md`. Left (task 7, Studio + you): the
  `ServerStorage.Briefcase` tool, `BriefcaseSpawn` parts, the `PowerGacha` NPC and its roll panel , Robux Developer Products in `PowerConfig.RobuxProducts`, the sync
  and the playtest. Later: enemies dropping briefcases, the stat rework, trading, storage upgrades.

## World

- **Daylight cycle** (20-minute day, sun/moon, Luminance by moonlight, Solar Lance weaker at night,
  admin set/freeze time): **built and in Studio** (synced 2026-10-14), spec
  `docs/superpowers/specs/2026-10-13-daylight-cycle-design.md`, plan `docs/superpowers/plans/2026-10-13-daylight-cycle.md`.
  Left: task 7's keyframe tuning by eye and the playtest (two players for "same time"). Later: night
  affecting enemies, spawns, shops and quests (the `Phase` attribute is the hook).

- **Swimmable water parts:** **built and in Studio**, plan `docs/superpowers/plans/2026-10-10-swimmable-water.md`,
  checklist `docs/superpowers/specs/2026-10-10-swimmable-water-checklist.md`. The water stays Parts
  (tagged `Water`), with scripted swimming. The map has no water parts yet: place and tag them.

## UI

- **Hub menu** (one full-screen menu: Profile, Backpack, Quests, Stats, Updates, locked slots; posed
  character; accent from the held power): **built and in Studio** (2026-10-14; load, keys and the
  Updates badge checked). Left: the playtest and pose tuning, checklist
  `docs/superpowers/specs/2026-10-14-hub-menu-checklist.md` (spec `specs/2026-10-14-hub-menu-design.md`,
  plan `plans/2026-10-14-hub-menu.md`).
- **HUD layout pass** (top-right icon row, key hints, one menu at a time): **built and in Studio** (synced 2026-10-14; left from task 6: screenshots at three sizes, icon images, the playtest), spec
  `docs/superpowers/specs/2026-10-09-hud-layout-design.md`, plan
  `docs/superpowers/plans/2026-10-09-hud-layout.md`, checklist
  `docs/superpowers/specs/2026-10-09-hud-layout-checklist.md`. The final visual design comes
  later; this fixes the layout.

## Settings

- **Settings menu** (gear at the right edge, or P) with rebindable fighting keys: **code built** on
  branch `claude/vigilant-rubin-ckqtnn`, waiting on the Studio apply and a playtest with
  `docs/superpowers/specs/2026-10-09-settings-keybinds-checklist.md`. Nothing to add in Studio.
  `tests/run.sh` runs the Keybinds and Preferences unit tests with Lune (not part of Studio).
- **Settings: Quick respawn, Camera shake, Flashes & impact frames, Damage numbers**, a **death
  screen** and **cast feedback** (why a skill didn't go off): **code built** on the same branch,
  waiting on Studio and `docs/superpowers/specs/2026-10-09-settings-death-feedback-checklist.md`.
  Later sections: effects quality, audio (once there are sounds).

## Before release

- `SkillSetConfig.OwnAllSets` is `true` (everyone owns every set, for testing): turn it off. (Cloud)
- Power Dealer prices are placeholders (Iridescent Requiem and Photoshop ¥25,000; the rest are
  "coming soon"). (Cloud)
- Kill feed credit between two real players is untested (only the `Player Dummy`). (Studio, 2 players)
- Remove `workspace."Player Dummy"` when done testing the kill feed. (Studio)
- `IridescentRequiemAnimations.CastX` (Prism Form pose) is still waiting to be published. (Studio, owner)
