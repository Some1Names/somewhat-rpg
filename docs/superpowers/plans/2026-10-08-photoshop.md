# Photoshop Skill Set Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Nozomi's Photoshop S power (History/Undo, Shutter, Snapshot, Photo Teleport, Gallery, Desaturate, Iris Horizon, Kaleidoscope) plus the three triangle counter hooks.

**Architecture:** Follows the existing set pattern: config in `SkillSetConfig`, one server module per skill in `ServerScriptService/Skills` (`Cast`/`Recast`/`Fire`), a `Framed` mark module modelled on `Sunmark`, one new server script for History/Undo/Gallery that makes its own remotes, and client visuals in a new `SkillEffects/PhotoshopEffects.luau` merged into the `effects` table. Counters hook into `Passives`, `LuminanceServer`, `PrismForm`, `BlackHole`, `Tornado`, `LightShot`, `PrismShot`.

**Tech Stack:** Roblox Luau. No Studio connection and no game runtime in the cloud session; verification is a syntax pass plus the owner's in-game checklist.

**Syntax check (every "Syntax-check" step):** `stylua --syntax luau --check <file>` (installed with `cargo install stylua --features luau`). Exit code **2 = parse error** (must fix); 0 or 1 (formatting differences only) pass. Don't reformat files: the repo isn't StyLua-formatted. All 76 existing scripts pass today.

**Spec:** `docs/superpowers/specs/2026-10-08-photoshop-design.md`

## Global Constraints

- All damage goes through `Damage.Deal(player, humanoid, amount, { stat = "Superliminal", skillSet = "Photoshop", ... })`. Numbers in CONFIG are "before the caster's Superliminal bonus".
- Before moving or holding a **player**, ask `CrowdControl.CanControl(model)`; NPCs can always be controlled.
- Before putting an **edit** (Framed, Desaturated, a paste, a grounding) on a player, ask `Passives.ResistEdit(targetPlayer)`; if true, skip the edit, keep the damage.
- UI is square: no `UICorner` anywhere.
- No new Studio instances may be assumed except the ones the spec lists (the `Photoshop` Tool, optional wearables and `PhotoshopAnimations`). New remotes are created in code.
- Colours: `SkillSetConfig.PhotoshopPink = Color3.fromRGB(255, 126, 200)`, `SkillSetConfig.PhotoshopBlue = Color3.fromRGB(140, 210, 255)`; set `color` = the pink.
- Match surrounding style: a header comment per file explaining the move, a `CONFIG` table with commented units, tabs, LF line endings.
- Never claim in-game behaviour; each task adds its lines to the in-game checklist (Task 12).

## Review Focus

1. **Caster dies, resets or unequips mid-move** (Iris ring closing, Kaleidoscope running, Gallery developing, photo pinned): loops stop, no damage after death, recast attributes cleared. Owned by each skill task: every loop checks `humanoid.Health > 0`, `player.Character == character` and the set still equipped.
2. **Target dies, respawns or leaves mid-move** (ring following a destroyed model, paste target gone, Framed model removed): the move ends cleanly. Each loop re-checks `target.Parent` and `humanoid.Health > 0`.
3. **Teleport destinations in walls, the air or the void** (Step In with a wall behind the target, a photo pinned over a cliff, Undo point recorded mid-fall, Gallery photo saved while airborne): destinations are grounded by a downward raycast (`groundAt` helper in Task 1) and Step In falls back to the side of the target in front of a wall. Gallery refuses to save while not standing on ground.
4. **Client-sent values** (aim far past range, NaN, Gallery remote spam, travel to an arbitrary position): the server clamps aims to CONFIG range, the Gallery remote only accepts `"save", slot` / `"travel", slot` with `slot` an integer 1..3, and travel only goes to a stored slot.
5. **Corrupt or oversized saved gallery string**: parse defensively; any bad entry becomes an empty slot, never an error.

---

### Task 1: Config, Framed, and shared hooks

