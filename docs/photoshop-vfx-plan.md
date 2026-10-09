# Photoshop VFX plan

The visual pass for Nozomi's Photoshop. Today every Photoshop effect is built in code
(`StarterPlayerScripts/SkillEffects/PhotoshopEffects.luau`) from plain parts, outlines and stock
sparkles. That works as a placeholder, but it reads as "boxes and rings" rather than "a camera
editing reality". This plan says what each move should look like, what gets built in Studio
versus in code, and in what order.

## Art direction

Nozomi edits reality like a photo. Every effect should borrow from cameras and photo editors, in
her pink `#FF7EC8` and light blue `#8CD2FF`:

| Motif | Where it shows up |
|---|---|
| **Camera flash**: a hard white pop with a soft bloom | Shutter, Snapshot, Step In, every paste |
| **Shutter / iris blades**: overlapping curved plates | Iris Horizon closing, the Gallery developing |
| **Photo frames / Polaroids**: white border, slightly glossy | Photo Teleport, the gallery photos, Step In's cut-out |
| **Crop marks**: dashed lines and corner brackets | Framed, Snapshot's lock, Paste |
| **Chromatic split**: a pink copy and a blue copy offset sideways | hits, Step In afterimages, Reflect |
| **Desaturation**: grey, film grain, colour leaking out | Desaturate |
| **Mirror shards**: angled glass with pink/blue edges | Kaleidoscope |
| **Rewind**: a reversed streak, a ghost sliding back | Undo |

Rules for every effect:
- **Readable at a glance.** The enemy should see Iris Horizon's ring and know to dash.
- **Screen-wide flashes go through the Flashes setting** (`Preferences "Flashes"`): any
  full-screen white or colour flash checks it, like `VFX.ImpactFrame` does.
- **Scale with `VFX.Quality()`** so low-end devices drop particle counts.
- **Square UI only** (no `UICorner`) for anything on screen.

## How it gets built

Follow the Iridescent Requiem revisual's workflow:

1. **A prefab pack in Studio:** `ReplicatedStorage.VFXPrefabs.Photoshop`. Each prefab is an
   invisible anchored Part holding ParticleEmitters with the usual attributes (`EmitCount`,
   `EmitDelay`, `EmitDuration`, `Tint`, `Hold`), so the look is tuned in Studio's Properties
   without touching code.
2. **Code calls `VFX.Play("Photoshop/<Name>", ...)`** where the plan says. If a prefab is
   missing, the current code-built look still plays. Nothing breaks before the Studio work is
   done, and each prefab can land on its own.
3. **One skill at a time, owner's eye.** A local session with Studio describes the current look,
   you say what to change, then it builds and checks with frozen playtest screenshots.
4. **Textures:** reuse what the game already has first (`FORM_SPARKLE`, `GLINT_TEXTURE`,
   `BOKEH_TEXTURE`, sparkles). New textures (shutter blade, crop bracket, film grain, Polaroid
   frame) need uploading to your account, which needs **your OK first**. Alternatively, use free
   Creator Store images.

**Who does what:** the code hooks, fallbacks and timing can be done from a cloud session. The
prefabs, textures, look-tuning and screenshots need Studio.

## Per move

Priority: **P1** is what players notice first, **P3** is polish.

### P1. V: Iris Horizon (her signature)
- **Now:** 8 white cards on a shrinking ring, then a dark ball with flat rainbow rings, a white
  flash and a crater.
- **Target:**
  - **Closing:** curved **shutter blades** (thin, glossy, pink → blue along each blade) rotating
    shut like a real camera iris, with a faint dashed crop circle on the ground showing the
    escape edge. A soft whir-glow builds as it closes.
  - **Collapse:** the blades meet, the inside goes black for a frame (Flashes setting), then a
    **rainbow black hole**: a black core with a spinning hue-cycling accretion ring, light
    streaks pulled inward for about 0.2 s.
  - **Burst:** a rainbow shockwave ring, prism shards flying out, a chromatic split on everyone
    hit, a crater (keep `VFX.Crater`) and a heavy shake.
  - **Escaped:** the blades snap shut on nothing with a small "missed shot" puff.
- **Prefabs:** `Photoshop/IrisBlades` (Hold, follows the ring), `Photoshop/RainbowCore`,
  `Photoshop/RainbowBurst`, `Photoshop/PrismShards`.
- **Code:** swap the cards for blade meshes or decals posed by the existing ring loop, and call
  the prefabs at collapse and burst.

### P1. F: Kaleidoscope
- **Now:** about 36 glass wedges slowly orbiting a dome, plus a flash per hit.
- **Target:**
  - **Opening:** reality cracks from her feet outward, with hex/triangle fractures racing across
    the ground and up into a dome.
  - **The dome:** mirrored shards with pink/blue rims, each showing a skewed, tinted copy of the
    arena: a ForceField or Glass shard with a SurfaceGui gradient (no real reflections needed).
    It slowly rotates, with sparkle dust drifting inside.
  - **Mirror hits:** a ghost copy of the target steps out of the nearest shard and strikes. Use
    the existing `ghostOf` tinted pink or blue, with a chromatic split on impact.
  - **Reflect:** a hard prismatic beam bending off a shard back at the shooter.
  - **Ending:** every shard shatters at once (the same pattern as Mandela's mirror break, in her
    colours).
