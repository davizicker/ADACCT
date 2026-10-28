"""Musgo (moss_01, Poly Haven, CC0): o pacote traz ~20 fiozinhos de 1-2 cm feitos para espalhar com Geometry Nodes.
Aqui eles viram TUFOS prontos (28 fios por tufo, ampliados 3-4x, 3 variações) para o Godot espalhar com MultiMesh.
Uso: python tools/blender/build_musgo.py <pasta_moss_01_1k.blend_1> saida.glb"""
import bpy, sys, os, math, random, json, struct

src, dst = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=os.path.join(src, "moss_01_1k.blend"))
fios = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("moss_01_") and o.name.endswith("LOD0") and "geometry" not in o.name]
fios += [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("moss_strand_") and o.name.endswith("LOD0")]
print("[musgo] fios:", len(fios))
tex = os.path.join(src, "textures")
mat = bpy.data.materials.new("musgo")
mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
out = nt.nodes.new("ShaderNodeOutputMaterial")
bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
d = nt.nodes.new("ShaderNodeTexImage")
d.image = bpy.data.images.load(os.path.join(tex, "moss_01_diff_1k.jpg"))
a = nt.nodes.new("ShaderNodeTexImage")
a.image = bpy.data.images.load(os.path.join(tex, "moss_01_alpha_1k.png"))
a.image.colorspace_settings.name = "Non-Color"
nt.links.new(d.outputs["Color"], bsdf.inputs["Base Color"])
nt.links.new(a.outputs["Color"], bsdf.inputs["Alpha"])
bsdf.inputs["Roughness"].default_value = 0.9

patches = []
for nome, seed in (("musgo_a", 1), ("musgo_b", 2), ("musgo_c", 3)):
    rng = random.Random(seed)
    bm_objs = []
    for i in range(28):
        o0 = rng.choice(fios)
        o = o0.copy()
        o.data = o0.data.copy()
        bpy.context.scene.collection.objects.link(o)
        r = 0.14 * math.sqrt(rng.random())
        t = rng.uniform(0, math.tau)
        s = rng.uniform(3.0, 4.2)
        o.scale = (s, s, s * rng.uniform(0.7, 1.2))
        o.rotation_euler = (rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), rng.uniform(0, math.tau))
        o.location = (r * math.cos(t), r * math.sin(t), 0)
        bm_objs.append(o)
    for ob in bpy.context.selected_objects:
        ob.select_set(False)
    for o in bm_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = bm_objs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.name = nome
    ob.location = (0, 0, 0)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    patches.append(ob)
for o in list(bpy.data.objects):
    if o not in patches:
        bpy.data.objects.remove(o)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_yup=True, export_image_format="AUTO", export_materials="EXPORT",
                          export_cameras=False, export_lights=False)
b = open(dst, "rb").read()
jl = struct.unpack("<I", b[12:16])[0]
j = json.loads(b[20:20 + jl])
for m in j.get("materials", []):
    m["alphaMode"] = "MASK"
    m["alphaCutoff"] = 0.4
    m["doubleSided"] = True
nj = json.dumps(j, separators=(",", ":")).encode()
nj += b" " * ((4 - len(nj) % 4) % 4)
o2 = b[:12] + struct.pack("<I", len(nj)) + b"JSON" + nj + b[20 + jl:]
o2 = o2[:8] + struct.pack("<I", len(o2)) + o2[12:]
open(dst, "wb").write(o2)
for p in patches:
    p.data.calc_loop_triangles()
    print("[musgo] %s: %d tris, %s" % (p.name, len(p.data.loop_triangles), tuple(round(x, 2) for x in p.dimensions)))
print("[musgo] exportado %s (%d KB)" % (dst, os.path.getsize(dst) // 1024))
