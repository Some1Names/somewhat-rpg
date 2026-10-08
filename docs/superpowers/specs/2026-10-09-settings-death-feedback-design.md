# More settings, death screen, quick respawn and cast feedback: design

Status: design approved in chat, waiting on review of this written spec.

## Intent

Three quality-of-life additions:

1. **More Settings sections**: Quick respawn, Camera shake, Flashes & impact frames and Damage
   numbers, saved per player.
2. **A death screen** that says who killed you and counts down to the respawn. With **Quick
   respawn** on, you respawn right away instead, with no death screen and no ragdoll.
3. **Cast feedback**: when a skill press is refused, a short message says why.

Success:
- A player sensitive to flashing or shake can turn them off once, and every skill respects it.
- A player who dies knows who killed them and when they'll be back.
- A player whose skill didn't fire knows why.

## 1. Settings sections

New rows in the Settings panel, under KEYBINDS. Each is an ON/OFF toggle button, saved on click.

| Section | Id | Label | Default |
|---|---|---|---|
| GAMEPLAY | `QuickRespawn` | Quick respawn | off |
| EFFECTS | `CameraShake` | Camera shake | on |
| EFFECTS | `Flashes` | Flashes & impact frames | on |
| EFFECTS | `DamageNumbers` | Damage numbers | on |

### `ReplicatedStorage/Preferences.luau` (new, shared, built like `Keybinds`)

- `Preferences.Options`: the ordered list above (`id`, `label`, `section`, `default` boolean).
- `Preferences.Attribute = "Preferences"`: the saved player attribute, e.g.
  `"QuickRespawn=1,CameraShake=0"`. Only values that differ from their default are stored. Up to
  200 characters.
- Pure functions:
  - `Preferences.Defaults()` gives the full map.
  - `Preferences.Parse(text)` gives the full map. Unknown ids, values other than `0`/`1`,
    non-strings and over-long strings fall back to the defaults.
  - `Preferences.Serialize(map)` gives the stored text.
  - `Preferences.Valid(map)` checks a map is complete and well formed.
- Client functions (they reach the game only when called):
  - `Preferences.Get(id) -> boolean`: the local player's value.
  - `Preferences.Changed(callback)`: called when the player's preferences change.
- Server function: `Preferences.For(player, id) -> boolean` reads another player's value (used
  for Quick respawn).

### Saving

- `SettingsServer` adds a `SetPreferences` RemoteEvent and checks it like `SetKeybinds`: string
  of at most 200 chars, re-parsed, and it must serialize back to itself. At most one save per
  0.5 s per player.
- `PlayerStats` saves `Preferences = ""` with the other text fields.
- The Settings client spaces saves out the same way it does for keybinds: newest wins, and the
  value shown is the pending one until the server echoes it.

### Where each setting takes effect

| Setting | Code that checks it |
|---|---|
| Camera shake | `VFX.Shake`, and the local `shake` in `SkillEffects/init.client.luau`, return at once when it's off. |
| Flashes & impact frames | `VFX.ImpactFrame`, `VFX.ImpactFrameNear` and `VFX.ScreenSpeedLines` return at once when it's off. |
| Damage numbers | `HitFeedback.client.luau` skips the floating number. The red flash and sparks still play. |
| Quick respawn | The server; see section 2. |

Because the checks sit inside the shared helpers, every current and future skill respects them.
`VFX` is used by both server and client, so its checks only apply on the client (where
`RunService:IsClient()` is true), for the local player.

## 2. Death screen and quick respawn

### Quick respawn (server, in `SettingsServer`)

- **When:** a player's character dies and `Preferences.For(player, "QuickRespawn")` is on.
- **What:** after `QUICK_RESPAWN_DELAY = 0.1` s, if the player is still in the game and that is
  still their character, the server calls `player:LoadCharacter()`.
- **Why the delay:** it lets the death's existing listeners run first (kill credit and XP in
  `Damage`, `KillFeed`, overcharge refills).
- The ragdolled body goes with the old character, so there's no death animation and no death
  screen.

### Death screen (`StarterPlayerScripts/DeathScreen.client.luau`, new)

- **When:** the local character's Humanoid dies and Quick respawn is off.
- **What it shows:** a full-width square band across the middle of the screen (dark, slightly
  see-through, no rounded corners):
  - **YOU DIED** in large text.
  - "Killed by **Name** with **Set**", or "Killed by **Name**" for a bare-handed kill, or "You
    died" when no player gets the credit. This comes from the `KillFeed` remote's message for the
    local player's UserId, which arrives at the same time.
  - "Respawning in N…", counting down from `Players.RespawnTime` (read on the client).
- **When it goes:** as soon as a new character is added, or when the countdown ends.

## 3. Cast feedback

- **Where:** a single red text line just above the skill bar. It shows the newest refusal for
  `FEEDBACK_TIME = 1.2` s, then fades. The existing red slot flash stays as it is.
- **How:** `SkillBar`'s `readyToCast` returns the reason instead of only `false`. It checks in
  this order and reports the first that applies:

| Condition | Message |
|---|---|
| Skill has no handler | `<Skill>: coming soon` |
| Mastery too low | `<Skill>: needs mastery <N>` |
| Ultimate needs overcharge, not overcharged | `<Skill>: needs overcharge` |
| Weapon still thrown | `<Skill>: <weapon> still thrown` (Mandela: "axe") |
| A form without enough Luminance | `<Skill>: not enough Luminance` |
| On cooldown (no charge ready) | `<Skill>: <s>s cooldown` (seconds rounded up) |
| Lock-on aim with nobody in its cone (checked when casting) | `<Skill>: no target` |

- **The Special key (G)** gets the same messages:
  - Overcharge: "Overcharge not full", or "Overcharge ready in <s>s" while cooling.
  - Flight: "Not enough light to fly".
  - Undo: "Undo ready in <s>s".
- **One limit:** a cast the server refuses on its own, such as over the void or a target out of
  reach by the time it arrives, still fails silently. The client can't know about these in
  advance.

## Out of scope

- An Effects quality slider, volume and sound settings.
- A RESPAWN NOW button.
- Player feedback or bug reports.
- Messages for refused dashes or ranged shots.

## Testing

- `tests/Preferences.spec.luau` tests the pure functions with Lune, run by `tests/run.sh`
  alongside the keybind tests.
- Every changed script passes the StyLua parse check and the selene undefined-variable check.
- The owner's in-game checklist covers:
  - Each toggle on and off (shake, flashes, numbers).
  - Each setting kept after rejoining a live server.
  - Death by another player, by an NPC, and by falling (the screen's text and countdown).
  - Quick respawn: instant respawn, with kill credit and the kill feed still working.
  - Each cast-feedback message.
