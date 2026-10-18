# Build depth (Deepwoken-like, sub-project 1)

## Goal
Builds should play differently, not just hit harder. Players commit points to a direction; that
unlocks some things and locks others. Out of scope here: parry/dodge combat changes, respec and
oaths, world/death penalty (later sub-projects).

## Decisions (agreed in chat)
- Keep Vitality, Strength, Superliminal, Firearm; add **Agility** and **Willpower**.
- Per-stat cap **50**; 3 points per level stays (300 total at level 100), so a max player cannot fill six stats.
- Weapons and skill sets get **stat requirements**.
- **Talents**: picked from a pool, gated by stat thresholds (15 / 30 / 50) and a talent-point budget
  (1 per 5 levels, 20 total). No world-earned talents yet.
- Data-driven: `TalentConfig` + `BuildRules` (pure, Lune-tested), like `PowerConfig` / `ReforgeRules`.

## Design
1. **Stats** (`StatConfig`): add `Agility` (stamina regen, dodge/parry window, move speed) and
   `Willpower` (posture, status resistance, skill resource). Each takes effect only through numbers
   the current `Guard`, dash and `StatusEffects` code already has. `StatCap` becomes 50 for all.
   Existing saves keep their points; anything above the new cap is refunded to unspent on join
   (same recalculation pattern `PlayerStats` already uses for level changes).
2. **Requirements**: optional `requires = { Strength = 20 }` on `SkillSetConfig` and `PunchConfig`
   entries. `BuildRules.Meets(stats, requires)` returns ok plus the first missing stat. `Loadout` and
   `SkillSetServer` check it server-side. Below the requirement the item is unusable (one rule for
   both, kept simple); the UI shows the missing stat.
3. **Talents**: `TalentConfig` entries `{ key, stat, tier (15|30|50), cost, effect }`. Tier unlocks when
   the stat has reached its threshold. Players equip talents within their talent-point budget in a new
   Talents section of the Stats menu. Saved as a text value (like `Reforge`/`Challenges`), mirrored as
   `Talent_<key>` attributes. Effects are numeric modifiers read where they already live (`Damage`,
   `Guard`, regen in `PlayerStats`); only talents needing a new hook get one, listed in the plan.
4. **UI**: Stats menu gets requirement badges, locked/unlocked talent tiers and the budget. Square
   corners, HUD colours.
5. **Testing**: Lune spec `tests/BuildRules.spec.luau` (caps, refund, requirement check, tier
   unlock, talent budget). In-game checklist supplied with the change; no claim of in-game
   verification without a playtest.

## Open items for the plan
- The exact starting talent list and numbers (tune in `TalentConfig`; start with ~3 per stat).
- Which existing weapons/sets get requirements (start with none locked at level 0 content).
- Any new Studio instances: none expected; all UI is script-built.
