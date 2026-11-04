# Nightingale main / Morgan Enchantress 9vs9

Current update: [2026-11-05 combat corrections](combat-rule-review-2026-11-05.md) supersedes the historical source and validation notes below. The active workbook/bundle includes the approved corrections; pending PR7.

Source: exact workbook SHA256 0930269b70fbf8bc1935c4276f64e9ed63c51519c4b819021409f7d2a3862e2f from design/workbook-20261103 commit1c0ff16cde52e5f75306ef82ef5dc54f2c14dc50; pending design source, not claimed merged. Review: workbook-caster-review-2026-11-04.md.

User revision supersedes the initial Witch build. Both teams mirrored; seven other slots unchanged. Slot8 Florence Nightingale The Matron is MAIN, Healing Hands6/Back to Duty6. Nodes S2,S2.1.1,S2.2.1-4; HP+5500, SDEF+275, Back to Duty Cross; S2.2.3 prerequisite grants no stat.

Slot5 Morgan le Fay Enchantress: S2,S2.1.1,S2.2.1-4; Fae Starfall6/Malediction6, confirmed by user. HP+5847, base AP Recovery+8, Malediction stat effectiveness+13%, Starfall SATK effectiveness+13%, Starfall cooldown-2. Final HP45647, MP95600, APR103, StarfallAP300/CD8. No Avalon’s Veil or Witch bonuses. Curse is the old name of Malediction in the current workbook.

Both Casters have12 total Skill Points. Node source coordinates: design/characters/caster-bindings.json. Nightingale finalHP44184. Her AI heals the lowest HP ratio, otherwise applies Haste. Morgan prioritizes ready Starfall, then Malediction targeting front/middle row. Malediction applies row DOT, Silence and Intimidated for4 Global Turns. +13% stat effectiveness applies to DOT and Attack Modifier reduction, not duration. Silence blocks active skills while normal attacks and passive auto-casts remain possible. No Firestorm replacement node selected.

Reuses src/combat and existing scenario importer/UI. Multiple character blocks share Caster sheet through explicit name/stat offsets. Accepted source and immutable runtime hashes track the selected implementation.256 class/Item caches and9 Caster skill caches independently validated; no claim of full Excel recalculation. Python backend not extended with Caster kits.

Presentation uses existing simple class sprites; new Casters use caster sheet, not unique character art. Piercer keeps its own sprite. Other assets, Auto, Restart and logs reused.

Verification:4915 Caster checks passed; six complete matches covering both starting sides and seeds42/43/44, all four selected actives cast. Candidate and published runtime tested independently. Legacy requested/mixed/log/rules and importer regressions rerun for final revision. UI opens requested_9v9.tscn. This is correctness testing, not balance tuning.

Earlier source review also incorporated Stun suspension of passive skills/auto-casts/continuous effects and Soldier aura12%DEF/4%ATK. Intrinsic node stats persist during Stun. Independent automata persist while their summoner lives. Unselected Firestorm/Connection/other Caster kits are not implemented; Vitruvian MP remains10004 per source.

Publication: separate demo/nightingale-morgan-9v9 branch, PR required, no merge authorized.
