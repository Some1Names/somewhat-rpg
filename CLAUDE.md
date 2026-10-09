# Somewhat RPG Game

A Roblox RPG (place 18888856538, owner xNagitox) with anime-style powers ("skill sets") from the
owner's manga. The game itself lives in Roblox Studio. This repo holds **a copy of every script**,
so the code can be worked on outside Studio, for example from a Claude Code cloud session.

## What this repo is, and isn't

- `src/` mirrors the scripts in Studio, in Rojo-style names (`.server.luau` = Script,
  `.client.luau` = LocalScript, `.luau` = ModuleScript, `init.*` = a script that has scripts
  inside it). `studio-manifest.json` maps each file to its exact instance path and class in Studio.
- **Only scripts are here.** Parts, models, UI that scripts build at runtime aside, prefabs
  (`ReplicatedStorage.VFXPrefabs`), animations, sounds, the map and Workspace scripts (free-model
  and rig `Animate` scripts) exist only in Studio. Don't invent instances: if code needs one that
  isn't created by a script, say so in your summary so it can be added in Studio.
- **Studio is the source of truth.** Nothing here runs by itself; a change counts once it's in
  Studio (see "Syncing with Studio").

## Working from a cloud session

A cloud session has no Roblox Studio connection. It can read and edit `src/`, but it cannot
playtest, take screenshots, inspect or move instances, publish animations or upload images.

- Keep changes reviewable and say clearly what you could not verify. The owner playtests
  themselves; list exactly what to try in-game.
- Commit with clear messages and push your branch. A local session with the Studio connection
  applies the diff to Studio.
- Luau syntax: there's no Luau toolchain installed by default. If you can, install `luau` /
  `luau-analyze` or `selene` to check syntax; otherwise read your edits carefully, since a syntax
  error breaks the whole script in-game.

## Owner's standing preferences

- UI is square everywhere: no rounded corners (`UICorner`).
- The owner playtests; don't claim something works in-game unless it was actually tested.
- All player damage goes through `ServerScriptService/Damage.luau` (`Damage.Deal`).
- Any upload to the owner's Roblox account (images, animations) needs their OK first.
- Match the surrounding code: comment density, naming, and the existing helpers.
- Real VFX come from imported effect/particle packs (or assets from VFX websites), set up as
  prefabs in `ReplicatedStorage.VFXPrefabs` and played with `VFX.Play`. Don't design final
  visuals from Roblox's stock particles or parts built in code; those are placeholders only,
  until the pack prefab exists.

## Architecture (where things live)

- **Config modules** (`src/ReplicatedStorage`): `SkillSetConfig` (every skill set: tier, keys,
  cooldowns, aim specs, `handler` names, passives, flight, forms), `StatConfig` (levels, stats, HP
  per Vitality, enemy scaling), `PunchConfig` (melee weapons/combos), `ShopConfig`,
  `StatusConfig` (Burnt/Bleeding/Poisoned/Weakened), `VFX` (client effects toolkit).
- **Skills**: each skill's server logic is a ModuleScript in `ServerScriptService/Skills` with
  `Cast(player, character, aim)` (and optional `Recast`), named by `handler` in SkillSetConfig.
  `SkillSetServer` validates casts (mastery, cooldowns via `SkillCooldowns`, `overchargedOnly`,
  `charges`) and calls the handler.
- **Visuals** are client-side: the server fires `ReplicatedStorage.SkillEffects`
  (`FireAllClients(kind, ...)`), and `StarterPlayerScripts/SkillEffects/init.client.luau` draws
  `effects[kind](...)`. A player's own instant visuals go through the `LocalSkillEffect` bindable.
  `VFX.Play(path, where, { scale, color, ... })` plays prefabs from `VFXPrefabs` (they exist only
  in Studio; attributes EmitCount/EmitDuration/Tint on their emitters drive them).
- **Combat systems**: `Damage` (stat scaling, kill credit, `LastAttacker`/`LastHit`, `OnDealt`),
  `CrowdControl` (PvP hold protection and immunity; ask `CanControl` before moving or stunning a
  player), `StatusEffects`, `Passives`, `Overcharge`, `Projectiles`, `Sunmark`, `Ragdoll`.
- **Player data**: `PlayerStats` (attributes, DataStore save/load; Studio can't reach DataStores),
  `Loadout` (owned/equipped sets), `ShopServer`, `KillFeed`.
- **Client UI**: `SkillBar`, `Inventory`, `StatsMenu`, `AdminPanel`, `ShopMenu`, `StatusHUD`,
  `OverheadHealth`, `Hotbar`, `KillFeed`.
- Sets so far: Mandela (S power, green; overcharge "Backbone Power"), Iridescent Requiem (S power,
  orange #FF9A3C / cyan #3CE0E6, Luminance passive, flight, Prism Form), Revolver (B weapon).

## Syncing with Studio (done by a local session that has the Studio MCP)

The `studio` git tag marks the commit whose `src/` matches Studio.

**Repo → Studio** (after a cloud session pushes):
1. `git fetch` and review `git diff studio..origin/<branch> -- src/`.
2. Apply each changed file to its instance from `studio-manifest.json`: small hunks as targeted
   edits; new files as new scripts with the class/RunContext the suffix implies (add them to the
   manifest by re-exporting afterwards).
3. Compile-check in Studio (playtest console), then move the tag: `git tag -f studio <commit>`.

**Studio → Repo** (after edits made directly in Studio):
1. In the Edit datamodel run `tools/export_chunk.luau` with `__START_I__, __START_OFF__` set to
   `1, 0`. The output is saved to a file; read its `nextI`/`nextOff` and run again from there
   until `done` is true.
2. `python tools/assemble_export.py <slice1.json> <slice2.json> ...` rewrites `src/` and
   `studio-manifest.json` (it fails if any script's length doesn't match Studio's).
3. Commit ("Sync from Studio") and `git tag -f studio`.

Export first if Studio has changed since the last sync, so cloud work starts from current code.
