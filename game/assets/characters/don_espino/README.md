# Don Espino runtime asset

Derived from the preserved `desgin/character_models/DON_ESPINO_hero_v3.blend`. The original FBX, detailed master and earlier model versions are not replaced by this runtime export.

`don_espino.glb` contains 34,588 triangles in four material groups, a 25-joint skeleton, named `Muzzle`/`GunOrigin` sockets and twelve animation clips. `asset_manifest.json` records the per-group budgets and clip durations. Godot imports tangents, named skins and automatic LODs. `don_espino_lod.glb` is an additional reduced export for future distance use; the demo uses the main asset's imported LODs.

Atlases are base color, tangent-space normal, roughness and metallic. Organic, hat/hair and clothing groups use 2048-pixel maps; props use 1024-pixel maps. Color maps are sRGB; data maps are linear. The glTF export packs the material textures it needs. Loose PNGs are the editable bake outputs.

The low mesh retains silhouette spines and the moustache/hat forms. Dense areoles, seams, pores, fabric and surface wear are baked from the native source geometry and shaders. The original 70,000 individual felt fibers are excluded from the game asset. Joining the bake sources preserves their original object/generated coordinates as attributes, so material scale remains stable.

The rig uses authored FK clips. `AnimationTree` blends four movement directions and idle, then filters actions to the upper body. Aiming rotates the character independently of travel, and shooting originates at the animated muzzle socket. Death uses its full-body clip. The golden Frenzy whiskers are lightweight Godot meshes with a pulsing metallic shader.

Regenerate with the three `tools/build_runtime_espino.py` stages described in the project README. Working Blender files are saved under `build/asset_work/`. The pipeline never saves to the source master path.
