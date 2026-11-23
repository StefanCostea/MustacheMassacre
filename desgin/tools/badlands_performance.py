"""Bake the third Badlands performance pass from the preserved Blender sources."""
import sys
from math import cos, radians, sin, sqrt, tau
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Quaternion, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import animate_badlands_enemies as previous
from badlands_hardware import Hardware

PROP_SCALE = .56


def boot_regions(body,h):
    # Traverse the leg below the belt, welding coincident UV-seam vertices
    # for this query only. The empty leather holster has its own islands.
    vs=body.data.vertices
    coords=[tuple(round(c/h,5) for c in v.co) for v in vs]
    edges={}
    for edge in body.data.edges:
        a,b=(coords[i] for i in edge.vertices)
        if max(a[2],b[2])<.323:
            edges.setdefault(a,set()).add(b)
            edges.setdefault(b,set()).add(a)
    visited={p for p in coords if p[2]<.04}
    todo=list(visited)
    while todo:
        for other in edges.get(todo.pop(),()):
            if other not in visited: visited.add(other);todo.append(other)
    return {i for i,p in enumerate(coords) if p in visited}


def support_rotation(kind,rig,body,h):
    # Find a low-energy orientation of the authored landing. A lowest-vertex
    # floor correction alone can leave the entire bandit balanced on his stem.
    animate(kind,"death",1,h,rig)
    limit={"chili_bandit":.72,"el_frigorifico":.28,"fridge_bruiser":.17,"pigeon_bomber":.40}[kind]
    return landing_support(body,h,limit)


def landing_support(body,h,limit):
    bpy.context.view_layer.update()
    evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    verts=np.array([v.co[:] for v in evaluated.data.vertices])/h
    verts-=np.median(verts,axis=0)
    normal=np.array([0.,0.,1.])
    for step in (limit/4,limit/16,limit/64,limit/256):
        offsets=np.arange(-4,5)*step
        candidates=np.array([[normal[0]+x,normal[1]+y,1] for x in offsets for y in offsets
                             if (normal[0]+x)**2+(normal[1]+y)**2<=limit**2])
        unit=candidates/np.linalg.norm(candidates,axis=1)[:,None]
        normal=candidates[np.argmax(np.min(verts @ unit.T,axis=0))]
    return Vector(normal).rotation_difference(Vector((0,0,1)))


def settle(rig,correction,t):
    root=rig.pose.bones["Root"]
    basis=root.bone.matrix_local.to_quaternion()
    turn=Quaternion().slerp(correction,previous.ramp(.54,.91,t))
    root.rotation_quaternion=basis.inverted() @ turn @ basis @ root.rotation_quaternion


def gloves(body,h):
    """Use closed gripping fingers on the sidearm and a relaxed free hand."""
    bm=bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                           plane_co=(0,0,.39*h),plane_no=(0,0,1),dist=1e-7)
    removed=[]
    for face in bm.faces:
        x,y,z=face.calc_center_median()/h
        if .266<z<.39 and abs(x)>.155 and (y<-.020 or abs(x)>.214):
            removed.append(face)
    bmesh.ops.delete(bm,geom=removed,context="FACES")
    bm.to_mesh(body.data);bm.free()
    g=Hardware(body,h)
    leather=g.material("Oxblood deerskin",(.19,.041,.021),0,.59)
    welt=g.material("Glove cuff piping",(.50,.227,.082),.08,.56)
    skin=g.material("Pepper fingertips",(.57,.044,.014),0,.54)
    for sign,side in ((-1,"R"),(1,"L")):
        g.bone="Hand"+side
        def tube(coords,radii,mat):
            g.sweep([(sign*x,y,z) for x,y,z in coords],radii,mat,12)
        tube([(.214,-.012,.405),(.22,-.023,.392),(.225,-.032,.376),(.233,-.031,.354),
              (.236,-.028,.341)],[.014,.021,.023,.023,.014],leather)
        tube([(.216,-.014,.402),(.218,-.018,.397)],[.026,.027],welt)
        for j in range(4):
            z=.36-j*.0088
            reach=.037 if side=="R" and j==0 else .019
            finger=[(.242,-.034,z),(.243,-.040-reach*.40,z-.002),
                    (.234,-.043-reach,z-.004),(.223,-.042-reach,z-.004),
                    (.216,-.038-reach*.82,z-.002)]
            if side=="L":
                finger=[(.238,-.027+j*.008,z+.002),(.244,-.042+j*.008,z-.010),
                        (.239,-.053+j*.007,z-.018),(.230,-.053+j*.007,z-.020),
                        (.226,-.050+j*.007,z-.018)]
            tube(finger[:3],[.008,.0074,.007],leather)
            tube(finger[2:],[.0071,.0069,.0036],skin)
        tube([(.222,-.028,.374),(.213,-.040,.372),(.212,-.059,.365),(.218,-.066,.361)],
             [.011,.010,.009,.005],skin)
    return g.finish()


