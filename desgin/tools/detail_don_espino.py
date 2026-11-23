"""Non-destructive presentation detail pass for the supplied Don Espino FBX.
Run with Blender 4.5: blender -b --python desgin/tools/detail_don_espino.py
"""
from pathlib import Path
import bpy, bmesh, math, random, json
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'desgin/renders/don_espino'
MODEL=ROOT/'desgin/character_models/DON_ESPINO_detail_v2.blend'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'reference/source_inspection.blend'))
scene=bpy.context.scene
body=bpy.data.objects['Cube']
pts=[body.matrix_world@v.co for v in body.data.vertices]
cx=(min(p.x for p in pts)+max(p.x for p in pts))/2
bpy.data.objects['DonEspino_ImportRoot'].location.x-=cx
bpy.context.view_layer.update()
# The FBX has three mirrored face pairs occupying exactly the same space.
# Reflect only the second member of each pair; keep the source meshes intact.
for name in ['Cube.005','Cube.003','Cube.007']:
    obj=bpy.data.objects[name];obj.data=obj.data.copy()
    reflection=Matrix.Diagonal((-1,1,1,1))
    obj.data.transform(obj.matrix_world.inverted()@reflection@obj.matrix_world)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    obj.data.update()

# Material-specific microdetail, intentionally subordinate to the broad shapes.
profiles={
 'PIEL':('Cactus wax',(.12,.40,.085,1),.52,0,95,.003),
 'Material.001':('Hat felt',(.12,.043,.018,1),.84,0,150,.003),
 'CINTASOBRERO':('Hat band leather',(.027,.009,.004,1),.47,0,90,.003),
 'Material.006':('Sculpted moustache',(.065,.025,.007,1),.64,0,70,.016),
 'BOTAS':('Boot leather',(.24,.125,.033,1),.44,0,95,.012),
 'PANTALON':('Ochre canvas',(.42,.115,.027,1),.81,0,175,.008),
 'pistola':('Brushed silver',(.52,.56,.58,1),.26,.88,190,.00035),
 'casquillo':('Cylinder metal',(.27,.30,.32,1),.3,.9,170,.00035),
 'Material.008':('Walnut grip',(.13,.040,.018,1),.44,0,90,.002),
 'EBILLA':('Buckle brass',(.59,.35,.05,1),.25,.82,160,.003),
 'Material.003':('Sheriff star brass',(.72,.43,.065,1),.25,.8,160,.003),
 'WALKIE':('Radio casing',(.06,.075,.078,1),.56,0,160,.005),
}
for name, (label,col,rough,metal,freq,depth) in profiles.items():
    mat=bpy.data.materials.get(name)
    if not mat:continue
    mat.use_nodes=True;mat.diffuse_color=col
    nt=mat.node_tree;nt.nodes.clear()
    out=nt.nodes.new('ShaderNodeOutputMaterial');out.location=(620,0)
    bs=nt.nodes.new('ShaderNodeBsdfPrincipled');bs.location=(340,0)
    bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
    if name=='PIEL':bs.inputs['Subsurface Weight'].default_value=.06
    nt.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
    coord=nt.nodes.new('ShaderNodeTexCoord');coord.location=(-850,0)
    tex=nt.nodes.new('ShaderNodeTexNoise');tex.label=label;tex.location=(-430,0)
    tex.inputs['Scale'].default_value=freq;tex.inputs['Detail'].default_value=2
    nt.links.new(coord.outputs['Generated'],tex.inputs['Vector'])
    ramp=nt.nodes.new('ShaderNodeValToRGB');ramp.location=(-130,150)
    ramp.color_ramp.elements[0].position=.18;ramp.color_ramp.elements[1].position=.82
    ramp.color_ramp.elements[0].color=tuple(c*.82 for c in col[:3])+(1,)
    ramp.color_ramp.elements[1].color=col
    nt.links.new(tex.outputs['Fac'],ramp.inputs[0]);nt.links.new(ramp.outputs['Color'],bs.inputs['Base Color'])
    bump=nt.nodes.new('ShaderNodeBump');bump.location=(90,-160)
    bump.inputs['Strength'].default_value=.23;bump.inputs['Distance'].default_value=depth
    nt.links.new(tex.outputs['Fac'],bump.inputs['Height']);nt.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
    if name in ['Material.006','Material.008']:
        mapping=nt.nodes.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.location=(-650,-100)
        mapping.inputs[1].default_value=(.16,1,3)
        nt.links.new(coord.outputs['Generated'],mapping.inputs[0]);nt.links.new(mapping.outputs[0],tex.inputs['Vector'])
