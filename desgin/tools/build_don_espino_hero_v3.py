"""Build an editable, genuinely modeled hero-detail Don Espino in Blender 4.5.
No generated images are used as geometry or as a camera-facing image plane.
"""
from pathlib import Path
import sys, os, json, random, math
sys.path.insert(0,str(Path(__file__).resolve().parent))
from espino_v3_helpers import *
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'desgin/renders/don_espino/v3';OUT.mkdir(parents=True,exist_ok=True)
MODEL=ROOT/'desgin/character_models/DON_ESPINO_hero_v3.blend'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'desgin/character_models/DON_ESPINO_detail_v2.blend'))
scene=bpy.context.scene
# Keep the user's defining torso, hat and boot shapes; replace unfinished parts.
keep=['Cube','Cube.001','Cube.002','Cube.003','Cube.011','Cube.012']
source={n:world_mesh(bpy.data.objects[n]) for n in keep}
for o in list(bpy.data.objects):
    if o.name not in keep:bpy.data.objects.remove(o,do_unlink=True)
for c in list(bpy.data.collections):
    if not c.objects and not c.children:bpy.data.collections.remove(c)
BIND={};PARTS={}
def tag(o,bone,part=None):
    BIND[o.name]=bone
    if part:PARTS.setdefault(part,[]).append(o)
    return o

def skin_material():
    m,nt,bs=mat('Cactus | wax, pores, mottling',(.17,.36,.032),.47)
    v=mapping(nt,(1,1,.65));n=noise(nt,7,4,vector=v)
    nt.links.new(ramp(nt,n.outputs['Fac'],[(.115,.275,.024),(.19,.38,.045)]),bs.inputs['Base Color'])
    pore=nt.nodes.new('ShaderNodeTexVoronoi');pore.inputs['Scale'].default_value=450;nt.links.new(v,pore.inputs['Vector'])
    bn=bump(nt,bs,pore.outputs['Distance'],.0004,.32)
    micro=noise(nt,400,2,vector=v);bump(nt,bs,micro.outputs['Fac'],.00025,.23,bn)
    bs.inputs['Subsurface Weight'].default_value=.035;bs.inputs['Subsurface Radius'].default_value=(.4,.7,.2)
    bs.inputs['Coat Weight'].default_value=.035;bs.inputs['Coat Roughness'].default_value=.55;bs.inputs['Specular IOR Level'].default_value=.27
    return m
skin=skin_material()
felt,nt,bs=mat('Hat | warm crimped felt',(.20,.072,.029),.86)
v=mapping(nt);n=noise(nt,12,4,vector=v)
nt.links.new(ramp(nt,n.outputs['Fac'],[(.075,.022,.008),(.20,.067,.030)]),bs.inputs['Base Color'])
fine=noise(nt,300,3,vector=v);bump(nt,bs,fine.outputs['Fac'],.0013,.45);bs.inputs['Sheen Weight'].default_value=.22;bs.inputs['Sheen Tint'].default_value=(.19,.065,.025,1);bs.inputs['Specular IOR Level'].default_value=.2
fiber=mat('Hat | individual felt fibers',(.24,.09,.04),.9)[0]
bandmat=leather('Hatband | dark saddle leather',(.045,.015,.006))
bootsmat=leather('Boots | worn ochre leather',(.32,.15,.043))
solemat=leather('Boots | layered sole leather',(.055,.026,.010))
beltmat=leather('Belt | honey saddle leather',(.28,.11,.022))
cloth=textile('Shorts | woven burnt-orange canvas',(.36,.095,.021),45,.8)
thread=mat('Stitch | warm flax thread',(.68,.41,.16),.85)[0]
darkthread=mat('Stitch | inset seam shadow',(.065,.025,.009),.85)[0]
brass=mat('Metal | aged brass',(.58,.32,.067),.27,.82)[0]
silver=mat('Metal | engraved gun steel',(.5,.56,.62),.24,.88)[0]
steelDark=mat('Metal | dark blued steel',(.075,.095,.115),.3,.85)[0]
engrave=mat('Metal | engraved channel shadow',(.025,.033,.039),.34,.8)[0]
wood=leather('Revolver | walnut grip',(.15,.043,.015))
# Elongated procedural wood grain.
nt=wood.node_tree;bs=nt.nodes.get('Principled BSDF');v=mapping(nt,(1,12,.23));grain=noise(nt,70,3,vector=v)
nt.links.new(ramp(nt,grain.outputs['Fac'],[(.065,.015,.005),(.23,.072,.023)]),bs.inputs['Base Color']);bump(nt,bs,grain.outputs['Fac'],.00065,.35)
ivory=mat('Cactus | ivory spines',(.69,.56,.28),.6)[0]
areolemat=mat('Cactus | corky areoles',(.32,.29,.10),.78)[0]
hair,nt,bs=mat('Moustache | grooved chestnut locks',(.10,.035,.012),.52)
v=mapping(nt,(2,160,1),uv=True);n=noise(nt,2,2,vector=v)
nt.links.new(ramp(nt,n.outputs['Fac'],[(.035,.011,.004),(.13,.050,.016)]),bs.inputs['Base Color']);bump(nt,bs,n.outputs['Fac'],.00065,.22)
bs.inputs['Coat Weight'].default_value=0;bs.inputs['Anisotropic'].default_value=.15;bs.inputs['Specular IOR Level'].default_value=.32
hairline=mat('Moustache | fine raised strand highlights',(.15,.057,.017),.46)[0]
black=mat('Eyes | polished obsidian',(.004,.006,.003),.16)[0]
bs=black.node_tree.nodes.get('Principled BSDF');bs.inputs['Coat Weight'].default_value=.45
radioMat=leather('Radio | charcoal casing',(.052,.064,.067))
buttonmat=mat('Radio | orange buttons',(.65,.12,.022),.4)[0]
paper=mat('Packet | aged cream paper',(.68,.57,.36),.76)[0]
red=mat('Packet | vermilion sleeve',(.60,.065,.035),.65)[0]