def timing(kind, clips):
    clips["death"] = {"chili_bandit":38, "pigeon_bomber":42, "fridge_bruiser":34, "el_frigorifico":45}[kind]
    if kind == "pigeon_bomber":
        clips.update(takeoff=24, idle=20, move=17, windup=24, attack=13, recover=22)
    if kind == "chili_bandit":
        clips.update(move=18, backstep=20, strafe_left=19, strafe_right=19, idle=54, windup=22, attack=5, recover=19)


def joints(kind, bones):
    if kind == "pigeon_bomber":
        for sign,side in ((-1,"R"),(1,"L")):
            bones["Foot"+side] = ((sign*.142,-.167,.226),"Cabinet")
        bones["Egg"] = ((-.17,-.262,-.068),"FootR")
        bones["Tail"] = ((0,.055,.376),"Cabinet")
    elif kind == "chili_bandit":
        h=previous.MODELS[kind]
        bones["Muzzle"]=((-.228,-.042-.434*PROP_SCALE/h,.361+.168*PROP_SCALE/h),"Sidearm")
        bones["Spine"] = ((0,.005,.382),"Cabinet")
        bones["Head"] = ((0,.007,.578),"Spine")
        bones["Stem"] = ((.044,0,.869),"Head")
        for sign,side in ((-1,"R"),(1,"L")):
            bones["Whisker"+side] = ((sign*.037,-.091,.65),"Head")
            bones["Arm"+side] = ((sign*.081,.017,.516),"Spine")
            bones["Elbow"+side] = ((sign*.182,.03,.46),"Arm"+side)
            bones["Hand"+side] = ((sign*.218,-.026,.387),"Elbow"+side)
            bones["Knee"+side] = ((sign*.087,-.014,.211),"Leg"+side)
            bones["Foot"+side] = ((sign*.103,-.001,.116),"Knee"+side)


