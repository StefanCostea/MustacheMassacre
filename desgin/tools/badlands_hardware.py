"""Model the articulated refrigerator hardware in character-height coordinates."""
from math import cos, pi, sin, tau
from pathlib import Path
import bpy
from mathutils import Vector


class Hardware:
    def __init__(self, body, height):
        self.body = body
        self.height = height
        self.vertices, self.faces, self.surface, self.owners = [], [], [], []
        self.uvs = []
        self.materials = []
        self.bone = "Cabinet"

    def material(self, name, rgb, metallic, roughness, glow=0):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = (*rgb,1)
        shader.inputs["Metallic"].default_value = metallic
        shader.inputs["Roughness"].default_value = roughness
        if glow:
            shader.inputs["Emission Color"].default_value = (*rgb,1)
            shader.inputs["Emission Strength"].default_value = glow
        self.materials.append(mat)
        return len(self.materials)-1

    def add(self, points, faces, material, smooth=False, uvs=None):
        start = len(self.vertices)
        self.vertices.extend(tuple(Vector(p)*self.height) for p in points)
        self.owners.extend([self.bone]*len(points))
        self.faces.extend(tuple(start+i for i in f) for f in faces)
        self.surface.extend([(material,smooth)]*len(faces))
        self.uvs.extend(uvs if uvs is not None else [(0,0)]*len(points))

    def sweep(self, points, radii, material, sides=7):
        pts = list(map(Vector,points))
        verts, faces = [], []
        for i,p in enumerate(pts):
            axis = (pts[min(i+1,len(pts)-1)] - pts[max(i-1,0)]).normalized()
            ref = Vector((0,1,0)) if abs(axis.y)<.93 else Vector((1,0,0))
            u = axis.cross(ref).normalized()
            v = axis.cross(u)
            r = radii[i] if isinstance(radii,list) else radii
            verts.extend(p+r*(u*cos(tau*j/sides)+v*sin(tau*j/sides)) for j in range(sides))
            if i:
                for j in range(sides):
                    a=(i-1)*sides+j; b=(i-1)*sides+(j+1)%sides
                    faces.append((a,b,b+sides,a+sides))
        faces.extend([tuple(reversed(range(sides))),tuple(range(len(verts)-sides,len(verts)))])
        self.add(verts,faces,material,True)

    def plate(self, outline, y, thickness, material, bevel=0):
        # Counter-clockwise x/z winding faces the camera (-Y).
        n=len(outline)
        cx=sum(p[0] for p in outline)/n; cz=sum(p[1] for p in outline)/n
        profile=[(y+thickness,1),(y+bevel,1),(y,1-bevel/max(.005,max(abs(x-cx) for x,z in outline)))]
        verts=[(cx+(x-cx)*s,d,cz+(z-cz)*s) for d,s in profile for x,z in outline]
        faces=[tuple(reversed(range(n))), tuple(range(2*n,3*n))]
        for layer in range(2):
            for j in range(n):
                a=layer*n+j; b=layer*n+(j+1)%n
                faces.append((a,b,b+n,a+n))
        self.add(verts,faces,material)

    def panel(self,x,z,w,h,y,t,r,material):
        shape=[]
        for k,(sx,sz) in enumerate(((1,1),(-1,1),(-1,-1),(1,-1))):
            for j in range(5):
                a=(k+j/4)*pi/2
                shape.append((x+sx*(w/2-r)+r*cos(a),z+sz*(h/2-r)+r*sin(a)))
        self.plate(shape,y,t,material,min(.002,r/3))

    def disc(self,x,z,r,y,t,mat,sides=20):
        self.plate([(x+r*cos(tau*i/sides),z+r*sin(tau*i/sides)) for i in range(sides)],y,t,mat,r*.12)

    def front(self,x,z):
        hit,point,_,_=self.body.ray_cast((x*self.height,-2*self.height,z*self.height),(0,1,0))
        return point.y/self.height if hit else None

    def finish(self):
        data=bpy.data.meshes.new("Authored fittings")
        data.from_pydata(self.vertices,[],self.faces); data.update()
        obj=bpy.data.objects.new("Articulated fittings",data)
        bpy.context.collection.objects.link(obj)
        for material in self.materials: data.materials.append(material)
        if any(uv != (0,0) for uv in self.uvs):
            layer = data.uv_layers.new(name=self.body.data.uv_layers.active.name)
            for loop in data.loops:
                layer.data[loop.index].uv = self.uvs[loop.vertex_index]
        for poly,(index,smooth) in zip(data.polygons,self.surface):
            poly.material_index=index; poly.use_smooth=smooth
        return obj,self.owners


