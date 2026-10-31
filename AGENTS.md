# Avatar War workspace

For Avatar War work, use `.agents/skills/avatar-war-workflow/SKILL.md` and start
with the relevant section of `docs/design/project-index.md`. Read only the
implementation and design material needed for the requested backend.

For Python combat simulations/statistical experiments, start with
`simulation/README.md` and `simulation/AGENTS.md`. Reuse the committed runner,
character data, build node catalog and scenario configuration. Default to 1,000
battles per pair, split equally between starting sides, unless the user specifies
another count. Godot demo requests use the existing Godot engine/scenario and do
not require loading the Python workflow merely because they involve combat.

The latest user-provided workbook and explicit user clarifications govern game
design. Import numeric changes through the existing importer. For Python, implement and
test mechanics in simulation/; for Godot, extend the existing Godot combat modules
and verify that backend separately. Do not infer unsupported
skill behavior from its name or silently reuse historical rules.

The Godot demo and Python simulator are separate implementations. Updating the
Excel workbook or simulation data does not automatically update Godot gameplay.

For cloud/local handoffs, read docs/design/cloud-local-workflow.md and inspect the relevant dated entries in docs/design/cloud-local-status.md, using docs/design/project-index.md to route first. GitHub main is the approved source of truth. Inspect open pull requests for proposed work. Update the handoff log in each implementation/design pull request with source revision, changes, validation, remaining gaps and next step. Do not claim local-only work is on GitHub or that Python and Godot are synchronized without evidence.

For graphics, environment, character art, animation, VFX and combat presentation work, follow the user-approved docs/design/graphics-roadmap.md. Read its progress table and the handoff log first. Use the current milestone in docs/design/project-index.md and the user's latest decisions; older Napoleon/2D milestones are historical after the switch to 3D. Do not mass-produce assets before the current quality sample is reviewed. Preserve combat behavior. Do not treat local demo code/assets as uploaded until verified in the repository.