def weights(kind, p, boot):
    x,y,z=p
    side="L" if x>0 else "R"
    w=dict(previous.body_weights(kind,p,boot))
    if kind == "pigeon_bomber":
        # The front panniers sit between the wing roots and the feet.
        # Keep both pockets on the chest throughout the full power stroke.
        wing=previous.ramp(.162,.307,abs(x))*(1-previous.ramp(.216,.264,-y))*(1-previous.ramp(.638,.706,z))
        wing=max(wing,previous.ramp(.309,.378,abs(x))*(1-previous.ramp(.65,.73,z)))
        tail=previous.ramp(.008,.15,y)*(1-previous.ramp(.38,.50,z))
        # All forward-facing toes belong to the boot, including the outer
        # talon at x=.30. The broad wing overlaps it in front projection.
        leg=(1-previous.ramp(.15,.246,z))*(1-previous.ramp(.30,.35,abs(x)))*previous.ramp(.053,.136,-y)
        wing*=1-(1-previous.ramp(.095,.215,z))*(1-previous.ramp(.305,.36,abs(x)))
        head=previous.ramp(.635,.72,z)*previous.ramp(.076,.20,-y)
        tips=previous.ramp(.354,.52,abs(x))
        whisk=w.get("Whisker"+side,0)
        w={"Foot"+side:leg,"Tail":tail*(1-leg), "Head":max(0,head-whisk),"Whisker"+side:whisk}
        rem=1-sum(w.values())
        w["Wing"+side]=rem*wing*(1-tips); w["Primaries"+side]=rem*wing*tips
        w["Cabinet"]=rem*(1-wing)
    if kind=="chili_bandit":
        if .382 < z < .421 and abs(x)>.16:
            wrist=1-previous.ramp(.39,.421,z)
            return [("Hand"+side,wrist),("Elbow"+side,1-wrist)]
        if z<.39:
            # The pepper curls out past the thigh; the holster hangs behind
            # the other leg. Neither should inherit a wrist or knee rotation.
            high=previous.ramp(.19,.243,z)
            cap=1-high*previous.ramp(.105,.14,abs(x)) if x>0 else 1
            leg=(1-previous.ramp(.285,.337,z))*cap if boot or z<.18 else 0
            knee=1-previous.ramp(.183,.244,z)
            foot=1-previous.ramp(.106,.15,z)
            return [(n,w) for n,w in [("Cabinet",1-leg),("Leg"+side,leg*(1-knee)),
                    ("Knee"+side,leg*knee*(1-foot)),("Foot"+side,leg*knee*foot)] if w>0]
        chest=w.pop("Cabinet",0)
        spine=previous.ramp(.365,.465,z)
        head=previous.ramp(.548,.606,z)
        w.update(Cabinet=chest*(1-spine),Spine=chest*spine*(1-head),Head=chest*spine*head)
        stem=previous.ramp(.880,.921,z)
        w["Stem"]=w["Head"]*stem
        w["Head"]*=1-stem
    keep=sorted(((k,v) for k,v in w.items() if v>0.0001),key=lambda kv:-kv[1])[:4]
    total=sum(v for _,v in keep)
    return [(k,v/total) for k,v in keep]


def quat(degrees):
    return Euler(tuple(radians(v) for v in degrees)).to_quaternion()


def set_pose(rig,h,name,rotation=(0,0,0),offset=(0,0,0)):
    b=rig.pose.bones[name]
    basis=b.bone.matrix_local.to_quaternion()
    q=rotation if isinstance(rotation,Quaternion) else quat(rotation)
    b.rotation_quaternion=basis.inverted() @ q @ basis
    b.location=basis.inverted() @ (Vector(offset)*h)


def limb(rig,h,names,target,pole,end_rotation):
    """Two segments in their common parent's rest coordinates, with a fixed pole."""
    a,b,c=(rig.data.bones[n].head_local/h for n in names)
    upper,lower=b-a,c-b
    ray=Vector(target)-a
    reach=min(ray.length,upper.length+lower.length-.001)
    axis=ray.normalized()
    elbow_dir=Vector(pole)-a
    normal=(elbow_dir-axis*elbow_dir.dot(axis)).normalized()
    along=(upper.length**2-lower.length**2+reach**2)/(2*reach)
    joint=axis*along+normal*sqrt(max(0,upper.length**2-along**2))
    upper_q=upper.rotation_difference(joint)
    lower_q=lower.rotation_difference(upper_q.inverted() @ (axis*reach-joint))
    set_pose(rig,h,names[0],upper_q)
    set_pose(rig,h,names[1],lower_q)
    set_pose(rig,h,names[2],(upper_q@lower_q).inverted() @ end_rotation)


