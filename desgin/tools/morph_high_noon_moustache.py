"""Build the two High Noon morph skins from the playable models and Blender feather sculpt.

Uses NumPy, Pillow and SciPy. The natural and motion-study bodies have identical
geometry and named skin bindings. The existing models and actions are read-only.
"""
import copy
import io
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from scipy.spatial import cKDTree

ROOT = Path(__file__).resolve().parents[2] / "game/assets/characters"
OUT = ROOT / "high_noon"
TYPES = {5121: "u1", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
HERO_SCALE = .62


class Source:
    def __init__(self, path):
        raw = path.read_bytes()
        size = struct.unpack_from("<I", raw, 12)[0]
        self.doc = json.loads(raw[20:20+size])
        self.data = raw[28+size:]

    def view(self, index):
        view = self.doc["bufferViews"][index]
        start = view.get("byteOffset", 0)
        return self.data[start:start+view["byteLength"]]

    def array(self, index):
        acc = self.doc["accessors"][index]
        width = WIDTH[acc["type"]]
        result = np.frombuffer(self.view(acc["bufferView"]), TYPES[acc["componentType"]],
                               acc["count"]*width, acc.get("byteOffset", 0)).reshape(-1, width)
        if acc.get("normalized"):
            return result.astype(float)/np.iinfo(result.dtype).max
        return result

    def vertex_colours(self, material, uv):
        tex = self.doc["materials"][material]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
        image = self.doc["images"][self.doc["textures"][tex]["source"]]
        atlas = np.asarray(Image.open(io.BytesIO(self.view(image["bufferView"]))).convert("RGB"))
        return atlas[(uv[:, 1]%1*atlas.shape[0]).astype(int), (uv[:, 0]%1*atlas.shape[1]).astype(int)]


class SkinFile:
    def __init__(self, source, body_node):
        self.data = bytearray()
        self.doc = {k: copy.deepcopy(source.doc[k]) for k in ("nodes", "scenes", "scene", "skins")}
        self.doc.update(asset={"version": "2.0"}, meshes=[], bufferViews=[], accessors=[])
        for n in self.doc["nodes"]:
            n.pop("mesh", None)
            n.pop("skin", None)
        body = self.doc["nodes"][body_node]
        body.update(mesh=0, skin=0, name="NoonFace")
        hair_node = len(self.doc["nodes"])
        self.doc["nodes"].append(dict(body, mesh=1, name="NoonHandlebar"))
        parent = next(n for n in self.doc["nodes"] if body_node in n.get("children", []))
        parent["children"].append(hair_node)
        for skin in self.doc["skins"]:
            skin["inverseBindMatrices"] = self.add(source.array(skin["inverseBindMatrices"]), "MAT4")

    def add(self, values, kind=None, component=5126):
        a = np.ascontiguousarray(values, dtype=TYPES[component])
        kind = kind or {v:k for k,v in WIDTH.items()}[a.shape[1] if a.ndim > 1 else 1]
        view = len(self.doc["bufferViews"])
        self.doc["bufferViews"].append(dict(buffer=0, byteOffset=len(self.data), byteLength=a.nbytes))
        self.data.extend(a.tobytes())
        self.data.extend(b'\x00' * (-len(self.data)%4))
        acc = dict(bufferView=view, componentType=component, count=len(a), type=kind)
        if kind=="VEC3":
            acc.update(min=a.min(axis=0).tolist(), max=a.max(axis=0).tolist())
        self.doc["accessors"].append(acc)
        return len(self.doc["accessors"])-1

    def primitive(self, attrs, triangles):
        attributes = {k:self.add(v, component=5123 if k=="JOINTS_0" else 5126) for k,v in attrs.items()}
        return dict(attributes=attributes, indices=self.add(triangles.reshape(-1), "SCALAR", 5125))

    def save(self, path):
        self.doc["buffers"] = [{"byteLength":len(self.data)}]
        meta = json.dumps(self.doc, separators=(",",":")).encode()
        meta += b" " * (-len(meta)%4)
        path.write_bytes(struct.pack("<4sIIII", b"glTF", 2, 28+len(meta)+len(self.data), len(meta), 0x4e4f534a)
                         + meta + struct.pack("<I4s",len(self.data),b"BIN\x00") + self.data)


def islands(pos, triangles):
    unique, inv = np.unique(pos.round(5), axis=0, return_inverse=True)
    edges = inv[triangles[:, [0,1,1,2,2,0]].reshape(-1,2)]
    graph = coo_matrix((np.ones(len(edges)),edges.T),shape=(len(unique),len(unique)))
    return connected_components(graph,directed=False)[1][inv]


def subset(attrs, triangles):
    ids, index = np.unique(triangles, return_inverse=True)
    return {k:v[ids] for k,v in attrs.items()}, index.reshape(-1,3), ids


def normals(p, triangles):
    n = np.zeros_like(p)
    a,b,c = p[triangles].transpose((1,0,2))
    crosses = np.cross(b-a,c-a)
    for column in triangles.T:
        np.add.at(n,column,crosses)
    return n / np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1.e-12)


