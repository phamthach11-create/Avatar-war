# Combat review corrections — 2026-11-05

The user approved correcting the design first, then the existing Godot demo after reviewing `avatar-war-2026-11-04T09-33-39-409808260.json` (A wins on global turn48). Base: demo/nightingale-morgan-9v9 at562016d; main source workbook blob1a07c01a84a540676ac2cd8863bb0993bc057fdd / SHA2565715d24e5c2804f55bce901b1dde941ae719fb02169d91b23eecb93c1198a19d.

## Final behavior

| Problem | Correction |
|---|---|
| Grand Battery could cast on the opposing turn and expire before the caster's own turn | Cast only at the start of each allied team turn, subject to existing cooldown/MP/Stun rules |
| Stun removed intrinsic spec and ally-death APR bonuses along with Character APR | Keep the imported Character source separate; suppress only that source, then apply remaining contributions and modifiers |
| Recasting War Cry/Haste did not renew their duration | One instance per status/source across casters; new expiration is end of R+D−1. No magnitude/duration stacking. Preserve original magnitude, caster and oldest-status ordering |
| Summons executed after the passive group of both teams | One ordered start-event pass: acting team, owner formation slot, source design-sheet row; summons are interleaved with auto-casts, not appended as a separate group |
| Malediction could apply negative statuses through Immunity | Reject negative-status application/refresh to Immunity or Invincible recipients through the shared requested-demo status gate |

Stun still blocks passive skills while intrinsic stat nodes remain. Independently summoned units still act while their living owner is stunned. Existing cast buffs are not removed by a later Stun. A shorter reapplied duration replaces the old duration rather than taking the maximum; this implements the user's explicit duration-replacement rule.

Ten workbook text cells changed across Devastator class, status and Combat Mechanics; exact before/after manifest: `design/sync/combat-rule-text-2026-11-05.json`. ZIP-level cell edits preserve all other source values, formula definitions, cached values, worksheet layout and unrelated workbook parts. No Excel recalculation claimed. Numeric class/skill caches validated independently by the existing importer.

## Verification

Tests used an isolated candidate project generated with the existing `build_scenarios` importer, before accepting the production checkpoint. Candidate engine hashes match the edited source. Only after passing checks was the receipt accepted and the normal runtime bundle published. `plan` returns0differences; `check` reports SYNC CURRENT.

- New focused regression:36,691 checks,0failures; includes both initiative sides, AP source separation, duration replacement, Immunity, summoned-event order and full matches.
- Caster roster:4,951 checks; six matches (seeds42/43/44, each starting side), selected active skills exercised.
- Legacy requested roster:1,516 checks; full match and summon regression.
- Current rules453; opening slots80; weapon playback429; log export1,355 checks, all pass.
- Design importer/synchronization:13 tests pass.
- Headless UI smoke: existing requested scene, ten turns, summons, build dialog, timed playback and Restart pass. No screenshot or visual-rendering QA claimed.
- Godot available in this environment:4.6.3; uploaded log used4.7.2. Local4.7.2 should run the same regression suites after pulling.

New seed42 match: firstA → A wins at45; firstB → B wins at45. This is regression evidence, not a new100-match balance estimate. It does not isolate which individual correction changed the outcome.

## Delivery scope

Continues the pending demo/nightingale-morgan-9v9 branch / PR7. Uses the same roster (Nightingale main8, Morgan Enchantress5), existing opening2/3/4/5 rule, skills and AI. No Python combat implementation or graphics changes. Updates on GitHub do not automatically replace an already-open demo on another PC; pull the demo branch and reopen `src/ui/requested_9v9.tscn`.
