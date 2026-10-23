# Bluetooth 9vs9 — historical reference

This is the existing simulation, preserved instead of rebuilding it for the next
team-combat task. `input_stats.json` and `assumptions.json` describe the exact older
design: Connection duration2, Fortify15%, Frozen no-overlap AI, first-link priority
and one-hop post-mitigation damage sharing. Do not treat it as the current design.

Replay using the frozen snapshot (no original attachment needed):

```sh
python simulation/legacy/bluetooth_9v9/simulate.py --runs 1000 --output simulation/results/bluetooth-historical
python simulation/legacy/bluetooth_9v9/export_report.py --input simulation/results/bluetooth-historical
```

The output directory must not already exist. `summary.json` and
`sample_result.json` here are regression references; the new run writes into the
chosen output folder. `export_report.py` exports that run using historical assumptions;
the shared reporter for new backends is `simulation/reporting.py`.

This old backend still contains numerical build effects in code. Before running
new Bluetooth designs, move those effects into reviewed node data and add tests;
reuse the targeting/link/DOT implementation rather than copying another engine.
The main test suite checks an exact historical replay so those mechanics are not
lost while modernizing the backend.
