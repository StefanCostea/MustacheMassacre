"""Native Blender pose studies from the motivation plan, using the saved hero model."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from espino_v3_helpers import *
from mathutils import Quaternion
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'desgin/renders/don_espino/v3'
SCENES=ROOT/'desgin/character_models/scenes';SCENES.mkdir(exist_ok=True)

def emission(name,color,power):
    m,nt,bs=mat(name,color,.35,.25);bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=power
    return m

def rotate_bone(rig,name,axis,angle):
    b=rig.pose.bones[name];p=b.head.copy()
    b.matrix=Matrix.Translation(p)@Matrix.Rotation(angle,4,axis)@Matrix.Translation(-p)@b.matrix
    bpy.context.view_layer.update()

def build(kind):
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'desgin/character_models/DON_ESPINO_hero_v3.blend'))
    s=bpy.context.scene;rig=bpy.data.objects['Don Espino | articulated hero rig']
    rig.hide_set(False)
    try:
        pref=bpy.context.preferences.addons['cycles'].preferences;pref.compute_device_type='OPTIX';pref.get_devices()
        for d in pref.devices:d.use=d.type=='OPTIX'
        s.cycles.device='GPU'
    except Exception:s.cycles.device='CPU'
    rotate_bone(rig,'upper_arm.R','Y',.55 if kind=='ricochet' else 1.00)
    if kind=='frenzy':rotate_bone(rig,'forearm.R','Y',-.26)
    aim=Vector((-2.65,-.10-.29*1.03,.98*1.03) if kind=='ricochet' else (-2.65,.20,1.00))
    # Solve the wrist orientation so the first tracer truly leaves the barrel axis.
    gun=bpy.data.objects['Hollow revolver barrel'];handbone=rig.pose.bones['hand.R']
    for _ in range(25):
        bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();G=gun.evaluated_get(dg).matrix_world
        muzzle=G@Vector((-.695,0,.105));direction=(G.to_3x3()@Vector((-1,0,0))).normalized()
        rotation=Quaternion().slerp(direction.rotation_difference((aim-muzzle).normalized()),.35).to_matrix().to_4x4();pivot=handbone.head.copy()
        handbone.matrix=Matrix.Translation(pivot)@rotation@Matrix.Translation(-pivot)@handbone.matrix
        rig.update_tag(refresh={'OBJECT'})
    bpy.context.view_layer.update()
    G=gun.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world
    muzzle=G@Vector((-.695,0,.105));direction=(G.to_3x3()@Vector((-1,0,0))).normalized()
    s['first_shot_axis_dot']=direction.dot((aim-muzzle).normalized());assert s['first_shot_axis_dot']>.9999
    # Save the pose as editable bone channels and a named one-frame action.
    rig.animation_data_create()
    for b in rig.pose.bones:
        b.keyframe_insert('location',frame=1,group=b.name)
        b.keyframe_insert('rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler',frame=1,group=b.name)
        b.keyframe_insert('scale',frame=1,group=b.name)
    if rig.animation_data.action:rig.animation_data.action.name='Pose | '+('Ricochet Rodeo' if kind=='ricochet' else 'High Noon Frenzy')
    s.frame_start=s.frame_end=1
    sand,nt,bs=mat('Badlands | granular red sand',(.12,.055,.025),.91)
    v=mapping(nt);n=noise(nt,4,4,vector=v);nt.links.new(ramp(nt,n.outputs['Fac'],[(.08,.030,.013),(.22,.11,.050)]),bs.inputs['Base Color'])
    fine=noise(nt,180,2,vector=v);bump(nt,bs,fine.outputs['Fac'],.003,.6)
    floor=bpy.data.objects['Studio floor'];floor.data.materials.clear();floor.data.materials.append(sand)
    rockmat=leather('Badlands | sandstone',(.19,.085,.035))
    random.seed(15)
    for i in range(30):
        x=random.uniform(-4,3);y=random.uniform(-1,4)
        if abs(x)<.8 and abs(y)<.7:continue
        sz=random.uniform(.035,.13)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(x,y,sz*.45));o=bpy.context.object;o.name='Badlands scattered sandstone';o.scale=(sz*1.3,sz,sz*.65);o.data.materials.append(rockmat)
    # Small mechanical wasteland enemies with moustaches, as in the game pillars.
    enamel=leather('Enemy | battered turquoise enamel',(.045,.17,.16));trim=mat('Enemy | steel trim',(.16,.21,.22),.4,.65)[0]
    dark=mat('Enemy | dark facial hair',(.027,.014,.008),.75)[0]
    hot=emission('Effects | hot amber core',(1,.52,.06),5)
    orange=emission('Effects | orange outer streak',(1,.16,.012),2.0)
    targetglow=emission('Effects | golden target rings',(1,.42,.03),3)
    eyes=emission('Enemy | angry amber eyes',(1,.20,.015),1.2)
    def fridge(loc,scale=1):
        x,y,z=loc
        o=cube('Moustached refrigerator enemy',(x,y,z+.71*scale),(.61*scale,.48*scale,1.23*scale),enamel,.060*scale)
        for zz,hh in [(.40,.57),(.99,.38)]:cube('Refrigerator raised door',(x,y-.249*scale,z+zz*scale),(.56*scale,.028*scale,hh*scale),enamel,.025*scale)
        for xx in [-.15,.15]:
            cube('Enemy foot',(x+xx*scale,y,z+.055*scale),(.16*scale,.28*scale,.11*scale),trim,.025*scale)
            cube('Angry glowing eye',(x+xx*.65*scale,y-.277*scale,z+.98*scale),(.095*scale,.018*scale,.033*scale),eyes,.008*scale)
            pts=catmull([(x,y-.29*scale,z+.88*scale),(x+xx*.8*scale,y-.33*scale,z+.90*scale),(x+xx*1.8*scale,y-.29*scale,z+.79*scale)],40)
            tube('Enemy moustache',pts,[.035*scale*sin(pi*(.10+.90*k/39))**.6 for k in range(40)],dark,12)
        tube('Refrigerator door handle',[(x+.19*scale,y-.30*scale,z+.48*scale),(x+.19*scale,y-.30*scale,z+.70*scale)],.018*scale,trim,12)
        return Vector((x,y-.29*scale,z+.98*scale))
    gun=bpy.data.objects['Hollow revolver barrel'];bpy.context.view_layer.update()
    muzzle=gun.matrix_world@Vector((-.695,0,.105));direction=gun.matrix_world.to_3x3()@Vector((-1,0,0));direction.normalize()
    flare_end=muzzle+direction*.28
    tube('Muzzle flash core',[muzzle,muzzle+direction*.08,flare_end],[.035,.068,.0008],hot,12)
    for j in range(7):
        a=j*pi*2/7;up=direction.cross(Vector((0,1,0))).normalized();side=direction.cross(up)
        p=muzzle+direction*.10+(up*cos(a)+side*sin(a))*.10
        tube('Muzzle flash tongues',[muzzle,p,muzzle+direction*.25],[.012,.025,.0001],orange,8)
    if kind=='ricochet':
        p1=fridge((-2.65,-.10,0),1.03);p2=fridge((-2.95,1.70,0),.86);p3=fridge((-1.40,2.55,0),.82)
        # Consecutive connected segments make the bounce chain readable.
        points=[flare_end,p1,p2,p3]
        paths('Ricochet trajectory — three consecutive enemy hits',[points],.012,hot,3)
        for p in [p1,p2,p3]:
            for j in range(10):
                a=j*2*pi/10;d=Vector((cos(a),-.25,sin(a)))
                tube('Ricochet impact sparks',[p+d*.06,p+d*random.uniform(.15,.32)],[.008,.0003],hot,8)
        s['ability']='Ricochet Rodeo: one projectile bounces through three nearby enemies.'
        target=Vector((-.75,.30,1.85));camloc=(3.0,-11.5,5.4);scale=6.4
        filename='06_actual_ricochet_rodeo';title='DON_ESPINO_ricochet_v3.blend'
    else:
        gold=emission('Frenzy | golden moustache wings',(.85,.35,.035),.38)
        gbs=gold.node_tree.nodes.get('Principled BSDF');gbs.inputs['Metallic'].default_value=.65;gbs.inputs['Roughness'].default_value=.3
        for sign in [-1,1]:
            o=bpy.data.objects['Moustache sculpt '+str(sign)];o.data.materials[0]=gold
            # The moustache grows outward into swept golden feather-like locks.
            for j in range(10):
                t=j/9;root=(sign*(.12+.045*j),-.60,2.53-.024*j)
                end=(sign*(1.82-.06*j),-.04+.015*j,3.05-.105*j)
                pts=[bezier(root,(sign*(.62+.025*j),-.68,2.75-.035*j),(sign*1.28,-.24,3.13-.092*j),end,k/89) for k in range(90)]
                rad=[(.050-.0015*j)*sin(pi*(.025+.975*k/89))**.65 for k in range(90)]
                tube('Frenzy swept golden moustache lock',pts,rad,gold,18)
                paths('Frenzy wing luminous filament',[pts],.0015,hot,2)
        for o in bpy.data.collections['Hero • eyes'].objects:o.data.materials[0]=hot
        # Six marked targets communicate High Noon's precise six-shot chain.
        targets=[(-2.65,.20,1.00),(-2.35,1.35,1.35),(-1.4,2.6,1.2),(1.35,2.6,1.2),(2.35,1.35,1.35),(2.65,.20,1.00)]
        for j,p in enumerate(targets):
            center=Vector(p);r=.15
            ring=[(p[0]+r*cos(a),p[1],p[2]+r*sin(a)) for a in [2*pi*k/80 for k in range(81)]]
            paths('High Noon target '+str(j+1),[ring],.008,targetglow,2)
            for ax in [0,2]:
                for sign in [-1,1]:
                    a=center.copy();b=center.copy();a[ax]+=sign*.10;b[ax]+=sign*.22
                    paths('High Noon reticle crosshair',[[a,b]],.006,targetglow,2)
        paths('High Noon active precision shot',[[flare_end,Vector(targets[0])]],.010,hot,3)
        # Time-suspended golden brass around the combat silhouette.
        brass=bpy.data.materials['Metal | aged brass']
        for j in range(6):
            a=2*pi*j/6;p=Vector((1.25*cos(a),.25+sin(a)*.65,1.55+.45*sin(a*2)))
            tube('Suspended golden cartridge',[p,p+Vector((.08,.02,.04))],.025,brass,20)
        # A restrained ground halo frames the transformation.
        ring=[(1.2*cos(a),.15+.75*sin(a),.015) for a in [2*pi*k/200 for k in range(201)]]
        paths('Frenzy ground halo',[ring],.007,targetglow,2)
        s['ability']='High Noon: six marked targets, shown during golden gunslinger-wing Stache Frenzy.'
        target=Vector((0,.1,1.85));camloc=(1.4,-11.5,4.6);scale=6.25
        filename='07_actual_high_noon_frenzy';title='DON_ESPINO_high_noon_v3.blend'
    # All special effects remain native editable meshes/curves in the saved scene.
    s.camera.location=camloc;s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=scale
    s.render.resolution_x=2000;s.render.resolution_y=1550;s.render.resolution_percentage=100
    s.cycles.samples=128;s.cycles.use_denoising=True
    s.use_nodes=True;nt=s.node_tree;nt.nodes.clear()
    layers=nt.nodes.new('CompositorNodeRLayers');glare=nt.nodes.new('CompositorNodeGlare');glare.glare_type='FOG_GLOW';glare.quality='HIGH';glare.threshold=1.7
    comp=nt.nodes.new('CompositorNodeComposite');nt.links.new(layers.outputs['Image'],glare.inputs['Image']);nt.links.new(glare.outputs['Image'],comp.inputs['Image'])
    s['render_scope']='Editable native Blender static combat pose study; not implemented gameplay or a complete animation.'
    s.render.filepath=str(OUT/(filename+'.png'))
    bpy.ops.wm.save_as_mainfile(filepath=str(SCENES/title),compress=True)
    if '--preview' in sys.argv:s.render.resolution_percentage=55;s.cycles.samples=24;s.render.filepath=str(OUT/(filename+'_preview.png'))
    bpy.ops.render.render(write_still=True)
    print('COMBAT RENDER COMPLETE',kind,flush=True)

args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
kinds=[a for a in args if a in ['ricochet','frenzy']] or ['ricochet','frenzy']
for kind in kinds:build(kind)
