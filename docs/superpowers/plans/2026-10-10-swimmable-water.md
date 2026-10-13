# Swimmable Water Parts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Who runs it:** Tasks 1–3 are code: a **cloud session** can write them. Task 4 needs **Studio**
> (tag the water parts, playtest, tune the feel). Branch `claude/vigilant-rubin-ckqtnn` (or a fresh
> branch off it). Read `CLAUDE.md`.

**Goal:** The map's water **Parts** (kept as parts, not converted to Terrain) become swimmable: you sink into them, float at the surface, swim where the camera points, rise with Space and climb out at the edge, with Roblox's swim animation.

**Architecture:** Roblox only swims in Terrain water, so swimming in parts is scripted. Water parts are tagged `Water` in Studio and made non-solid. A shared `Water` module answers "is this point inside water, and where's the surface?" (an oriented-box test, Lune-tested). A client `Swim` script, running on the local character (which the client owns, so movement replicates), puts the Humanoid in the Swimming state and drives it with a `LinearVelocity` and a buoyancy `VectorForce`. Server checks that care (Gallery saves) use the same module.

**Tech Stack:** Roblox Luau; Lune (`tests/run.sh`); StyLua (parse) and selene in `~/.cargo/bin`.

**Spec (approved in chat on 2026-10-10; this section is the spec):**
- **The water stays Parts.** Every water part is tagged **`Water`** (CollectionService) and set to `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, so you fall into it and ground raycasts see the floor under it.
- **In water** (your character's root inside a `Water` part):
  - You **float at the surface** when you aren't moving (your head just above it).
  - You **swim where the camera points** with the move keys (looking down and moving dives); **Space** rises. Speed **16** studs/s (normal walk speed), no sprint in water.
  - **At the surface by an edge, Space jumps out** (a normal jump).
  - Roblox's **swim animation** plays (the rig's Animate script reacts to the Swimming state).
  - Gravity is cancelled while in water; leaving the water gives normal physics back at once.
- **Not in water:** nothing changes.
- **Flying** (Iridescent Requiem) ignores water. **Dash and Lightstep** work in water. **Double jump** doesn't work underwater. No drowning, no swim stamina.
- **Saving a Gallery photo while in water is refused** (no footing), like in the air.
- Other players see you swim (your client owns your character, so its movement replicates).

## Global Constraints

- Numbers in `Water` (or the Swim script's CONFIG): `SwimSpeed = 16`, `SurfaceOffset = 1.2` (studs the root floats below the surface; head above), `RiseSpeed = 10`, `CheckInterval = 0` (every frame on the client), the tag `"Water"`.
- Only the **local** character is driven by the client; no server physics.
- Every Humanoid state the script disables while swimming is re-enabled on leaving the water, death and respawn.
- Match the surrounding style (header comments, CONFIG with units, tabs).
- Don't invent instances: tagging and setting the parts' properties is Studio work (Task 4).

## Review Focus

1. **Stuck states:** leaving the water, dying in it, respawning, or being yanked out by a skill (Event Horizon's pull, Step In) always restores normal physics and states; no floating on land. (Task 2 step.)
2. **Skill movers in water:** a BlackHole/Collapse pull (`LinearVelocity` with `Hold`), a knockback or a Paste still move a swimming player; the swim controller yields to them (it skips driving while a `Hold`-tagged mover is on the root, like Dash does). (Task 2 step.)
3. **Rotated and overlapping parts:** the inside test works for rotated parts and when two water parts touch (no flicker at the seam). (Task 1 test.)
4. **Edges:** you can always get out: at the surface next to a ledge up to about 4 studs high, Space gets you onto it. (Task 4 playtest.)
5. **NPCs:** enemies don't swim; they walk along the bottom under water parts. If that looks wrong or gets them stuck, note it for the enemy rework rather than fixing it here. (Task 4 playtest.)

---

### Task 1: The Water module (pure test, TDD)

**Files:** Create `src/ReplicatedStorage/Water.luau`, `tests/Water.spec.luau`.

**Interfaces:**
- Produces: `Water.Tag = "Water"`, the numbers above, `Water.inside(cframe: CFrame, size: Vector3, point: Vector3) -> boolean` (oriented box), `Water.surfaceY(cframe, size, point) -> number` (the top of the box above that point, for unrotated-or-tilted parts: the highest point of the box's top face over `point`), and the game helpers `Water.Find(point) -> BasePart?` (any tagged part containing it) and `Water.IsIn(character) -> boolean` (its root).
- First line `local CFrame = CFrame or require("@lune/roblox").CFrame` and the same for `Vector3`, so Lune can run the pure functions (the game helpers only run in Roblox).

- [ ] **Step 1: Write the spec:** a 10×4×10 box at the origin: `(0,0,0)` inside, `(0,2.1,0)` outside, `(4.9,0,4.9)` inside, `(5.1,0,0)` outside; the same box rotated 45° about Y (its corners now on the axes, about 7.07 out): `(6,0,0)` inside, `(7.2,0,0)` outside, `(3.4,0,3.4)` inside, `(4,0,4)` outside; `surfaceY` of the unrotated box at any inside point is `2`.
- [ ] **Step 2:** `tests/run.sh`: FAIL (module missing).
- [ ] **Step 3:** Write the module (`cframe:PointToObjectSpace(point)` against half the size).
- [ ] **Step 4:** `tests/run.sh`: all pass.
- [ ] **Step 5:** StyLua and selene; commit `"Water: inside-the-water test"`.

### Task 2: The Swim client script

**Files:** Create `src/StarterPlayer/StarterPlayerScripts/Swim.client.luau`. Modify `DoubleJump.client.luau` (no double jump while `Water.IsIn`), `Sprint.client.luau` (no sprint while swimming), and `Flight.client.luau` only if flying needs an explicit skip.

- [ ] **Step 1:** Each frame: if the local character's root is in water and it isn't flying: on entering, disable `Freefall`, `Running`, `Climbing`, `Landed`, `GettingUp`, `FallingDown` states, `ChangeState(Swimming)`, and attach a `LinearVelocity` (world, `MaxForce` moderate) and a `VectorForce` cancelling gravity (`mass × workspace.Gravity`). While in: velocity = camera-relative move direction × `SwimSpeed`, plus `RiseSpeed` up while Space is held, plus a spring toward `surfaceY − SurfaceOffset` when idle near the top; Space at the surface → re-enable states and `Jump`. On leaving (or death/respawn): remove both movers and re-enable every state.
- [ ] **Step 2:** Yield to skill movers: if the root has a `LinearVelocity`/`BodyVelocity` with the `Hold` attribute that isn't ours, don't drive this frame (Review Focus 2). Read through Review Focus 1.
- [ ] **Step 3:** The DoubleJump and Sprint guards.
- [ ] **Step 4:** StyLua and selene; commit `"Swim: swimming in water parts"`.

### Task 3: Server-side water checks and docs

**Files:** `src/ServerScriptService/PhotoshopServer.server.luau` (Gallery "save": refuse when `Water.IsIn(character)`); create `docs/superpowers/specs/2026-10-10-swimmable-water-checklist.md` (every spec line and Review Focus item as something to try); update `ROADMAP.md`, `docs/superpowers/plans/README.md`, `CLAUDE.md` (Architecture: the `Water` tag and module).

- [ ] **Step 1:** The Gallery check; the docs.
- [ ] **Step 2:** StyLua and selene; `tests/run.sh`; commit `"Water: no Gallery saves in water; checklist and docs"`; push.

### Task 4 (Studio, local session): tag, playtest, tune

- [ ] **Step 1:** Repo → Studio per `CLAUDE.md`.
- [ ] **Step 2:** Find the water parts (Material Water, or named Water/Sea/Lake/River, or big transparent blue parts); show the owner the list with screenshots; with their OK, tag each `Water` and set `CanCollide`/`CanQuery`/`CanTouch` false.
- [ ] **Step 3:** Playtest with the checklist (swim, dive, surface, climb out at edges, Dash/Lightstep in water, a pull and a Step In on a swimmer, dying in water, a second player watching). Tune `SwimSpeed`, `SurfaceOffset` and `RiseSpeed` with the owner.
- [ ] **Step 4:** Move the `studio` tag; re-export Studio → repo; push.
