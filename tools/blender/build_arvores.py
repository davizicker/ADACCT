"""Árvores, palmeira e bananeira com GEOMETRIA de verdade (troncos e galhos afunilados, folhas como malhas), sem cartões de textura.
Cada espécie sai em 2 níveis de detalhe no mesmo .glb:  <nome>_L0 (perto: galhos + folhas individuais) e <nome>_L1 (longe: galhos finos + tufos 3D).
Materiais por posição (o Godot troca pelos materiais do projeto): 0 casca/tronco, 1..3 folhas em 3 verdes (ou 1 = folha da palmeira/bananeira).
Uso: python tools/blender/build_arvores.py assets/models/poly/arvores.glb"""
import bpy, bmesh, sys, os, math, random
from mathutils import Vector, Matrix

OUT = sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)


def frame(t):
    a = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
    u = t.cross(a).normalized()
    v = t.cross(u).normalized()
    return u, v


def tube(bm, pts, radii, sides, mat=0, uvl=None, tile=0.9):
    n = len(pts)
    rings, vs = [], []
    acc = 0.0
    for i in range(n):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        u, v = frame(t)
        ring = [bm.verts.new(pts[i] + (u * math.cos(math.tau * k / sides) + v * math.sin(math.tau * k / sides)) * radii[i]) for k in range(sides)]
        rings.append(ring)
        if i > 0:
            acc += (pts[i] - pts[i - 1]).length
        vs.append(acc / tile)
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            try:
                f = bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
            except ValueError:
                continue
            f.material_index = mat
            f.smooth = True
            if uvl is not None:
                circ = max(radii[i], 0.01) * math.tau / tile
                for loop, (uu, vv) in zip(f.loops, ((k / sides * circ, vs[i]), ((k + 1) / sides * circ, vs[i]), ((k + 1) / sides * circ, vs[i + 1]), (k / sides * circ, vs[i + 1]))):
                    loop[uvl].uv = (uu, vv)
    # tampa na ponta (fecha o galho)
    tip = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-1] * 0.8)
    for k in range(sides):
        try:
            f = bm.faces.new((rings[-1][(k + 1) % sides], rings[-1][k], tip))
            f.material_index = mat
        except ValueError:
            pass


def leaf(bm, pos, d, up, L, W, mat):
    """Folha lanceolada com dobra central e ponta caída: 6 vértices, 4 triângulos."""
    d = d.normalized()
    s = d.cross(up).normalized()
    n = s.cross(d).normalized()
    b = bm.verts.new(pos)
    l = bm.verts.new(pos + d * L * 0.38 - s * W * 0.5 + n * L * 0.03)
    r = bm.verts.new(pos + d * L * 0.38 + s * W * 0.5 + n * L * 0.03)
    m = bm.verts.new(pos + d * L * 0.55 + n * L * 0.05)
    t = bm.verts.new(pos + d * L - n * L * 0.12)
    for tri in ((b, m, l), (b, r, m), (l, m, t), (m, r, t)):
        try:
            f = bm.faces.new(tri)
            f.material_index = mat
            f.smooth = True
        except ValueError:
            pass


def lump(bm, c, rad, rng, mat, sub=1):
    """Tufo 3D de folhagem: icosfera achatada e deformada (sub=1: 80 faces)."""
    g = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=rad)
    vs = g["verts"]
    sq = rng.uniform(0.7, 0.9)
    for v in vs:
        v.co = Vector((v.co.x * rng.uniform(0.85, 1.15), v.co.y * rng.uniform(0.85, 1.15), v.co.z * sq * rng.uniform(0.85, 1.15))) + c
    for f in set(f for v in vs for f in v.link_faces):
        f.material_index = mat
        f.smooth = True


