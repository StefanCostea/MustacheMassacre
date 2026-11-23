"""Build the animated Badlands enemies from their versioned design meshes in Blender."""
import sys
from math import cos, pi, radians, sin, tau
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from badlands_hardware import build_hardware

MODELS = {"fridge_bruiser":1.58,"chili_bandit":1.72,"pigeon_bomber":1.35,"el_frigorifico":2.60}
FPS=30


def ramp(a,b,v):
    t=min(1,max(0,(v-a)/(b-a)))
    return t*t*(3-2*t)


def curve(t, keys):
    for (a,x),(b,y) in zip(keys,keys[1:]):
        if t<=b: return x+(y-x)*ramp(a,b,t)
    return keys[-1][1]


def split_bruiser_door(body,h):
    bm=bmesh.new();bm.from_mesh(body.data)
    for axis,level in ((2,.245),(2,.647),(1,-.140)):
        point=Vector((0,0,0)); normal=point.copy(); point[axis]=level*h;normal[axis]=1
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                               plane_co=point,plane_no=normal,dist=1e-7)
    for f in bm.faces: f.select=False
    for e in bm.edges: e.select=False
    for v in bm.verts: v.select=False
    selected=[]
    for f in bm.faces:
        p=f.calc_center_median()/h
        if .245<p.z<.647 and p.y<-.140 and not (p.z>.603 and p.y<-.212): selected.append(f)
    for face in selected: face.select_set(True)
    bm.to_mesh(body.data);bm.free()
    bpy.ops.object.select_all(action="DESELECT");body.select_set(True)
    bpy.context.view_layer.objects.active=body
    before=set(bpy.context.scene.objects)
    bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.separate(type="SELECTED");bpy.ops.object.mode_set(mode="OBJECT")
    door,=set(bpy.context.scene.objects)-before
    door.name="Hinged enamel door"
    return door


def make_skeleton(kind,h,performance=None):
    bones={"Root":((0,0,0),None),"Cabinet":((0,0,.28),"Root")}
    for sign,side in ((-1,"R"),(1,"L")):
        x=sign*(.14 if kind=="pigeon_bomber" else .13)
        bones["Foot"+side]=((x,0,.22 if kind!="pigeon_bomber" else .16),"Root")
        bones["Whisker"+side]=((sign*.025,-.196,.584),"Cabinet")
        if kind=="pigeon_bomber":
            bones["Wing"+side]=((sign*.239,-.058,.557),"Cabinet")
            bones["Primaries"+side]=((sign*.425,-.17,.43),"Wing"+side)
        if kind=="chili_bandit":
            bones["Leg"+side]=((sign*.066,0,.345),"Cabinet")
            bones["Foot"+side]=((sign*.104,.00,.157),"Leg"+side)
            bones["Arm"+side]=((sign*.067,.003,.54),"Cabinet")
            bones["Elbow"+side]=((sign*.172,.028,.47),"Arm"+side)
            bones["Hand"+side]=((sign*.227,-.023,.386),"Elbow"+side)
            bones["Whisker"+side]=((sign*.025,-.09,.70),"Cabinet")
        elif kind=="fridge_bruiser":
            bones["Whisker"+side]=((sign*.045,-.235,.728),"Cabinet")
        elif kind=="pigeon_bomber":
            bones["Whisker"+side]=((sign*.035,-.397,.746),"Head")
    if kind=="fridge_bruiser": bones["Door"]=((-.259,-.146,.449),"Cabinet")
    if kind=="el_frigorifico":
        for i in range(4): bones["Louver"+str(i)]=((0,-.218,.379+i*.035),"Cabinet")
        bones["Fan"]=((0,-.213,.421),"Cabinet")
        bones["Gauge"]=((.176,-.212,.482),"Cabinet")
        bones["Vent"]=((0,-.235,.432),"Cabinet")
    if kind=="chili_bandit":
        bones["Sidearm"]=((-.228,-.042,.361),"HandR")
        bones["Muzzle"]=((-.228,-.042-.434*.39/h,.361+.168*.39/h),"Sidearm")
    if kind=="pigeon_bomber":
        bones["Head"]=((0,-.265,.663),"Cabinet")
        bones["Egg"]=((-.207,-.389,.43),"Cabinet")
    if performance: performance.joints(kind,bones)
    data=bpy.data.armatures.new("Enemy skeleton")
    rig=bpy.data.objects.new("Rig",data);bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for key,(head,_) in bones.items():
        bone=data.edit_bones.new(key);bone.head=Vector(head)*h
        bone.tail=bone.head+Vector((0,0,.045*h))
    for key,(_,parent) in bones.items():
        if parent: data.edit_bones[key].parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def boot_regions(body,h):
    # Flood upwards from the boot soles. The overlapping holster and pepper tip
    # are separate pieces below the hip even where they share the leg's x/z range.
    vertices=body.data.vertices
    neighbors=[[] for _ in vertices]
    for edge in body.data.edges:
        a,b=edge.vertices
        neighbors[a].append(b);neighbors[b].append(a)
    found=set(i for i,v in enumerate(vertices) if v.co.z<h*.04)
    active=list(found)
    while active:
        for i in neighbors[active.pop()]:
            if i not in found and vertices[i].co.z<h*.323:
                found.add(i);active.append(i)
    return found


