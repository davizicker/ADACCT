"""PLANTA MESTRA: desenha as faixas da rua, as zonas proibidas e o envelope de cada objeto, mais o corte da rua e o ritmo do jogo.
Lê docs/planta/planta.json (casas, rua, objetos) e docs/planta/planta_mestra.json (faixas, zonas, envelopes, violações).
Escreve docs/planta/planta_mestra.png, planta_mestra_pequena.png, corte_da_rua.png, trechos/*.png e docs/31-planta-mestra.md.
Uso: python3 tools/planta_mestra.py
"""
import json, os, math
from PIL import Image, ImageDraw, ImageFont

D = json.load(open("docs/planta/planta.json"))
M = json.load(open("docs/planta/planta_mestra.json"))
OUT = "docs/planta/"
os.makedirs(OUT + "trechos", exist_ok=True)
try:
    F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
    FB = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
    FS = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)
except Exception:
    F = FB = FS = ImageFont.load_default()

RUA = D["rua"]                 # [x, z, largura, y] a cada 2 m
CALCADA = 0.7
CORREDOR = M["corredor"]
PROF_PAREDE = M["faixas"]["parede"]["prof"]

COR = {
    "corredor": (190, 225, 175), "leito": (150, 148, 142), "calcada": (185, 183, 176), "faixa_parede": (226, 196, 140),
    "porta": (40, 140, 255), "boca_de_beco": (0, 200, 210), "volta_de_item": (235, 60, 170),
    "ok": (30, 120, 40), "viola": (230, 20, 20), "casa": (200, 120, 90), "sobrado": (175, 95, 70), "visitavel": (232, 175, 40),
}
TIPO_COR = {"barril": (120, 70, 30), "caixote": (150, 95, 50), "caixote_comprido": (150, 95, 50), "cesto": (170, 130, 60), "jarro": (190, 120, 80),
            "saco": (170, 150, 110), "balde": (110, 90, 70), "regador": (90, 110, 120), "banquinho": (140, 100, 60), "aro": (100, 60, 40),
            "lanterna": (240, 200, 60), "bola": (240, 240, 240), "tv_do_bar": (60, 60, 60), "lousa": (40, 60, 40), "banco": (160, 110, 60),
            "carroca": (130, 90, 50), "carro_coberto": (90, 90, 110), "pedestal": (170, 170, 170), "oratorio": (120, 60, 160),
            "poste": (250, 210, 40), "lampiao_parede": (250, 210, 40), "item_oleo": (235, 60, 170), "item_bilhete": (235, 60, 170), "item_medalha": (235, 60, 170)}


def normal(i):
    a, b = RUA[max(i - 1, 0)], RUA[min(i + 1, len(RUA) - 1)]
    dx, dz = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dz) or 1
    return dz / L * -1, dx / L        # (nx, nz) = direita de quem sobe


def faixa_poly(P, i, d0, d1, lado):
    a, b = RUA[i], RUA[i + 1]
    na, nb = normal(i), normal(i + 1)
    return [P(a[0] + na[0] * d0 * lado, a[1] + na[1] * d0 * lado), P(b[0] + nb[0] * d0 * lado, b[1] + nb[1] * d0 * lado),
            P(b[0] + nb[0] * d1 * lado, b[1] + nb[1] * d1 * lado), P(a[0] + na[0] * d1 * lado, a[1] + na[1] * d1 * lado)]