- **Prefabs:** `Photoshop/GroundFracture`, `Photoshop/ShardDust` (Hold), `Photoshop/ShardBreak`.

### P2. Z: Snapshot, Framed and Step In
- **Snapshot now:** a white flash, a ring and a spinning card. **Target:**
  - **On her:** a camera-flash pop at her hand with a lens flare.
  - **On the target:** a quick "focus" (crop brackets snapping in from wide to tight), then the
    flash.
  - **The photo:** a Polaroid of the target pops out above them and floats away.
- **Framed now:** four pink corner lines (caster only). **Target:** the same idea, polished:
  - Animated crop brackets that breathe slightly.
  - A small "REC ●" or viewfinder tick that blinks as the frame runs out, so the 4 s window is
    readable.
  - Still caster-only.
- **Step In now:** a pink afterimage, a card and a flash. **Target:**
  - **Where she left:** a cut-out silhouette (Polaroid-edged) left behind, peeling away like a
    sticker.
  - **Where she lands:** a chromatic split as she appears behind the target, plus a flash.
- **Prefabs:** `Photoshop/CameraFlash` (used by many moves), `Photoshop/LensFlare`,
  `Photoshop/PolaroidPop`.

### P2. C: Desaturate
- **Now:** a grey ForceField column, grey flakes, a grey Highlight, and the local screen going
  grey inside.
- **Target:**
  - **The zone:** colour bleeds out from the centre in a spreading ring. Inside, the ground and
    characters go grey (keep the Highlight and the ColorCorrection).
  - **Particles:** **film grain** and vertical scratch lines drift through the column, plus
    rising flecks of colour, like paint being sucked out.
  - **The edge:** a faint pink/blue chromatic fringe, so the boundary reads.
  - **Ending:** colour floods back in from the edges.
- **Prefabs:** `Photoshop/ColorDrain` (the spreading ring), `Photoshop/FilmGrain` (Hold),
  `Photoshop/ColorFlecks` (Hold).

### P2. X: Photo Teleport, Paste and Cut & Paste
- **Now:** a white card with a blue outline on the ground, which flips on paste.
- **Target:**
  - **The pinned photo:** a standing Polaroid showing a soft snapshot of that spot (a gradient
    is fine), gently bobbing, with a thin light beam up so it can be found from afar.
  - **Paste:** the photo grows into a doorway. The pasted character steps out of it with a
    chromatic split, and the photo crumples away.
  - **Cut & Paste on an enemy:** a dashed cut line traces round them before they vanish (crop
    marks), so it reads as "cut".
- **Prefabs:** `Photoshop/PhotoBeacon`, `Photoshop/PasteDoorway`, `Photoshop/CutLine`.

### P3. Click: Shutter
- **Now:** a pink/blue beam with a white flash.
- **Target:** a fast flash streak with a small shutter "click" pop at the muzzle. On a Framed
  target, the crop brackets flicker brighter to show the frame was extended.
- **Prefabs:** reuse `Photoshop/CameraFlash` (small scale).

### P3. G: Undo, and the Gallery
- **Undo now:** a blue ghost, a beam and a flash. **Target:**
  - **Where she was:** a rewind streak (a ghost sliding backwards along her path with motion
    blur).
  - **Her screen:** a quick reverse-scrub of horizontal VHS-style lines (Flashes setting).
  - **Where she lands:** a soft blue flash.
- **Gallery now:** a card above her head that develops, then a flash on travel. **Target:**
  - **Developing:** a Polaroid ejects and slowly develops from dark to the image above her head,
    with shutter blades closing around her at the end.
  - **Travel:** she's "pasted" into the destination.
  - **Cancelled:** the photo burns at the edges.
- **Prefabs:** `Photoshop/RewindStreak`, `Photoshop/PhotoBurn`.

### Also: the set itself
- **Equip:** a quick camera-flash pop and a pink/blue shimmer on equip (the shared `Equip`
  effect, in her colours).
- **Wearables (optional):** a camera on a strap, or a floating lens/viewfinder by her shoulder
  (`ServerStorage.SkillSets.Photoshop.Wearables`).
- **Animations (the `PhotoshopAnimations` folder):**
  - CastZ: raise a camera, snap.
  - CastX: flick a photo.
  - CastC: a sweeping wipe.
  - CastV: frame with both hands.
  - CastF: arms spread, reality shattering.
  - Publishing them needs your OK.

## Order of work

1. **Shared:** `CameraFlash` and the code fallback pattern. Everything else reuses them.
2. **Iris Horizon** (P1).
3. **Kaleidoscope** (P1).
4. **Snapshot, Framed and Step In** (P2).
5. **Desaturate** (P2).
6. **Photo Teleport and Paste** (P2).
7. **Shutter, Undo, the Gallery and Equip** (P3).
8. **Animations and wearables**, whenever you have them.

Each step is one Studio session, plus a small code change that can be done from the cloud.

## Open questions for you

1. **Shutter blades and Polaroid frames:** upload new textures (needs your OK), or use free
   Creator Store images?
2. **The "REC ●" viewfinder on Framed:** cute, or too much?
3. **Snapshot's floating Polaroid:** show it to everyone, or only the caster?
4. **Iris Horizon's black frame on collapse:** keep it (it respects the Flashes setting), or
   drop it?
