"""Native geometry polish: volumetric boots, tapered hair and open revolver frame."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from espino_v3_helpers import *

def polish_model(scene):
    if scene.get('hero_geometry_polished'):return
    rig=bpy.data.objects['Don Espino | articulated hero rig']
    def attach(o,bone,collection):
        for c in list(o.users_collection):c.objects.unlink(o)
        bpy.data.collections['Hero • '+collection].objects.link(o)
        old=o.matrix_world.copy();o.parent=rig;o.parent_type='BONE';o.parent_bone=bone
        bpy.context.view_layer.update();o.matrix_world=old
        return o
    thread=bpy.data.materials['Stitch | warm flax thread']
    bootmat=bpy.data.materials['Boots | worn ochre leather']
    solemat=bpy.data.materials['Boots | layered sole leather']
    seam_mat=bpy.data.materials['Stitch | inset seam shadow']
    # Wear is a surface attribute, so it follows the shoe when posed.
    nt=bootmat.node_tree;bs=nt.nodes.get('Principled BSDF');old=bs.inputs['Base Color'].links[0].from_socket
    attr=nt.nodes.new('ShaderNodeAttribute');attr.attribute_name='leather_wear'
    wearnoise=noise(nt,42,3,vector=mapping(nt))
    fac=nt.nodes.new('ShaderNodeMath');fac.operation='MULTIPLY';nt.links.new(attr.outputs['Fac'],fac.inputs[0]);nt.links.new(wearnoise.outputs['Fac'],fac.inputs[1])
    mix=nt.nodes.new('ShaderNodeMixRGB');nt.links.new(fac.outputs[0],mix.inputs[0]);nt.links.new(old,mix.inputs[1]);mix.inputs[2].default_value=(.26,.19,.11,1);nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
    for o in list(bpy.data.collections['Hero • boots'].objects):bpy.data.objects.remove(o,do_unlink=True)
    for sign in [-1,1]:
        cx=sign*.405;bone='foot.L' if sign>0 else 'foot.R';new=[]
        # Rounded toe box flows continuously into the ankle and open shaft.
        profile=catmull([
            (.065,.151,.278,-.115),(.085,.159,.286,-.117),
            (.120,.163,.287,-.112),(.155,.158,.270,-.105),
            (.185,.146,.228,-.078),(.215,.126,.164,-.010),
            (.255,.116,.132,.020),(.315,.113,.119,.028),
            (.385,.119,.122,.028),(.455,.137,.132,.028),
            (.520,.145,.138,.028)],140)
        N=160;vv=[];ff=[];uv=[];wear=[]
        for i,(z,rx,ry,cy) in enumerate(profile):
            t=i/(len(profile)-1)
            for j in range(N):
                a=2*pi*j/N;back=(1+cos(a))*.5
                # Fuller forefoot with a softly rounded, slightly squared toe.
                ca=cos(a);sa=sin(a);foot=max(0,1-(z-.065)/.17)
                sx=(1 if sa>=0 else -1)*abs(sa)**(1-.20*foot)
                sy=(1 if ca>=0 else -1)*abs(ca)**(1-.10*foot)
                wr=(.0024*sin(102*z+2*sin(a)+.3*cos(3*a))+.0011*sin(155*z-3*a))*math.exp(-((z-.29)/.075)**2)
                x=cx+rx*sx+wr*sa;y=cy+ry*sy+wr*ca
                zz=z+.020*back*(1-t)**8-.020*abs(ca)**6*t**12
                zz+=.0013*sin(39*y+11*a)*math.exp(-((y+.19)/.08)**2)*math.exp(-((z-.18)/.06)**2)
                vv.append((x,y,zz));uv.append((j/N,t))
                wear.append(.58*math.exp(-((y+.33)/.15)**2)*math.exp(-((z-.12)/.09)**2))
        for i in range(len(profile)-1):
            for j in range(N):ff.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
        ff.append(tuple(range(N-1,-1,-1)))
        boot=mesh('Cowboy boot leather '+str(sign),vv,ff,bootmat,uv);recalc(boot)
        attr=boot.data.attributes.new('leather_wear','FLOAT','POINT')
        for d,w in zip(attr.data,wear):d.value=w
        solid=boot.modifiers.new('Leather lining thickness','SOLIDIFY');solid.thickness=.006;solid.offset=-1
        new.append(boot)
        # The sole follows the leather footprint, with forefoot support and a heel.
        outline=[Vector(vv[j])+Vector(((vv[j][0]-cx)*.025,(vv[j][1]+.115)*.018,-.001)) for j in range(N)]
        soleverts=[]
        for dz in [.002,-.027]:
            soleverts.extend([(p.x,p.y,p.z+dz) for p in outline])
        fs=[(j,(j+1)%N,(j+1)%N+N,j+N) for j in range(N)]+[tuple(range(N-1,-1,-1)),tuple(range(N,2*N))]
        sole=mesh('Layered leather outsole '+str(sign),soleverts,fs,solemat);recalc(sole);bevel(sole,.004,3);new.append(sole)
        welt=[p+Vector((0,0,.003)) for p in outline];welt.append(welt[0])
        new.append(paths('Raised boot welt '+str(sign),[welt],.004,bootmat))
        new.append(stitches('Boot welt stitching '+str(sign),welt,.014,.00125,thread))
        for dz in [-.008,-.018]:new.append(paths('Outsole leather lamination',[[p+Vector((0,0,dz)) for p in welt]],.0008,seam_mat))
        # Broad heel under the rear third; the toe rests close to the ground.
        new.append(cube('Stacked heel '+str(sign),(cx,.105,.025),(.222,.155,.050),solemat,.013))
        for z in [.014,.029,.044]:new.append(cube('Heel leather layer',(cx,.105,z),(.223,.155,.008),solemat,.006))
        cuff=[Vector(vv[(len(profile)-1)*N+j]) for j in range(N)];cuff.append(cuff[0])
        new.append(paths('Rolled boot collar',[cuff],.0045,bootmat))
        new.append(stitches('Boot collar stitches',[p+Vector((0,0,-.010)) for p in cuff],.014,.0015,thread))
        bpy.context.view_layer.update()
        # Paired shaft panels, stitched on the actual leather surface.
        for dx in [-.078,.078]:
            pts=[]
            for k in range(120):
                z=.225+.275*k/119;x=cx+dx*(.86+.14*cos(k/119*pi))
                p=project(boot,x,z,.0024)
                if p is not None:pts.append(p)
            new.append(paths('Boot front panel seam',[pts],.0016,seam_mat))
            new.append(stitches('Boot panel saddle stitch',[p+Vector((dx*.048,-.0008,0)) for p in pts],.013,.0012,thread))
        # Western fan motif: two flowing leaves per side, one central stem.
        ornament=[]
        for flip in [-1,1]:
            for ctrl in [
                [(0,-.302),(.100,-.318),(.089,-.235),(.006,-.249)],
                [(0,-.252),(.074,-.270),(.062,-.196),(0,-.205)]]:
                pts=[]
                for k in range(90):
                    q=bezier(*[(cx+flip*x,y,0) for x,y in ctrl],k/89)
                    hit,p,n,_=boot.ray_cast(Vector((q.x,q.y,1)),Vector((0,0,-1)))
                    if hit:pts.append(p+n*.0018)
                ornament.append(pts)
        pts=[]
        for k in range(100):
            y=-.315+.13*k/99;hit,p,n,_=boot.ray_cast(Vector((cx,y,1)),Vector((0,0,-1)))
            if hit:pts.append(p+n*.0018)
        ornament.append(pts);new.append(paths('Western toe embroidery',ornament,.00125,thread))
        for dx in [-.133,.133]:new.append(cube('Boot pull tab',(cx+dx,.027,.485),(.019,.040,.070),bootmat,.008))
        # Toe cap construction seam and small worn crease lines.
        cap=[]
        for j in range(101):
            x=cx-.142+.284*j/100;y=-.245+.07*(abs((x-cx)/.142)**1.8)
            hit,p,n,_=boot.ray_cast(Vector((x,y,1)),Vector((0,0,-1)))
            if hit:cap.append(p+n*.001)
        new.append(stitches('Toe cap stitching',cap,.013,.0008,thread))
        pivot=Vector((cx,.025,.42));rot=Matrix.Translation(pivot)@Matrix.Rotation(sign*.18,4,'Z')@Matrix.Translation(-pivot)
        for o in new:o.matrix_world=rot@o.matrix_world;attach(o,bone,'boots')
    # Tapered swept locks with irregular fine channels and larger flowing clumps.
    hair=bpy.data.materials['Moustache | grooved chestnut locks']
    for n in hair.node_tree.nodes:
        if n.type=='VALTORGB':
            n.color_ramp.elements[0].color=(.045,.016,.006,1);n.color_ramp.elements[-1].color=(.17,.075,.028,1)
    for sign in [-1,1]:
        old=bpy.data.objects['Moustache sculpt '+str(sign)];bpy.data.objects.remove(old,do_unlink=True)
        vv=[];ff=[];uv=[];N=220;K=640
        centers=[]
        for i in range(N+1):
            t=i/N;c=bezier((.014,-.55,2.525),(.17,-.61,2.66),(.43,-.60,2.42),(.64,-.515,2.14),t);c.x*=sign*.93;centers.append(c)
        for i,c in enumerate(centers):
            t=i/N;tan=(centers[min(i+1,N)]-centers[max(i-1,0)]).normalized();front=Vector((0,-1,0));up=tan.cross(front).normalized()
            if up.z<0:up=-up
            envelope=max(.0005,sin(pi*(.08+.92*t))**.70*(1-.43*t))
            for j in range(K):
                a=2*pi*j/K;phase=a+.006*sin(19*a+t*4)+.003*sin(31*a-t*3)
                fine=.00065*cos(137*phase+.8*sin(t*5+2*a))+.00032*cos(211*phase+t*1.7)
                clump=.0015*cos(15*a+.5*sin(t*4))+.00065*cos(29*a-t*2)
                f=(fine+clump)*sin(pi*(.05+.95*t))**.4
                q=c+up*((.184*envelope+f)*cos(a))+front*((.125*envelope+f)*sin(a))
                vv.append(q);uv.append((t,j/K))
        for i in range(N):
            for j in range(K):ff.append((i*K+j,i*K+(j+1)%K,(i+1)*K+(j+1)%K,(i+1)*K+j))
        ff.extend([tuple(range(K-1,-1,-1)),tuple(N*K+j for j in range(K))])
        o=mesh('Moustache sculpt '+str(sign),vv,ff,hair,uv);recalc(o);attach(o,'head','moustache')
    # Open mechanical frame: the cylinder is no longer buried in a solid plate.
    old=bpy.data.objects['Revolver solid frame'];G=old.matrix_world.copy();bpy.data.objects.remove(old,do_unlink=True)
    silver=bpy.data.materials['Metal | engraved gun steel']
    pieces=[
        prism('Revolver recoil shield',[(.056,.165),(.159,.165),(.230,.102),(.204,-.090),(.122,-.126),(.064,-.066)],.061,silver),
        prism('Revolver top strap',[(-.206,.162),(.140,.162),(.140,.188),(-.206,.188)],.027,silver),
        prism('Revolver lower frame',[(-.203,-.025),(.103,-.025),(.125,-.064),(-.180,-.064)],.027,silver),
        prism('Revolver front yoke',[(-.223,.170),(-.193,.170),(-.187,-.052),(-.222,-.052)],.039,silver),
    ]
    for o in pieces:o.matrix_world=G@o.matrix_world;attach(o,'weapon.R','revolver')
    # Remove ornamental lines that were on the now-open front plate; retain rear scrolls.
    for o in list(bpy.data.collections['Hero • revolver'].objects):
        if o.name.startswith('Engraved frame scrolls'):
            for spline in list(o.data.splines):
                if all(p.co.x<.02 for p in spline.points):o.data.splines.remove(spline)
        if o.name.startswith('Frame pin') and (G.inverted()@o.matrix_world.translation).x<0:bpy.data.objects.remove(o,do_unlink=True)
    # Smooth knee transitions: the skin tube already has a modeled joint bulge.
    for o in list(bpy.data.objects):
        if o.name.startswith('Cactus knee joint'):bpy.data.objects.remove(o,do_unlink=True)
    scene['hero_geometry_polished']=True

if __name__=='__main__':
    root=Path(__file__).resolve().parents[2];p=root/'desgin/character_models/DON_ESPINO_hero_v3.blend'
    bpy.ops.wm.open_mainfile(filepath=str(p));polish_model(bpy.context.scene)
    bpy.ops.wm.save_as_mainfile(filepath=str(p),compress=True)