def desenhar(S, x0, x1, z0, z1, topo, titulo):
    W, H = int((x1 - x0) * S), int((z1 - z0) * S) + topo
    im = Image.new("RGB", (W, H), (240, 236, 226))
    dr = ImageDraw.Draw(im, "RGBA")

    def P(x, z):
        return ((x - x0) * S, (z - z0) * S + topo)

    passo = 10 if S < 30 else 2
    for gx in range(int(x0) // passo * passo, int(x1) + passo, passo):
        dr.line([P(gx, z0), P(gx, z1)], fill=(226, 220, 205), width=1)
    for gz in range(int(z0) // passo * passo, int(z1) + passo, passo):
        dr.line([P(x0, gz), P(x1, gz)], fill=(226, 220, 205), width=1)
    # faixas da rua: leito, corredor, calçada, faixa de parede (a mesma conta do jogo: parede = largura/2 + calçada)
    for i in range(len(RUA) - 1):
        w2 = RUA[i][2] * 0.5
        par = w2 + CALCADA
        for lado in (-1, 1):
            dr.polygon(faixa_poly(P, i, par - PROF_PAREDE, par, lado), fill=COR["faixa_parede"])
            dr.polygon(faixa_poly(P, i, w2, par, lado), fill=COR["calcada"] + (150,))
            dr.polygon(faixa_poly(P, i, 0, w2, lado), fill=COR["leito"])
            dr.polygon(faixa_poly(P, i, 0, CORREDOR, lado), fill=COR["corredor"])
    for i, p in enumerate(RUA):
        s = i * 2
        if s % (50 if S < 30 else 10) == 0:
            dr.text(P(p[0], p[1]), "s=%d" % s, fill=(0, 0, 0), font=F if S < 30 else FB)
    # casas
    for h in D["casas"]:
        poly = [P(c[0], c[1]) for c in h["cantos"]]
        cor = COR["visitavel"] if h["visitavel"] else (COR["casa"] if h["andares"] == 1 else COR["sobrado"])
        dr.polygon(poly, fill=cor, outline=(40, 30, 25))
        dr.line([poly[0], poly[3]], fill=(20, 20, 20), width=3)
        cx = sum(p[0] for p in poly) / 4
        cy = sum(p[1] for p in poly) / 4
        dr.text((cx - 8, cy - 8), (h["numero"] or "-") + ("\n" + h["sala"] if h["visitavel"] else ""), fill=(0, 0, 0), font=F)
    # zonas proibidas
    for z in M["zonas"]:
        cor = COR[z["tipo"]]
        dr.polygon([P(c[0], c[1]) for c in z["cantos"]], fill=cor + (70,), outline=cor + (255,))
    # envelopes dos objetos
    for o in M["objetos"]:
        a = P(o["caixa_xz"][0], o["caixa_xz"][1])
        b = P(o["caixa_xz"][2], o["caixa_xz"][3])
        r = [min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1])]
        if r[2] - r[0] < 4:
            r = [r[0] - 2, r[1] - 2, r[0] + 2, r[1] + 2]
        dr.rectangle(r, fill=TIPO_COR.get(o["tipo"], (100, 100, 100)), outline=COR["ok"] if o["ok"] else COR["viola"], width=2 if o["ok"] else 4)
        if S >= 30:
            dr.text((r[2] + 2, r[1]), o["tipo"], fill=(0, 0, 0), font=FS)
    dr.text((20, 12), titulo, fill=(0, 0, 0), font=FB)
    return im, dr


# ------------------------------------------------------------------ planta inteira
xs = [p[0] for p in RUA] + [c[0] for h in D["casas"] for c in h["cantos"]]
zs = [p[1] for p in RUA] + [c[1] for h in D["casas"] for c in h["cantos"]]
X0, X1, Z0, Z1 = min(xs) - 10, max(xs) + 10, min(zs) - 10, max(zs) + 10
im, dr = desenhar(16.0, X0, X1, Z0, Z1, 230, "BRADADOR - PLANTA MESTRA: faixas da rua, zonas proibidas e envelope de cada objeto (1 m = 16 px)")
leg = [("corredor do jogador (nada sólido)", COR["corredor"]), ("leito da rua", COR["leito"]), ("calçada", COR["calcada"]),
       ("faixa de parede (objetos encostados, até %.2f m)" % PROF_PAREDE, COR["faixa_parede"]), ("frente de porta (livre)", COR["porta"]),
       ("boca de beco (livre)", COR["boca_de_beco"]), ("volta de item (livre)", COR["volta_de_item"]), ("casa visitável", COR["visitavel"]),
       ("objeto OK (borda verde)", COR["ok"]), ("objeto fora da planta (borda vermelha)", COR["viola"])]
