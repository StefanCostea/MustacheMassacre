# County art pass

The cast and scenery sheets in this folder were generated against the Don Espino art direction. Each isolated crop went through Runware TRELLIS.2 at 1024 with 2048 textures. The model folders retain the submitted render hash, task UUID, service result, unedited GLB and Blender audit.

The five new enemy models are Mustard Sniper, Ticket Puppet, Shaving Brush Guard, Bumper Car and His Royal Flushness. Each has seven embedded Blender clips for idle, movement, windup, attack, recovery, hurt and death. The Head Fry Cook uses the existing animated skillet outlaw with a chef's hat. The royal boss's flood and bumper-car collisions are driven by gameplay. Blender MCP connected to the existing Don Espino motion-study scene. Preparation and animation ran in separate Blender 5.3 batch sessions to preserve that scene. Mixamo reported a signed-out session. The new motions are authored in Blender.

The truck, ticket booth, exhaust plant, barber garage and palace facade use textured reconstructions. The Ferris wheel has a rotating rim and twelve individually hung cabins. The navigation mesh, grates, flood, signs, lights, bridges and interactive valves belong to the Godot county scene.

Rebuild a model with `blender -b --python-exit-code 1 --python desgin/tools/prepare_county_cast.py -- puppet`, substituting its asset name. Check the regions from the gameplay camera with the following command.

```sh
COUNTY_FRAMES=/tmp/county-review ./tools/run_demo.sh --rendering-method gl_compatibility --fixed-fps 60 --script "$PWD/desgin/tools/review_county.gd" -- --natural-hero
```