class Arv:
    def __init__(self, seed, h, crown, branch_n, depth, leaf_len, leaves_per_tip, lod, flare=1.5, lean=0.0):
        self.rng = random.Random(seed)
        self.h, self.crown, self.bn, self.depth = h, crown, branch_n, depth
        self.leaf_len, self.lpt, self.lod, self.flare, self.lean = leaf_len, leaves_per_tip, lod, flare, lean
        self.tips = []
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def galho(self, p, d, length, r, depth):
        rng = self.rng
        segs = 4 if depth == 0 else 3
        pts, rad = [p], [r]
        cur, dd = p, d
        for i in range(segs):
            dd = (dd + Vector((rng.uniform(-0.18, 0.18), rng.uniform(-0.18, 0.18), rng.uniform(-0.04, 0.12) if depth else 0.02))).normalized()
            cur = cur + dd * (length / segs)
            pts.append(cur)
            rad.append(max(r * (1 - 0.7 * (i + 1) / segs), 0.012))
        if depth == 0:
            rad[0] = r * self.flare
            rad[1] = r * (1 + (self.flare - 1) * 0.35)
        sides = (7 if depth == 0 else 5) if self.lod == 0 else (5 if depth == 0 else 4)
        tube(self.bm, pts, rad, sides, 0, self.uv)
        if depth < self.depth:
            for c in range(self.bn if depth == 0 else rng.randint(2, 3)):
                k = rng.uniform(0.45, 1.0) if depth == 0 else rng.uniform(0.55, 1.0)
                base_i = min(int(k * segs), segs)
                bp = pts[base_i]
                az = rng.uniform(0, math.tau) if depth else (c / max(self.bn, 1)) * math.tau + rng.uniform(-0.3, 0.3)
                tilt = rng.uniform(0.7, 1.1) if depth == 0 else rng.uniform(0.5, 0.9)
                out = Vector((math.cos(az), math.sin(az), 0))
                nd = (Vector((0, 0, 1)) * math.cos(tilt) + out * math.sin(tilt)).normalized() if depth == 0 else (dd * 0.5 + out * 0.6 + Vector((0, 0, rng.uniform(0.0, 0.3)))).normalized()
                self.galho(bp, nd, length * (0.85 if depth == 0 else 0.62) * rng.uniform(0.8, 1.1), rad[base_i] * 0.6, depth + 1)
        if depth >= self.depth - 1:
            self.tips.append((cur, dd))

    def folhas(self, cores):
        rng = self.rng
        for tip, d in self.tips:
            if self.lod == 0:
                # miolo de folhagem (tufo 3D) + folhas individuais saindo dele
                lump(self.bm, tip + Vector((0, 0, 0.2)), self.crown * 0.24, rng, rng.choice(cores), 1)
                for _ in range(self.lpt):
                    o = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.4, 1.0))).normalized() * rng.uniform(self.crown * 0.12, self.crown * 0.34)
                    dd = o.normalized() + Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 0.1))
                    leaf(self.bm, tip + o + Vector((0, 0, 0.2)), dd, Vector((0, 0, 1)), self.leaf_len * rng.uniform(0.8, 1.25), self.leaf_len * 0.4, rng.choice(cores))
            else:
                lump(self.bm, tip + Vector((0, 0, 0.25)), self.crown * 0.34, rng, rng.choice(cores), 1)

    def pronto(self, nome):
        me = bpy.data.meshes.new(nome)
        self.bm.to_mesh(me)
        self.bm.free()
        ob = bpy.data.objects.new(nome, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def arvore(nome, seed, h, crown, branch_n, depth, leaf_len, lpt, lod, flare=1.5):
    a = Arv(seed, h, crown, branch_n, depth, leaf_len, lpt, lod, flare)
    r0 = 0.42 * (h / 4.5) ** 0.5
    # tronco: sobe até ~55% da altura e dali nascem os galhos principais (galho(depth0) = tronco + coroa)
    a.galho(Vector((0, 0, -0.35)), Vector((0, 0, 1)), h * 0.95, r0, 0)
    a.folhas([1, 2, 3])
    return a.pronto(nome)


def palmeira(nome, lod):
    rng = random.Random(77)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    H = 12.0
    n = 26 if lod == 0 else 9
    pts, rad = [], []
    for i in range(n + 1):
        t = i / n
        pts.append(Vector((math.sin(t * 1.6) * 0.35 * (t), 0, -0.4 + t * H)))
        base = 0.34 * (1 - t) + 0.20 * t
        ring = 1 + (0.07 * math.sin(t * H / 0.38 * math.tau) if lod == 0 else 0.0)
        rad.append(base * ring * (1.5 if i == 0 else 1.0))
    tube(bm, pts, rad, 10 if lod == 0 else 6, 0, uvl, 1.0)
    topo = pts[-1]
    # bainha verde no topo
    tube(bm, [topo + Vector((0, 0, -1.3)), topo + Vector((0, 0, -0.2)), topo + Vector((0, 0, 0.5))], [0.2, 0.22, 0.16], 8 if lod == 0 else 5, 1)
    nf = 14 if lod == 0 else 9
    for i in range(nf):
        az = math.tau * i / nf + rng.uniform(-0.15, 0.15)
        a0 = math.radians(70 - 60 * (i / nf) ** 0.8 + rng.uniform(-6, 6))
        L = 3.9 * rng.uniform(0.85, 1.1)
        out = Vector((math.cos(az), math.sin(az), 0))
        up = Vector((0, 0, 1))
        nseg = 7 if lod == 0 else 4
        path = []
        for k in range(nseg + 1):
            t = k / nseg
            path.append(topo + out * (L * t * math.cos(a0)) + up * (L * t * math.sin(a0) - 1.2 * L * t * t))
        tube(bm, path, [0.05 * (1 - k / nseg) + 0.012 for k in range(nseg + 1)], 4 if lod == 0 else 3, 1)
        if lod == 0:
            for k in range(2, nseg + 1):
                for j in range(3):
                    t = (k - 1 + j / 3) / nseg
                    t = min(t, 1.0)
                    pk = topo + out * (L * t * math.cos(a0)) + up * (L * t * math.sin(a0) - 1.2 * L * t * t)
                    side = out.cross(up)
                    ll = 0.95 * (1 - 0.55 * t)
                    for sg in (-1, 1):
                        dirv = (side * sg * 0.9 + out * 0.45 - up * 0.65).normalized()
                        w = 0.07
                        a = bm.verts.new(pk)
                        b = bm.verts.new(pk + dirv * ll * 0.5 + out * 0.1 + up * 0.04)
                        c = bm.verts.new(pk + dirv * ll + up * -0.25 * ll)
                        d = bm.verts.new(pk + out * w)
                        e = bm.verts.new(pk + dirv * ll * 0.5 + out * (0.1 + w))
                        for tri in ((a, b, e), (a, e, d), (b, c, e)):
                            try:
                                f = bm.faces.new(tri)
                                f.material_index = 1
                            except ValueError:
                                pass
        else:
            # longe: lâmina arqueada simples de cada fronde, como malha de verdade (6 triângulos)
            side = out.cross(up)
            ww = 0.55
            vs = [(bm.verts.new(p - side * ww), bm.verts.new(p + side * ww)) for p in path]
            for k in range(nseg):
                for tri in ((vs[k][0], vs[k][1], vs[k + 1][1]), (vs[k][0], vs[k + 1][1], vs[k + 1][0])):
                    try:
                        f = bm.faces.new(tri)
                        f.material_index = 1
                    except ValueError:
                        pass
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def bananeira(nome, lod):
    rng = random.Random(5)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    for s in range(3 if lod == 0 else 2):          # touceira: 1 a 3 pseudocaules
        ox, oy = (0, 0) if s == 0 else (rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7))
        h = 2.6 * rng.uniform(0.7, 1.1) if s else 2.8
        n = 5 if lod == 0 else 2
        pts = [Vector((ox, oy, i / n * h)) for i in range(n + 1)]
        tube(bm, pts, [0.2 - 0.07 * i / n for i in range(n + 1)], 8 if lod == 0 else 5, 0, uvl, 1.0)
        top = pts[-1]
        nl = 7 if lod == 0 else 5
        for i in range(nl):
            az = math.tau * i / nl + rng.uniform(-0.3, 0.3) + s
            out = Vector((math.cos(az), math.sin(az), 0))
            side = out.cross(Vector((0, 0, 1)))
            L = rng.uniform(2.2, 2.9)
            a0 = math.radians(rng.uniform(25, 60))
            ns = 7 if lod == 0 else 3
            rows = []
            for k in range(ns + 1):
                t = k / ns
                c = top + out * (L * t * math.cos(a0)) + Vector((0, 0, 1)) * (L * t * math.sin(a0) - 1.6 * L * t * t)
                w = 0.42 * math.sin(math.pi * min(t * 1.05 + 0.04, 1.0)) ** 0.8
                wave = 0.06 * math.sin(t * 9 + i)
                rows.append((bm.verts.new(c - side * w + Vector((0, 0, -w * 0.25 + wave))), bm.verts.new(c), bm.verts.new(c + side * w + Vector((0, 0, -w * 0.25 - wave)))))
            for k in range(ns):
                for j in range(2):
                    a, b = rows[k][j], rows[k][j + 1]
                    c2, d2 = rows[k + 1][j + 1], rows[k + 1][j]
                    for tri in ((a, b, c2), (a, c2, d2)):
                        try:
                            f = bm.faces.new(tri)
                            f.material_index = 1
                            f.smooth = True
                        except ValueError:
                            pass
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


