"""Prepare the four TRELLIS.2 enemy sculpts for the Godot design review.

Run in an isolated Blender process with --background --python-exit-code 1.
"""

import json
from math import cos, pi, radians, sin
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[2]
MODELS = {
    "fridge_bruiser": (1.58, 55000),
    "chili_bandit": (1.72, 18000),
    "pigeon_bomber": (1.35, 18000),
    "el_frigorifico": (2.60, 25000),
}
EXPORTS = ROOT / "game/assets/enemies/design_review"


def hardware_material(name, color, metallic):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = 0.52
    return material


def rear_condenser(body, height, sheriff):
    """Seat a continuous return pipe and two mounting rails on the inferred back."""
    width = height * (0.27 if sheriff else 0.35)
    low, high = (0.40, 0.63) if sheriff else (0.33, 0.72)
    top = height * high
    pitch = height * (high - low) / 6
    radius = height * 0.0085
    mounts = hardware_material("Condenser straps", (0.09, 0.071, 0.054), 0.60)
    copper = hardware_material("Aged copper" if sheriff else "Blackened copper",
                               (0.32, 0.12, 0.052) if sheriff else (0.115, 0.076, 0.060), 0.65)
    parts = []

    def mount_curve(name, path, thickness, clearance, material):
        curve = bpy.data.curves.new(name, "CURVE")
        curve.dimensions = "3D"
        curve.bevel_depth = thickness
        curve.bevel_resolution = 2
        curve.use_fill_caps = True
        line = curve.splines.new("POLY")
        line.points.add(len(path) - 1)
        for point, (x, z) in zip(line.points, path):
            hit, surface, _, _ = body.ray_cast((x, 2 * height, z), (0, -1, 0))
            if not hit:
                raise ValueError(f"Condenser mount misses {body.name} at {x}, {z}")
            point.co = (x, surface.y + clearance, z, 1)
        obj = bpy.data.objects.new(name, curve)
        bpy.context.collection.objects.link(obj)
        curve.materials.append(material)
        obj.parent = body
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.convert(target="MESH")
        for face in obj.data.polygons:
            face.use_smooth = True
        parts.append(obj)

    for side in (-1, 1):
        mount_curve("Condenser strap", [(side * width * 0.31, top - pitch * row / 4)
                                         for row in range(-1, 26)], radius * 1.32, radius * 0.4, mounts)
    path = []
    for row in range(7):
        side = 1 if row % 2 == 0 else -1
        z = top - pitch * row
        for i in range(11):
            path.append((side * width * (i / 10 - 0.5), z))
        if row < 6:
            for i in range(1, 10):
                angle = pi * i / 10
                path.append((side * (width + pitch * sin(angle)) / 2, z + pitch * (cos(angle) - 1) / 2))
    mount_curve("Condenser coil", path, radius, radius * 2.3, copper)
    return parts


def bandit_sidearm(body):
    library = ROOT / "desgin/character_models/refined/don_espino_natural_workflow/03_moustache_and_revolver.blend"
    # Load the project's textured prop mesh alone. Its local origin is at the grip.
    with bpy.data.libraries.load(str(library)) as (available, picked):
        assert "Cube.001" in available.meshes
        picked.meshes = ["Cube.001"]
    prop = bpy.data.objects.new("Bandit sidearm", picked.meshes[0])
    bpy.context.collection.objects.link(prop)
    prop.parent = body
    for vertex in prop.data.vertices:
        if vertex.co.y < -0.25:
            vertex.co.y = -0.25 + (vertex.co.y + 0.25) * 0.60
    prop.scale = (0.39, 0.39, 0.39)
    prop.rotation_euler = (radians(90), radians(12), radians(67))
    prop.location = (-0.225, 0.008, 0.661)
    return prop


def prepare(name, height, triangle_target, folder=None, exports=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    folder = folder or ROOT / "desgin/character_models/generated" / name / "v01"
    exports = exports or EXPORTS
    bpy.ops.import_scene.gltf(filepath=str(folder / "source.glb"))
    mesh, = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    mesh.name = name
    mesh.data.transform(mesh.matrix_world)
    mesh.parent = None
    mesh.matrix_world = Matrix.Identity(4)
    for obj in list(bpy.context.scene.objects):
        if obj != mesh:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    bounds = [Vector(corner) for corner in mesh.bound_box]
    center = (bounds[0] + bounds[6]) * 0.5
    bottom = min(c.z for c in bounds)
    scale = height / (max(c.z for c in bounds) - bottom)
    mesh.data.transform(Matrix.Scale(scale, 4) @ Matrix.Translation((-center.x, -center.y, -bottom)))
    source_area = sum(face.area for face in mesh.data.polygons)

    edit = bmesh.new()
    edit.from_mesh(mesh.data)
    bmesh.ops.remove_doubles(edit, verts=list(edit.verts), dist=1e-6)
    bmesh.ops.dissolve_degenerate(edit, edges=list(edit.edges), dist=1e-7)
    edit.to_mesh(mesh.data)
    edit.free()
    mesh.data.calc_loop_triangles()
    reduction = mesh.modifiers.new("Review mesh", "DECIMATE")
    reduction.ratio = min(1.0, triangle_target / len(mesh.data.loop_triangles))
    reduction.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=reduction.name)
    mesh.data.validate(clean_customdata=False)
    mesh.data.calc_loop_triangles()
    assert mesh.data.uv_layers and len(mesh.data.loop_triangles) > 0
    area_ratio = sum(face.area for face in mesh.data.polygons) / source_area
    if abs(area_ratio - 1.0) > 0.06:
        raise ValueError(f"{name} lost surface coverage during reduction ({area_ratio:.1%})")

    images = []
    for material in mesh.data.materials:
        material.name = name + "_surface"
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image and node.image not in images:
                images.append(node.image)
    assert len(images) == 2, f"{name} lost a PBR texture"
    for image in images:
        role = "color" if image.colorspace_settings.name == "sRGB" else "metal_rough"
        image.name = f"{name}_{role}"
        assert min(image.size) > 0
        if not image.packed_file:
            image.pack()
    parts = [mesh]
    if name in ("fridge_bruiser", "el_frigorifico"):
        parts.extend(rear_condenser(mesh, height, name == "el_frigorifico"))
    elif name == "chili_bandit":
        parts.append(bandit_sidearm(mesh))
    for part in parts:
        part.select_set(True)
        part.data.calc_loop_triangles()
    bpy.context.view_layer.objects.active = mesh
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(folder / "prepared.blend"), compress=True)
    exports.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(exports / (name + ".glb")), export_format="GLB",
        use_selection=True, export_animations=False, export_yup=True,
    )
    audit = {
        "blender": bpy.app.version_string,
        "height_m": height,
        "front_in_godot": "+Z",
        "body_surface_area_ratio": round(area_ratio, 4),
        "review_triangles": sum(len(part.data.loop_triangles) for part in parts),
        "textures": {image.name: list(image.size) for image in images},
    }
    (folder / "review-audit.json").write_text(json.dumps(audit, indent=2) + "\n")


if __name__ == "__main__":
    for model, (height_m, budget) in MODELS.items():
        prepare(model, height_m, budget)
