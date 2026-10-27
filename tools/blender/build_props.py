"""Otimiza os modelos do Poly Haven para o jogo e exporta .glb em assets/models/poly/.
Uso:  python tools/blender/build_props.py <pasta_inbox_com_os_.blend> <pasta_saida>
Requer o módulo `bpy` (pip install bpy) ou rodar dentro do Blender.

Para cada modelo: reduz triângulos até o alvo (DECIMATE), recentra os pés em y=0 (só informa; o jogo recentra),
e exporta glTF binário com texturas em JPEG (qualidade 82), exceto os que têm transparência (PNG).
Também converte as texturas .exr do material stone_wall_04 (muro) para PNG 8 bits."""
import bpy, sys, os, glob
from mathutils import Vector

inbox, outdir = sys.argv[1], sys.argv[2]
os.makedirs(outdir, exist_ok=True)

# nome -> (alvo de triangulos, tem transparencia?)
PROPS = {
    "wine_barrel_01":      (4500, False),
    "wooden_bucket_01":    (3500, False),
    "wooden_stool_01":     (3500, False),
    "street_lamp_01":      (9000, True),
    "street_lamp_02":      (7000, True),
    "Lantern_01":          (7000, True),
    "Television_01":       (1918, False),
    "binder_notebook":     (3500, False),
    "covered_car":         (9000, False),
    "dead_tree_trunk":     (9000, False),
    "football":            (4296, False),
    "gothic_statue":       (14000, False),
    "large_castle_door":   (9000, False),
    "rusted_wheel_rim_02": (5000, False),
    "wild_rooibos_bush":   (16000, True),
}


def find_blend(name):
    d = os.path.join(inbox, name)
    plain = os.path.join(d, "plain.blend")
    if os.path.exists(plain):
        return plain
    return glob.glob(os.path.join(d, "*.blend"))[0]


def count_tris(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    t = 0
    for o in objs:
        me = o.evaluated_get(dg).to_mesh()
        me.calc_loop_triangles()
        t += len(me.loop_triangles)
        o.evaluated_get(dg).to_mesh_clear()
    return t


for name, (target, alpha) in PROPS.items():
    bpy.ops.wm.open_mainfile(filepath=find_blend(name))
    # o Poly Haven traz vários LODs (_LOD1, _LOD2...) no mesmo arquivo: guarda só o mais detalhado (LOD0 ou sem sufixo)
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and "_LOD" in o.name and not o.name.endswith("_LOD0"):
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:                       # shape keys impedem o DECIMATE; descarta (não usamos formas animadas)
        if o.data.shape_keys:
            # remove sem operadores (que dependem de contexto): apaga os blocos de shape key diretamente
            for kb in list(o.data.shape_keys.key_blocks)[::-1]:
                o.shape_key_remove(kb)
    if alpha:                              # props de transparência (PNG) pesam muito: texturas a 512 px
        for im in bpy.data.images:
            if im.size[0] > 512 and im.type == "IMAGE":
                im.scale(512, 512)
    before = count_tris(meshes)
    if before > target * 1.1:
        ratio = target / before
        for o in meshes:
            bpy.context.view_layer.objects.active = o
            for m in list(o.modifiers):
                if m.type == "DECIMATE":
                    o.modifiers.remove(m)
            md = o.modifiers.new("dec", "DECIMATE")
            md.decimate_type = "COLLAPSE"
            md.ratio = max(0.02, min(1.0, ratio))
            md.use_collapse_triangulate = True
            try:
                bpy.ops.object.modifier_apply(modifier=md.name)
            except RuntimeError as e:
                print("[props] aviso: nao aplicou decimate em", o.name, e)
    after = count_tris(meshes)
    out = os.path.join(outdir, name + ".glb")
    kw = dict(filepath=out, export_format="GLB", export_apply=True, export_yup=True, export_materials="EXPORT",
              export_cameras=False, export_lights=False, export_animations=True)
    kw["export_image_format"] = "AUTO" if alpha else "JPEG"
    if not alpha:
        kw["export_jpeg_quality"] = 82
    bpy.ops.export_scene.gltf(**kw)
    print("[props] %-22s %6d -> %6d tris  %5d KB" % (name, before, after, os.path.getsize(out) // 1024))

# ---- texturas do muro (stone_wall_04): EXR -> PNG 8 bits (normal e rugosidade são dados, não cor)
src = os.path.join(inbox, "stone_wall_04", "textures")
dst = os.path.join(outdir, "..", "..", "textures", "polyhaven", "stone_wall_04")
os.makedirs(dst, exist_ok=True)
import shutil
for fn, cs in [("stone_wall_04_diff_1k.jpg", "sRGB"), ("stone_wall_04_nor_gl_1k.exr", "Non-Color"),
               ("stone_wall_04_rough_1k.exr", "Non-Color"), ("stone_wall_04_disp_1k.png", "Non-Color")]:
    p = os.path.join(src, fn)
    if not os.path.exists(p):
        continue
    base = fn.rsplit(".", 1)[0]
    if fn.endswith(".jpg"):
        shutil.copy(p, os.path.join(dst, fn))
        print("[tex]", fn, "copiado")
        continue
    img = bpy.data.images.load(p, check_existing=False)
    img.colorspace_settings.name = cs
    _ = img.pixels[0]                     # força a leitura dos dados (a carga é preguiçosa)
    outp = os.path.join(dst, base + ".png")
    img.file_format = "PNG"
    img.filepath_raw = outp
    img.save()
    print("[tex]", os.path.basename(outp), os.path.getsize(outp) // 1024, "KB")
