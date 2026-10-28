"""Cria níveis de detalhe (LOD) dos modelos de planta do Poly Haven que o jogo usa muito:
wild_rooibos_bush (16 mil triângulos) e dead_tree_trunk (9 mil). Saída: plantas_lod.glb com rooibos_L0/L1 e tronco_L0/L1
(mesmos materiais e UVs; só menos triângulos). Uso: python tools/blender/build_lods.py assets/models/poly assets/models/poly/plantas_lod.glb"""
import bpy, sys, os

pasta, dst = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
saida = []
for arq, nome, alvos in (("wild_rooibos_bush.glb", "rooibos", (5500, 1300)), ("dead_tree_trunk.glb", "tronco", (4000, 900))):
    for lod, alvo in enumerate(alvos):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(pasta, arq))
        novos = [o for o in bpy.data.objects if o not in before]
        meshes = [o for o in novos if o.type == "MESH"]
        for o in novos:
            o.select_set(o in meshes)
        bpy.context.view_layer.objects.active = meshes[0]
        for o in meshes:
            o.parent = None
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if len(meshes) > 1:
            bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        for o in [o for o in bpy.data.objects if o not in before and o != ob and o.type != "MESH"]:
            bpy.data.objects.remove(o)
        ob.data.calc_loop_triangles()
        n0 = len(ob.data.loop_triangles)
        md = ob.modifiers.new("d", "DECIMATE")
        md.ratio = min(1.0, alvo / n0)
        md.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=md.name)
        ob.data.calc_loop_triangles()
        ob.name = "%s_L%d" % (nome, lod)
        saida.append(ob)
        print("[lod] %s: %d -> %d tris" % (ob.name, n0, len(ob.data.loop_triangles)))
for o in bpy.data.objects:
    if o not in saida and o.type != "MESH":
        bpy.data.objects.remove(o)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_yup=True, export_image_format="JPEG", export_jpeg_quality=85,
                          export_materials="EXPORT", export_cameras=False, export_lights=False)
print("[lod] exportado %s (%d KB)" % (dst, os.path.getsize(dst) // 1024))
