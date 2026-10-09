# Photoshop Revisual Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Written for a LOCAL session with the Roblox Studio MCP.** It needs Studio for every step:
> importing packs, building prefabs, frozen playtest screenshots, and the owner's eye.
> Branch: `claude/vigilant-rubin-ckqtnn`. Do it after (or alongside)
> `2026-10-09-photoshop-punches.md`.

**Goal:** Replace Photoshop's remaining code-built visuals with prefabs made from imported effect/particle packs, one move at a time, until every move matches the target looks in `docs/photoshop-vfx-plan.md`.

**Architecture:** Visuals live in `StarterPlayerScripts/SkillEffects/PhotoshopEffects.luau` and play prefabs from `ReplicatedStorage.VFXPrefabs.Photoshop` through `VFX.Play(path, where, options)`. Each step imports or adapts a pack effect into a prefab (emitter attributes `EmitCount`/`EmitDuration`/`Tint`/`Hold`), swaps the code-built piece for `VFX.Play`, and checks the result in a frozen playtest screenshot before moving on.

**Tech Stack:** Roblox Studio (MCP), imported VFX packs (Creator Store, or VFX websites the owner picks), Luau.

**Spec:** `docs/photoshop-vfx-plan.md` (the target looks per move, the art direction and the order). Also `CLAUDE.md`'s rule: **final visuals come from imported packs, never from stock Roblox particles or parts built in code** (those stay only as a fallback while a prefab is missing).

## Global Constraints

- Colours: pink `#FF7EC8` (`SkillSetConfig.PhotoshopPink`) and light blue `#8CD2FF` (`SkillSetConfig.PhotoshopBlue`). Use the prefab `Tint` attribute or `VFX.Play`'s `color` option.
- **The owner approves before anything is imported or uploaded to their account.** List each pack or asset and where it comes from, and wait for an OK.
- **Screen-wide flashes and black frames go through `VFX.ImpactFrame`/`ImpactFrameNear`/`ScreenSpeedLines`**, or check `Preferences.Get("Flashes")`. **Shake goes through `VFX.Shake`.**
- Particle counts scale with `VFX.Quality()` (`VFX.Play` already does this for prefabs).
- **One move per task.** Each ends with frozen screenshots shown to the owner and their OK.
- Keep every `effects.<Kind>(...)` signature as it is. The server events don't change.

## Where things stand

The pack prefabs that already exist: `Photoshop/CameraFlash`, `PhotoGlint`, `GreyAsh`, `PrismGlitter`, plus the `Shared/*` impacts, shockwaves, sparks and aura burst.

Still **code-built**, to replace:
- **Photo cards:** white Parts with a SelectionBox, used by Snapshot, Photo Pin, Step In, Paste, Iris Horizon's 8 cards and the Gallery.
- **Iris Horizon's burst:** the dark core sphere and the rainbow rim cylinders.
- **Kaleidoscope's dome:** the glass WedgeParts.
- **Desaturate's column:** a grey ForceField cylinder.
- **Beams:** Shutter, Reflect and Undo use the `lightBeam` Part beams.
- **Pixelate:** square pixel Parts, used when someone is cut out of the picture.
- **Framed's corners:** a BillboardGui. That's UI, so it can stay, but restyle it to match.

## Review Focus

1. **A prefab missing in a live server** (not published, renamed): `VFX.Play` warns and returns nil. Each swap keeps the old code-built piece as the fallback when `VFX.Play` returns nil, so nothing goes invisible.
2. **Zone prefabs with `Hold`** (the Desaturate column, the Kaleidoscope dome): they must end when the zone ends early (`DesaturateEnd`, `KaleidoscopeEnd`, the caster dying). Use `VFX.Stop(holder)`.
3. **Many players casting at once:** check the frame rate with 3 Kaleidoscopes, or 6 Desaturates, on screen.
4. **Flashes off in Settings:** no full-screen white or black frames from Photoshop.
5. **Colour on Tint "FromWhite" vs "Solid":** pink/blue must read on both a bright sky and a dark night. Screenshot both.

