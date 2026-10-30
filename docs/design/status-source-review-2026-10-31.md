# Workbook status-source review — 2026-10-31

## Source and scope
- Base main: `a2afe350854e6bfb31933d2ae93c02b67cd261ab`.
- Replaced `data/excel/Thiết kế game.xlsx` with the user-uploaded workbook, byte-for-byte.
- Workbook SHA-256: `d3d228ba437508d871a8cb4ae16e663e46c8818b051a0125844ab0f5df83d0d8`.
- Reviewed status duplication and event ordering; no Python or Godot implementation changes.

## Confirmed rules
- `Combat Mechanics!C171`: source identity is the skill or passive node, not the caster; level and effect magnitude do not create another source.
- `C172:C175`: at most one instance per target, status, and source. First valid application wins. A duplicate cannot stack, replace, refresh or extend it. Preserve the original caster, value and expiry. Reapply only after removal/expiration.
- `C176:C178`: different sources follow their stacking rules; resolve effects independently; rejected duplicates do not refund costs. Explicit exceptions, including Stun Count stacking/refresh, override the default.
- `C160:C169`: turn phases and simultaneous-event ordering are now specified. Default order is acting team first, then formation slots 1–9; multiple statuses on one recipient resolve oldest first. Reactive timing and stat pipeline remain distinct.
- `C110` points to the new duplicate rules; `C115` permits refresh only for effects that explicitly allow it. The previous start/end-boundary pending items have been removed.

## Consequences for implementation
1. Two Napoleons using Crushing Barrage on the same target produce only one Sunder from that skill. Its DOT is also a same-source status and cannot duplicate. A different DOT skill remains a different source (`status!F22`). Do not treat two casters as two status sources.
2. Intimidated from the same passive node on different characters cannot stack on a target. Identify the node within its character/kit; a bare node label shared across unrelated characters is not sufficient.
3. Two Robins marking the same target with Thief’s Mark leave only the first valid mark. Preserve its caster-specific damage scope; the later Robin does not become the mark owner.
4. For effects with several components, reject only matching status duplicates. A valid direct damage/heal component still resolves. No cost refund is granted.
5. Same-caster reapplication also cannot refresh a default status. Stun Count explicitly remains an exception (`status!F24`).
6. Chill says “per stack” (`status!F27`) but does not explicitly authorize repeated same-source stacking. Under the new default, Frozen Axe cannot keep adding its own Chill stacks merely because Chill has infinite duration. If accumulation from that same skill is intended, it needs an explicit exception; do not invent one in code.
7. The status sheet's general duration and stacking text (`C47:C48`) does not itself authorize duplicate refresh. Interpret it under Combat Mechanics section 15. A cross-reference could make this clearer, but this upload does not edit the user's wording.

## Additional observed workbook change
Soldier character Accuracy (`Soldier class!C25`) changed from 0 to 1 (100%); its character Attack allocation formula (`C11`) also changed. Preserve both supplied changes; do not import only the new mechanics.

## Validation and limitations
- XLSX ZIP integrity passed; openpyxl read all 13 sheets successfully.
- No cells typed as Excel errors were found. This does not recalculate or certify every formula.
- Uploaded file and committed workbook are byte-identical.
- Compared cell contents against main; changes are in Combat Mechanics, Terminology, status and Soldier class. Row shifts account for many changed cells.
- No battle was rerun; this review does not establish Godot/Python conformance. The earlier `log 1.json` predates these rules and shows two-caster Sunder stacking.
- Keep the independent-conversion-source priority item pending; event ordering alone should not silently resolve that separate stat-evaluation rule.
