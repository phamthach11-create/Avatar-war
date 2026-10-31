# Current 9v9 test

Open project.godot and press Auto. Next turn presents one complete global turn; Restart cancels pending animations. Skills is enabled by default; Defend test exercises defense and slot transfer.

Source: GitHub phamthach11-create/Avatar-war commit 808728defa9c5ee3ec6a153ece6b90d4782386b5, workbook blob acf197a41137cd2b2bb8aa7ac1cf91f74ab0c165. Snapshot: design-2026-10-21.xlsx. Read dummy Combat power total column B, Item, Term, status and Combat mechanic.

Configuration: data/gameplay/dummy_9v9.json. Combat: src/combat/sword_battle.gd. Legacy combat fixtures remain separate.

18 dummies: HP/MP 40000, ATK 2000, DEF/SDEF 1000, AP recovery 100. Warrior weapon supplies Front (frontmost living enemy in each lane) and Single targeting only; weapon stats are not added again. Skill uses this same demo targeting, SL10, damage 2400 against unguarded dummy, MP1000, AP100, CD4. Normal attacks use multi-hit1.2, crit20%, penetration20%; all hits keep original primary position. Main is rear center.

User ruling 2026-10-21: Stun Count has ONE shared duration of 3 Global Turns refreshed by each stack gain. Last gain at G expires at start G+3, for the entire stack. Threshold4 clears stacks and applies Stun; Stun applied G expires start G+2. No stacks accrue while stunned; character AP recovery is zero and no voluntary slots are assigned while stunned.

Cooldown starts at full duration. First automatic recovery starts on each team's first turn; after activation recovery occurs at every Global Turn. Instant recovery affects the remaining counter immediately without granting slots or AP.

Verification: tests/simulation/test_sword_battle.gd covers targeting, damage, multi-hit, cooldown, Stun duration and shared expiry, 40 seeded battles and UI restart cancellation. Run Godot --headless --path <project> --script tests/simulation/test_sword_battle.gd.

Demo policies: fixed seed42, choose first team with selector, automatic skill priority when ready and MP sufficient, random legal front target, 500 Global Turn safety limit. Defend test is an optional scripted comparison. These are test controls, not additional workbook rules.
