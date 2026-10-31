# Dummy skill test — local demo

Source: the user-provided OneDrive workbook, read on 19 October 2026. The GitHub main branch checked during this task still returned the older two-dummy design; this implementation was not pushed to the repository.

## Design entries applied

- Balanced dummy!H1:O2: Dummy special hit; AP cost 100, mana cost K, cooldown 1; SATK = K * SL * 0.3.
- Balanced dummy!B2:B8: HP 20000, MP 20000, ATK 2000, DEF 1000, SATK 3000, SDEF 1000, APR 100.
- Combat mechanic!A57:C63: cooldown starts at duration; each team's recovery begins on its first turn, then occurs every global turn; immediate cooldown changes apply when resolved.
- Combat mechanic!A36:C42: Defend costs 50 AP, transfers the existing slot when possible, increases defense and skill-defense effectiveness by 50%, expires at the next own-team turn (two global turns after use).

## Test choices

The workbook displays skill values at SL 10. This demo allocates all 10 skill points to the one defined skill, with no bonus level. K = 1000, so skill attack is 3000. Against SDEF 1000, damage is 1500 before remaining-HP capping. No extra character SATK is added to this skill's stated formula.

The skill description does not define a multi-target pattern or targeting restriction. The test retains the existing single-target, front-first demo policy. Auto uses the skill whenever cooldown is zero and MP is sufficient; otherwise it uses a normal attack. MP is not regenerated because no MP recovery rule is specified here.

Skills starts ON. Turn it OFF to compare the normal-only benchmark; toggling restarts the battle. Defend test starts OFF. Turn it ON to make the first initial slot holder of each team turn defend and transfer that existing slot to an eligible ally. Other initial slots continue normally. This is a test policy, not a general-purpose combat AI or a manual action-selection interface.

AP may become negative when a committed skill costs more AP than the holder has. MP must cover the mana cost. Default recovery applies to living characters only; additional actions do not create recovery events. The model exposes immediate cooldown changes for testing modifiers; the dummy skill itself has no recovery modifier.

## Implementation

- data/gameplay/dummy_skill.json: source-backed skill values and selected test level.
- src/combat/squad_battle.gd: skill/normal action selection, MP, cooldown, Defend and slot transfer.
- src/ui/main.gd: sequential presentation, resource display and test switches.
- src/ui/dummy_view.gd: skill hit coloring and guard indicator, using existing character animation.
- tests/simulation/test_dummy_skill.gd: skill scaling, resources, staggered cooldown activation, immediate changes and Defend checks.

The 1v1 benchmark module remains unchanged. Passing an empty skill configuration keeps the normal-only 9v9 simulation available.