# Densely sculpted original torso, with longitudinal ribs in actual geometry.
body=source['Cube'];body.name='Cactus torso — sculpted botanical ribs'
body.data.materials.clear();body.data.materials.append(skin)
rem=body.modifiers.new('Clean continuous cactus surface','REMESH');rem.mode='VOXEL';rem.voxel_size=.012;rem.use_smooth_shade=True
bpy.context.view_layer.objects.active=body;bpy.ops.object.modifier_apply(modifier=rem.name)
sm=body.modifiers.new('Organic surface smoothing','SMOOTH');sm.factor=.8;sm.iterations=3;bpy.ops.object.modifier_apply(modifier=sm.name)
subd(body,1,True)
for v in body.data.vertices:
    p=v.co;r=math.hypot(p.x,p.y-.018)
    if r>.05:
        a=math.atan2(p.y-.018,p.x)
        fade=min(1,max(0,(p.z-1.38)/.12))*min(1,max(0,(3.22-p.z)/.16))
        ridge=(.0105*cos(15*a+.18*sin(p.z*2))+.0015*cos(30*a+.3))*fade
        irregular=.0015*noise_vector(p*25).x
        p.x+=(ridge+irregular)*p.x/r;p.y+=(ridge+irregular)*(p.y-.018)/r
bm=bmesh.new();bm.from_mesh(body.data);bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,1.46),plane_no=(0,0,1),clear_inner=True,clear_outer=False);bm.to_mesh(body.data);bm.free();body.data.update();recalc(body)
tag(body,'torso','body')

# Sculpted moustache lobes. Grooves are part of the mesh, following curved locks.
for sign in [-1,1]:
    verts=[];faces=[];uv=[];N=160;K=384
    centers=[]
    for i in range(N+1):
        t=i/N
        c=bezier((.014,-.55,2.525),(.17,-.61,2.66),(.42,-.61,2.41),(.615,-.515,2.14),t);c.x*=sign;centers.append(c)
    for i,c in enumerate(centers):
        t=i/N;tan=(centers[min(i+1,N)]-centers[max(i-1,0)]).normalized();front=Vector((0,-1,0));up=tan.cross(front).normalized()
        if up.z<0:up=-up
        envelope=(sin(pi*(.08+.92*t))**.66 if t<1 else .001)
        rz=.164*envelope;rd=.109*envelope
        for j in range(K):
            a=2*pi*j/K
            flutes=.0012*cos(72*a+.45*sin(t*3))+.0005*cos(113*a+t*1.4)+.0007*cos(13*a+t*2)
            q=c+up*((rz+flutes)*cos(a))+front*((rd+flutes)*sin(a))
            verts.append(q);uv.append((t,j/K))
    for i in range(N):
        for j in range(K):faces.append((i*K+j,i*K+(j+1)%K,(i+1)*K+(j+1)%K,(i+1)*K+j))
    faces.extend([tuple(range(K-1,-1,-1)),tuple(N*K+j for j in range(K))])
    tag(mesh('Moustache sculpt '+str(sign),verts,faces,hair,uv),'head','moustache')
# Original blocky brow silhouettes, subdivided and covered with flow-aligned grooves.
for idx,name in enumerate(['Cube.002','Cube.003']):
    o=source[name];o.name='Sculpted eyebrow '+str(idx);o.data.materials.clear();o.data.materials.append(hair);subd(o,3,True)
    sign=-1 if idx==0 else 1
    for v in o.data.vertices:
        p=v.co
        # Fine diagonal channels cut across the front surface of the brow.
        if p.y<-.34:p.y+=.0018*sin((p.z+.32*abs(p.x))*850)+.0007*sin((p.z+.32*abs(p.x))*1500)
    o.data.update();tag(o,'head','moustache')
for s in [-1,1]:
    tag(ellipsoid('Black eye '+str(s),(s*.115,-.495,2.665),(.047,.045,.065),black,40,28),'head','eyes')

# The original asymmetric hat shape stays identifiable under real felt fibers.
hat=source['Cube.001'];hat.name='Sheriff hat — source silhouette, refined felt'
hat_indices=[p.material_index for p in hat.data.polygons]
hat.data.materials.clear();hat.data.materials.append(felt);hat.data.materials.append(bandmat)
for p,i in zip(hat.data.polygons,hat_indices):p.material_index=i
subd(hat,3,True);tag(hat,'head','hat')
# Trace actual material boundaries, rather than guessing rings around the hat.
band_edges={}
for p in hat.data.polygons:
    if p.material_index!=1:continue
    for edge in p.edge_keys:band_edges[edge]=band_edges.get(edge,0)+1
edges=[e for e,n in band_edges.items() if n==1];adj={}
for a,b in edges:adj.setdefault(a,[]).append(b);adj.setdefault(b,[]).append(a)
loops=[];unused=set(tuple(sorted(e)) for e in edges)
while unused:
    a,b=next(iter(unused));loop=[a,b];unused.remove(tuple(sorted((a,b))))
    while True:
        options=[v for v in adj.get(loop[-1],[]) if tuple(sorted((v,loop[-1]))) in unused]
        if not options:break
        nxt=options[0];unused.remove(tuple(sorted((loop[-1],nxt))));loop.append(nxt)
        if nxt==loop[0]:break
    if len(loop)>10:loops.append(loop)
for loop in loops:
    pts=[hat.data.vertices[i].co.copy() for i in loop];avgz=sum(p.z for p in pts)/len(pts);midz=3.20
    seam=[]
    for p in pts:
        a=math.atan2(p.y,p.x);q=radial(hat,a,p.z+(.013 if avgz<midz else -.013),.0025,1)
        if q is not None:seam.append(q)
    if len(seam)>5:
        tag(paths('Hatband edge piping',[pts],.0025,bandmat),'head','hat')
        tag(stitches('Hatband sewn edge',seam,.020,.00145,thread),'head','hat')
