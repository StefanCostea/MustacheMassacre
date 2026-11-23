"""Prepare the TRELLIS sculpts, bind articulated appliances and export their seven gameplay clips."""
import json
import sys
from math import cos, exp, pi, radians, sin
from pathlib import Path
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from prepare_badlands_enemy_designs import prepare, ROOT
from animate_badlands_enemies import make_skeleton, bind_mesh, create_actions

HEIGHT = {"skillet_outlaw":1.72,"repair_appliance":1.52}

def smooth(a,b,x):
    v=max(0,min(1,(x-a)/(b-a)))
    return v*v*(3-2*v)

def joints(kind,bones):
    skillet=kind=="skillet_outlaw"
    shoulder=.245 if skillet else .22
    for sign,side in ((-1,"R"),(1,"L")):
        bones["Arm"+side]=((sign*shoulder,0,.50 if skillet else .57),"Cabinet")
        bones["Palm"+side]=((sign*.36,-.02,.36 if skillet else .41),"Arm"+side)
        bones["Leg"+side]=((sign*.114,0,.255 if skillet else .26),"Cabinet")
        bones["Foot"+side]=((sign*.114,-.008,.135),"Leg"+side)
    bones["Nozzle"]=((-.40,-.072,.34),"PalmR")
    bones["WhiskerR"]=((-.08,-.18,.56),"Cabinet")
    bones["WhiskerL"]=(( .08,-.18,.56),"Cabinet")

def weights(kind,p):
    x,y,z=p;side="R" if x<0 else "L";x=abs(x)
    # The pan tapers at both shoulders. The box welder has straight side walls.
    skillet=kind=="skillet_outlaw"
    shoulder=.246 if skillet else .218
    arm=smooth(shoulder-.012,shoulder+.064,x)*(1-smooth(.50 if skillet else .57,.62 if skillet else .68,z))*smooth(.26,.30,z)
    hand=smooth(.325,.399,x)
    leg=(1-smooth(.225,.31,z))*(1-smooth(.245,.32,x))
    boot=1-smooth(.13,.19,z)
    return [(n,v) for n,v in [("Cabinet",1-leg-arm),("Leg"+side,leg*(1-boot)),("Foot"+side,leg*boot),
                               ("Arm"+side,arm*(1-hand)),("Palm"+side,arm*hand)] if v>.00001]

def timing(kind,lengths):
    lengths.update(move=28 if kind=="skillet_outlaw" else 23,windup=23,attack=16,recover=23,death=41 if kind=="skillet_outlaw" else 42)

def support_rotation(kind,rig,body,h):
    return None

def animate(kind,clip,t,h,rig):
    for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
    def pose(name,rot=(0,0,0),offset=(0,0,0)):
        bone=rig.pose.bones[name];basis=bone.bone.matrix_local.to_quaternion()
        bone.rotation_quaternion=basis.inverted() @ Euler(tuple(radians(a) for a in rot)).to_quaternion() @ basis
        bone.location=basis.inverted() @ (Vector(offset)*h)
    skillet=kind=="skillet_outlaw";beat=2*pi*t;step=sin(beat);pulse=sin(pi*t)
    if clip in ("move","idle"):
        gait=1 if clip=="move" else 0
        pose("Cabinet",(2+cos(beat)*1.8,step*(4 if gait else 1),step*4*gait),(step*.018*gait,0,.013*(1-cos(2*beat))*gait+.008*sin(beat)))
        for sign,side in ((-1,"R"),(1,"L")):
            phase=step*sign
            pose("Leg"+side,((17 if skillet else 22)*phase*gait,0,sign*1.5))
            pose("Foot"+side,(-12*phase*gait,0,0),(0,-phase*.026*gait,max(0,phase)*.036*gait))
            pose("Arm"+side,(-14*phase*gait,sign*(3+3*step),0))
            pose("Palm"+side,(5*cos(beat)*sign,0,0))
    elif clip in ("windup","attack","recover"):
        brace=smooth(0,.82,t) if clip=="windup" else 1-smooth(.2,1,t) if clip=="recover" else 1
        swing=sin(pi*t) if clip=="attack" else 0
        pose("Cabinet",((12 if skillet else -8)*brace-25*swing,4*brace,-10*brace+22*swing),(0,.034*brace-.09*swing,-.035*brace))
        pose("ArmR",(-36*brace-45*swing,12*brace,-9*brace))
        pose("PalmR",(-14*brace+15*swing,0,-16*swing))
        pose("ArmL",(-25*brace+30*swing,-7*brace,-12*brace))
        pose("FootL",(0,4*brace,0),(0,-.035*brace,0))
    elif clip=="hurt":
        pose("Cabinet",(-15*pulse,0,-8*pulse),(0,.04*pulse,0))
        pose("ArmR",(-16*pulse,0,0))
    elif clip=="death":
        drop=smooth(.1,.69,t)
        bounce=sin((t-.69)*29)*exp(-10*(t-.69)) if t>.69 else 0
        pose("Root",((-85 if skillet else 24)*drop+8*bounce,(10 if skillet else 77)*drop-6*bounce,12*drop),(0,.12*drop,0))
        pose("Cabinet",(12*pulse,0,-5*pulse))
        for sign,side in ((-1,"R"),(1,"L")):
            pose("Leg"+side,((-34+sign*12)*pulse,sign*12*drop,0))
            pose("Arm"+side,((-28 if skillet else -45)*pulse,sign*(18*drop+11*bounce),sign*14*drop))

def build(kind):
    h=HEIGHT[kind]
    folder=ROOT/'desgin/character_models/generated'/kind/'v01'
    prepare(kind,h,22000)
    body=bpy.data.objects[kind]
    performance=sys.modules[__name__]
    rig=make_skeleton(kind,h,performance)
    bind_mesh(body,rig,(weights(kind,v.co/h) for v in body.data.vertices))
    clips=create_actions(kind,rig,body,h,performance)
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'animated.blend'),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/enemies/animated'/(kind+'.glb')),export_format='GLB',
        export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,export_force_sampling=True,export_yup=True)
    (folder/'motion.json').write_text(json.dumps(dict(source="Blender authored",bones=len(rig.data.bones),frames=clips),indent=2))
    
if __name__=="__main__":
    for name in sys.argv[sys.argv.index('--')+1:]:build(name)