def body_weights(kind,p,boot=False):
    x,y,z=p; a=abs(x);side="L" if x>0 else "R"
    weights={"Cabinet":1.0}
    def layer(bone,w):
        if w<=0: return
        for key in weights: weights[key]*=1-w
        weights[bone]=w
    if kind in ("fridge_bruiser","el_frigorifico"):
        upper=.229 if kind=="fridge_bruiser" else .249
        layer("Foot"+side,1-ramp(upper-.030,upper,z))
        if kind=="el_frigorifico":
            w=ramp(.03,.115,a)*ramp(.164,.196,-y)*ramp(.533,.548,z)*(1-ramp(.617,.655,z))
        else:
            w=ramp(.045,.15,a)*ramp(.20,.255,-y)*ramp(.643,.675,z)*(1-ramp(.756,.778,z))
        layer("Whisker"+side,w)
    elif kind=="chili_bandit":
        # Track the curved shoulder and the open gap between hand and hip.
        arm_edge=.143 if z<.42 else max(.066,.143-(z-.42)*.59)
        arm=ramp(arm_edge,arm_edge+.016,a)*ramp(.269,.285,z)*(1-ramp(.517,.550,z))
        if z>.51 and y>.040: arm*=1-ramp(.51,.539,z)  # loose kerchief at the back
        leg=1-ramp(.276,.323,z) if boot else 0
        layer("Leg"+side,leg)
        layer("Foot"+side,leg*(1-ramp(.13,.185,z)))
        layer("Arm"+side,arm)
        layer("Elbow"+side,arm*(1-ramp(.435,.493,z)))
        layer("Hand"+side,arm*(1-ramp(.365,.404,z)))
        layer("Whisker"+side,ramp(.063,.113,a)*ramp(.645,.675,z)*(1-ramp(.727,.745,z)))
    else:
        layer("Foot"+side,(1-ramp(.122,.192,z))*ramp(-.03,.11,-y))
        head=ramp(.635,.694,z)*ramp(.095,.22,-y)
        layer("Head",head)
        layer("Whisker"+side,head*ramp(.086,.178,a)*(1-ramp(.761,.795,z)))
        wing=ramp(.193,.348,a)*(1-ramp(.673,.72,z))*ramp(.08,.19,z)
        wing*=1-ramp(.24,.34,-y)*(1-ramp(.30,.365,a))
        layer("Wing"+side,wing)
        layer("Primaries"+side,wing*ramp(.374,.501,a))
    kept=sorted(((w,n) for n,w in weights.items() if w>.0005),reverse=True)[:4]
    total=sum(w for w,_ in kept)
    return [(n,w/total) for w,n in kept]


def bind_mesh(obj,rig,assignment):
    groups={}
    for vertex,weights in zip(obj.data.vertices,assignment):
        for name,weight in weights:
            if name not in groups: groups[name]=obj.vertex_groups.new(name=name)
            groups[name].add([vertex.index],weight,"REPLACE")
    obj.parent=rig
    mod=obj.modifiers.new("Character deformation","ARMATURE");mod.object=rig