def hair_patch(src, primitive, attrs, faces, natural):
    pos = attrs["POSITION"]
    component = islands(pos,faces)
    if not natural:
        # Each lobe of the original is a whole sculpted island. The brows and brim are higher.
        labels = [i for i in np.unique(component) if pos[component==i,1].min()<2.20]
        assert len(labels)==2
        return np.isin(component[faces[:,0]],labels)
    # The scan fuses the lobes into the face. Select their bronze surface below the eyes.
    x,y,z = pos[faces].mean(1).T
    r,g,b = src.vertex_colours(primitive["material"],attrs["TEXCOORD_0"])[faces].mean(1).T
    main = np.bincount(component).argmax()
    lip = (component[faces[:,0]]==main)&(abs(x)<.49)&(y>1.505)&(y<1.961)&(z>.16)
    bronze = lip & (r>g*1.07) & (g>b*1.015)
    # Take the one-triangle seam on the fused underside as well.
    rim = np.zeros(len(pos),bool)
    rim[faces[bronze]]=True
    return bronze | (lip & rim[faces].any(1) & (r>g*.84))


def exposed_skin(src, primitive, attrs):
    """Reconstruct the sliver of cactus underneath the scan's welded upper lip."""
    angle, height = np.meshgrid(np.linspace(-1.40,1.40,37),np.linspace(1.51,1.956,13))
    a = angle.ravel()
    y = height.ravel()
    x = .331*np.sin(a)
    z = .026+.328*np.cos(a)
    pos = np.column_stack([x,y,z])
    normal = np.column_stack([np.sin(a),np.zeros_like(a),np.cos(a)])
    skin_pos = attrs["POSITION"]
    rgb = src.vertex_colours(primitive["material"],attrs["TEXCOORD_0"])
    # Sample the vertical green ribs immediately below the scan seam.
    usable = (skin_pos[:,2]>.02)&(skin_pos[:,1]>1.36)&(skin_pos[:,1]<1.55)&(rgb[:,1]>1.2*rgb[:,0])
    donors = np.flatnonzero(usable)
    tree = cKDTree(skin_pos[donors])
    _, near = tree.query(np.column_stack([x,1.44+.16*(y-1.5),z]),k=4)
    pigments = rgb[donors[near]].mean(axis=1)/255.
    linear = np.where(pigments>.04045,((pigments+.055)/1.055)**2.4,pigments/12.92)
    # Follow the surrounding cheek when the torso or neck bends.
    cactus = np.flatnonzero((rgb[:,1]>1.23*rgb[:,0]) & (skin_pos[:,2]>.02))
    _, nearby = cKDTree(skin_pos[cactus]).query(pos)
    bind = cactus[nearby]
    grid = np.arange(len(pos)).reshape(angle.shape)
    lo,hi = grid[:-1,:-1].ravel(),grid[1:,:-1].ravel()
    tri = np.concatenate([np.column_stack([lo,lo+1,hi]),np.column_stack([lo+1,hi+1,hi])])
    return dict(POSITION=pos,NORMAL=normal,COLOR_0=linear,JOINTS_0=attrs["JOINTS_0"][bind],
                WEIGHTS_0=attrs["WEIGHTS_0"][bind]),tri


