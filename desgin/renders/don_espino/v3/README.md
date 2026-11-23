# Don Espino — editable hero-detail model

[Open the Blender model](../../../character_models/DON_ESPINO_hero_v3.blend)

The five inspection images below are Cycles renders of this saved Blender scene. Two additional combat images render posed copies of the same model in editable Blender scenes. The asset contains editable geometry, curves, procedural materials, studio lights and an articulated presentation rig. The concept image is used as a visual reference; it is not placed in the scene or used as a texture.

## Actual model and reference

| Actual Blender render | Hero concept reference |
| --- | --- |
| ![Actual Blender model](01_actual_blender_hero.png) | ![Hero reference](../concepts/01_character_hero.png) |

The rebuild retains the original cactus torso, distinctive split-crown hat and boot silhouettes, with substantial sculpting and surface refinement. The facial hair, shorts, belt, limbs, hands, revolver and accessories are rebuilt or developed to carry the hero image's detail in three dimensions.

## Modeled detail

- Curved moustache lobes with mesh-level longitudinal grooves, finer brow channels and directional chestnut shading.
- A clean cactus surface with sculpted ribs, pores, corky areoles and tapered ivory spines.
- 70,000 short felt fibers on the hat, a leather band with sewn edges, and a faceted brass sheriff badge.
- Tailored canvas shorts with separate leg openings, cloth folds, fly, pocket seams, rolled hems and visible fabric weave.
- A separate leather belt, perimeter stitching, adjustment holes, belt loops and an open brass buckle with a prong.
- Rebuilt rounded boot uppers with leather grain, toe wear, ankle creases, shaft seams, collar stitching, toe embroidery, raised welts, layered soles, heels and pull tabs.
- A silver six-shot revolver with an open frame, fluted cylinder, hollow barrel, separate trigger and guard, hammer, sights, grip panels, checkering, screws and decorative engraving.
- Posed cactus limbs, knee forms, rounded fingers gripping the revolver, and a hand resting on the radio.
- A compact armature with named bones, weighted torso/limbs, and attached hands, clothing, accessories and weapon.

## Close-ups and rear view

![Face, hair and hat](02_actual_face_and_hat.png)

![Clothing and boots](03_actual_clothing_and_boots.png)

![Hand and revolver](04_actual_hand_and_revolver.png)

![Rear view](05_actual_rear.png)

## Actual Blender combat scenes

These are native static pose studies, including editable bone poses and modeled effects. They are not gameplay captures or completed attack animations.

**Ricochet Rodeo:** the raised revolver fires a connected bounce chain through three moustached refrigerator enemies in the Badlands, following the upgrade in the motivation plan.

[Open the Ricochet Blender scene](../../../character_models/scenes/DON_ESPINO_ricochet_v3.blend)

![Actual Ricochet Rodeo render](06_actual_ricochet_rodeo.png)

**High Noon during Stache Frenzy:** six target markers accompany the precision shot; the moustache grows into swept golden gunslinger wings, following the character-specific transformation described later in the plan.

[Open the High Noon Blender scene](../../../character_models/scenes/DON_ESPINO_high_noon_v3.blend)

![Actual High Noon and Frenzy render](07_actual_high_noon_frenzy.png)

## Validation and scope

[Validation results](validation.json) record the geometry, curve and bone counts, finite-coordinate checks, complete skin weights, valid bone attachments and a forearm motion test. The test verifies that the hand and revolver preserve their relative alignment during articulation. The original FBX checksum is also checked.

[Combat scene validation](combat_validation.json) reopens both saved scenes and checks their bone attachments, saved pose actions and alignment between the barrel and the first shot.

This is a high-resolution presentation model with an articulated rig. It is not an engine-optimized LOD set, baked game-texture package or completed animation library. Materials and fine curves are editable inside Blender; export to a game engine requires an appropriate baking and optimization pass.

The reference is a generated image, so this model is a three-dimensional interpretation rather than a pixel-identical reconstruction. Lighting, pose and camera can be adjusted in the Blender scene.

## Reproduction

From the project root, using Blender 4.5:

```sh
blender -b -t 8 --python desgin/tools/build_don_espino_hero_v3.py
blender -b -t 8 --python desgin/tools/render_don_espino_hero_v3.py
blender -b -t 8 --python desgin/tools/render_don_espino_combat_v3.py
blender -b -t 4 --python desgin/tools/validate_don_espino_hero_v3.py
blender -b -t 4 --python desgin/tools/validate_don_espino_combat_v3.py
```

The builder uses the preserved v2 scene as the source for the original torso, hat, brows and boots. All new geometry and shaders are generated locally. The renderer uses OptiX when available and falls back to CPU rendering otherwise.
