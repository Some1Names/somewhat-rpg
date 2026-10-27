# Character slots: Studio set-up and playtest checklist

Spec: `2026-10-28-character-slots-design.md`. Plan: `../plans/2026-10-28-character-slots.md`.
Nothing here has been run in Studio or Lune yet (no Lune on the machine that wrote it): run
`tests/run.sh` first (the new one is `tests/SlotConfig.spec.luau`).

## Put into Studio

New scripts (class and path):

| Script | Class | Path |
|---|---|---|
| `SlotConfig` | ModuleScript | `ReplicatedStorage` |
| `CharacterLook` | ModuleScript | `ReplicatedStorage` |
| `Slots` | ModuleScript | `ServerScriptService` |
| `SlotServer` | Script | `ServerScriptService` |
| `SlotMenu` | ModuleScript | `StarterPlayer.StarterPlayerScripts` |
| `Customizer` | ModuleScript | `StarterPlayer.StarterPlayerScripts` |

Changed: `PlayerStats` (loads and saves one slot, nothing on join), `TitleMenu` (PLAY opens the
slot screen). The `SlotAction` RemoteFunction is made by `SlotServer`.

Yours to make: `ReplicatedStorage.CharacterParts`, a Folder with hair accessories named
`Hair_2` .. `Hair_5` (each an Accessory with a `Handle`; style 1 is "none") and face decals
named `Face_2` .. `Face_4` (a Decal with its `Texture`). A style with no part is hidden in
the customizer, so it works with colours only until you add them. Names for the styles are in
`SlotConfig` (`HairStyles`, `FaceStyles`), and so are the colour palettes.

## Playtest

- [ ] Join with an existing save (a live server, not Studio): PLAY shows slot 1 with your name,
  level and power, and Continue gives your old progress intact. Slots 2 and 3 are empty.
- [ ] Make a character in slot 2 (name + look): the preview changes as you pick; CREATE lets you in
  as a level 0 character wearing the look, not your Roblox avatar (no hats, no shirt).
- [ ] Gain XP or yen in slot 2, rejoin: slot 1 is untouched, slot 2 kept its progress, the cards
  show the new level.
- [ ] Die and respawn: the look is re-applied each time, even if your avatar's hat loads late.
- [ ] Bad names are refused with a reason: empty, 2 letters, 17 letters, `no!`, only spaces, a
  name you already used in another slot, a word the filter blocks.
- [ ] DELETE needs the exact name (any case); Cancel keeps the character; after deleting, that slot
  is empty and can be made again.
- [ ] On the slot screen the character stands still and can't be hurt (walk an enemy over, wait).
- [ ] BACK from the slot screen and from the customizer returns to where you were.
- [ ] Studio playtest: the screen works and nothing is saved (`SAVE_IN_STUDIO` is off).
- [ ] Turn DataStore access off for a live test or Studio API access off: "Couldn't load" shows with
  RETRY in a live server, and nothing is written.
- [ ] Other menus still work after entering: hub tabs, stats, quests, hotbar (they used to get
  their data at join; now it arrives when you pick a slot).
