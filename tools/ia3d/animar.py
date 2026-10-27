"""Rig automático + animações procedurais (o que o Mixamo faz, de graça e no seu PC).
Uso:  python tools/ia3d/animar.py entrada.glb saida.glb --tipo humanoide|quadrupede [--anims idle,walk,run,scream]
Requer o módulo bpy:  pip install bpy

1) analisa a malha (altura, braços, pernas) e cria um esqueleto com as proporções do modelo;
2) liga a malha ao esqueleto com pesos automáticos (Blender "automatic weights");
3) gera animações em laço por código (idle, walk, run, scream | idle, walk, gallop) e exporta tudo num .glb.
Os nomes das animações combinam com scripts/modelos.gd do jogo (idle, walk, run, scream, gallop).

LIMITES (honestidade): o esqueleto é por proporção (supõe um humanoide em pose T ou A, de pé; ou um quadrúpede de lado), os pesos
automáticos falham em malhas muito sujas, e as animações são cíclicas e simples; não são captura de movimento."""
import bpy, bmesh, math, sys, os, argparse
from mathutils import Vector, Matrix, Quaternion

ap = argparse.ArgumentParser()
ap.add_argument("entrada")
ap.add_argument("saida")
ap.add_argument("--tipo", default="humanoide", choices=["humanoide", "quadrupede"])
ap.add_argument("--anims", default="")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.entrada)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    raise SystemExit("nenhuma malha no arquivo")
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
mesh = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mesh.name = "Corpo"
V = [v.co.copy() for v in mesh.data.vertices]
zmin = min(v.z for v in V)
zmax = max(v.z for v in V)
H = zmax - zmin


def fatia(zlo, zhi, filtro=None):
    return [v for v in V if zlo <= v.z - zmin <= zhi and (filtro is None or filtro(v))]


def media(vs, eixo):
    return sum(getattr(v, eixo) for v in vs) / max(len(vs), 1)


# ------------------------------------------------------------------ esqueleto
bones = {}   # nome -> (head, tail, pai)


def osso(nome, head, tail, pai=None):
    bones[nome] = (Vector(head), Vector(tail), pai)


FWD = Vector((0, 1, 0))      # direção "para a frente" (calculada abaixo)
LAT = Vector((1, 0, 0))      # eixo lateral

if a.tipo == "humanoide":
    cx = media(fatia(0.4 * H, 0.75 * H), "x")
    cy = media(fatia(0.45 * H, 0.7 * H), "y")
    alcance = max(abs(v.x - cx) for v in fatia(0.65 * H, 0.95 * H))
    pe = fatia(0, 0.06 * H)
    FWD = Vector((0, 1 if media(pe, "y") > cy else -1, 0)) if pe else Vector((0, -1, 0))
    wz = media(fatia(0.4 * H, 0.95 * H, lambda v: abs(v.x - cx) > 0.9 * alcance), "z") - zmin
    perna_x = max(0.04 * H, abs(media(fatia(0.05 * H, 0.35 * H, lambda v: v.x > cx), "x") - cx))
    P = lambda x, z, dy=0.0: (cx + x, cy + dy, zmin + z)
    osso("quadril", P(0, 0.52 * H), P(0, 0.60 * H))
    osso("coluna", P(0, 0.60 * H), P(0, 0.70 * H), "quadril")
    osso("peito", P(0, 0.70 * H), P(0, 0.81 * H), "coluna")
    osso("pescoco", P(0, 0.81 * H), P(0, 0.87 * H), "peito")
    osso("cabeca", P(0, 0.87 * H), P(0, 0.99 * H), "pescoco")
    for lado, s in (("E", 1), ("D", -1)):
        ombro = 0.10 * H
        osso("braco." + lado, P(s * ombro, 0.80 * H), P(s * (ombro + (alcance - ombro) * 0.5), 0.80 * H - (0.80 * H - wz) * 0.5), "peito")
        osso("antebraco." + lado, bones["braco." + lado][1], P(s * alcance * 0.97, wz), "braco." + lado)
        osso("mao." + lado, bones["antebraco." + lado][1], P(s * alcance, wz - 0.03 * H), "antebraco." + lado)
        osso("coxa." + lado, P(s * perna_x, 0.52 * H), P(s * perna_x, 0.28 * H), "quadril")
        osso("canela." + lado, bones["coxa." + lado][1], P(s * perna_x, 0.06 * H), "coxa." + lado)
        osso("pe." + lado, bones["canela." + lado][1], P(s * perna_x, 0.02 * H, FWD.y * 0.08 * H), "canela." + lado)