**Files:**
- Modify: `src/ReplicatedStorage/SkillSetConfig.luau` (add the Photoshop entry after IridescentRequiem, colours, document `undo` in the header comment)
- Modify: `src/ReplicatedStorage/StatusConfig.luau` (add `Desaturated`, append to `Order`)
- Modify: `src/ReplicatedStorage/ShopConfig.luau` (Photoshop item: `set = "Photoshop"`, `price = 25000`, drop `tier`/`comingSoon`, real description)
- Modify: `src/ServerScriptService/Passives.luau` (add `ResistEdit`)
- Modify: `src/ServerScriptService/CrowdControl.luau` (add `Held`)
- Create: `src/ServerScriptService/Framed.luau`
- Create: `src/ServerScriptService/PhotoshopUtil.luau`

**Interfaces:**
- Produces:
  - `SkillSetConfig.Sets.Photoshop` with: `tool = "Photoshop"`, `kind = "power"`, `tier = "S"`, `color`; `passive = { name = "History" }`; `undo = { name = "Undo", cooldown = 18, rewind = 3, healShare = 0.5 }`; `ranged = { name = "Shutter", handler = "Shutter", aims = true, charges = 3, recharge = 3, interval = 0.25, animation = "CastZ", beam = { range = 120, effect = "Shutter" } }`; `skills`:
    - `Z = { name = "Snapshot", mastery = 1, cooldown = 6, handler = "Snapshot", recast = "Step In", aim = { kind = "lock", range = 50, cone = 30 } }`
    - `X = { name = "Photo Teleport", mastery = 5, cooldown = 10, handler = "PhotoTeleport", recast = "Paste", aim = { kind = "circle", range = 60, radius = 4 } }`
    - `C = { name = "Desaturate", mastery = 20, cooldown = 14, charges = 3, handler = "Desaturate", aim = { kind = "circle", range = 50, radius = 18 } }`
    - `V = { name = "Iris Horizon", mastery = 50, cooldown = 35, handler = "IrisHorizon", aim = { kind = "lock", range = 60, cone = 30 } }`
    - `F = { name = "Kaleidoscope", mastery = 100, cooldown = 90, handler = "Kaleidoscope", aim = { kind = "self", radius = 60 } }`
  - `SkillSetConfig.PhotoshopPink`, `SkillSetConfig.PhotoshopBlue`; `SkillSetConfig.UndoReadyAttribute(setName) -> string` (`setName .. "UndoReadyAt"`, server time).
  - `StatusConfig.Effects.Desaturated = { duration = 1, maxStacks = 1, color = Color3.fromRGB(150, 150, 160), glyph = "\u{25D0}" }` (no damage).
  - `Passives.ResistEdit(player: Player) -> boolean`: true only when the player holds a set whose passive is `Misremembered` and it's ready; then it spends it exactly as `behaviours.Misremembered` does (sets the ready attribute, fires `"Misremember"`).
  - `CrowdControl.Held(model) -> boolean`: a player whose `CCImmuneUntil` is more than `IMMUNITY` seconds away (still inside a hold, not just immune); false for NPCs.
  - `Framed.Duration = 4`; `Framed.Mark(player, model) -> boolean` (calls `Passives.ResistEdit` for a player target; false when resisted; sets `FramedUntil`/`FramedBy`; `FireClient(player, "Framed", model, Framed.Duration)`); `Framed.Has(player, model) -> boolean`; `Framed.Extend(player, model, seconds)` (only if `Has`; capped at now + `Duration`; re-fires `"Framed"` with the time left); `Framed.Nearest(player, point, radius) -> Model?` (same shape as `Sunmark.Nearest`).
  - `PhotoshopUtil.groundAt(position: Vector3, ignore: {Instance}) -> Vector3?` (raycast down 200 studs from 4 above; returns hit + 3 studs up, nil over the void); `PhotoshopUtil.lockOn(character, root, aim, range, cone) -> BasePart?` (the root part, same pick as `SpineLash`'s `lockOn`); `PhotoshopUtil.alive(player, character, humanoid) -> boolean` (player in game, still that character, health > 0, Photoshop still equipped); `PhotoshopUtil.playerOf(model) -> Player?`.

- [ ] **Step 1:** Add the config, status, shop and colour entries above. `SkillSetServer`'s tier check must not warn (5 moves, S-tier limit 5).
- [ ] **Step 2:** Implement `Passives.ResistEdit` by factoring the "ready → spend → effect" part of `behaviours.Misremembered` into a local `spendMisremembered(player, character, setName, set) -> boolean` used by both.
- [ ] **Step 3:** Implement `CrowdControl.Held`, `Framed.luau` and `PhotoshopUtil.luau` with the signatures above.
- [ ] **Step 4:** Syntax-check every touched file; expected: no exit code 2.
- [ ] **Step 5:** Commit: `git commit -m "Add Photoshop config, Framed mark and edit resistance"`

### Task 2: Triangle hooks in the existing sets

**Files:**
- Modify: `src/ServerScriptService/LuminanceServer.server.luau`
- Modify: `src/ServerScriptService/Skills/PrismForm.luau`
- Modify: `src/ServerScriptService/Skills/BlackHole.luau` (pull checks at ~199 and ~252)
- Modify: `src/ServerScriptService/Skills/Tornado.luau` (holds at ~173 and ~293)

**Interfaces:**
- Consumes: `StatusConfig.Stacks(model, "Desaturated")`.
- Produces: a desaturated Iridescent holder gains no Luminance (in sun or shade), loses 0.15/s, lands if flying, can't take off (`toggleFlight` refuses), can't enter Prism Form (`PrismForm.Cast` returns false), and an active Prism Form ends (the `watch` loop's break condition). A character with `Flying == true` is never started on a pull/hold by BlackHole or Tornado (damage still applies).

- [ ] **Step 1:** In `LuminanceServer`, add `DESATURATED_DRAIN = 0.15` and a `desaturated(character)` check; in the tick, when desaturated, skip every gain branch and subtract the drain, and set flying off. Refuse take-off in `toggleFlight` while desaturated. Update the header comment.
- [ ] **Step 2:** In `PrismForm`, refuse `Cast` and break `watch` while desaturated; header comment notes it.
- [ ] **Step 3:** In `BlackHole` and `Tornado`, add `and not target:GetAttribute("Flying")` (the model's attribute) where a new pull/hold starts, and release an existing hold when the target starts flying. Header comments note "in flight, Iridescent Requiem slips it".
- [ ] **Step 4:** Syntax-check the four files.
- [ ] **Step 5:** Commit: `git commit -m "Desaturated grounds light; flight slips Event Horizon and Tornado"`

### Task 3: Shutter (ranged)

**Files:**
- Create: `src/ServerScriptService/Skills/Shutter.luau`
- Modify: `src/StarterPlayer/StarterPlayerScripts/Ranged.client.luau:373` (own-shot effect name)

**Interfaces:**
- Consumes: `Framed.Has/Extend`, `Projectiles.Cast(from, offset, ignore)`.
- Produces: `Shutter.Fire(player, character, origin, direction)`; CONFIG `Damage = 9`, `FrameExtend = 1.5`. Fires `"Shutter"(origin, finish, struck: boolean)` to every client but the shooter. `Ranged.client` fires `ranged.beam.effect or "LightShot"` locally.

- [ ] **Step 1:** Implement like `LightShot.Fire`; on a hit, `Framed.Extend(player, model, CONFIG.FrameExtend)` when `Framed.Has`.
- [ ] **Step 2:** Change `Ranged.client.luau:373` to use `ranged.beam.effect or "LightShot"`.
- [ ] **Step 3:** Syntax-check; commit: `git commit -m "Add Photoshop's Shutter"`

### Task 4: Z Snapshot and Step In

**Files:**
- Create: `src/ServerScriptService/Skills/Snapshot.luau`

**Interfaces:**
- Consumes: `PhotoshopUtil.lockOn/groundAt/alive`, `Framed.Mark/Has/Nearest`, `SkillSetConfig.RecastAttribute("Photoshop", "Z")`.
- Produces: `Snapshot.Cast(player, character, aim) -> boolean` (false with no target, so no cooldown); `Snapshot.Recast(player, character)`. CONFIG `Range = 50`, `Cone = 30`, `Damage = 12`, `StepRange = 60`, `BehindDistance = 4`. Events: `"Snapshot"(character, model)`, `"StepIn"(character, from, to)`.

- [ ] **Step 1:** Cast: lock on, deal damage, `Framed.Mark`; if marked, set the recast attribute and clear it when the frame ends (`task.delay` re-checking `Framed.Has`, so an extended frame keeps it).
- [ ] **Step 2:** Recast: pick `Framed.Nearest(player, root.Position, StepRange)`; destination = target root + its back × `BehindDistance`; if a raycast from the target to that point hits a wall, use the side facing her instead; ground it with `groundAt`; `PivotTo` facing the target; clear the recast attribute.
- [ ] **Step 3:** Syntax-check; commit: `git commit -m "Add Snapshot and Step In"`

### Task 5: X Photo Teleport and Paste

**Files:**
- Create: `src/ServerScriptService/Skills/PhotoTeleport.luau`

**Interfaces:**
- Consumes: `Framed.Nearest`, `PhotoshopUtil.groundAt/alive/playerOf`, `CrowdControl.CanControl/Apply`, `Passives.ResistEdit`.
- Produces: `PhotoTeleport.Cast(player, character, aim) -> boolean` (false when `groundAt` finds nothing); `PhotoTeleport.Recast(player, character)`. CONFIG `Range = 60`, `Lifetime = 8`, `PasteRange = 60`, `PasteHold = 0.5`. One photo per player at a time (a new cast replaces it). Events: `"PhotoPin"(id, character, point, lifetime)`, `"PhotoPaste"(id, model, from, to)`, `"PhotoGone"(id)`.

- [ ] **Step 1:** Cast: clamp the aim to `Range` (flat), ground it, store `{ id, point, expires }`, set the recast attribute, expire after `Lifetime` (fire `"PhotoGone"`, clear the attribute).
- [ ] **Step 2:** Recast: if `Framed.Nearest(player, point, PasteRange)` gives a target that may be controlled (`CanControl` for players) and isn't resisted (`ResistEdit` for players), `PivotTo` it onto the photo, zero its velocity, `CrowdControl.Apply(model, PasteHold)`; otherwise paste her. Then end the photo.
- [ ] **Step 3:** Syntax-check; commit: `git commit -m "Add Photo Teleport and Paste"`

### Task 6: C Desaturate

**Files:**
- Create: `src/ServerScriptService/Skills/Desaturate.luau`

**Interfaces:**
- Consumes: `StatusEffects.Apply(model, "Desaturated", { source = player, stat = "Superliminal", skillSet = "Photoshop" })`, `Passives.ResistEdit`.
- Produces: `Desaturate.Cast(player, character, aim) -> boolean`. CONFIG `Range = 50`, `Radius = 18`, `Duration = 4`, `TickInterval = 0.5`, `TickDamage = 4`, `Linger = 1` (the status's own duration). Event: `"Desaturate"(id, center, radius, duration)`.

- [ ] **Step 1:** Clamp/ground the centre; every tick, for each living enemy root within `Radius` (flat, the zone is a column so fliers count): deal `TickDamage`, then apply Desaturated unless `ResistEdit` (players only). Stop early if the caster is gone (`alive`); the zone itself stays its full duration otherwise.
- [ ] **Step 2:** Syntax-check; commit: `git commit -m "Add Desaturate"`

### Task 7: V Iris Horizon

**Files:**
- Create: `src/ServerScriptService/Skills/IrisHorizon.luau`

**Interfaces:**
- Consumes: `PhotoshopUtil.lockOn/alive/playerOf`, `Framed.Has`, `Passives.ResistEdit`.
- Produces: `IrisHorizon.Cast(player, character, aim) -> boolean` (false with no target). CONFIG `Range = 60`, `Cone = 30`, `RingRadius = 8` (16 across), `CloseTime = 1.5`, `FramedCloseTime = 0.4`, `FramedStartShare = 0.5`, `TargetDamage = 45`, `SplashDamage = 25`, `SplashRadius = 10`, `EscapedDamage = 10`. Events: `"IrisHorizon"(id, model, ringRadius, closeTime, startShare)`, `"IrisBurst"(id, point, splashRadius, caught: boolean)`.

- [ ] **Step 1:** Ring centre follows the target's root each step; its radius shrinks from `RingRadius * (1 - startShare)` to 0 over the close time. At close: `caught` = the target is still within the radius it had a step before closing (track the target's flat distance from the centre each step against the current radius; leaving it once = escaped).
- [ ] **Step 2:** Burst at the target's position: target takes `TargetDamage` if caught else `EscapedDamage`; others within `SplashRadius` take `SplashDamage`; everyone hit who is flying is grounded (`SetAttribute("Flying", nil)`) unless `ResistEdit`. Abort without a burst if the caster stops being `alive`; burst at the last centre if the target dies or leaves.
- [ ] **Step 3:** Syntax-check; commit: `git commit -m "Add Iris Horizon"`

### Task 8: F Kaleidoscope and beam reflection

**Files:**
- Create: `src/ServerScriptService/Skills/Kaleidoscope.luau`
- Modify: `src/ServerScriptService/Skills/LightShot.luau`, `src/ServerScriptService/Skills/PrismShot.luau`

**Interfaces:**
- Consumes: `Framed.Has`, `PhotoshopUtil.alive`.
- Produces: `Kaleidoscope.Cast(player, character, aim) -> boolean`; `Kaleidoscope.Reflects(humanoid: Humanoid, shooter: Model) -> Player?` (the Photoshop player whose own humanoid this is, with her Kaleidoscope running and `shooter`'s root inside its radius). CONFIG `Radius = 60`, `Duration = 5`, `TickInterval = 0.5`, `HitDamage = 7`, `FramedHits = 2`. Events: `"Kaleidoscope"(id, character, center, radius, duration)`, `"KaleidoscopeHit"(id, model)`, `"Reflect"(from, to)`.

- [ ] **Step 1:** Zone centred where she cast (it doesn't follow her); tick hits as specified; ends early when she stops being `alive`.
- [ ] **Step 2:** In `LightShot.Fire` and each beam of `PrismShot`: when the struck humanoid passes `Kaleidoscope.Reflects(humanoid, character)`, deal the same base damage to the shooter's humanoid as `reflector`'s hit with Photoshop's options, fire `"Reflect"`, and skip the original hit. Header comments mention it.
- [ ] **Step 3:** Syntax-check; commit: `git commit -m "Add Kaleidoscope; it bounces light beams back"`

### Task 9: History, Undo and the Gallery (server)

**Files:**
- Create: `src/ServerScriptService/PhotoshopServer.server.luau`
- Modify: `src/ServerScriptService/PlayerStats.luau:46-48` (`PhotoGallery = ""` in `TEXT_DEFAULTS`)

**Interfaces:**
- Consumes: `Damage.OnDealt(listener)`, `CrowdControl.Held`, `PhotoshopUtil.groundAt/alive`, `SkillSetConfig.UndoReadyAttribute`.
- Produces: RemoteEvents made in code in ReplicatedStorage: `Undo` (client → server, no args) and `PhotoGallery` (client → server `(action: "save" | "travel", slot: number)`). Player attribute `PhotoshopUndoReadyAt`, and `PhotoGallery` text `"x,y,z;x,y,z;"` (one entry per slot, empty for none, one decimal place). CONFIG `SampleInterval = 0.25`, `GallerySlots = 3`, `CombatLock = 8`, `DevelopTime = 2`. Events: `"Undo"(character, from, to)`, `"GalleryDevelop"(character, time)`, `"GalleryTravel"(character, from, to)`, `"GalleryCancel"(character)`.

- [ ] **Step 1:** History: every `SampleInterval`, for each player holding Photoshop, push `{ at, pivot }`; drop samples older than `rewind`. On unequip or death, clear.
- [ ] **Step 2:** Damage log via `Damage.OnDealt`: for a victim player holding Photoshop, push `{ at, dealt }` unless `options.skillSet == "Mandela"`. Also stamp `lastCombat[player]` for attacker and victim players.
- [ ] **Step 3:** Undo: refuse when not holding Photoshop, dead, `CrowdControl.Held(character)`, or before `PhotoshopUndoReadyAt`. Otherwise `PivotTo` the oldest kept sample, heal `healShare` × the logged damage since that sample's time × `StatusConfig.HealMultiplier(character)` (Poisoned halves it), capped at `MaxHealth`, clear history and log, set the ready attribute.
- [ ] **Step 4:** Gallery: validate `action` and `slot` (integer 1..3). `save`: needs Photoshop equipped and the character on the ground (`groundAt` within 4 studs of the feet); writes the slot. `travel`: needs the slot filled, Photoshop equipped, no combat for `CombatLock` s; fires `"GalleryDevelop"`, waits `DevelopTime` and cancels (`"GalleryCancel"`) if any damage was logged meanwhile or the caster stopped being `alive`; then `PivotTo` the slot. One develop at a time per player. Parse the saved string defensively (bad entry → empty slot).
- [ ] **Step 5:** Syntax-check; commit: `git commit -m "Add History, Undo and the photo Gallery"`

### Task 10: Client controls (SkillBar, Inventory, Gallery picker)

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/SkillBar.client.luau` (`tryOvercharge`, ~473-501, and the meter label ~611)
- Modify: `src/StarterPlayer/StarterPlayerScripts/Inventory.client.luau` (~558-561 detail rows)
- Create: `src/StarterPlayer/StarterPlayerScripts/PhotoGallery.client.luau`

**Interfaces:**
- Consumes: the `Undo` and `PhotoGallery` remotes, `PhotoshopUndoReadyAt`, `PhotoGallery` attribute.
- Produces: G fires `Undo` for a set with `undo` (denied-flash when cooling, same as overcharge); the meter area shows `UNDO [G]` or the seconds left. Inventory lists `G — Undo`. T toggles a square 3-slot panel (each slot: SAVE and GO buttons, "empty" or the slot's coordinates as text), only with Photoshop equipped; it closes on unequip.

- [ ] **Step 1:** SkillBar and Inventory edits, following the existing flight/overcharge branches.
- [ ] **Step 2:** PhotoGallery picker, styled like the other square menus (borrow `ShopMenu`'s frame look).
- [ ] **Step 3:** Syntax-check; commit: `git commit -m "Add Undo to the skill bar and the T photo gallery"`

### Task 11: Visuals

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/SkillEffects/PhotoshopEffects.luau`
- Modify: `src/StarterPlayer/StarterPlayerScripts/SkillEffects/init.client.luau` (merge its functions into `effects` before the `play` wiring)

**Interfaces:**
- Consumes: every event named in Tasks 3–9, with those exact argument lists; `VFX` helpers (`Shake`, `ImpactFrameNear`, `ScreenSpeedLines`, `Ground`, `Crater`).
- Produces: `PhotoshopEffects` returns `{ [kind] = function(...) }`, all built from code (Parts, Beams, ParticleEmitters, Highlights) in `PhotoshopPink`/`PhotoshopBlue`; nothing from `VFXPrefabs`.
- Looks: Shutter: white flash + pink/blue beam. Framed: four pink corner brackets round the target (caster only). Snapshot/StepIn: camera flash, fade at the old spot. PhotoPin: a flat photo frame standing at the point. PhotoPaste: the photo flips and the model appears. Desaturate: a grey translucent column with drifting grey flakes. IrisHorizon: a ring of 8 photo cards shrinking round the target; IrisBurst: a rainbow-rimmed black sphere that implodes then bursts (crater, shake). Kaleidoscope: a dome of mirrored triangular shards; KaleidoscopeHit: a shard flash on the model. Reflect: a beam back along `from→to`. Undo / GalleryTravel: a rewind ghost at the old spot. GalleryDevelop: a photo developing over her head for `time`. Desaturated status: a grey Highlight while the status attribute is on (in `StatusVFX` if that's where per-status looks live).

- [ ] **Step 1:** Implement each function with every created instance parented under `workspace.SkillEffects` (as the other effects do) and cleaned up with `Debris`.
- [ ] **Step 2:** Syntax-check; commit: `git commit -m "Draw Photoshop's visuals"`

### Task 12: Manifest, roadmap and the in-game checklist

**Files:**
- Modify: `studio-manifest.json` (entries for the 10 new scripts, with class and path the suffix implies)
- Modify: `ROADMAP.md` (Photoshop: built, waiting on Studio apply and playtest; list the Studio items)
- Create: `docs/superpowers/specs/2026-10-08-photoshop-checklist.md`

- [ ] **Step 1:** Manifest entries matching the existing format.
- [ ] **Step 2:** Checklist: one line per move, per Framed combo, per counter (two players), and one per Review Focus item above (die mid-Iris, target respawns mid-ring, Step In against a wall, photo pinned over a cliff, Undo after falling, gallery spam, corrupt gallery string via the admin panel or a fresh save).
- [ ] **Step 3:** Run the syntax check over all of `src/`; commit: `git commit -m "Photoshop: manifest, roadmap and test checklist"`; push.
