# Awakening: a switchable form of a power, at the smith

Status: design only, nothing built. Decided with the owner 2026-10-21.

## Why

Raising the level cap (for Region 2) raises the per-stat cap (`StatConfig.MaxStatPoints` =
`MaxLevel * PointsPerLevel / 4`), which opens higher stat requirements. New powers can then be stronger
than old ones of the same tier. Awakening gives an older power a way to keep up without replacing it.

## The rule

- **Awakening is a second kit for a power the owner picks** (not every power has one; more can be added
  in later updates). It is a **switchable form**, not a replacement: the player keeps the base power,
  and its saved mastery, reforge and ownership, and can switch between the base kit and the awakened
  kit at the **smith** (the Reforge NPC, `Smith` tag, `ReforgeMenu`).
- **Unlocking** costs yen and region drop materials (`Mat_<key>`), and needs a higher stat requirement than
  the base power (`awakened.requires`, in the bands the raised stat cap allows).
- A power with no awakening keeps up through the **universal path**: the Reforge level cap rising per
  region (number-only bonuses, no new design per power). Awakening is a showpiece, not a requirement.
- Rule for new content: a new power or weapon in a tier sits in that tier's stat-requirement band, so it is a
  sidegrade; a stronger band is a new tier or the next region's.

## Shape (data first, so nothing needs migrating)

- `SkillSetConfig.Sets.<Set>.awakened = { requires = {...}, cost = {...}, skills = {...}, ... }`: the second kit
  lives inside the base set's entry, so the set name, mastery, reforge and the `Powers` saves stay the same.
- Saved: one flag per set for "unlocked" and one for "active form", beside the `Reforge` text. Existing saves
  have neither and default to the base kit.
- `SkillSetServer` picks the active kit's skills and cooldowns when validating a cast; `BuildCheck` reads the
  active kit's `requires`; the skill bar and Hub read the same active kit.
- The smith's remote (`ReforgeServer`) gets two checked actions: unlock (spend cost, check requirement) and
  switch form (not in combat, `CombatRules`' out-of-combat rule).

## Open questions

- Which powers get an awakening first, and what each awakened kit is (one spec per power, with the owner).
- The cost numbers, and which materials the next region drops.
- Whether the awakened kit keeps the base set's aura and colour, and what the awakened passive is.
- Whether the reforge level cap rises to 15 or 20 in Region 2 (universal path).
