"""Derive a textured, skinned game asset from the preserved native hero master.

Usage: blender -b -t 4 --python tools/build_runtime_espino.py -- prepare|bake|export
Stages are saved separately so a texture pass can resume without remeshing.
"""
from pathlib import Path
import bpy,bmesh,math,json,sys,time
from mathutils import Vector,Matrix,Quaternion
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'game/assets/characters/don_espino';OUT.mkdir(parents=True,exist_ok=True)
WORK=ROOT/'build/asset_work';WORK.mkdir(parents=True,exist_ok=True)
MASTER=ROOT/'desgin/character_models/DON_ESPINO_hero_v3.blend'
GROUPS=['organic','face_hat','clothing','props']
STAGE=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'prepare'

def triangles(o):
    o.data.calc_loop_triangles();return len(o.data.loop_triangles)

def classify(o):
    labels=[c.name.split(' • ')[-1] for c in o.users_collection if c.name.startswith('Hero • ')]
    if any(x in labels for x in ['body','limbs','hands','eyes','spines']):return 'organic'
    if any(x in labels for x in ['hat','moustache']):return 'face_hat'
    if any(x in labels for x in ['shorts','belt','boots']):return 'clothing'
    return 'props'

def budget(name,tri):
    rules=[('Cactus torso',3400),('Sheriff hat',4400),('Moustache sculpt',1800),('Sculpted eyebrow',420),
           ('Cowboy boot leather',1100),('Tailored shorts',1900),('Continuous posed arm',380),('Continuous posed leg',420),
           ('palm',150),('finger',90),('thumb',100),('Black eye',140),('Belt —',600),
           ('Six-fluted',450),('Hollow revolver',240),('Revolver recoil',100),('Walnut grip',100)]
    for token,n in rules:
        if token.lower() in name.lower():return min(n,tri)
    return min(tri,140)

def prepare():
    bpy.ops.wm.open_mainfile(filepath=str(MASTER));s=bpy.context.scene
    rig=bpy.data.objects['Don Espino | articulated hero rig'];rig.hide_set(False);rig.animation_data_clear()
    rig.name='EspinoRig'
    for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    original=[o for c in bpy.data.collections if c.name.startswith('Hero • ') for o in c.objects if o.type in ['MESH','CURVE']]
    low=[];high=[];spine_index=0
    for o in original:
        if '70000 individual' in o.name:
            bpy.data.objects.remove(o,do_unlink=True);continue
        g=classify(o);o['bake_group']=g;o['bake_role']='high';high.append(o)
        o.hide_set(False);o.hide_render=False
        name=o.name
        if any(x in name for x in ['Corky cactus areole','Areole cork granule']):continue
        if o.type=='CURVE':
            structural=any(x in name for x in ['Buckle —','Open steel trigger guard','Curved trigger','Raised boot welt','Rolled boot collar','Curved tapered cactus spines'])
            if not structural:continue
            if 'Curved tapered cactus spines' in name:
                spine_index+=1
                if spine_index%3:continue
            old_res=o.data.bevel_resolution;o.data.bevel_resolution=0
        world=o.matrix_world.copy();binding=o.parent_bone if o.parent_type=='BONE' else None
        # Evaluated mesh carries original vertex-group deform data through modifiers.
        dg=bpy.context.evaluated_depsgraph_get();me=bpy.data.meshes.new_from_object(o.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
        if o.type=='CURVE':o.data.bevel_resolution=old_res
        rt=bpy.data.objects.new('RT_'+name,me);s.collection.objects.link(rt);me.transform(world)
        rt['bake_group']=g;rt['bake_role']='low';rt['source_name']=name
        if binding:
            vg=rt.vertex_groups.new(name=binding);vg.add(list(range(len(me.vertices))),1,'REPLACE')
        else:
            for vg in o.vertex_groups:rt.vertex_groups.new(name=vg.name)
            if not rt.vertex_groups:
                vg=rt.vertex_groups.new(name='head' if g=='face_hat' else 'pelvis');vg.add(list(range(len(me.vertices))),1,'REPLACE')
        count=triangles(rt);target=budget(name,count)
        bpy.context.view_layer.objects.active=rt
        if count>target*1.1:
            mod=rt.modifiers.new('Runtime silhouette reduction','DECIMATE');mod.ratio=target/count;mod.use_collapse_triangulate=True
            bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=rt.modifiers.new('Explicit export triangulation','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
        low.append(rt)
    # Four shared UV atlases, preserving rigid and deforming skin weights on join.
    grouped={g:[o for o in low if o['bake_group']==g] for g in GROUPS}
    for g in GROUPS:
        bpy.ops.object.select_all(action='DESELECT');members=grouped[g]
        for o in members:o.select_set(True)
        bpy.context.view_layer.objects.active=members[0];bpy.ops.object.join();o=bpy.context.object;o.name='Runtime_'+g
        o['bake_group']=g;o['bake_role']='low'
        for layer in list(o.data.uv_layers):o.data.uv_layers.remove(layer)
        o.data.uv_layers.new(name='RuntimeUV')
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=1.151917,island_margin=.012,area_weight=.4,correct_aspect=True,scale_to_bounds=True)
        bpy.ops.object.mode_set(mode='OBJECT')
        print('PREPARED',g,triangles(o),'triangles',flush=True)
    for o in list(s.objects):
        if o!=rig and o.get('bake_role') not in ['high','low']:bpy.data.objects.remove(o,do_unlink=True)
    s.render.engine='CYCLES';s.cycles.samples=16
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'espino_bake_source.blend'),compress=True)

