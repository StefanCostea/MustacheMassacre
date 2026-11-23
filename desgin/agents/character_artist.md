# Character Artist agent

Use this guide when asked to run the Character Artist agent or prepare a game
character. Use Astra with image generation, Runware MCP, Blender MCP, Mixamo MCP
and the local Godot project for validation.
This is a persistent workspace agent brief, discovered through root `AGENTS.md`.

## Ownership and visual direction

1. Read `desgin/docs/motivation/game_motivation.md` and inspect the established
   concept render at `desgin/renders/don_espino/concepts/01_character_hero.png`.
2. For each new high-quality character request, produce and show a polished
   generated concept image first: clear full-body silhouette, detailed cartoon
   surfaces, neutral studio lighting, readable costume, exaggerated moustache.
   Additional views can guide the artist during mesh review.
3. For a requested new model, generate a single neutral image of the same
   character, submit it to TRELLIS.2 through Runware, and save the source GLB.
   A request for concept art alone ends with the render. An existing supplied
   TRELLIS.2 or Leonardo.Ai asset proceeds directly to the Blender audit.
   [Runware and TRELLIS.2 workflow](../../.agents/skills/character-artist/references/runware-trellis.md)
4. Preserve original models, textures, source hashes and the currently working
   game asset. Work in a versioned sibling directory. Show renders of the actual
   mesh separately from generated concept art; never claim they are equivalent
   without comparison.

## Pipeline

| Stage | Owner / tool | Required output |
| --- | --- | --- |
| Concept and model generation | Character Artist with image generation and Runware TRELLIS.2, or user-supplied asset | Concept and neutral input render for generated models, original GLB/FBX, provenance |
| Mesh and pose preparation | Astra + Blender MCP | Audited source, cleaned working blend, neutral-pose FBX with textures |
| Humanoid rig and motion | Mixamo MCP | Rigged mesh FBX; idle, walking, running and relevant attack FBXs |
| Character polish | Astra + Blender MCP | Corrected weights, moustache bones, polished clips, GLB, native blend |
| Gameplay acceptance | Godot | Import report, animation previews, deformation checks and gameplay test |

### Blender preparation

- Begin with MCP addon status and scene info. Preserve the user's open scene;
  use a separate scene or working file. Inspect front, side, back and close-ups.
- Record source hash, scale, axes, bounds, triangles, materials, textures, UVs,
  existing rigs/animations, disconnected islands and topology problems.
- Clean duplicates/degenerates carefully; preserve UVs, silhouette, face, hat,
  moustache, fingers, boots and props. Generated triangular topology is not
  automatically suitable for bending joints.
- Prepare a relaxed symmetric A/T pose, fingers apart, arms clear of torso,
  feet separated. Detach rigid weapon/radio/hat parts where needed. Do not force
  a posed fused mesh into a neutral pose with destructive global rotation.
- Prefer a neutral-pose concept as the **input to generation**, not just a
  heroic action pose. The pilot reference is
  `desgin/renders/don_espino/refined_workflow/07_neutral_pose_generation_reference.png`.
  A hand fused to the hip/radio or a gripped weapon needs genuine separation and
  deformation cleanup; spatial/color masks alone failed the Don Espino pilot.
- Use measured reduction and comparison renders. A starting desktop hero budget
  is 30–60k triangles, with a higher-detail source retained. Adjust based on
  silhouette, deformation and measured Godot performance; do not treat budget as
  permission to lose detail. Bake detail to textures when needed.
- Export selected neutral mesh as FBX, apply scale, preserve materials and
  texture files, and record orientation/unit settings. Verify by reimport.

### Mixamo

- Inspect session status. Upload the prepared FBX and check the actual character
  shown. Place chin, wrist, elbow, knee and groin markers accurately if required.
  Inspect auto-rig review before confirming. Stylized proportions can fail;
  record the failure and improve the neutral mesh rather than claiming success.
- Use the available MCP tools for supported actions. If marker placement needs
  UI access the MCP does not expose, state that limitation and use an available
  browser fallback, or request the specific manual step. Keep completed work.
- Download the rig once **with skin**; subsequent clips **without skin**, same
  character, FBX, 30 FPS. Prefer in-place locomotion for the CharacterBody3D
  controller. Preserve raw downloads and animation names/IDs/settings.
- Use the **T-pose/skinned animation bind pose** as the animation base. An
  "Original Pose" download may have different rest matrices from the motion
  FBXs even when bone names and hip positions agree. Before assigning actions,
  compare every bone's world rest position and orientation. The neutral Don
  Espino pilot exposed a 0.61 m wrist difference and 108-degree hand rest
  rotation. Direct channel copying across that mismatch causes false limb and
  weapon deformation. Use a matching skinned bind export, or explicitly retarget
  and bake across rest poses. Even a skinned animation FBX can retain the original
  bind while its animation curves compensate for it; a without-skin FBX can
  instead use the T-pose rest skeleton. The validated neutral-model solution is
  `desgin/tools/retarget_natural_espino.py`: sample absolute source bone matrices,
  use `Bone.convert_local_to_pose(..., invert=True)` for the target basis, bake,
  and check every bone/frame. Its maximum position error was below 0.00003 m.
  Never infer compatibility from names alone or copy the raw channels blindly.
- Minimum pilot: idle, walk, run, pistol attack. Then cover the runtime contract:
  `idle`, `run_forward`, `run_backward`, `strafe_left`, `strafe_right`, `shoot`,
  `reload`, `dash`, `hurt`, `death`, `cast`, `ultimate`.