def bandit(clip,t,h,rig):
    C=lambda *v: previous.curve(t,v)
    phase=t*tau
    walk=clip in ("move","backstep","strafe_left","strafe_right")
    lateral=1 if clip=="strafe_left" else -1 if clip=="strafe_right" else 0
    stride=sin(phase) if walk else 0
    idle=sin(phase) if clip=="idle" else 0
    ready=kick=hit=0
    if clip=="windup": ready=C((0,0),(.22,-.13),(.76,.94),(1,1))
    if clip=="attack":
        ready=1; kick=C((0,0),(.2,1),(.54,.48),(1,0))
    if clip=="recover": ready=C((0,1),(.25,.97),(.67,.32),(1,0))
    if clip=="hurt": hit=C((0,0),(.24,1),(.65,-.21),(1,0))
    hips=(.017*stride,0,-.033-.025*ready+(.014*cos(2*phase) if walk else .003*idle))
    chest=(4+2.3*stride+6*ready-8*kick-10*hit,-3*stride-7*ready,8*stride-16*ready)
    set_pose(rig,h,"Cabinet",(2,3*stride,-5*stride),hips)
    set_pose(rig,h,"Spine",chest)
    set_pose(rig,h,"Head",(-3-3*stride-5*ready+5*kick,-4*ready,9*ready-5*stride+2*idle))
    set_pose(rig,h,"Stem",(6*stride-11*kick,3*idle,0))
    for sign,side in ((-1,"R"),(1,"L")):
        s=sign*stride
        swing=max(0,-sign*cos(phase)) if walk else 0
        # Stance foot traverses backward as the actor advances. The opposite
        # foot clears the ground and flexes at the knee on its forward stroke.
        reach=.025 if lateral else -.124 if clip=="backstep" else .149
        ankle=(sign*(.108+.018*ready+.011*abs(lateral))-hips[0]+lateral*.099*s,
               -.002+reach*s+sign*(.034*ready+.024*abs(lateral)),
               .116-hips[2]+.062*swing)
        limb(rig,h,("Leg"+side,"Knee"+side,"Foot"+side),ankle,
             (sign*.10,-.18,.18),quat((8*s-13*swing,0,sign*(5+5*ready))))
        if side=="R":
            carry=Vector((-.179+.009*s,-.075+.037*s,.363-.006*s))
            aiming=Vector((-.068,-.235,.552))
            target=carry.lerp(aiming,ready)+Vector((-.012*kick,.022*kick,.016*kick))
            # Align the prop in character space at discharge. During carry
            # the wrist yields to the stride and the weight of the barrel.
            parent=quat((2,3*stride,-5*stride)) @ quat(chest)
            world=quat((50*(1-ready)+9*s-13*kick,3*(1-ready),-9*(1-ready)))
            palm=parent.inverted() @ world
            limb(rig,h,("ArmR","ElbowR","HandR"),target,(-.30,.05,.397),palm)
        else:
            target=Vector((.165,-.059+.064*s,.365+.035*max(0,-s))).lerp(Vector((.11,-.126,.446)),ready)
            limb(rig,h,("ArmL","ElbowL","HandL"),target,(.268,.052,.415),quat((-15-18*ready+10*s,5,-9)))
        set_pose(rig,h,"Whisker"+side,(3*idle+6*kick,sign*(5*kick+2*s),3*s))


