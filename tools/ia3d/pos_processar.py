"""Limpa um modelo vindo de IA (TripoSR, Hunyuan3D, Meshy...) e o deixa pronto para o jogo.
Uso:  python tools/ia3d/pos_processar.py entrada.glb saida.glb [--tris 30000] [--altura 2.7]
Requer o módulo bpy:  pip install bpy   (Python 3.11 para Blender 4/5; veja a página do pacote)
O que faz: junta as malhas, remove pedaços soltos pequenos, solda vértices, reduz triângulos (DECIMATE),
põe os pés em y=0 e o centro em x/z=0, escala para a altura pedida (metros) e exporta .glb com texturas em JPEG."""
import bpy, bmesh, sys, os, argparse

ap = argparse.ArgumentParser()
ap.add_argument("entrada")
ap.add_argument("saida")
ap.add_argument("--tris", type=int, default=30000)
ap.add_argument("--altura", type=float, default=0.0, help="altura final em metros (0 = não muda)")
ap.add_argument("--solto", type=float, default=0.02, help="remove pedaços soltos com menos de X do total de faces")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])

bpy.ops.wm.read_factory_settings(use_empty=True)
ext = os.path.splitext(a.entrada)[1].lower()
if ext in (".glb", ".gltf"):
    bpy.ops.import_scene.gltf(filepath=a.entrada)
elif ext == ".obj":
    bpy.ops.wm.obj_import(filepath=a.entrada)
elif ext == ".fbx":
    bpy.ops.import_scene.fbx(filepath=a.entrada)
else:
    raise SystemExit("formato não suportado: " + ext)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    raise SystemExit("nenhuma malha no arquivo")
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# 1) solda vértices e remove ilhas pequenas (lixo típico dos geradores)
bm = bmesh.new()
bm.from_mesh(ob.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
bm.faces.ensure_lookup_table()
visto, ilhas = set(), []
for f in bm.faces:
    if f.index in visto:
        continue
    pilha, ilha = [f], []
    visto.add(f.index)
    while pilha:
        cur = pilha.pop()
        ilha.append(cur)
        for e in cur.edges:
            for nf in e.link_faces:
                if nf.index not in visto:
                    visto.add(nf.index)
                    pilha.append(nf)
    ilhas.append(ilha)
total = len(bm.faces)
removidas = 0
for ilha in ilhas:
    if len(ilha) < total * a.solto and len(ilhas) > 1:
        bmesh.ops.delete(bm, geom=[f for f in ilha if f.is_valid], context="FACES")
        removidas += 1
bm.to_mesh(ob.data)
bm.free()

# 2) reduz triângulos
ob.data.calc_loop_triangles()
antes = len(ob.data.loop_triangles)
if antes > a.tris:
    md = ob.modifiers.new("dec", "DECIMATE")
    md.ratio = max(0.01, a.tris / antes)
    md.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=md.name)
ob.data.calc_loop_triangles()
depois = len(ob.data.loop_triangles)

# 3) pés em y=0 (z=0 no Blender), centrado, escala por altura
mn = [min(v.co[i] for v in ob.data.vertices) for i in range(3)]
mx = [max(v.co[i] for v in ob.data.vertices) for i in range(3)]
cx, cy = (mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2
for v in ob.data.vertices:
    v.co.x -= cx
    v.co.y -= cy
    v.co.z -= mn[2]
if a.altura > 0:
    k = a.altura / max(mx[2] - mn[2], 1e-6)
    for v in ob.data.vertices:
        v.co *= k
ob.data.update()
for p in ob.data.polygons:
    p.use_smooth = True

bpy.ops.export_scene.gltf(filepath=a.saida, export_format="GLB", export_apply=True, export_yup=True,
                          export_materials="EXPORT", export_image_format="JPEG", export_jpeg_quality=85,
                          export_cameras=False, export_lights=False, export_animations=False)
print("[pos] %s: %d -> %d triângulos, %d pedaços soltos removidos, %d KB" % (os.path.basename(a.saida), antes, depois, removidas, os.path.getsize(a.saida) // 1024))
