# Roadmap

What's left, as of 2026-10-09. Plans ready to run are listed in `docs/superpowers/plans/README.md`. **Cloud** = code-only, a cloud session can do it.
**Studio** = needs the local Studio connection (looking at effects, prefabs, uploads, playtests).

## In progress: Iridescent Requiem revisual

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

1. **Aido** (Furukiwa Aido, The Director; S power, red, atomic): **designed**, spec
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

- **Block, parry and posture** on E: **designed**, spec `docs/superpowers/specs/2026-10-09-block-parry-design.md`,
  plan `docs/superpowers/plans/2026-10-09-block-parry.md` (not built yet).
- **Death stakes and the Headhunter** (dropped yen, the kill leader mark): **designed**, spec
  `docs/superpowers/specs/2026-10-09-death-stakes-design.md`, plan
  `docs/superpowers/plans/2026-10-09-death-stakes.md` (not built yet).
- **More ways to earn mastery** (PvP, kill bonus, training dummies to 10): **designed**, spec
  `docs/superpowers/specs/2026-10-09-mastery-sources-design.md`, plan
  `docs/superpowers/plans/2026-10-09-mastery-sources.md` (not built yet). Mastery challenges
  belong to the coming quest system; boss mastery to the boss and enemy rework.
- **Mastery unlocks per power** (own skill levels; passives, G, Lightstep, the Gallery by mastery):
  **designed**, spec `docs/superpowers/specs/2026-10-09-mastery-unlocks-design.md`, plan
  `docs/superpowers/plans/2026-10-09-mastery-unlocks.md` (not built yet). Later: each power, moveset
  or weapon's own block (the `block` hook), NPCs that block. Other areas to deepen after it: builds
  (talents at level milestones), the world (quests, bosses).

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
