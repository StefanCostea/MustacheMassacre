"""Prepare the county's six TRELLIS reconstructions and bake regional enemy performances."""
import sys
from math import cos, exp, pi, sin
from pathlib import Path
import bpy
from mathutils import Matrix
sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_badlands_enemy_designs import ROOT, prepare
from animate_badlands_enemies import make_skeleton, bind_mesh, create_actions, ramp
from badlands_performance import set_pose

SCENERY = {"grand_palace":8.5, "wax_van":2.05, "ticket_kiosk":3.25, "fry_plant":4.4, "barber_garage":4.85}
SIZES = {"mustard": 1.90, "puppet": 1.88, "brush": 1.86, "flushness": 2.75,
         "dodgem": 1.52, **SCENERY}

def joints(kind, bones):
    bones.clear()
    bones.update(Root=((0,0,0),None), Cabinet=((0,0,.32),"Root"),
                 Head=((0,0,.64),"Cabinet"))
    for sign, side in [(-1,"R"),(1,"L")]:
        for key,x,z,parent in [("Arm",.18,.61,"Cabinet"),("Hand",.23,.41,"Arm"+side),
                               ("Leg",.10,.34,"Cabinet"),("Foot",.12,.14,"Leg"+side)]:
            bones[key+side]=((sign*x,0,z),parent)

def weights(kind, point):
    x,y,z=point
    side="L" if x>0 else "R"
    values={"Cabinet":1.}
    def layer(key,w):
        for b in values: values[b]*=1.-w
        values[key]=w
    if kind=="dodgem":
        layer("Head",ramp(.6,.8,z))
    else:
        layer("Head",ramp(.64,.71,z))
        arm=ramp(.16,.24,abs(x))*ramp(.24,.38,z)*(1-ramp(.60,.70,z))
        if kind=="flushness": arm=ramp(.23,.34,abs(x))*ramp(.21,.31,z)*(1-ramp(.47,.60,z))
        layer("Arm"+side,arm)
        layer("Hand"+side,arm*(1-ramp(.36,.46,z)))
        if kind!="flushness":
            leg=(1-ramp(.29,.38,z))*(1-ramp(.17,.24,abs(x)))
            layer("Leg"+side,leg)
            layer("Foot"+side,leg*(1-ramp(.12,.18,z)))
    active=sorted(values.items(),key=lambda pair:-pair[1])[:4]
    total=sum(w for _,w in active)
    return [(b,w/total) for b,w in active if w>0]

def timing(kind, clips):
    clips.update(move=28 if kind=="brush" else 21,windup=23,attack=16,recover=18,death=37)

def support_rotation(kind,rig,body,h):
    return None  # create_actions grounds each death sample against the evaluated surface.

def animate(kind,clip,t,h,rig):
    for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
    gait=sin(t*2*pi) if clip=="move" else 0
    breath=sin(t*2*pi) if clip in ("idle","move") else 0
    prep=ramp(.03,.83,t) if clip=="windup" else (1-ramp(0,.45,t) if clip=="attack" else 0)
    strike=sin(t*pi)*exp(-1.2*t) if clip=="attack" else 0
    fall=ramp(.10,.78,t) if clip=="death" else 0
    hurt=sin(t*pi) if clip=="hurt" else 0
    def pose(name,r=(0,0,0),p=(0,0,0)):set_pose(rig,h,name,r,p)
    tip={"puppet":(69,48),"mustard":(-86,13),"brush":(17,-86),"flushness":(-92,15),"dodgem":(8,108)}[kind]
    pose("Root",(tip[0]*fall,tip[1]*fall,8*fall))
    mechanical=kind in ("dodgem","flushness")
    bob=.025*abs(gait) if not mechanical else .014*abs(gait)
    pose("Cabinet",(2*breath-11*prep+16*strike+8*hurt,gait*(3 if mechanical else 5),-8*prep+11*strike),(0,0,bob))
    pose("Head",(-4*prep-9*strike+3*breath,3*breath,5*prep))
    for side,sign in [("R",-1),("L",1)]:
        beat=sign*gait
        aim=(45 if kind=="mustard" and side=="R" else 23) if kind!="dodgem" else 0
        pose("Arm"+side,(-17*beat-aim*prep-37*strike,sign*(6*breath+14*prep+23*fall),sign*(3*gait+11*strike)))
        pose("Hand"+side,(-7*beat-16*prep+17*strike,0,3*breath))
        pose("Leg"+side,(24*beat-8*prep,0,0))
        pose("Foot"+side,(-18*beat,0,0),(0,-.028*beat,.035*max(0,beat)))

def build(kind):
    folder=ROOT/"desgin/character_models/generated"/kind/"v01"
    target=ROOT/"game/assets/county"
    h=SIZES[kind]
    if kind in SCENERY:folder=ROOT/"desgin/prop_models/county/v01"/kind
    prepare(kind,h,35000 if kind in SCENERY else 24000,folder,target if kind in SCENERY else folder)
    if kind in SCENERY:return
    body=bpy.data.objects[kind]
    if kind in ("mustard","brush","puppet"):
        bpy.ops.export_scene.fbx(filepath=str(folder/"neutral.fbx"),use_selection=True,embed_textures=True,path_mode="COPY")
    rig=make_skeleton(kind,h,sys.modules[__name__])
    bind_mesh(body,rig,(weights(kind,v.co/h) for v in body.data.vertices))
    create_actions(kind,rig,body,h,sys.modules[__name__])
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/"animated.blend"),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(target/(kind+".glb")),export_format="GLB",export_animation_mode="NLA_TRACKS",export_anim_slide_to_zero=True,export_force_sampling=True,export_yup=True)

if __name__=="__main__":build(sys.argv[-1])
