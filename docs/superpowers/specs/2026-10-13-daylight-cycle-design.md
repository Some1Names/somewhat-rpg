# Daylight cycle: design

Status: design approved in chat 2026-10-13; waiting on review of this written spec.

## Intent

A day and night cycle that moves the sun, sky and lighting, so the world feels alive, and that
makes the sun-based powers (Iridescent Requiem's Luminance, Solar Lance) behave sensibly through the
day. Night is darker and dangerous for light users, but not a lock-out.

**This update:** the visual cycle, the sun/moon rules for Luminance and Solar Lance, an admin
control for testing, and a `Phase` hook.
**Later update (not built here):** night affecting enemies, spawns, shops and quests. The `Phase`
attribute is the only thing added for it.

## Decisions (from the owner)

- One full 24h in-game day = **20 real minutes** (`DayLength = 1200`).
- Luminance at night: **moonlight charges slowly** (`MoonShare = 0.25` of the normal rate, under
  open sky).
- Solar Lance at night: **the moon doesn't count as sunlight**, so it is treated as "covered"
  (the existing `CoveredShare`, 50% size and damage).
- Admin panel gets **set time** and **freeze time**.
- No clock on the HUD.

## How the time works

The server owns a **time anchor**; clients compute the time from it.

- `ReplicatedStorage` attributes: `DayAnchorTime` (the in-game hour at `DayAnchorServerTime`),
  `DayAnchorServerTime` (a `workspace:GetServerTimeNow()` value), `DayFrozen` (bool).
- Current hour = `(DayAnchorTime + (now - DayAnchorServerTime) * 24 / DayLength) % 24`, or just
  `DayAnchorTime` while frozen.
- A new server starts at `StartHour` (7:00, morning). The time isn't saved between servers.
- **Server** (`DayCycle.server.luau`): sets the anchor on start, sets `Lighting.ClockTime` to the
  current hour once a second (so `Lighting:GetSunDirection()` and `GetMoonDirection()` are right for
  server checks), and keeps `ReplicatedStorage.Phase` up to date.
- **Client** (`DayCycleClient.client.luau`): every frame computes the hour and sets `Lighting.ClockTime`
  and the look below. Smooth at any day speed; the server's once-a-second value is overwritten
  locally, so there's no stepping.
- **Admin:** `SetTime` writes a new anchor and `FreezeTime` toggles `DayFrozen` (freezing re-anchors at
  the current hour first). Both are global; the admin panel's player target is ignored.

## Phases

`Phase` (a `ReplicatedStorage` string attribute): **Dawn** 5:00–7:00, **Day** 7:00–17:00,
**Dusk** 17:00–19:00, **Night** 19:00–5:00. Boundaries are in `DayCycleConfig.Phases`. Nothing
reads `Phase` in this update except the helper's night check; it exists for the later update.

## The look

`DayCycleConfig.Keyframes` is a list of `{ hour, ... }` entries (at least 0, 6, 12, 18; more can be
added). The client interpolates between the two surrounding keyframes (wrapping past midnight) and
applies the values to the **existing** Lighting instances:

| Target | Values per keyframe |
|---|---|
| `Lighting` | `Brightness`, `Ambient`, `OutdoorAmbient`, `ExposureCompensation` |
| `ColorCorrection` | `TintColor`, `Brightness`, `Saturation` |
| `Atmosphere` | `Color`, `Decay`, `Density`, `Haze`, `Glare` |
| `Bloom` | `Intensity` |
| `SunRays` | `Intensity` |
| `Sky` | `StarCount` |

- The client **skips any instance that isn't there** (no errors, nothing created). The keyframe
  values are a first pass and the owner tunes them in Studio.
- Skill effects already add their own temporary ColorCorrection under `Lighting` (see
  `VFX.luau`, `SkillEffects`). The cycle only touches the permanent `ColorCorrection` named
  `ColorCorrection`, so those keep working on top.
- Studio's current state (read 2026-10-13): `ClockTime 15.2`, `Brightness 3`, with `SunRays`,
  `Atmosphere`, `DepthOfField`, `Bloom`, `Sky`, `ColorCorrection`. The "day" keyframes should
  start from these values so noon looks like today.

## `SkyLight` helper (new, server)

`ServerScriptService/SkyLight.luau`, one function: `SkyLight.Exposure(position)` →
`"sun"`, `"moon"` or `nil`.

- Sun up (`GetSunDirection().Y > 0`): ray from `position` toward the sun; clear → `"sun"`.
- Otherwise, moon up (`GetMoonDirection().Y > 0`): same ray toward the moon; clear → `"moon"`.
- Anything blocked, or neither above the horizon → `nil`.
- The ray rules are exactly the two existing copies: 1000-stud ray, characters ignored, parts at
  least 0.5 transparent let light through, up to four see-through parts.
- `LuminanceServer.server.luau` (`inSunlight`) and `Skills/SolarLance.luau` (`underSky`) both call it.
  This removes the duplicated ray check. One side effect: Solar Lance's old check let nothing
  through, so now parts at least 50% transparent no longer cover it (they never covered Luminance).

## Rules changed in existing code

- **Luminance** (`LuminanceServer`): `"sun"` charges as today. `"moon"` charges at
  `chargePerSecond * MoonShare`, with the above-the-clouds multiplier still applying. `nil` is
  shade, as today. The shaded flag (`ShadedAttribute`) stays true for `nil` only, so moonlit
  open sky doesn't show the shaded warning.
- **Solar Lance**: `"sun"` is full size and damage. `"moon"` and `nil` both use `CoveredShare`.
- No other code reads the sun.

## Files

**New**
- `src/ReplicatedStorage/DayCycleConfig.luau`: `DayLength`, `StartHour`, `MoonShare`, `Phases`,
  `Keyframes`, and the pure helpers `HourAt(anchorTime, anchorServerTime, now, frozen)`,
  `PhaseAt(hour)` and `Sample(hour)` (interpolated look).
- `src/ServerScriptService/DayClock.luau` (the anchor, `Hour`, `SetHour`, `SetFrozen`; a module so
  `AdminServer` can use it) and a tiny `DayCycle.server.luau` that starts it
- `src/StarterPlayer/StarterPlayerScripts/DayCycleClient.client.luau`
- `src/ServerScriptService/SkyLight.luau`
- `tests/DayCycleConfig.spec.luau` (run by `tests/run.sh`; see Testing)

**Changed**
- `ServerScriptService/LuminanceServer.server.luau`, `Skills/SolarLance.luau`
- `ServerScriptService/AdminServer.server.luau` (`SetTime`, `FreezeTime`)
- `StarterPlayerScripts/AdminPanel.client.luau` (hour box plus Set, and a Freeze toggle)
- `SkillSetConfig` Luminance passive comment only if a tunable moves there (`MoonShare` lives in
  `DayCycleConfig`, since it's the cycle's rule)

## Error handling

- `SetTime`: reject non-numbers and NaN, wrap into 0–24 with `% 24`. `FreezeTime` takes no value.
- Client waits for the anchor attributes (`WaitForChild`-style `GetAttribute` check each frame);
  until they exist it leaves Lighting alone.
- If `Sample` finds fewer than two keyframes it returns the first one (a config mistake shouldn't
  break the loop).

## Testing

- **Unit tests (Lune, `tests/run.sh`):** `HourAt` (running, frozen, wrap past 24), `PhaseAt` at every
  boundary, and `Sample` (exact keyframe, midway, wrap between the last and first keyframe, colours
  interpolate per channel).
- **Cloud can't verify:** how it looks, the sun checks (rays need Workspace), the admin panel. The
  plan carries a Studio checklist: freeze at 6:00, 12:00, 18:00, 0:00 and screenshot; stand in sun
  then shade then moonlight with Iridescent Requiem and watch Luminance; cast Solar Lance by day
  and night; set and freeze time from the admin panel; two players see the same time.

## Needed in Studio (not created by scripts)

- Nothing new is required for the cycle to run.
- The existing `Sky` already has a moon texture and `StarCount 3000`; the cycle drives `StarCount`
  (0 by day). Its look is for the owner to judge in Studio.
- Map lights that should switch on at night (lamps, windows) are not part of this update.

## Not in scope

HUD clock, saving the time, weather, enemies/spawns/shops/quests at night, a moon phase cycle, and
changing other sets' skills to depend on the time.
