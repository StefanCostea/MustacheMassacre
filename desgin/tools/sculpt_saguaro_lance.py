"""Sculpt one interlocking forearm of Don Espino's two-arm Saguaro Lance."""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sculpt_high_noon import Sculpt, linear, material, strand

OUT = Path(__file__).resolve().parents[2] / "game/assets/characters/saguaro_lance"
bpy.ops.wm.read_factory_settings(use_empty=True)
mesh = Sculpt()
pi = math.pi
# Each half owns four fluted columns. The flat inner edge meets its mirror
# along the centre seam. The lip doubles back inside to form a recessed bore.
profile = [(-.13,.075),(-.07,.139),(.03,.168),(.16,.208),(.33,.246),
           (.53,.278),(.72,.298),(.89,.302),(1.02,.282),(1.11,.300),
           (1.16,.290),(1.15,.224),(1.065,.202),(.94,.178),(.88,.035)]
for i,(z,radius) in enumerate(profile):
    for j in range(49):
        angle = -pi/2 + pi*j/48
        ridge = .5+.5*math.cos(8*angle + .28*math.sin(z*pi))
        r = radius*(.94+.095*ridge)
        x,y = r*math.cos(angle),r*math.sin(angle)
        mesh.vertices.append((x,-z,y))
        if i < 9:
            color = linear("285343").lerp(linear("8AAB59"),ridge*.71+.16*i/9)
        elif i < 12:
            color = linear("AE6132").lerp(linear("FFE190"),.32+.58*ridge)
        else:
            color = linear("3C2435").lerp(linear("C44B4B"),.30*ridge+.24*(14-i)/2)
        mesh.colors.append((*color,1));mesh.texcoords.append((i/14,j/48))
        if i and j:
            a=i*49+j
            mesh.faces.append((a-50,a-49,a,a-1))
# Close the inner cut surface so the two sides read as solid growing pads before contact.
for i in range(len(profile)-1):
    a=i*49
    mesh.faces.append((a,a+49,a+97,a+48))
for k in range(4):
    a = -pi/2+(k+.5)*pi/4
    radial=Vector((math.cos(a),math.sin(a),0))
    tangent=Vector((-math.sin(a),math.cos(a),0))
    for j in range(4):
        z=.17+j*.19 + .037*(k%2)
        r=.215+.076*math.sin((z-.12)*1.9)
        at=Vector((0,0,z))+radial*r
        strand(mesh,[at-tangent*.032,at+radial*.019,at+radial*.025,at+tangent*.032],
               .021,"AC7544","ECCC82",axis=(0,0,1),steps=8)
        for sign in [-1,1]:
            tip=at+radial*(.077+.018*j)+tangent*.039*sign+Vector((0,0,-.083))
            strand(mesh,[at, at+radial*.035, tip+Vector((0,0,.019)),tip],
                   .014,"C08746","FFE8A7",axis=(0,0,1),steps=7)
    base=radial*.254+Vector((0,0,.69))
    path=[base,radial*.366+Vector((0,0,.84)),radial*.34+Vector((0,0,1.06)),radial*.29+Vector((0,0,1.22+.04*(k%2)))]
    strand(mesh,path,.094,"405C35","E49B48",axis=tangent,flat=.45,steps=25)
    for z in [.33,.60]:
        at=radial*(.251 if z==.33 else .28)+Vector((0,0,z))
        strand(mesh,[at-tangent*.051,at+radial*.014-tangent*.02,at+radial*.015+tangent*.02,at+tangent*.051],
               .020,"AA4F44","EC9766",axis=(0,0,1),steps=10)
mesh.object("LanceForearm",material("Saguaro ribs, cork and amber"))
bpy.ops.export_scene.gltf(filepath=str(OUT/"lance_half.glb"),export_format='GLB',export_animations=False)
