# Daylight Cycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Who runs it:** Tasks 1–6 are code: a **cloud session** can write them. Task 7 needs **Studio**
> (apply, look at the keyframes, playtest). Branch `claude/vigilant-rubin-ckqtnn` (or a fresh branch
> off it). Read `CLAUDE.md`.

**Goal:** A 20-minute server-driven day and night cycle that moves the sun, sky and lighting, with Iridescent Requiem's Luminance charging slowly by moonlight and Solar Lance weaker at night.

**Architecture:** The server keeps a time anchor (attributes on `ReplicatedStorage`); a pure `DayCycleConfig` module turns it into an hour, a phase and an interpolated look. Each client drives `Lighting` every frame from the anchor; the server sets `Lighting.ClockTime` once a second so its sun/moon checks are right. A new `SkyLight` helper answers "does sun or moonlight reach this point" for Luminance and Solar Lance. Admins can set and freeze the time.

**Tech Stack:** Roblox Luau; Lune (`tests/run.sh`) for the pure module; StyLua and selene if installed (`~/.cargo/bin`). None was installed on 2026-10-13: read edits carefully, since a syntax error breaks the whole script.

**Spec:** `docs/superpowers/specs/2026-10-13-daylight-cycle-design.md` (approved in chat 2026-10-13; read it first).

## Global Constraints

- `DayLength = 1200` real seconds per 24h day; `StartHour = 7`; `MoonShare = 0.25`.
- Phases: **Dawn** 5:00–7:00, **Day** 7:00–17:00, **Dusk** 17:00–19:00, **Night** 19:00–5:00.
- Attributes on `ReplicatedStorage`: `DayAnchorTime` (number, the hour at the anchor), `DayAnchorServerTime` (number, a `workspace:GetServerTimeNow()` value), `DayFrozen` (bool), `Phase` (string).
- The client **creates no instances** and skips any Lighting child that is missing. It only touches the permanent `ColorCorrection` named exactly `ColorCorrection` (skill effects add their own `VFXImpactPop`, `PossibilityGrade`, `RewriteGrade`, `Desaturated`).
- All player damage still goes through `Damage.Deal`; this plan touches no damage code.
- UI is square (no `UICorner`). Match surrounding style: tabs, header comments, CONFIG with units.
- Don't claim anything works in-game; the owner playtests. List what to try (Task 6 checklist).

## Review Focus

1. **Clock skew and wrap:** a client whose server-time is slightly behind the anchor (negative elapsed), an anchor hour of 24 or more, and running past midnight all give an hour in `[0, 24)`. (Task 1 tests.)
2. **Junk from the admin panel:** `SetTime` with NaN, ±infinity, a string, a negative, `24`, `30.5` never breaks the clock; valid numbers wrap with `% 24`. (Task 1 `CleanHour` tests; Task 5 uses it.)
3. **Freeze and resume don't jump the time:** freezing and unfreezing re-anchor at the current hour. (Task 2 step.)
4. **Client starts before the attributes replicate, or Lighting children are missing:** Lighting is left alone and nothing errors. (Task 3 step.)
5. **Horizon gap and cover:** when neither sun nor moon is above the horizon, or the light is blocked, `Exposure` is `nil` (shade), never a stale "sun". Standing under a roof at night is shade, not moonlit. (Task 4 steps and Task 6 checklist.)

---

### Task 1: DayCycleConfig (pure, TDD)

**Files:** Create `src/ReplicatedStorage/DayCycleConfig.luau`, `tests/DayCycleConfig.spec.luau`.

**Interfaces:**
- Produces (module table `DayCycleConfig`):
  - `DayLength: number` (1200), `StartHour: number` (7), `MoonShare: number` (0.25).
  - `HourAt(anchorHour: number, anchorServerTime: number, now: number, frozen: boolean) -> number`: the hour in `[0, 24)`; `frozen` returns `anchorHour % 24`; otherwise `(anchorHour + (now - anchorServerTime) * 24 / DayLength) % 24`.
  - `PhaseAt(hour: number) -> "Dawn" | "Day" | "Dusk" | "Night"` using the Global Constraints boundaries (start inclusive, end exclusive).
  - `CleanHour(value: any) -> number?`: `nil` unless `value` is a finite number; else `value % 24`.
  - `Keyframes: { Keyframe }` and `Sample(hour: number) -> Keyframe`. A `Keyframe` is `{ hour = number, Lighting = {...}, ColorCorrection = {...}, Atmosphere = {...}, Bloom = {...}, SunRays = {...}, Sky = {...} }`. Property names are real Roblox property names: `Lighting` {`Brightness`, `Ambient`, `OutdoorAmbient`, `ExposureCompensation`}, `ColorCorrection` {`TintColor`, `Brightness`, `Saturation`}, `Atmosphere` {`Color`, `Decay`, `Density`, `Haze`, `Glare`}, `Bloom` {`Intensity`}, `SunRays` {`Intensity`}, `Sky` {`StarCount`}. Numbers are numbers; **colours are `{r, g, b}` arrays in 0–255** (the module must not use `Color3`, so Lune can run it). `Sample` interpolates the two keyframes around `hour` (wrapping past 24 back to the first keyframe), numbers by lerp and colour arrays per channel; its result has no `hour` field that matters to callers.

