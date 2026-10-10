# Death stakes and the Headhunter: playtest checklist

Spec: `2026-10-09-death-stakes-design.md`. Plan: `../plans/2026-10-09-death-stakes.md`.
Ticked lines were checked in Studio on 2026-10-10 (solo, with the Player Dummy). The rest need
**two or three players in a live server** (Studio can't save, and only drives one player).

## Solo in Studio
- [x] Three kills of the Player Dummy (`KillFeedDummy`) give you the mark: "**You** is the
      Headhunter" in the kill feed, and a red square **HEADHUNTER** tag over your head.
- [x] Resetting as the Headhunter ends it: "The Headhunter fell", the tag goes, your count is 0,
      and you lose **20%** of your yen (¥1,000 → ¥800).
- [x] An ordinary death loses **5%** (¥1,000 → ¥950).
- [x] The death screen shows the loss under the cause ("−400 ¥"), and nothing when it's 0.
- [x] The tag follows the Headhunter through a respawn.
- [x] The feed lines: "is the Headhunter", "took …'s head  +XP  +¥", "The Headhunter fell".

## Two or three players, live server
- [ ] Killing another player gives you 5% of their yen; their death screen shows the loss.
- [ ] Killing the same player again within 5 minutes gives nothing (they still lose their 5%).
      After 5 minutes it pays again.
- [ ] Each paid player kill counts; at 3 the kill leader becomes the Headhunter.
- [ ] A tie stays with the Headhunter; passing their count moves the mark (feed line, tag moves).
- [ ] Killing the Headhunter: you get their **20%** and bonus XP (your XP to the next level ×
      20%, +5% per kill they had above 3, at most 50%); "**You** took **Name**'s head".
      Everyone's count goes back to 0.
- [ ] The Headhunter killed by an NPC, a fall long after a fight, or a repeat kill: they lose
      20%, nobody gets anything, "The Headhunter fell".
- [ ] The Headhunter's name is red over their health bar for everyone else.
- [ ] The Headhunter leaves **right after a fight**: they lose 20% (check their yen when they
      rejoin), "The Headhunter fell", counts reset.
- [ ] The Headhunter leaves **after 10 minutes without fighting**: no yen lost; the mark still ends.
- [ ] A player who isn't the Headhunter leaves: their count is gone; if they were second, the
      mark doesn't change. A killer who leaves just before their victim dies: no errors, no yen.
- [ ] Shutting the server down while someone is the Headhunter takes no yen from them.
- [ ] Rejoining resets the 5-minute repeat rule for that pair (a new session starts fresh).
