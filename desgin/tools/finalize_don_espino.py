"""Check and finalize the detailed presentation model and its review renders."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'desgin/renders/don_espino'
model=ROOT/'desgin/character_models/DON_ESPINO_detail_v2.blend'
bpy.ops.wm.open_mainfile(filepath=str(model))
hat=bpy.data.objects['Cube.001'];inv=hat.matrix_world.inverted();removed=0
for o in list(bpy.data.objects):
    if not o.name.startswith('Hat band saddle stitch'):continue
    p=o.matrix_world@Vector(o.data.splines[0].points[0].co[:3]);a=math.atan2(p.y,p.x)
    origin=Vector((2*math.cos(a),2*math.sin(a),p.z));direction=Vector((-math.cos(a),-math.sin(a),0))
    hit,local,n,i=hat.ray_cast(inv@origin,(inv.to_3x3()@direction).normalized())
    if not hit or hat.data.materials[hat.data.polygons[i].material_index].name!='CINTASOBRERO':
        bpy.data.objects.remove(o,do_unlink=True);removed+=1
scene=bpy.context.scene
report={'blender':bpy.app.version_string,'mesh_objects':len([o for o in scene.objects if o.type=='MESH']),'curve_detail_objects':len([o for o in scene.objects if o.type=='CURVE']),'spines':scene.get('spine_count'),'image_dependencies':len(bpy.data.images),'nonfinite_vertices':0,'overlap_pairs':{},'material_nodes':{m.name:len(m.node_tree.nodes) for m in bpy.data.materials if m.use_nodes},'rig_validation':'not animation-validated; source binding limitations documented','removed_off_band_stitches':removed}
for o in scene.objects:
    if o.type=='MESH':
        report['nonfinite_vertices']+=sum(not all(math.isfinite(c) for c in v.co) for v in o.data.vertices)
for a,b in [('Cube.004','Cube.005'),('Cube.002','Cube.003'),('Cube.006','Cube.007')]:
    ca=sum((bpy.data.objects[a].matrix_world@v.co for v in bpy.data.objects[a].data.vertices),Vector())/len(bpy.data.objects[a].data.vertices)
    cb=sum((bpy.data.objects[b].matrix_world@v.co for v in bpy.data.objects[b].data.vertices),Vector())/len(bpy.data.objects[b].data.vertices)
    report['overlap_pairs'][a+' / '+b]={'centroid_separation':(ca-cb).length,'mirrored_x_error':abs(ca.x+cb.x)}
assert report['nonfinite_vertices']==0
assert all(v['centroid_separation']>.1 for v in report['overlap_pairs'].values())
bpy.ops.wm.save_as_mainfile(filepath=str(model))
(OUT/'model_validation.json').write_text(json.dumps(report,indent=2))
cam=scene.camera
for name,loc,scale,target in [('01_model_detail_three_quarter',(5,-11,5),5.4,(0,0,2.02)),('02_model_detail_front',(0,-12,3.4),5.35,(0,0,2.02)),('03_model_detail_closeup',(3,-10,4.9),2.8,(0,-.05,2.94))]:
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
    scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
print(json.dumps(report,indent=2),flush=True)