else:
    ex = max(v.x for v in V) - min(v.x for v in V)
    ey = max(v.y for v in V) - min(v.y for v in V)
    comp = "x" if ex > ey else "y"
    lat = "y" if comp == "x" else "x"
    LAT = Vector((1, 0, 0)) if lat == "x" else Vector((0, 1, 0))
    c_min = min(getattr(v, comp) for v in V)
    c_max = max(getattr(v, comp) for v in V)
    L = c_max - c_min
    # a frente é a ponta onde o corpo sobe mais (pescoço/cabeça)
    alto_min = max((v.z for v in V if getattr(v, comp) < c_min + 0.2 * L), default=0)
    alto_max = max((v.z for v in V if getattr(v, comp) > c_max - 0.2 * L), default=0)
    sinal = 1 if alto_max >= alto_min else -1
    FWD = Vector((1, 0, 0) if comp == "x" else (0, 1, 0)) * sinal
    lc = media(V, lat)
    ponto = lambda t, z, dl=0.0: (Vector((c_min + t * L if sinal > 0 else c_max - t * L, lc + dl, zmin + z)) if comp == "x" else Vector((lc + dl, c_min + t * L if sinal > 0 else c_max - t * L, zmin + z)))
    # t = 0 na traseira, 1 na frente (ao longo do sentido da frente)
    def P(t, z, dl=0.0):
        p = ponto(t, z, dl)
        return p if (sinal > 0 or True) else p
    # com sinal<0 a frente está em c_min: t cresce para c_min
    def Q(t, z, dl=0.0):
        pos = (c_min + t * L) if sinal > 0 else (c_max - t * L)
        return Vector((pos, lc + dl, zmin + z)) if comp == "x" else Vector((lc + dl, pos, zmin + z))
    osso("pelve", Q(0.12, 0.62 * H), Q(0.30, 0.64 * H))
    osso("coluna1", Q(0.30, 0.64 * H), Q(0.50, 0.66 * H), "pelve")
    osso("coluna2", Q(0.50, 0.66 * H), Q(0.70, 0.68 * H), "coluna1")
    osso("pescoco", Q(0.70, 0.68 * H), Q(0.86, 0.84 * H), "coluna2")
    osso("cabeca", Q(0.86, 0.84 * H), Q(0.98, 0.90 * H), "pescoco")
    osso("cauda1", Q(0.12, 0.64 * H), Q(0.02, 0.58 * H), "pelve")
    osso("cauda2", Q(0.02, 0.58 * H), Q(-0.06, 0.42 * H), "cauda1")
    osso("cauda3", Q(-0.06, 0.42 * H), Q(-0.10, 0.22 * H), "cauda2")
    for lado, s in (("E", 1), ("D", -1)):
        dl = s * 0.10 * H
        osso("coxa_t." + lado, Q(0.14, 0.60 * H, dl), Q(0.10, 0.34 * H, dl), "pelve")
        osso("canela_t." + lado, bones["coxa_t." + lado][1], Q(0.12, 0.12 * H, dl), "coxa_t." + lado)
        osso("casco_t." + lado, bones["canela_t." + lado][1], Q(0.12, 0.01 * H, dl), "canela_t." + lado)
        osso("coxa_f." + lado, Q(0.72, 0.62 * H, dl), Q(0.74, 0.34 * H, dl), "coluna2")
        osso("canela_f." + lado, bones["coxa_f." + lado][1], Q(0.74, 0.12 * H, dl), "coxa_f." + lado)
        osso("casco_f." + lado, bones["canela_f." + lado][1], Q(0.74, 0.01 * H, dl), "canela_f." + lado)

