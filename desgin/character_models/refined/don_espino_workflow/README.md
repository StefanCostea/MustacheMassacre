# Don Espino — Blender / Mixamo pipeline pilot

Tested 12 November 2026 with the connected Blender 5.3 MCP, Mixamo MCP,
a browser fallback for joint markers, and Godot 4.7.2.

**Result: the tool pipeline reaches animated GLB import and playback, but this
candidate fails visual quality review. It is not approved for gameplay.**

**Follow-up correction:** the neutral-model iteration identified a bind-pose
transfer error as an additional cause of this pilot's deformation. The original
pose rig and the Mixamo motion skeleton can have substantially different rest
matrices despite matching bone names. This pilot copied channels directly;
therefore its results do not isolate mesh/weight problems alone. Its quality
rejection remains valid, but the explanation below is incomplete without this
transfer issue. The neutral-model workflow now uses a matching skinned animation
base and checks every bone's rest matrix before reusing actions.

## Source and preparation

The supplied `../DonEspino.glb` is preserved byte for byte, SHA256
`6f0244b78e25b2397594ab5d080515b15e402e99fe416306f5a9459e22655606`.
It contains 290,497 triangles, one PBR material with embedded 2048×2048 color
and metallic/roughness textures, and no skeleton or animations.

The mesh was imported into a separate Blender scene. Welding UV duplicates and
removing degenerates produced a 290,049-triangle working mesh. The reduced,
validated candidate contains **59,939 triangles**. UV/normal splits produce
75,633 exported vertices; this is a review candidate, not a finished performance
optimization. `audit.json` records the topology, including remaining
nonmanifold edges. Merely reducing triangles does not produce deformation-ready
joint topology.

A spatial/color-mask attempt to straighten the arms stretched triangles between
the hand, hip/radio and revolver. It was rejected and isolated under `rejected/`.
`DonEspino_clean_pose_test.fbx` deliberately preserves the original pose for the
Mixamo feasibility test; it is **not an accepted neutral-pose export**.

Recalculating normals on this generated nonmanifold mesh also reversed faces.
8,038 face orientations on the rigged candidate were restored against the
untouched source. Future preparation should preserve source winding and compare
orientation before exporting, rather than assuming global recalculation is safe.

## Mixamo and Blender polish

The MCP uploaded the FBX and reached joint-marker placement. The installed
Mixamo MCP explicitly does not support markers. A temporary browser fallback
placed them and selected the No Fingers skeleton. The first rig attempt returned
to marker placement; correcting surface contacts produced a successful rig.
The original-pose rig was downloaded, then uploaded through the MCP as an
existing compatible skeleton. All four motion downloads subsequently completed
through the Mixamo MCP. Short UI timeouts required waiting for the selected
animation and retrying the already-open download panel.

Raw files remain in `raw_mixamo/`; `mixamo_clips.json` records IDs and settings.

| Clip | Mixamo ID | Source motion |
| --- | --- | --- |
| idle | 128210901 | Idle With Aimed Pistol |
| walk | 128250901 | Walking With An Aimed Pistol |
| run_forward | 128230901 | Running With A Pistol |
| shoot | 115050901 | Shooting A Pistol From Behind Cover |

These are generic base motions. They do not establish the quality of Don
Espino's final reload, dash, High Noon or other special attacks.

Blender polish restored source materials, repaired face orientation, attempted
rigid prop/boot bindings and leg weights, and added independent left/right
moustache root/mid/tip bones. Moustache follow-through and a `stache_frenzy` motion
test were authored and baked. The Frenzy test is not the complete golden-wing
ultimate. Horizontal root movement was removed; measured residual hip drift is
below 0.000001 metres. The export contains 28 skin joints, including six animated
moustache bones, normalized four-influence weights, and `Muzzle` / `GunOrigin`
sockets. The sockets still need weapon alignment acceptance after reconstruction.

## Quality review

The automatic weights and corrective pass **still produce stretched arm/weapon
and radio connections, poor leg bending, and unsuitable weapon presentation**.
Godot confirms these visible defects. Successful auto-rigging and valid GLB
structure are not quality acceptance. The existing playable hero remains
unchanged and its hash was checked against the previously tested asset.

The next art step is genuine separation/retopology of the fused contacts and a
proper neutral bind pose, followed by another rig and motion review. A cleaner
generated neutral body can also avoid these contacts at the source. The new
polished concept reference is
`../../../renders/don_espino/refined_workflow/07_neutral_pose_generation_reference.png`:
empty open hands, arms clear of torso, separated feet and no held gear. Generate
the body from that pose; preserve the revolver/radio as separately rigged props.
This reference is generated concept art, not proof that the current GLB has been
reconstructed.

## Review artifacts

- `01_source_audit.blend`: imported source and initial cleanup.
- `03_clean_pose_test.blend`: source/reduced comparison and studio.
- `06_animation_pilot_NOT_APPROVED.blend`: actual rig and five baked clips.
- `DonEspino_animation_pilot_NOT_APPROVED.glb`: isolated animated review export.
- `export_validation.json`: independent export checks and actual clip lengths.
- `../../../renders/don_espino/refined_workflow/`: actual Blender renders, sampled
  animation frames, Mixamo evidence, Godot captures and the separate generated
  neutral-pose reference/prompt.

Run from the workspace root:

```sh
python3 tools/verify_refined_character_pilot.py
./tools/run_demo.sh res://scenes/refined_character_review.tscn
```

In the review scene, Left/Right changes clips, Space replays, A/D turns the
character and Escape exits. The main scene and playable character are unchanged.
Godot imported and rendered all five clips with one skeleton. The Xvfb capture
log contains benign XIM/DRI3 notices, but no gameplay script/import errors.

The reusable agent brief is `desgin/agents/character_artist.md`, linked from root
`AGENTS.md`. Review the quality gate before continuing this pilot or replacing
any runtime asset.
