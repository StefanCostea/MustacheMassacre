"""Final native reference-proportion and botanical material refinement."""
import bpy
from mathutils import Matrix

def refine_reference(scene):
    if scene.get('reference_proportions_refined'):return
    for o in bpy.data.collections['Hero • hat'].objects:
        o.matrix_world=Matrix.Diagonal((1.12,1.12,1,1))@o.matrix_world
    for name in ['Moustache sculpt -1','Moustache sculpt 1']:
        o=bpy.data.objects[name];o.matrix_world=Matrix.Diagonal((.93,1,1,1))@o.matrix_world
    skin=bpy.data.materials['Cactus | wax, pores, mottling'];nt=skin.node_tree
    for n in nt.nodes:
        if n.type=='TEX_VORONOI':n.inputs['Scale'].default_value=260
        if n.type=='BUMP' and abs(n.inputs['Distance'].default_value-.0004)<.00001:n.inputs['Distance'].default_value=.0008
    body=bpy.data.objects['Cactus torso — sculpted botanical ribs'];m=skin.copy();m.name='Cactus torso | longitudinal rib color';body.data.materials[0]=m
    nt=m.node_tree;bs=nt.nodes.get('Principled BSDF');old=bs.inputs['Base Color'].links[0].from_socket
    coords=nt.nodes.new('ShaderNodeTexCoord');sep=nt.nodes.new('ShaderNodeSeparateXYZ');nt.links.new(coords.outputs['Object'],sep.inputs[0])
    angle=nt.nodes.new('ShaderNodeMath');angle.operation='ARCTAN2';nt.links.new(sep.outputs['Y'],angle.inputs[0]);nt.links.new(sep.outputs['X'],angle.inputs[1])
    mul=nt.nodes.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=15;nt.links.new(angle.outputs[0],mul.inputs[0])
    co=nt.nodes.new('ShaderNodeMath');co.operation='COSINE';nt.links.new(mul.outputs[0],co.inputs[0])
    remap=nt.nodes.new('ShaderNodeMapRange');remap.inputs['From Min'].default_value=-1;remap.inputs['From Max'].default_value=1;remap.inputs['To Min'].default_value=.82;remap.inputs['To Max'].default_value=1.1;nt.links.new(co.outputs[0],remap.inputs['Value'])
    mix=nt.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=.35;nt.links.new(old,mix.inputs[1]);nt.links.new(remap.outputs['Result'],mix.inputs[2]);nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
    scene['reference_proportions_refined']=True

if __name__=='__main__':
    from pathlib import Path
    root=Path(__file__).resolve().parents[2];p=root/'desgin/character_models/DON_ESPINO_hero_v3.blend'
    bpy.ops.wm.open_mainfile(filepath=str(p));refine_reference(bpy.context.scene)
    bpy.ops.wm.save_as_mainfile(filepath=str(p),compress=True)
