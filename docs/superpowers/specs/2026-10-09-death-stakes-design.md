# Death stakes and the Headhunter: design

Status: approved in chat 2026-10-09; waiting on review of this written spec.

## Intent

Part of making the game "deeper than Blox Fruits, simpler than Deepwoken": dying should cost
something, and PvP should have a prize, without Deepwoken's wipes. Two pieces:

1. **Dropped yen:** every death costs a little yen, which goes to the player who got the kill.
   Kept low (5%) so friends can't use kills to pass money around.
2. **The Headhunter:** the server's kill leader is marked for everyone to see. They lose more if
   they die, and whoever takes their head gets a big XP reward. Killing them resets the race.

Success: fights have stakes and a reason to hunt; nobody loses progress they can't win back;
friends can't farm each other for money, XP or the mark.

## Kill credit

The same rule as the kill feed (`KillFeed.server.luau`): the killer is `Damage.LastAttacker` if
their last hit (`Damage.LastHit`) was within **15 s** and they aren't the victim. Otherwise no
player gets the kill (an NPC, a fall long after a fight, a reset).

**Repeat kills:** a killer who already killed the same victim within the last **5 minutes** gets
**nothing** from that kill (no yen, no XP, and it doesn't count toward the mark). The victim still
loses their yen; it just disappears.

## Dropped yen

- On death a player loses **5%** of the yen they carry (**20%** while they're the Headhunter),
  rounded down.
- A credited, non-repeat killer receives that amount. Otherwise it's gone.
- The death screen shows the loss (**"−1,240 ¥"**) under who killed you; nothing when it's 0.

## Kill count

- `HeadhunterKills` (a player attribute, this server only, not saved): kills of **other
  players** that count (credited, not repeats). NPC kills never count.
- In **Studio only** (`RunService:IsStudio()`), killing a `KillFeedDummy` counts as a player kill
  and gives the mark if earned, so the system can be tested alone. No yen moves for dummies.

## The Headhunter

- **Who:** the player with the most `HeadhunterKills`, once that's at least **3**. Ties: whoever
  reached that count first keeps it. If someone passes the Headhunter's count, the mark **moves**
  to them (no reset).
- Stored as the `Headhunter` attribute on `ReplicatedStorage` (the player's UserId, or nil), so
  every client can read it.
- **No perk:** the Headhunter only carries the risk (and the fame).
- **The Headhunter dies:**
  - **to a credited, non-repeat player:** that killer gets the Headhunter's **20%** yen and
    **bonus XP** = their own `StatConfig.XPToLevelUp(level)` × (20% + 5% for each of the
    Headhunter's kills above 3), at most 50%.
  - **any other way** (an NPC, a fall, a reset, a repeat kill): the 20% is still lost; nobody
    gets yen or XP.
  - Either way: the mark ends and **every** player's `HeadhunterKills` resets to 0.
- **The Headhunter leaves the server:**
  - in combat (dealt or took damage) within the last **10 minutes**: they lose the **20%**
    before their data is saved, as if they'd died. Not when the server is shutting down.
  - otherwise: nothing lost.
  - Either way: the mark ends and every count resets.

## What everyone sees

- **Over the Headhunter's head:** a red square **HEADHUNTER** tag, seen from any distance and
  through walls (`AlwaysOnTop`). Their name in OverheadHealth turns red.
- **Kill feed lines:** "**Name** is the Headhunter" (it starts or moves), "**Killer** took
  **Name**'s head" (with **+XP** and **+¥**), "The Headhunter fell" (any other end, leaving
  included).

## Architecture

- **`ReplicatedStorage/HeadhunterConfig.luau`:** the numbers (`DropShare = 0.05`,
  `HeadhunterDropShare = 0.2`, `MinKills = 3`, `RepeatWindow = 300`, `CreditTime = 15`,
  `LeaveCombatWindow = 600`, `BonusBase = 0.2`, `BonusPerKill = 0.05`, `BonusMax = 0.5`) and pure
  rules, Lune-tested: `dropAmount(yen, isHeadhunter)`, `bonusXP(xpToLevel, headhunterKills)`,
  `leader(counts, reachedAt) -> userId?` (most kills ≥ MinKills, ties to the earliest to reach it),
  `isRepeat(lastKillAt, now)`.
- **`ServerScriptService/Headhunter.server.luau`:** watches every player's character deaths
  (and Studio dummies), credits kills, moves yen, counts kills, picks/moves/ends the mark,
  tracks each player's last combat time with `Damage.OnDealt` (attacker and victim), and sends
  feed lines.
- **`PlayerStats`:** `PlayerStats.TakeYen(player, share) -> number` (takes `floor(yen × share)`,
  returns it) and `PlayerStats.BeforeLeave(callback)` (callbacks run in its PlayerRemoving
  **before** `save`, skipped during `BindToClose`).
- **Remotes:** the `KillFeed` remote gets the extra lines as a second message kind
  (`"Headhunter", kind, names, xp, yen`), drawn by `KillFeed.client.luau`. The death screen reads
  the player attribute `LastDeathYenLost` (set before the character is removed).
- **Client:** `Headhunter.client.luau` (the head tag);
  `OverheadHealth` (red name for the Headhunter); `DeathScreen` (the yen line).

## Not in scope

Lives, XP loss, wound debuffs; a Headhunter perk; an on-screen banner or kill counter (the
owner doesn't want one: the head tag and the feed lines are the only signs); saving kill counts across servers; a global
leaderboard; team/party rules (friends can still fight; the repeat rule is the only anti-farm).

## Testing

- Lune: `tests/HeadhunterConfig.spec.luau` (drop amounts at 0, 99, 1000 yen and as Headhunter;
  bonus XP at 3, 5 and 20 kills and the cap; leader with no one ≥3, a clear leader, a tie, a
  pass; repeat at 299 s and 301 s).
- StyLua parse and selene on every changed script.
- In-game checklist `docs/superpowers/specs/2026-10-09-death-stakes-checklist.md` (solo with the
  Player Dummy in Studio; real yen and the leave rule need two or three players in a live
  server, since Studio can't save).