for i, (t, c) in enumerate(leg):
    x = 20 + (i % 4) * 470
    y = 55 + (i // 4) * 30
    dr.rectangle([x, y, x + 22, y + 18], fill=c, outline=(0, 0, 0))
    dr.text((x + 30, y), t, fill=(0, 0, 0), font=F)
nv = len(M["violacoes"])
CB = [c for c in (open("docs/planta/correcoes_bake.txt").read().split("\n") if os.path.exists("docs/planta/correcoes_bake.txt") else []) if c.strip()]
dr.text((20, 150), "Objetos conferidos: %d | zonas proibidas: %d | fora da planta: %d | correções no bake: %d" % (len(M["objetos"]), len(M["zonas"]), nv, len(CB)), fill=(150, 0, 0) if nv else (0, 100, 0), font=FB)
im.save(OUT + "planta_mestra.png")
im.resize((im.width // 3, im.height // 3)).save(OUT + "planta_mestra_pequena.png")

# ------------------------------------------------------------------ trechos ampliados (40 px/m), um a cada 60 m de rua
trechos_png = []
for k, s0 in enumerate(range(0, len(RUA) * 2 - 2, 60)):
    pts = RUA[s0 // 2: min(len(RUA), (s0 + 60) // 2 + 1)]
    xs = [p[0] for p in pts]
    zs = [p[1] for p in pts]
    x0, x1, z0, z1 = min(xs) - 9, max(xs) + 9, min(zs) - 9, max(zs) + 9
    im2, _ = desenhar(40.0, x0, x1, z0, z1, 60, "Trecho s=%d a %d m (1 m = 40 px, grade de 2 m)" % (s0, s0 + 60))
    nome = "trechos/trecho_%03d.png" % s0
    im2.save(OUT + nome)
    trechos_png.append((s0, nome))

# ------------------------------------------------------------------ corte da rua (seção transversal típica, rua de 5 m)
S = 90
W2 = 2.5
im3 = Image.new("RGB", (int((W2 + CALCADA + 2.2) * 2 * S) + 40, 560), (245, 242, 232))
d3 = ImageDraw.Draw(im3, "RGBA")
cx = im3.width // 2
base = 470
def X(d):
    return cx + d * S
def Y(h):
    return base - h * S
d3.text((20, 10), "Corte da rua (rua de 5 m): faixas e envelopes em escala, 1 m = %d px" % S, fill=(0, 0, 0), font=FB)
par = W2 + CALCADA
for lado in (-1, 1):
    d3.rectangle([min(X(par * lado), X((par + 1.6) * lado)), Y(4.0), max(X(par * lado), X((par + 1.6) * lado)), base], fill=COR["casa"], outline=(40, 30, 25))
    d3.text((min(X(par * lado), X((par + 1.6) * lado)) + 6, Y(3.8)), "parede\nda casa", fill=(0, 0, 0), font=F)
    d3.rectangle([min(X(W2 * lado), X(par * lado)), Y(0.12), max(X(W2 * lado), X(par * lado)), base], fill=COR["calcada"])
    d3.rectangle([min(X((par - PROF_PAREDE) * lado), X(par * lado)), Y(2.3), max(X((par - PROF_PAREDE) * lado), X(par * lado)), Y(0.12)], fill=COR["faixa_parede"] + (110,), outline=(150, 110, 50))
d3.rectangle([X(-W2), Y(0.02), X(W2), base], fill=COR["leito"])
d3.rectangle([X(-CORREDOR), Y(2.3), X(CORREDOR), Y(0.02)], fill=COR["corredor"] + (120,), outline=(60, 130, 60))
d3.text((X(-CORREDOR) + 8, Y(2.2)), "corredor do jogador\n%.1f m livre\n(Mula e fuga)" % (CORREDOR * 2), fill=(0, 70, 0), font=F)
d3.text((X(par - PROF_PAREDE) + 4, Y(2.25)), "faixa de\nparede\n%.2f m" % PROF_PAREDE, fill=(110, 70, 20), font=F)
d3.line([X(-par - 1.6), Y(2.3), X(par + 1.6), Y(2.3)], fill=(120, 120, 120), width=1)
d3.text((X(-par - 1.5), Y(2.3) - 18), "2,3 m: acima daqui (lampião, sacada) não atrapalha quem passa", fill=(90, 90, 90), font=FS)
# exemplos de envelope encostados na parede da direita e da esquerda
ex = [("barril", 0.80, 0.95, 1), ("banco", 0.55, 0.95, -1)]
for nome, prof, alt, lado in ex:
    a, b = X((par - prof) * lado), X(par * lado)
    d3.rectangle([min(a, b), Y(0.12 + alt), max(a, b), Y(0.12)], fill=TIPO_COR[nome], outline=(0, 0, 0))
    d3.text((min(a, b) + 3, Y(0.12 + alt) - 18), nome, fill=(0, 0, 0), font=F)
d3.rectangle([X(par - 0.6), Y(3.6), X(par), Y(2.5)], fill=TIPO_COR["lampiao_parede"], outline=(0, 0, 0))
d3.text((X(par - 0.6) - 110, Y(3.4)), "lampião", fill=(0, 0, 0), font=F)
for d, t in [(0, "eixo"), (CORREDOR, "%.2f" % CORREDOR), (W2, "%.1f meio-fio" % W2), (par, "%.1f parede" % par)]:
    for lado in ((1,) if d == 0 else (-1, 1)):
        d3.line([X(d * lado), base, X(d * lado), base + 12], fill=(0, 0, 0), width=2)
        d3.text((X(d * lado) - 20, base + 16), t, fill=(0, 0, 0), font=FS)
im3.save(OUT + "corte_da_rua.png")

# ------------------------------------------------------------------ ritmo do jogo (o que o jogador encontra a cada trecho)
def s_de(o):
    return o.get("s", 0.0)

itens = [o for o in D["objetos"] if o["grupo"] == "Coletaveis"]
becos = [o for o in D["objetos"] if o["grupo"] == "Becos"]
luzes = [o for o in D["objetos"] if o["grupo"] == "Iluminacao" and not o["nome"].startswith("Fios")]
salas = [h for h in D["casas"] if h["visitavel"]]
ritmo = []
comp = (len(RUA) - 1) * 2
for s0 in range(0, int(comp), 50):
    s1 = s0 + 50
    f = lambda L: [o for o in L if s0 <= s_de(o) < s1]
    ritmo.append({"s0": s0, "s1": s1,
                  "oleo": len([o for o in f(itens) if o["nome"].startswith("Oleo")]),
                  "medalhas": len([o for o in f(itens) if o["nome"].startswith("Reliquia")]),
                  "bilhetes": len([o for o in f(itens) if o["nome"].startswith("Bilhete")]),
                  "becos": len(f(becos)), "luzes": len(f(luzes)),
                  "salas": ", ".join(h["sala"] for h in salas if s0 <= h["s"] < s1)})

# ------------------------------------------------------------------ documento
md = ["# 31 — Planta mestra (o mapa decidido antes dos objetos)\n",
      "A planta mestra é a regra do mapa. Cada objeto da rua tem **uma faixa** onde pode ficar e **um envelope**, o espaço máximo que ocupa, já com folga.",
      "Nenhum objeto pode entrar numa **zona proibida** nem no envelope de outro objeto.",
      "O código está em `scripts/planta_mestra.gd`. O bake confere e corrige: desliza o objeto ao longo da parede até a vaga mais próxima que cabe, ou tira o objeto se não houver vaga a menos de 5 m.",
      "Depois de corrigir, confere de novo. As imagens e este documento são gerados por `tools/planta_mestra.gd` + `tools/planta_mestra.py`.\n",
      "![corte da rua](planta/corte_da_rua.png)\n",
      "## Faixas da rua (medidas a partir do eixo, para cada lado)\n",
      "| Faixa | Onde | O que pode |", "|---|---|---|",
      "| Corredor do jogador | eixo até %.2f m | nada sólido: é por onde se anda e se foge da Mula |" % CORREDOR,
      "| Leito da rua | %.2f m até o meio-fio (largura/2) | bueiros, poças, pedras soltas rentes ao chão |" % CORREDOR,
      "| Calçada | meio-fio até a parede (+%.1f m) | postes, carroça, carro coberto |" % CALCADA,
      "| Faixa de parede | da parede até %.2f m para a rua | barris, caixotes, cestos, bancos, oratórios, lousas |" % PROF_PAREDE,
      "| Alto (acima de 2,3 m) | qualquer ponto | lampiões de parede, sacadas, varais, fios |",
      "",
      "## Zonas proibidas\n",
      "| Zona | Tamanho | Por quê |", "|---|---|---|",
      "| Frente de porta | 1,9 m de largura × 1,4 m para fora | a porta tem que abrir e ser vista; em casa visitável, o E entra na sala |",
      "| Boca de beco | largura do beco + 0,4 m × 1,8 m para fora (as duas bocas do beco-escada) | o beco é refúgio: a entrada não pode ter tropeço |",
      "| Volta de item | raio de 0,75 m | frasco, bilhete e medalha ficam à vista e clicáveis; só o apoio deles fica perto |",
      "| Corredor do jogador | %.1f m no meio da rua | fuga e caminhada sem enroscar |" % (CORREDOR * 2),
      "",
      "## Catálogo de envelopes (tamanho máximo de cada tipo de objeto)\n",
      "| Prefixo do nome | Tipo | Faixa | Largura × fundo × altura (m) | Móvel pela planta |", "|---|---|---|---|---|"]
for c in M["catalogo"]:
    e = c["envelope"]
    md.append("| %s | %s | %s | %.2f × %.2f × %.2f | %s |" % (c["prefixo"], c["tipo"], c["faixa"], e[0], e[1], e[2], "sim" if c["movel"] else "não (corrigir na montagem)"))
md += ["", "Objeto de rua sem tipo no catálogo conta como erro: nada entra no mapa sem envelope definido.", "",
       "## Ritmo do jogo (o que o jogador encontra a cada 50 m de rua)\n",
       "| Trecho (s) | Querosene | Medalhas | Bilhetes | Becos (refúgio) | Luzes | Casas visitáveis |", "|---|---|---|---|---|---|---|"]
for r in ritmo:
    md.append("| %d–%d | %d | %d | %d | %d | %d | %s |" % (r["s0"], r["s1"], r["oleo"], r["medalhas"], r["bilhetes"], r["becos"], r["luzes"], r["salas"]))
lacunas = [r for r in ritmo if r["s1"] <= 450 and r["becos"] == 0 and r["oleo"] == 0 and not r["salas"]]
md.append("")
md.append("Trechos sem beco, sem casa visitável **e** sem querosene (a tensão sobe sem nenhum alívio): " + (", ".join("%d–%d" % (r["s0"], r["s1"]) for r in lacunas) if lacunas else "nenhum."))
md += ["", "## Resultado da conferência\n",
       "- Objetos conferidos: %d" % len(M["objetos"]), "- Zonas proibidas: %d" % len(M["zonas"]), "- Fora da planta agora: **%d**" % nv]
for v in M["violacoes"]:
    md.append("  - %s (%s, s=%.0f): %s" % (v["obj"], v["tipo"], v["s"], "; ".join(v["regras"])))
cb = open("docs/planta/correcoes_bake.txt").read().split("\n") if os.path.exists("docs/planta/correcoes_bake.txt") else []
cb = [c for c in cb if c.strip()]
md.append("- Correções feitas na montagem (bake): %d" % len(cb))
for c in cb:
    md.append("  - " + c)
md += ["", "## Imagens\n", "- Planta inteira: `docs/planta/planta_mestra.png` (1 m = 16 px); reduzida: `planta_mestra_pequena.png`.", "- Trechos ampliados (1 m = 40 px):"]
for s0, nome in trechos_png:
    md.append("  - s=%d–%d: `docs/planta/%s`" % (s0, s0 + 60, nome))
open("docs/31-planta-mestra.md", "w").write("\n".join(md) + "\n")
print("planta mestra ok: objetos=%d zonas=%d violacoes=%d trechos=%d" % (len(M["objetos"]), len(M["zonas"]), nv, len(trechos_png)))
