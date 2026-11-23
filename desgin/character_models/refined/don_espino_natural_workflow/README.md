# Don Espino Natural — gameplay-test candidate

Prepared 12 November 2026 using Blender 5.3 MCP, Mixamo MCP and Godot 4.7.2.
The neutral model now has a complete playable animation set. The previous hero
remains the default for comparison; this is not a claim of final art approval.

## Try it

Launch `build/releases/LastCall/play-natural.sh`, or from the source checkout:

```sh
./tools/run_natural_demo.sh
./tools/run_demo.sh res://scenes/natural_character_review.tscn
```

The viewer uses Left/Right to choose clips, Space to replay, A/D to turn and
Escape to exit. The arena keeps the existing WASD/mouse, Space, R, Q/E/F controls.

## Artifacts and provenance

- `DonEspinoNatural_animated.glb`: self-contained model with fifteen clips.
- `DonEspinoNatural_candidate.blend`: clean native handoff; one scene, ten
  objects including studio, packed textures, rig and all animations.
- `raw_mixamo/`: preserved local downloads; IDs/settings are recorded in
  `mixamo_clips.json` and `mixamo_directions.json`.
- `audit.json`, `retarget_validation.json`, `animation_manifest.json` and
  `export_validation.json`: measured counts, provenance and checks.
- `../../../renders/don_espino/natural_workflow/`: actual-model studio views,
  animation samples, Godot clip captures and staged arena ability shots.

The supplied `../DonEspinoNatural.glb` is unchanged, SHA256
`4db8c2827897a544efb922f1b6b3e59038ae004725d7fd92dc80219bdea06919`.
Its 279,291 triangles became a 59,950-triangle body with the two original 2048px
PBR textures preserved. The separate revolver reuses the existing baked project
weapon: 6,424 triangles. Total: **66,374 triangles, two materials, 74,088 exported
vertices including seams, five embedded images and 64 joints**. The GLB contains
no studio lights, camera or floor.

## Rig and animation

The open-handed A-pose rigged on the first marker attempt. Mixamo produced 57
bones, including four finger chains per hand. Marker placement used a temporary
browser fallback because the installed MCP does not expose that step; rig
mapping and motion downloads then used the MCP. Temporary browser data was
removed. Six moustache bones and a separate `weapon.R` control bring the total
to 64. Body/limb weights remain Mixamo's; the revolver is rigidly attached.

An important transfer bug was identified: without-skin motion FBXs and the
original/skinned FBXs have different rest matrices despite matching names.
Differences reach 0.94 m at fingertips and 119 degrees. This also contributed to
the previous pilot's bad deformation. `desgin/tools/retarget_natural_espino.py`
converts absolute evaluated source poses into the target's local rest basis with
`Bone.convert_local_to_pose`, then checks every bone/frame. Maximum position
error was **0.000022 m**, before intentional loop/floor and character polish.
Raw channels are never copied across the mismatching rest poses.

| Clips | Origin |
| --- | --- |
| idle, run_forward, run_backward, strafe_left, strafe_right | Mixamo body motion, retargeted with polished loops and moustache follow-through |
| shoot, reload, dash, hurt, death, cast, ultimate | Authored character actions over the retargeted ready pose |
| walk, shoot_source | Additional original Mixamo review motions |
| stache_frenzy | Authored moustache growth/motion test |

Seven source motions were downloaded at 30 FPS. Runtime shooting uses a short
authored recoil rather than the long behind-cover source clip. Casting uses a
baked two-bone reach with opening fingers; death is grounded against the actual
deformed mesh. Reload uses hand/moustache gestures and gun roll. An articulated
cylinder, finer trigger-finger contact and facial blendshapes remain further art
polish. Golden wings are the existing Godot Frenzy effect, aligned to the new
moustache height; the GLB itself includes the moustache motion and gun flourish.

A moving reference verified that Mixamo ID 128280901 travels +1.419 m on Blender
X. It maps to runtime `strafe_right` in the existing controller basis even though
Mixamo calls it left. ID 128290901 maps to runtime `strafe_left`.

## Checks and limits

Independent GLB checks pass: all twelve runtime clips plus three review clips,
six animated moustache bones, normalized four-influence weights, rigid prop
hierarchy and embedded textures. Loop endpoint errors are below 0.00006 and
timelines begin at zero. Godot renders all fifteen clips with one skeleton.

All **53 gameplay checks pass with the candidate**, including muzzle alignment,
actual hits, abilities, reload, death and retry/results. The default hero passes
the same checks. The rebuilt standalone executable was also checked in both
modes. All original source models and the default runtime GLB are preserved.

Arena captures stage invulnerability, charge and enemy health for art review;
they are not a normal balance run. A 1920×1080, 35-enemy Xvfb stress run measured
125 ms median / 137.829 ms p95; the default under the same conditions measured
128.571 / 137.819 ms. Both were slow in this isolated display environment, so
these results **do not establish native-display 60 FPS**. Both reports/logs are
under `build/natural_character_workflow/`; do not reuse the earlier native-display
benchmark as evidence for this model.

Recheck with `python3 tools/verify_natural_character.py`. Preparation, polish,
retargeting, action and export scripts are under `desgin/tools/*natural_espino*.py`.
The recurring workflow is `desgin/agents/character_artist.md`.
