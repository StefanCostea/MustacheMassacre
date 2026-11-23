# Don Espino — detail and combat direction

Source of truth: `../../character_models/DON_ESPINO.fbx` and `../motivation/game_motivation.md`.

## Identity observed in the model

An elongated cylindrical cactus torso, very thin arms and exposed green shins, an oversized brown split-crown cowboy hat with a dark band and gold sheriff star, heavy brown brows, a large downward-swept brown moustache, ochre shorts and belt, small tan cowboy boots, a cigarette, a red-and-cream packet and a belt radio. The separate weapon is a silver revolver with a brown grip. Retain this tall, awkward, dead-serious silhouette; do not substitute a squat cactus mascot, poncho, bulky human torso or realistic cowboy.

The source contains 20 mesh objects, 99,068 vertices and 139,154 polygons, 26 materials, two armatures, and an imported animation action. No image textures are embedded. Several mirrored face components occupy identical positions in the Blender import and produce overlapping surfaces. The detail version reflects one member of each eye, brow and moustache pair to restore the intended bilateral face.

## Hero-detail model v3

The current native asset is `../../character_models/DON_ESPINO_hero_v3.blend`. Review its actual Cycles renders and the concept comparison in `../../renders/don_espino/v3/README.md`. V3 develops the concept's detail as geometry and procedural materials, and replaces the inherited animation binding with a compact articulated presentation skeleton. The original FBX and the earlier v2 scene remain preserved.

Two native combat scene studies accompany v3: `../../character_models/scenes/DON_ESPINO_ricochet_v3.blend` and `../../character_models/scenes/DON_ESPINO_high_noon_v3.blend`. These contain posed copies of the detailed character and editable geometry for effects. Ricochet Rodeo shows a three-enemy bounce chain; High Noon shows six target markers and the golden-wing Frenzy transformation. They are static pose studies, not a finished animation set or implemented gameplay.

## Earlier editable model pass: v2

`../../character_models/DON_ESPINO_detail_v2.blend` retains the source mesh shapes and imported rig data, repairs the overlapping face pieces, and adds a named detail collection. Changes include sparse surface-aligned cactus spine clusters and areoles, material-specific roughness and microtexture, directional grain on the moustache and revolver grip, hat-band and belt stitching, boot decoration, and small brass belt rivets.

The material system lives in Blender shader nodes. This is a presentation asset, not a new game-ready retopology, baked texture set or validated animation rig. Source FBX armature modifiers reference the metarig while many weights use generated-rig DEF names; resolving and validating that pre-existing binding is a separate rigging task. The loose revolver remains a separate prop and is hidden in character inspection renders. The original FBX is unchanged.

## Combat concepts

These are image-generated visual development paintings in the model's stylized 3D language. They are not posed Blender renders, exported meshes, animations, or implemented gameplay. Additional costume seams and action deformation in these images are concept suggestions.

| Image | Situation | Mechanic from the motivation plan | Readability priority |
| --- | --- | --- | --- |
| Character hero | Neutral studio, full body, revolver in hand | Furious Gunslinger starting character | Tall silhouette, brows, moustache and split-crown sheriff hat |
| Ricochet Rodeo | The Crispy Badlands, dusty saloon street | Precision six-shooter, fan-the-hammer upgrade, ricochets | A legible bullet path bouncing between enemies |
| Prickly Situation | Grease City, radioactive fast-food district | A critical-hit enemy bursts into needles that inherit ricochet | Needles originate at the defeated enemy, not the player's body |
| Tumbleweed of Doom | Funland Forever, possessed amusement park | Spinning tumbleweed sucks in enemies | A clear vortex, silhouettes pulled inward, player outside its center |
| High Noon + Frenzy | The Grand Grooming, fractured arena | Time dilation, six marked targets, precision shots; golden moustache wings during Frenzy | Don Espino remains visible beneath the golden wing silhouette |

## Priorities and interpretation

Use the final, character-specific High Noon ultimate and golden-wing Stache Frenzy in the roster section. The earlier flaming moustache from the sky is a general brainstorm, not the chosen Don Espino ultimate. Tumbleweed of Doom and Prickly Situation are upgrade-family concepts, not claims that the plan has finalized their input bindings. Effects should escalate from sharp gold muzzle flashes, through green needle chains and dusty vortices, to a brief golden ultimate spectacle. Keep threat silhouettes separate from bright effects. Don Espino stays stern; the enemies and escalation carry the joke.
