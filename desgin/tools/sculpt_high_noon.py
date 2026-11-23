"""Build Don Espino's High Noon attachments in a separate Blender process."""
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/characters/high_noon"
rng = random.Random(78)
pi = math.pi


def linear(hexcolor):
    rgb = [int(hexcolor[i:i+2], 16)/255 for i in (0,2,4)]
    return Vector([c/12.92 if c<.04045 else ((c+.055)/1.055)**2.4 for c in rgb])


def curve(a,b,c,d,t):
    return a*(1-t)**3 + b*(3*t*(1-t)**2) + c*(3*t*t*(1-t)) + d*t**3


class Sculpt:
    def __init__(self):
        self.vertices, self.faces, self.colors, self.texcoords = [],[],[],[]

    def sweep(self, controls, section, pigment, lateral, steps=22, sides=12):
        a,b,c,d = map(Vector,controls)
        start = len(self.vertices)
        for i in range(steps+1):
            t = i/steps
            v = curve(a,b,c,d,t)
            tangent = ((b-a)*(3*(1-t)**2)+(c-b)*(6*(1-t)*t)+(d-c)*(3*t*t)).normalized()
            wide = Vector(lateral)
            wide = (wide - tangent*wide.dot(tangent)).normalized()
            thick = tangent.cross(wide)
            for j in range(sides):
                angle = 2*pi*j/sides
                w,h = section(t,angle)
                p = v + wide*(w*math.cos(angle)) + thick*(h*math.sin(angle))
                self.vertices.append((p.x,-p.z,p.y))
                self.colors.append((*pigment(t,angle),1.0))
                self.texcoords.append((t,j/sides))
                if i:
                    k=start+(i-1)*sides+j
                    n=start+(i-1)*sides+(j+1)%sides
                    self.faces.append((k,n,n+sides,k+sides))
        self.faces.append(tuple(start+j for j in reversed(range(sides))))
        self.faces.append(tuple(start+steps*sides+j for j in range(sides)))

    def object(self,name,material):
        mesh=bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices,[],self.faces)
        mesh.update()
        for face in mesh.polygons: face.use_smooth=True
        uv=mesh.uv_layers.new(name="Fibre")
        for face in mesh.polygons:
            seam=any(self.texcoords[i][1]>.8 for i in face.vertices)
            for loop in face.loop_indices:
                u,v=self.texcoords[mesh.loops[loop].vertex_index]
                uv.data[loop].uv=(u,1. if seam and v==0. else v)
        attr=mesh.color_attributes.new(name="Pigment",type="FLOAT_COLOR",domain="POINT")
        attr.data.foreach_set("color",[v for rgba in self.colors for v in rgba])
        obj=bpy.data.objects.new(name,mesh)
        bpy.context.collection.objects.link(obj)
        mesh.materials.append(material)
        return obj