# Crimped, short fibers sampled over the genuine felt surface.
hat.data.calc_loop_triangles();tris=[t for t in hat.data.loop_triangles if hat.data.polygons[t.polygon_index].material_index==0]
weights=[t.area for t in tris];random.seed(2026);lines=[]
for tri in random.choices(tris,weights,k=70000):
    a,b,c=[hat.data.vertices[i].co for i in tri.vertices];u=random.random();v=random.random()
    if u+v>1:u=1-u;v=1-v
    p=a+u*(b-a)+v*(c-a);n=tri.normal.normalized();t=n.cross(Vector((.13,.71,.36))).normalized();b=n.cross(t)
    phi=random.uniform(0,2*pi);d=t*cos(phi)+b*sin(phi);length=random.uniform(.006,.014)
    lines.append([p-n*.0002,p+d*length*.35+n*.0005,p+d*length*.70+b*.001+n*.0009,p+d*length+n*.0002])
tag(paths('Hat felt — 70000 individual crimped fibers',lines,.00040,fiber,1),'head','hat')
# Faceted sheriff badge, five points and a raised center.
outline=[]
for j in range(10):
    a=pi/2+j*pi/5;r=.137 if j%2==0 else .060
    outline.append((.27+r*cos(a),3.225+r*sin(a)))
star=prism('Faceted brass sheriff star',outline,.012,brass);star.location.y=-.512;tag(star,'head','hat')
# Ridge facets catch the studio light.
vs=[(.27,-.545,3.225)]+[(x,-.526,z) for x,z in outline]
fs=[(0,j+1,(j+1)%10+1) for j in range(10)]
tag(mesh('Sheriff badge raised facets',vs,fs,brass),'head','hat')
print('Built torso, sculpted face and felt hat',flush=True)

# Tailored shorts: a continuous front/back garment with two open leg hems.
verts=[];faces=[];uv=[];NX=100;NZ=46
for side in [-1,1]:
    for j in range(NZ+1):
        v=j/NZ
        for i in range(NX+1):
            t=-1+2*i/NX
            bottom=1.075+.145*math.exp(-(t/.16)**2)
            z=bottom+(1.55-bottom)*v
            width=.52-.018*sin(pi*v)
            x=t*width
            roundness=max(0,1-abs(t)**3.7)**.5
            lower=.34*min(1,abs(t)*5)
            depth=lower*(1-v)**2+.505*(1-(1-v)**2)
            y=side*depth*roundness
            fold=.003*sin(21*t+8*v)*sin(pi*v)**2+.002*sin(43*t-9*v)*math.exp(-((v-.16)/.14)**2)
            fold+=.004*sin(18*v+9*t)*math.exp(-((abs(t)-.60)/.18)**2)*sin(pi*v)
            y+=side*fold*roundness
            verts.append((x,y,z));uv.append(((t+1)*.5,v))
size=(NX+1)*(NZ+1)
for side in range(2):
    off=side*size
    for j in range(NZ):
        for i in range(NX):
            a=off+j*(NX+1)+i
            face=(a,a+1,a+NX+2,a+NX+1)
            faces.append(face if side==0 else tuple(reversed(face)))
