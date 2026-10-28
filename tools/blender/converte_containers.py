"""Medieval Containers (Daniel74, blendswap 76295, CC0): barris, cestos, caixotes, baldes, jarros, potes, sacos.
O .blend vem de Blender Internal: as texturas ficaram soltas (empacotadas, mas não ligadas aos materiais).
Este script religa cada imagem ao material certo, zera a posição de cada objeto e exporta UM .glb (um nó por variação),
para o PropKit (PropKit.make_cont). Uso: python tools/blender/converte_containers.py ContainersUpload.blend saida.glb"""
import bpy, sys, os

src, dst = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=src)
IMG = {"Wood": "Wood.jpg", "RustedMetal": "Rusted Metal.jpg", "LogEdgeWeathered": "TreeLogEdgeWeathered.jpg", "Wicker": "Wicker.jpg",
       "WickerRound": "WickerRound.jpg", "Pottery": "Pottery.jpg", "Leather": "BrownLeather.jpg", "Cloth": "Cloth.jpg", "Rope": "Rope.jpg",
       "Wheat": "Wheat.jpg", "WheatFlour": "WheatFlour.jpg", "Peas": "Peas.jpg"}
ROUGH = {"RustedMetal": 0.55, "Pottery": 0.6, "Leather": 0.7}
for m in bpy.data.materials:
    if m.name not in IMG:
        continue
    img = bpy.data.images.get(IMG[m.name])
    if img is None:
        print("[cont] sem imagem para", m.name)
        continue
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = img
    nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = ROUGH.get(m.name, 0.85)
    bsdf.inputs["Metallic"].default_value = 0.35 if m.name == "RustedMetal" else 0.0
# só as malhas; cada uma na origem, com transformações aplicadas
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
sem_uv = [o.name for o in meshes if not o.data.uv_layers]
for o in meshes:
    o.location = (0, 0, 0)
    for p in o.data.polygons:
        p.use_smooth = True
print("[cont] %d malhas; sem UV: %s" % (len(meshes), sem_uv))
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_yup=True, export_image_format="JPEG", export_jpeg_quality=85,
                          export_materials="EXPORT", export_cameras=False, export_lights=False)
print("[cont] exportado %s (%d KB)" % (dst, os.path.getsize(dst) // 1024))
