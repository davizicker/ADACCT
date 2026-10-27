"""Extrai variantes individuais das plantas/coberturas do Poly Haven (cada arquivo traz dezenas de objetos e LODs)
e exporta um .glb por variante em assets/models/poly/. Uso: python tools/blender/build_plants.py <inbox> <saida>"""
import bpy, sys, os, glob

inbox, outdir = sys.argv[1], sys.argv[2]
os.makedirs(outdir, exist_ok=True)

# nome de saída -> (arquivo, objeto a manter)
PLANTAS = {
    "moss_patch":      ("moss_01", "moss_01_geometry_nodes"),
    "grass_patch":     ("grass_medium_01", "grass_medium_01_geometry_nodes"),
    "periwinkle_a":    ("periwinkle_plant", "periwinkle_plant_01_LOD3"),
    "periwinkle_b":    ("periwinkle_plant", "periwinkle_plant_03_LOD3"),
    "periwinkle_c":    ("periwinkle_plant", "periwinkle_plant_04_LOD2"),
    "weed_a":          ("weed_plant_02", "weed_plant_02_a_LOD1"),
    "weed_b":          ("weed_plant_02", "weed_plant_02_c_LOD1"),
    "grass_tuft_a":    ("grass_medium_01", "grass_medium_01_tall_a_LOD1"),
    "grass_tuft_b":    ("grass_medium_01", "grass_medium_01_mid_a_LOD2"),
}


def find_blend(name):
    for d in sorted(glob.glob(os.path.join(inbox, name + "_1k.blend*"))):
        if os.path.isdir(d):
            return glob.glob(os.path.join(d, "*.blend"))[0]
    raise FileNotFoundError(name)


for out_name, (src, keep) in PLANTAS.items():
    bpy.ops.wm.open_mainfile(filepath=find_blend(src))
    for o in list(bpy.data.objects):
        if o.name != keep:
            bpy.data.objects.remove(o, do_unlink=True)
    if keep not in bpy.context.scene.objects:
        bpy.context.scene.collection.objects.link(bpy.data.objects[keep])
    o = bpy.data.objects[keep]
    o.name = out_name
    for im in bpy.data.images:
        if im.size[0] > 512 and im.type == "IMAGE":
            im.scale(512, 512)
    me = o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    me.calc_loop_triangles()
    tris = len(me.loop_triangles)
    path = os.path.join(outdir, out_name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True,
                              export_materials="EXPORT", export_cameras=False, export_lights=False,
                              export_animations=False, export_image_format="AUTO")
    print("[plantas] %-14s %6d tris %5d KB" % (out_name, tris, os.path.getsize(path) // 1024))
