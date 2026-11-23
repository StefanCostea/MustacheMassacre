---
name: environment-artist
description: Design, reconstruct with TRELLIS.2, prepare in Blender, and integrate Mustache Massacre scenery and inanimate props in Godot. Use for arena landmarks, terrain, vegetation, cover, destructibles, loose equipment, and ability props.
---

# Environment Artist

Start with the playable location. Read `game/scripts/arena.gd` and the caller that owns the object. Capture it with Don Espino from the game's camera. Record the silhouette, world-space dimensions, pivot and any movement, collision, aim, warning, or cover-fade behavior that the new art must support. [Game direction](../../../desgin/docs/motivation/game_motivation.md) · [Visual reference](../../../desgin/renders/don_espino/concepts/01_character_hero.png)

## Concept and reconstruction

Generate a polished three-quarter view of the complete object in the game's tactile cartoon Western style. Design for recognition at arena distance. A fuel drum needs a contrasting danger mark visible from above. Put craftsmanship into the secondary forms and material transitions. Reserve the brightest accents for things players act on.

Save the concept and prompt in a versioned folder under `desgin/renders/`. Inspect the image before submitting. A design board can establish a family of props. Isolate each object into its own square, check even the tips and handles, and keep open space between spokes, ladder rungs and branches. A user-supplied model can enter at mesh preparation.

For TRELLIS.2, query Runware's model list and schema, upload the individual reference, and save the request UUID before submitting. Reuse that UUID to check pending work. Keep each completed source GLB with its reference hash, task and output IDs, returned cost, and source hash under `desgin/prop_models/`. Verify the binary header, meshes and texture payload. The installed local uploader and exact Runware request fields are documented in the [Runware reference](../character-artist/references/runware-trellis.md). A continuous ground surface can use a generated top-down material with world-space tracks and wear.

## Prepare the real mesh

Inspect front, flank, rear and overhead in Blender or Godot. Single-view reconstructions can turn branches solid, mirror lettering, angle a rectangular foundation, or put the detailed face against a wall. Correct orientation before fitting exact cover dimensions. Use a ground-centred pivot for scenery and a centre-of-mass attachment for anything that rolls. Preserve UVs and paint, remove degenerate geometry, and reduce geometry and texture size according to screen footprint and repeat count. Keep the authoring source and a reproducible cleanup. [Badlands Blender build](../../../desgin/tools/prepare_badlands_props.py)

Export a static GLB with embedded maps. A trigger can animate the prop's existing transform for a fuse, impact or tumble. Give a moving part its own pivot only when the action calls for one. Tile geometry and textures at the asset level so repeated placements share resources.

## Integrate and review

Place the finished art in the normal playable scene. Use the existing simple gameplay colliders and navigation clearances. Check silhouette against collider at eye and muzzle height. Aim at destructibles, shoot them, watch the entire fuse and explosion, walk behind cover, and verify that the whole visible object fades. Keep lane dressing low and reserve larger silhouettes for the perimeter. Compare matched before/after frames at the normal camera and review at least one unhidden close view. For repeated scenery, measure the rendered stress scene and inspect a clean source import and exported launcher. Document the actual provider result and any authored corrections. [Badlands reference pack](../../../desgin/renders/badlands_props/v01/concepts)

Run the project checks with `./tools/run_demo.sh --headless --fixed-fps 60 -- --environment-test --natural-hero`. Capture the arrival, the arena at fixed angles, and a live encounter from the workspace root with the following command.

```sh
BADLANDS_ART_DIR=/tmp/badlands-review ./tools/run_demo.sh --resolution 1440x810 --fixed-fps 30 --script "$PWD/desgin/tools/review_badlands_environment.gd" -- --natural-hero
```

In this pack, reconstruction left the saloon open overhead and distorted its lettering. A fitted roof and locally typeset plaque corrected both. Inspect thin parts again after decimation, especially near the ground. For straw, rope and twigs, inspect the depth of the silhouette against a contrasting backdrop. Baked color alone can hide missing volume.