- [ ] **Step 1: Write `tests/DayCycleConfig.spec.luau`** in the style of `tests/GuardConfig.spec.luau` (a `check(name, condition)` helper, exit non-zero on failure), requiring `../src/ReplicatedStorage/DayCycleConfig`. Assertions:
  - `HourAt(7, 100, 100, false) == 7`; `HourAt(7, 100, 150, false) == 8`; `HourAt(7, 100, 150, true) == 7`; `HourAt(23, 0, 100, false) == 1` (wraps); `HourAt(7, 100, 90, false)` is within `1e-9` of `6.8` (negative elapsed); `HourAt(24, 0, 0, false) == 0`; `HourAt(30, 0, 0, true) == 6`.
  - `PhaseAt`: `4.99` Night, `5` Dawn, `6.99` Dawn, `7` Day, `16.99` Day, `17` Dusk, `18.99` Dusk, `19` Night, `0` Night, `23.99` Night.
  - `CleanHour`: `CleanHour(6.5) == 6.5`, `CleanHour(24) == 0`, `CleanHour(30.5) == 6.5`, `CleanHour(-1) == 23`; `nil` for `0/0` (NaN), `math.huge`, `-math.huge`, `"7"`, `nil`, `{}`, `true`.
  - `Keyframes`: at least 6 entries, `hour` strictly ascending, first is `0`, last is below `24`, a keyframe at `12` exists, and every keyframe has the same property names in every group as the first one.
  - `Sample`: `Sample(12).Lighting.Brightness == 3` and `Sample(12).ColorCorrection.Saturation == 0.25`; `Sample(0)` equals the `hour = 0` keyframe; `Sample(24)` and `Sample(0)` give equal `Lighting.Brightness`; with `a`, `b` the keyframes at hours `5` and `7`, `Sample(6).Lighting.Brightness` is within `1e-9` of the mean of theirs, and each channel of `Sample(6).Lighting.Ambient` is the mean of theirs; with `l` the keyframe at the largest hour and `f` the one at `0`, `Sample((l.hour + 24) / 2)` (the wrap midpoint) has `Lighting.Brightness` equal to the mean of `l`'s and `f`'s; `Sample(-1)` equals `Sample(23)` in `Lighting.Brightness`.
- [ ] **Step 2:** Run `tests/run.sh`: FAIL (module missing).
- [ ] **Step 3: Implement the module.** Keyframes at hours `0, 5, 7, 12, 17, 19, 21` (add more if the look needs it). The **`12` keyframe uses today's Studio values exactly**: Lighting `Brightness 3`, `Ambient {88, 82, 176}`, `OutdoorAmbient {70, 70, 70}`, `ExposureCompensation 0`; ColorCorrection `TintColor {242, 245, 255}`, `Brightness 0`, `Saturation 0.25`; Atmosphere `Color {95, 249, 203}`, `Decay {143, 155, 222}`, `Density 0.34`, `Haze 0.75`, `Glare 0.75`; Bloom `Intensity 1`; SunRays `Intensity 0.15`; Sky `StarCount 0`. First-pass feel for the rest (tuned in Studio, Task 7): `Lighting.Brightness` 0 → 0.4, 5 → 0.7, 7 → 2.5, 17 → 2.5, 19 → 0.8, 21 → 0.5; `Ambient` and `OutdoorAmbient` a dark blue at night (about `{20, 24, 50}` and `{25, 30, 60}`) warming at 5/7 and 17/19; `ColorCorrection.TintColor` cool blue at night (about `{170, 190, 255}`), warm orange at 7 and 17 (about `{255, 215, 185}`); `Saturation` lower at night; `SunRays.Intensity` 0 at night, higher at 7 and 17; `Sky.StarCount` 0:3000, 5:1500, 7:0, 12:0, 17:0, 19:1500, 21:3000. One-line header comment saying what it is and that it is Lune-tested. `Sample` finds the surrounding pair by scanning `Keyframes`; with fewer than two keyframes it returns the first.
- [ ] **Step 4:** Run `tests/run.sh`: all `ok`.
- [ ] **Step 5:** Commit `"DayCycleConfig: hour, phase and look"`.

### Task 2: DayClock module and the server script

**Files:** Create `src/ServerScriptService/DayClock.luau`, `src/ServerScriptService/DayCycle.server.luau`.

