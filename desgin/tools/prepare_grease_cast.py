"""Prepare the General Coo and diner TRELLIS meshes. Coo uses authored avian motion."""
import json
import sys
from math import cos, exp, pi, sin
from pathlib import Path
import bpy
from mathutils import Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
from prepare_badlands_enemy_designs import ROOT, prepare
from animate_badlands_enemies import make_skeleton, bind_mesh, create_actions
from badlands_performance import landing_support, set_pose, settle

def blend(a,b,v):
    u=max(0,min(1,(v-a)/(b-a)))
    return u*u*(3-2*u)

def joints(kind,bones):
    bones['Head']=((0,-.035,.63),'Cabinet')
    for sign,side in [(-1,'R'),(1,'L')]:
        def joint(name,x,y,z,parent):
            bones[name+side]=((sign*x,y,z),parent)
        joint('Wing',.20,0,.61,'Cabinet')
        joint('Palm',.34,-.02,.41,'Wing'+side)
        joint('Leg',.105,.004,.26,'Cabinet')
        joint('Foot',.12,-.018,.142,'Leg'+side)
        joint('Whisker',.052,-.15,.73,'Head')
        joint('WhiskerTip',.14,-.15,.73,'Whisker'+side)

def weights(v):
    x,y,z=v; side='L' if x>0 else 'R'; a=abs(x)
    values={'Cabinet':1.0}
    def layer(key,t):
        for n in values:values[n]*=1-t
        values[key]=t
    layer('Head',blend(.63,.71,z))
    whisk=blend(.042,.10,a)*blend(.665,.715,z)*(1-blend(.78,.83,z))*blend(.035,.14,-y)
    layer('Whisker'+side,whisk)
    layer('WhiskerTip'+side,whisk*blend(.13,.2,a))
    leg=(1-blend(.22,.31,z))*(1-blend(.22,.29,a))
    layer('Leg'+side,leg)
    layer('Foot'+side,leg*(1-blend(.12,.18,z)))
    wing=blend(.19,.275,a)*blend(.19,.29,z)*(1-blend(.58,.68,z))
    layer('Wing'+side,wing)
    layer('Palm'+side,wing*blend(.30,.40,a))
    active=sorted([(k,w) for k,w in values.items() if w>.0001],key=lambda item:-item[1])[:4]
    total=sum(w for _,w in active)
    return [(k,w/total) for k,w in active]

def timing(kind, clips):
    clips.clear()
    clips.update(idle=48,move=24,backstep=25,strafe_left=25,strafe_right=25,fire=10,vent=30,hop=21,cast=29,hurt=10,death=37)

def support_rotation(kind,rig,body,h):
    animate(kind,"death",1,h,rig)
    return landing_support(body,h,.85)

def animate(kind,clip,t,h,rig):
    for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
    gait=clip in ('move','backstep','strafe_left','strafe_right')
    beat=t*2*pi; stride=sin(beat)*(-1 if clip=='backstep' else 1)
    lateral=1 if clip=='strafe_left' else -1 if clip=='strafe_right' else 0
    hop=sin(pi*t) if clip=='hop' else 0
    recoil=sin(pi*t)*exp(-3*t) if clip=='fire' else 0
    brace=sin(pi*t) if clip in ('vent','cast','hurt') else 0
    fall=blend(.12,.76,t) if clip=='death' else 0
    def pose(name,r=(0,0,0),p=(0,0,0)):set_pose(rig,h,name,r,p)
    pose('Root',(-101*fall,22*fall,7*fall))
    pose('Cabinet',(4+4*int(gait)+10*brace-8*recoil,4*stride*int(gait),4*stride*int(gait)),(0,.035*recoil,.015*cos(beat*2)*int(gait)))
    pose('Head',(-3*int(gait)*cos(beat*2)-5*brace,3*sin(beat),1.4*cos(beat)),(0,-.014*cos(beat*2)*int(gait),0))
    for side,sign in [('R',-1),('L',1)]:
        step=sign*stride*int(gait)
        pose('Leg'+side,(24*step-26*hop,7*lateral*step,0))
        pose('Foot'+side,(-17*step+15*hop,0,0),(0,-.02*step,max(0,step)*.043))
        # Wing tips come forward into the carry, then flare open during the hop.
        draw=1 if side=='R' else 0
        pose('Wing'+side,(-17-17*draw-(6-3*draw)*step-12*recoil*draw,sign*(32-70*hop+5*step),-sign*(15+15*draw+9*brace)))
        pose('Palm'+side,(-11-14*draw+6*step-12*recoil,sign*(11-19*hop),-sign*(10+14*brace)))
        pose('Whisker'+side,(1.5*cos(beat),sign*(1.8*sin(beat)+4*brace),0))
        pose('WhiskerTip'+side,(2*cos(beat-.42),sign*(3*sin(beat-.42)+7*recoil+6*hop),0))

def build():
    folder=ROOT/'desgin/character_models/generated/general_coo/v01'
    height=1.62
    prepare('general_coo',height,36500,folder,folder)
    body=bpy.data.objects['general_coo']
    bpy.ops.export_scene.fbx(filepath=str(folder/'neutral.fbx'),use_selection=True,embed_textures=True,path_mode='COPY')
    rig=make_skeleton('general_coo',height,sys.modules[__name__])
    bind_mesh(body,rig,(weights(v.co/height) for v in body.data.vertices))
    clips=create_actions('general_coo',rig,body,height,sys.modules[__name__])
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'animated.blend'),compress=True)
    target=ROOT/'game/assets/characters/general_coo'
    target.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(target/'general_coo.glb'),export_format='GLB',export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,export_force_sampling=True,export_yup=True)
    (folder/'motion.json').write_text(json.dumps({'frames':clips,'bones':len(rig.data.bones),'source':'Authored in Blender 5.3. Mixamo was signed out.'},indent=2))
    folder=ROOT/'desgin/prop_models/grease_city/v01/diner'
    prepare('grease_diner',5.4,19500,folder,ROOT/'game/assets/environment/props')

if __name__=='__main__':build()