pants=mesh('Tailored shorts — crotch, two leg openings and sculpted folds',verts,faces,cloth,uv)
bm=bmesh.new();bm.from_mesh(pants.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(pants.data);bm.free()
solid=pants.modifiers.new('Canvas thickness','SOLIDIFY');solid.thickness=.009
subd(pants,1);tag(pants,'pelvis','shorts')
# Physical fly, pocket welt seams and hem stitching, seated on the cloth.
for x in [-.018,.018]:
    pts=[project(pants,x,z,.005) for z in [1.25+k*.002 for k in range(129)]];pts=[p for p in pts if p is not None]
    tag(paths('Fly seam piping',[pts],.0021,darkthread),'pelvis','shorts')
    tag(stitches('Fly lockstitch',pts,.016,.0013,thread),'pelvis','shorts')
for s in [-1,1]:
    pts=[]
    for k in range(100):
        t=k/99;x=s*(.17+.28*t);z=1.43-.11*sin(t*pi/2);p=project(pants,x,z,.006)
        if p is not None:pts.append(p)
    tag(paths('Slanted front pocket welt',[pts],.0018,beltmat),'pelvis','shorts')
    tag(stitches('Front pocket saddle stitching',[p+Vector((0,-.002,-.008)) for p in pts],.018,.0014,thread),'pelvis','shorts')
    # Top-stitched rolled hems follow the two actual open boundaries.
    for v in [.04,.10]:
        pts=[]
        for side in [-1,1]:
            ts=[(k/100 if s==1 else -1+k/100) for k in range(101)]
            if side==1:ts.reverse()
            for t in ts:
                bottom=1.075+.145*math.exp(-(t/.16)**2);z=bottom+(1.55-bottom)*v
                x=t*(.52-.018*sin(pi*v));roundness=max(0,1-abs(t)**3.7)**.5
                lower=.34*min(1,abs(t)*5);depth=lower*(1-v)**2+.505*(1-(1-v)**2)
                y=side*(depth*roundness+.007)
                pts.append(Vector((x,y,z)))
        tag(paths('Rolled shorts hem piping',[pts],.0035,cloth),'pelvis','shorts')
        tag(stitches('Rolled shorts hem stitching',pts,.018,.00145,thread),'pelvis','shorts')
# Continuous leather belt follows the same cross-section as the tailored waistband.
def belt_xy(a,inset=0):
    return ((.547+inset)*cos(a),(.531+inset)*(1 if sin(a)>=0 else -1)*sqrt(max(0,1-abs(cos(a))**3.7)))
N=192;bv=[];bf=[]
for z,radd in [(1.43,0),(1.55,0),(1.43,-.012),(1.55,-.012)]:
    for j in range(N):
        a=2*pi*j/N;x,y=belt_xy(a,radd)
        bv.append((x,y,z))
for j in range(N):
    k=(j+1)%N
    bf.extend([(j,k,N+k,N+j),(2*N+j,3*N+j,3*N+k,2*N+k),(N+j,N+k,3*N+k,3*N+j),(j,2*N+j,2*N+k,k)])
belt=mesh('Belt — solid leather strap',bv,bf,beltmat);bevel(belt,.003,2);tag(belt,'pelvis','belt')
for z in [1.445,1.535]:
    pts=[(*belt_xy(a,.0025),z) for a in [2*pi*k/700 for k in range(701)]]
    tag(stitches('Belt perimeter saddle stitches',pts,.021,.0016,thread),'pelvis','belt')
for s in [-1,1]:
    for k in range(3):
        x=s*(.16+.046*k);y=-.533*sqrt(max(0,1-abs(x/.547)**3.7))-.001
        tag(ellipsoid('Belt adjustment hole',(x,y,1.49),(.0055,.0018,.0055),darkthread,12,8),'pelvis','belt')
# Brass buckle frame and pin; open center with leather showing through.
outline=[(-.102,-.54,1.43),(-.102,-.54,1.55),(.102,-.54,1.55),(.102,-.54,1.43),(-.102,-.54,1.43)]
tag(paths('Buckle — cast brass frame',[outline],.009,brass),'pelvis','belt')
tag(paths('Buckle — prong',[[(-.09,-.555,1.49),(.035,-.555,1.49)]],.005,brass),'pelvis','belt')
for a in [pi*.15,pi*.85,pi*1.15,pi*1.85]:
    p=Vector((*belt_xy(a,.006),1.49))
    o=cube('Canvas belt loop',p,(.055,.025,.16),cloth,.008);o.rotation_euler.z=a-pi/2;tag(o,'pelvis','shorts')

# Detailed boots retain the original hand-sculpted silhouettes.
boot_objects={}
for s,name in [(1,'Cube.011'),(-1,'Cube.012')]:
    boot=source[name];boot.name='Cowboy boot leather '+str(s)
    coords=[v.co.copy() for v in boot.data.vertices];cx=(min(p.x for p in coords)+max(p.x for p in coords))/2
    cy=(min(p.y for p in coords)+max(p.y for p in coords))/2
    for v in boot.data.vertices:
        p=v.co;p.x=(p.x-cx)*1.42+s*.405;p.y=(p.y-.04)*.86+.02;p.z+=.055
    boot.data.materials.clear();boot.data.materials.append(bootsmat);subd(boot,2,True)
    for v in boot.data.vertices:
        p=v.co;theta=math.atan2(p.y-.035,p.x-s*.405)
        wrinkle=.003*sin(110*p.z+3*sin(theta))*math.exp(-((p.z-.31)/.09)**2)
        p.x+=wrinkle*cos(theta);p.y+=wrinkle*sin(theta)
        if p.y<-.12 and p.z>.14:
            influence=max(0,min(1,(-.12-p.y)/.16))
            target=.145+.025*max(0,1-((p.x-s*.405)/.17)**2)+.18*(p.y+.36)**2
            p.z-=max(0,p.z-target)*influence
    boot.data.update();recalc(boot);tag(boot,'foot.L' if s==1 else 'foot.R','boots');boot_objects[s]=boot
    bone=BIND[boot.name]
    # Convex projected footprint for a stitched welt and layered outsole.
    points=sorted(set((round(v.co.x,5),round(v.co.y,5)) for v in boot.data.vertices))
    def cross2(o,a,b):return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    lower=[]
    for p in points:
        while len(lower)>=2 and cross2(lower[-2],lower[-1],p)<=0:lower.pop()
        lower.append(p)
    upper=[]
    for p in reversed(points):
        while len(upper)>=2 and cross2(upper[-2],upper[-1],p)<=0:upper.pop()
        upper.append(p)
    hull=lower[:-1]+upper[:-1];hullpts=catmull([(x,y,0) for x,y in hull]+[(hull[0][0],hull[0][1],0),(hull[1][0],hull[1][1],0)],180)
    # The boot's upward toe has a matching curved sole, rather than a floating slab.
    from mathutils.kdtree import KDTree
    kd=KDTree(len(boot.data.vertices))
    for v in boot.data.vertices:kd.insert((v.co.x,v.co.y,0),v.index)
    kd.balance()
    outline=[]
    for p in hullpts:
        near=[boot.data.vertices[i] for _,i,_ in kd.find_n((p.x,p.y,0),24)]
        top=min(v.co.z for v in near)+.014
        top=max(.075,min(.15,top));outline.append((p.x,p.y,top))
    sv=[]
    for dz in [0,-.047]:
        for x,y,z in outline:sv.append((x+(x-s*.405)*.025,y,z+dz))
    Nn=len(outline);sf=[(j,(j+1)%Nn,(j+1)%Nn+Nn,j+Nn) for j in range(Nn)]
    sf.append(tuple(range(Nn,2*Nn)))
    sole=mesh('Layered leather outsole '+str(s),sv,sf,solemat);bevel(sole,.004,3);tag(sole,bone,'boots')
    welt=[Vector(p)+Vector((0,0,.003)) for p in outline]
    tag(paths('Raised boot welt '+str(s),[welt],.005,bootsmat),bone,'boots')
    tag(stitches('Boot welt stitching '+str(s),welt,.014,.0017,thread),bone,'boots')
    heel=cube('Stacked heel '+str(s),(s*.405,.105,.040),(.23,.18,.080),solemat,.018);tag(heel,bone,'boots')
    for z in [.012,.034,.056]:
        tag(cube('Heel leather layer',(s*.405,.105,z),(.232,.182,.020),solemat,.008),bone,'boots')
    # Shaft rim and saddle stitching.
    ztop=max(v.co.z for v in boot.data.vertices)
    cuff=[]
    for k in range(181):
        a=2*pi*k/180;origin=Vector((s*.405+cos(a)*1,sin(a)*1+.025,ztop-.015))
        hit,p,n,_=boot.ray_cast(origin,Vector((-cos(a),-sin(a),0)))
        if hit:cuff.append(p+n*.003)
    if len(cuff)>6:
        tag(paths('Rolled boot collar',[cuff],.0045,bootsmat),bone,'boots')
        tag(stitches('Boot collar stitches',[p+Vector((0,0,-.009)) for p in cuff],.015,.0015,thread),bone,'boots')
    # Five clean feather-like embroidery strokes, projected onto the leather vamp.
    ornament=[]
    for flip in [-1,1]:
        for controls in [
            [(0,-.285),(.085,-.30),(.09,-.22),(.012,-.23)],
            [(0,-.235),(.067,-.25),(.075,-.18),(0,-.19)]]:
            pts=[]
            c=[(s*.405+flip*x,y,0) for x,y in controls]
            for k in range(65):
                q=bezier(*c,k/64)
                hit,p,n,_=boot.ray_cast(Vector((q.x,q.y,1)),Vector((0,0,-1)))
                if hit:pts.append(p+n*.0018)
            ornament.append(pts)
    pts=[]
    for k in range(50):
        y=-.295+.125*k/49
        hit,p,n,_=boot.ray_cast(Vector((s*.405,y,1)),Vector((0,0,-1)))
        if hit:pts.append(p+n*.0018)
    ornament.append(pts)
    tag(paths('Western toe embroidery',ornament,.0017,thread),bone,'boots')
    for dx in [-.085,.085]:
        pts=[]
        for k in range(80):
            z=.23+.27*k/79;x=s*.405+dx*(.8+.2*sin(k/79*pi))
            p=project(boot,x,z,.003)
            if p is not None:pts.append(p)
        if len(pts)>2:
            tag(paths('Boot front panel seam',[pts],.0032,bootsmat),bone,'boots')
            tag(stitches('Boot panel saddle stitch',pts,.016,.00135,thread),bone,'boots')
    # Small reinforced pull tab on the outer shaft.
    tab=cube('Boot pull tab',(s*.405+s*.13,.045,.46),(.027,.054,.105),bootsmat,.009);tag(tab,bone,'boots')
print('Built tailored shorts, belt and layered stitched boots',flush=True)

# Posed anatomical chains, with slim cactus limbs and fully modeled hands.
joints={
 'arm.R':[(-.49,.01,2.10),(-.69,-.12,1.76),(-.68,-.35,1.47)],
 'arm.L':[(.49,.01,2.10),(.89,-.035,1.88),(.59,-.43,1.70)],
 'leg.R':[(-.255,.025,1.15),(-.34,.01,.79),(-.405,.025,.42)],
 'leg.L':[(.255,.025,1.15),(.34,.01,.79),(.405,.025,.42)]}
for key,chain in joints.items():
    pts=catmull(chain,100);isarm=key.startswith('arm');side=key[-1]
    radii=[]
    for k in range(len(pts)):
        t=k/(len(pts)-1)
        r=(.055-.013*t if isarm else .062-.008*t)+.007*math.exp(-((t-.5)/.08)**2)
        radii.append(r)
    o=tube('Continuous posed '+key,pts,radii,skin,32)
    BIND[o.name]={'chain':key,'count':100,'sides':32};PARTS.setdefault('limbs',[]).append(o)

for key,chain in joints.items():
    if key.startswith('leg'):
        side=key[-1];knee=Vector(chain[1])+Vector((0,-.015,0))
        tag(ellipsoid('Cactus knee joint '+side,knee,(.065,.058,.073),skin,28,20),'shin.'+side,'limbs')

# Revolver: modeled mechanical separation, hollow muzzle, six real chamber mouths,
# a fluted cylinder, trigger guard, walnut grips, hardware and ornamental channels.
gun_start=set(bpy.data.objects.keys())
frame=prism('Revolver solid frame',[(-.19,.17),(.16,.17),(.25,.10),(.21,-.09),(.13,-.14),(-.05,-.13),(-.18,-.02)],.060,silver)
# The cylinder covers the center of the frame; separate dark gaps show its movement.
disk_x('Cylinder axle',(-.065,0,.08),.028,.31,steelDark)
# Fluting is actual radial geometry with six scallops.
gv=[];gf=[];NN=192;LL=20
for i in range(LL+1):
    x=-.20+.255*i/LL
    for j in range(NN):
        a=2*pi*j/NN
        rad=.102-.0085*max(0,cos(6*a))**8*sin(pi*i/LL)**.4
        gv.append((x,rad*sin(a),.08+rad*cos(a)))
for i in range(LL):
    for j in range(NN):gf.append((i*NN+j,i*NN+(j+1)%NN,(i+1)*NN+(j+1)%NN,(i+1)*NN+j))
mesh('Six-fluted revolver cylinder',gv,[tuple(reversed(f)) for f in gf],silver)
for x in [-.203,.058]:
    disk_x('Cylinder end plate',(x,0,.08),.101,.007,silver)
    for j in range(6):
        a=2*pi*j/6;y=.059*sin(a);z=.08+.059*cos(a)
        disk_x('Chamber bore mouth',(x+(-.004 if x<0 else .004),y,z),.023,.002,steelDark)
        if x>0:disk_x('Cartridge rim',(x+.006,y,z),.018,.002,brass)
# Annular barrel, with true inner wall rather than a painted muzzle.
vv=[];ff=[];M=80
for x,r in [(-.69,.043),(-.21,.043),(-.69,.025),(-.23,.025)]:
    for j in range(M):a=2*pi*j/M;vv.append((x,r*sin(a),.105+r*cos(a)))
for j in range(M):
    k=(j+1)%M;ff.extend([(j,k,M+k,M+j),(2*M+j,3*M+j,3*M+k,2*M+k),(j,2*M+j,2*M+k,k)])
mesh('Hollow revolver barrel',vv,[tuple(reversed(f)) for f in ff],silver)
cube('Top barrel rib',(-.455,0,.144),(.48,.030,.018),silver,.004)
cube('Front sight',(-.635,0,.172),(.042,.022,.037),steelDark,.004)
cube('Rear sight',(.115,0,.191),(.060,.025,.023),steelDark,.003)
tube('Ejector housing',[(-.62,0,.045),(-.22,0,.045)],.021,silver,24)
# Open curved trigger guard and curved trigger.
guard=catmull([(-.10,0,-.052),(-.15,0,-.15),(-.095,0,-.225),(.055,0,-.225),(.13,0,-.13),(.10,0,-.07)],90)
paths('Open steel trigger guard',[guard],.010,silver,3)
paths('Curved trigger',[[(-.035,0,-.08),(-.015,0,-.12),(-.023,0,-.162),(-.055,0,-.18)]],.009,steelDark,3)
prism('Hammer',[(.105,.15),(.14,.24),(.20,.26),(.24,.24),(.185,.205),(.18,.14)],.016,silver)
# Full grip frame plus layered wood panels.
grip_outline=[(.11,-.065),(.215,-.08),(.29,-.25),(.285,-.36),(.12,-.345),(.095,-.29),(.14,-.20)]
prism('Grip metal backstrap',grip_outline,.044,silver)
for sign in [-1,1]:
    panel=prism('Walnut grip panel '+str(sign),[(.122,-.095),(.20,-.104),(.268,-.25),(.266,-.336),(.139,-.324),(.118,-.285),(.157,-.204)],.008,wood);panel.location.y=sign*.050
    for x,z in [(.17,-.145),(.205,-.29)]:
        o=ellipsoid('Grip screw',(x,sign*.060,z),(.012,.0025,.012),silver,20,12)
        paths('Grip screw slot',[[(x-.007,sign*.063,z),(x+.007,sign*.063,z)]],.0013,engrave,1)
    # Cut-looking diamond checkering, made of fine recessed-color geometry.
    lines=[]
    for j in range(10):
        z=-.215-j*.008
        lines.append([(.165,sign*.059,z),(.235,sign*.059,z-.035)])
        lines.append([(.165,sign*.059,z-.035),(.235,sign*.059,z)])
    paths('Walnut diamond checkering '+str(sign),lines,.00035,engrave,1)
# Scrollwork on each frame side, as finely inset geometric channels.
for sign in [-1,1]:
    lines=[]
    for cx,cz,rr in [(.13,.06,.042),(.17,-.015,.032),(-.12,-.045,.026)]:
        pts=[]
        for k in range(90):
            t=k/89;ang=pi*.5+t*pi*3;r=rr*(1-.85*t)
            pts.append((cx+r*cos(ang),sign*.061,cz+r*sin(ang)))
        lines.append(pts)
    for k in range(14):
        x=.075+k*.009;lines.append([(x,sign*.061,.12),(x+.0045,sign*.061,.136),(x+.009,sign*.061,.12)])
    paths('Engraved frame scrolls '+str(sign),lines,.00040,engrave,2)
    for x,z in [(.08,-.06),(.215,.065),(-.145,.12)]:
        ellipsoid('Frame pin',(x,sign*.062,z),(.009,.002,.009),steelDark,16,8)
# Engraving on the long barrel is offset onto its visible front face.
lines=[]
for k in range(7):
    x=-.61+k*.047
    lines.append([(x,-.041,.105),(x+.012,-.044,.117),(x+.025,-.041,.105),(x+.037,-.044,.094)])
lines=[[(x,-sqrt(max(.00001,.043**2-(z-.105)**2))-.0004,z) for x,y,z in line] for line in lines]
paths('Barrel ornamental engraving',lines,.00035,engrave,2)
gunparts=[o for o in bpy.data.objects if o.name not in gun_start]
G=Matrix.Translation(Vector((-.95,-.35,1.44)))@Matrix.Rotation(-.64,4,'Y')
for o in gunparts:o.matrix_world=G@o.matrix_world;tag(o,'weapon.R','revolver')
# Right hand wraps the actual wood grip: fingertips and thumb have separate surfaces.
palm_local=Vector((.21,.002,-.055));palm_world=G@palm_local
palm=ellipsoid('Right gripping palm',palm_world,(.074,.049,.10),skin,32,22);palm.rotation_euler.y=-.64;tag(palm,'hand.R','hands')
for j,z in enumerate([-.135,-.198,-.261]):
    xx=.168+(.025*j)
    pts=catmull([(xx+.07,.032,z+.024),(xx+.073,-.018,z),(xx+.035,-.073,z-.009),(xx-.025,-.069,z),(xx-.04,-.02,z+.012)],44)
    pts=[G@p for p in pts]
    rr=[.019*(.83+.17*sin(pi*k/(len(pts)-1))) for k in range(len(pts))]
    tag(tube('Right curled finger '+str(j),pts,rr,skin,20),'finger.R.'+str(j),'hands')
thumb=catmull([(.17,-.035,.025),(.105,-.074,-.018),(.092,-.076,-.075),(.13,-.070,-.105)],40)
tag(tube('Right opposed thumb',[G@p for p in thumb],[.024-.007*k/39 for k in range(40)],skin,20),'thumb.R','hands')
# Left hand rests over the belt radio, with separated tapering fingers.
lp=(.565,-.47,1.68)
tag(ellipsoid('Left palm resting at hip',lp,(.065,.045,.085),skin,32,20),'hand.L','hands')
for j in range(3):
    x=.52+j*.039
    pts=catmull([(x,-.49,1.69),(x+.005,-.515,1.61),(x+.025,-.505,1.55),(x+.04,-.47,1.565)],40)
    tag(tube('Left draped finger '+str(j),pts,[.017-.004*k/39 for k in range(40)],skin,18),'finger.L.'+str(j),'hands')
pts=catmull([(.60,-.455,1.72),(.65,-.47,1.68),(.66,-.49,1.63)],30)
tag(tube('Left thumb',pts,[.022-.007*k/29 for k in range(30)],skin,18),'thumb.L','hands')
print('Built posed limbs, gripping hands and engraved six-shot revolver',flush=True)

# Radio and folded packet, rebuilt with rounded edges and visible construction.
rad=cube('Radio rounded casing',(.505,-.423,1.56),(.16,.09,.29),radioMat,.021);tag(rad,'pelvis','accessories')
for name,loc,sc,ma in [
 ('Radio speaker',(.505,-.474,1.60),(.055,.005,.065),steelDark),
 ('Radio tuning knob',(.555,-.42,1.718),(.016,.016,.018),radioMat)]:
    tag(ellipsoid(name,loc,sc,ma,24,16),'pelvis','accessories')
for j in range(6):
    z=1.575+j*.009
    tag(paths('Radio speaker grille',[[(.47,-.481,z),(.535,-.481,z)]],.0011,radioMat),'pelvis','accessories')
for i in range(2):
    for j in range(3):tag(cube('Radio orange keypad',(.467+j*.030,-.476,1.475+i*.028),(.021,.009,.018),buttonmat,.003),'pelvis','accessories')
pts=[(.485,-.42,1.70),(.482,-.42,1.91)]
tag(tube('Radio flexible antenna',pts,[.007,.004],radioMat,16),'pelvis','accessories')
tag(ellipsoid('Radio antenna cap',pts[-1],(.006,.006,.007),radioMat,16,10),'pelvis','accessories')
packet=cube('Folded cream packet',(.315,-.49,1.43),(.145,.055,.20),paper,.007);packet.rotation_euler.y=-.11;tag(packet,'pelvis','accessories')
tag(cube('Packet red upper sleeve',(.315,-.492,1.512),(.146,.059,.055),red,.003),'pelvis','accessories')
# Folded paper triangles and scored fold edges.
tag(mesh('Packet folded envelope flap',[(.247,-.523,1.46),(.315,-.528,1.525),(.383,-.523,1.46),(.315,-.529,1.405)],[(0,1,2,3)],paper),'pelvis','accessories')
tag(paths('Packet folds',[[ (.247,-.525,1.38),(.315,-.529,1.44),(.383,-.525,1.38)]],.0011,darkthread),'pelvis','accessories')
# The cigarette remains a small unlabelled character accessory.
white=mat('Cigarette | paper',(.73,.72,.62),.83)[0]
filtermat=mat('Cigarette | filter',(.52,.23,.055),.82)[0]
ash=mat('Cigarette | ash',(.16,.15,.13),.96)[0]
p0=Vector((.07,-.64,2.425));p1=Vector((.17,-.70,2.24));pm=p0.lerp(p1,.28)
tag(tube('Cigarette filter',[p0,pm],.010,filtermat,20),'head','accessories')
tag(tube('Cigarette paper',[pm,p1],.009,white,20),'head','accessories')
tag(ellipsoid('Cigarette ash tip',p1,(.009,.009,.011),ash,16,10),'head','accessories')

# Surface-aligned corky areoles and individually curved tapering ivory spines.
random.seed(52);cluster_count=0
for row,z in enumerate([1.64,1.84,2.04,2.24,2.45,2.67,2.87,3.06]):
    for j in range(14):
        a=2*pi*(j+.5*(row%2))/14
        if sin(a)<-.4 and z>2.40:continue
        p=radial(body,a,z,.001)
        if p is None:continue
        n=Vector((cos(a),sin(a),.06)).normalized();t=n.cross(Vector((0,0,1))).normalized();b=n.cross(t)
        bone='head' if z>2.30 else 'torso'
        base=ellipsoid('Corky cactus areole',p,(.013,.013,.008),areolemat,16,10);base.rotation_euler=n.to_track_quat('Z','Y').to_euler();tag(base,bone,'spines')
        for k in range(5):
            ang=k*2*pi/5
            q=p+(t*cos(ang)+b*sin(ang))*.009+n*.002
            tag(ellipsoid('Areole cork granule',q,(.0035,.0035,.0035),ivory,8,6),bone,'spines')
        lines=[]
        for k in range(3):
            length=random.uniform(.035,.065);tangent=t*(k-1)*.018+b*random.uniform(-.01,.014)
            path=[(*p,1.0),(*(p+n*length*.4+tangent*.5),.7),(*(p+n*length*.82+tangent),.35),(*(p+n*length+tangent*.9+b*.006),.02)]
            lines.append(path)
        tag(paths('Curved tapered cactus spines',lines,.0033,ivory,2),bone,'spines');cluster_count+=1

for o in list(bpy.data.objects):
    bn=BIND.get(o.name)
    if bn in ['foot.L','foot.R']:
        ss=1 if bn=='foot.L' else -1;pivot=Vector((ss*.405,.025,.42))
        o.matrix_world=Matrix.Translation(pivot)@Matrix.Rotation(ss*.18,4,'Z')@Matrix.Translation(-pivot)@o.matrix_world

# Fresh, compact armature whose bone names match the new bindings.
adata=bpy.data.armatures.new('Don Espino Hero Skeleton');rig=bpy.data.objects.new('Don Espino | articulated hero rig',adata);scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None):
    b=adata.edit_bones.new(name);b.head=head;b.tail=tail
    if parent:b.parent=adata.edit_bones[parent]
    return b