def build(source_path, natural):
    src = Source(source_path)
    node = next(i for i,n in enumerate(src.doc["nodes"]) if n.get("name")==("Natural_Skin" if natural else "Runtime_face_hat"))
    prim = src.doc["meshes"][src.doc["nodes"][node]["mesh"]]["primitives"][0]
    attrs = {k:src.array(v) for k,v in prim["attributes"].items()}
    faces = src.array(prim["indices"]).reshape(-1,3)
    take = hair_patch(src,prim,attrs,faces,natural)
    assert 2100 < take.sum() < 10000
    file = SkinFile(src,node)
    bare, bare_faces, _ = subset(attrs,faces[~take])
    face = file.primitive(bare,bare_faces)
    surfaces = [face]
    if natural:
        patch, patch_faces = exposed_skin(src,prim,attrs)
        cap = file.primitive(patch,patch_faces)
        file.doc["materials"] = [dict(name="SourceSkin"),dict(name="ExposedCactus",
                                  pbrMetallicRoughness=dict(metallicFactor=0.,roughnessFactor=.83))]
        face["material"] = 0
        cap["material"] = 1
        surfaces.append(cap)
    file.doc["meshes"].append(dict(name="FaceDuringHighNoon",primitives=surfaces))
    hair, hair_faces, _ = subset(attrs,faces[take])
    p = hair["POSITION"].copy()
    s = np.sign(p[:,0])
    if not natural:
        # The two moustache roots overlap slightly at the centre seam.
        labels = islands(p,hair_faces)
        for label in np.unique(labels):
            s[labels==label] = np.sign(p[labels==label,0].mean())
    span = np.max(abs(p[:,0]))
    u = np.clip(p[:,0]*s/span,0,1)
    sections = np.linspace(0,1,33)
    centres = np.array([np.median(p[abs(u-t)<.037,1:],axis=0) for t in sections])
    anchors = np.stack([np.interp(u,sections,c) for c in centres.T],axis=1)
    # Both lobes keep the thickness and grooves of their actual surface as they straighten.
    lip_y, lip_z = centres[0]
    def spine(t, half_span, rise):
        return np.stack([t*half_span, -.15*np.sin(np.pi*t)+rise*t*t, -.21*t*t],axis=-1)/HERO_SCALE
    def rest(t):
        return np.stack([t*span,*[np.interp(t,sections,c) for c in centres.T]],axis=-1)
    def hair_shape(width, rise):
        v = spine(u,width,rise)
        v[:,0] *= s
        v[:,1:] += np.array([lip_y,lip_z]) + (p[:,1:]-anchors)*.92
        return v
    uncurled = hair_shape(.78,.095)
    upper = hair_shape(1.72,.71)
    lower = hair_shape(1.72,.03)
    reach = [u*.73]
    feather_flag = [np.zeros(len(p))]
    colours = [np.ones((len(p),3))]
    wing = Source(OUT/"handlebar_wing.glb")
    feathers = wing.doc["meshes"][0]["primitives"][0]
    sculpt = {k:wing.array(a) for k,a in feathers["attributes"].items()}
    wing_faces = wing.array(feathers["indices"]).reshape(-1,3)
    groups = islands(sculpt["POSITION"],wing_faces)
    # The real moustache now supplies the leading edge. Keep only the locks that branch from it.
    locks = [i for i in np.unique(groups) if sculpt["POSITION"][groups==i,0].min()>.04]
    sculpt, wf, _ = subset(sculpt,wing_faces[np.isin(groups[wing_faces[:,0]],locks)])
    wp = sculpt["POSITION"]
    # Interior folds follow the native hair at a fraction of their finished reach.
    fold_u = np.clip(wp[:,0]/2.30,0,1)
    folded = rest(fold_u)
    start = spine(fold_u,.78,.095) + [0,lip_y,lip_z]
    # The branches sit under the straightened whisker, then flex down in the same stroke.
    opened = wp.copy()
    opened[:,1] += .12*(wp[:,0]/2.3)**2
    opened = opened/HERO_SCALE+[0,lip_y,lip_z]
    dipped = opened.copy()
    dipped[:,1] -= .68/HERO_SCALE*(wp[:,0]/1.72)**1.65
    dipped[:,2] -= .11/HERO_SCALE*fold_u**2
    head = src.doc["skins"][0]["joints"].index(next(i for i,n in enumerate(src.doc["nodes"]) if n["name"]==("mixamorig:Head" if natural else "head")))
    poses = [[p],[uncurled],[upper],[lower]]
    uv = [hair["TEXCOORD_0"]]
    triangles = [hair_faces]
    for side in [-1,1]:
        offset = sum(len(part) for part in poses[0])
        mirror = [side,1,1]
        for parts, shape in zip(poses,[folded,start,opened,dipped]):
            parts.append(shape*mirror)
        triangles.append(offset+(wf[:,::-1] if side<0 else wf))
        reach.append(fold_u)
        feather_flag.append(np.ones(len(wp)))
        colours.append(sculpt["COLOR_0"])
        uv.append(sculpt["TEXCOORD_0"])
    rest_pose, *shapes = [np.concatenate(parts) for parts in poses]
    tri = np.concatenate(triangles)
    base_n = normals(rest_pose,tri)
    base_n[:len(p)]=hair["NORMAL"]
    # Folded vanes are inside the hair at rest, so use their open normals as the limit.
    opened_n = normals(shapes[1],tri)
    base_n[len(p):]=opened_n[len(p):]
    joints = np.zeros((len(rest_pose),4),dtype=int)
    weights = np.zeros_like(joints,dtype=float)
    joints[:,0]=head
    weights[:,0]=1.
    joints[:len(p)] = hair["JOINTS_0"]
    weights[:len(p)] = hair["WEIGHTS_0"]
    joints[weights==0] = head
    used, remap = np.unique(joints,return_inverse=True)
    joints = remap.reshape(joints.shape)
    source_skin = src.doc["skins"][0]
    matrices = src.array(source_skin["inverseBindMatrices"])[used]
    file.doc["skins"].append(dict(name="HandlebarBind",joints=[source_skin["joints"][i] for i in used],
                                  inverseBindMatrices=file.add(matrices,"MAT4")))
    file.doc["nodes"][-1]["skin"] = 1
    morph = file.primitive(dict(POSITION=rest_pose,NORMAL=base_n,TEXCOORD_0=np.concatenate(uv),
                                TEXCOORD_1=np.stack([np.concatenate(reach),np.concatenate(feather_flag)],axis=1),
                                COLOR_0=np.concatenate(colours),JOINTS_0=joints,WEIGHTS_0=weights),tri)
    # Lift the original handlebar tips during ordinary combat. The wing vanes stay folded.
    curl = rest_pose.copy()
    bend = np.clip((u - .18) / .82, 0, 1)
    curl[:len(p), 0] += s * (.14*np.sin(np.pi*bend*.78) - .055*bend**3)
    curl[:len(p), 1] += .38*bend**2
    shapes.append(curl)
    morph["targets"] = []
    for i,shape in enumerate(shapes):
        n = normals(shape,tri)
        if i==0:n[len(p):]=opened_n[len(p):]
        morph["targets"].append(dict(POSITION=file.add(shape-rest_pose),NORMAL=file.add(n-base_n)))
    file.doc["meshes"].append(dict(name="MoustacheToWings",primitives=[morph],weights=[0,0,0,0],
                                   extras={"targetNames":["Uncurl","Upstroke","Downstroke","MomentumCurl"]}))
    name = "natural" if natural else "original"
    file.save(OUT/f"handlebar_{name}.glb")
    print(name, "moustache faces",len(hair_faces),"feather faces per side",len(wf),"lip",lip_y,lip_z)


if __name__=="__main__":
    build(ROOT/"don_espino/don_espino.glb",False)
    build(ROOT/"don_espino_natural_review/don_espino_natural.glb",True)
