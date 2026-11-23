"""Prepare the supplied neutral Don Espino in the live Blender MCP.

Preserves source winding and UVs; never recalculates normals globally on the
generated nonmanifold mesh. All outputs are separate from the source and pilot 1.
"""
import bpy,bmesh,json,hashlib
from pathlib import Path
from mathutils import Vector

ROOT=Path('/home/stefancostea/Documents/MustacheMassacre')
OUT=ROOT/'desgin/character_models/refined/don_espino_natural_workflow'
OUT.mkdir(parents=True,exist_ok=True)
source=bpy.data.objects['DonEspino_Natural_Source']
obj=source.copy();obj.data=source.data.copy();obj.name='DonEspino_Natural_Clean'
bpy.context.scene.collection.objects.link(obj)
source.hide_set(True);source.hide_render=True
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
bpy.context.view_layer.objects.active=obj
bm=bmesh.new();bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
bm.to_mesh(obj.data);bm.free();obj.data.update()
clean_faces=sum(len(p.vertices)-2 for p in obj.data.polygons)
mod=obj.modifiers.new('60k silhouette reduction','DECIMATE');mod.ratio=60000/clean_faces;mod.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier=mod.name)
obj.data.validate(verbose=True,clean_customdata=False)
zmin=min(v.co.z for v in obj.data.vertices);zmax=max(v.co.z for v in obj.data.vertices)
scale=3/(zmax-zmin)
for v in obj.data.vertices:v.co=Vector((v.co.x*scale,v.co.y*scale,(v.co.z-zmin)*scale))
obj.parent=None;obj.matrix_world.identity()

textures=OUT/'textures';textures.mkdir(exist_ok=True)
images=[]
for node in obj.data.materials[0].node_tree.nodes:
    if node.type=='TEX_IMAGE' and node.image and node.image not in images:images.append(node.image)
for i,im in enumerate(images):
    im.filepath_raw=str(textures/('base_color.png' if im.colorspace_settings.name=='sRGB' else 'metallic_roughness.png'))
    im.file_format='PNG';im.save();im.pack()
bpy.ops.export_scene.fbx(filepath=str(OUT/'DonEspinoNatural_mixamo.fbx'),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',path_mode='COPY',embed_textures=True,bake_anim=False)

stats={}
for o in [source,obj]:
    bm=bmesh.new();bm.from_mesh(o.data)
    stats[o.name]={'vertices':len(bm.verts),'triangles':sum(len(f.verts)-2 for f in bm.faces),'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges)}
    bm.free()
report={'source':'desgin/character_models/refined/DonEspinoNatural.glb','source_sha256':hashlib.sha256((ROOT/'desgin/character_models/refined/DonEspinoNatural.glb').read_bytes()).hexdigest(),'topology':stats,'height_metres':3,'textures':[{'name':im.name,'resolution':list(im.size),'colorspace':im.colorspace_settings.name} for im in images],'pose':'supplied symmetric A-pose; open empty hands; no geometric reposing','normals':'source winding preserved; no global recalculation','stage':'prepared, not rigged'}
(OUT/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'01_neutral_prepared.blend'))
print(json.dumps(report))