MATS = {"casca": (0.35, 0.28, 0.22), "folha_a": (0.12, 0.30, 0.08), "folha_b": (0.20, 0.38, 0.10), "folha_c": (0.28, 0.42, 0.12),
        "palma_tronco": (0.55, 0.52, 0.48), "palma_folha": (0.16, 0.34, 0.10), "banana_tronco": (0.45, 0.55, 0.25), "banana_folha": (0.25, 0.48, 0.12)}


def mats(ob, nomes):
    for n in nomes:
        if n not in bpy.data.materials:
            m = bpy.data.materials.new(n)
            m.diffuse_color = (*MATS[n], 1.0)
        ob.data.materials.append(bpy.data.materials[n])


objs = []
specs = [("arvore_a", 11, 6.2, 3.2, 5, 3, 0.75, 22), ("arvore_b", 23, 5.0, 2.8, 6, 3, 0.7, 20), ("arvore_c", 37, 7.4, 3.6, 4, 4, 0.8, 22),
         ("arvore_pequena", 41, 2.4, 1.4, 4, 2, 0.4, 14)]
for nome, seed, h, crown, bn, dep, ll, lpt in specs:
    for lod in (0, 1):
        ob = arvore("%s_L%d" % (nome, lod), seed, h, crown, bn, dep, ll, lpt, lod, 1.7)
        mats(ob, ["casca", "folha_a", "folha_b", "folha_c"])
        objs.append(ob)
for lod in (0, 1):
    ob = palmeira("palmeira_L%d" % lod, lod)
    mats(ob, ["palma_tronco", "palma_folha"])
    objs.append(ob)
    ob = bananeira("bananeira_L%d" % lod, lod)
    mats(ob, ["banana_tronco", "banana_folha"])
    objs.append(ob)
for ob in objs:
    print("[arv] %-22s %6d tris" % (ob.name, sum(len(p.vertices) - 2 for p in ob.data.polygons)))
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_image_format="NONE", export_materials="EXPORT",
                          export_cameras=False, export_lights=False)
print("[arv] exportado %s (%d KB)" % (OUT, os.path.getsize(OUT) // 1024))
