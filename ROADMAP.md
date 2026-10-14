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

1. **Aido** (Furukiwa Aido, The Director; his power is named **Deus Ex Machina**; S power, red, atomic): **designed**, spec
   `docs/superpowers/specs/2026-10-09-aido-design.md`, plan `docs/superpowers/plans/2026-10-09-aido.md`
   (not built yet). Fuse, Z Catastrophe, X Collapse, C Total Destruction, V Ground Zero, F Final Cut
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

- **Block and posture** on Alt (moved from E; parry dropped for now): **built and in Studio** (synced 2026-10-13), spec
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
  Waiting on a playtest. Aido's numbers go in with the Aido build.
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
- **Power aura** (an `Aura` model under `ServerStorage.SkillSets.<Set>` welds to the character while its tool is held; Photoshop uses `PhotoshopAura`): **code committed, not in Studio yet** (`SkillSetServer`, commit `fcdb0b3`). The aura models are yours (VFX).
- **Enemy drops** (materials as glowing orbs, per-player, saved bag; spent in Reforge): **built and in Studio** (2026-10-14; a one-hit kill dropped orbs and walking onto them filled the bag)
  (plan `docs/superpowers/plans/2026-10-14-enemy-drops.md`, checklist `docs/superpowers/specs/2026-10-14-enemy-drops-checklist.md`).
  `DroppedItemOrb` is in `ReplicatedStorage.VFXPrefabs`. Left: the checklist (two players, visuals, UI).

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
