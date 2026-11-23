"""Inspect actual exported GLB data: clips, sockets, skin and source integrity."""
from pathlib import Path
import hashlib,json,struct

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'desgin/character_models/refined/don_espino_workflow'
path=WORK/'DonEspino_animation_pilot_NOT_APPROVED.glb'
raw=path.read_bytes();assert raw[:4]==b'glTF'
chunks={};offset=12
while offset<len(raw):
    size,kind=struct.unpack_from('<II',raw,offset);chunks[kind]=raw[offset+8:offset+8+size];offset+=8+size
g=json.loads(chunks[0x4E4F534A]);binary=chunks[0x004E4942]

def accessor(index):
    a=g['accessors'][index];v=g['bufferViews'][a['bufferView']]
    fmt,width={5126:('f',4),5125:('I',4),5123:('H',2),5121:('B',1),5122:('h',2),5120:('b',1)}[a['componentType']]
    size={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',size*width)
    result=[struct.unpack_from('<'+fmt*size,binary,start+i*stride) for i in range(a['count'])]
    if a.get('normalized') and fmt!='f':
        divisor={5125:4294967295,5123:65535,5121:255,5122:32767,5120:127}[a['componentType']]
        result=[tuple(x/divisor for x in row) for row in result]
    return result

names={n.get('name') for n in g['nodes']}
required={'idle','walk','run_forward','shoot','stache_frenzy'}
clips={a['name']:a for a in g.get('animations',[])}
assert set(clips)==required,sorted(clips)
assert {'Muzzle','GunOrigin'}<=names
assert not g.get('cameras')
assert not any(n.get('name') in ['Cube','Review_Studio_Ground'] for n in g['nodes'])
stache={f'stache_{part}.{side}' for side in ['L','R'] for part in ['root','mid','tip']}
assert stache<=names
max_error=0;triangles=0;vertices=0
skin=g['skins'][0]
for mesh in g['meshes']:
    for p in mesh['primitives']:
        triangles+=g['accessors'][p['indices']]['count']//3
        weights=accessor(p['attributes']['WEIGHTS_0']);joints=accessor(p['attributes']['JOINTS_0'])
        vertices+=len(weights)
        assert len(weights)==len(joints)==g['accessors'][p['attributes']['POSITION']]['count']
        for w,j in zip(weights,joints):
            max_error=max(max_error,abs(sum(w)-1))
            assert all(0<=x<len(skin['joints']) for x in j)
        assert max_error<1e-4,max_error
animated_stache=set()
durations={}
for name,a in clips.items():
    assert a['channels'] and a['samplers']
    durations[name]=max(max(row[0] for row in accessor(s['input'])) for s in a['samplers'])
    for channel in a['channels']:
        node=g['nodes'][channel['target']['node']].get('name')
        if node in stache:animated_stache.add(node)
assert animated_stache==stache
audit=json.loads((WORK/'audit.json').read_text())
assert hashlib.sha256((ROOT/audit['source']).read_bytes()).hexdigest()==audit['source_sha256']
historical=json.loads((ROOT/'build/verification/archive_verification.json').read_text())['tested_game_hashes']
active='assets/characters/don_espino/don_espino.glb'
assert hashlib.sha256((ROOT/'game'/active).read_bytes()).hexdigest()==historical[active]
report={'source_preserved':True,'active_game_hero_unchanged':True,'triangles':triangles,'vertices_with_uv_splits':vertices,'skin_joints':len(skin['joints']),'moustache_bones_animated':len(animated_stache),'clips':durations,'max_weight_normalization_error':max_error,'sockets':['Muzzle','GunOrigin'],'structural_validation':'passed','visual_quality':'NOT APPROVED: source pose/prop and limb deformation still require reconstruction'}
(WORK/'export_validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
