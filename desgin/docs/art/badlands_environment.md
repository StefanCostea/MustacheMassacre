# The Crispy Badlands street

The Last Call saloon looks over a dusty fork in the wagon road. Turquoise paint links the tower, hitch rails and trough, oxblood marks the fuel drums, and worn canvas binds the hay stacks. The arrival camera opens wide enough to show the settlement, then moves into the regular combat view when the bell rings. [Matched before and after](../../renders/badlands_props/v01/comparison.jpg) · [Staged encounter with the arena AI](../../renders/badlands_props/v01/street_encounter.mp4)

| Set | Playable assets |
| --- | --- |
| Last Call | False-front saloon, freight wagon, feed sacks, hurricane lantern, bounty notice and arrival bell |
| Water and cover | Trestle water tower, riveted water trough, canvas-bound hay bales |
| Destructibles | Striped fuel drums and brass-bound citrus crates |
| Desert edge | Saguaro, sandstone mesa, agave and rock cluster, timber fence |
| Special attack | Rolling tumbleweed centred inside its vortex |

The 16 prop types use textured TRELLIS.2 geometry. The ground combines a generated top-down route painting with a finer hardpan material. The shader adds worn wheel ruts. Gravel uses one instanced mesh. The short-lived bandit projectile and cactus thorn use shared shaped meshes, and the speckled egg has a brass crown. [All sixteen models rendered in Godot](../../renders/badlands_props/v01/props.jpg) · [Gameplay camera](../../renders/badlands_props/v01/after/gameplay.png)

## Source and repairs

The first four concept sheets were separated into single-object references before reconstruction. Each source folder contains the original GLB, saved Runware request, and a result recording the paid job, seed, reference checksum and source checksum. Seventeen completed reconstructions cost $0.7142 in total according to Runware. [Concepts and prompts](../../renders/badlands_props/v01/concepts) · [Source models](../../prop_models/badlands)

The first straw reconstruction had holes through the bale faces. The shipped version uses a tightly pressed reference, raised straw fibres, and loose stems at the foot. The saloon needed a corrugated roof to close its open top, a chimney, and a legible enamel sign. The bounty notice uses the original illustrated print on its three-dimensional board. The crate's stray geometry below its base was removed. [Revised hay reference](../../renders/badlands_props/v02/concepts/hay_bales.png) · [Finished saloon](../../renders/badlands_props/v01/after/saloon.png)

## Rebuild and inspect

Run the Blender preparation from the workspace root. Its dimensions are in metres, with X as width, Y as depth and Z as height in Blender. Supply a prop name after `--` to rebuild a single asset.

```sh
blender -b -t 4 --python-exit-code 1 -P desgin/tools/prepare_badlands_props.py
./tools/run_demo.sh --headless --editor --import --quit
./tools/run_demo.sh --headless --fixed-fps 60 -- --environment-test --natural-hero
```

The playground uses simple collision volumes. The barrel and crate stay 1.4 m high throughout their life, and each cover piece fades as a unit when it obscures Don Espino. The environment test instantiates the arena and casts the tumbleweed, checks all 16 models, walks the player behind and beside each cover, and destroys both breakables. The 1080p stress scene uses 35 mixed enemies and recurring Frenzy on an RTX 3060 Laptop GPU. [Run measurements](../../../build/verification/badlands_environment.json) · [Stress capture](../../renders/badlands_props/v01/stress.jpg)