# cria o armature
arm_data = bpy.data.armatures.new("Esqueleto")
arm = bpy.data.objects.new("Esqueleto", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for n, (h, t, pai) in bones.items():
    eb = arm_data.edit_bones.new(n)
    eb.head = h
    eb.tail = t if (t - h).length > 1e-4 else h + Vector((0, 0, 0.02))
for n, (h, t, pai) in bones.items():
    if pai:
        arm_data.edit_bones[n].parent = arm_data.edit_bones[pai]
bpy.ops.object.mode_set(mode="OBJECT")

# pesos automáticos
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
try:
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
except RuntimeError as e:
    print("[animar] pesos automáticos falharam (%s); usando envelope" % e)
    bpy.ops.object.parent_set(type="ARMATURE_ENVELOPE")
# vértices que o Blender não conseguiu pesar (pontas, peças soltas): ligam-se ao osso mais próximo
def _dist_seg(p, h, t):
    d = t - h
    k = 0.0 if d.length_squared < 1e-12 else max(0.0, min(1.0, (p - h).dot(d) / d.length_squared))
    return (p - (h + d * k)).length


for v in mesh.data.vertices:
    if not any(g.weight > 0.01 for g in v.groups):
        melhor = min(bones, key=lambda n: _dist_seg(v.co, bones[n][0], bones[n][1]))
        grupo = mesh.vertex_groups.get(melhor) or mesh.vertex_groups.new(name=melhor)
        grupo.add([v.index], 1.0, "REPLACE")
sem = sum(1 for v in mesh.data.vertices if not any(g.weight > 0.01 for g in v.groups))
print("[animar] %d ossos; vértices sem peso: %d de %d" % (len(bones), sem, len(mesh.data.vertices)))


# ------------------------------------------------------------------ animações
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
pb = arm.pose.bones
for p in pb:
    p.rotation_mode = "QUATERNION"
rest = {n: arm.data.bones[n].matrix_local.to_3x3() for n in bones}

# sentido positivo do giro em torno do eixo lateral: leva um membro que aponta para baixo para a frente?
_t = Quaternion(LAT, 0.2) @ Vector((0, 0, -1))
SGN = 1.0 if _t.dot(FWD) > 0 else -1.0


def girar(nome, eixo_mundo, ang):
    """Rotação de `ang` (rad) em torno de um eixo do MUNDO, convertida para o espaço local do osso."""
    if nome not in pb:
        return
    eixo_l = rest[nome].inverted() @ Vector(eixo_mundo)
    q = Quaternion(eixo_l.normalized(), ang)
    pb[nome].rotation_quaternion = q @ pb[nome].rotation_quaternion


def zerar():
    for p in pb:
        p.rotation_quaternion = Quaternion((1, 0, 0, 0))


def chave(frame):
    for p in pb:
        p.keyframe_insert("rotation_quaternion", frame=frame)


def nova_acao(nome, frames, pose_fn, laco=True):
    act = bpy.data.actions.new(nome)
    arm.animation_data_create()
    arm.animation_data.action = act
    for f in range(frames + 1):
        zerar()
        pose_fn(f / frames if laco else f / frames)
        chave(f + 1)
    zerar()
    act.use_fake_user = True
    return act


S = SGN
ANIMS = {}
if a.tipo == "humanoide":
    def idle(t):
        r = math.sin(t * math.tau)
        girar("peito", LAT, S * 0.03 * r)
        girar("cabeca", LAT, S * -0.02 * r)
        for l, s in (("E", 1), ("D", -1)):
            girar("braco." + l, (0, 1, 0), s * 0.05 * r)

    def andar(t, amp=0.5, joelho=0.7, braco=0.4, cotovelo=0.3, incl=0.0):
        for l, fase in (("E", 0.0), ("D", 0.5)):
            ph = (t + fase) * math.tau
            girar("coxa." + l, LAT, S * amp * math.sin(ph))
            girar("canela." + l, LAT, -S * joelho * max(0.0, math.sin(ph + 1.2)))
            girar("braco." + l, LAT, -S * braco * math.sin(ph))
            girar("antebraco." + l, LAT, S * cotovelo * (0.5 + 0.5 * math.sin(ph)))
        girar("coluna", (0, 0, 1), 0.08 * math.sin(t * math.tau))
        girar("peito", (0, 0, 1), -0.08 * math.sin(t * math.tau))
        girar("coluna", LAT, S * incl)

    def gritar(t):
        # inspira (0-0.35), grita segurando (0.35-0.8), solta (0.8-1)
        k = min(1.0, t / 0.35) if t < 0.8 else max(0.0, (1.0 - t) / 0.2)
        tremor = math.sin(t * 60.0) * 0.02 * (1 if 0.35 < t < 0.8 else 0)
        girar("peito", LAT, S * -0.25 * k)
        girar("pescoco", LAT, S * -0.3 * k)
        girar("cabeca", LAT, S * (-0.35 * k + tremor))
        for l, s in (("E", 1), ("D", -1)):
            girar("braco." + l, (0, 1, 0), s * -0.7 * k)
            girar("antebraco." + l, LAT, S * 0.5 * k)

    ANIMS = {"idle": (48, idle, True), "walk": (32, lambda t: andar(t), True),
             "run": (20, lambda t: andar(t, 0.9, 1.3, 0.8, 1.1, S * -0.18), True), "scream": (60, gritar, False)}
else:
    def idle(t):
        r = math.sin(t * math.tau)
        girar("coluna2", LAT, S * 0.02 * r)
        girar("cabeca", LAT, S * -0.03 * r)
        girar("cauda1", (0, 0, 1), 0.15 * math.sin(t * math.tau * 2))
        girar("cauda2", (0, 0, 1), 0.25 * math.sin(t * math.tau * 2 - 0.6))

    def passo(t, amp, joelho, cauda, fase_t):
        for l, fase_f in (("E", 0.0), ("D", fase_t)):
            pf = (t + fase_f) * math.tau
            pt = (t + fase_f + 0.5) * math.tau
            girar("coxa_f." + l, LAT, S * amp * math.sin(pf))
            girar("canela_f." + l, LAT, -S * joelho * max(0.0, math.sin(pf + 1.3)))
            girar("coxa_t." + l, LAT, -S * amp * 0.8 * math.sin(pt))
            girar("canela_t." + l, LAT, S * joelho * max(0.0, math.sin(pt + 1.3)))
        girar("coluna1", LAT, S * 0.06 * math.sin(t * math.tau * 2))
        girar("coluna2", LAT, S * -0.06 * math.sin(t * math.tau * 2))
        girar("pescoco", LAT, S * 0.08 * math.sin(t * math.tau * 2 + 1.0))
        girar("cauda1", (0, 0, 1), cauda * math.sin(t * math.tau * 2))
        girar("cauda2", (0, 0, 1), cauda * 1.4 * math.sin(t * math.tau * 2 - 0.7))
        girar("cauda3", (0, 0, 1), cauda * 1.8 * math.sin(t * math.tau * 2 - 1.4))

    ANIMS = {"idle": (48, idle, True), "walk": (32, lambda t: passo(t, 0.45, 0.8, 0.12, 0.5), True),
             "gallop": (18, lambda t: passo(t, 0.8, 1.2, 0.22, 0.12), True)}

quais = [x.strip() for x in a.anims.split(",") if x.strip()] or list(ANIMS.keys())
for nome in quais:
    if nome not in ANIMS:
        print("[animar] animação desconhecida: %s (disponíveis: %s)" % (nome, ", ".join(ANIMS)))
        continue
    frames, fn, laco = ANIMS[nome]
    nova_acao(nome, frames, fn, laco)
    print("[animar] animação '%s' (%d quadros)" % (nome, frames))

arm.animation_data.action = None
bpy.ops.object.mode_set(mode="OBJECT")
kw = dict(filepath=a.saida, export_format="GLB", export_apply=True, export_yup=True, export_materials="EXPORT",
          export_image_format="JPEG", export_jpeg_quality=85, export_cameras=False, export_lights=False, export_animations=True)
try:
    bpy.ops.export_scene.gltf(export_animation_mode="ACTIONS", **kw)
except TypeError:
    bpy.ops.export_scene.gltf(export_nla_strips=False, **kw)
print("[animar] exportado: %s (%d KB)" % (os.path.basename(a.saida), os.path.getsize(a.saida) // 1024))
