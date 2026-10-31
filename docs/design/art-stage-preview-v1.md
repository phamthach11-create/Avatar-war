# Stage composition preview v1

Separate scene: res://src/ui/art_direction_preview.tscn. Main scene and combat implementation are unchanged.

Shows chosen Napoleon anime cel-shaded style1 on the chosen bright Stone Citadel A environment. Two image edits were produced using built-in image generation: transparent commander+cannon draft, and empty arena draft. Generated alpha was inspected (true RGBA transparency, not a checkerboard). Includes four Napoleon instances across two mirrored 3x3 teams; fourteen old units are deliberately temporary comparison figures. MAIN remains A5/B5.

Controls: size slider80-125%, only-Napoleon toggle, full-size closeup, return to existing combat test. Scene has no new shooting animation, VFX or combat state. Base scale is150px for the Napoleon group at1280x820; placeholders126px. Three lanes separated170px to reduce name/figure overlap. Texture filtering/mipmaps aid downscaling; shadow is drawn separately below the feet.

Runtime checks: exactly18 slots and4 Napoleon instances; mirrored arrangement; scale125%, solo mode showing4, closeup and rendered screenshots. Initial composition was revised after checking labels/row overlap. Not a finished character rig or layered environment; character and cannon are still one static image. Art direction needs user review before expanding into the Napoleon firing sample.

Assets: assets/art_direction/v1/napoleon_cel_draft.png and stone_citadel_draft.png. Source concepts and prompts remain in local conversation outputs. GitHub roadmap/handoff record progress; binaries and scene are not uploaded to repository yet.
