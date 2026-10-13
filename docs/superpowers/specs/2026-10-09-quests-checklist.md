# Quests: in-game test checklist

Not run in-game yet. `tests/run.sh` (Lune) passes QuestConfig's rules (bounty reward, the saved
challenge text, how challenges advance, bounty ids) and the Keybinds rules with J removed. Everything
below needs Studio. Bounty Hunters are NPCs tagged `QuestGiver` with a `GiverId` and a ProximityPrompt
(`ObjectText` "Bounty Hunter"), placed on the `QuestSpawn` parts; enemies carry an `EnemyType`
attribute.

## Bounties (level quests)
- [ ] Walk up to a Bounty Hunter: the prompt shows "Bounty Hunter". E (out of combat) opens a small
      square panel titled BOUNTY HUNTER listing that giver's bounties: title, "Defeat N <Type>s",
      reward (XP and ¥), "Lv. N" and Accept.
- [ ] A bounty above your level shows greyed with "Lv. N" and Accept does nothing. (Use the admin
      panel to change level.)
- [ ] Accept: the panel closes and a small tracker appears at the right edge, vertically centred:
      "BOUNTY", the bounty's title and "<Type>s 0/N". The Quests menu's BOUNTY tab shows the same.
- [ ] Kill an enemy of the right `EnemyType`: the tracker counts up. Killing a different type, or a
      player, doesn't count. Kills by someone else (you did no damage) don't count.
- [ ] The last kill pays at once, wherever you are: a gold "Bounty complete" popup with the title
      and "+X XP  +¥Y", the tracker disappears. X is 1.5 × N × the enemy's level XP, Y the same for ¥
      (StatConfig.EnemyXP / EnemyYen), on top of what the kills paid.
- [ ] Take the same bounty again (it's repeatable). Take a different one while one is active: it
      replaces the old (progress starts at 0).
- [ ] Walk away from the giver with the panel open: it closes itself.
- [ ] Abandon (Quests menu, BOUNTY tab) clears the bounty and the tracker. Dying keeps it. Leaving
      and rejoining drops it.
- [ ] Review Focus 5: from far away (more than 15 studs), or below the level, the server refuses.
      (Fire the `Quest` remote from the command bar to try.)
- [ ] Nothing errors with no `QuestGiver` NPCs in the map; a prompt on a model without the tag does
      nothing.

## Mastery challenges
- [ ] J (or the QUESTS button, left edge under INVENTORY / ADMIN) opens the Quests menu; J again or
      × closes it. The mouse is free while it's open. Esc-less, like the other menus.
- [ ] J is no longer offered as a key in Settings → Keybinds.
- [ ] CHALLENGES tab: a row of the sets you own (the held set is picked at first), each challenge with its
      text, a progress bar, "n/N" and "+reward". Ones whose move isn't unlocked show "Mastery N" and
      stay greyed (mastery 5: Event Horizon / Prism Form / Cut & Paste; 20: Tornado; 50: Solar Lance /
      Iris Horizon).
- [ ] Mandela: 15 Axe Boomerang hits (a hit with Spine Lash counts too); pull 3 with one Event Horizon;
      25 hits erased from players by Misremembered (needs another player or the Player Dummy);
      Tornado kills 3 enemies at once, 5 times; the axe finisher on someone Z's pull left exposed
      (the "exposed" link), 5 times.
- [ ] Iridescent Requiem: 20 Light Shots; hit 3 with one Prism Shot; 10 enemies flashed through with
      Lightstep; 90 s of flight without landing (it counts when you land); 5 Solar Lances on a
      Sunmarked target.
- [ ] Photoshop: 10 Snapshots that frame someone; Step In with all 3 punches landing, 5 times; Cut &
      Paste an enemy 5 times; Undo 10 times healing at least 20 each time; catch someone in Iris
      Horizon without them escaping, 5 times.
- [ ] Revolver: 30 shots; 3 Dead Eye kills.
- [ ] Completing one: a gold "Challenge complete" popup with its text and "+N mastery XP", the row
      shows ✓ and the set's mastery XP goes up (level up popup if it crosses a level). Doing more of
      it afterwards pays nothing again.
- [ ] Progress is saved (the Challenges attribute, 1,000 characters at most): leave and rejoin on a real
      server (Studio can't reach DataStores), the bars are where they were and done ones stay done.
- [ ] An untagged or other-set hit doesn't count (e.g. a Knife hit isn't a Light Shot). Burnt and
      Bleeding ticks don't count for hits or kills.

## Output window
- [ ] No errors from Quests, QuestServer, QuestBoard, Quests (client), Damage, Passives, PlayerStats
      or any skill.
