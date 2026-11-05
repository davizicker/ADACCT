"""Terceira leva (5 modelos de luz e latão: lampião diya, vaso, castiçais, castiçal de madeira, lamparina de óleo). Otimiza os modelos do Poly Haven para o jogo e exporta .glb em assets/models/poly/.
Uso:  blender -b --python tools/blender/build_props3.py -- <pasta_inbox> <pasta_saida>
(cada modelo em <inbox>/<nome>/<nome>/<nome>_1k.blend)
Requer o módulo `bpy` (pip install bpy) ou rodar dentro do Blender.

Para cada modelo: reduz triângulos até o alvo (DECIMATE), recentra os pés em y=0 (só informa; o jogo recentra),
e exporta glTF binário com texturas em JPEG (qualidade 82), exceto os que têm transparência (PNG).
Também converte as texturas .exr do material stone_wall_04 (muro) para PNG 8 bits."""
import bpy, sys, os, glob
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
inbox, outdir = args[0], args[1]
os.makedirs(outdir, exist_ok=True)

# nome -> (alvo de triangulos, tem transparencia?)
PROPS = {
    "brass_diya_lantern":   (3500, True),
    "brass_vase_03":        (1800, False),
    "brass_candleholders":  (7000, True),
    "wooden_candlestick":   (2500, False),
    "vintage_oil_lamp":     (4500, True),
    "lightbulb_01":         (1500, True),
    "cardboard_box_01":     (900, False),
    "anthurium_botany_01":  (4500, True),
    "WoodenChair_01":       (4500, False),
    "chinese_armchair":     (7000, False),
    "rusted_spade_01":      (2500, False),
    "trowel_01":            (1500, False),
    "wooden_bookshelf_worn": (7000, False),
    "WoodenTable_01":       (4500, False),
    "WoodenTable_02":       (4500, False),
}


def find_blend(name):
    achados = glob.glob(os.path.join(inbox, name, "**", "*.blend"), recursive=True)
    if not achados:
        raise FileNotFoundError(name)
    return achados[0]


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
    if os.path.exists(os.path.join(outdir, name + ".glb")):
        continue                       # já convertido
    bpy.ops.wm.open_mainfile(filepath=find_blend(name))
    # o Poly Haven traz vários LODs (_LOD1, _LOD2...) no mesmo arquivo: guarda só o mais detalhado (LOD0 ou sem sufixo)
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and "_LOD" in o.name and not o.name.endswith("_LOD0"):
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:                       # objetos fora da view layer (plantas com LODs) não aceitam modificadores
        if o.name not in bpy.context.view_layer.objects:
            try:
                bpy.context.scene.collection.objects.link(o)
            except RuntimeError:
                pass
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

