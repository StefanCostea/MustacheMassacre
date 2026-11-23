# Don Espino motion study

The November 17 pass tests a one-handed shooting stance, a seven-frame recoil and a moustache-assisted reload. The base is the natural character candidate. Blender 5.3.0 ran the pass through the live MCP in a separate scene. The legs in the five travel clips use the existing retargeted Mixamo takes. The new stance, arm poses, contact targets, curl motion and cylinder action were authored in Blender. Mixamo was signed out during this pass.

## Review

Open the side-by-side viewer from the workspace root.

```sh
./tools/run_demo.sh res://scenes/espino_motion_study.tscn
```

The previous pass is on the left and the study is on the right. Left and Right select nine revised clips. From idle, press Left once to see the fall on both models. A and D rotate both figures. Space restarts the motion.

```sh
./tools/run_demo.sh -- --espino-motion-study
```

This runs the source arena with the study. The editable file is `DonEspino_motion_study.blend`. The four-second Godot comparison is `desgin/renders/don_espino/motion_study/espino_comparison.webp`. The export at `game/assets/characters/don_espino_motion_study/don_espino_study.glb` carries all fifteen actions. The original Mixamo cover-shot reference is retained. The carry polish uses the saved Mixamo travel takes and new Blender arm animation. The carry pass also adjusts arm poses around the special actions. The packaged release still contains the previous candidate.

## What to look for

- The ready pose spreads the boots, lifts the hat brim and gives the shooting elbow a clear silhouette. The new arm carriage carries through walk, run, reverse and both strafes.
- While walking, the barrel travels roughly 33–49 degrees below level. In the forward run it travels roughly 24–50 degrees below level. The free arm counter-swings with the opposite boot and the wrist follows the forearm. At discharge, the right arm comes level and recoils while the left continues its gait. Repeated shots keep the arm raised. After the last shot, it eases back into the carry. Compare the prior and revised hands in `desgin/renders/don_espino/motion_study/carry_comparison.webp`.
- Over the 1.2-second reload, the wrist brings the revolver to the right curl. The cylinder moves out, spins twice and seats. Its original chamber faces and end plates move with it. The exported mesh totals 66,374 triangles with a dedicated 65th joint.
- The death clip starts from the revised idle. His gun hand recoils, the rear boot takes a short step, and the lead knee buckles. The belt drops first. The free hand braces on the floor, then the shoulders roll back, the trailing boot kicks and the moustache settles. The 0.97-second Blender-authored clip finished before the results screen in a lethal-hit test from a moving strafe. A 60 Hz sampling of the deformed body, gun and cylinder checked floor clearance through the fall. The original fall is on the left in the viewer. A Godot motion comparison is saved at `desgin/renders/don_espino/motion_study/death_comparison.webp`.
- The study passed 58 source combat checks, including firing twice during a strafe, recoil, off-hand swing, and return to carry. The default hero passed its 53 checks. An additional moving reload in Godot confirmed the cylinder rotates while strafing, returns to its starting offset and restores all six rounds.

Further performance work includes a boot plant and push-off that follow the dash direction, a distinct Tumbleweed release silhouette, and a held High Noon pose timed against the first shot. Judge each at arena scale, including transitions while moving. Precise finger contacts and travel foot sliding still need review.
