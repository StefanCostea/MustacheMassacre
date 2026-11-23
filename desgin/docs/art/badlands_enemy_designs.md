# The Crispy Badlands enemy designs

The arena and the review gallery use the same four animated models. El Frigorífico opens the shutters on his chest before he fires the ice fan. During his charge he leans into the player with the vent mostly closed, giving the two attacks different silhouettes. [Animation reel](../../renders/badlands_enemies/v03/enemy_motion.mp4) · [Sheriff close-up](../../renders/badlands_enemies/v02/sheriff_detail.png) · [Ice release](../../renders/badlands_enemies/v02/ice_fan.png)

```sh
./tools/run_demo.sh res://scenes/badlands_enemy_review.tscn
```

Press **1–4** to inspect an enemy or **0** for the lineup. Use **←/→** to select and repeat an animation, **Space** to toggle automatic cycling, **A/D** to turn, and **Tab** for the arena camera angle. **B** cycles through the animated model, previous sculpt and original prototype at the same angle. In the Linux release, run `./play.sh -- --enemy-gallery`. [Previous lineup](../../renders/badlands_enemies/v02/lineup.png) · [Previous sheriff at the same angle](../../renders/badlands_enemies/v02/sheriff_previous.png)

## Playable animation

| Enemy | What to watch | Triangles | Bones | Clips |
| --- | --- | ---: | ---: | ---: |
| Fridge Bruiser | The door swings out in the charge. When defeated he rocks onto one boot, strikes the ground on his side and the open door rebounds. | 61,831 | 7 | 7 |
| Chili Bandit | Flexible knees, a turning chest and fitted leather gloves give the sidearm a low carry and a separate firing silhouette. He strides, backpedals or sidesteps to match his movement. His knees give way on defeat and his stem folds as he rolls onto his side. | 26,657 | 21 | 10 |
| Pigeon Bomber | The bird springs off the ground, tucks its feet and banks in flight. The loaded foot swings forward. Its striped egg separates, tumbles and bursts on impact. A defeated pigeon loses a wingbeat, drops to the surface underneath and skids. | 17,997 | 13 | 8 |
| El Frigorífico | Four frosted shutters expose his fan before the ice attack. His legs buckle in two beats on defeat, the cabinet twists onto its back corner and the gauge and shutters settle. | 48,177 | 13 | 10 |

The pigeon cruises 1.95 metres above its spawn level. Its movement, collision capsule and attack socket rise together. The camera ray picks the airborne body for the revolver, and cover still obstructs the shot. The egg in the talon and the projectile use the same mesh. The gallery shows its flight and shell fragments. In the arena the enemy AI picks the target and the explosion applies damage. [Staged encounter using the arena AI](../../renders/badlands_enemies/v03/bombing_run.mp4) · [Egg in flight](../../renders/badlands_enemies/v03/bombing_run.png)

The bandit's two-segment arm and leg poses keep its weapon in the grip and distinguish a planted boot from the passing foot. Each enemy has its own impact frame and resting pose. The boss results screen waits for his fall. [Four death sequences in Godot](../../renders/badlands_enemies/v03/death_review.jpg) · [Gallery reel](../../renders/badlands_enemies/v03/enemy_motion.mp4)

The Linux build passed 112 enemy-animation checks, 53 combat checks and three restart cycles. The checks include crossing the central trough in flight, shooting a flier through the normal cursor and revolver path, egg handoff and damage, directional steps, and death timing. A full automated run reached victory. [Verification report](../../../build/verification/badlands_enemies.json)

All 35 clips are Blender-authored. Blender MCP reported Blender 5.3.0 and Mixamo reported a signed-out session. The v03 native rigs and GLBs are beside the preserved v02 sources. The sheriff's detail maps still come from v02. [Editable character files](../../character_models/generated) · [Blender choreography](../../tools/badlands_performance.py) · [Godot controller](../../../game/scripts/badlands_enemy_motion.gd)