def build_hardware(body,height,sheriff):
    g=Hardware(body,height)
    iron=g.material("Graphite gasket",(.017,.025,.032),.35,.52)
    brass=g.material("Worn honey brass",(.59,.31,.075),.72,.30)
    silver=g.material("Brushed nickel",(.46,.51,.53),.72,.37)
    porcelain=g.material("Aged ivory porcelain",(.67,.58,.41),.13,.51)
    frost=g.material("Cold compressor glass",(.105,.72,.91),.28,.26,1.05)
    if not sheriff:
        # Finish both exposed cut surfaces, with a liner and a recessed rack.
        g.panel(0,.446,.539,.405,-.121,.018,.025,iron)
        g.panel(0,.446,.49,.364,-.124,.012,.018,porcelain)
        for z in (.34,.40,.47,.54):
            g.panel(0,z,.438,.012,-.133,.01,.004,silver)
        g.bone="Door"
        g.panel(0,.446,.525,.40,-.140,.009,.022,iron)
        g.panel(0,.446,.494,.369,-.141,.008,.018,porcelain)
        return g.finish()

    darkhair=g.material("Pewter strand shadow",(.23,.205,.165),.09,.62)
    hair=g.material("Silver guard hair",(.60,.56,.46),.10,.55)
    thread=g.material("Waxed saddle thread",(.62,.39,.19),.01,.82)
    iris=g.material("Amber iris",(.32,.126,.025),.08,.29)
    # Six-point, faceted law star. The centre stands forward of the old soft badge.
    cx,cz,y=0,.709,-.197
    rim=[(cx+(r:=.042 if i%2==0 else .021)*cos(pi/2+tau*i/12),cz+r*sin(pi/2+tau*i/12)) for i in range(12)]
    g.plate(rim,y,.023,brass,.001)
    g.add([(0,y-.009,cz)]+[(x,y,z) for x,z in rim],[(0,1+i,1+(i+1)%12) for i in range(12)],brass)
    for x,z in rim[::2]: g.disc(x,z,.0045,y-.001,.004,brass,10)
    # Fit the enamel sclera and inset iris beneath the descending inner brow.
    # Each little cornea follows the surveyed face instead of floating on a flat plate.
    for side in (-1,1):
        outline=[]
        for j in range(25):
            u=j/24
            outline.append((side*(.015+.092*u), .640+.032*u+.007*sin(pi*u)))
        for j in range(23,0,-1):
            u=j/24
            outline.append((side*(.015+.092*u), .640+.032*u-.023*sin(pi*u)**.72))
        if side>0: outline.reverse()
        cx,cz=side*.058,.647
        def eye_surface(x,z,offset):
            # Preserve the cast shadow from the overhanging brow at its upper edge.
            depth=g.front(x,z)
            return (x,(depth if depth is not None else -.17)-offset,z)
        rings=[[eye_surface(cx,cz,.007)]]
        for scale,relief in ((.55,.0055),(.91,.0040),(1,.0025)):
            rings.append([eye_surface(cx+(x-cx)*scale,cz+(z-cz)*scale,relief) for x,z in outline])
        n=len(outline)
        g.add(rings[0]+rings[1],[(0,j+1,(j+1)%n+1) for j in range(n)],porcelain,True)
        for a,b,mat in ((1,2,porcelain),(2,3,brass)):
            g.add(rings[a]+rings[b],[(j,n+j,n+(j+1)%n,(j+1)%n) for j in range(n)],mat,True)
        def lens(x,z,rx,rz,depth,mat):
            pts=[eye_surface(x,z,depth+.001)]
            for i in range(24):
                a=i*tau/24;pts.append(eye_surface(x+rx*cos(a),z+rz*sin(a),depth))
            g.add(pts,[(0,j+1,1+(j+1)%24) for j in range(24)],mat,True)
        lens(cx-side*.004,.649,.012,.010,.009,iris)
        lens(cx-side*.004,.649,.0065,.008,.011,iron)
        lens(cx-side*.004-.002,.652,.0023,.0023,.013,porcelain)
    # Visible screwdriver slots and pins down both door stiles.
    for side in (-1,1):
        for z in (.351,.408,.467,.515,.715,.745):
            x=side*(.190 if z<.53 else .157)
            depth=g.front(x,z)
            if depth is not None:
                g.disc(x,z,.0054,depth-.003,.005,brass,12)
                g.sweep([(x-.0026,depth-.0037,z-.0014),(x+.0026,depth-.0037,z+.0014)],.00065,iron,5)
        # Long tapered combed locks follow the actual moustache surface.
        for row in range(13):
            pts=[]; widths=[]
            for j in range(43):
                t=.018*(row%4)+(1-.018*(row%4)-.012*(row%3))*j/42
                x=side*(.013+(.248-.0007*row)*t)
                z=.600-.049*sin(pi*t)+.029*t**5+(row-6)*.00195*(.45+sin(pi*t))+.0018*sin(t*tau*1.3+row*.41)
                depth=g.front(x,z)
                if depth is not None and depth<-.175:
                    pts.append((x,depth-.0007,z))
                    widths.append((.00025+.00060*sin(pi*j/42))*(1-.45*t))
            if len(pts)>4:
                g.bone="Whisker"+("L" if side>0 else "R")
                g.sweep(pts,widths,hair if row%3==0 else darkhair,5)
        g.bone="Cabinet"
    # Tiny saddle stitches follow the belt and the hat band beneath its rivets.
    for z in (.285,.320,.838):
        for i in range(-14,15):
            x=i*.015
            if z<.4 and -.05<x<.064: continue
            if z>.8 and abs(x)>.118: continue
            pts=[]
            for px in (x-.004,x,x+.004):
                depth=g.front(px,z)
                if depth is not None: pts.append((px,depth-.0017,z))
            if len(pts)==3: g.sweep(pts,.0011,thread,5)
    # Brass-framed cold bank under four shutters. The shutters tip open on the ice fan.
    def arch(w,bottom,shoulder,top):
        return [(-w,bottom),(w,bottom),(w,shoulder)]+[(w*cos(j*pi/20),shoulder+(top-shoulder)*sin(j*pi/20)) for j in range(1,21)]
    g.plate(arch(.148,.347,.435,.505),-.208,.038,brass,.003)
    g.plate(arch(.138,.355,.434,.495),-.210,.012,iron,.002)
    for j in range(11):
        phase=j*pi/10
        g.disc(.143*cos(phase),.435+.065*sin(phase),.0024,-.2098,.002,porcelain,8)
    g.bone="Fan"
    for j in range(7):
        a=tau*j/7
        leaf=[(r*cos(a+d),.421+r*sin(a+d)) for r,d in ((.018,0),(.054,.10),(.065,.70),(.054,.81),(.022,.45))]
        g.plate(leaf,-.213,.002,frost,.0005)
    g.disc(0,.421,.019,-.215,.003,brass)
    blade=g.material("Frost on brushed steel",(.48,.48,.46),.30,.54)
    mat=g.materials[blade]
    tex=mat.node_tree.nodes.new("ShaderNodeTexImage")
    atlas=Path(__file__).resolve().parents[1]/"character_models/generated/el_frigorifico/v02/sheriff_frost.png"
    tex.image=bpy.data.images.load(str(atlas));tex.image.pack()
    tex.extension="EXTEND"
    mat.node_tree.links.new(tex.outputs["Color"],mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
    for i in range(4):
        z=.379+i*.035
        g.bone="Louver"+str(i)
        w=[.254,.263,.251,.204][i]
        pts,faces,uvs=[],[],[]
        columns=25
        # Rolled, bowed steel. The back face is visible at the open extreme.
        for row,(dy,dz,v) in enumerate([(-.220,-.014,.06),(-.232,-.013,.015),
                                         (-.234,-.009,.23),(-.229,.002,.63),(-.218,.013,.985)]):
            for j in range(columns):
                u=j/(columns-1); arc=1-(2*u-1)**2
                pts.append(((u-.5)*w,dy-.0035*arc,z+dz+.0045*arc))
                uvs.append((u,(i+v)/4))
                if row and j:
                    a=(row-1)*columns+j-1
                    faces.append((a,a+1,a+columns+1,a+columns))
        g.add(pts,faces,blade,True,uvs)
        back = [(j,j+4*columns,j+4*columns+1,j+1) for j in range(columns-1)]
        ends = [tuple(r*columns for r in range(5)),tuple(r*columns+columns-1 for r in reversed(range(5)))]
        g.add(pts,back+ends,silver)
        for row in (0,4):
            rail=pts[row*columns:(row+1)*columns]
            g.sweep(rail,.0012,silver)
    g.bone="Cabinet"
    # Mounted pressure gauge, readable from the boss's front-right corner.
    cx,cz,y=.176,.482,-.207
    g.disc(cx,cz,.036,y,.060,brass,32);g.disc(cx,cz,.0295,y-.002,.004,porcelain,32)
    for i in range(9):
        a=(-35+i*31)*pi/180
        g.sweep([(cx+.022*cos(a),y-.004,cz+.022*sin(a)),(cx+.027*cos(a),y-.004,cz+.027*sin(a))],.0013,iron,5)
    g.bone="Gauge";g.sweep([(cx-.005,y-.006,cz-.003),(cx+.018,y-.006,cz+.010)], [.0022,.0009],iron)
    g.disc(cx,cz,.0037,y-.007,.002,brass,12)
    g.bone="Cabinet"
    for s in (-1,1):
        g.sweep([(s*.188,-.16,.36),(s*.222,-.12,.38),(s*.237,-.08,.50),(s*.218,-.08,.55)],.007,brass,10)
        for z in (.405,.433,.461):
            g.sweep([(s*.230,-.099,z),(s*.232,-.093,z+.010)],.010,iron,8)
    return g.finish()
