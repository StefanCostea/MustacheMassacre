"""Render inspection views of the actual saved hero-detail Blender model."""
from pathlib import Path
import sys,bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'desgin/renders/don_espino/v3'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'desgin/character_models/DON_ESPINO_hero_v3.blend'))
s=bpy.context.scene
try:
 p=bpy.context.preferences.addons['cycles'].preferences;p.compute_device_type='OPTIX';p.get_devices()
 for d in p.devices:d.use=d.type=='OPTIX'
 s.cycles.device='GPU'
except Exception: s.cycles.device='CPU'
s.cycles.samples=128;s.cycles.use_denoising=True
views={
 'hero':('01_actual_blender_hero.png',(.70,-10.5,3.5),(-.12,0,2),4.43,1500,2000),
 'face':('02_actual_face_and_hat.png',(.45,-9,3.5),(0,-.13,2.96),2.40,1800,1800),
 'boots':('03_actual_clothing_and_boots.png',(1.1,-8,2.2),(0,-.05,.97),2.1,1800,1800),
 'weapon':('04_actual_hand_and_revolver.png',(-.5,-6,2.5),(-1,-.34,1.38),1.22,1800,1400),
 'rear':('05_actual_rear.png',(-2.5,9,3.4),(0,0,2),4.43,1500,2000),
}
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(views)
for key in args:
 filename,loc,target,scale,w,h=views[key];cam=s.camera;cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 s.render.resolution_x=w;s.render.resolution_y=h;s.render.resolution_percentage=100;s.render.filepath=str(OUT/filename)
 bpy.ops.render.render(write_still=True)
 print('RENDERED',key,flush=True)