def material(name):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    shader=next(n for n in mat.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
    col=mat.node_tree.nodes.new("ShaderNodeVertexColor"); col.layer_name="Pigment"
    mat.node_tree.links.new(col.outputs["Color"],shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value=.53
    return mat


def strand(mesh,path,radius,start,end,axis=(0,1,0),flat=1,steps=18):
    low,high=linear(start),linear(end)
    mesh.sweep(path,lambda t,a:(radius*max(.010,math.sin(pi*t)**.68),radius*flat*max(.010,math.sin(pi*t)**.68)),
               lambda t,a:low.lerp(high,t)*(.91+.09*math.cos(a)),axis,steps,8)


def wing(mat):
    mesh=Sculpt()
    # The load-bearing handlebar has a dipped root and a curled outer wrist.
    spine=[Vector(v) for v in [(0,0,.025),(.45,-.29,.07),(1.26,.30,-.08),(1.52,.54,-.22)]]
    strand(mesh,spine,.142,"4A3025","CE8642",flat=.81,steps=36)
    for k in range(8):
        u=k/7
        at=curve(*spine,.19+.73*u)
        # Each flight lock emerges at a different point and parts from its neighbours at the tip.
        end=Vector((.78+1.51*u,-.46+1.06*u**1.8,-.53-.20*u))
        path=[at, at+Vector((.25+.17*u,-.10,-.14)),
              end+Vector((-.17-.18*u,-.35-.09*u,.09)), end]
        dark=linear("553025");copper=linear(["AC6634","9C572E","B2763D"][k%3]);honey=linear("ECB567")
        def section(t,a):
            envelope=max(.013,math.sin(pi*t**.83)**.68)
            groove=1+.05*math.cos(7*a+t)
            return (.145+.030*u)*envelope*groove,(.071+.018*u)*envelope*groove
        def pigment(t,a):
            return dark.lerp(copper,min(1,t*2.1)).lerp(honey,max(0,(t-.52)/.48))*(.87+.13*math.cos(4*a+t))
        mesh.sweep(path,section,pigment,(0,.88,.47),30,16)
        for j in [-1,1]:
            off=Vector((0,.035*j,.046))
            strand(mesh,[path[0],path[1]+off,path[2]+off,path[3]],.012,"825429","F5C47A",steps=22)
    for k in range(6):
        u=k/5
        at=curve(*spine,.11+.73*u)
        strand(mesh,[at+Vector((0,.015,.06)),at+Vector((.15,-.11,.08)),
                     at+Vector((.37,-.14,-.04)),at+Vector((.48,.02+.12*u,-.17))],
               .076,"64402B","CC8F4A",flat=.75,steps=22)
    # A separate upward-twirled guard hair gives the wing a moustache silhouette in profile.
    strand(mesh,[(0,.015,.065),(.50,-.32,.11),(1.41,.21,.02),(1.57,.73,-.13)],.079,"543124","D39958",flat=.8,steps=36)
    return mesh.object("HandlebarWing",mat)


def launcher(mat):
    stem, mouth = Sculpt(),Sculpt()
    dark,green,light=map(linear,["345A39","729A52","C2C976"])
    path=[(0,0,-.070),(0,.015,.12),(0,-.028,.43),(0,0,.64)]
    def lobes(t,a):
        # A ribbed living forearm with a tapered elbow and a swollen flower throat.
        r=(.095 + .072*math.sin(t*pi*.88)+.017*t)*(1+.095*math.cos(9*a+.30*t))
        return r,r
    stem.sweep(path,lobes,lambda t,a: dark.lerp(green,.5+.45*math.cos(9*a+.30*t)).lerp(light,.20*t*t),(1,0,0),36,72)
    for row in range(3):
        for k in range(9):
            a=2*pi*k/9+.08*row
            direction=Vector((math.cos(a),math.sin(a),0))
            r=[.128,.164,.16][row]
            at=direction*r+Vector((0,-.005,.13+row*.16))
            side=Vector((-direction.y,direction.x,0))
            for j in [-1,1]:
                tip=at+direction*(.062+.013*row)+side*.028*j+Vector((0,0,-.047))
                strand(stem,[at-direction*.02,at+direction*.03,tip+Vector((0,0,.009)),tip],.010,"BB9857","FDE6A7",axis=(0,0,1),steps=6)
    for k in range(8):
        a=2*pi*k/8
        v=Vector((math.cos(a),math.sin(a),0)); side=(-math.sin(a),math.cos(a),0)
        path=[v*.124+Vector((0,0,.43)),v*.186+Vector((0,0,.48)),v*.185+Vector((0,0,.64)),v*.123+Vector((0,0,.71))]
        strand(mouth,path,.061,"435B3A","BA7448",side,.48,22)
    # A recessed dark throat with an ivory thorn visibly seated at its centre.
    mouth.sweep([(0,0,.632),(0,0,.639),(0,0,.645),(0,0,.65)],lambda t,a:(.14,.14),
                lambda t,a:linear("403A25"),(1,0,0),2,32)
    mouth.sweep([(0,0,.648),(0,0,.694),(0,0,.759),(0,-.014,.832)],lambda t,a:(.069*(1-t)+.001,.069*(1-t)+.001),
                lambda t,a:linear("C69855").lerp(linear("FFF0BF"),t),(1,0,0),13,10)
    stem.object("CactusForearm",mat)
    mouth.object("ThornBloom",mat)


def special_accents(mat):
    curl = Sculpt()
    paths = [[(0,0,0),(.14,-.16,.04),(.43,-.18,.03),(.51,.035,.005)],
             [(.51,.035,.005),(.58,.22,-.025),(.36,.27,-.018),(.32,.13,0)],
             [(.32,.13,0),(.31,.04,.013),(.40,.043,.015),(.42,.105,.04)]]
    for i,path in enumerate(paths):
        for k in range(3):
            pts=[Vector(v)+Vector((0,.017*k,.019*k)) for v in path]
            curl.sweep(pts,lambda t,a:(.049*(1-.22*i-.13*t),.036*(1-.22*i-.13*t)),
                       lambda t,a:linear("774729").lerp(linear("F3BE66"),min(1,(i+t)/2.6))*(.83+.16*math.cos(4*a)),(0,1,.27),20,12)
    curl.object("RicochetCurl",mat)
    export("ricochet_curl")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bud=Sculpt()
    for k in range(11):
        a=2*pi*k/11; radial=Vector((math.cos(a),.15,math.sin(a)))
        sideways=(-math.sin(a),0,math.cos(a))
        strand(bud,[(0,0,0),radial*.15+Vector((0,-.09,0)),radial*.26+Vector((0,.025,0)),
                    radial*(.27 if k%2 else .32)+Vector((0,.14 if k%2 else .09,0))],.078,"B84D2D","F6C567",sideways,.31)
    for k in range(9):
        a=2*pi*k/9;v=Vector((.067*math.cos(a),.11,.067*math.sin(a)))
        strand(bud,[v*.1,v*.6,v,v+Vector((0,.049,0))],.027,"84602D","E4B664",(1,0,0),steps=10)
    bud.object("SeedBlossom",material("Marigold at dusk"))
    export("seed_blossom")


def export(name):
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")),export_format="GLB",export_animations=False)


def loose_revolver():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/"game/assets/characters/don_espino/don_espino.glb"))
    obj=bpy.data.objects["Runtime_props"]
    rig=next(o for o in bpy.context.scene.objects if o.type=="ARMATURE")
    rig.data.pose_position="REST";bpy.context.view_layer.update()
    group=obj.vertex_groups["weapon.R"].index
    keep={v.index for v in obj.data.vertices if any(g.group==group and g.weight>.5 for g in v.groups)}
    mesh=obj.data.copy()
    matrix=bpy.data.objects["GunOrigin"].matrix_world.inverted_safe() @ obj.matrix_world
    mesh.transform(matrix)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.index not in keep],context="VERTS");bm.to_mesh(mesh);bm.free()
    assert len(mesh.polygons)>100
    for o in list(bpy.context.scene.objects):bpy.data.objects.remove(o,do_unlink=True)
    drop=bpy.data.objects.new("FallenSixShooter",mesh);bpy.context.collection.objects.link(drop)
    export("fallen_six_shooter")


if __name__ == "__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    wing(material("Comb gold and chestnut"));export("handlebar_wing")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    launcher(material("Wax and ivory"));export("thorn_arm")
    loose_revolver()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    special_accents(material("Amber curl"))
