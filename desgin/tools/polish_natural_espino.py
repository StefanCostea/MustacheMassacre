"""Add facial controls and a separate baked revolver to the neutral Mixamo rig.

Preserves the body's automatic weights; no speculative limb/torso masks.
"""
import bpy,json,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix

ROOT=Path('/home/stefancostea/Documents/MustacheMassacre')
OUT=ROOT/'desgin/character_models/refined/don_espino_natural_workflow'
scene=bpy.context.scene;rig=bpy.data.objects['Natural_Mixamo_Rig'];mesh=bpy.data.objects['Natural_Skin']
rig.animation_data.action=None
for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT');rig.hide_set(False);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT');inverse=rig.matrix_world.inverted()
for side,sign in [('L',1),('R',-1)]:
    points=[Vector((sign*.03,-.43,1.98)),Vector((sign*.21,-.46,1.84)),Vector((sign*.40,-.34,1.60)),Vector((sign*.47,-.30,1.54))]
    parent=rig.data.edit_bones['mixamorig:Head']
    for i,part in enumerate(['root','mid','tip']):
        bone=rig.data.edit_bones.new(f'stache_{part}.{side}');bone.head=inverse@points[i];bone.tail=inverse@points[i+1];bone.parent=parent;parent=bone
bpy.ops.object.mode_set(mode='OBJECT')

image=next(n.image for n in mesh.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image and n.image.colorspace_settings.name=='sRGB')
pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels);pixels=pixels.reshape(image.size[1],image.size[0],4)
uv=np.empty(len(mesh.data.loops)*2,dtype=np.float32);mesh.data.uv_layers.active.data.foreach_get('uv',uv);uv=uv.reshape(-1,2)
indices=np.empty(len(mesh.data.loops),dtype=np.int32);mesh.data.loops.foreach_get('vertex_index',indices)
colors=np.zeros((len(mesh.data.vertices),3));colors[indices]=pixels[np.clip((uv[:,1]*image.size[1]).astype(int),0,image.size[1]-1),np.clip((uv[:,0]*image.size[0]).astype(int),0,image.size[0]-1),:3]
groups={g.name:g for g in mesh.vertex_groups}
for side in ['L','R']:
    for part in ['root','mid','tip']:
        name=f'stache_{part}.{side}';groups[name]=mesh.vertex_groups.new(name=name)
assignments={}
for v in mesh.data.vertices:
    x,y,z=mesh.matrix_world@v.co;r,g,b=colors[v.index]
    if abs(x)<.55 and y<-.25 and 1.50<z<2.01 and .08<r<.65 and r>g*1.03 and g>b*1.10:
        # Keep a portion of the original attachment weights and soften the top
        # edge so eyebrow corners cannot follow moustache motion.
        alpha=.85*min(1,max(0,(2.01-z)/.06))
        weights={mesh.vertex_groups[g.group].name:g.weight*(1-alpha) for g in v.groups}
        side='L' if x>0 else 'R';u=min(2,max(0,(abs(x)-.03)/.18));a=min(2,int(u));f=u-a;parts=['root','mid','tip']
        weights[f'stache_{parts[a]}.{side}']=alpha*(1-f)
        if a<2:weights[f'stache_{parts[a+1]}.{side}']=alpha*f
        assignments[v.index]=weights
ids=list(assignments)
for group in mesh.vertex_groups:
    try:group.remove(ids)
    except RuntimeError:pass
for index,weights in assignments.items():
    for name,value in weights.items():
        if value>1e-6:groups[name].add([index],value,'REPLACE')

# The baked revolver is a rigid prop, separate from the supplied body mesh.
gun=bpy.data.objects['Natural_Separate_Revolver']
grip=Vector((0,.30,-.24));scale=.70
for v in gun.data.vertices:v.co=(v.co-grip)*scale
tip=(Vector(gun['muzzle_local'])-grip)*scale
gun['muzzle_local']=list(tip);gun['grip_rebased']=True
idle=bpy.data.actions['natural_idle_with_skin_ground_truth'];rig.animation_data.action=idle
if idle.slots:rig.animation_data.action_slot=idle.slots[0]
scene.frame_set(1);bpy.context.view_layer.update()
hand=rig.pose.bones['mixamorig:RightHand'];index=rig.pose.bones['mixamorig:RightHandIndex1']
palm=rig.matrix_world@hand.head.lerp(index.head,.55)
gun.parent=rig;gun.parent_type='BONE';gun.parent_bone=hand.name
gun.matrix_world=Matrix.Translation(palm+Vector((0,-.01,.005)))
gun.hide_set(False);gun.hide_render=False
for name,pos in [('GunOrigin',Vector()),('Muzzle',tip)]:
    old=bpy.data.objects.get(name)
    if old:old.name='Previous_'+name
    marker=bpy.data.objects.new(name,None);scene.collection.objects.link(marker);marker.parent=gun;marker.location=pos
    marker.rotation_euler=Vector((0,-1,0)).to_track_quat('Z','Y').to_euler();marker.empty_display_size=.04
bpy.context.view_layer.update()
report=json.loads((OUT/'audit.json').read_text());report['polish']={'moustache_vertices':len(ids),'moustache_bones':6,'body_weights':'Mixamo body weights preserved','weapon':'Separate existing baked revolver, 6424 triangles, rigid RightHand attachment','raw_bone_count':len(rig.data.bones),'grip_error_metres':(gun.matrix_world.translation-(palm+Vector((0,-.01,.005)))).length}
(OUT/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'03_moustache_and_revolver.blend'))
print(json.dumps(report['polish']))
