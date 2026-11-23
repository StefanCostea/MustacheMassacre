"""Finish a runtime-compatible action set over validated Mixamo body motion."""
import bpy,math,json,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion

ROOT=Path('/home/stefancostea/Documents/MustacheMassacre')
OUT=ROOT/'desgin/character_models/refined/don_espino_natural_workflow'
rig=bpy.data.objects['Natural_Mixamo_Rig'];skin=bpy.data.objects['Natural_Skin'];gun=bpy.data.objects['Natural_Separate_Revolver'];scene=bpy.context.scene
manifest=json.loads(rig['natural_retarget_manifest'])
actions={name:bpy.data.actions[data['action']] for name,data in manifest.items()}
required_moves={'idle','run_forward','run_backward','strafe_left','strafe_right'}
assert required_moves<=actions.keys()

def bind(action):
    rig.animation_data.action=action
    if action.slots:rig.animation_data.action_slot=action.slots[0]

bind(actions['idle']);scene.frame_set(1);bpy.context.view_layer.update()
gun_world=gun.matrix_world.copy()
if 'weapon.R' not in rig.data.bones:
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    hand=rig.data.edit_bones['mixamorig:RightHand'];finger=rig.data.edit_bones['mixamorig:RightHandIndex1']
    bone=rig.data.edit_bones.new('weapon.R');bone.head=hand.head.lerp(finger.head,.55);bone.tail=bone.head+Vector((0,0,10));bone.parent=hand
    bpy.ops.object.mode_set(mode='OBJECT')
gun.parent_bone='weapon.R';gun.matrix_world=gun_world;bpy.context.view_layer.update()
scene.render.fps=30

def key_all(frame):
    for b in rig.pose.bones:
        b.keyframe_insert('location',frame=frame,group=b.name)
        b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
        b.keyframe_insert('scale',frame=frame,group=b.name)

def rotate_world(name,axis,angle):
    b=rig.pose.bones[name];world=rig.matrix_world@b.matrix;p=world.translation
    rotation=Quaternion(Vector(axis),angle).to_matrix().to_4x4()
    b.matrix=rig.matrix_world.inverted()@Matrix.Translation(p)@rotation@Matrix.Translation(-p)@world
    bpy.context.view_layer.update()

def point_bone(name,old_direction,new_direction):
    b=rig.pose.bones[name];world=rig.matrix_world@b.matrix;p=world.translation
    rotation=old_direction.normalized().rotation_difference(new_direction.normalized()).to_matrix().to_4x4()
    b.matrix=rig.matrix_world.inverted()@Matrix.Translation(p)@rotation@Matrix.Translation(-p)@world
    bpy.context.view_layer.update()

def reach_left_hand(amount):
    # Analytic two-bone IK, baked into FK keys; no runtime constraints required.
    shoulder=rig.matrix_world@rig.pose.bones['mixamorig:LeftArm'].head
    elbow=rig.matrix_world@rig.pose.bones['mixamorig:LeftForeArm'].head
    hand=rig.matrix_world@rig.pose.bones['mixamorig:LeftHand'].head
    a=(elbow-shoulder).length;b=(hand-elbow).length
    target=hand.lerp(shoulder+Vector((.40,-.48,.28)),amount)
    direction=(target-shoulder).normalized();distance=min((target-shoulder).length,(a+b)*.985)
    target=shoulder+direction*distance
    pole=Vector((1,0,0));pole=(pole-direction*pole.dot(direction)).normalized()
    cosine=max(-1,min(1,(a*a+distance*distance-b*b)/(2*a*distance)))
    desired_elbow=shoulder+direction*(a*cosine)+pole*(a*math.sqrt(max(0,1-cosine*cosine)))
    point_bone('mixamorig:LeftArm',elbow-shoulder,desired_elbow-shoulder)
    elbow=rig.matrix_world@rig.pose.bones['mixamorig:LeftForeArm'].head
    hand=rig.matrix_world@rig.pose.bones['mixamorig:LeftHand'].head
    point_bone('mixamorig:LeftForeArm',hand-elbow,target-elbow)

def decorate(name,t):
    wave=math.sin(t*math.tau)
    for side,sign in [('L',1),('R',-1)]:
        for i,part in enumerate(['root','mid','tip']):
            b=rig.pose.bones[f'stache_{part}.{side}'];b.rotation_mode='QUATERNION'
            amplitude=math.radians(1.5 if name=='idle' else 3)
            value=amplitude*math.sin(t*math.tau-i*.35)
            if name=='shoot':value=math.radians(6)*math.sin(math.pi*t)*math.exp(-t*2)*(1+i*.2)
            if name=='reload':value=math.radians(9)*math.sin(math.pi*t)*(1+i*.2)
            if name in ['ultimate','stache_frenzy']:value=math.radians(10)*math.sin(math.pi*t)*math.sin(t*math.tau*2-i*.3)
            b.rotation_quaternion=Quaternion(Vector((1,0,0)),value)@Quaternion(Vector((0,0,1)),sign*value*.25)
            growth=1+.30*math.sin(math.pi*t)**2 if name in ['ultimate','stache_frenzy'] else 1
            b.scale=Vector((1,growth,1))

