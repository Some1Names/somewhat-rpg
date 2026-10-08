# Roadmap

What's left, as of 2026-10-09. **Cloud** = code-only, a cloud session can do it.
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

1. **Aido** (S power, red, atomic bomb): Z Catastrophe, X Collapse, C Total Destruction, F dragon
   form ultimate; inflicts Burnt.
2. **Photoshop** (Nozomi, S power, pink / light blue): photo teleport / fast travel, Iris Horizon,
   ultimate Kaleidoscope.
3. Later: Himaru (S power), Daemon (A power) + Daemon's katana (A weapon, shop item),
   Kintsugi (B power), Monotwister (Aido's katana, S weapon).

Infrastructure these need: a `weapon` kind with a katana combo, the reserved MELEE inventory slot,
and saved ownership + loadout (`Loadout` is session-only today).

## Before release

- `SkillSetConfig.OwnAllSets` is `true` (everyone owns every set, for testing): turn it off. (Cloud)
- Power Dealer prices are placeholders (Iridescent Requiem ¥25,000; the rest are "coming soon"). (Cloud)
- Kill feed credit between two real players is untested (only the `Player Dummy`). (Studio, 2 players)
- Remove `workspace."Player Dummy"` when done testing the kill feed. (Studio)
- `IridescentRequiemAnimations.CastX` (Prism Form pose) is still waiting to be published. (Studio, owner)
