# Mixed 9v9 demo — 2026-10-29

## Source and scope
Workbook snapshot design-2026-10-29.xlsx, GitHub source commit dc81030fb999116aa50288ea2a388c16c7aa642a, blob 36876091de28fd6b889e2e32c7f57c4f2f59f37c. The six class sheets' total base column B supplies stats, including equipment: do not add weapon stats twice. Average Attack is a reference expectation, not per-hit ATK. Skill costs, formulas, target and area come from each class's skill table; weapon scope only applies to normals.

Code: src/combat/mixed_battle.gd extends the existing combat modules. Data/builds: data/gameplay/mixed_9v9.json. Existing Dummy fixtures and tests remain for regression. UI, arena, sprite atlas and audio are reused. Class tint, a cannon overlay, ranged bolts and healing feedback distinguish roles; these are shared placeholder character illustrations, not final unique character art.

## Formation and builds
Both teams use the same roster, nodes and allocations. Row-major identities: front indices 0-2, middle 3-5, rear 6-8. Display mirrors the teams. Random main selection was performed once, choosing index4 (A5/B5), Leonidas Striker. Main is not forced into the rear row.

Front: Joan tank, Leonidas tank, Harald Bluetooth. Middle: Joan support, Leonidas Striker MAIN, Leonardo. Rear: Napoleon I, Robin Hood, Napoleon II. Each team has all six characters and two Napoleons. Both Napoleons use Emperor builds with Imperial Decree, avoiding the as-yet-unspecified Grand Battery trigger. Skills and selected node IDs are inspectable in Builds and the JSON. Unused passive points are not silently spent. No summon, spirit revival, or unselected branch is simulated.

## Implemented selected kits
- Joan: Holy Blade with behind-primary secondary and explicit Stun Count; Holy Guard heal + Immunity; Maiden's Care auto-heals the main and adds cast-time flat Base SDEF from Joan's Base SDEF.
- Leonidas tank: War Cry and Phalanx. Leonidas Striker: War Cry and God-King Slayer, including skill CHC, own CDB, Main bonus and selected SATK Effectiveness node.
- Bluetooth: Frozen Axe initial damage + DOT + Immobilized across the target row, Deadly Strike with selected node removing HP condition and reducing MP/AP cost. Connection was not selected.
- Leonardo: Vitruvian Man buffs the rear allied row; Mona Lisa heals all living allies and removes one oldest negative status. Summons were not selected.
- Robin: unavoidable Golden Arrow, passive Thief's Mark on the two highest-damage living enemies; each source's vulnerability only amplifies that Robin's damage.
- Napoleon: Crushing Barrage applies Sunder and DOT without inventing an initial strike; Imperial Decree on the other living Napoleon restores MP through the chosen node and grants source-specific follow-up chance. Follow-up requires paying the coordinating Napoleon's normal attack AP cost, does not consume an existing slot, and cannot recursively coordinate.

Normals use per-character accuracy, evasion, multi-hit, penetration and crit, own weapon area and final secondary damage penalty. Block negates only damage, keeping landed-hit effects; Phalanx counters one hit without MHR or AP cost and never chains counters. Areas stay centered on the initial primary through all hits. Main death cancels remaining resolution.

## Timing approved by user
Start: revival (none in selected builds), passive auto-casts, acting-side AP recovery, slots. End: DOT, expiration, cooldown. Simultaneous sources within each phase resolve in stable side/index/source-application order as the demo's deterministic scheduling policy; this is not an added universal game rule.

Cooldown starts full; both teams recover at the end of every Global Turn starting Turn1. Timed effects applied on G with D last through end G+D-1. Stun and Stun Count both have duration3; count has one shared timer refreshed on gain, maximum one gain per target per Global Turn. Stun blocks voluntary slots and zeros Base Character AP recovery; passives remain usable. Immobilized blocks voluntary slots without suppressing AP recovery. Costs can leave AP negative.

AI is a disclosed test policy: useful heal, unexpired buff/decree avoidance, then ready actives, then normal attack against a low-HP legal target. No swap/Defend AI or claim of optimal play. Seed42 by default, first-side selector, 300-turn safety cap. Skills OFF disables selected kit skills and triggered Phalanx; build stat nodes remain.

## Source issues retained
User correction 2026-10-29 supersedes Soldier class B25=0 for this demo: both Leonidas builds on both teams now have Accuracy100%, Evasion0%. Workbook itself has not been edited. Direct normal-attack tests confirm HP damage for all four Leonidas instances. Mona Lisa text formula contains 50%%; the saved numeric SL5 heal 4135 is used and scaled linearly by the chosen level. No workbook edits made.

## Verification and synchronization
Six seeded full battles split between both starting sides ended at main defeat in 72-79 Global Turns after the Accuracy correction; 8,196 checks covered formation, SP, cooldown, shared Stun duration, skill scope/costs, healing/cleanse, DOT, Block, full battle resource invariants and Restart cancellation. UI checked in a rendered screenshot. These checks cover the selected kits only, not the entire workbook or Python simulator.

This demo is initially a local implementation. Do not claim GitHub or Python has the same behavior until its source, assets, tests and this handoff are published and reviewed.

