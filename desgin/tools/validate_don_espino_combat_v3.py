"""Reopen saved combat scenes and verify the posed weapon and first shot agree."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];report={}
for kind,filename,aim in [
    ('ricochet','DON_ESPINO_ricochet_v3.blend',(-2.65,-.10-.29*1.03,.98*1.03)),
    ('high_noon','DON_ESPINO_high_noon_v3.blend',(-2.65,.20,1.00))]:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'desgin/character_models/scenes'/filename))
    bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
    rig=bpy.data.objects['Don Espino | articulated hero rig'];gun=bpy.data.objects['Hollow revolver barrel']
    G=gun.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world
    muzzle=G@Vector((-.695,0,.105));direction=(G.to_3x3()@Vector((-1,0,0))).normalized()
    dot=direction.dot((Vector(aim)-muzzle).normalized())
    bad=[o.name for o in bpy.context.scene.objects if o.parent_type=='BONE' and o.parent_bone not in rig.data.bones]
    pose_action=rig.animation_data.action.name if rig.animation_data and rig.animation_data.action else None
    assert dot>.9999,(kind,dot)
    assert not bad
    assert pose_action
    report[kind]={'saved_scene':filename,'barrel_first_shot_alignment':dot,'invalid_bone_bindings':bad,'saved_pose_action':pose_action,'scope':'static posed native Blender scene'}
(ROOT/'desgin/renders/don_espino/v3/combat_validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2),flush=True)
