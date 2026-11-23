"""Repairs and legible signage for the generated Badlands props, in Blender coordinates."""
import math
import random

import bpy
from mathutils import Vector


def paint(name, color, metal=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    rgb = [int(color[i:i+2], 16)/255 for i in (0, 2, 4)]
    shader.inputs["Base Color"].default_value = (*[((v+.055)/1.055)**2.4 if v>.04045 else v/12.92 for v in rgb], 1)
    shader.inputs["Roughness"].default_value = .70
    shader.inputs["Metallic"].default_value = metal
    return mat


def geometry(name, vertices, faces, material):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    mesh.materials.append(material)
    return ob


def sign_plate(name, outline, y, depth, mat):
    count = len(outline)
    vertices = [(x, yy, z) for yy in [y, y+depth] for x,z in outline]
    faces = [tuple(range(count)), tuple(range(2*count-1, count-1, -1))]
    faces.extend((i, i+count, (i+1)%count+count, (i+1)%count) for i in range(count))
    return geometry(name, vertices, faces, mat)


def lettering(root, text, y, z, width, height, material):
    curve = bpy.data.curves.new(text, "FONT")
    curve.body = text
    curve.font = bpy.data.fonts.load(str(root/"game/assets/fonts/WesternSerif.ttf"), check_existing=True)
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = .011
    curve.bevel_depth = .0025
    curve.resolution_u = 3
    curve.bevel_resolution = 0
    obj = bpy.data.objects.new("Hand lettered " + text, curve)
    bpy.context.collection.objects.link(obj)
    curve.materials.append(material)
    obj.rotation_euler.x = math.pi/2
    obj.location = (0, y, z)
    bpy.context.view_layer.update()
    # The font's local plane is XY. Measure actual ink bounds, including asymmetrical ascenders.
    bbox = [Vector(corner) for corner in obj.bound_box]
    extent = [max(v[i] for v in bbox)-min(v[i] for v in bbox) for i in range(2)]
    obj.scale = (width/extent[0],height/extent[1],1)
    obj.location.z -= (min(v.y for v in bbox)+max(v.y for v in bbox))*.5*obj.scale.y
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")


def stove_part(name, radius1, radius2, height, z, material):
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=radius1, radius2=radius2, depth=height,
                                    location=(-2.63,1.61,z))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)


def saloon(root):
    trim = paint("Hammered ochre brass", "B88848", .28)
    enamel = paint("Deep oxblood enamel", "582B28")
    cream = paint("Buttermilk lettering", "FFE4A0")
    iron = paint("Stove iron", "485052", .23)
    panels = [paint("Oxidized roof " + str(i), color, .22)
              for i,color in enumerate(["814D3B","895140","795142","875B48","716056","995B41"])]
    rng = random.Random(13)
    # Close the hollow roof from the upstairs false front to the rear cornice.
    for side, eave_y in enumerate([-1.32, 2.83]):
        for j in range(12):
            left = -4.55+j*9.10/12
            width = 9.10/12 + .008
            vertices, faces = [], []
            for row in range(4):
                t = row / 3
                for i in range(33):
                    x = left + width*i/32
                    rib = .052 * (.5+.5*math.cos(i*math.pi/2))**1.7
                    y = .62*(1-t)+eave_y*t
                    z = 4.10*(1-t)+3.45*t + rib + .012*math.sin(x*3.6 + row)
                    vertices.append((x,y,z))
            for row in range(3):
                for i in range(32):
                    n=row*33+i
                    face=(n,n+1,n+34,n+33)
                    faces.append(tuple(reversed(face)) if side==0 else face)
            geometry("Corrugated tin",vertices,faces,rng.choice(panels))
    verts=[(x,y,z) for x in (-4.61,4.61) for y,z in ((.42,4.065),(.62,4.19),(.82,4.065))]
    geometry("Rolled ridge cap",verts,[(0,3,4,1),(1,4,5,2)],iron)
    for dims in [(.29,.21,.14,3.88),(.17,.165,.80,4.24),(.195,.195,.08,4.60),(.29,.07,.16,4.77)]:
        stove_part("Cookstove chimney",*dims,iron)

    middle = 3.86
    contour = [(-.92,-1),(.92,-1),(1,-.50),(1,.50),(.92,1),(-.92,1),(-1,.50),(-1,-.50)]
    for name,w,h,y,mat in [("Sign brass border",2.74,.51,-1.553,trim),("Oxblood sign face",2.68,.467,-1.572,enamel)]:
        sign_plate(name, [(x*w, middle+z*h) for x,z in contour], y, .095, mat)
    lettering(root, "LAST CALL", -1.60, 3.965, 4.66, .48, cream)
    lettering(root, "S A L O O N", -1.60, 3.562, 1.97, .16, trim)
    for x in [-2.48,2.48]:
        sign_plate("Brass pin", [(x+math.cos(i*math.pi/4)*.055, middle+math.sin(i*math.pi/4)*.055) for i in range(8)],-1.61,.028,trim)
    star=[(math.cos(math.pi*.5+i*math.pi/5)*(.235 if i%2==0 else .103),
           4.67+math.sin(math.pi*.5+i*math.pi/5)*(.235 if i%2==0 else .103)) for i in range(10)]
    sign_plate("Sheriff crest",star,-1.53,.055,trim)


