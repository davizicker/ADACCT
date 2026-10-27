"""Gera dois modelos de teste (humanoide em pose T e quadrúpede) para testar animar.py. Uso: python gerar_teste.py <pasta>"""
import bpy, sys, os, math
out = sys.argv[-1]


def cil(nome, r, h, loc, rot=(0, 0, 0), seg=12):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc, rotation=rot, vertices=seg)
    bpy.context.active_object.name = nome


def esf(nome, r, loc, sc=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=16, ring_count=10)
    o = bpy.context.active_object
    o.scale = sc
    o.name = nome


def juntar_e_salvar(arq):
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.shade_smooth()
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, arq), export_format="GLB", export_yup=True, export_apply=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
# humanoide 1,8 m, pose T, de frente para -Y (como o glTF exporta frente +Z)
cil("tronco", 0.17, 0.62, (0, 0, 1.2), seg=16)
cil("pelve", 0.16, 0.2, (0, 0, 0.93))
esf("cabeca", 0.11, (0, 0, 1.68), (0.9, 1.0, 1.15))
cil("pescoco", 0.05, 0.1, (0, 0, 1.55))
for s in (-1, 1):
    cil("braco", 0.04, 0.75, (s * 0.55, 0, 1.45), rot=(0, math.radians(90), 0), seg=8)
    cil("coxa", 0.07, 0.45, (s * 0.1, 0, 0.7))
    cil("canela", 0.05, 0.45, (s * 0.1, 0, 0.25))
    cil("pe", 0.05, 0.22, (s * 0.1, -0.08, 0.04), rot=(math.radians(90), 0, 0), seg=8)
juntar_e_salvar("teste_humanoide.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
# quadrúpede (cavalo simples) ao longo de Y, cabeça para -Y
esf("corpo", 0.4, (0, 0, 1.2), (0.55, 1.5, 0.75))
cil("pescoco", 0.14, 0.7, (0, -0.95, 1.55), rot=(math.radians(-35), 0, 0))
esf("cabeca", 0.15, (0, -1.25, 1.85), (0.7, 1.4, 0.8))
for sx in (-1, 1):
    for sy, nome in ((-0.7, "f"), (0.7, "t")):
        cil("coxa_" + nome, 0.07, 0.6, (sx * 0.2, sy, 0.8))
        cil("canela_" + nome, 0.04, 0.6, (sx * 0.2, sy, 0.25))
cil("cauda", 0.04, 0.6, (0, 1.2, 0.95), rot=(math.radians(25), 0, 0))
juntar_e_salvar("teste_quadrupede.glb")
print("[teste] ok")
