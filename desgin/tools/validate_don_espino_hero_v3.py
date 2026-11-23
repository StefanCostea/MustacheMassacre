from pathlib import Path
import bpy,math,json,hashlib
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'desgin/renders/don_espino/v3'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'desgin/character_models/DON_ESPINO_hero_v3.blend'))
rig=bpy.data.objects['Don Espino | articulated hero rig'];scene=bpy.context.scene
report={'model':'DON_ESPINO_hero_v3.blend','blender':bpy.app.version_string,'base_mesh_vertices':0,'base_mesh_polygons':0,'curve_control_points':0,'curve_splines':0,'invalid_coordinates':0,'invalid_bone_bindings':[],'weight_sum_errors':0,'bone_count':len(rig.data.bones),'felt_fibers':scene['felt_fibers'],'areole_clusters':scene['areole_clusters'],'image_texture_nodes':0,'external_image_files':[]}
for obj in scene.objects:
 if obj.parent_type=='BONE' and obj.parent_bone not in rig.data.bones:report['invalid_bone_bindings'].append(obj.name)
 if obj.type=='MESH':
  report['base_mesh_vertices']+=len(obj.data.vertices);report['base_mesh_polygons']+=len(obj.data.polygons)
  report['invalid_coordinates']+=sum(not all(math.isfinite(c) for c in v.co) for v in obj.data.vertices)
  if any(m.type=='ARMATURE' for m in obj.modifiers):
   report['weight_sum_errors']+=sum(abs(sum(g.weight for g in v.groups)-1)>.00001 for v in obj.data.vertices)
 if obj.type=='CURVE':
  report['curve_splines']+=len(obj.data.splines);report['curve_control_points']+=sum(len(s.points)+len(s.bezier_points) for s in obj.data.splines)
for m in bpy.data.materials:
 if m.use_nodes:report['image_texture_nodes']+=sum(n.type=='TEX_IMAGE' for n in m.node_tree.nodes)
for i in bpy.data.images:
 if i.source=='FILE':report['external_image_files'].append(i.filepath)
# Exercise the arm chain and verify the held prop follows its hand exactly.
hand=bpy.data.objects['Right gripping palm'];gun=bpy.data.objects['Hollow revolver barrel']
oldgun=gun.matrix_world.copy();relative=hand.matrix_world.inverted()@gun.matrix_world
pb=rig.pose.bones['forearm.R'];pb.rotation_mode='XYZ';pb.rotation_euler.x=.25;bpy.context.view_layer.update()
newrelative=hand.matrix_world.inverted()@gun.matrix_world
report['forearm_pose_test']={'weapon_motion':(gun.matrix_world.translation-oldgun.translation).length,'hand_weapon_relative_error':max(abs(a-b) for ra,rb in zip(relative,newrelative) for a,b in zip(ra,rb))}
pb.rotation_euler=(0,0,0);bpy.context.view_layer.update()
assert report['invalid_coordinates']==0
assert not report['invalid_bone_bindings']
assert report['weight_sum_errors']==0
assert report['forearm_pose_test']['weapon_motion']>.01
assert report['forearm_pose_test']['hand_weapon_relative_error']<.00001
assert report['image_texture_nodes']==0
source=ROOT/'desgin/character_models/DON_ESPINO.fbx'
ref=json.loads((ROOT/'desgin/renders/don_espino/reference/source_integrity.json').read_text())
report['original_fbx_unchanged']=hashlib.sha256(source.read_bytes()).hexdigest()==ref['sha256']
assert report['original_fbx_unchanged']
report['scope']='High-resolution editable presentation model and articulated rig. No production LOD, engine baking, or full animation library is claimed.'
(OUT/'validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2),flush=True)
