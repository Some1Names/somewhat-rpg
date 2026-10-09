# Photoshop Punches and Step In Combo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Written for a LOCAL session with the Roblox Studio MCP.** Work on branch
> `claude/vigilant-rubin-ckqtnn`, then apply to Studio ("Repo → Studio" in `CLAUDE.md`) and
> playtest each task there. The cloud session that wrote this plan couldn't run the game.

**Goal:** Give Photoshop a 4-hit melee punch combo that scales with Superliminal, and make Snapshot's Step In end in an automatic 3-punch combo, so Z deals real damage instead of only setting up.

**Architecture:** Melee weapons are entries in `PunchConfig.Weapons`. The Punch client and `PunchCombat` server pick the one for the held tool (`PunchConfig.WeaponFor`). Photoshop becomes one more entry, and weapons gain a `stat` field so it can scale with Superliminal while Fists and the axe stay on Strength. Step In's combo is server-timed in `Skills/Snapshot.luau`, with the caster's client playing the punch animations.

**Tech Stack:** Roblox Luau. Studio playtests through the MCP. `tests/run.sh` (Lune) for the pure modules. Use StyLua and selene if installed.

**Spec (approved in chat on 2026-10-09; this section is the spec):**
- **The punches:**
  - Left click with Photoshop out is a 4-hit punch combo, like Mandela's axe. Right click held still readies Shutter (left click then shoots), exactly as Mandela's Knife works next to his axe.
  - 12 damage per punch before the Superliminal bonus. The 4th punch is the critical finisher (`PunchConfig.CritMultiplier` ×2.5 = 30) and knocks back like the fists' finisher.
  - The hitbox is a bit bigger than fists. Hits count towards Photoshop mastery and use the existing punch animations (`PunchAnimations.Punch1–4`) until Photoshop-specific ones exist.
  - Hits play the Photoshop VFX pack (`VFX.Play("Photoshop/CameraFlash", …)`), not stock particles (see `CLAUDE.md`).
- **The Step In combo:**
  - Right after Step In lands her behind the Framed target, three automatic punches follow, 0.15 s apart: 8, 8 and 14 damage before the Superliminal bonus. The last one knocks back, following `CrowdControl` for players.
  - Each punch hits whoever is in front of her at that moment, so a target who dashes away makes the rest miss.
  - Her client plays `Punch1`–`Punch3` in time with the punches.

## Global Constraints

- All damage goes through `Damage.Deal(player, humanoid, amount, { stat = "Superliminal", skillSet = "Photoshop", melee = true, ... })`.
- Before knocking back a player, ask `CrowdControl.CanControl(model)` and then `CrowdControl.Apply(model, time)`.
- Fists and `MandelaAxe` must behave exactly as before (Strength scaling, same numbers).
- No final visuals from stock particles. Use `VFXPrefabs.Photoshop` prefabs. A missing prefab only warns, which is acceptable.
- Match the surrounding style: header comments, CONFIG tables with units, tabs.

## Review Focus

