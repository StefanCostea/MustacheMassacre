"""REJECTED EXPERIMENT: reference only. Do not use for production preparation.

The spatial/color masks stretched triangles between the hand, hip and weapon.
This failed visual review. Original source and faithful reduced mesh remain intact.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector
import numpy as np

ROOT=Path('/home/stefancostea/Documents/MustacheMassacre')
OUT=ROOT/'desgin/character_models/refined/don_espino_workflow'
OUT.mkdir(parents=True,exist_ok=True)
source=bpy.data.objects['DonEspino_Clean_Work']
obj=source.copy();obj.data=source.data.copy();obj.name='DonEspino_Neutral_Candidate'
bpy.context.scene.collection.objects.link(obj)
source.hide_set(True);source.hide_render=True
obj.hide_set(False);obj.hide_render=False
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
bpy.context.view_layer.objects.active=obj

# Separate generated parts fused at the hip by restricting the left-hand
# correction to green arm/hand texels, leaving the radio and belt stationary.
image=bpy.data.images['Image_0']
pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels)
pixels=pixels.reshape(image.size[1],image.size[0],4)
uv=obj.data.uv_layers.active.data
uvs=np.empty(len(uv)*2,dtype=np.float32);uv.foreach_get('uv',uvs);uvs=uvs.reshape(-1,2)
indices=np.empty(len(obj.data.loops),dtype=np.int32);obj.data.loops.foreach_get('vertex_index',indices)
cols=pixels[np.clip((uvs[:,1]*image.size[1]).astype(int),0,image.size[1]-1),np.clip((uvs[:,0]*image.size[0]).astype(int),0,image.size[0]-1),:3]
green=np.zeros(len(obj.data.vertices),dtype=bool)
green[indices[(cols[:,1]>cols[:,0]*1.12)&(cols[:,1]>cols[:,2]*1.08)]]=True

def segment_distance(p,a,b):
    t=max(0,min(1,(p-a).dot(b-a)/(b-a).length_squared))
    return (p-a.lerp(b,t)).length,t

# The two original arm chains are asymmetric. Straighten each with a local
# piecewise rigid transform, blending at its elbow and shoulder attachment.
chains=[
 (-1,[(-.137,-.008,.040),(-.172,-.023,-.082),(-.231,-.069,-.164)],False),
 (1,[(.139,.005,.061),(.251,-.008,-.005),(.198,-.092,-.114)],True),
]
changed=[0,0]
for n,(sign,points,green_only) in enumerate(chains):
    a,b,c=map(Vector,points)
    direction=Vector((sign*.82,0,-.5736)).normalized()
    nb=a+direction*(b-a).length;nc=nb+direction*(c-b).length
    r0=(b-a).rotation_difference(direction);r1=(c-b).rotation_difference(direction)
    for v in obj.data.vertices:
        p=v.co.copy()
        if p.z<-.25 or p.z>.09 or sign*p.x<.132:continue
        if green_only and not green[v.index]:continue
        d0,t0=segment_distance(p,a,b);d1,t1=segment_distance(p,b,c)
        if min(d0,d1)>(.035 if green_only else .105):continue
        p0=a+r0@(p-a);p1=nb+r1@(p-b)
        # Smoothly blend near elbow; distal props retain the wrist transform.
        blend=max(0,min(1,((p-a).dot(c-a)/(c-a).length_squared-.40)/.24))
        target=p0.lerp(p1,blend)
        attach=max(0,min(1,(sign*p.x-.132)/.028))
        attach=attach*attach*(3-2*attach)
        v.co=p.lerp(target,attach)
        changed[n]+=1
obj.data.update()

# Non-destructive source remains available in the saved audit blend. Collapse
# on the candidate only and preserve the UV map and seam delimiters.
mod=obj.modifiers.new('Gameplay reduction candidate','DECIMATE')
mod.ratio=60000/len(obj.data.polygons)
mod.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier=mod.name)
for p in obj.data.polygons:p.use_smooth=True

# Ground at Z=0 and normalize overall height to three metres (hat included).
zmin=min(v.co.z for v in obj.data.vertices);zmax=max(v.co.z for v in obj.data.vertices)
factor=3/(zmax-zmin)
for v in obj.data.vertices:v.co=Vector((v.co.x*factor,v.co.y*factor,(v.co.z-zmin)*factor))
obj.parent=None;obj.matrix_world.identity()

textures=OUT/'textures';textures.mkdir(exist_ok=True)
for im in [bpy.data.images['Image_0'],bpy.data.images['Image_1']]:
    im.filepath_raw=str(textures/('base_color.png' if im.name=='Image_0' else 'metallic_roughness.png'))
    im.file_format='PNG';im.save();im.pack()
bpy.ops.export_scene.fbx(filepath=str(OUT/'DonEspino_neutral_candidate.fbx'),use_selection=True,object_types={'MESH'},apply_unit_scale=True,axis_forward='-Z',axis_up='Y',path_mode='COPY',embed_textures=True,bake_anim=False)
report={'source':'desgin/character_models/refined/DonEspino.glb','source_sha256':hashlib.sha256((ROOT/'desgin/character_models/refined/DonEspino.glb').read_bytes()).hexdigest(),'source_triangles':290497,'clean_triangles':290049,'candidate_triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),'candidate_vertices':len(obj.data.vertices),'arm_vertices_adjusted':changed,'height_metres':3,'pose_status':'A-pose candidate: requires visual and deformation review','rig_status':'not rigged','animations':[]}
(OUT/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'02_neutral_candidate.blend'))
print(json.dumps(report))
