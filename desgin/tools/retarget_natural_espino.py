"""Retarget Mixamo's WITHOUT-SKIN motion across its differing FBX rest pose.

Absolute evaluated bone motion is converted into the skinned rig's local basis.
Every bone/frame is checked after baking. Direct action copying is unsafe here.
Run again after additional raw clips arrive; existing baked clips are retained.
"""
import bpy,json,math
from pathlib import Path
from mathutils import Matrix,Vector

ROOT=Path('/home/stefancostea/Documents/MustacheMassacre')
OUT=ROOT/'desgin/character_models/refined/don_espino_natural_workflow'
rig=bpy.data.objects['Natural_Mixamo_Rig'];scene=bpy.context.scene
manifest=json.loads(rig.get('natural_retarget_manifest','{}'))
clips=[('idle','01_idle.fbx'),('walk','02_walk.fbx'),('run_forward','03_run_forward.fbx'),('shoot_source','04_shoot_source.fbx'),('run_backward','05_run_backward.fbx'),('strafe_left','06_strafe_left.fbx'),('strafe_right','07_strafe_right.fbx')]

def rotation_error(a,b):
    q=a.to_quaternion().normalized();p=b.to_quaternion().normalized()
    return math.degrees(2*math.acos(min(1,abs(q.dot(p)))))

for name,file in clips:
    path=OUT/'raw_mixamo'/file
    if name in manifest or not path.exists():continue
    before=set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(path))
    added=[o for o in bpy.data.objects if o not in before]
    source=next(o for o in added if o.type=='ARMATURE')
    raw_action=source.animation_data.action
    first,last=[int(round(x)) for x in raw_action.frame_range]
    names=[b.name for b in source.pose.bones]
    assert all(n in rig.pose.bones for n in names)
    rest_position=max(((rig.matrix_world@rig.data.bones[n].head_local)-(source.matrix_world@source.data.bones[n].head_local)).length for n in names)
    rest_rotation=max(rotation_error(rig.matrix_world@rig.data.bones[n].matrix_local,source.matrix_world@source.data.bones[n].matrix_local) for n in names)
    anchor=rig.matrix_world@rig.data.bones['mixamorig:Hips'].head_local
    cache=[]
    inverse=rig.matrix_world.inverted()
    for frame in range(first,last+1):
        scene.frame_set(frame);bpy.context.view_layer.update()
        hip=source.matrix_world@source.pose.bones['mixamorig:Hips'].head
        shift=Matrix.Translation(Vector((anchor.x-hip.x,anchor.y-hip.y,0)))
        cache.append((frame,{n:inverse@shift@source.matrix_world@source.pose.bones[n].matrix for n in names}))
    for obj in added:bpy.data.objects.remove(obj,do_unlink=True)
    if raw_action.users==0:bpy.data.actions.remove(raw_action)
    action=bpy.data.actions.new('Natural_baked_'+name);action.use_fake_user=True
    slot=action.slots.new(id_type='OBJECT',name=rig.name)
    rig.animation_data_create();rig.animation_data.action=action;rig.animation_data.action_slot=slot
    max_position=0;max_rotation=0
    for frame,desired in cache:
        scene.frame_set(frame)
        for bone in rig.pose.bones:
            bone.rotation_mode='QUATERNION'
            if bone.name not in desired:bone.matrix_basis=Matrix.Identity(4)
        for n,matrix in desired.items():
            bone=rig.pose.bones[n]
            if bone.parent:
                basis=bone.bone.convert_local_to_pose(matrix,bone.bone.matrix_local,parent_matrix=desired[bone.parent.name],parent_matrix_local=bone.parent.bone.matrix_local,invert=True)
            else:basis=bone.bone.convert_local_to_pose(matrix,bone.bone.matrix_local,invert=True)
            bone.matrix_basis=basis
        for bone in rig.pose.bones:
            bone.keyframe_insert('location',frame=frame,group=bone.name)
            bone.keyframe_insert('rotation_quaternion',frame=frame,group=bone.name)
            bone.keyframe_insert('scale',frame=frame,group=bone.name)
        bpy.context.view_layer.update()
        for n,matrix in desired.items():
            actual=rig.pose.bones[n].matrix
            max_position=max(max_position,(rig.matrix_world.to_3x3()@(actual.translation-matrix.translation)).length)
            max_rotation=max(max_rotation,rotation_error(actual,matrix))
    assert max_position<.0001,(name,max_position)
    assert max_rotation<.2,(name,max_rotation)
    manifest[name]={'action':action.name,'source_file':file,'frames':[first,last],'fps':30,'rest_position_mismatch_m':rest_position,'rest_rotation_mismatch_deg':rest_rotation,'baked_pose_max_position_error_m':max_position,'baked_pose_max_rotation_error_deg':max_rotation,'retarget':'evaluated absolute pose converted into skinned local rest basis; horizontal root motion removed'}
    action['provenance']=json.dumps(manifest[name])
    print('RETARGET',name,json.dumps(manifest[name]))

rig['natural_retarget_manifest']=json.dumps(manifest)
(OUT/'retarget_validation.json').write_text(json.dumps(manifest,indent=2)+'\n')
action=bpy.data.actions[manifest['idle']['action']];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
scene.render.fps=30;scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'05_motion_retargeted.blend'))
