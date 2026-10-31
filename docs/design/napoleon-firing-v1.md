# Napoleon firing sample v1

Scene res://src/ui/napoleon_firing_preview.tscn, standalone Control presentation prototype. Keeps chosen anime1 style and commander height157.5px (approved105% reference). Existing combat/main scene is unchanged.

Four different commander key poses: idle, windup, command/fire, recovery. Generated atlas does not fit exact cells: final measured connected-subject regions/foot anchors in atlas.json prevent the outstretched hand being clipped or duplicated. Cannon carriage, wheels and barrel are separate draw layers; barrel slides and wheels rock on firing. Ballistic projectile, muzzle flash/smoke, eight-frame ground impact, embers, scorch, hurt pose and controllable world shake. Two original synthesized sound cues.

Normal sample: one projectile lands after travel and triggers hurt reaction at the Cross primary and four secondary recipients. This is a one-hit visual sample, not a reroll of live multi-hit/accuracy/crit. Barrage sample: three visual salvos, then applies a status indicator without direct damage; six DOT ticks are compressed in time for preview. No battle resource is changed. Targets are temporary old sprites, not approved designs for the remaining classes.

Controls: Normal, Barrage/DOT, pause/resume, 1x/0.5x, repeat, sound, shake, closeup zoom, back to 9vs9 composition. Starts with looping normal shot. Restarting either sample clears pending projectile/impact/target effect state.

Verification: rendered fire and impact frames; fixed-step timeline checks one normal fire/arrival, three barrage fires, six DOT ticks, reset cleanup. Scene opened in the primary Godot project after resource import. This is the first firing draft awaiting user review, not production rigging or final VFX. Assets/source/test are local; GitHub roadmap and handoff record status but binaries are not uploaded.