def motion(kind,clip,t,h,rig):
    """Pose bones in shared character axes; offsets use fractions of neutral height."""
    bird=kind=="pigeon_bomber"; chili=kind=="chili_bandit"; boss=kind=="el_frigorifico"
    running=clip=="move"; loop=clip in ("idle","move")
    attack=clip in ("attack","ice_attack")
    ice=clip.startswith("ice_")
    # Anticipation, commitment and settle share endpoints between adjacent state clips.
    ready=0; punch=0; recoil=0; collapse=0
    if clip.endswith("windup"):
        ready=curve(t,[(0,0),(.20,-.15),(.76,1),(1,1)])
    elif attack:
        ready=1
        punch=curve(t,[(0,0),(.14,1),(.38,.84),(.72,.66),(1,.60)]) if not chili else 0
        recoil=curve(t,[(0,0),(.21,1),(.52,.56),(1,0)])
    elif clip.endswith("recover"):
        ready=curve(t,[(0,1),(.42,.7),(.82,-.1),(1,0)])
        punch=0 if chili else curve(t,[(0,.60),(.40,.5),(.68,-.10),(1,0)])
    elif clip=="death":
        collapse=curve(t,[(0,0),(.13,-.08),(.65,1),(.79,.85),(.94,.98),(1,.96)])
    hurt=curve(t,[(0,0),(.22,1),(.62,-.28),(1,0)]) if clip=="hurt" else 0
    phi=t*tau; stride=sin(phi) if running else 0
    breath=sin(phi) if loop else 0
    body_pitch=(1.2*breath if not running else 3*cos(phi*2)) + (10 if bird else 7)*ready - (18 if bird else 20)*punch + 10*hurt
    if chili: body_pitch=.9*breath+2.8*stride-4.5*ready+5.5*recoil+10*hurt
    if ice: body_pitch=-7*ready+12*recoil
    poses={}
    def pose(name,r=(0,0,0),p=(0,0,0)):
        poses[name]=(r,p)
    lift=(.013*abs(stride) if running else .003*(1-cos(phi)) if loop else 0)
    if bird: lift=.064+(.022*sin(phi*2) if running else .012*breath)-.035*ready+.046*punch
    pose("Cabinet",(body_pitch,(3.4 if running else .8)*stride,3.0*stride if chili else 1.3*stride),
         (.012*stride,0,lift-.018*abs(ready)+.012*recoil))
    pose("Root",((66 if bird else -63 if chili else -80)*collapse,(-53 if chili else 27 if bird else 12)*collapse,8*collapse))
    for sign,side in ((-1,"R"),(1,"L")):
        s=sign*stride
        if chili:
            pose("Leg"+side,(24*s-8*ready+(20+15*sign)*collapse,sign*(-3*ready+12*collapse),0))
            pose("Foot"+side,(-21*s+17*max(0,s)-22*collapse,0,0),(0,0,.015*max(0,s)))
            right=side=="R"
            pose("Arm"+side,((13*s if running else 1.8*breath)+(-70 if right else -10)*ready+(9 if right else -3)*recoil-22*collapse,
                             (-24 if right else -8)*ready-sign*19*collapse,(41 if right else 8)*ready))
            pose("Elbow"+side,(-9-8*max(0,-s)+(-23 if right else -19)*ready+8*recoil*right-18*collapse,0,0))
            pose("Hand"+side,(4*s,sign*3*s,0))
        else:
            kick=40*collapse*sign if bird else 20*collapse*sign
            foot_lift=.034*max(0,s) if running else 0
            pose("Foot"+side,((13*s if not bird else 18+12*s)+kick-8*sign*ready,sign*4*ready,0),
                 (0,-.061*s+sign*.026*ready,foot_lift+(.035 if bird else 0)))
        pose("Whisker"+side,(2*breath+6*recoil,sign*(2.8*breath+6*ready-11*recoil+9*hurt),sign*2*stride))
        if bird:
            flap=sin(phi)* (29 if running else 12) if loop else 0
            lag=sin(phi-.68)*(19 if running else 7) if loop else 0
            pose("Wing"+side,(0,-sign*(flap+28*ready-58*punch-28*collapse),sign*(-5*ready+8*punch)))
            pose("Primaries"+side,(0,-sign*(lag+14*ready-26*punch-15*collapse),0))
    if bird: pose("Head",(-3*breath-16*ready+22*recoil,0,2*breath))
    if kind=="fridge_bruiser": pose("Door",(0,0,-(9*ready+73*punch+15*collapse)))
    if boss:
        for i in range(4):
            # Roll the leading edge upward. With the opposite rotation, the
            # raked blades stay broadside to the camera and hide the ice fan.
            opened=(53+2*i)*ready+(11-i)*recoil if ice else 8*ready+12*recoil
            pose("Louver"+str(i),(-opened+3*breath,0,0))
        pose("Gauge",(0,-34*ready-47*recoil+3*breath,0))
        # Integer blade intervals preserve the rotor silhouette across cuts.
        ice_turns={"ice_windup":3,"ice_attack":7,"ice_recover":3}
        fan_angle=360*t if loop else ice_turns[clip]*360*t/7 if ice else 28*ready+18*recoil
        pose("Fan",(0,fan_angle,0))
    basis=rig.data.bones["Root"].matrix_local.to_quaternion()
    for bone in rig.pose.bones:
        rot,offset=poses.get(bone.name,((0,0,0),(0,0,0)))
        world=Euler(tuple(radians(v) for v in rot)).to_quaternion()
        bone.rotation_quaternion=basis.inverted() @ world @ basis
        bone.location=basis.inverted() @ (Vector(offset)*h)
    if chili:
        # Solve at the wrist. The palm, grip and barrel keep one relative orientation
        # while the elbow and shoulder change the direction of the forearm.
        bpy.context.view_layer.update()
        weapon=rig.pose.bones["Sidearm"]
        wrist=rig.pose.bones["HandR"]
        parent_rot=wrist.parent.matrix.to_quaternion() @ basis.inverted()
        desired=Euler((radians(53*(1-ready)+3*stride-12*recoil),0,radians(-8*(1-ready)))).to_quaternion()
        if clip=="death":
            desired=rig.pose.bones["Root"].matrix.to_quaternion() @ basis.inverted() @ desired
        grip=Euler((radians(53),0,0)).to_quaternion()
        wrist.rotation_quaternion=basis.inverted() @ parent_rot.inverted() @ desired @ grip.inverted() @ basis
        weapon.rotation_quaternion=basis.inverted() @ grip @ basis


