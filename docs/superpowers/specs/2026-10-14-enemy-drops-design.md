# Enemy drops: design

Status: design agreed in chat 2026-10-14 (with the owner's `DroppedItemOrb` model); waiting on review
of this written spec. First of two designs: **reforge** (levels plus random modifiers, for weapons and
powers) is designed next and spends the materials defined here. Gear (armor, accessories) is a later,
separate design.

## Intent

Enemies drop **materials**: collected as glowing orbs on the ground, kept in a saved bag, and later
spent on reforging. The drops should feel like loot, not like a stat: a coloured orb falls where the
enemy died, you walk to it, "+2 Scrap" pops up.

Success: killing an enemy with friends gives each of you your own drop and nothing to fight over;
higher-level enemies give rarer orbs; materials are never lost on leaving (they're saved) and can't be
duplicated.

## The materials

- **Four generic materials**, one per rarity tier. The tier decides which orb it uses. Names are
  placeholders for the owner to rename (`DropConfig.Materials`, `display`):

| Tier | Material | Orb (from `DroppedItemOrb`) | First-pass drop (per helper, per kill) |
|---|---|---|---|
| Common | Scrap | `CommonOrb` (grey) | from level 1, 40%, 1–3 |
| Rare | Core | `RareOrb` (blue) | from level 10, 12%, 1–2 |
| Gold | Crystal | `GoldOrb` (yellow) | from level 30, 3%, 1 |
| Dark | Essence | `DarkOrbRed` (3 in 4) or `DarkOrbPurple` (1 in 4), picked per drop (the two `DarkOrb` parts were renamed) | from level 50, 0.5%, 1 |

  An enemy rolls every tier whose `minLevel` its `Level` reaches (an enemy with no `Level` counts as
  level 1). All numbers are `DropConfig` values to tune.
- **Rare enemy-specific materials** (e.g. `Wolf Fang`): each is its own saved material with a tier
  (which only picks its orb and colour). They come from **drop tables**: `DropConfig.Tables[name] =
  { { material, chance, min, max }, ... }`. An enemy model picks one with the optional attribute
  `DropTable = "<name>"` (set in Studio). Rolled in addition to the generic tiers.
- **The bag:** each material is a saved player attribute `Mat_<key>` (a number, 0 to `MaxPerMaterial
  = 999`), like `Owns<id>`. `PlayerStats` gets defaults for every material in `DropConfig.Materials`,
  so a new material needs only a config line. Materials aren't lost on death or leaving.

## Who gets a drop

- On `Damage.OnKill` for an NPC victim tagged `Enemy`, **every player who dealt at least 10% of the
  enemy's max health** (`ContributionShare = 0.1`) is a **helper**. Damage is tracked per enemy from
  `Damage.OnDealt` (players only, weak table, forgotten when the enemy dies or is removed).
- **Each helper rolls independently** (their own chance for each tier and table entry), and gets their
  own drop orbs, which only they can pick up at first. No stealing, no fighting over loot.
- Player-versus-player kills drop nothing. Enemies without the `Enemy` tag (training dummies) drop
  nothing.

## The drop (the orb)

- The prefab is the owner's `DroppedItemOrb` model, moved in Studio to
  `ReplicatedStorage.VFXPrefabs.DroppedItemOrb` (it holds `CommonOrb`, `RareOrb`, `GoldOrb` and two
  `DarkOrb` parts, each with its particles on an `Attachment`). The server clones the part of the
  drop's tier, sets `CanCollide = false`, `CanQuery = false`, `Anchored = true`, and places it in
  `workspace.Drops` (a folder the script creates at runtime).
- **Where:** at the enemy's last position, dropped onto the ground (a raycast down), floating
  `HoverHeight = 2` studs up, scattered up to `ScatterRadius = 4` studs so several orbs don't stack.
- **Attributes on the orb:** `OwnerUserId`, `Material` (key), `Amount`, `PublicAt` and `ExpiresAt`
  (both `workspace:GetServerTimeNow()` values). A small `BillboardGui` label above it reads
  "Scrap x2" in the tier's colour (square, no rounded corners).
- **Windows:** the owner alone for `OwnerWindow = 30` s, then anyone for `PublicWindow = 30` s more,
  then it's removed. At most `MaxDrops = 200` orbs exist (the oldest go first).
- **Pick-up:** automatic, but not for the first `PickupDelay = 1.2` s after it lands, so an orb is seen even
  when a player stands on it. The server checks every `0.2` s; a living player within `PickupRange = 6`
  studs (flat) and 8 studs up or down, who is allowed to take it (the owner, or anyone once `PublicAt`
  has passed), gets it. If their bag would exceed `MaxPerMaterial`, they take what fits and the rest
  stays.
- **Client** (`DropClient`): during the owner window, orbs that aren't yours are hidden for you
  (transparency, particles and label off, all local). They appear when `PublicAt` passes. The server
  enforces the rule regardless; hiding is only so you don't see loot you can't take.
- **Pop-up:** the client shows "+2 Scrap" when it sees a `Mat_<key>` attribute on the local player
  go up (no remote event). Dropping in value or the first load shows nothing.

## The Inventory

A **Materials** list in the Inventory menu: one row per material you own (name, amount, tier colour),
nothing for materials you have none of. It's information only (reforge will be the one place they're
spent).

## Admin

The admin panel gets a **"Materials +50 each"** button (`GiveMaterials` in `AdminServer`) so reforge can
be tested without grinding. No other admin tools.

## Files

**New**
- `src/ReplicatedStorage/DropConfig.luau`: `Tiers`, `Materials`, `Tables`, the numbers above, and
  pure helpers `DropConfig.Rolls(level, tableName, random)` (what a helper gets: a list of
  `{ material, amount }`) and `DropConfig.IsHelper(damage, maxHealth)`. Lune-tested.
- `src/ServerScriptService/Drops.luau`: helper damage tracking, the roll-and-spawn on kill, pickup
  loop, expiry. `DropsServer.server.luau` starts it, like `DayClock` and `DayCycle`.
- `src/StarterPlayer/StarterPlayerScripts/DropClient.client.luau`: hiding others' orbs, "+N" pop-ups.
- `tests/DropConfig.spec.luau`

**Changed**
- `ServerScriptService/PlayerStats.luau`: saved defaults for `Mat_<key>`.
- `ServerScriptService/AdminServer.server.luau` and `StarterPlayerScripts/AdminPanel.client.luau`:
  `GiveMaterials`.
- `StarterPlayerScripts/Inventory.client.luau`: the Materials list.
- `CLAUDE.md` (Architecture), `ROADMAP.md`, `docs/superpowers/plans/README.md`.

## Needed in Studio (not created by scripts)

- Move `Workspace.DroppedItemOrb` to `ReplicatedStorage.VFXPrefabs.DroppedItemOrb`; give the two
  `DarkOrb` parts distinct names or leave them (the code picks any child named `DarkOrb`).
- Optionally set `DropTable` on enemy models that should drop specific materials (a table has to exist
  in `DropConfig.Tables` first).
- The orbs are the owner's real effects, so nothing placeholder is involved.

## Error handling and exploits

- Server-side only: helpers, rolls, amounts and pickup range are all decided on the server; a client
  can't ask for anything.
- Pickup is atomic (the orb is destroyed before the bag is credited), so two players can't both take it.
- The bag is capped and saved with the rest of the player's data; a failed save load never wipes it
  (`PlayerStats` already guards that).
- A missing prefab, tier part or material key logs one warning and skips the drop; it never errors a kill.

## Not in scope

Reforge (next design), selling or trading materials, briefcase or power drops, drops from players,
dropping on player death, drop sounds, a pickup magnet or vacuum, gear.
