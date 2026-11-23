"""Transfer frontal high-frequency concept detail onto the existing sheriff UV islands."""
import io
import json
import struct
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
source = ROOT / "game/assets/enemies/design_review/el_frigorifico.glb"
out = ROOT / "desgin/character_models/generated/el_frigorifico/v02"
out.mkdir(parents=True, exist_ok=True)
with source.open("rb") as file:
    _, _, _, length, _ = struct.unpack("<4s4I", file.read(20))
    gltf = json.loads(file.read(length))
    file.read(8)
    binary = file.read()


def buffer(index):
    view = gltf["bufferViews"][index]
    start = view.get("byteOffset", 0)
    return binary[start:start + view["byteLength"]]


def accessor(index, columns):
    data = gltf["accessors"][index]
    item = np.dtype({5123: "<u2", 5125: "<u4", 5126: "<f4"}[data["componentType"]])
    stride = gltf["bufferViews"][data["bufferView"]].get("byteStride", columns * item.itemsize)
    return np.ndarray((data["count"], columns), dtype=item, buffer=buffer(data["bufferView"]),
                      offset=data.get("byteOffset", 0), strides=(stride, item.itemsize))


mesh_index = next(n["mesh"] for n in gltf["nodes"] if n["name"] == "el_frigorifico")
prim = gltf["meshes"][mesh_index]["primitives"][0]
material = gltf["materials"][prim["material"]]["pbrMetallicRoughness"]


def read_map(slot):
    texture = gltf["textures"][material[slot]["index"]]
    image = texture.get("source", texture.get("extensions", {}).get("EXT_texture_webp", {}).get("source"))
    return np.array(Image.open(io.BytesIO(buffer(gltf["images"][image]["bufferView"]))).convert("RGB"))


color = read_map("baseColorTexture")
orm = read_map("metallicRoughnessTexture")
points = accessor(prim["attributes"]["POSITION"], 3) / 2.6
normals = accessor(prim["attributes"]["NORMAL"], 3)
uv = accessor(prim["attributes"]["TEXCOORD_0"], 2) * [color.shape[1], color.shape[0]] - 0.5
triangles = accessor(prim["indices"], 1).reshape(-1, 3)
reference = np.array(Image.open(ROOT / "desgin/renders/el_frigorifico/concepts/v01/character.png").convert("RGB"))
h, w = reference.shape[:2]
# Unwrap the four frosted lips into individual strips. Trace the lower edge's
# arc so the white crystals stay on the leading edge when a shutter tilts.
u, v = np.meshgrid(np.linspace(-1, 1, 384), np.linspace(0, 1, 40))
strips = []
for half_width, lower, bow, depth in [(245,101,16,54),(285,190,19,56),(298,278,17,57),(298,350,8,51)]:
    x = (0.32 + 0.353 * (342 + u*half_width) / 689) * w
    y = (0.475 + 0.155 * (lower + bow*u**2 - depth*(1-v)) / 414) * h
    strips.append(cv2.remap(reference, x.astype(np.float32), y.astype(np.float32), cv2.INTER_LINEAR))
Image.fromarray(np.concatenate(strips)).save(out/"sheriff_frost.png")
reference = reference.astype(np.float32)
# Subtract broad studio illumination. Retain carved fibres, enamel wear and leather grain.
fine = reference - cv2.GaussianBlur(reference, (0, 0), 4.5)
mid = cv2.GaussianBlur(reference, (0, 0), 1.8) - cv2.GaussianBlur(reference, (0, 0), 13)
detail = (fine * 1.30 + mid * .48).clip(-52, 52)
correction = np.zeros_like(color, dtype=np.float32)
valid = np.zeros(color.shape[:2], np.uint8)
for face in triangles:
    verts = uv[face]
    lo = np.maximum(np.ceil(verts.min(0)).astype(int), 0)
    hi = np.minimum(np.floor(verts.max(0)).astype(int), [color.shape[1]-1, color.shape[0]-1])
    if np.any(hi < lo):
        continue
    a, b = verts[1]-verts[0], verts[2]-verts[0]
    det = a[0]*b[1] - a[1]*b[0]
    if abs(det) < 1e-8:
        continue
    iy, ix = np.mgrid[lo[1]:hi[1]+1, lo[0]:hi[0]+1]
    dx, dy = ix-verts[0, 0], iy-verts[0, 1]
    u, v = (dx*b[1]-dy*b[0])/det, (a[0]*dy-a[1]*dx)/det
    inside = (u >= 0) & (v >= 0) & (u+v <= 1)
    u, v, iy, ix = u[inside], v[inside], iy[inside], ix[inside]
    weights = np.column_stack((1-u-v, u, v))
    x, z, front = (weights @ points[face]).T
    facing = weights @ normals[face, 2]
    # Landmarks at the belt, moustache part, brows, brim, band and hat crown.
    py = np.interp(z, [0,.24,.315,.50,.575,.65,.71,.79,.83,1],
                       [.971,.700,.661,.454,.385,.324,.244,.198,.161,.015])
    px = .5 + x * np.interp(z, [0,.27,.54,.63,.79,1], [1.20,1.21,1.29,1.29,1.22,1.22])
    sx = (px * (w-1)).round().astype(int).clip(0,w-1)
    sy = (py * (h-1)).round().astype(int).clip(0,h-1)
    mix = np.clip((facing-.10)/.66,0,1)*np.clip((front-.04)/.10,0,1)
    correction[iy, ix] = detail[sy,sx] * mix[:,None]
    valid[iy, ix] = 1
    # Felt and hair are dielectric. Preserve metal response on the buckle and vent.
    hair = (z>.535)&(z<.635)&(front>.177)
    felt = (z>.78)&((z<.824)|(z>.858))
    organic = hair | felt
    oy, ox = iy[organic], ix[organic]
    orm[oy,ox,2] = (orm[oy,ox,2]*.10).astype(np.uint8)
    orm[oy,ox,1] = np.maximum(orm[oy,ox,1], 168)
# Extend the correction over atlas seams for bilinear filtering.
padded = cv2.dilate(valid, np.ones((5,5),np.uint8)) - valid
for channel in range(3):
    correction[:,:,channel] = cv2.inpaint(correction[:,:,channel], padded, 2, cv2.INPAINT_NS)
Image.fromarray((color.astype(np.float32) + correction).clip(0,255).astype(np.uint8)).save(out/"sheriff_color.png")
Image.fromarray(orm).save(out/"sheriff_metal_rough.png")
