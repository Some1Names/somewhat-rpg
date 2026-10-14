# Mastery unlocks per power: design

Status: approved in chat 2026-10-09; waiting on review of this written spec.

## Intent

Mastery only unlocks skills today, at the same 1 / 5 / 20 / 50 / 100 in every power. Each power
should have its own unlock path, and its passive and other features should unlock through mastery
too, so levelling a set reveals it piece by piece.

## What unlocks by mastery

- **Skills** (already a per-skill `mastery` field): new numbers per power, below.
- **Features**, each gaining an optional `mastery` field (default 1, always on): the `passive`,
  `overcharge`, `flight`, `dash`, `undo` and `gallery` tables in `SkillSetConfig.Sets`.
- **Never gated:** the `ranged` click attack (every set's basic attack) and a `form`'s own table
  (Prism Form is the X skill, gated as a skill).

| Set | Z | X | C | V | F | Passive | G | Other |
|---|---|---|---|---|---|---|---|---|
| Mandela | 1 | 5 | 15 | 40 | 100 | Misremembered 10 | overcharge (Backbone Power) 25 | |
| IridescentRequiem | 1 | 10 | 20 | 50 | 100 | Luminance 1 | flight 30 | dash (Lightstep) 15 |
| Photoshop | 1 | 5 | 20 | 40 | 100 | History 15 | undo 15 | gallery 30 |
| Aido (when built) | 1 | 5 | 20 | 50 | 100 | Half-Life 10 | overcharge (Chain Reaction) 25 | |
| Revolver | 1 | 10 | | | | | | |

Luminance stays at 1 (flight, Prism Form and Solar Lance all run on it). History and Undo unlock
together (Undo rewinds History).

## While a feature is locked

- **Passive:** it does nothing (Misremembered never erases; History records nothing; Half-Life
  adds no Fallout or bonus).
- **Overcharge:** no stacks build (from damage dealt or taken), G does nothing, and the meter shows
  the lock instead of the stacks.
- **Flight:** G doesn't take off.
- **Dash:** the dash key does the **normal** dash instead of the set's own (Lightstep).
- **Undo / Gallery:** G and T do nothing; the gallery's waypoints don't show.
- **Feedback:** pressing the key refuses with the usual message ("Backbone Power: needs mastery
  25"); the Inventory lists the feature with "Mastery N" like a locked skill; reaching the level
  shows the gold "… unlocked" popup skills already get.

## Architecture

- **`SkillSetConfig`:** the `mastery` fields and new skill numbers above; a helper
  `SkillSetConfig.FeatureUnlocked(player, setName, feature: string) -> boolean` (false when the
  set has no such feature table; otherwise the player's `MasteryAttribute` for the set is at least
  `<feature>.mastery or 1`) and `SkillSetConfig.FeatureMastery(set, feature) -> number`.
- **Gates (server is the authority; clients mirror for feedback):**
  - `Passives.Absorb` (passive), `PhotoshopServer` History sampling (passive), Aido's `AidoUtil`
    (passive, noted in the Aido plan).
  - `Overcharge.AddDamage`, `AddTaken`, `Activate` (overcharge).
  - `LuminanceServer` take-off (~84) and `Flight.client` (~28) (flight).
  - `DashRelay` (~47) and `Dash.client` (~279) (dash: fall back to the normal dash).
  - `PhotoshopServer` Undo and Gallery remotes; `PhotoGallery.client` (`gallerySet`).
  - `SkillBar`: `tryOvercharge` refusals and the meter's lock text; level-up popups for features.
  - `Inventory`: the feature rows show "Mastery N" when locked.
- No new remotes or saved data.

## Testing

- StyLua parse and selene on every changed script.
- In-game checklist `docs/superpowers/specs/2026-10-09-mastery-unlocks-checklist.md`, using the
  Admin panel's mastery setter to step each set through its unlock levels.