def gpu():
    s=bpy.context.scene
    try:
        p=bpy.context.preferences.addons['cycles'].preferences;p.compute_device_type='OPTIX';p.get_devices()
        for d in p.devices:d.use=d.type=='OPTIX'
        s.cycles.device='GPU'
    except Exception:s.cycles.device='CPU'

def bake():
    bpy.ops.wm.open_mainfile(filepath=str(WORK/'espino_bake_source.blend'));s=bpy.context.scene;gpu()
    s.cycles.samples=16;s.render.bake.use_selected_to_active=True;s.render.bake.cage_extrusion=.012;s.render.bake.max_ray_distance=.065;s.render.bake.margin=12;s.render.bake.use_clear=True
    # Cycles repeats scene synchronization for every selected source object.
    # Consolidate each source group, preserving its original procedural coordinates
    # as point attributes so joining does not change wood, skin or cloth texture scale.
    import numpy as np
    dg=bpy.context.evaluated_depsgraph_get()
    for g in GROUPS:
        originals=[o for o in s.objects if o.get('bake_role')=='high' and o.get('bake_group')==g]
        merged=[]
        for o in originals:
            me=bpy.data.meshes.new_from_object(o.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
            coordinates=np.empty(len(me.vertices)*3,dtype=np.float32);me.vertices.foreach_get('co',coordinates);coordinates=coordinates.reshape((-1,3))
            bounds=np.array(o.bound_box);lo=bounds.min(axis=0);span=np.maximum(bounds.max(axis=0)-lo,1e-8)
            for name,values in [('source_object',coordinates),('source_generated',(coordinates-lo)/span)]:
                attr=me.attributes.new(name,'FLOAT_VECTOR','POINT');attr.data.foreach_set('vector',np.asarray(values,dtype=np.float32).ravel())
            if me.uv_layers.active:me.uv_layers.active.name='SourceUV'
            me.transform(o.matrix_world)
            dup=bpy.data.objects.new('BakeSource_'+g,me);s.collection.objects.link(dup);merged.append(dup)
        for o in originals:bpy.data.objects.remove(o,do_unlink=True)
        bpy.ops.object.select_all(action='DESELECT')
        for o in merged:o.select_set(True)
        bpy.context.view_layer.objects.active=merged[0];bpy.ops.object.join()
        joined=bpy.context.object;joined['bake_role']='high';joined['bake_group']=g
        print('CONSOLIDATED',g,len(joined.data.polygons),flush=True)
    for m in bpy.data.materials:
        if not m.use_nodes:continue
        nt=m.node_tree
        for node in list(nt.nodes):
            if node.type!='TEX_COORD':continue
            for output,name in [('Object','source_object'),('Generated','source_generated')]:
                links=list(node.outputs[output].links)
                if not links:continue
                attr=nt.nodes.new('ShaderNodeAttribute');attr.attribute_name=name
                for link in links:nt.links.new(attr.outputs['Vector'],link.to_socket)
    bpy.context.view_layer.update()
    objects=[o for o in s.objects if o.get('bake_role')]
    for g in GROUPS:
        low=bpy.data.objects['Runtime_'+g];high=[o for o in objects if o.get('bake_role')=='high' and o.get('bake_group')==g]
        size=2048 if g!='props' else 1024
        for o in objects:o.hide_render=True;o.hide_set(True)
        low.hide_render=False;low.hide_set(False)
        for o in high:o.hide_render=False;o.hide_set(False)
        mats=set(m for o in high for m in o.data.materials if m and m.use_nodes)
        for channel in ['color','normal','roughness','metallic']:
            path=OUT/(g+'_'+channel+'.png')
            if path.exists():print('RESUME',path.name,flush=True);continue
            image=bpy.data.images.new(g+'_'+channel,width=size,height=size,alpha=False,float_buffer=False)
            image.colorspace_settings.name='sRGB' if channel=='color' else 'Non-Color'
            for m in low.data.materials:
                if not m:continue
                m.use_nodes=True;n=m.node_tree.nodes.new('ShaderNodeTexImage');n.name='BAKE_DESTINATION';n.image=image;m.node_tree.nodes.active=n
            restores=[]
            if channel in ['color','roughness','metallic']:
                for m in mats:
                    nt=m.node_tree;bs=nt.nodes.get('Principled BSDF');out=next((n for n in nt.nodes if n.type=='OUTPUT_MATERIAL'),None)
                    if not bs or not out:continue
                    old=out.inputs['Surface'].links[0].from_socket if out.inputs['Surface'].links else None
                    em=nt.nodes.new('ShaderNodeEmission');sock=bs.inputs[{'color':'Base Color','roughness':'Roughness','metallic':'Metallic'}[channel]]
                    if sock.links:nt.links.new(sock.links[0].from_socket,em.inputs['Color'])
                    else:
                        v=sock.default_value;em.inputs['Color'].default_value=v if channel=='color' else (v,v,v,1)
                    nt.links.new(em.outputs[0],out.inputs['Surface']);restores.append((nt,em,out,old))
            bpy.ops.object.select_all(action='DESELECT')
            for o in high:o.select_set(True)
            low.select_set(True);bpy.context.view_layer.objects.active=low
            print('BAKING',g,channel,flush=True)
            if channel=='normal':bpy.ops.object.bake(type='NORMAL',normal_space='TANGENT')
            else:bpy.ops.object.bake(type='EMIT')
            image.filepath_raw=str(path);image.file_format='PNG';image.save()
            for nt,em,out,old in restores:
                nt.nodes.remove(em)
                if old:nt.links.new(old,out.inputs['Surface'])
            print('BAKED',path.name,flush=True)
    print('BAKES COMPLETE',flush=True)

def rotate_world(rig,name,axis,angle):
    b=rig.pose.bones[name];p=b.head.copy()
    b.matrix=Matrix.Translation(p)@Matrix.Rotation(angle,4,axis)@Matrix.Translation(-p)@b.matrix
    bpy.context.view_layer.update()

def animations(rig):
    # Build forward-ready upper-body pose from the hero's relaxed reference pose.
    for b in rig.pose.bones:b.rotation_mode='QUATERNION';b.matrix_basis=Matrix.Identity(4)
    rotate_world(rig,'upper_arm.R','Y',.80);rotate_world(rig,'upper_arm.R','Z',math.pi/2)
    # The exported marker's -X points along the original gun barrel.
    originalG=Matrix.Translation(Vector((-.95,-.35,1.44)))@Matrix.Rotation(-.64,4,'Y')
    rest_weapon=rig.data.bones['weapon.R'].matrix_local
    for _ in range(18):
        worldgun=rig.pose.bones['weapon.R'].matrix@rest_weapon.inverted()@originalG
        direction=(worldgun.to_3x3()@Vector((-1,0,0))).normalized();rot=Quaternion().slerp(direction.rotation_difference(Vector((0,-1,0))),.45)
        b=rig.pose.bones['hand.R'];p=b.head.copy();b.matrix=Matrix.Translation(p)@rot.to_matrix().to_4x4()@Matrix.Translation(-p)@b.matrix
        bpy.context.view_layer.update()
    ready={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
    clips={'idle':1.6,'run_forward':.64,'run_backward':.64,'strafe_left':.64,'strafe_right':.64,'shoot':.20,'reload':1.2,'dash':.22,'hurt':.30,'death':.85,'cast':.55,'ultimate':1.1}
    rig.animation_data_create();manifest={}
    for name,duration in clips.items():
        action=bpy.data.actions.new(name);rig.animation_data.action=action;frames=max(3,round(duration*30))
        for f in range(frames+1):
            t=f/frames
            for b in rig.pose.bones:b.matrix_basis=ready[b.name].copy()
            bpy.context.view_layer.update()
            if name=='idle':
                rig.pose.bones['root'].location.z=.008*math.sin(t*2*math.pi)
                rotate_world(rig,'head','Y',.009*math.sin(t*2*math.pi))
            if name in ['run_forward','run_backward','strafe_left','strafe_right']:
                axis='X' if name.startswith('run') else 'Y';direction=-1 if name in ['run_backward','strafe_right'] else 1
                for side,phase in [('L',0),('R',math.pi)]:
                    swing=math.sin(t*2*math.pi+phase)*direction
                    rotate_world(rig,'thigh.'+side,axis,.45*swing)
                    rotate_world(rig,'shin.'+side,'X',-.28*max(0,-swing))
                rig.pose.bones['root'].location.z=.035*abs(math.sin(t*2*math.pi))
                rotate_world(rig,'torso','Z',.025*math.sin(t*2*math.pi))
            if name=='shoot':rotate_world(rig,'forearm.R','X',.16*math.sin(math.pi*t)*math.exp(-t*3))
            if name=='reload':
                e=math.sin(math.pi*t);rotate_world(rig,'upper_arm.R','X',.50*e);rotate_world(rig,'forearm.R','Y',.40*e);rotate_world(rig,'weapon.R','Y',2*math.pi*t)
            if name=='dash':rotate_world(rig,'torso','X',-.17*math.sin(math.pi*t));rig.pose.bones['root'].location.z=.03*math.sin(math.pi*t)
            if name=='hurt':rotate_world(rig,'head','Y',.12*math.sin(math.pi*t));rotate_world(rig,'torso','X',.09*math.sin(math.pi*t))
            if name=='death':rotate_world(rig,'root','X',-1.49*min(1,t*1.4));rotate_world(rig,'head','Z',.15*t)
            if name=='cast':rotate_world(rig,'upper_arm.L','Z',-.75*math.sin(math.pi*t));rotate_world(rig,'forearm.L','X',.5*math.sin(math.pi*t))
            if name=='ultimate':rotate_world(rig,'head','Y',.08*math.sin(math.pi*t));rotate_world(rig,'torso','Z',.05*math.sin(t*6*math.pi))
            for b in rig.pose.bones:
                b.keyframe_insert('location',frame=f+1,group=b.name);b.keyframe_insert('rotation_quaternion',frame=f+1,group=b.name);b.keyframe_insert('scale',frame=f+1,group=b.name)
        track=rig.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,1,action);track.mute=True
        manifest[name]={'seconds':duration,'frames':frames+1,'loop':name in ['idle','run_forward','run_backward','strafe_left','strafe_right']}
    rig.animation_data.action=None
    for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
    return manifest

def export():
    bpy.ops.wm.open_mainfile(filepath=str(WORK/'espino_bake_source.blend'));s=bpy.context.scene;rig=bpy.data.objects['EspinoRig'];rig.hide_set(False)
    for o in list(s.objects):
        if o!=rig and o.get('bake_role')!='low':bpy.data.objects.remove(o,do_unlink=True)
    totals={}
    for g in GROUPS:
        o=bpy.data.objects['Runtime_'+g];o.hide_set(False);o.hide_render=False
        m=bpy.data.materials.new('Espino_'+g);m.use_nodes=True;nt=m.node_tree;bs=nt.nodes.get('Principled BSDF')
        for ch,inp in [('color','Base Color'),('roughness','Roughness'),('metallic','Metallic'),('normal','Normal')]:
            im=bpy.data.images.load(str(OUT/(g+'_'+ch+'.png')),check_existing=True);im.colorspace_settings.name='sRGB' if ch=='color' else 'Non-Color'
            n=nt.nodes.new('ShaderNodeTexImage');n.image=im
            if ch=='normal':normal=nt.nodes.new('ShaderNodeNormalMap');nt.links.new(n.outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs[0],bs.inputs[inp])
            else:nt.links.new(n.outputs['Color'],bs.inputs[inp])
        o.data.materials.clear();o.data.materials.append(m)
        for p in o.data.polygons:p.material_index=0
        o.parent=rig;o.matrix_parent_inverse=Matrix.Identity(4)
        arm=o.modifiers.new('Game skeleton','ARMATURE');arm.object=rig
        totals[g]=triangles(o)
        # Every surviving vertex must have normalized, named deform weights.
        for v in o.data.vertices:
            weights=[x for x in v.groups if x.weight>0];total=sum(x.weight for x in weights)
            if total<1e-6:
                name='head' if g=='face_hat' else 'pelvis';vg=o.vertex_groups.get(name) or o.vertex_groups.new(name=name);vg.add([v.index],1,'REPLACE')
            elif abs(total-1)>.00001:
                for x in weights:o.vertex_groups[x.group].add([v.index],x.weight/total,'REPLACE')
    # Small socket nodes exported with the armature, preserving gun alignment.
    G=Matrix.Translation(Vector((-.95,-.35,1.44)))@Matrix.Rotation(-.64,4,'Y')
    for name,p in [('Muzzle',(-.695,0,.105)),('GunOrigin',(-.20,0,.105))]:
        marker=bpy.data.objects.new(name,None);s.collection.objects.link(marker);marker.parent=rig;marker.parent_type='BONE';marker.parent_bone='weapon.R'
        bpy.context.view_layer.update();marker.matrix_world=Matrix.Translation(G@Vector(p))
    clips=animations(rig);s.render.fps=30;s.frame_set(1)
    for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'DON_ESPINO_runtime.blend'),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'don_espino.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_apply=False,export_skins=True,export_yup=True,export_image_format='AUTO',export_cameras=False,export_lights=False)
    # Lower-detail mesh export for distant display; preserve skin/animation and UVs.
    for g in GROUPS:
        o=bpy.data.objects['Runtime_'+g];mod=o.modifiers.new('Distance LOD','DECIMATE');mod.ratio=.42
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_move_up(modifier=mod.name);bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'don_espino_lod.glb'),export_format='GLB',use_selection=True,export_animations=False,export_apply=False,export_skins=True,export_yup=True,export_cameras=False,export_lights=False)
    report={'source':str(MASTER.relative_to(ROOT)),'triangles':totals,'total_triangles':sum(totals.values()),'material_surfaces':4,'bone_count':len(rig.data.bones),'animations':clips,'textures':'four baked atlases; 2048px organic/face_hat/clothing, 1024px props','source_preserved':True}
    (OUT/'asset_manifest.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2),flush=True)

{'prepare':prepare,'bake':bake,'export':export}[STAGE]()
