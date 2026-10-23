# Avatar War workspace

For combat simulation requests, start with `simulation/README.md` and
`simulation/AGENTS.md`. Reuse the committed runner, character data, build node
catalog and scenario configuration instead of creating a new standalone engine.
Default to 1,000 battles per pair, split equally between starting sides.

The latest user-provided workbook and explicit user clarifications govern game
design. Import numeric changes through the existing importer; implement and test
new mechanics in the existing simulation directory. Do not infer unsupported
skill behavior from its name or silently reuse historical rules.

The Godot demo and Python simulator are separate implementations. Updating the
Excel workbook or simulation data does not automatically update Godot gameplay.