- Select actions appropriate for a serious revolver gunslinger: crisp recoil,
  stylish reload, fast evasive dash, Tumbleweed cast and High Noon/Frenzy.
  Record which clips come from Mixamo and which are edited or authored.

### Blender rig and animation polish

- Import the rig and clips; keep one deform skeleton and compatible rest pose.
  Check shoulders, elbows, wrists, hips, knees and feet at extreme poses. Repair
  weights and rigid-part bindings; eliminate weapon drift and torso collapse.
- Add independent left/right moustache root, mid and tip bones, attached to the
  head. Keep the hat and face coherent; prevent neighbouring skin from being
  pulled by moustache bones. Add subtle follow-through in locomotion, stronger
  recoil/action response, and an authored Frenzy extension/wing treatment.
- Bake constraints and procedural motion into exportable actions. Give clips
  clear names, trim lengths, consistent loop endpoints and grounded feet.
  Preserve independent movement/aiming and upper-body action blending.
- Provide named `Muzzle` and `GunOrigin` sockets with correct forward axes.
  Preserve original PBR textures and color spaces; avoid double metallic or
  brightness corrections. Export a self-contained GLB without studio cameras
  or lights. Reimport and compare animation count, materials and skin weights.

For a character feature that transforms, use the visible source geometry in the morph. Give the camera a beat on the resting silhouette. Check the root, halfway pose, fully open form and reverse transition on each playable rig. Don Espino’s actual moustache lobes form the leading edges of his High Noon wings. The vanes open after the lobes uncurl. [In-game sequence](../renders/don_espino/high_noon/high_noon.mp4)

### Carry, grip and action transitions

- Establish the resting carry, action contact and recovery as distinct poses. For Don Espino, the revolver hangs low at idle, swings with travel, comes level at discharge, then recoils. Use the prop's actual forward axis to measure its angle. His grip and muzzle sockets sit at different heights, so the line between them gives a misleading barrel pitch.
- When polishing an existing gait, scrub one full stride from the prop side and the free-hand side. Plot each wrist relative to its own shoulder. A hand can travel across the screen with the pelvis while remaining frozen beside the torso. Use the actual foot contacts of each clip to phase the opposing arms. Backpedals and side steps can have different lead feet and travel axes. Sample wrapped frames for wrist lag so the loop closes.
- Carry the rigid prop with the gripping hand. Shape the swing at the shoulder and elbow and let the wrist follow through. On the free side, check forearm-to-palm alignment, thumb direction and the progression of finger curl through both extremes. Check the deformed hand and prop around the belt, legs and costume. Sample enlarged accessories at their greatest reach. Espino’s Frenzy curl needed more room than his normal moustache.
- Check the first attack from motion and a second attack at normal cadence in the game. Apply the firing pose before reading the socket for the flash or trace. Inspect the arm mask and the rotation inherited from locomotion. For Espino’s one-handed shot the free arm keeps its stride while the gun arm compensates for the moving chest. His reload uses both arms. Blend back to the carry after the last round. [Playable firing layer](../../game/scripts/espino_fire_pose.gd)
- Preserve approved contact frames when changing the resting pose. Blend the entrance and exit around the contact, then check it again in motion. Espino’s reload still needs the cylinder at the moustache and his fall still needs the free hand at the floor. Compare against the immediately preceding pass at the same camera angle, speed and stride phase. [Blender authoring script](../tools/author_espino_motion_study.py)

### Godot and visual review

- Initially import into a separate review directory/scene. Keep the active
  playable asset until the candidate meets the existing animation/socket
  contract and passes deformation and gameplay review.
- Render actual-mesh front/back/three-quarter comparisons and sampled motion
  strips or videos for idle, walk, run and attacks. Review silhouette, face,
  moustache, feet, joints and prop contacts at full size and gameplay scale.
- Check GLB axes/scale, texture import, skeleton, normalized weights, named
  clips, loops, sockets and AnimationTree blending. Test locomotion while aiming
  and firing, dash, reload, abilities, Frenzy, death and retry. Measure frame
  cost in the existing arena before replacing the current character.
- Save a concise status report with artifacts, provenance, measured counts,
  completed checks, quality problems and next steps. Separate prepared,
  rigged, animated, reviewed and gameplay-ready states. A successful export
  alone does not establish animation quality.

## Pilot input

The current source is `desgin/character_models/refined/DonEspinoNatural.glb`.
Its output is `desgin/character_models/refined/don_espino_natural_workflow/`,
with renders in `desgin/renders/don_espino/natural_workflow/` and the Godot
review scene `game/scenes/natural_character_review.tscn`. It has a separate
revolver and the complete twelve-clip runtime contract. Use `--natural-hero`
to test it in the arena; the default hero remains available for comparison.

`desgin/character_models/refined/DonEspino.glb` is the user's refined Don Espino.
Pilot work belongs under `desgin/character_models/refined/don_espino_workflow/`,
with actual renders under `desgin/renders/don_espino/refined_workflow/` and review
assets under `game/assets/characters/don_espino_refined_review/`.

The current animation review is the motion study. Use
`./tools/run_demo.sh res://scenes/espino_motion_study.tscn` for clips and
`./tools/run_demo.sh -- --espino-motion-study` for the source arena. [Motion study handoff](../character_models/refined/don_espino_motion_study/README.md)