**Interfaces:**
- Consumes: `DayCycleConfig` (Task 1).
- Produces (`DayClock`): `Start()`, `Hour() -> number`, `SetHour(hour: number)`, `SetFrozen(frozen: boolean)`, `IsFrozen() -> boolean`. Callers pass a number already cleaned by `DayCycleConfig.CleanHour`.

- [ ] **Step 1: Implement `DayClock`.** `Start()` sets the three anchor attributes on `ReplicatedStorage` (`DayAnchorTime = StartHour`, `DayAnchorServerTime = workspace:GetServerTimeNow()`, `DayFrozen = false`), applies once (sets `Lighting.ClockTime = Hour()` and the `Phase` attribute from `PhaseAt`), then loops `task.wait(1)` doing the same apply. `Hour()` reads the attributes through `DayCycleConfig.HourAt`. `SetHour(hour)` writes a new anchor `(hour, now)` and applies immediately. `SetFrozen(frozen)` first re-anchors at the **current** hour and `now` (so freezing and resuming never jump the time: Review Focus 3), then sets `DayFrozen`, then applies. Only write `Phase` when it changed.
- [ ] **Step 2: `DayCycle.server.luau`:** a three-line script with a header comment that requires `DayClock` and calls `Start()`.
- [ ] **Step 3:** Read both back for syntax and require paths (`ServerScriptService:WaitForChild`, `ReplicatedStorage:WaitForChild("DayCycleConfig")`). Commit `"DayCycle: server clock, Phase attribute"`.

### Task 3: DayCycleClient

**Files:** Create `src/StarterPlayer/StarterPlayerScripts/DayCycleClient.client.luau`.

**Interfaces:** Consumes `DayCycleConfig.HourAt` and `Sample` (Task 1) and the attributes written by Task 2.

- [ ] **Step 1: Implement.** `RunService:BindToRenderStep("DayCycle", Enum.RenderPriority.Last.Value, ...)` so the local write wins over the server's once-a-second `ClockTime`. Each frame: read `DayAnchorTime`, `DayAnchorServerTime`, `DayFrozen` from `ReplicatedStorage`; if either number is `nil`, return without touching anything (Review Focus 4). Compute `hour` with `HourAt(anchorTime, anchorServerTime, workspace:GetServerTimeNow(), frozen == true)`, set `Lighting.ClockTime = hour`, then for each group in `Sample(hour)` other than `hour`: the target is `Lighting` for the group `Lighting`, otherwise `Lighting:FindFirstChild(groupName)` and it must `:IsA(groupName)`; skip the group if missing. For each property: a 3-number array becomes `Color3.fromRGB(r, g, b)`, a number is set as is.
- [ ] **Step 2:** Read back for syntax; confirm nothing else in `src/` writes `Lighting.ClockTime` or these properties permanently (`grep`). Commit `"DayCycleClient: smooth lighting from the server clock"`.

### Task 4: SkyLight, Luminance and Solar Lance

**Files:** Create `src/ServerScriptService/SkyLight.luau`. Modify `src/ServerScriptService/LuminanceServer.server.luau`, `src/ServerScriptService/Skills/SolarLance.luau`.

**Interfaces:**
- Produces: `SkyLight.Exposure(position: Vector3) -> "sun" | "moon" | nil`. The caller passes the exact start point (the two callers add the +2 studs up themselves).
- Consumes: `DayCycleConfig.MoonShare`.

- [ ] **Step 1: `SkyLight.Exposure`.** If `Lighting:GetSunDirection().Y > 0` the light is the sun and the kind is `"sun"`; else if `Lighting:GetMoonDirection().Y > 0` it is `"moon"`; else return `nil`. Then the ray from `position` along the light direction × 1000 studs with the rules `LuminanceServer.inSunlight` has now: players' characters ignored, up to four parts passed through when `Transparency >= 0.5`, anything else blocks. Clear → the kind; blocked → `nil`. Move that loop here whole.
- [ ] **Step 2: `LuminanceServer`.** Delete `inSunlight`; require `SkyLight` and `DayCycleConfig`. In the tick, keep the existing chain order (desaturated, form, flying) and replace the final `elseif inSunlight(...)` / `else` pair with one `else` branch that calls `SkyLight.Exposure(root.Position + Vector3.new(0, 2, 0))` once: `"sun"` charges exactly as today; `"moon"` charges `passive.chargePerSecond * DayCycleConfig.MoonShare` (with the above-the-clouds multiplier still applying), `shaded` stays `false`; `nil` is the existing shade branch (`shaded = true`). Update the header comment (night/moonlight in two lines). Remove locals that become unused (`Lighting`, `SUN_RAY_LENGTH`, `SEE_THROUGH`, `Players` only if nothing else uses it).
- [ ] **Step 3: `SolarLance`.** Delete `underSky`; in `strike`, the covered branch becomes `if SkyLight.Exposure(point + Vector3.new(0, 2, 0)) ~= "sun" then` (same `CoveredShare` cut; moonlight counts as covered). Update the header comment ("where the sun can't reach (indoors, under cover, at night)"). Remove locals that become unused (`Lighting`, and `Players` if nothing else uses it). Note in the commit: parts at least 50% transparent no longer cover it (they never covered Luminance).
- [ ] **Step 4:** Read both files back for syntax; `grep` that no `inSunlight`/`underSky` remains. Commit `"SkyLight: shared sun/moon check; moonlight charges Luminance"`.

