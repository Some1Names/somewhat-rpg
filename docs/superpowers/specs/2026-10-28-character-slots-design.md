# Character slots and customizer: design

Date: 2026-10-28. Status: approved in chat (design A, name + look). Spec awaiting review.

## Goal

After PLAY on the title menu, the player sees **3 save slots**. Each slot is an independent
character with its own progress. An empty slot opens a **customizer** (name + look); a used slot
shows a summary with Continue and Delete. Existing saves are not lost.

## Out of scope

- Switching slot mid-session (rejoin to switch).
- Gameplay traits or starting bonuses (look and name only).
- Changing a character's look after creation (a later "barber" NPC could reuse the customizer).
- Roblox avatar import; the rig stays R6.

## Data model

Store `PlayerStats_v1` (unchanged name), new keys:

| Key | Holds |
|---|---|
| `<UserId>_1` .. `<UserId>_3` | One slot: the exact flat record `PlayerStats` saves today, plus text fields `CharName` and `Look`. |
| `<UserId>_meta` | `{ [1..3] = { name, level, power, look, playedAt } or nil }`, so the slot screen needs one read. |
| `<UserId>` (legacy) | Read-only after migration; never deleted, so a rollback is possible. |

- **Migration:** on first meta load, if no meta exists and the legacy `<UserId>` key has data, copy
  it into `_1` with `CharName = player.DisplayName` and a default `Look`, and write the meta.
  Done once per player; guarded by the meta existing.
- **Look** is saved text `skin;hair;hairColor;face;top;bottom` (indices into `SlotConfig` palettes),
  validated on load like other text fields. Any bad part falls back to its default.
- Meta is rewritten whenever a slot is created, deleted, or saved (level and power come from the
  slot's attributes at save time).

## Components

1. **`SlotConfig`** (`ReplicatedStorage`, pure, Lune-tested): `SlotCount = 3`, key names, name rules
   (3-16 characters, letters/digits/space/underscore, trimmed, filtered by `TextService` on the
   server), look palettes (skin tones, outfit colours, hair/face option lists), `ParseLook` /
   `FormatLook` / `DefaultLook`, and the meta summary shape.
2. **`Slots`** (`ServerScriptService`, module): meta load/save with retries, migration, `Create`,
   `Delete`, `Select`. Holds each player's current slot. Owns the "a player has no slot yet" state.
3. **`SlotServer`** (`ServerScriptService`, script): creates the remotes by script (`SlotAction`
   RemoteFunction/RemoteEvent pair: `List`, `Create(slot, name, look)`, `Select(slot)`,
   `Delete(slot, nameTyped)`), rate-limits them, validates every argument server-side.
4. **`PlayerStats`** (changed): `load(player)` becomes `load(player, slot)`; `save` writes the key
   for `Slots.Current(player)`. Join no longer loads anything; the existing "still loading"
   guards (`Level == nil`, `IsLoaded`) already treat a slot-less player as not loaded.
5. **`CharacterLook`** (`ServerScriptService`, module): applies a look to the R6 character
   (BodyColors for skin; outfit colours painted on Torso/Arms/Legs; a hair accessory cloned from
   `ServerStorage.CharacterParts`; a face decal). Re-applies on every `CharacterAdded`.
6. **`SlotMenu`** (`StarterPlayerScripts`, client): the 3-card screen, opened by `TitleMenu`'s PLAY
   instead of fading straight into the world. Square corners, white text with dark stroke,
   matching the hub style.
7. **`Customizer`** (client module used by `SlotMenu`): name box, option rows, and a live preview
   (posed R6 character in a ViewportFrame, reusing the `HubPose` approach).
8. **`TitleMenu`** (changed): PLAY opens `SlotMenu`; the fade into the world now happens when
   `Select` succeeds.

## Flow

1. Join: server loads the meta (with migration). The character still spawns as today, but is
   anchored and given a ForceField while `SlotPending` is set, so nothing hits a player on the menu.
2. `TitleMenu` shows PLAY. PLAY requests `List` and opens `SlotMenu`.
3. Empty slot: Customizer. Confirm sends `Create`; the server validates and filters the name,
   validates the look, writes the fresh slot and the meta, then runs `Select`.
4. Used slot: Continue sends `Select`. Delete asks the player to type the character's name, then
   sends `Delete`; the server removes the slot key (via `RemoveAsync`) and clears its meta entry.
5. `Select(slot)` on the server: refuses unless the slot exists and the player has none selected yet;
   calls `PlayerStats` load for that slot, applies the look, clears `SlotPending` (unanchor, remove
   ForceField), refills health, and replies. The client then fades to the world as PLAY does now.

## Error handling

- Meta or slot load fails (after the existing 3 retries): the menu shows "Could not load, try
  again" with a Retry button; nothing is saved for that player (`canSave` stays false), so a failed
  load can never overwrite a save.
- Create with a taken/invalid/filtered name or a bad look: server replies with a reason; the
  Customizer shows it. Slot unchanged.
- Remote spam or out-of-range slot numbers are ignored.
- Studio playtests: slots load but nothing is written (`SAVE_IN_STUDIO` stays false), so the
  menu can be tested without touching real saves.
- Player leaves while on the menu: nothing to save (`canSave` false).

## Risks and checks (done in the plan, not guessed here)

- Every `PlayerAdded` handler in `ServerScriptService` (`Powers`, `Loadout`, `Consumables`,
  `Reforge`, `Factions`, `Overcharge`, ...) must tolerate the attributes appearing later, at
  `Select`, instead of at join. The plan lists each one and what it needs to wait on.
- `AdminPanel` and `PlayerStats.ResetProgress` act on the *current slot* only.
- The legacy key must stay readable; migration is a copy, never a move.

## Needs the owner in Studio

- `ServerStorage.CharacterParts` with hair accessories (`Hair_<n>`) and face decals (`Face_<n>`).
  Options with no part are hidden, so the menu works with skin and outfit colours only until the
  parts exist.
- No Developer Products or uploads needed.

## Testing

- **Lune** specs for `SlotConfig`: name validation, look parse/format round-trip and fallbacks,
  meta shape, slot key names.
- **Playtest checklist** for the owner: join with an old save (appears in slot 1 intact); create
  slots 2 and 3 with different looks and names; progress in one does not touch the others; delete
  needs the typed name; rejoin keeps looks; a bad name is refused; killing time on the menu does
  not hurt the character.
