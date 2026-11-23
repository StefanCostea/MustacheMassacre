from pathlib import Path
import bpy,json
from mathutils import Vector
p=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(p/'desgin/renders/don_espino/reference/source_inspection.blend'))
r={}
for o in bpy.context.scene.objects:
 if o.type=='MESH' and o.name!='Plane':
  coords=[o.matrix_world@v.co for v in o.data.vertices]
  r[o.name]={'bounds':[[round(f(c[i] for c in coords),3) for i in range(3)] for f in [min,max]],'parent':o.parent.name if o.parent else None,'parent_type':o.parent_type,'parent_bone':o.parent_bone,'modifiers':[(m.name,m.type) for m in o.modifiers],'matrix':[[round(v,3) for v in row] for row in o.matrix_world],'groups':[(g.name, len([v for v in o.data.vertices if any(q.group==g.index and q.weight>.5 for q in v.groups)])) for g in o.vertex_groups if g.name.startswith('DEF-')]}
print(json.dumps(r,indent=2))
(p/'desgin/renders/don_espino/reference/object_layout.json').write_text(json.dumps(r,indent=2))
for o in bpy.context.scene.objects:
 if o.type=='ARMATURE':print('RIG',o.name,len(o.data.bones),'action',o.animation_data.action.name if o.animation_data and o.animation_data.action else None)
