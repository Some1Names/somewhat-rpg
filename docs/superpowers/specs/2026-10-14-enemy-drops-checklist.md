# Enemy drops: in-game test checklist

`tests/DropConfig.spec.luau` covers the pure rules (rolls, helpers, bag cap, pickup rights and range; run in
Studio on 2026-10-14 because Lune isn't installed on this machine). The server (`Drops`), `DropClient`, the
saved `Mat_<key>` defaults, the Inventory list and the admin button are written but **not played**.
Spec: `specs/2026-10-14-enemy-drops-design.md`; plan: `plans/2026-10-14-enemy-drops.md`.

Synced to Studio 2026-10-14, `DroppedItemOrb` already moved to `ReplicatedStorage.VFXPrefabs`. One
server-side playtest checked: a one-hit kill of a level 10 Henchman dropped Scrap and Core owned by the
killer with a 30 s window, and standing on them emptied the ground and raised the bag. Everything else
below is unplayed.

## Studio setup
- [ ] The enemies you kill are tagged `Enemy` (they are, for `EnemyAI`). Optionally set the attribute
      `DropTable = "Wolf"` on one to test its extra drop (`WolfFang`).

## Solo
- [ ] Kill a level 1 enemy: a grey orb with "Scrap xN" floats about 2 studs over the ground near where it
      died; walking within 6 studs takes it and "+N Scrap" pops up. Kill a few: Scrap is about 80%.
- [ ] A one-hit kill still drops (the killing blow counts).
- [ ] A training dummy, and a player you kill, drop nothing.
- [ ] Open the Inventory (B): a MATERIALS list under the slots shows what you hold, tier-coloured,
      "None yet" when empty; it updates while open when you pick something up.
- [ ] Admin panel (PROGRESS): "Materials +50 each" adds 50 of every material and shows the pop-ups.
- [ ] Rejoin: the bag is kept (Studio doesn't save; check on a live server). Reforge accepts the materials.
- [ ] With 999 of a material, an orb of it stays on the ground (and vanishes after about a minute).
- [ ] Wait 60 s without picking one up: it disappears.
- [ ] An enemy with `DropTable = "Wolf"`: about 1 in 10 kills also drops Wolf Fang.

## Two players
- [ ] Both hit an enemy for at least 10% of its health each: each gets their own orb(s); you only see your
      own for the first 30 s, and the other player's is hidden until it turns public.
- [ ] One of you only chips it for under 10%: that player gets nothing.
- [ ] After 30 s the orbs are public: either player can take the other's.
- [ ] Standing on one public orb together: only one of you gets it.

## Watch for
- Console warnings starting "Drops:" (missing prefab or orb part).
- 200 orbs at once removes the oldest (kill many enemies without picking up).
