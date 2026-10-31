# Export test battle logs

Click **Xuất log** after the current turn finishes presenting or after victory. Choose a folder and save JSON (recommended for analysis) or TXT (readable report). The save dialog pauses Auto; resume with Auto after saving/canceling. Save before Restart or closing the game: export is optional and logs are not automatically persisted.

Only fully presented turns are exportable. The button is disabled during playback, even though the combat model has already calculated that turn. Restart starts a new match ID and cancels a pending save dialog, preventing a stale request from exporting a different match.

JSON schema1 includes source design commit/blob, explicit user corrections, complete scenario/builds, seed, first side, Skills mode, engine/config SHA256, match/export times, initial state, turn/action/impact events and final state/result. Each impact records damage (negative for healing), landed/miss, crit/penetration flags and recipient state. Unit states include HP/MP/AP, cooldowns, statuses with duration/source, Stun Count and Stun expiry. Static skill descriptions are stored once in scenario; state changes after actions replace only changed unit snapshots, including system AP/cooldown/expiration events. Instructions to reconstruct state are embedded in JSON. Exports during an unfinished match are clearly marked in_progress.

TXT lists the roster/builds, source, turn-by-turn events, hits/misses/heals, state changes and final resources. Log export does not alter RNG or battle state. Logs are user-selected local files and should not be committed as source.

Implementation: src/combat/battle_log.gd and the Export dialog in src/ui/main.gd. Verification: tests/simulation/test_battle_log.gd exports empty, partial and completed matches in JSON/TXT, reconstructs every final unit state from serialized deltas, checks current-match identities, Auto pause, stale dialog cancellation, and busy-playback blocking. A real completed fixture contained 60 turns / 1114 impacts. Rendered toolbar and save dialog were checked.