To rebuild the current rigs from the v01 prepared meshes and existing v02 sheriff maps, run these commands from the workspace root. A character directory name after `--` limits Blender to that character. Copy the reviewed GLBs into the project before importing.

```sh
blender -b --factory-startup -t 4 --python-exit-code 1 --python desgin/tools/badlands_performance.py
cp desgin/character_models/generated/*/v03/*.glb game/assets/enemies/animated/
./tools/run_demo.sh --headless --import
./tools/run_demo.sh --headless --fixed-fps 60 -- --enemy-animation-test
```

## Original sculpts

| Enemy | Design and combat cue | Review triangles including props | Artwork |
| --- | --- | ---: | --- |
| Fridge Bruiser | Mint enamel, compressor boots and a black moustache make a squat charging block. The broad latch and exposed hinges identify the striking door. A blackened copper condenser breaks up the rear panel. | 57,933 | [Concept](../../renders/fridge_bruiser/concepts/v01/character.png) · [Godot](../../renders/badlands_enemies/v01/fridge_bruiser.png) |
| Chili Bandit | A crooked pepper stem and narrow straw brim carry the silhouette above cover. An ivory neckerchief separates the face from the red body. A compact sidearm rides in the low holster as a separate mesh for the draw. | 24,417 | [Concept](../../renders/chili_bandit/concepts/v01/character.png) · [Godot](../../renders/badlands_enemies/v01/chili_bandit.png) |
| Pigeon Bomber | Broad slate wings, a russet flight cap and a short, heavy body distinguish the flier. Two pale speckled eggs sit outside the dark harness where the player can see the payload. | 17,997 | [Concept](../../renders/pigeon_bomber/concepts/v01/character.png) · [Godot](../../renders/badlands_enemies/v01/pigeon_bomber.png) |
| El Frigorífico | The oversized cream sheriff hat rises above the other enemies. Silver moustache tips extend beyond the indigo cabinet, frost collects on the front fan vent, and a copper coil identifies the appliance from behind. | 27,899 | [Concept](../../renders/el_frigorifico/concepts/v01/character.png) · [Godot](../../renders/badlands_enemies/v01/el_frigorifico.png) |

## Source and review

The built-in image generator used Don Espino's hero portrait as the style reference. The exact prompts are beside each concept. The neutral single-character compositions also served as the model inputs. Each Runware request used `microsoft:trellis-2@4b` at 1024 resolution with 2048 textures. The four reported charges total **$0.1295**.

Each character's version directory contains its original GLB, editable Blender file, input hash, request, provider result and mesh audits. Blender preserved the body texture maps, fitted both condensers to the rear surfaces and adapted the project's existing revolver for the bandit's holster. The bruiser needed a higher triangle budget to retain its cabinet and door. [Sources and receipts](../../character_models/generated) · [Blender preparation](../../tools/prepare_badlands_enemy_designs.py)

The v01 renders document the initial static design review in Godot Forward+. Fine scratches, moustache strands and feather details were softer in the reconstructed meshes than in the concepts. These views record the state before articulation and sheriff detailing. [First lineup](../../renders/badlands_enemies/v01/lineup.png) · [Rear view](../../renders/badlands_enemies/v01/back.png) · [Arena scale](../../renders/badlands_enemies/v01/arena_angle.png)


## Skillet Outlaw and Repair Appliance

The Skillet Outlaw carries his face on his armored front. Walk around him while he turns or shoot during his post-charge recovery. The Repair Appliance points a brass nozzle at a wounded fridge for a short teal weld. A revolver hit interrupts the repair. Both use generated concept art, Runware TRELLIS.2 geometry, a Blender-authored skeleton and seven authored gameplay clips. Mixamo was signed out for this pass. Open the enemy gallery and press **5** or **6** to review the clips. [Skillet concept](../../renders/skillet_outlaw/concepts/v01/neutral.png) · [Repair concept](../../renders/repair_appliance/concepts/v01/neutral.png) · [Gameplay weld](../../renders/badlands_expansion/weld.jpg)
