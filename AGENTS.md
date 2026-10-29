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

For all cloud/local handoffs, read docs/design/cloud-local-workflow.md and docs/design/cloud-local-status.md before continuing. GitHub main is the approved source of truth. Inspect open pull requests for proposed work. Update the handoff log in each implementation/design pull request with source revision, changes, validation, remaining gaps and next step. Do not claim local-only work is on GitHub or that Python and Godot are synchronized without evidence.

For graphics, environment, character art, animation, VFX and combat presentation work, follow the user-approved docs/design/graphics-roadmap.md. Read its progress table and the handoff log first. The next art milestone is direction and composition, followed by a playable Napoleon quality sample; do not mass-produce assets before that sample is reviewed. Preserve combat behavior. Do not treat local demo code/assets as uploaded until verified in the repository.
