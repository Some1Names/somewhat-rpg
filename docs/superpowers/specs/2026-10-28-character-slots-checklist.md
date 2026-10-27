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

## Placeholder hair and faces (already in Studio's `ReplicatedStorage.CharacterParts`)

Mockups from the Creator Store until you make your own; replace the part with the same name to
swap one. They exist only in Studio, not in this repo.

| Part | What | Source |
|---|---|---|
| `Hair_2` Short | messy anime hair | mesh `11307925648`, texture `11307925735` (store asset `116819530261392`) |
| `Hair_3` Spiky | spiky anime hair | mesh `14578296892` (store asset `114404620603615`) |
| `Hair_4` Long | white anime hair | mesh `13038459165`, texture `13014002425` (store asset `120216091759609`) |
| `Hair_5` Tied | samurai topknot | mesh `9374122150`, scale 6 (store asset `92796120117054`) |
| `Face_2` Calm | anime face | image `114820106` |
| `Face_3` Fierce | anime face, blue eyes | image `54172037` |
| `Face_4` Smile | kawaii anime face | image `672612369` |

**The store hair models carried hidden scripts** (a Studio-only script plus a 35 KB local script
that builds an overlay window, the same in all four). I did not run them. Each hair was rebuilt
clean (mesh, texture, scale, attachment only) and the originals deleted; `CharacterParts` has no
scripts. If you insert more free models, check them for scripts first. A decal's asset id is not
its image id (the image is usually the id minus one), which is why the first face picks showed
nothing.

## Playtest

The game is R6 only, and `CharacterLook` paints R6 parts only (`Torso`, `Left Leg`...). A Studio
playtest on Avatar Type "Player Choice" or R15 spawned an R15 character, so the player kept their
own head and face. To make every player R6 whatever the setting says, Studio has
`StarterPlayer.StarterCharacter`: a plain R6 rig (Humanoid, the six parts, HumanoidRootPart,
BodyColors, no scripts). It is an instance, not a script, so it is not in this repo; delete it to
go back to the avatar the setting picks. Game Settings > Avatar > Avatar Type = **R6** is still
the clean fix. With a StarterCharacter Roblox never reports the avatar as loaded, so `Slots`
paints the look at once rather than waiting for that.

- [ ] Join with an existing save (a live server, not Studio): PLAY shows slot 1 with your name,
  level and power, and Continue gives your old progress intact. Slots 2 and 3 are empty.
- [ ] Make a character in slot 2: the customizer has four tabs (BODY, HAIR, FACE, OUTFIT). HAIR and
  FACE show square head tiles, and pressing one replaces the current hair or face. Skin, hair, top
  and bottom colours come from one colour wheel (drag the wheel, the bar for brightness, or type a
  hex). The big preview follows each change; CREATE lets you in as a level 0 character wearing the
  look, not your Roblox avatar (no hats, no shirt).
- [ ] A used slot's card shows its level and yen, and takes its colour from the power that character
  holds (top line, big number, ring under the character, CONTINUE, the level and the power name).
  White with no power. The summary is refreshed on every save, so it can lag by an autosave
  (2 minutes) or the last leave.
- [ ] Every player spawns R6 (head, face, hair and colours all from the look, not their avatar).
- [ ] The hub's Profile shows the codename big, with `@<your real username>` under it, and its
  3D model wears the look (it redraws after the server paints it).
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
- [ ] Settings are the player's, not a character's: rebind a key or change a preference on the title's
  SETTINGS, press PLAY, Continue: they are still changed; a new character in another slot has them too.
- [ ] Create characters in slots 1 and 3 only (leave 2 empty), rejoin: both show, 2 is empty.
- [ ] The hair preview in the customizer sits on the head (the preview's physics isn't solved; if the
  hair floats, say so and the preview needs to place the hair by hand).
- [ ] While held on the slot screen, nothing hurts or moves the character (check enemy status effects
  and crowd control, not just damage).
- [ ] Other menus still work after entering: hub tabs, stats, quests, hotbar (they used to get
  their data at join; now it arrives when you pick a slot).
