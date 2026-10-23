# Henchman enemy: Studio apply and playtest checklist

Spec: `2026-10-23-henchman-enemy-design.md`. Plan: `../plans/2026-10-23-henchman-enemy.md`.

## Apply to Studio

- [ ] New ModuleScript `ReplicatedStorage.EnemyConfig` from `src/ReplicatedStorage/EnemyConfig.luau`.
- [ ] Apply the diffs of `ReplicatedStorage.DropConfig`, `ReplicatedStorage.TalismanConfig`,
      `ServerScriptService.Drops`, `ServerScriptService.EnemyAI` (see `git diff studio..HEAD -- src/`).
- [ ] No console errors on a playtest start; re-export to refresh `studio-manifest.json`.

## Playtest

Run in a solo playtest next to a Henchman (Level 10, `EnemyType=Henchman`).

- [ ] Walk toward it: it starts chasing at about 25 studs, without being hit. Standing farther away it stays idle.
- [ ] Its swings go jab, jab, heavy, then a pause of about 1.2 s (a window to hit back), then jab again.
- [ ] The heavy shows the red warning, it lunges a few studs at you, and a Q dash during the wind-up dodges it.
- [ ] The jabs show the white warning and can be staggered by a melee hit; the heavy cannot.
- [ ] Leave its territory (about 45 studs from where it stood): it gives up and walks home, then regains health.
- [ ] Known loop to watch: stand somewhere it can't reach inside 25 studs (a ledge). It chases, gives up, walks
      home and tries again. If that looks bad, tell me and I'll add a short aggro cooldown after a give-up.
- [ ] An enemy with no `EnemyType` (a plain dummy-style `Enemy`) still ignores you until hit, and swings the old random way.
- [ ] Kill a Henchman: orbs of Scrap and sometimes Thug Badge (Rare orb) and Core appear; the Backpack lists Thug Badge.
- [ ] Talisman: temporarily set `TalismanConfig.OwnAll = false` and `talisman.chance = 1` in `EnemyConfig`; a kill
      shows the "Found" toast and the Backpack lists Thug's Knuckle; killing another gives no second toast. Yen chests never give it.
      Put both values back after.
- [ ] Hitting it from the side or behind while it's mid-combo, then moving away, doesn't leave it stuck swinging at nothing.
