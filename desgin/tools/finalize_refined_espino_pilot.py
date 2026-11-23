"""Bake/export the Mixamo pilot for isolated review, never the active hero."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector

ROOT=Path('/home/stefancostea/Documents/MustacheMassacre')
OUT=ROOT/'desgin/character_models/refined/don_espino_workflow'
rig=bpy.data.objects['DonEspino_Mixamo_Rig'];mesh=bpy.data.objects['DonEspino_Mixamo_Skin']
scene=bpy.context.scene;scene.render.fps=30
actions={'walk':bpy.data.actions['walk']}
for name,file in [('idle','01_idle.fbx'),('run_forward','03_run_forward.fbx'),('shoot','04_shoot.fbx')]:
    before=set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(OUT/'raw_mixamo'/file))
    added=[o for o in bpy.data.objects if o not in before]
    imported=next(o for o in added if o.type=='ARMATURE')
    action=imported.animation_data.action.copy();action.name=name;actions[name]=action
    for obj in added:bpy.data.objects.remove(obj,do_unlink=True)

def bind(action):
    rig.animation_data_create();rig.animation_data.action=action
    if action.slots:rig.animation_data.action_slot=action.slots[0]
    for bone in rig.pose.bones:
        if bone.name.startswith('stache_'):
            bone.rotation_mode='XYZ';bone.rotation_euler=(0,0,0);bone.scale=(1,1,1)

durations={};motion={}
for name,action in actions.items():
    bind(action)
    first,last=map(lambda x:int(round(x)),action.frame_range)
    hips=rig.pose.bones['mixamorig:Hips']
    anchor=rig.matrix_world@hips.bone.head_local
    to_local=(rig.matrix_world.to_3x3()@hips.bone.matrix_local.to_3x3()).inverted()
    samples=[]
    for frame in range(first,last+1):
        scene.frame_set(frame);bpy.context.view_layer.update()
        point=rig.matrix_world@hips.head
        shift=Vector((point.x-anchor.x,point.y-anchor.y,0))
        samples.append((frame,hips.location-to_local@shift))
    for frame,location in samples:
        scene.frame_set(frame);hips.location=location
        hips.keyframe_insert(data_path='location',frame=frame,group=hips.name)
        phase=(frame-first)/max(1,last-first)
        recoil=math.exp(-phase*5)*math.sin(phase*math.pi*6) if name=='shoot' else math.sin(phase*math.tau*2)
        amplitude=math.radians(7 if name=='shoot' else 2.5)
        for side,sign in [('L',1),('R',-1)]:
            for i,part in enumerate(['root','mid','tip']):
                bone=rig.pose.bones[f'stache_{part}.{side}']
                bone.rotation_euler=(amplitude*recoil*(1+i*.25),0,sign*amplitude*.3*recoil)
                bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=bone.name)
    residual=[]
    for frame,_ in samples:
        scene.frame_set(frame);bpy.context.view_layer.update();p=rig.matrix_world@hips.head
        residual.append(Vector((p.x-anchor.x,p.y-anchor.y,0)).length)
    motion[name]={'max_horizontal_hip_drift_metres':max(residual),'frames':[first,last]}
    durations[name]=(last-first)/30
    action['provenance']='Mixamo body motion; horizontal root translation removed and authored moustache follow-through added in Blender'

frenzy=actions['idle'].copy();frenzy.name='stache_frenzy';bind(frenzy)
for frame in range(1,62):
    scene.frame_set(frame);t=(frame-1)/60;envelope=math.sin(math.pi*t)**2
    for side,sign in [('L',1),('R',-1)]:
        for i,part in enumerate(['root','mid','tip']):
            bone=rig.pose.bones[f'stache_{part}.{side}']
            bone.rotation_euler=(math.radians(8)*envelope*math.sin(t*math.tau*3-i*.5),0,sign*math.radians(12)*envelope)
            bone.scale=Vector((1,1+.25*envelope,1))
            bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=bone.name)
            bone.keyframe_insert(data_path='scale',frame=frame,group=bone.name)
frenzy['provenance']='Authored moustache motion over a Mixamo idle base; pilot only, not the complete golden-wing ultimate'
actions['stache_frenzy']=frenzy;durations['stache_frenzy']=(frenzy.frame_range[1]-1)/30

for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for name,action in actions.items():
    track=rig.animation_data.nla_tracks.new();track.name=name
    strip=track.strips.new(name,int(action.frame_range[0]),action);track.mute=True
bind(actions['idle']);scene.frame_start=1;scene.frame_end=int(actions['idle'].frame_range[1]);scene.frame_set(1)

# Reuse the existing studio without modifying the source comparison scene.
studio=bpy.data.scenes['DonEspino_Refined_Workflow']
for obj in studio.objects:
    if obj.type in {'LIGHT','CAMERA'} or obj.name=='Review_Studio_Ground':
        if obj.name not in scene.objects:scene.collection.objects.link(obj)
scene.world=studio.world;scene.camera=studio.camera
scene.camera.location=(3,-6,2.9);scene.camera.rotation_euler=(Vector((0,0,1.5))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100

review=ROOT/'desgin/renders/don_espino/refined_workflow/animation_samples';review.mkdir(parents=True,exist_ok=True)
for name,action in actions.items():
    bind(action);first,last=action.frame_range
    for i,fraction in enumerate([0,.25,.5,.75]):
        scene.frame_set(int(first+(last-first)*fraction));scene.render.filepath=str(review/f'{name}_{i+1:02d}.png');bpy.ops.render.render(write_still=True)

bind(actions['idle']);scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for obj in [rig,mesh]+[o for o in scene.objects if o.name in ['Muzzle','GunOrigin']]:
    obj.hide_set(False);obj.hide_render=False;obj.select_set(True)
bpy.context.view_layer.objects.active=rig
path=OUT/'DonEspino_animation_pilot_NOT_APPROVED.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_def_bones=True,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'06_animation_pilot_NOT_APPROVED.blend'))
report=json.loads((OUT/'audit.json').read_text())
report.update({'animation_clips':durations,'root_motion':motion,'pilot_glb':path.name,'quality_status':'NOT APPROVED: visible arm/weapon and leg deformation in motion; needs neutral-pose reconstruction or retopology before gameplay replacement','gameplay_replacement':False,'source_preserved':hashlib.sha256((ROOT/'desgin/character_models/refined/DonEspino.glb').read_bytes()).hexdigest()==report['source_sha256']})
(OUT/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'clips':durations,'motion':motion,'export':str(path),'source_preserved':report['source_preserved']}))
