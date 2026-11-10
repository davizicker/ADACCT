"""Kit de fachada colonial mineira, modelado por script no Blender (bpy). Gera um .glb por módulo em assets/models/kit/.
Uso: python tools/blender/kit_colonial.py <pasta_saida>

Convenções (coordenadas do glTF, Y para cima):
  - a frente do módulo olha para +Z; o plano da parede é z = 0; o módulo se projeta para +Z (para a rua);
  - origem no centro-base do módulo (x = 0 no meio);
  - cada material é um objeto com o NOME do material do jogo (cantaria, madeira, ferro, vidro, telha...). O Godot troca pelos
    materiais dele (texturas PBR), então aqui só importa a GEOMETRIA: bisel, molduras, ripas, balaústres torneados, desgaste.
"""
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/kit"      # blender -b --python kit_colonial.py -- <pasta>
os.makedirs(OUT, exist_ok=True)
random.seed(7)


def limpar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


class Peca:
    """Acumula geometria por material (um bmesh por material)."""
    def __init__(self):
        self.bm = {}

    def _b(self, m):
        if m not in self.bm:
            self.bm[m] = bmesh.new()
        return self.bm[m]

    def box(self, m, size, pos, rot=(0, 0, 0), bevel=0.0, jitter=0.0):
        b = self._b(m)
        r = bmesh.ops.create_cube(b, size=1.0)
        verts = r["verts"]
        mat = Matrix.Translation(pos) @ Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X")
        mat = mat @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
        for v in verts:
            v.co = mat @ v.co
            if jitter:
                v.co += Vector((random.uniform(-jitter, jitter), random.uniform(-jitter, jitter), random.uniform(-jitter, jitter)))
        if bevel > 0:
            edges = list({e for v in verts for e in v.link_edges})
            bmesh.ops.bevel(b, geom=edges, offset=bevel, segments=2, affect="EDGES")

    def torneado(self, m, perfil, pos, segs=10):
        """Sólido de revolução em torno de Y. perfil = [(raio, y)...] de baixo para cima (balaústre, pé de mesa)."""
        b = self._b(m)
        anel = []
        for r, y in perfil:
            row = []
            for k in range(segs):
                a = 2 * math.pi * k / segs
                row.append(b.verts.new(Vector((pos[0] + math.cos(a) * r, pos[1] + y, pos[2] + math.sin(a) * r))))
            anel.append(row)
        for i in range(len(anel) - 1):
            for k in range(segs):
                k2 = (k + 1) % segs
                try:
                    b.faces.new((anel[i][k], anel[i][k2], anel[i + 1][k2], anel[i + 1][k]))
                except ValueError:
                    pass
        for row in (anel[0], anel[-1]):
            try:
                b.faces.new(row)
            except ValueError:
                pass

    def perfil_extrudado(self, m, pts, comprimento, pos):
        """Perfil 2D (z,y) extrudado ao longo de X (cornija, rodapé)."""
        b = self._b(m)
        x0 = pos[0] - comprimento / 2.0
        x1 = pos[0] + comprimento / 2.0
        a = [b.verts.new(Vector((x0, pos[1] + y, pos[2] + z))) for z, y in pts]
        c = [b.verts.new(Vector((x1, pos[1] + y, pos[2] + z))) for z, y in pts]
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            try:
                b.faces.new((a[i], a[j], c[j], c[i]))
            except ValueError:
                pass
        try:
            b.faces.new(a)
            b.faces.new(list(reversed(c)))
        except ValueError:
            pass

    def exportar(self, nome, bisel=0.006):
        objs = []
        for m, b in self.bm.items():
            bmesh.ops.recalc_face_normals(b, faces=b.faces)
            me = bpy.data.meshes.new(m)
            b.to_mesh(me)
            b.free()
            ob = bpy.data.objects.new(m, me)
            bpy.context.scene.collection.objects.link(ob)
            mt = bpy.data.materials.new(m)
            ob.data.materials.append(mt)
            for p in ob.data.polygons:
                p.use_smooth = False
            objs.append(ob)
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        path = os.path.join(OUT, nome + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                                  export_yup=False, export_materials="EXPORT", export_image_format="NONE",
                                  export_cameras=False, export_lights=False, export_animations=False)
        tris = sum(len(o.data.polygons) for o in objs)
        print("[kit] %-22s %5d faces %4d KB" % (nome, tris, os.path.getsize(path) // 1024))


# ---------------------------------------------------------------- janela (vão 1,0 x 1,5; base em y=0)
def janela():
    p = Peca()
    w, h = 1.0, 1.5
    # guarnição de pedra: ombreiras, verga com pedra-chave, peitoril com moldura
    for s in (-1, 1):
        p.box("cantaria", (0.16, h + 0.05, 0.16), (s * (w / 2 + 0.08), h / 2, 0.06), bevel=0.012, jitter=0.004)
    p.box("cantaria", (w + 0.4, 0.17, 0.18), (0, h + 0.095, 0.07), bevel=0.012, jitter=0.004)
    p.box("cantaria", (0.22, 0.27, 0.21), (0, h + 0.12, 0.085), bevel=0.014)                    # pedra-chave
    p.box("cantaria", (w + 0.46, 0.06, 0.30), (0, -0.03, 0.12), bevel=0.01)                    # peitoril
    p.box("cantaria", (w + 0.30, 0.05, 0.21), (0, -0.085, 0.07), bevel=0.01)                   # moldura sob o peitoril
    # caixilho de madeira, 2 folhas e 6 vidros (à frente do plano da parede: a parede do jogo é sólida)
    z = 0.03
    for s in (-1, 1):
        p.box("madeira", (0.05, h, 0.06), (s * (w / 2 - 0.025), h / 2, z), bevel=0.004)
    p.box("madeira", (w, 0.05, 0.06), (0, h - 0.025, z), bevel=0.004)
    p.box("madeira", (w, 0.05, 0.06), (0, 0.025, z), bevel=0.004)
    p.box("madeira", (0.035, h, 0.045), (0, h / 2, z), bevel=0.003)
    for yy in (h / 3, 2 * h / 3):
        p.box("madeira", (w, 0.03, 0.04), (0, yy, z), bevel=0.003)
    # o vidro NÃO faz parte do módulo: é um painel separado com shader de interior (assets/shaders/janela_interior.gdshader)
    p.exportar("janela_colonial")


# ---------------------------------------------------------------- veneziana (uma folha; dobradiça em x=0, folha para +x)
def veneziana(espelhada=False):
    p = Peca()
    X = -1 if espelhada else 1
    lw, lh = 0.52, 1.56
    p.box("madeira", (0.06, lh, 0.04), (X * 0.03, lh / 2, 0), bevel=0.004)
    p.box("madeira", (0.06, lh, 0.04), (X * (lw - 0.03), lh / 2, 0), bevel=0.004)
    for y in (0.03, lh / 2, lh - 0.03):
        p.box("madeira", (lw, 0.06, 0.04), (X * lw / 2, y, 0), bevel=0.004)
    n = 12
    for i in range(n):
        y = 0.12 + i * (lh - 0.24) / (n - 1)
        p.box("madeira", (lw - 0.1, 0.045, 0.012), (X * lw / 2, y, 0.002), rot=(math.radians(-38), 0, 0), bevel=0.002)   # ripas inclinadas
    for y in (0.22, lh - 0.22):
        p.box("ferro", (0.18, 0.025, 0.012), (X * 0.09, y, 0.03), bevel=0.002)                                           # dobradiças
    p.exportar("veneziana_e" if espelhada else "veneziana")


# ---------------------------------------------------------------- porta de duas folhas (vão 1,4 x 2,5)
def porta():
    p = Peca()
    w, h = 1.4, 2.5
    for s in (-1, 1):
        p.box("cantaria", (0.2, h + 0.1, 0.2), (s * (w / 2 + 0.1), h / 2, 0.08), bevel=0.014, jitter=0.005)
    p.box("cantaria", (w + 0.7, 0.24, 0.26), (0, h + 0.12, 0.1), bevel=0.014)                     # verga
    p.box("cantaria", (w + 0.86, 0.08, 0.32), (0, h + 0.28, 0.12), bevel=0.01)                    # pingadeira
    p.box("cantaria", (w + 0.5, 0.1, 0.5), (0, -0.02, 0.22), bevel=0.012)                          # soleira
    p.box("cantaria", (w + 0.9, 0.1, 0.36), (0, -0.12, 0.40), bevel=0.012)                         # degrau
    z = 0.04
    for s in (-1, 1):
        cx = s * w / 4
        lw = w / 2 - 0.02
        p.box("madeira", (lw, h - 0.1, 0.07), (cx, (h - 0.1) / 2 + 0.02, z), bevel=0.006)          # folha
        for (py, ph) in ((0.45, 0.8), (1.45, 0.75), (2.15, 0.35)):
            p.box("madeira", (lw - 0.22, ph, 0.03), (cx, py + 0.02, z + 0.04), bevel=0.01)         # almofadas em relevo
        p.box("ferro", (0.04, 0.16, 0.04), (s * 0.06 + 0.0, 1.1, z + 0.06), bevel=0.004)           # puxador
        for y in (0.5, 1.9):
            p.box("ferro", (lw * 0.55, 0.04, 0.02), (cx - s * lw * 0.2, y, z + 0.045), bevel=0.003)  # ferragens
    p.exportar("porta_dupla")


# ---------------------------------------------------------------- sacada de 1 m (laje com mísulas, balaústres torneados, corrimão)
def sacada():
    p = Peca()
    prof = 1.2
    p.box("cantaria", (1.0, 0.14, prof), (0, -0.07, prof / 2), bevel=0.01)                         # laje
    p.box("cantaria", (1.0, 0.05, 0.05), (0, 0.025, prof - 0.04), bevel=0.006)                    # lábio
    p.box("cantaria", (1.0, 0.05, 0.08), (0, -0.165, prof - 0.1), bevel=0.006)                    # moldura sob a laje
    for z in (0.3, 0.9):                                                                           # mísulas escalonadas
        for k, (a, b2) in enumerate(((0.36, 0.14), (0.24, 0.14))):
            p.box("cantaria", (0.16, b2, a), (0.0, -0.21 - k * 0.14, z - 0.18 + a / 2 + k * 0.14))
    rail = 1.0
    p.box("ferro", (1.0, 0.04, 0.04), (0, rail, prof - 0.06), bevel=0.004)                         # corrimão
    p.box("ferro", (1.0, 0.03, 0.03), (0, 0.12, prof - 0.06), bevel=0.003)
    perfil = [(0.012, 0.0), (0.012, 0.1), (0.03, 0.22), (0.014, 0.4), (0.03, 0.58), (0.014, 0.74), (0.012, 0.88)]
    for i in range(6):
        p.torneado("ferro", perfil, (-0.42 + i * 0.168, 0.12, prof - 0.06), segs=6)
    p.exportar("sacada_1m")


# ---------------------------------------------------------------- cornija de 1 m com dentículos
def cornija():
    p = Peca()
    pts = [(0.0, 0.0), (0.04, 0.0), (0.04, 0.05), (0.09, 0.07), (0.15, 0.1), (0.15, 0.14), (0.09, 0.17), (0.0, 0.17)]
    p.perfil_extrudado("cantaria", pts, 1.0, (0, -0.17, 0))
    for i in range(5):
        p.box("cantaria", (0.06, 0.05, 0.07), (-0.4 + i * 0.2, -0.2, 0.07))
    p.exportar("cornija_1m")


# ---------------------------------------------------------------- cachorro de beiral (ponta de caibro com curva)
def cachorro():
    p = Peca()
    p.box("madeira", (0.11, 0.16, 0.5), (0, 0.0, 0.25), bevel=0.006)
    for k in range(4):
        t = k / 3.0
        p.box("madeira", (0.11, 0.16 - 0.06 * t, 0.12), (0, -0.0 + 0.02 * t, 0.56 + k * 0.1), bevel=0.005)
    p.exportar("cachorro_beiral")


# ---------------------------------------------------------------- chaminé de pedra
def chamine():
    p = Peca()
    p.box("cantaria", (0.8, 1.6, 0.8), (0, 0.8, 0), bevel=0.02, jitter=0.01)
    p.box("cantaria", (1.0, 0.1, 1.0), (0, 1.65, 0), bevel=0.012)
    p.box("cantaria", (0.9, 0.18, 0.9), (0, 1.79, 0), bevel=0.012)
    for s in (-1, 1):
        p.box("ferro", (0.22, 0.28, 0.22), (s * 0.2, 1.96, 0), bevel=0.01)
    p.exportar("chamine")


# ================================================================ KIT 2 (mapa do zero): peças mais ricas para moldar as casas

def _voluta(p, m, cx, cy, z, r0, voltas=1.6, esp=0.012, segs=22, sentido=1):
    """Arabesco de ferro forjado (espiral plana no plano XY), feito de segmentos finos."""
    pts = []
    for k in range(segs + 1):
        t = k / segs
        a = sentido * t * voltas * 2 * math.pi
        r = r0 * (1.0 - 0.75 * t)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
        L = math.hypot(x1 - x0, y1 - y0)
        ang = math.atan2(y1 - y0, x1 - x0)
        p.box(m, (L + esp, esp, esp), ((x0 + x1) / 2, (y0 + y1) / 2, z), rot=(0, 0, ang))


# ---------------------------------------------------------------- sacada de ferro forjado (1,6 m) com mísulas entalhadas
def sacada_ferro():
    p = Peca()
    w, prof = 1.6, 0.75
    p.box("cantaria", (w, 0.12, prof), (0, -0.06, prof / 2), bevel=0.012)                          # laje de pedra
    p.box("cantaria", (w + 0.06, 0.05, 0.06), (0, -0.005, prof - 0.02), bevel=0.008)             # lábio
    pts = [(0.0, 0.0), (0.06, 0.0), (0.06, -0.04), (0.03, -0.07), (0.0, -0.08)]
    p.perfil_extrudado("cantaria", [(z + prof - 0.08, y - 0.12) for z, y in pts], w - 0.04, (0, 0, 0))   # moldura sob a laje
    for sx in (-1, 1):                                                                             # mísulas em S
        x = sx * (w / 2 - 0.18)
        for k in range(6):
            t = k / 5.0
            p.box("cantaria", (0.14, 0.09, 0.62 - 0.5 * t), (x, -0.17 - k * 0.075, 0.31 - 0.25 * t), bevel=0.01)
    # gradil: barras, corrimão, rodapé e arabescos
    z = prof - 0.05
    alt = 0.95
    p.box("ferro", (w - 0.02, 0.035, 0.045), (0, alt, z), bevel=0.006)                             # corrimão
    p.box("ferro", (w - 0.02, 0.025, 0.025), (0, 0.08, z))                                           # barra de baixo
    p.box("ferro", (w - 0.02, 0.02, 0.02), (0, alt - 0.16, z))                                       # faixa de cima
    for sz in (-1, 1):
        p.box("ferro", (0.025, alt, 0.025), (sz * (w / 2 - 0.02), alt / 2, z))
        p.box("ferro", (0.025, 0.025, prof - 0.1), (sz * (w / 2 - 0.02), alt, prof / 2))         # retorno lateral
        p.box("ferro", (0.025, alt, 0.025), (sz * (w / 2 - 0.02), alt / 2, 0.06))
    n = 13
    for i in range(n):
        x = -w / 2 + 0.06 + i * (w - 0.12) / (n - 1)
        p.box("ferro", (0.016, alt - 0.08, 0.016), (x, (alt + 0.08) / 2 - 0.04 + 0.04, z))
    for i in range(4):                                                                              # arabescos na faixa de cima
        cx = -w / 2 + 0.2 + i * (w - 0.4) / 3
        _voluta(p, "ferro", cx - 0.05, alt - 0.08, z + 0.012, 0.06, sentido=1)
        _voluta(p, "ferro", cx + 0.05, alt - 0.08, z + 0.012, 0.06, sentido=-1)
    p.exportar("sacada_ferro")


# ---------------------------------------------------------------- janela de guilhotina (vão 1,0 x 1,6) com cercadura de orelhas
def janela_guilhotina():
    p = Peca()
    w, h = 1.0, 1.6
    for sx in (-1, 1):
        p.box("cantaria", (0.17, h + 0.04, 0.15), (sx * (w / 2 + 0.085), h / 2, 0.06), bevel=0.012, jitter=0.003)
        p.box("cantaria", (0.30, 0.20, 0.17), (sx * (w / 2 + 0.11), h + 0.07, 0.065), bevel=0.012)        # orelhas
    p.box("cantaria", (w + 0.32, 0.22, 0.17), (0, h + 0.12, 0.065), bevel=0.012)                       # verga
    arc = 10
    for k in range(arc):                                                                                # verga em arco abatido
        a0 = math.pi * k / arc
        a1 = math.pi * (k + 1) / arc
        am = (a0 + a1) / 2
        L = 2 * 0.62 * math.sin((a1 - a0) / 2) + 0.02
        p.box("cantaria", (L, 0.07, 0.18), (math.cos(am) * 0.62, h + 0.26 + math.sin(am) * 0.10, 0.07), rot=(0, 0, am + math.pi / 2), bevel=0.006)
    p.box("cantaria", (w + 0.44, 0.06, 0.28), (0, -0.03, 0.12), bevel=0.01)                            # peitoril
    p.box("cantaria", (w + 0.24, 0.05, 0.2), (0, -0.085, 0.08), bevel=0.008)
    z = 0.035
    for sx in (-1, 1):
        p.box("madeira", (0.055, h, 0.06), (sx * (w / 2 - 0.027), h / 2, z), bevel=0.004)
    for yy in (0.027, h / 2, h - 0.027):
        p.box("madeira", (w, 0.055 if yy != h / 2 else 0.07, 0.06), (0, yy, z), bevel=0.004)          # travessas (a do meio é o encontro das guilhotinas)
    for half in (0, 1):
        y0 = half * h / 2
        for k in (1, 2):
            p.box("madeira", (0.025, h / 2 - 0.06, 0.035), (-w / 2 + k * w / 3, y0 + h / 4, z + 0.01), bevel=0.002)
        p.box("madeira", (w - 0.08, 0.025, 0.035), (0, y0 + h / 4, z + 0.01), bevel=0.002)
    p.exportar("janela_guilhotina")


# ---------------------------------------------------------------- porta-balcão (vão 1,1 x 2,4) para as sacadas: almofadas embaixo, vidro em cima
def porta_balcao():
    p = Peca()
    w, h = 1.1, 2.4
    for sx in (-1, 1):
        p.box("cantaria", (0.18, h + 0.05, 0.16), (sx * (w / 2 + 0.09), h / 2, 0.06), bevel=0.012, jitter=0.003)
    p.box("cantaria", (w + 0.42, 0.22, 0.18), (0, h + 0.11, 0.07), bevel=0.012)
    p.box("cantaria", (0.2, 0.28, 0.2), (0, h + 0.15, 0.08), bevel=0.012)                               # pedra-chave
    z = 0.035
    for sx in (-1, 1):
        cx = sx * w / 4
        lw = w / 2 - 0.015
        for xx in (cx - lw / 2 + 0.03, cx + lw / 2 - 0.03):
            p.box("madeira", (0.06, h, 0.06), (xx, h / 2, z), bevel=0.004)
        for yy in (0.03, 0.85, h - 0.03):
            p.box("madeira", (lw, 0.06, 0.06), (cx, yy, z), bevel=0.004)
        p.box("madeira", (lw - 0.12, 0.6, 0.03), (cx, 0.44, z + 0.03), bevel=0.01)                      # almofada
        for k in (1, 2):
            p.box("madeira", (0.025, h - 0.95, 0.035), (cx - lw / 2 + k * lw / 3, 0.85 + (h - 0.9) / 2, z + 0.01), bevel=0.002)
        for k in (1, 2):
            p.box("madeira", (lw - 0.1, 0.025, 0.035), (cx, 0.85 + k * (h - 0.9) / 3, z + 0.01), bevel=0.002)
        p.box("ferro", (0.03, 0.14, 0.03), (sx * 0.05, 1.05, z + 0.05), bevel=0.003)
    p.exportar("porta_balcao")


# ---------------------------------------------------------------- grade de ferro de janela térrea (1,0 x 1,5) com volutas no topo
def grade_janela():
    p = Peca()
    w, h = 1.0, 1.5
    z = 0.2
    for i in range(7):
        x = -w / 2 + 0.07 + i * (w - 0.14) / 6
        p.box("ferro", (0.018, h, 0.018), (x, h / 2, z))
        p.box("ferro", (0.03, 0.06, 0.03), (x, h + 0.03, z))
    for yy in (0.15, h * 0.55, h - 0.08):
        p.box("ferro", (w, 0.022, 0.022), (0, yy, z))
    for i in range(3):
        cx = -0.3 + i * 0.3
        _voluta(p, "ferro", cx - 0.06, h - 0.2, z + 0.01, 0.05, sentido=1)
        _voluta(p, "ferro", cx + 0.06, h - 0.2, z + 0.01, 0.05, sentido=-1)
    for sx in (-1, 1):
        p.box("ferro", (0.03, 0.03, z), (sx * (w / 2 - 0.02), 0.3, z / 2))
        p.box("ferro", (0.03, 0.03, z), (sx * (w / 2 - 0.02), h - 0.2, z / 2))
    p.exportar("grade_janela")


# ---------------------------------------------------------------- porta de uma folha (vão 1,1 x 2,3) com bandeira em arco e raios de ferro
def porta_bandeira():
    p = Peca()
    w, h = 1.1, 2.3
    r = w / 2
    for sx in (-1, 1):
        p.box("cantaria", (0.2, h + 0.05, 0.18), (sx * (w / 2 + 0.1), h / 2, 0.07), bevel=0.014, jitter=0.004)
    arc = 12
    for k in range(arc):
        a0 = math.pi * k / arc
        a1 = math.pi * (k + 1) / arc
        am = (a0 + a1) / 2
        L = 2 * (r + 0.1) * math.sin((a1 - a0) / 2) + 0.03
        p.box("cantaria", (L, 0.2, 0.18), (math.cos(am) * (r + 0.1), h + math.sin(am) * (r + 0.1), 0.07), rot=(0, 0, am + math.pi / 2), bevel=0.01)
    p.box("cantaria", (w + 0.5, 0.1, 0.45), (0, -0.02, 0.2), bevel=0.012)                               # soleira
    z = 0.04
    p.box("madeira", (w - 0.02, h - 0.04, 0.07), (0, (h - 0.04) / 2 + 0.02, z), bevel=0.006)
    for py, ph in ((0.5, 0.75), (1.35, 0.7), (1.95, 0.3)):
        for sx in (-1, 1):
            p.box("madeira", ((w - 0.2) / 2 - 0.04, ph, 0.03), (sx * (w - 0.2) / 4 + sx * 0.0, py, z + 0.045), bevel=0.01)
    p.box("madeira", (w, 0.08, 0.08), (0, h, z), bevel=0.005)                                           # travessa da bandeira
    for k in range(5):                                                                                  # raios de ferro da bandeira
        a = math.pi * (k + 0.5) / 5
        p.box("ferro", (r * 0.9, 0.02, 0.02), (math.cos(a) * r * 0.45, h + math.sin(a) * r * 0.45, z + 0.01), rot=(0, 0, a))
    for k in range(arc):
        a0 = math.pi * k / arc
        a1 = math.pi * (k + 1) / arc
        am = (a0 + a1) / 2
        L = 2 * (r - 0.02) * math.sin((a1 - a0) / 2) + 0.02
        p.box("madeira", (L, 0.05, 0.06), (math.cos(am) * (r - 0.02), h + math.sin(am) * (r - 0.02), z), rot=(0, 0, am + math.pi / 2))
    p.box("ferro", (0.05, 0.05, 0.05), (0.38, 1.1, z + 0.07), bevel=0.01)                              # aldrava
    p.exportar("porta_bandeira")


# ---------------------------------------------------------------- cunhal de cantaria (1 m de altura): blocos alternados com bisel
def cunhal_1m():
    p = Peca()
    for k in range(3):
        longo = k % 2 == 0
        p.box("cantaria", (0.52 if longo else 0.32, 0.31, 0.14), (0.0 if longo else 0.1, k * 0.333 + 0.16, 0.06), bevel=0.014, jitter=0.006)
    p.exportar("cunhal_1m")


# ---------------------------------------------------------------- embasamento de pedra (1 m de largura, 0,9 m de altura): blocos rústicos
def embasamento_1m():
    p = Peca()
    y = 0.0
    fila = 0
    while y < 0.9:
        hh = random.uniform(0.2, 0.3)
        x = -0.5 + (0.0 if fila % 2 == 0 else 0.18)
        while x < 0.5:
            ww = random.uniform(0.3, 0.5)
            x1 = min(x + ww, 0.5)
            p.box("muro", (x1 - x - 0.02, hh - 0.02, 0.08), ((x + x1) / 2, y + hh / 2, 0.04), bevel=0.015, jitter=0.008)
            x = x1
        y += hh
        fila += 1
    p.box("cantaria", (1.0, 0.06, 0.14), (0, 0.93, 0.07), bevel=0.01)                                   # capa
    p.exportar("embasamento_1m")


# ---------------------------------------------------------------- beiral de telhas capa-e-canal (1 m de largura): o fim do telhado visto da rua
def beiral_telhas():
    p = Peca()
    n = 6
    for i in range(n):
        x = -0.5 + (i + 0.5) / n
        for camada, (r, yy) in enumerate(((0.07, 0.0), (0.06, 0.05))):                                  # canal (embaixo) e capa (em cima, deslocada)
            xx = x + (0.0 if camada == 0 else 0.5 / n)
            if xx > 0.5:
                continue
            segs = 6
            for k in range(segs):
                a0 = math.pi * k / segs
                a1 = math.pi * (k + 1) / segs
                am = (a0 + a1) / 2
                L = 2 * r * math.sin((a1 - a0) / 2) + 0.01
                sgn = -1 if camada == 0 else 1
                p.box("telha", (L, 0.012, 0.45), (xx + math.cos(am) * r, yy + sgn * math.sin(am) * r * 0.6, 0.22), rot=(0, 0, sgn * (am + math.pi / 2)))
    p.exportar("beiral_telhas")


# ---------------------------------------------------------------- balaustre isolado e mesa torneada não: só os módulos de fachada
if __name__ == "__main__":
    for fn in (janela, veneziana, lambda: veneziana(True), porta, sacada, cornija, cachorro, chamine,
               sacada_ferro, janela_guilhotina, porta_balcao, grade_janela, porta_bandeira, cunhal_1m, embasamento_1m, beiral_telhas):
        limpar()
        fn()