bone('root',(0,0,0),(0,0,.4));bone('pelvis',(0,0,1.05),(0,0,1.55),'root');bone('torso',(0,0,1.55),(0,0,2.3),'pelvis');bone('head',(0,0,2.3),(0,0,3.18),'torso')
for key,chain in joints.items():
    side=key[-1];isarm=key.startswith('arm');upper=('upper_arm.' if isarm else 'thigh.')+side;lower=('forearm.' if isarm else 'shin.')+side
    bone(upper,chain[0],chain[1],'torso' if isarm else 'pelvis');bone(lower,chain[1],chain[2],upper)
    if isarm:
        htail=palm_world if side=='R' else Vector(lp)
        if (htail-Vector(chain[2])).length<.03:htail+=Vector((0,0,-.08))
        bone('hand.'+side,chain[2],htail,lower)
        for j in range(3):
            h=htail+Vector((j*.02,0,-.02));bone('finger.'+side+'.'+str(j),h,h+Vector((0,-.01,-.08)),'hand.'+side)
        bone('thumb.'+side,htail+Vector((-.025,0,.02)),htail+Vector((-.065,-.015,-.04)),'hand.'+side)
    else:
        bone('foot.'+side,chain[2],(chain[2][0],-.28,.12),lower)
bone('weapon.R',G@Vector((.20,0,-.20)),G@Vector((-.5,0,.105)),'hand.R')
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True
# Rigidity for accessories; continuous skin weights for the torso and limb joints.
BIND[body.name]={'body':True}
for name,binding in BIND.items():
    obj=bpy.data.objects.get(name)
    if obj is None:continue
    old=obj.matrix_world.copy()
    if isinstance(binding,str):
        obj.parent=rig;obj.parent_type='BONE';obj.parent_bone=binding
        bpy.context.view_layer.update();obj.matrix_world=old
    else:
        obj.parent=rig;obj.matrix_parent_inverse=rig.matrix_world.inverted();obj.matrix_world=old
        if 'body' in binding:
            a=obj.vertex_groups.new(name='torso');b=obj.vertex_groups.new(name='head')
            for v in obj.data.vertices:
                w=max(0,min(1,(v.co.z-2.13)/.34));w=w*w*(3-2*w)
                if w<1:a.add([v.index],1-w,'REPLACE')
                if w>0:b.add([v.index],w,'REPLACE')
        else:
            key=binding['chain'];side=key[-1];isarm=key.startswith('arm')
            a=obj.vertex_groups.new(name=('upper_arm.' if isarm else 'thigh.')+side);b=obj.vertex_groups.new(name=('forearm.' if isarm else 'shin.')+side)
            for v in obj.data.vertices:
                t=(v.index//binding['sides'])/(binding['count']-1)
                w=max(0,min(1,(t-.39)/.22));w=w*w*(3-2*w)
                if w<1:a.add([v.index],1-w,'REPLACE')
                if w>0:b.add([v.index],w,'REPLACE')
        mod=obj.modifiers.new('Hero skeleton deformation','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=True
bpy.context.view_layer.update()
# Organize editable components without hiding model construction.
for label,objs in PARTS.items():
    c=bpy.data.collections.new('Hero • '+label);scene.collection.children.link(c)
    for o in objs:
        for old in list(o.users_collection):old.objects.unlink(o)
        c.objects.link(o)
rig.hide_set(True)

from refine_hero_v3_reference import refine_reference
refine_reference(scene)
from polish_don_espino_v3 import polish_model
polish_model(scene)
from refine_espino_surface_v3 import refine_surfaces,seat_shoulders
refine_surfaces(scene)
seat_shoulders(scene)

# A physically rendered studio matches the reference's warm tactile presentation.
stage=mat('Studio | warm charcoal',(.052,.037,.029),.9)[0]
stagebs=stage.node_tree.nodes.get('Principled BSDF');stagebs.inputs['Emission Color'].default_value=(.05,.036,.029,1);stagebs.inputs['Emission Strength'].default_value=.65
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,0));floor=bpy.context.object;floor.name='Studio floor';floor.data.materials.append(stage)
scene.world=bpy.data.worlds.new('Hero Studio World');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.23,.20,.17,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.38