def flight(clip,t,h,rig):
    C=lambda *v: previous.curve(t,v)
    bank=0; kick=0; dive=0; pitch=4
    sweep=-2; tuck=1
    if clip in ("idle","move","hurt"):
        phase=t*tau
        if clip=="hurt":
            bank=C((0,0),(.25,23),(1,0)); pitch+=C((0,0),(.23,-15),(1,0))
        if clip=="move": pitch=15; sweep=9
        flap=12+47*sin(phase); tip=11+27*sin(phase-.92)
        bob=.028*cos(phase-.25)
    elif clip=="takeoff":
        tuck=C((0,0),(.20,0),(.56,.65),(1,1))
        flap=C((0,-14),(.23,77),(.49,-43),(.71,52),(1,12))
        tip=C((0,-8),(.31,33),(.54,-26),(.81,26),(1,-10))
        pitch=C((0,0),(.22,17),(.50,-14),(1,4))
        bob=C((0,0),(.19,-.043),(.47,.045),(1,.028))
    elif clip=="windup":
        flap=C((0,12),(.24,62),(.51,-27),(.81,72),(1,58))
        tip=C((0,-10),(.34,35),(.59,-22),(.9,32),(1,27))
        bank=C((0,0),(.52,-20),(1,-12))
        dive=C((0,0),(.48,-.38),(1,1))
        kick=C((0,0),(.35,-.33),(.78,-.22),(1,1))
        bob=.028-.07*dive
    elif clip=="attack":
        kick=C((0,1),(.24,1.20),(.72,.18),(1,0))
        dive=C((0,1),(.20,1.08),(.65,-.67),(1,-.55))
        flap=C((0,58),(.38,-45),(.76,-17),(1,16))
        tip=C((0,27),(.21,39),(.57,-35),(1,-7))
        bank=C((0,-12),(.35,15),(1,13)); bob=-.042+.075*(1-dive)
    else:
        phase=t*tau
        flap=16+43*sin(phase); tip=-7+21*(sin(phase-.9)+sin(.9))
        bank=13*(1-t);dive=-.55*(1-t);bob=.074*(1-t)+.028*cos(phase)
    set_pose(rig,h,"Cabinet",(pitch+23*dive,bank,3*sin(t*tau)),(0,0,bob))
    set_pose(rig,h,"Head",(-pitch*.66-15*dive,bank*-.53,-4*bank/15))
    set_pose(rig,h,"Tail",(-9-14*dive+flap*.12,0,-bank*.65))
    for sign,side in ((-1,"R"),(1,"L")):
        asym=sign*bank*.47
        set_pose(rig,h,"Wing"+side,(4*dive,-sign*(flap+asym),sign*(sweep+7*cos(t*tau))))
        set_pose(rig,h,"Primaries"+side,(0,-sign*tip,sign*(10+8*cos(t*tau))))
        # Legs tuck back during cruise. The loaded foot swings forward on
        # the last wind-up frames, reaching release before the downstroke.
        throw=kick if side=="R" else -.15*kick
        set_pose(rig,h,"Foot"+side,(52*tuck-96*throw,sign*(9*tuck-4*throw),sign*5*tuck))
        set_pose(rig,h,"Whisker"+side,(-5*dive+flap*.04,sign*(2+flap*.045),0))


