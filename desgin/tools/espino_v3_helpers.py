"""Geometry and shader helpers for the editable Don Espino hero model."""
import bpy, bmesh, math, random
from mathutils import Vector, Matrix
from mathutils.noise import noise_vector
from math import sin,cos,pi,sqrt

def mat(name,color,rough=.5,metal=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    nt=m.node_tree;bs=nt.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
    bs.location=(450,100);nt.nodes.get('Material Output').location=(740,100)
    return m,nt,bs

def noise(nt,scale,detail=2,loc=(-650,0),vector=None):
    n=nt.nodes.new('ShaderNodeTexNoise');n.location=loc;n.inputs['Scale'].default_value=scale;n.inputs['Detail'].default_value=detail
    if vector:nt.links.new(vector,n.inputs['Vector'])
    return n

def ramp(nt,inp,colors,loc=(-150,150)):
    r=nt.nodes.new('ShaderNodeValToRGB');r.location=loc
    for e,c in zip(r.color_ramp.elements,colors):e.color=(*c,1)
    nt.links.new(inp,r.inputs[0]);return r.outputs['Color']

def bump(nt,bs,inp,dist,strength=.3,normal=None):
    b=nt.nodes.new('ShaderNodeBump');b.location=(220,-130);b.inputs['Strength'].default_value=strength;b.inputs['Distance'].default_value=dist
    nt.links.new(inp,b.inputs['Height'])
    if normal:nt.links.new(normal,b.inputs['Normal'])
    nt.links.new(b.outputs['Normal'],bs.inputs['Normal']);return b.outputs['Normal']

def mapping(nt,scale=(1,1,1),uv=False):
    c=nt.nodes.new('ShaderNodeTexCoord');c.location=(-1200,0)
    m=nt.nodes.new('ShaderNodeVectorMath');m.operation='MULTIPLY';m.location=(-1000,0);m.inputs[1].default_value=scale
    nt.links.new(c.outputs['UV' if uv else 'Object'],m.inputs[0]);return m.outputs['Vector']

def textile(name,color,scale=180,rough=.8):
    m,nt,bs=mat(name,color,rough)
    v=mapping(nt)
    n=noise(nt,6,3,vector=v)
    nt.links.new(ramp(nt,n.outputs['Fac'],[tuple(c*.68 for c in color),tuple(c*1.13 for c in color)]),bs.inputs['Base Color'])
    waves=[]
    for direction in ['X','Z']:
        w=nt.nodes.new('ShaderNodeTexWave');w.wave_type='BANDS';w.bands_direction=direction;w.inputs['Scale'].default_value=scale;w.inputs['Distortion'].default_value=1.1;w.inputs['Detail Scale'].default_value=2
        nt.links.new(v,w.inputs['Vector']);waves.append(w)
    mult=nt.nodes.new('ShaderNodeMath');mult.operation='MULTIPLY'
    for i,w in enumerate(waves):nt.links.new(w.outputs['Color'],mult.inputs[i])
    bn=bump(nt,bs,mult.outputs[0],.00125,.45)
    fine=noise(nt,420,2,vector=v);bump(nt,bs,fine.outputs['Fac'],.0007,.23,bn)
    bs.inputs['Sheen Weight'].default_value=.12
    bs.inputs['Sheen Tint'].default_value=(*color,1)
    bs.inputs['Specular IOR Level'].default_value=.23
    colorlink=bs.inputs['Base Color'].links[0].from_socket
    multcolor=nt.nodes.new('ShaderNodeMixRGB');multcolor.blend_type='MULTIPLY';multcolor.inputs[0].default_value=.12
    nt.links.new(colorlink,multcolor.inputs[1]);nt.links.new(ramp(nt,mult.outputs[0],[(.60,.60,.60),(1.12,1.12,1.12)]),multcolor.inputs[2]);nt.links.new(multcolor.outputs[0],bs.inputs['Base Color'])
    return m

def leather(name,color):
    m,nt,bs=mat(name,color,.49)
    v=mapping(nt);n=noise(nt,8,3,vector=v)
    nt.links.new(ramp(nt,n.outputs['Fac'],[tuple(c*.63 for c in color),tuple(c*1.20 for c in color)]),bs.inputs['Base Color'])
    grain=nt.nodes.new('ShaderNodeTexVoronoi');grain.distance='EUCLIDEAN';grain.inputs['Scale'].default_value=240;nt.links.new(v,grain.inputs['Vector'])
    bn=bump(nt,bs,grain.outputs['Distance'],.0012,.38)
    fine=noise(nt,620,2,vector=v);bump(nt,bs,fine.outputs['Fac'],.0004,.2,bn)
    bs.inputs['Coat Weight'].default_value=.025;bs.inputs['Coat Roughness'].default_value=.6
    bs.inputs['Specular IOR Level'].default_value=.25;bs.inputs['Roughness'].default_value=.61
    return m

def smooth(o):
    if o.type=='MESH':
        for p in o.data.polygons:p.use_smooth=True
    return o

def mesh(name,verts,faces,material,uvs=None):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o)
    if material:data.materials.append(material)
    if uvs:
        layer=data.uv_layers.new(name='DetailUV')
        for poly in data.polygons:
            for li in poly.loop_indices:layer.data[li].uv=uvs[data.loops[li].vertex_index]
    return smooth(o)