def wanted(root):
    mat = paint("Letterpress bounty", "FFFFFF")
    tree = mat.node_tree
    ink = tree.nodes.new("ShaderNodeTexImage")
    ink.image = bpy.data.images.load(str(root/"desgin/renders/badlands_props/v01/concepts/wanted.png"))
    tree.links.new(ink.outputs["Color"], next(n for n in tree.nodes if n.type=="BSDF_PRINCIPLED").inputs["Base Color"])
    ob = geometry("WANTED print", [(-.322,-.047,.052),(.321,-.047,.052),(.321,-.047,.86),(-.322,-.047,.86)],
                  [(0,1,2,3)],mat)
    uv = ob.data.uv_layers.new()
    for loop,coord in zip(uv.data,[(.251,.126),(.766,.126),(.766,.880),(.251,.880)]):
        loop.uv=coord


def straw(body):
    """Lay short raised blades on the golden areas, leaving the painted straps exposed."""
    import numpy as np
    mesh = body.data
    mesh.calc_loop_triangles()
    faces = list(mesh.loop_triangles)
    import bisect
    from itertools import accumulate
    weights = list(accumulate(f.area for f in faces))
    albedo = next(n.image for n in mesh.materials[0].node_tree.nodes if n.type=="TEX_IMAGE" and n.image.colorspace_settings.name=="sRGB")
    pixels = np.empty(len(albedo.pixels), dtype=np.float32)
    albedo.pixels.foreach_get(pixels)
    pixels = pixels.reshape(albedo.size[1],albedo.size[0],4)
    uv_data = mesh.uv_layers.active.data
    rng = random.Random(1953)
    vertices, blades, colors = [], [], []
    for _ in range(3600):
        f = faces[bisect.bisect_left(weights, rng.random()*weights[-1])]
        n = f.normal
        if n.z < -.45:
            continue
        a,b = rng.random(),rng.random()
        if a+b>1: a,b=1-a,1-b
        coef = (1-a-b,a,b)
        uv = sum((uv_data[i].uv * w for i,w in zip(f.loops,coef)),Vector((0.,0.)))
        r,g,blue = pixels[int((uv.y%1)*albedo.size[1]),int((uv.x%1)*albedo.size[0]),:3]
        if r<g*1.25 or g<blue*1.25 or r<.045:
            continue
        at = sum((mesh.vertices[i].co*w for i,w in zip(f.vertices,coef)),Vector((0.,0.,0.)))
        if at.z < .035: continue
        # The stems lie along the bale, fanning at the cut ends and following its shoulders.
        grain = Vector((1., rng.uniform(-.58,.58),rng.uniform(-.36,.36)))
        if abs(n.x)>.68: grain=Vector((.15,rng.uniform(-.85,.85),rng.uniform(.28,.95)))
        direction=(grain - n*n.dot(grain)).normalized()
        side = n.cross(direction) * rng.uniform(.0025,.0054)
        length = rng.uniform(.029,.112)
        base = at+n*.009
        mid = base+direction*length*.40+n*.008
        tip = base+direction*length+n*rng.uniform(.008,.029)
        i=len(vertices)
        vertices.extend([base-side*.4,mid-side,tip,mid+side,base+side*.4])
        blades.append((i,i+1,i+2,i+3,i+4));colors.append(rng.randrange(4))
    mat = [paint("Cut straw "+str(i),color) for i,color in enumerate(["C49951","EBC16C","A57C40","D4A24D"])]
    ob=geometry("Raised straw fibres",vertices,blades,mat[0])
    for m in mat[1:]: ob.data.materials.append(m)
    for index, poly in zip(colors,ob.data.polygons): poly.material_index=index


def shed_straw():
    """A few loose stems and seed heads gather where the feed hits the ground."""
    verts, faces = [], []
    rng = random.Random(76)
    for i in range(105):
        sx = -1 if i%2 else 1
        x = sx * rng.uniform(.90,1.68)
        y = rng.uniform(-1.18,1.12)
        if abs(y)<.96 and abs(x)<1.40: continue
        at=Vector((x,y,rng.uniform(.008,.018)))
        delta = Vector((rng.uniform(-.14,.14),rng.uniform(-.13,.13),0.))
        side=Vector((-delta.y,delta.x,0.)).normalized()*rng.uniform(.003,.007)
        j=len(verts)
        verts.extend([at-side, at+delta*.62+side+Vector((0,0,.008)), at+delta, at+delta*.53-side])
        faces.append((j,j+1,j+2,j+3))
    geometry("Shed straw",verts,faces,paint("Dry oat", "BC9957"))
