"""Converte os "tiny weeds" (Nobiax, CC0) de OBJ+TGA para GLB com recorte de alfa, para o PropKit.
Uso: python tools/blender/converte_matos.py <pasta_tiny_weeds> <saida_dir>
Cada pasta 01/02/03 vira mato_a/b/c.glb (escala cm -> m, cartões com textura recortada e normal map)."""
import bpy, sys, os, json, struct

src, dst = sys.argv[-2], sys.argv[-1]
MAP = {"01": ("tiny_weed_03_01.obj", "mato_a"), "02": ("tiny_weeds_03_02.obj", "mato_b"), "03": ("tiny_weeds_03_03.obj", "mato_c")}


def patch_glb(path):
    """alphaMode MASK + doubleSided em todos os materiais (o exportador do Blender não faz isso sozinho com cartões)."""
    b = open(path, "rb").read()
    jl = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    for m in j.get("materials", []):
        m["alphaMode"] = "MASK"
        m["alphaCutoff"] = 0.45
        m["doubleSided"] = True
        pb = m.setdefault("pbrMetallicRoughness", {})
        pb["metallicFactor"] = 0.0
        pb["roughnessFactor"] = 0.9
    nj = json.dumps(j, separators=(",", ":")).encode()
    nj += b" " * ((4 - len(nj) % 4) % 4)
    rest = b[20 + jl:]
    out = b[:12] + struct.pack("<I", len(nj)) + b"JSON" + nj + rest
    out = out[:8] + struct.pack("<I", len(out)) + out[12:]
    open(path, "wb").write(out)


for pasta, (obj, nome) in MAP.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.obj_import(filepath=os.path.join(src, pasta, obj), forward_axis="NEGATIVE_Z", up_axis="Y")
    ob = bpy.context.scene.objects[0]
    ob.scale = (0.01, 0.01, 0.01)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(scale=True)
    mat = bpy.data.materials.new(nome)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(src, pasta, "diffuse.tga"))
    tex.image.alpha_mode = "STRAIGHT"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    nrm = nt.nodes.new("ShaderNodeTexImage")
    nrm.image = bpy.data.images.load(os.path.join(src, pasta, "normal.tga"))
    nrm.image.colorspace_settings.name = "Non-Color"
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nrm.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.9
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    ob.name = nome
    bpy.ops.object.shade_smooth()
    saida = os.path.join(dst, nome + ".glb")
    bpy.ops.export_scene.gltf(filepath=saida, export_format="GLB", export_yup=True, export_image_format="AUTO",
                              export_materials="EXPORT", export_cameras=False, export_lights=False)
    patch_glb(saida)
    ob.data.calc_loop_triangles()
    print("[matos] %s: %d tris, %.2f x %.2f x %.2f m, %d KB" % (nome, len(ob.data.loop_triangles), *ob.dimensions, os.path.getsize(saida) // 1024))


# ---- hera: as 5 peças de hera (default, bend L/R, corner H/V) num único .glb, um nó por peça ----
bpy.ops.wm.read_factory_settings(use_empty=True)
mat = bpy.data.materials.new("hera_real")
mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
out = nt.nodes.new("ShaderNodeOutputMaterial")
bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = bpy.data.images.load(os.path.join(src, "ivy", "diffuse.tga"))
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
nrm = nt.nodes.new("ShaderNodeTexImage")
nrm.image = bpy.data.images.load(os.path.join(src, "ivy", "normal.tga"))
nrm.image.colorspace_settings.name = "Non-Color"
nm = nt.nodes.new("ShaderNodeNormalMap")
nt.links.new(nrm.outputs["Color"], nm.inputs["Color"])
nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
bsdf.inputs["Roughness"].default_value = 0.85
for nome in ["ivy_default", "ivy_bend_left", "ivy_bend_right", "ivy_corner_horizontal", "ivy_corner_vertical"]:
    bpy.ops.wm.obj_import(filepath=os.path.join(src, "ivy", nome + ".obj"), forward_axis="NEGATIVE_Z", up_axis="Y")
    ob = bpy.context.selected_objects[0] if bpy.context.selected_objects else bpy.context.scene.objects[-1]
    ob.name = nome
    ob.scale = (0.01, 0.01, 0.01)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.transform_apply(scale=True)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
saida = os.path.join(dst, "hera.glb")
bpy.ops.export_scene.gltf(filepath=saida, export_format="GLB", export_yup=True, export_image_format="AUTO", export_materials="EXPORT",
                          export_cameras=False, export_lights=False)
patch_glb(saida)
print("[matos] hera.glb: %d peças, %d KB" % (len([o for o in bpy.data.objects if o.type == "MESH"]), os.path.getsize(saida) // 1024))
