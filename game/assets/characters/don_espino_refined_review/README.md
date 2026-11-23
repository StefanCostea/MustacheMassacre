# Refined Don Espino — review only

`don_espino_review.glb` is the Blender/Mixamo pipeline pilot. It has five clips,
28 skin joints and six animated moustache bones. It imports and plays in Godot,
but **fails visual review** because of arm/prop stretching and leg deformation.

Open `game/scenes/refined_character_review.tscn` to inspect it. This is separate
from the active playable hero. Full provenance and findings are in
`desgin/character_models/refined/don_espino_workflow/README.md`.

Do not promote it to the playable hero until the neutral pose, topology,
deformations, weapon sockets and the complete gameplay animation contract pass
review. Generic pistol body motion and a moustache motion test do not replace
the authored reload, dash, abilities and golden-wing Frenzy.