loop_clips=required_moves|{'walk'}
for name,action in actions.items():
    bind(action);first,last=map(int,action.frame_range)
    scene.frame_set(first);bpy.context.view_layer.update()
    first_pose={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
    for frame in range(first,last+1):
        scene.frame_set(frame);t=(frame-first)/max(1,last-first)
        if name in loop_clips and frame>=last-1:
            blend=(frame-(last-2))/2
            for b in rig.pose.bones:
                a=b.matrix_basis;ref=first_pose[b.name]
                loc=a.translation.lerp(ref.translation,blend)
                quat=a.to_quaternion().slerp(ref.to_quaternion(),blend)
                scale=a.to_scale().lerp(ref.to_scale(),blend)
                b.matrix_basis=Matrix.LocRotScale(loc,quat,scale)
        rig.pose.bones['weapon.R'].matrix_basis=Matrix.Identity(4)
        decorate(name,t);key_all(frame)

bind(actions['idle']);scene.frame_set(1);bpy.context.view_layer.update()
base={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
authored={'shoot':.24,'reload':1.2,'dash':.22,'hurt':.30,'death':.85,'cast':.55,'ultimate':1.1,'stache_frenzy':2.0}
for name,duration in authored.items():
    action=bpy.data.actions.new('Natural_authored_'+name);action.use_fake_user=True
    slot=action.slots.new(id_type='OBJECT',name=rig.name);rig.animation_data.action=action;rig.animation_data.action_slot=slot
    frames=max(3,round(duration*30))
    for f in range(frames+1):
        frame=f+1;t=f/frames;envelope=math.sin(math.pi*t)
        scene.frame_set(frame)
        for b in rig.pose.bones:b.matrix_basis=base[b.name].copy()
        bpy.context.view_layer.update()
        if name=='shoot':
            kick=envelope*math.exp(-t*2)
            rotate_world('mixamorig:RightForeArm',(1,0,0),-.16*kick)
            rotate_world('weapon.R',(1,0,0),-.08*kick)
            rotate_world('mixamorig:Spine2',(1,0,0),-.025*kick)
        elif name=='reload':
            rotate_world('mixamorig:RightArm',(1,0,0),.28*envelope)
            rotate_world('mixamorig:RightForeArm',(0,0,1),.22*envelope)
            rotate_world('weapon.R',(0,1,0),.50*envelope)
            rotate_world('mixamorig:LeftForeArm',(1,0,0),-.25*envelope)
            for b in rig.pose.bones:
                if b.name.startswith('mixamorig:LeftHand') and b.name!='mixamorig:LeftHand':b.rotation_quaternion=b.rotation_quaternion.slerp(Quaternion(),envelope*.7)
        elif name=='dash':
            rotate_world('mixamorig:Spine2',(1,0,0),.20*envelope)
            rotate_world('mixamorig:Hips',(1,0,0),.10*envelope)
        elif name=='hurt':
            rotate_world('mixamorig:Spine2',(1,0,0),-.13*envelope)
            rotate_world('mixamorig:Head',(0,1,0),.09*envelope)
        elif name=='cast':
            reach_left_hand(envelope)
            for b in rig.pose.bones:
                if b.name.startswith('mixamorig:LeftHand') and b.name!='mixamorig:LeftHand':b.rotation_quaternion=b.rotation_quaternion.slerp(Quaternion(),envelope)
        elif name=='ultimate':
            rotate_world('mixamorig:RightArm',(0,0,1),-.55*envelope)
            rotate_world('mixamorig:RightForeArm',(1,0,0),-.85*envelope)
            rotate_world('mixamorig:Head',(0,0,1),.10*math.sin(t*math.tau))
        elif name=='death':
            eased=min(1,t*1.35);eased=eased*eased*(3-2*eased)
            rotate_world('mixamorig:Hips',(0,1,0),-1.50*eased)
            # Ground the actual deformed mesh while the cactus falls sideways.
            dg=bpy.context.evaluated_depsgraph_get();evaluated=skin.evaluated_get(dg);data=evaluated.to_mesh()
            coords=np.empty(len(data.vertices)*3,dtype=np.float32);data.vertices.foreach_get('co',coords);coords=coords.reshape(-1,3)
            row=np.array(skin.matrix_world[2]);minimum=float((coords@row[:3]+row[3]).min());evaluated.to_mesh_clear()
            hips=rig.pose.bones['mixamorig:Hips'];world=rig.matrix_world@hips.matrix;world.translation.z+=.008-minimum
            hips.matrix=rig.matrix_world.inverted()@world;bpy.context.view_layer.update()
        decorate(name,t);key_all(frame)
    action['provenance']='Authored character-specific action over the correctly retargeted Mixamo idle pose; moustache and weapon controls baked'
    actions[name]=action

# Preserve explicit animation provenance and a complete runtime contract.
core=required_moves|{'shoot','reload','dash','hurt','death','cast','ultimate'}
assert len(core)==12 and core<=actions.keys()
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for name,action in actions.items():
    track=rig.animation_data.nla_tracks.new();track.name=name
    track.strips.new(name,int(action.frame_range[0]),action);track.mute=True
bind(actions['idle']);scene.frame_start=1;scene.frame_end=int(actions['idle'].frame_range[1]);scene.frame_set(1)
rig['natural_final_actions']=json.dumps({k:a.name for k,a in actions.items()})
report={'runtime_contract':sorted(core),'clips':{name:{'action':a.name,'frames':list(a.frame_range),'seconds':(a.frame_range[1]-a.frame_range[0])/30,'origin':'Mixamo with world-space retarget and authored moustache follow-through' if name in manifest else 'authored on retargeted Mixamo idle'} for name,a in actions.items()},'bone_count':len(rig.data.bones),'weapon_attachment':'separate rigid revolver parented to weapon.R below RightHand; animated independently during recoil/reload'}
(OUT/'animation_manifest.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'06_complete_animation_set.blend'))
print(json.dumps(report))