def area(name,loc,target,power,color,size):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o
area('Large warm key',(-3,-4,6),(0,0,2),450,(1,.84,.68),3.2)
area('Soft front fill',(3,-4,3),(0,0,2),180,(.78,.87,1),3)
area('Golden felt rim',(-2,2,5),(0,0,2.5),380,(1,.64,.38),2)
area('Cool right rim',(3,1,4),(0,0,2.5),220,(.38,.72,1),2)
camdata=bpy.data.cameras.new('Hero portrait camera');cam=bpy.data.objects.new('Hero portrait camera',camdata);scene.collection.objects.link(cam);scene.camera=cam
cam.location=(.70,-10.5,3.5);target=Vector((-.12,0,2.00));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=4.43
scene.render.engine='CYCLES';scene.cycles.samples=96;scene.cycles.use_denoising=True
scene.render.resolution_x=1500;scene.render.resolution_y=2000;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
try:
    pref=bpy.context.preferences.addons['cycles'].preferences;pref.compute_device_type='OPTIX';pref.get_devices()
    for d in pref.devices:d.use=d.type=='OPTIX'
    scene.cycles.device='GPU';print('GPU devices',[(d.name,d.type,d.use) for d in pref.devices],flush=True)
except Exception as e:print('GPU unavailable',e,flush=True)
scene['hero_reference']='desgin/renders/don_espino/concepts/01_character_hero.png'
scene['construction']='Actual editable meshes, curves, procedural shaders and an articulated presentation skeleton. No hero-image plane or generated-image texture.'
scene['areole_clusters']=cluster_count;scene['felt_fibers']=70000
scene['rig_status']='Presentation rig: weighted torso/limbs and bone-parented accessories, hands and weapon. High-resolution art asset; no engine LOD or animation library claimed.'
# Ensure closed authored surfaces have outward-facing normals.
for obj in scene.objects:
    if obj.type!='MESH':continue
    bm=bmesh.new();bm.from_mesh(obj.data)
    if bm.faces and all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)<0:
        bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(obj.data)
    bm.free()

# Store a useful camera view and save the actual scene before rendering.
for screen in bpy.data.screens:
    for ar in screen.areas:
        if ar.type=='VIEW_3D':ar.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(MODEL),compress=True)
preview='--preview' in sys.argv
if preview:
    scene.render.resolution_percentage=55;scene.cycles.samples=24
scene.render.filepath=str(OUT/('hero_preview.png' if preview else '01_actual_blender_hero.png'))
bpy.ops.render.render(write_still=True)
print('HERO V3 COMPLETE',str(MODEL),flush=True)
