"""Import the source FBX and render neutral inspection views with Blender 4.5."""
from pathlib import Path
import json
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'desgin/renders/don_espino/reference'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(ROOT / 'desgin/character_models/DON_ESPINO.fbx'))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
report = {'objects': [], 'materials': [], 'images': []}
for o in bpy.context.scene.objects:
    report['objects'].append({'name': o.name, 'type': o.type, 'vertices': len(o.data.vertices) if o.type == 'MESH' else None, 'faces': len(o.data.polygons) if o.type == 'MESH' else None, 'dimensions': list(o.dimensions), 'location': list(o.location), 'materials': [m.name for m in o.data.materials] if o.type == 'MESH' else [], 'uv_layers': list(o.data.uv_layers.keys()) if o.type == 'MESH' else [], 'vertex_groups': list(o.vertex_groups.keys()) if o.type == 'MESH' else []})
for m in bpy.data.materials:
    report['materials'].append({'name': m.name, 'diffuse': list(m.diffuse_color), 'nodes': [{'name': n.name, 'type': n.type, 'image': n.image.name if n.type == 'TEX_IMAGE' and n.image else None} for n in m.node_tree.nodes] if m.use_nodes else []})
for im in bpy.data.images:
    report['images'].append({'name': im.name, 'path': im.filepath, 'size': list(im.size), 'packed': bool(im.packed_file)})
(OUT / 'source_inspection.json').write_text(json.dumps(report, indent=2))
print(json.dumps({'objects':[{k:v for k,v in o.items() if k != 'vertex_groups'} for o in report['objects']], 'materials':report['materials'], 'images':report['images']}, indent=2), flush=True)
# Normalize the imported model to 4 Blender units without altering source data.
points = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
scale = 4 / (hi.z - lo.z)
root = bpy.data.objects.new('DonEspino_ImportRoot', None)
bpy.context.collection.objects.link(root)
for o in list(bpy.context.scene.objects):
    if o != root and o.parent is None:
        o.parent = root
root.scale = (scale,) * 3
root.location = Vector((-(lo.x+hi.x)/2, -(lo.y+hi.y)/2, -lo.z)) * scale
bpy.context.view_layer.update()
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 1200
scene.render.resolution_y = 1200
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new('Neutral World')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.24,.26,.30,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .45
scene.view_settings.view_transform = 'AgX'
mat = bpy.data.materials.new('Neutral Floor')
mat.diffuse_color = (.14,.16,.19,1)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.025))
bpy.context.object.data.materials.append(mat)

def point_at(o, target):
    o.rotation_euler = (Vector(target) - o.location).to_track_quat('-Z','Y').to_euler()
for name, loc, power, size in [('Key',(-4,-6,8),1100,5),('Fill',(5,-2,5),800,4),('Rim',(1,5,7),1300,3)]:
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
    obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=loc;point_at(obj,(0,0,2))
data=bpy.data.cameras.new('Inspection Camera');cam=bpy.data.objects.new('Inspection Camera',data);scene.collection.objects.link(cam);scene.camera=cam
data.type='ORTHO';data.ortho_scale=5.5
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'source_inspection.blend'))
for name,loc in [('front',(0,-10,4)),('rear',(0,10,4)),('three_quarter',(7,-10,6)),('side',(10,0,4))]:
    cam.location=loc;point_at(cam,(0,0,2))
    scene.render.filepath=str(OUT / f'original_{name}.png')
    bpy.ops.render.render(write_still=True)
print('INSPECTION COMPLETE',flush=True)
