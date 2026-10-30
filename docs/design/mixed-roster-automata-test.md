# Mixed roster with automatons — 2026-10-31

## Scope
User requested one 9vs9 match with identical teams, the exact nine-slot builds in `simulation/scenarios/mixed_mirror_automata.json`, and main at slot5. Source workbook is the user upload committed in `57a5c98`, SHA-256 `d3d228ba437508d871a8cb4ae16e663e46c8818b051a0125844ab0f5df83d0d8`.

This is a Python extension of the existing TeamBattle match loop, not the local Godot demo. No claim of Godot parity or uploaded Godot assets is made. Only the selected kits/nodes are supported; this is not a general prose-to-game compiler.

## Confirmed test decisions
- User confirmed both teams use the same roster/builds.
- User confirmed Grand Battery auto-casts at allied team-turn start when ready and affordable.
- Each build includes the matching S1/S2 unlock and uses six passive points.
- Joan selection interpreted as S1.1.1 plus S1.2.1–S1.2.4. Joan skills: Holy Blade4, Holy Guard5, Maiden Care5.
- Leonardo6: Piercing5/Bombard5. Leonardo8 has17SP: Mona10/Piercing7, Vitruvian0. Its unlock level1 is counted within SP, not added free.
- Mona is selected when any living non-Immune ally is below50% MaxHP and the caster can act/pay; otherwise missing summons take priority. This50% is an explicit test AI policy, not a new game mechanic.
- Robin uses normal attacks, Hood and its free extra slot, plus the selected Golden Arrow proc. No voluntary Golden Arrow casts.

## Automatons
Both teams summoned two Piercing Automatons and one Bombard Automaton. They attack only at allied team-turn start, starting after the turn of summoning. Each owner is limited to one of each type. Machines inherit only Base Attack at the listed rate, snapshot at summon; selected machine passives apply separately. No extra character AP/MP cost is charged for their automatic attacks.

They persist after owner death because their skill duration is the rest of battle and there is no specified despawn rule. They occupy no formation slot and have no invented HP/targetability. Baseline is one hit,100% hit-check Accuracy against target Evasion, CHC/CDB/PEN0; explicit machine nodes add MHR/CHC/ATK Effectiveness/stun. Inventor's CHC12% does not increase damage with CDB0. These choices are preserved in the run manifest for review.

## Result
Seed42, A first: B wins at global turn50, B main5593.47HP, A main0. A has3 survivors/96411.86HP; B has4/104225.95HP.

| Metric | A | B |
|---|---:|---:|
| Actual damage | 675954.73 | 646136.89 |
| Actual healing | 300600.75 | 338232.68 |
| Automaton damage | 168373.13 | 182850.36 |
| Mona casts | 5 | 5 |
| Mona healing | 213221.87 | 259705.94 |

Piercing summons: A turn3, B turn4. Bombard summons: A turn9, B turn8. Same-source Barrage Sunder/DOT do not stack or refresh. Frozen is not deliberately recast over its existing row effects. Current Soldier Attack is2647.12; do not compare this result as a controlled single-rule change against the old log with Soldier Attack4656.05.

Mona and machine contributions are actual HP changes, capped by remaining/missing HP. One seeded match is not a balance or starting-side win-rate estimate. The AI is a documented heuristic, not a globally optimal action planner; no swap or Defend tactics are included.

## Reproduce
```sh
python -m simulation.mixed_run --output simulation/results/my_mixed_test
python -m unittest simulation.tests.test_mixed_battle -v
```
The output directory must be new. Exports input snapshot, workbook/code hashes, full JSON event log with turn-end states, final state, per-unit CSV, milestones and report. Change scenario/builds/seed rather than writing a new script.

## Validation
14 targeted tests pass: exact build/SP import, summon timing and inheritance, persistent machines, Mona threshold and cleanse, nonstacking statuses, duration/cooldown, character-only AP suppression under stun, counter timing basics, Robin proc cost, AOE recipient order, main-death stop, and seeded replay with HP/MP/AP conservation.

The full suite before the final AOE-order test had45 passes and one pre-existing legacy importer error: `Missing sheet: Combat mechanic`. That importer expects the historical Robin workbook schema; the new mixed importer reads the supplied Combat Mechanics workbook independently. No historical contract or regression baseline was changed to conceal the failure.
