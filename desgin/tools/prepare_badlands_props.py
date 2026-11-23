"""Rebuild the street's static GLBs from the saved TRELLIS.2 source meshes in Blender.

blender -b -t 4 -P desgin/tools/prepare_badlands_props.py [-- saloon ...]
Dimensions below are width, depth and height in Blender metres.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import badlands_prop_finishes as finish

SOURCE = ROOT / "desgin/prop_models/badlands/v01"
DEST = ROOT / "game/assets/environment/props"

# Base mesh budgets reflect screen size and repeat count. Each reconstruction has two packed maps.
PROPS = {
    "saloon": ((9.45, 5.4, 5.05), 27000, 2048),
    "water_tower": ((3.8, 3.6, 6.0), 19000, 1024),
    "wagon": ((2.2, 3.25, 1.75), 14000, 1024),
    "bell": ((.78, .64, 1.24), 6500, 1024),
    "fuel_drum": ((.82, .82, 1.40), 4200, 1024),
    "citrus_crates": ((.88, .88, 1.40), 4900, 1024),
    "hay_bales": ((3, 2, 1.80), 8200, 1024),
    "trough": ((3, 1.2, 1.80), 9300, 1024),
    "saguaro": ((1.62, 1.25, 2.58), 8200, 1024),
    "mesa": ((6.4, 4.8, 3.1), 4400, 1024),
    "fence": ((2.0, .25, 1.14), 2600, 512),
    "agave_rocks": ((1.48, 1.15, .78), 2400, 512),
    "lantern": ((.32, .32, .53), 3800, 512),
    "tumbleweed": ((1.02, .94, .96), 6800, 1024),
    "sacks": ((1.08, .86, .98), 3700, 1024),
    "wanted": ((.76, .09, .92), 2600, 1024),
}

# Free-form and cylindrical shapes keep the concept's presentation.
RECTANGULAR = {"saloon", "citrus_crates", "trough", "hay_bales", "wagon", "fence", "wanted", "bell", "water_tower"}
DEPTH_LONG = {"wagon"}


def bounds(mesh):
    low = Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
    high = Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])
    return low, high


def square_to_axes(mesh, name):
    """Recover the street axes from the surface-area weighted vertical walls."""
    if name not in RECTANGULAR:
        return
    real = imag = 0.0
    for face in mesh.polygons:
        normal = face.normal
        if abs(normal.z) > .50:
            continue
        angle = 4 * math.atan2(normal.y, normal.x)
        real += math.cos(angle) * face.area
        imag += math.sin(angle) * face.area
    mesh.transform(Matrix.Rotation(-math.atan2(imag, real) / 4, 4, "Z"))
    low, high = bounds(mesh)
    size = high - low
    if name in {"saloon","trough","hay_bales","fence","wanted","wagon"}:
        if (size.x < size.y) != (name in DEPTH_LONG):
            mesh.transform(Matrix.Rotation(math.pi / 2, 4, "Z"))


def prepare(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str((SOURCE.parent / "v02" if name == "hay_bales" else SOURCE) / name / "source.glb"))
    obj, = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    mesh = obj.data
    mesh.transform(obj.matrix_world)
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
    for other in list(bpy.context.scene.objects):
        if other != obj:
            bpy.data.objects.remove(other, do_unlink=True)
    obj.name = name
    mesh.name = name + "_mesh"
    square_to_axes(mesh, name)
    target, budget, tex_size = PROPS[name]
    low, high = bounds(mesh)
    size = high - low
    center = (low + high) / 2
    center.z = low.z
    mesh.transform(Matrix.Diagonal(Vector([*(target[i]/size[i] for i in range(3)), 1])) @ Matrix.Translation(-center))

    edit = bmesh.new()
    edit.from_mesh(mesh)
    bmesh.ops.remove_doubles(edit, verts=list(edit.verts), dist=.000002)
    bmesh.ops.dissolve_degenerate(edit, edges=list(edit.edges), dist=.000001)
    edit.to_mesh(mesh)
    edit.free()
    mesh.calc_loop_triangles()
    initial = len(mesh.loop_triangles)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    mod = obj.modifiers.new("Gameplay reduction", "DECIMATE")
    mod.ratio = min(1, budget / initial)
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mesh.calc_loop_triangles()
    assert len(mesh.uv_layers) and 0 < len(mesh.loop_triangles), name
    if len(mesh.loop_triangles) > 1.2 * budget:
        print(f"{name}: preserving disconnected components at {len(mesh.loop_triangles)} triangles", flush=True)
    # Collapsing thin shell components can introduce long spikes beyond the fixed collider.
    low_limit = Vector((-target[0]*.505, -target[1]*.505, -.005))
    high_limit = Vector((target[0]*.505, target[1]*.505, target[2]*1.005))
    damaged = bmesh.new()
    damaged.from_mesh(mesh)
    outside = [v for v in damaged.verts if any(v.co[i] < low_limit[i]-.03 or v.co[i] > high_limit[i]+.03 for i in range(3))]
    if outside:
        bmesh.ops.delete(damaged, geom=outside, context="VERTS")
        damaged.to_mesh(mesh)
    damaged.free()
    for mat in mesh.materials:
        mat.name = name + "_patina"
        for node in mat.node_tree.nodes:
            if node.type != "TEX_IMAGE" or not node.image:
                continue
            image = node.image
            role = "albedo" if image.colorspace_settings.name == "sRGB" else "orm"
            image.name = name + "_" + role
            if max(image.size) > tex_size:
                image.scale(tex_size, tex_size)
                image.pack()
    if name == "hay_bales":
        finish.straw(obj)
        finish.shed_straw()
    if name == "saloon":
        finish.saloon(ROOT)
    if name == "wanted":
        finish.wanted(ROOT)
    bpy.ops.object.select_all(action="SELECT")
    DEST.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(DEST / (name+".glb")), export_format="GLB",
                              use_selection=True, export_animations=False, export_yup=True,
                              export_image_format="WEBP", export_image_quality=91)
    print("PREPARED", name, initial, len(mesh.loop_triangles), flush=True)


if __name__ == "__main__":
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else PROPS
    for slug in names:
        prepare(slug)
