"""Converte um .blend do Poly Haven em .glb (glTF binário) para o Godot.
Uso (headless):  blender -b <arquivo.blend> --python tools/blender/converter.py -- <saida.glb>
Imprime: triangulos, dimensoes (m), materiais e se há transparência (alpha).
Os mapas .exr do Poly Haven (rugosidade/normal) são empacotados pelo exportador glTF do Blender."""
import bpy, sys, os

# Dois modos: dentro do Blender (blender -b arq.blend --python converter.py -- saida.glb)
# ou com o módulo bpy (python converter.py entrada.blend saida.glb), útil para arquivos de versões novas.
if "--" in sys.argv:
    out = sys.argv[sys.argv.index("--") + 1]
else:
    bpy.ops.wm.open_mainfile(filepath=sys.argv[1])
    out = sys.argv[2]

# ---- estatísticas
tris = 0
mins = [1e9] * 3
maxs = [-1e9] * 3
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
dg = bpy.context.evaluated_depsgraph_get()
from mathutils import Vector
for o in meshes:
    ev = o.evaluated_get(dg)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    tris += len(me.loop_triangles)
    for corner in o.bound_box:
        w = o.matrix_world @ Vector(corner)
        for i in range(3):
            mins[i] = min(mins[i], w[i])
            maxs[i] = max(maxs[i], w[i])
    ev.to_mesh_clear()
dims = [maxs[i] - mins[i] for i in range(3)]
mats = sorted({s.material.name for o in meshes for s in o.material_slots if s.material})
print("[blender] %s | objetos=%d triangulos=%d dim(x,y,z)=%.2f x %.2f x %.2f m | materiais=%s" % (
    os.path.basename(out), len(meshes), tris, dims[0], dims[1], dims[2], ",".join(mats)))

# ---- exporta
bpy.ops.export_scene.gltf(
    filepath=out, export_format="GLB", export_apply=True, export_yup=True,
    export_image_format="AUTO", export_materials="EXPORT", export_cameras=False, export_lights=False,
    export_animations=True, use_selection=False)
print("[blender] exportado:", out, os.path.getsize(out) // 1024, "KB")