def create_actions(kind,rig,body,h,performance=None):
    lengths={"idle":48,"move":26 if kind=="el_frigorifico" else 20,"windup":24,"attack":5 if kind=="chili_bandit" else 17,
             "recover":18,"hurt":9,"death":26}
    if kind=="el_frigorifico": lengths.update(ice_windup=24,ice_attack=12,ice_recover=22)
    if performance: performance.timing(kind,lengths)
    scene=bpy.context.scene;scene.render.fps=FPS
    ad=rig.animation_data_create()
    for clip,frames in lengths.items():
        action=bpy.data.actions.new(clip);ad.action=action
        last_quats={}
        correction=performance.support_rotation(kind,rig,body,h) if performance and clip=="death" else None
        for frame in sorted(set(range(0,frames+1,1 if performance else 2))|{frames,1}):
            scene.frame_set(frame)
            if performance:
                performance.animate(kind,clip,frame/frames,h,rig)
            else:
                motion(kind,clip,frame/frames,h,rig)
            if clip=="death":
                if correction:
                    performance.settle(rig,correction,frame/frames)
                bpy.context.view_layer.update()
                evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
                verts=np.empty(3*len(evaluated.data.vertices),np.float32)
                evaluated.data.vertices.foreach_get("co",verts)
                low=float(verts[2::3].min())
                root=rig.pose.bones["Root"]
                delta=-low if performance else max(0,-low)+.012*h*sin(pi*frame/frames)**2
                root.location+=root.bone.matrix_local.to_quaternion().inverted() @ Vector((0,0,delta))
            for b in rig.pose.bones:
                if b.name in ("Egg","Muzzle","Vent"): continue
                q=b.rotation_quaternion.copy()
                if b.name in last_quats: q.make_compatible(last_quats[b.name])
                b.rotation_quaternion=q;last_quats[b.name]=q
                b.keyframe_insert("rotation_quaternion",frame=frame,group=b.name)
                b.keyframe_insert("location",frame=frame,group=b.name)
        slot=ad.action_slot;ad.action=None
        tr=ad.nla_tracks.new();tr.name=clip
        strip=tr.strips.new(clip,0,action);strip.action_slot=slot
        tr.mute=True
    for tr in ad.nla_tracks: tr.mute=False
    # Reset to the neutral rest state for import; the NLA tracks are independent clips.
    for b in rig.pose.bones: b.matrix_basis=Matrix.Identity(4)
    scene.frame_start=0;scene.frame_end=max(lengths.values());scene.frame_set(0)
    return lengths