---

### Task 1: Iris Horizon (P1)

**Files:** `PhotoshopEffects.luau` (`IrisHorizon`, `IrisBurst`, `IrisCancel`), plus new prefabs `Photoshop/IrisBlades`, `Photoshop/RainbowCore`, `Photoshop/RainbowBurst`, `Photoshop/PrismShards`.

- [ ] **Step 1:** Freeze-frame the current ring and burst in a playtest, show the owner, and confirm the target from the VFX plan (shutter blades closing, a rainbow black hole, a prism burst).
- [ ] **Step 2:** Propose packs/assets for blades, the black-hole core and the rainbow shockwave. Get the owner's OK, then import and build the four prefabs with tint attributes.
- [ ] **Step 3:** Swap the code: the blades follow the existing ring loop (posed per blade, as the cards are now). `IrisBurst` plays RainbowCore, then RainbowBurst and PrismShards, keeping `VFX.Crater` and `VFX.Shake`. The code-built cards and spheres remain only as the fallback.
- [ ] **Step 4:** Playtest: caught and escaped versions, a Framed fast close, a cancel on caster death. Take frozen screenshots, get the owner's OK, and commit `"Iris Horizon: imported VFX"`.

### Task 2: Kaleidoscope (P1)

**Files:** `PhotoshopEffects.luau` (`Kaleidoscope`, `KaleidoscopeHit`, `KaleidoscopeEnd`, `Reflect`), plus prefabs `Photoshop/GroundFracture`, `Photoshop/MirrorShards` (Hold), `Photoshop/ShardBreak`, `Photoshop/PrismBeam`. `PrismGlitter` exists already.

- [ ] Steps as in Task 1: freeze the current look, agree the target (ground fracture opening, a rotating mirror dome, a ghost copy striking on each hit, the dome shattering at the end), import and build, swap with fallback, playtest (including an early end), get OK, commit.

### Task 3: Snapshot, Framed and Step In (P2)

**Files:** `Snapshot`, `StepIn`, `Framed` (restyle the BillboardGui only: square, no UICorner), plus prefabs `Photoshop/LensFlare`, `Photoshop/PolaroidPop`, `Photoshop/CutOut` (replacing `pixelate` for Step In). `CameraFlash` exists already.

- [ ] Steps as in Task 1. Include the Step In combo's punch hits from the punches plan (`PhotoshopPunchHit`) in the screenshots.

### Task 4: Desaturate (P2)

**Files:** `Desaturate`, `DesaturateEnd`, plus prefabs `Photoshop/ColorDrain`, `Photoshop/FilmGrain` (Hold), `Photoshop/ColorFlecks` (Hold). `GreyAsh` exists already. Keep the grey Highlight and the local ColorCorrection.

- [ ] Steps as in Task 1. Check an early end and two overlapping zones.

### Task 5: Photo Teleport and Paste (P2)

**Files:** `PhotoPin`, `PhotoPaste`, `PhotoGone`, plus prefabs `Photoshop/PhotoBeacon`, `Photoshop/PasteDoorway`, `Photoshop/CutLine`.

- [ ] Steps as in Task 1. Show both a self-paste and Cut & Paste on an enemy.

### Task 6: Shutter, Undo, the Gallery and Equip (P3)

**Files:** `Shutter`, `Undo`, `GalleryDevelop`, `GalleryTravel`, `GalleryCancel`, and Equip for Photoshop, plus prefabs `Photoshop/ShutterStreak`, `Photoshop/RewindStreak`, `Photoshop/PhotoBurn`.

- [ ] Steps as in Task 1.

### Task 7: Wrap-up

- [ ] Update `docs/photoshop-vfx-plan.md` ("Where things stand") and the roadmap.
- [ ] Re-export Studio → repo (`tools/export_chunk.luau` and `assemble_export.py`, as in `CLAUDE.md`), move the `studio` tag, commit, and push.