### Task 5: Admin set-time and freeze

**Files:** Modify `src/ServerScriptService/AdminServer.server.luau`, `src/StarterPlayer/StarterPlayerScripts/AdminPanel.client.luau`.

**Interfaces:** Consumes `DayClock.SetHour/SetFrozen/IsFrozen/Hour` (Task 2) and `DayCycleConfig.CleanHour` (Task 1). Produces admin actions `SetTime(target, hour)` and `FreezeTime(target)`; both ignore the target (the time is global).

- [ ] **Step 1: Server.** `actions.SetTime`: `CleanHour(hour)`; `nil` → `false, "Enter an hour from 0 to 24"`; else `DayClock.SetHour` and `true, "Set the time to HH:MM"` (zero-padded; minutes `math.floor((h % 1) * 60)`). `actions.FreezeTime`: toggles with `DayClock.SetFrozen(not DayClock.IsFrozen())` and returns `true, "Time frozen at HH:MM"` or `"Time is running"`. Use a small local `clockText(hour)` for the HH:MM.
- [ ] **Step 2: Panel.** After the MASTERY block add `heading("WORLD")`, `inputRow("Time (0–24)", "Set", function(value) run("SetTime", value) end)`, and a full-width button row (same pattern as the other `button(section(ROW_HEIGHT), ...)` rows) whose text is "Freeze time" or "Resume time" following `ReplicatedStorage:GetAttribute("DayFrozen")` (update on `GetAttributeChangedSignal("DayFrozen")`); `Activated` runs `run("FreezeTime")`.
- [ ] **Step 3:** Read back for syntax. Commit `"Admin: set and freeze the time of day"`.

### Task 6: Checklist and docs

**Files:** Create `docs/superpowers/specs/2026-10-13-daylight-cycle-checklist.md`. Modify `ROADMAP.md`, `docs/superpowers/plans/README.md`, `CLAUDE.md` (Architecture).

- [ ] **Step 1: The checklist** (one line per thing to try, from the spec): freeze at 6:00, 12:00, 18:00 and 0:00 from the admin panel and screenshot each (noon should look like before); let it run a minute and check the sky moves smoothly with no stepping; two players see the same time; resume after a freeze does not jump; Iridescent Requiem outside by day (charges), in shade by day (shade cap), outside at night (charges slowly, no shaded warning), under a roof at night (shaded); dawn and dusk (no flicker between sun and moon); Solar Lance by day outside versus at night outside (half size and damage); skill-effect colour grades (Prism Form, Desaturate, Rewrite) still show on top at night; `SetTime` with `abc`, `-3`, `30.5` from the panel (status message, nothing breaks); the Sky's stars appear at night and fade by day.
- [ ] **Step 2: Docs.** `ROADMAP.md`: add "Daylight cycle: code built" under World with the spec/plan paths and "later: night affecting enemies, spawns, shops and quests (hook: `ReplicatedStorage.Phase`)". `plans/README.md`: add a Ready-to-run row (Cloud tasks 1–6, then Studio task 7 with the owner). `CLAUDE.md`: add `DayCycleConfig` to the config modules and one line in Architecture for `DayClock`/`DayCycleClient`/`SkyLight`.
- [ ] **Step 3:** Run `tests/run.sh` (if Lune is installed; otherwise say it wasn't run). Commit `"Daylight cycle: checklist and docs"`; push.

### Task 7 (Studio, local session, with the owner): apply, tune, playtest

- [ ] **Step 1:** Repo → Studio per `CLAUDE.md` (new scripts: `DayClock`, `DayCycle` (Script), `SkyLight` in ServerScriptService; `DayCycleConfig` in ReplicatedStorage; `DayCycleClient` LocalScript in StarterPlayerScripts). Compile-check in the playtest console.
- [ ] **Step 2:** Freeze at the four hours, take screenshots and show the owner; tune `DayCycleConfig.Keyframes` with them (noon should still match today's look). The Sky already has `StarCount 3000` and a moon texture; check they show at night.
- [ ] **Step 3:** Run the checklist (two players for the "same time" line). Fix what's off, then move the `studio` tag per `CLAUDE.md`.