# Remove excessively mirrored plastic reflections on the eyes, keep small catches.
for name in ['Material.004','Material.005']:
    mat=bpy.data.materials[name]
    for n in mat.node_tree.nodes:
        if n.type=='BSDF_PRINCIPLED':n.inputs['Roughness'].default_value=.3

collection=bpy.data.collections.new('V2 Detail — spines, seams, hardware')
scene.collection.children.link(collection)

def simple_mat(name,col,rough=.6,metal=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return m
ivory=simple_mat('V2 warm cactus spines',(.59,.50,.25))
areole=simple_mat('V2 cactus areoles',(.18,.22,.055),.85)
thread=simple_mat('V2 saddle stitching',(.63,.39,.15),.9)
sole=simple_mat('V2 boot sole',(.055,.025,.009),.8)
brass=bpy.data.materials['EBILLA']

def move_collection(o):
    for c in list(o.users_collection):c.objects.unlink(o)
    collection.objects.link(o)

def curve(name,coords,radius,mat,parent=None):
    data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.resolution_u=2;data.bevel_depth=radius;data.bevel_resolution=2
    s=data.splines.new('POLY');s.points.add(len(coords)-1)
    for p,co in zip(s.points,coords):p.co=(*co,1)
    o=bpy.data.objects.new(name,data);collection.objects.link(o);data.materials.append(mat)
    if parent: o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    return o

def cone(name,start,end,radius,mat,parent):
    d=Vector(end)-Vector(start)
    bpy.ops.mesh.primitive_cone_add(vertices=6,radius1=radius,radius2=0,depth=d.length,location=(Vector(start)+Vector(end))/2)
    o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(mat);move_collection(o)
    o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    return o

def sphere(name,loc,scale,mat,parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,location=loc)
    o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(mat);move_collection(o)
    if parent:o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    for p in o.data.polygons:p.use_smooth=True
    return o

# Sparse botanical spine clusters follow actual surface intersections.
random.seed(37)
spine_count=0
for row,z in enumerate([1.73,1.96,2.19,2.43,2.67,2.89,3.04]):
    for column in range(12):
        angle=2*math.pi*(column+(row%2)*.5)/12
        # Leave the face clean and readable.
        if math.sin(angle)<-.25 and z>2.12:continue
        origin=Vector((1.4*math.cos(angle),1.4*math.sin(angle),z))
        direction=Vector((-math.cos(angle),-math.sin(angle),0))
        inv=body.matrix_world.inverted()
        hit,local,normal,_=body.ray_cast(inv@origin,(inv.to_3x3()@direction).normalized())
        if not hit:continue
        pos=body.matrix_world@local;n=(body.matrix_world.to_3x3().inverted().transposed()@normal).normalized()
        sphere('Areole',pos+n*.005,(.016,.016,.016),areole,body)
        for j in [-1,0,1]:
            tangent=n.cross(Vector((0,0,1)))
            length=random.uniform(.035,.065)
            end=pos+n*length+tangent*j*.021+Vector((0,0,.015*abs(j)))
            cone('Cactus spine',pos+n*.006,end,.0042,ivory,body);spine_count+=1

def surface_point(obj, angle, z, offset=.004, required_material=None):
    origin=Vector((2*math.cos(angle),2*math.sin(angle),z))
    direction=Vector((-math.cos(angle),-math.sin(angle),0))
    inv=obj.matrix_world.inverted()
    hit,local,n,face_index=obj.ray_cast(inv@origin,(inv.to_3x3()@direction).normalized())
    if not hit:return None
    if required_material and obj.data.materials[obj.data.polygons[face_index].material_index].name != required_material:return None
    normal=(obj.matrix_world.to_3x3().inverted().transposed()@n).normalized()
    return obj.matrix_world@local+normal*offset

# Project each stitch onto the actual hat and belt surfaces.
hat=bpy.data.objects['Cube.001']
for z in [3.14,3.24]:
    for i in range(35):
        a=math.pi+math.pi*i/34
        coords=[surface_point(hat,t,z,required_material="CINTASOBRERO") for t in [a-.012,a+.012]]
        if all(p is not None for p in coords):curve('Hat band saddle stitch',coords,.0023,thread,hat)
# Belt has raised seam dashes; front-facing to keep geometry restrained.
pants=bpy.data.objects['Cube.008']
for z in [1.435,1.51]:
    for i in range(31):
        a=math.pi+math.pi*i/30
        coords=[surface_point(pants,t,z) for t in [a-.015,a+.015]]
        if all(p is not None for p in coords):curve('Waist seam',coords,.0023,thread,pants)
# Small brass rivets either side of the buckle and at the waistband.
for x in [-.31,-.23,.23,.31]:
    sphere('Belt rivet',(x,-.52,1.478),(.011,.006,.011),brass,pants)
# Add a line of stitched toe decoration to the existing boots.
for name in ['Cube.011','Cube.012']:
    boot=bpy.data.objects[name]
    points=[boot.matrix_world@v.co for v in boot.data.vertices]
    x=(min(p.x for p in points)+max(p.x for p in points))/2
    y=min(p.y for p in points)
    for sign in [-1,1]:
        coords=[]
        for xx,yy in [(x+sign*.07,y+.14),(x+sign*.035,y+.11),(x,y+.10)]:
            inv=boot.matrix_world.inverted()
            hit,local,n,_=boot.ray_cast(inv@Vector((xx,yy,1)),(inv.to_3x3()@Vector((0,0,-1))).normalized())
            if hit:coords.append(boot.matrix_world@local+Vector((0,0,.003)))
        if len(coords)>1:curve('Boot toe embroidery',coords,.0025,thread,boot)
# Preserve the original detailed revolver geometry; its cylinder is already modeled.
gun=bpy.data.objects['Cube.019']
# The original weapon is separate from the hand; present it as a separate prop.
gun['v2_note']='Original separate revolver prop; kept separate for rigging.'

# All added objects are editable and clearly separated from the source geometry.
scene['don_espino_v2_notes']='Source silhouette retained; mirrored face overlap repaired; procedural materials, spine clusters, stitching and brass rivets added. Presentation asset, not a production retopology or verified animation rig.'
scene['source_fbx']='DON_ESPINO.fbx'
scene['spine_count']=spine_count
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1600;scene.render.resolution_y=1600;scene.render.resolution_percentage=100
cam=scene.camera

def aim(loc,target,scale):
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale

# Source pose and rig remain as imported. Hide the loose prop for character views.
gun.hide_render=True
for o in bpy.context.scene.objects:
    if o.type=='ARMATURE':o.hide_set(True)
aim((5,-11,5),(0,0,2.02),5.4)
bpy.ops.wm.save_as_mainfile(filepath=str(MODEL))
for name,loc,scale,target in [
 ('01_model_detail_three_quarter',(5,-11,5),5.4,(0,0,2.02)),
 ('02_model_detail_front',(0,-12,3.4),5.35,(0,0,2.02)),
 ('03_model_detail_closeup',(3,-10,4.9),2.8,(0,-.05,2.94)),
 ('04_model_detail_rear',(5,11,5),5.4,(0,0,2.02))]:
    aim(loc,target,scale);scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
# Dedicated full source revolver render, still physically identical to the FBX.
gun.hide_render=False
for o in bpy.context.scene.objects:
    if o.type in ['MESH','CURVE'] and o not in [gun,bpy.data.objects['Plane']]:o.hide_render=True
points=[gun.matrix_world@v.co for v in gun.data.vertices]
center=sum(points,Vector())/len(points)
aim(center+Vector((.2,-4,1.7)),center,1.3)
scene.render.filepath=str(OUT/'05_original_revolver_detail.png');bpy.ops.render.render(write_still=True)
print('DETAIL PASS COMPLETE',spine_count,'spines',str(MODEL),flush=True)
