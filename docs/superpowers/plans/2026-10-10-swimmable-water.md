# Swimmable Water Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Written for a LOCAL session with the Roblox Studio MCP.** The water is part of the map, which
> only exists in Studio. Branch `claude/vigilant-rubin-ckqtnn` (or a fresh branch off it). Read
> `CLAUDE.md`.

**Goal:** Players swim in the map's water instead of walking on it or through it, and every move and skill behaves sensibly in and over water.

**Architecture:** No script in `src/` disables swimming (checked: nothing calls `SetStateEnabled` or touches `Swimming`), so the water is almost certainly made of **Parts** (Roblox only swims in **Terrain water**). The fix is to turn those parts into Terrain water with `Terrain:FillBlock`, which gives Roblox's built-in swimming, splashes and waves for free, then fix the few scripts whose ground raycasts should ignore water.

**Tech Stack:** Roblox Studio (MCP), Luau; StyLua (parse) and selene if installed; `tests/run.sh` must still pass.

**Spec (approved in chat on 2026-10-10; this section is the spec):**
- The map's water becomes swimmable using Roblox's normal swimming (Space to rise, move keys to swim).
- It should look like water: the owner picks the Terrain water colour, transparency and waves (`Terrain.WaterColor`, `WaterTransparency`, `WaterWaveSize`, `WaterWaveSpeed`) to match the old look.
- No drowning, no swim stamina for now (normal Roblox swimming).
- Moves stay sane in water: dashing and Lightstep work while swimming; skills that place things "on the ground" (Snapshot's landing, Photo Teleport, Gallery saves, aim previews, craters) use the solid floor under the water, or the water surface where there's no floor within reach, never place someone at the bottom of deep water.
- If some water must stay a Part (for example moving or animated water), it keeps its look and gets a Terrain water volume under it, rather than a custom swim script.

## Global Constraints

- **Nothing is uploaded** (no new assets). Terrain water is built in.
- Keep a backup: before converting, duplicate the water parts into `ServerStorage.OldWaterBackup` (not deleted) until the owner approves the result.
- Raycast fixes use `RaycastParams.IgnoreWater = true` only where a solid floor is wanted; leave hit detection (projectiles, beams, melee) alone.
- Match the surrounding style.

## Review Focus

1. **Deep water and "ground" skills:** Step In or Paste onto someone swimming over deep water lands the caster at their height (the existing "over a drop" rule), not on the sea floor. (Task 3 step.)
2. **Gallery saves while swimming:** saving refuses like it does in the air (no solid footing), so a photo can't be saved mid-lake. (Task 3 step.)
3. **NPC enemies near water:** they don't get stuck swimming or chase into water forever; if they do, they give up and return home like when a target flies. (Task 4 playtest.)
4. **Performance:** the converted Terrain doesn't add a big lag spike; very large water areas are filled in chunks. (Task 2 step.)
5. **Old parts:** the original water parts are gone from Workspace (or made non-colliding and kept only for looks) so nobody walks on an invisible floor. (Task 2 step.)

---

### Task 1: Find the water

- [ ] **Step 1:** In the Edit datamodel, list every candidate: BaseParts with `Material = Water`, named like "Water"/"Sea"/"Lake"/"River", or large flat transparent blue parts; and any existing Terrain water (`Terrain:ReadVoxels` over the map bounds, or visually).
- [ ] **Step 2:** Take frozen screenshots of each water area and show the owner the list (names, sizes, positions). Confirm which ones should become swimmable.

### Task 2: Convert to Terrain water

- [ ] **Step 1:** Back up the confirmed parts into `ServerStorage.OldWaterBackup`.
- [ ] **Step 2:** For each part: `workspace.Terrain:FillBlock(part.CFrame, part.Size, Enum.Material.Water)` (for a wedge or cylinder, `FillWedge` / `FillCylinder`; for huge parts, fill in chunks of at most 512 studs). Then remove the part from Workspace (or, for a part kept for looks, set `CanCollide = false`, `CanQuery = false`, `CanTouch = false`).
- [ ] **Step 3:** Match the look with the owner: set `Terrain.WaterColor`, `WaterTransparency`, `WaterReflectance`, `WaterWaveSize`, `WaterWaveSpeed`; screenshot before/after.
- [ ] **Step 4:** Playtest: walk in, swim, jump out at an edge; check the frame rate. Read through Review Focus 4 and 5.

### Task 3: Ground raycasts that should ignore water

**Files (check each; change only where a solid floor is wanted):** `src/ServerScriptService/PhotoshopUtil.luau` (`groundAt`), `src/ServerScriptService/Skills/Snapshot.luau` (landing), `src/ServerScriptService/Skills/PhotoTeleport.luau`, `src/ServerScriptService/PhotoshopServer.server.luau` (Gallery save standing check), `src/StarterPlayer/StarterPlayerScripts/AimIndicator.luau` (ground previews), `src/ReplicatedStorage/VFX.luau` (`Ground` / `Crater`; it already lists `Enum.Material.Water` ~463, check what for), plus any other `RaycastParams` found by `grep -rn "RaycastParams.new" src`.

- [ ] **Step 1:** For each, decide: solid floor wanted → `IgnoreWater = true`; otherwise leave it. For Gallery saves, also refuse while the Humanoid state is `Swimming` (Review Focus 2). Keep Snapshot's "over a drop" rule working over deep water (Review Focus 1).
- [ ] **Step 2:** StyLua and selene on the changed files; `tests/run.sh`.
- [ ] **Step 3:** Commit `"Ground raycasts ignore water where a floor is wanted"`.

### Task 4: Playtest and wrap-up

- [ ] **Step 1:** In water, try: swimming with each power out; Dash and Lightstep while swimming; double jump out of water; Photoshop Snapshot → Step In on a swimming dummy; Photo Teleport onto water; saving a Gallery photo while swimming (refused); Mandela's Event Horizon and Tornado over water; an NPC chasing you into water (Review Focus 3). Screenshots for the owner.
- [ ] **Step 2:** With the owner's OK, delete `ServerStorage.OldWaterBackup`.
- [ ] **Step 3:** Add `docs/superpowers/specs/2026-10-10-swimmable-water-checklist.md` (the Step 1 list); update `ROADMAP.md` and `docs/superpowers/plans/README.md` (done). Re-export Studio → repo (`CLAUDE.md`), move the `studio` tag, commit, push.
