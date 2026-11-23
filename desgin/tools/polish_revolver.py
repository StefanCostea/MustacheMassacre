from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
model=ROOT/'desgin/character_models/DON_ESPINO_detail_v2.blend'
OUT=ROOT/'desgin/renders/don_espino'
bpy.ops.wm.open_mainfile(filepath=str(model))
for name,depth in [('pistola',.00035),('casquillo',.00035),('Material.008',.002)]:
    for n in bpy.data.materials[name].node_tree.nodes:
        if n.type=='BUMP':n.inputs['Distance'].default_value=depth
bpy.ops.wm.save_as_mainfile(filepath=str(model))
scene=bpy.context.scene;gun=bpy.data.objects['Cube.019'];gun.hide_render=False
for o in scene.objects:
    if o.type in ['MESH','CURVE'] and o not in [gun,bpy.data.objects['Plane']]:o.hide_render=True
points=[gun.matrix_world@v.co for v in gun.data.vertices];center=sum(points,Vector())/len(points)
cam=scene.camera;cam.location=center+Vector((.2,-4,1.7));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=1.3
scene.cycles.samples=24
scene.render.filepath=str(OUT/'05_original_revolver_detail.png')
bpy.ops.render.render(write_still=True)