1. **Fists and the axe after the `stat` change:** the punch damage numbers must be unchanged with Mandela and bare-handed (Task 1 playtest step).
2. **The Step In combo when the target dies or respawns mid-combo, or the caster dies or unequips:** no error, and no hits after that (Task 2 checks `PhotoshopUtil.alive` and the target's health before each punch).
3. **Left click while readying Shutter:** it must shoot, not punch. Readying already blocks punches for ranged sets; check Photoshop isn't marked `primary`, since `primary` would replace punches entirely (Task 1 playtest step).
4. **Mashing Z during the combo:** Step In's recast is cleared on landing, so a second Step In can't start mid-combo (Task 2 playtest step).
5. **The combo's knockback on a player under hold protection:** damage still lands, there's no knockback, and nothing errors (Task 2 playtest step with two players).

---

### Task 1: Photoshop punches (Superliminal melee)

**Files:**
- Modify: `src/ReplicatedStorage/PunchConfig.luau` (a new `PhotoshopPunch` weapon, and the `stat` field documented in the weapons comment)
- Modify: `src/ServerScriptService/PunchCombat.server.luau` (`SCALING_STAT` ~26 becomes `weapon.stat or "Strength"` at both uses, ~203 and ~230; trails only when the weapon has a trail; the CameraFlash on hit)

**Interfaces:**
- Produces: `PunchConfig.Weapons.PhotoshopPunch = { tool = "Photoshop", skillSet = "Photoshop", stat = "Superliminal", baseDamage = 12, minInterval = 0.3, finisherCooldown = 0.6, hitboxSize = Vector3.new(6, 6, 6), hitboxForward = 3.5, animationFolder = "PunchAnimations", animationPrefix = "Punch", hits = <copy Fists.hits> }`. No `holdAnimation` and no `overcharged`.

- [ ] **Step 1:** Add the weapon entry and document `stat` ("the stat its damage scales with; Strength if none") in the comment above `PunchConfig.Weapons`.
- [ ] **Step 2:** In PunchCombat, scale by `weapon.stat or SCALING_STAT` (rename the constant `DEFAULT_STAT`). For a `skillSet` weapon with no SwingTrail on the character, `showTrail` must quietly do nothing: read it and guard if needed. On each landed Photoshop punch, fire `skillEffects:FireAllClients("PhotoshopPunchHit", point, critical)`, and add `effects.PhotoshopPunchHit(point, critical)` to PhotoshopEffects. It plays `VFX.Play("Photoshop/CameraFlash", point, { scale = critical and 1.6 or 1 })`.
- [ ] **Step 3:** Apply to Studio and playtest:
  - (a) Photoshop left click does 4 punches; the 4th crits and knocks the dummy back.
  - (b) Damage grows with Superliminal points, not Strength.
  - (c) Right click held + left click shoots Shutter, not a punch.
  - (d) Mandela's axe and bare fists deal exactly the same damage as before.
  - (e) Punches add Photoshop mastery XP on NPCs.
- [ ] **Step 4:** Commit: `git commit -m "Photoshop punches: a Superliminal melee combo"`

### Task 2: Step In ends in a 3-punch combo

**Files:**
- Modify: `src/ServerScriptService/Skills/Snapshot.luau` (`Recast`, after the `PivotTo` and the `"StepIn"` event)
- Modify: `src/StarterPlayer/StarterPlayerScripts/SkillEffects/PhotoshopEffects.luau` (a `StepInCombo` effect that plays the punch animations on the local caster)

**Interfaces:**
- Consumes: `PhotoshopUtil.alive(player, character, humanoid)`, `Damage.Deal`, `CrowdControl.CanControl/Apply`, and the `"PhotoshopPunchHit"(point, critical)` effect from Task 1.
- Produces: CONFIG in Snapshot: `ComboHits = { 8, 8, 14 }`, `ComboInterval = 0.15`, `ComboReach = 6` (studs in front of her), `ComboWidth = 5`, `ComboKnockback = 40` (studs/s), `ComboKnockbackTime = 0.3`. A SkillEffects event `"StepInCombo"(character, hits: number, interval: number)` sent to the caster only (`FireClient`), plus `"PhotoshopPunchHit"(point, critical)` to all clients at each landed punch.

- [ ] **Step 1:** In `Snapshot.Recast`, after landing, `task.spawn` the combo:
  - Each punch waits `ComboInterval` after the last, and stops if the caster isn't `alive` anymore.
  - It hits the first living enemy in a `ComboWidth`-wide box `ComboReach` ahead of her: `Damage.Deal` with `melee = true` and Superliminal. The last punch is `critical = true` and knocks back along her look direction: `AssemblyLinearVelocity` for NPCs, and for players only when `CanControl`, then `CrowdControl.Apply`.
  - Clear the recast before the combo starts (it already is).
- [ ] **Step 2:** In PhotoshopEffects, add `effects.StepInCombo(character, hits, interval)`. If `character == Players.LocalPlayer.Character`, load `ReplicatedStorage.PunchAnimations.Punch1..hits` through the humanoid's Animator (priority Action3, the same as cast animations) and play each `interval` apart. Then send the event from Snapshot with `skillEffects:FireClient(player, "StepInCombo", character, #CONFIG.ComboHits, CONFIG.ComboInterval)`.
- [ ] **Step 3:** Apply to Studio and playtest:
  - (a) Z on the dummy, then Z again: she appears behind it and lands 3 quick punches (about 42 damage plus Snapshot's 12), the last knocks it back, and her arms play the punches.
  - (b) Move the dummy, or have a second player dash, right after Step In: the later punches miss.
  - (c) Die mid-combo: no errors and no further hits.
  - (d) Mash Z during the combo: no second Step In.
  - (e) Two players: the knockback respects hold protection.
- [ ] **Step 4:** Commit: `git commit -m "Step In ends in a 3-punch combo"`

### Task 3: Docs and sync

**Files:**
- Modify: `docs/superpowers/specs/2026-10-08-photoshop-checklist.md` (lines for the punches and the Step In combo)
- Modify: `ROADMAP.md` (Photoshop: punches and Step In combo done)

- [ ] **Step 1:** Add the checklist lines and the roadmap note. Re-export or move the `studio` tag as `CLAUDE.md` describes once Studio matches.
- [ ] **Step 2:** Commit and push: `git commit -m "Photoshop punches: checklist and roadmap"`, then `git push -u origin claude/vigilant-rubin-ckqtnn`.