def death(kind,t,h,rig):
    C=lambda *v: previous.curve(t,v)
    if kind=="fridge_bruiser":
        roll=C((0,0),(.11,-9),(.27,9),(.42,29),(.55,62),(.615,94),(.73,82),(.84,91),(.93,89),(1,89))
        pitch=C((0,0),(.28,-9),(.62,4),(1,3))
        slip=C((0,0),(.54,0),(.68,.105),(1,.124))
        set_pose(rig,h,"Root",(pitch,roll,-7*roll/90),(.16*(1-cos(radians(roll)))+slip,0,0))
        set_pose(rig,h,"Door",(0,0,C((0,0),(.25,-7),(.51,-65),(.64,-106),(.77,-32),(.89,-58),(1,-50))))
        for sign,side in ((-1,"R"),(1,"L")):
            set_pose(rig,h,"Foot"+side,((22 if sign>0 else -16)*sin(t*3.14),sign*17*sin(t*3.14),0))
            set_pose(rig,h,"Whisker"+side,(0,sign*C((0,0),(.61,12),(.72,-16),(1,-3)),0))
    elif kind=="el_frigorifico":
        drop=C((0,0),(.13,1),(.24,.56),(.41,1),(1,.9))
        angle=C((0,0),(.13,8),(.29,-10),(.43,-21),(.59,-48),(.71,-88),(.78,-81),(.87,-89),(1,-88))
        twist=C((0,0),(.21,-16),(.44,-39),(.71,-67),(1,-66))
        set_pose(rig,h,"Root",(angle,16*drop,twist),(.072*drop,.09*drop,0))
        set_pose(rig,h,"Cabinet",(0,0,-3*drop),(0,0,-.064*drop))
        for i in range(4):
            set_pose(rig,h,"Louver"+str(i),(C((0,0),(.2,-57),(.60,-43),(.71,-6),(.78,-29),(1,-6)),0,0))
        set_pose(rig,h,"Fan",(0,195*(1-(1-t)**3),0))
        set_pose(rig,h,"Gauge",(0,C((0,0),(.23,-63),(.7,-22),(.78,29),(1,20)),0))
        for sign,side in ((-1,"R"),(1,"L")):
            step=C((0,0),(.17,1),(.40,0),(.57,.25),(1,0))
            set_pose(rig,h,"Foot"+side,(sign*19*step+15*drop,sign*5*drop,0),(0,sign*.060*drop,.047*step if sign==1 else 0))
            set_pose(rig,h,"Whisker"+side,(0,sign*C((0,0),(.19,-11),(.7,24),(.8,-20),(.9,8),(1,-4)),0))
    elif kind=="chili_bandit":
        buckle=C((0,0),(.13,.2),(.38,1),(.61,.91),(1,.86))
        sidefall=C((0,0),(.17,-.07),(.40,.22),(.56,.52),(.76,1),(.85,.93),(1,.98))
        set_pose(rig,h,"Root",(5*buckle,101*sidefall,8*buckle),(.09*sidefall,.022*buckle,0))
        set_pose(rig,h,"Cabinet",(12*buckle,-5*buckle,-12*buckle))
        set_pose(rig,h,"Spine",(13*buckle,2*sidefall,14*buckle))
        set_pose(rig,h,"Head",(-12*buckle,21*sidefall,-11*sidefall))
        set_pose(rig,h,"Stem",(5*buckle,C((0,0),(.53,14),(.74,-54),(.84,-40),(1,-54)),0))
        for sign,side in ((-1,"R"),(1,"L")):
            set_pose(rig,h,"Leg"+side,((-22 if sign>0 else -61)*buckle,sign*10*buckle,0))
            set_pose(rig,h,"Knee"+side,((49 if sign>0 else 96)*buckle,0,0))
            set_pose(rig,h,"Foot"+side,(-33*buckle,sign*12*sidefall,0))
            brace=C((0,0),(.31,.15),(.51,1),(.69,.81),(1,.42))
            hand=Vector((sign*.17,-.071,.36))
            caught=Vector((sign*.22,-.12,.38))
            rest=Vector((sign*.082,-.16,.49 if sign>0 else .405))
            target=hand.lerp(caught,brace).lerp(rest,previous.ramp(.56,.84,t))
            limb(rig,h,("Arm"+side,"Elbow"+side,"Hand"+side),target,
                 (sign*(.23-.11*sidefall),-.09,.406),quat((38 if sign<0 else 14,0,11*buckle)))
            set_pose(rig,h,"Whisker"+side,(0,sign*13*buckle,0))
    else:
        roll=C((0,0),(.15,-29),(.36,-51),(.54,-43),(.665,-11),(.76,14),(.85,6),(1,7))
        pitch=C((0,5),(.17,-10),(.38,23),(.58,51),(.67,31),(.77,42),(.92,39),(1,39))
        skid=C((0,0),(.52,.10),(.665,.20),(.80,.35),(.94,.39),(1,.39))
        set_pose(rig,h,"Root",(pitch,roll,-23*min(1,t/.67)),(-.14*min(1,t/.67),-skid,0))
        set_pose(rig,h,"Head",(-pitch*.65,19*min(1,t/.70),12*min(1,t/.70)))
        set_pose(rig,h,"Tail",(-17*min(1,t/.67),0,roll*.3))
        for sign,side in ((-1,"R"),(1,"L")):
            wing=C((0,10),(.15,68 if sign>0 else -29),(.34,-48 if sign>0 else 27),(.55,15 if sign>0 else -14),(.665,38),(.81,-10),(1,-8))
            set_pose(rig,h,"Wing"+side,(0,-sign*wing,sign*(6+15*t)))
            set_pose(rig,h,"Primaries"+side,(0,-sign*(wing*.39+12*sin(t*tau)),sign*12*t))
            set_pose(rig,h,"Foot"+side,(53+24*sin(t*3.14),sign*8,0))


def animate(kind,clip,t,h,rig):
    if clip!="death" and kind not in ("pigeon_bomber","chili_bandit"):
        previous.motion(kind,clip,t,h,rig)
        return
    for b in rig.pose.bones:
        b.rotation_quaternion=Quaternion(); b.location=(0,0,0)
    if clip=="death": death(kind,t,h,rig)
    elif kind=="chili_bandit": bandit(clip,t,h,rig)
    else: flight(clip,t,h,rig)


if __name__=="__main__":
    for name in (sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else previous.MODELS):
        previous.build(name,previous.MODELS[name],sys.modules[__name__])