def build(kind,h,performance=None):
    folder=ROOT/"desgin/character_models/generated"/kind
    dest=folder/("v03" if performance else "v02");dest.mkdir(exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(folder/"v01/prepared.blend"))
    bpy.context.preferences.filepaths.save_version=0
    body=bpy.data.objects[kind]; props=list(body.children)
    if kind=="el_frigorifico":
        for node in body.data.materials[0].node_tree.nodes:
            if node.type!="TEX_IMAGE" or not node.image: continue
            role="color" if node.image.colorspace_settings.name=="sRGB" else "metal_rough"
            im=bpy.data.images.load(str(folder/"v02"/("sheriff_"+role+".png")),check_existing=True)
            im.colorspace_settings.name=node.image.colorspace_settings.name;im.pack();node.image=im
    door=split_bruiser_door(body,h) if kind=="fridge_bruiser" else None
    fittings=build_hardware(body,h,kind=="el_frigorifico") if kind in ("el_frigorifico","fridge_bruiser") else None
    if performance and kind=="chili_bandit": fittings=performance.gloves(body,h)
    rig=make_skeleton(kind,h,performance)
    boots=(performance.boot_regions(body,h) if performance else boot_regions(body,h)) if kind=="chili_bandit" else set()
    if kind=="chili_bandit" and not performance:
        for vertex in body.data.vertices:
            x,y,z=vertex.co/h
            if x<-.16 and .27<z<.378:
                curl=1-ramp(.285,.378,z)
                vertex.co.x+=h*(-.226-x)*.52*curl
                vertex.co.y-=h*.020*sin(curl*pi)
                vertex.co.z+=h*.030*curl*curl
    weights = performance.weights if performance else body_weights
    bind_mesh(body,rig,(weights(kind,v.co/h,v.index in boots) for v in body.data.vertices))
    for obj in props:
        mat=obj.matrix_world.copy();obj.parent=None
        bone="Cabinet"
        if kind=="chili_bandit":
            bone="Sidearm"
            # Move the neutral prop from the holster to the gripping palm, local bore pointing -Y.
            grip=rig.data.bones[bone].head_local
            mat=Matrix.Translation(grip) @ Matrix.Scale(performance.PROP_SCALE if performance else .39,4)
        obj.matrix_world=Matrix.Identity(4);obj.data.transform(mat)
        bind_mesh(obj,rig,([ (bone,1) ] for v in obj.data.vertices))
    if door: bind_mesh(door,rig,([("Door",1)] for v in door.data.vertices))
    if fittings:
        obj,owners=fittings;bind_mesh(obj,rig,([(key,1)] for key in owners))
    # One skinned surface per material. Keep all controller bones in the GLB for gameplay sockets.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type=="MESH": obj.select_set(True)
    bpy.context.view_layer.objects.active=body
    if len(bpy.context.selected_objects)>1: bpy.ops.object.join()
    clips=create_actions(kind,rig,body,h,performance)
    export=dest if performance else ROOT/"game/assets/enemies/animated";export.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(dest/"animated.blend"),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(export/(kind+".glb")),export_format="GLB",export_animation_mode="NLA_TRACKS",
                              export_anim_slide_to_zero=True,export_animations=True,export_force_sampling=True,
                              export_optimize_animation_size=True,export_yup=True)
    print("BADLANDS_EXPORT",kind,clips,flush=True)


if __name__ == "__main__":
    for name in (sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else MODELS):
        build(name,MODELS[name])