def subd(o,level=1,apply=False):
    mod=o.modifiers.new('Sculpt surface refinement','SUBSURF');mod.levels=level;mod.render_levels=level
    if apply:
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def bevel(o,width=.005,segments=3):
    mod=o.modifiers.new('Machined rounded edges','BEVEL');mod.width=width;mod.segments=segments
    return o

def cube(name,loc,scale,material,r=.01):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if material:o.data.materials.append(material)
    if r:bevel(o,r,3)
    return smooth(o)

def ellipsoid(name,loc,scale,material,segments=24,rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=loc)
    o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if material:o.data.materials.append(material)
    return smooth(o)

def paths(name,lines,radius,material,res=2):
    d=bpy.data.curves.new(name,'CURVE');d.dimensions='3D';d.resolution_u=2;d.bevel_depth=radius;d.bevel_resolution=res
    for coords in lines:
        if len(coords)<2:continue
        s=d.splines.new('POLY');s.points.add(len(coords)-1)
        for i,p in enumerate(coords):
            if len(p)==4:s.points[i].co=(*p[:3],1);s.points[i].radius=p[3]
            else:s.points[i].co=(*p,1)
    o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);d.materials.append(material);return o

def bezier(p0,p1,p2,p3,t):
    return (1-t)**3*Vector(p0)+3*(1-t)**2*t*Vector(p1)+3*(1-t)*t*t*Vector(p2)+t**3*Vector(p3)

def catmull(points,count=60):
    points=[Vector(p) for p in points];out=[]
    for k in range(count):
        a=k/(count-1)*(len(points)-1);i=min(int(a),len(points)-2);t=a-i
        p0=points[max(i-1,0)];p1=points[i];p2=points[i+1];p3=points[min(i+2,len(points)-1)]
        out.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t**3))
    return out

def tube(name,points,radii,material,sides=16,caps=True):
    points=[Vector(p) for p in points];verts=[];faces=[];uvs=[]
    for i,p in enumerate(points):
        tangent=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
        n=tangent.cross(Vector((0,1,0)))
        if n.length<.01:n=tangent.cross(Vector((1,0,0)))
        n.normalize();b=tangent.cross(n).normalized();r=radii[i] if isinstance(radii,list) else radii
        if any(w in name.lower() for w in ['finger','thumb']):
            f=max(0,(i/(len(points)-1)-.86)/.14);r*=max(.035,math.sqrt(max(0,1-f*f)))
        for j in range(sides):
            a=2*pi*j/sides;verts.append(p+r*(n*cos(a)+b*sin(a)));uvs.append((i/(len(points)-1),j/sides))
    for i in range(len(points)-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    if caps:faces.extend([tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+j for j in range(sides))])
    return mesh(name,verts,faces,material,uvs)

def recalc(o):
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()

def world_mesh(o):
    o.data=o.data.copy();world=o.matrix_world.copy()
    for m in list(o.modifiers):o.modifiers.remove(m)
    o.parent=None;o.data.transform(world);o.matrix_world=Matrix.Identity(4)
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
    o.vertex_groups.clear();return smooth(o)

def project(obj,x,z,offset=.002):
    hit,p,n,_=obj.ray_cast(Vector((x,-3,z)),Vector((0,1,0)))
    return p+n*offset if hit else None

def radial(obj,a,z,offset=.002,material=None):
    hit,p,n,fi=obj.ray_cast(Vector((3*cos(a),3*sin(a),z)),Vector((-cos(a),-sin(a),0)))
    if not hit:return None
    if material is not None and obj.data.polygons[fi].material_index!=material:return None
    return p+n*offset

def stitches(name,points,spacing,radius,material):
    pts=[Vector(p) for p in points];total=0;lines=[];on=False;cur=[]
    for a,b in zip(pts[:-1],pts[1:]):
        d=b-a;L=d.length
        if L<1e-8:continue
        steps=max(1,int(L/(spacing*.15)))
        for j in range(steps):
            p=a+d*j/steps;phase=(total+L*j/steps)%spacing
            if phase<spacing*.55:cur.append(p)
            elif cur:
                if len(cur)>1:lines.append(cur)
                cur=[]
        total+=L
    if len(cur)>1:lines.append(cur)
    return paths(name,lines,radius,material,1)

def disk_x(name,center,radius,depth,material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=radius,depth=depth,location=center,rotation=(0,pi/2,0));o=bpy.context.object;o.name=name;o.data.materials.append(material);return smooth(o)

def prism(name,outline,halfdepth,material):
    v=[(x,y,z) for y in [-halfdepth,halfdepth] for x,z in outline];N=len(outline)
    f=[tuple(range(N-1,-1,-1)),tuple(range(N,2*N))]+[(j,(j+1)%N,(j+1)%N+N,j+N) for j in range(N)]
    o=mesh(name,v,f,material);bevel(o,.006,3);return o
