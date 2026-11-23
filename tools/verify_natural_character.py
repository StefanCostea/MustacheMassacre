"""Validate the neutral-model GLB itself, independently of Blender's report."""
from pathlib import Path
import json,struct,hashlib,math

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'desgin/character_models/refined/don_espino_natural_workflow'
path=WORK/'DonEspinoNatural_animated.glb'
raw=path.read_bytes();assert raw[:4]==b'glTF'
chunks={};offset=12
while offset<len(raw):
    size,kind=struct.unpack_from('<II',raw,offset);chunks[kind]=raw[offset+8:offset+8+size];offset+=8+size
g=json.loads(chunks[0x4E4F534A]);binary=chunks[0x004E4942]

def read(index):
    a=g['accessors'][index];view=g['bufferViews'][a['bufferView']]
    fmt,width={5126:('f',4),5125:('I',4),5123:('H',2),5121:('B',1),5122:('h',2),5120:('b',1)}[a['componentType']]
    size={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    start=view.get('byteOffset',0)+a.get('byteOffset',0);stride=view.get('byteStride',width*size)
    values=[struct.unpack_from('<'+fmt*size,binary,start+i*stride) for i in range(a['count'])]
    if a.get('normalized') and fmt!='f':
        divisor={5121:255,5123:65535,5125:4294967295,5120:127,5122:32767}[a['componentType']]
        values=[tuple(x/divisor for x in row) for row in values]
    return values

names={n.get('name'):i for i,n in enumerate(g['nodes'])}
core={'idle','run_forward','run_backward','strafe_left','strafe_right','shoot','reload','dash','hurt','death','cast','ultimate'}
clips={a['name']:a for a in g['animations']}
assert core<=clips.keys()
assert {'walk','shoot_source','stache_frenzy'}<=clips.keys()
stache={f'stache_{part}.{side}' for part in ['root','mid','tip'] for side in ['L','R']}
assert stache<=names.keys()
assert {'Muzzle','GunOrigin','weapon.R','Natural_Separate_Revolver'}<=names.keys()
assert not g.get('cameras')
assert not ({'Cube','Review_Studio_Ground','DonEspino_Natural_Source','Natural_OriginalPose_Diagnostic'}&names.keys())
assert all('bufferView' in image and 'uri' not in image for image in g['images'])
parents={child:i for i,n in enumerate(g['nodes']) for child in n.get('children',[])}
gun=names['Natural_Separate_Revolver'];ancestors=[];cursor=gun
while cursor in parents:cursor=parents[cursor];ancestors.append(cursor)
assert names['weapon.R'] in ancestors
assert 'skin' not in g['nodes'][gun], 'Revolver should be a separate rigid prop'
assert parents[names['Muzzle']]==gun and parents[names['GunOrigin']]==gun
skin=g['skins'][0];assert len(skin['joints'])==64
triangles=0;vertices=0;max_error=0
for mesh in g['meshes']:
    for p in mesh['primitives']:
        triangles+=g['accessors'][p['indices']]['count']//3
        vertices+=g['accessors'][p['attributes']['POSITION']]['count']
        if 'WEIGHTS_0' not in p['attributes']:continue
        weights=read(p['attributes']['WEIGHTS_0']);joints=read(p['attributes']['JOINTS_0'])
        for w,j in zip(weights,joints):
            max_error=max(max_error,abs(sum(w)-1))
            assert all(0<=x<len(skin['joints']) for x in j)
        assert max_error<1e-4
durations={};animated_hair=set();loop_errors={}
for name,animation in clips.items():
    times=[read(s['input']) for s in animation['samplers']]
    durations[name]=max(row[0] for values in times for row in values)
    assert min(row[0] for values in times for row in values)<1e-5,'Animation must start at zero'
    error=0
    for channel in animation['channels']:
        node=g['nodes'][channel['target']['node']].get('name')
        if node in stache:animated_hair.add(node)
        if name in ['idle','walk','run_forward','run_backward','strafe_left','strafe_right']:
            sampler=animation['samplers'][channel['sampler']];values=read(sampler['output']);a,b=values[0],values[-1]
            if channel['target']['path']=='rotation':
                # q and -q describe the same orientation.
                distance=min(math.dist(a,b),math.dist(a,tuple(-x for x in b)))
            else:distance=math.dist(a,b)
            error=max(error,distance)
    if name in ['idle','walk','run_forward','run_backward','strafe_left','strafe_right']:
        loop_errors[name]=error;assert error<1e-4,(name,error)
assert animated_hair==stache
audit=json.loads((WORK/'audit.json').read_text())
assert hashlib.sha256((ROOT/audit['source']).read_bytes()).hexdigest()==audit['source_sha256']
previous=json.loads((ROOT/'build/verification/archive_verification.json').read_text())['tested_game_hashes']
active='assets/characters/don_espino/don_espino.glb'
assert hashlib.sha256((ROOT/'game'/active).read_bytes()).hexdigest()==previous[active]
retarget=json.loads((WORK/'retarget_validation.json').read_text())
assert len(retarget)==7
assert all(r['baked_pose_max_position_error_m']<1e-4 for r in retarget.values())
report={'source_preserved':True,'default_runtime_hero_preserved':True,'triangles':triangles,'export_vertices_with_seams':vertices,'materials':len(g['materials']),'skin_joints':len(skin['joints']),'moustache_bones_animated':len(animated_hair),'runtime_contract_clips':len(core),'all_clips':durations,'loop_seam_max_component_error':loop_errors,'max_weight_normalization_error':max_error,'rigid_revolver_attachment':'weapon.R','embedded_images':len(g['images']),'retarget_max_position_error_m':max(r['baked_pose_max_position_error_m'] for r in retarget.values()),'validation':'passed'}
(WORK/'export_validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
