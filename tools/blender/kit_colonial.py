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

OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/kit"
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


# ---------------------------------------------------------------- balaustre isolado e mesa torneada não: só os módulos de fachada
if __name__ == "__main__":
    for fn in (janela, veneziana, lambda: veneziana(True), porta, sacada, cornija, cachorro, chamine):
        limpar()
        fn()
