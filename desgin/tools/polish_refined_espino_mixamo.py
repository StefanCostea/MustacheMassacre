"""Blender MCP pilot polish of the actual Mixamo rig, preserving the source.

Run after importing 00_rig_original_pose.fbx and restoring source materials and
face orientation. Imported animation clips are applied separately.
"""
import bpy, math, json
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT=Path('/home/stefancostea/Documents/MustacheMassacre')
OUT=ROOT/'desgin/character_models/refined/don_espino_workflow'
rig=bpy.data.objects['DonEspino_Mixamo_Rig']
mesh=bpy.data.objects['DonEspino_Mixamo_Skin']
scene=bpy.context.scene
rig.animation_data_clear();scene.frame_set(1)
for bone in rig.pose.bones:
    bone.location=(0,0,0);bone.rotation_mode='QUATERNION'
    bone.rotation_quaternion=(1,0,0,0);bone.scale=(1,1,1)
bpy.context.view_layer.update()

bpy.ops.object.select_all(action='DESELECT');rig.hide_set(False);rig.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
inverse=rig.matrix_world.inverted()
for side,sign in [('L',1),('R',-1)]:
    points=[Vector((sign*.035,-.365,1.91)),Vector((sign*.22,-.39,1.83)),Vector((sign*.39,-.32,1.64)),Vector((sign*.48,-.29,1.55))]
    parent=rig.data.edit_bones['mixamorig:Head']
    for i,part in enumerate(['root','mid','tip']):
        name=f'stache_{part}.{side}'
        bone=rig.data.edit_bones.get(name) or rig.data.edit_bones.new(name)
        bone.head=inverse@points[i];bone.tail=inverse@points[i+1]
        bone.parent=parent;bone.use_connect=False;parent=bone
for name in ['mixamorig:HeadTop_End','mixamorig:LeftToe_End','mixamorig:RightToe_End']:
    rig.data.edit_bones[name].use_deform=False
bpy.ops.object.mode_set(mode='OBJECT')

image=bpy.data.images['Image_0']
pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels)
pixels=pixels.reshape(image.size[1],image.size[0],4)
uv=mesh.data.uv_layers.active.data
uvs=np.empty(len(uv)*2,dtype=np.float32);uv.foreach_get('uv',uvs);uvs=uvs.reshape(-1,2)
indices=np.empty(len(mesh.data.loops),dtype=np.int32);mesh.data.loops.foreach_get('vertex_index',indices)
cols=pixels[np.clip((uvs[:,1]*image.size[1]).astype(int),0,image.size[1]-1),np.clip((uvs[:,0]*image.size[0]).astype(int),0,image.size[0]-1),:3]
colors=np.zeros((len(mesh.data.vertices),3),dtype=np.float32);colors[indices]=cols

groups={g.name:g for g in mesh.vertex_groups}
for side in ['L','R']:
    for part in ['root','mid','tip']:
        name=f'stache_{part}.{side}'
        if name not in groups:groups[name]=mesh.vertex_groups.new(name=name)

def assign(v,weights):
    for old in list(v.groups):mesh.vertex_groups[old.group].remove([v.index])
    total=sum(weights.values())
    for name,value in weights.items():
        if value>1e-6:groups[name].add([v.index],value/total,'REPLACE')

counts={'moustache':0,'hat_face':0,'boots_legs':0,'weapon_hand':0,'radio':0}
for v in mesh.data.vertices:
    x,y,z=mesh.matrix_world@v.co
    r,g,b=colors[v.index]
    green=g>r*1.12 and g>b*1.08
    brown=r>g*1.10 and g>b*1.05
    if -.51<x<.54 and y<-.235 and 1.50<z<1.95 and brown:
        side='L' if x>0 else 'R';u=min(2,max(0,(abs(x)-.04)/.20))
        a=min(2,int(u));f=u-a;parts=['root','mid','tip']
        weights={f'stache_{parts[a]}.{side}':1-f}
        if a<2:weights[f'stache_{parts[a+1]}.{side}']=f
        assign(v,weights);counts['moustache']+=1
    elif z>1.95:
        assign(v,{'mixamorig:Head':1});counts['hat_face']+=1
    elif x<-.50 and y<.02 and .48<z<1.28:
        assign(v,{'mixamorig:RightHand':1});counts['weapon_hand']+=1
    elif .34<x<.73 and y<-.22 and .99<z<1.44 and not green:
        assign(v,{'mixamorig:Hips':1});counts['radio']+=1
    elif z<.88:
        side='Left' if x>.055 else 'Right'
        if z<.28:weights={f'mixamorig:{side}Foot':1}
        elif z<.42:
            t=(z-.28)/.14;weights={f'mixamorig:{side}Foot':1-t,f'mixamorig:{side}Leg':t}
        elif z<.52:weights={f'mixamorig:{side}Leg':1}
        elif z<.64:
            t=(z-.52)/.12;weights={f'mixamorig:{side}Leg':1-t,f'mixamorig:{side}UpLeg':t}
        elif z<.76:weights={f'mixamorig:{side}UpLeg':1}
        else:
            t=(z-.76)/.12;weights={f'mixamorig:{side}UpLeg':1-t,'mixamorig:Hips':t}
        assign(v,weights);counts['boots_legs']+=1

# Export sockets follow the actual gripped revolver, never the head weights.
hand=rig.pose.bones['mixamorig:RightHand']
gun=[mesh.matrix_world@v.co for v in mesh.data.vertices if v.co.x<-.55 and v.co.y<-.15 and .48<v.co.z<1.20]
grip=Vector((-.66,-.24,1.00))
tip=min(gun,key=lambda p:p.z) if gun else Vector((-.82,-.5,.65))
for name,pos in [('GunOrigin',grip),('Muzzle',tip)]:
    obj=bpy.data.objects.get(name) or bpy.data.objects.new(name,None)
    if not obj.users_collection:scene.collection.objects.link(obj)
    obj.parent=rig;obj.parent_type='BONE';obj.parent_bone=hand.name
    obj.matrix_world.translation=pos
    obj.empty_display_size=.05

report=json.loads((OUT/'audit.json').read_text())
report['polish_weights']=counts
report['rig_status']='Mixamo auto-rig succeeded on second marker placement; 25 original joints plus 6 authored moustache bones'
report['face_orientation_repaired']=8038
report['quality_status']='animation/deformation review pending; not accepted for main gameplay'
(OUT/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'05_weights_and_moustache.blend'))
print(json.dumps(counts))
