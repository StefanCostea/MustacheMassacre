"""Sculpt cloth compression folds and add subtle botanical skin freckles."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from espino_v3_helpers import *

def refine_surfaces(scene):
    if scene.get('hero_surface_refined'):return
    def cloth_displace(p):
        x,y,z=p;a=abs(x)
        if z>1.43 or z<1.09:return p
        fade=sin(pi*max(0,min(1,(z-1.09)/.34)))**1.2
        line=z-(1.19+.30*(a-.12))
        amp=(.018*math.exp(-(line/.020)**2)-.009*math.exp(-((line+.027)/.018)**2))
        amp+=(.011*math.exp(-((line-.088)/.022)**2)-.005*math.exp(-((line-.062)/.015)**2))
        amp*=fade*math.exp(-((a-.28)/.20)**2)*min(1,abs(y)/.14)
        return Vector((x,y+(1 if y>0 else -1)*amp,z))
    for o in bpy.data.collections['Hero • shorts'].objects:
        if o.type=='MESH':
            for v in o.data.vertices:v.co=cloth_displace(v.co)
            o.data.update()
        elif o.type=='CURVE':
            for sp in o.data.splines:
                for p in sp.points:
                    q=cloth_displace(p.co.xyz);p.co=(*q,p.co.w)
    for name in ['Cactus | wax, pores, mottling','Cactus torso | longitudinal rib color']:
        m=bpy.data.materials[name];nt=m.node_tree;bs=nt.nodes.get('Principled BSDF');old=bs.inputs['Base Color'].links[0].from_socket
        v=mapping(nt);vor=nt.nodes.new('ShaderNodeTexVoronoi');vor.inputs['Scale'].default_value=36;nt.links.new(v,vor.inputs['Vector'])
        r=nt.nodes.new('ShaderNodeValToRGB');r.color_ramp.elements[0].position=.055;r.color_ramp.elements[0].color=(.60,.60,.60,1);r.color_ramp.elements[1].position=.14;r.color_ramp.elements[1].color=(0,0,0,1);nt.links.new(vor.outputs['Distance'],r.inputs[0])
        mix=nt.nodes.new('ShaderNodeMixRGB');nt.links.new(r.outputs['Color'],mix.inputs[0]);nt.links.new(old,mix.inputs[1]);mix.inputs[2].default_value=(.48,.43,.12,1);nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
        bs.inputs['Roughness'].default_value=.54;bs.inputs['Subsurface Weight'].default_value=.05
    scene['hero_surface_refined']=True

def seat_shoulders(scene):
    if scene.get('hero_shoulders_seated'):return
    # Bury the capped upper-arm roots inside the torso for a continuous silhouette.
    for side,sign in [('R',-1),('L',1)]:
        o=bpy.data.objects['Continuous posed arm.'+side]
        for v in o.data.vertices:
            t=(v.index//32)/99
            if t<.22:v.co.x-=sign*.09*(1-t/.22)**2
        o.data.update()
    scene['hero_shoulders_seated']=True

if __name__=='__main__':
    root=Path(__file__).resolve().parents[2];p=root/'desgin/character_models/DON_ESPINO_hero_v3.blend'
    bpy.ops.wm.open_mainfile(filepath=str(p));refine_surfaces(bpy.context.scene);seat_shoulders(bpy.context.scene)
    bpy.ops.wm.save_as_mainfile(filepath=str(p),compress=True)
