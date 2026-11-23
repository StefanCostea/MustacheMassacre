"""Ground, render and export the neutral-model character for Godot testing."""
import bpy,json,numpy as np
from pathlib import Path
from mathutils import Vector

ROOT=Path('/home/stefancostea/Documents/MustacheMassacre')
OUT=ROOT/'desgin/character_models/refined/don_espino_natural_workflow'
RENDERS=ROOT/'desgin/renders/don_espino/natural_workflow'
scene=bpy.context.scene;rig=bpy.data.objects['Natural_Mixamo_Rig'];skin=bpy.data.objects['Natural_Skin'];gun=bpy.data.objects['Natural_Separate_Revolver']
actions={name:bpy.data.actions[value] for name,value in json.loads(rig['natural_final_actions']).items()}

def bind(action):
    rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]

def skin_minimum():
    evaluated=skin.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
    coords=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',coords);coords=coords.reshape(-1,3)
    row=np.array(skin.matrix_world[2]);minimum=float((coords@row[:3]+row[3]).min());evaluated.to_mesh_clear();return minimum

floor={}
for name,action in actions.items():
    bind(action);first,last=map(int,action.frame_range);minimum=10;locations=[]
    hips=rig.pose.bones['mixamorig:Hips']
    for f in range(first,last+1):
        scene.frame_set(f);bpy.context.view_layer.update();minimum=min(minimum,skin_minimum());locations.append((f,hips.location.copy()))
    lift=max(0,.008-minimum);floor[name]={'minimum_before_m':minimum,'constant_lift_m':lift}
    if lift:
        delta=(rig.matrix_world.to_3x3()@hips.bone.matrix_local.to_3x3()).inverted()@Vector((0,0,lift))
        for f,location in locations:
            scene.frame_set(f);hips.location=location+delta;hips.keyframe_insert('location',frame=f,group=hips.name)

scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.camera.location=(3,-6,2.9);scene.camera.rotation_euler=(Vector((0,-.20,1.4))-scene.camera.location).to_track_quat('-Z','Y').to_euler();scene.camera.data.ortho_scale=3.75
samples=RENDERS/'animation_samples';samples.mkdir(parents=True,exist_ok=True)
for name,action in actions.items():
    bind(action);first,last=action.frame_range
    scene.camera.data.ortho_scale=4.8 if name=='death' else 3.75
    for i,t in enumerate([0,.33,.66]):
        scene.frame_set(round(first+(last-first)*t));scene.render.filepath=str(samples/f'{name}_{i+1:02d}.png');bpy.ops.render.render(write_still=True)

bind(actions['idle']);scene.frame_set(1);scene.camera.data.ortho_scale=3.75
bpy.ops.object.select_all(action='DESELECT')
for obj in [rig,skin,gun,bpy.data.objects['Muzzle'],bpy.data.objects['GunOrigin']]:
    obj.hide_set(False);obj.hide_render=False;obj.select_set(True)
bpy.context.view_layer.objects.active=rig
path=OUT/'DonEspinoNatural_animated.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,export_skins=True,export_def_bones=False,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'07_DonEspinoNatural_animated.blend'))
report=json.loads((OUT/'audit.json').read_text());report['stage']='animated candidate exported; Godot checks pending';report['body_triangles']=sum(len(p.vertices)-2 for p in skin.data.polygons);report['weapon_triangles']=sum(len(p.vertices)-2 for p in gun.data.polygons);report['floor_offsets']=floor;report['runtime_animation_count']=len(actions);report['native_bones']=len(rig.data.bones);report['strafe_coordinate_check']={'mixamo_id':'128280901','ui_description':'Strafe Left With An Aimed Pistol','unmodified_root_displacement_blender':[1.418854832649231,0,0],'runtime_role':'strafe_right: +X in the existing controller basis'}
(OUT/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('NATURAL_EXPORT',str(path),report['body_triangles']+report['weapon_triangles'],'triangles',len(actions),'clips')
