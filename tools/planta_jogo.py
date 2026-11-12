"""Desenha a PLANTA DO JOGO (vista de cima, em escala) a partir de docs/planta/planta.json e escreve docs/29-planta-do-jogo.md.
Uso: python3 tools/planta_jogo.py docs/planta/planta.json docs/planta/
"""
import json, sys, os, math
from PIL import Image, ImageDraw, ImageFont

d = json.load(open(sys.argv[1]))
outdir = sys.argv[2]
S = 16.0                                   # pixels por metro
xs = [p[0] for p in d["rua"]] + [c[0] for h in d["casas"] for c in h["cantos"]]
zs = [p[1] for p in d["rua"]] + [c[1] for h in d["casas"] for c in h["cantos"]]
x0, x1, z0, z1 = min(xs) - 12, max(xs) + 12, min(zs) - 12, max(zs) + 12
W, H = int((x1 - x0) * S), int((z1 - z0) * S) + 260
im = Image.new("RGB", (W, H), (236, 232, 220))
dr = ImageDraw.Draw(im)
try:
    F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
    FB = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
    FS = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)
except Exception:
    F = FB = FS = ImageFont.load_default()

def P(x, z):
    return ((x - x0) * S, (z - z0) * S + 200)

# grade de 10 m
for gx in range(int(x0) // 10 * 10, int(x1) + 10, 10):
    dr.line([P(gx, z0), P(gx, z1)], fill=(222, 216, 200), width=1)
    dr.text(P(gx + 0.3, z0 + 0.3), "%d m" % gx, fill=(160, 150, 130), font=FS)
for gz in range(int(z0) // 10 * 10, int(z1) + 10, 10):
    dr.line([P(x0, gz), P(x1, gz)], fill=(222, 216, 200), width=1)
    dr.text(P(x0 + 0.3, gz + 0.3), "%d m" % gz, fill=(160, 150, 130), font=FS)

# rua (com a largura real) e eixo
rua = d["rua"]
for i in range(len(rua) - 1):
    a, b = rua[i], rua[i + 1]
    dx, dz = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dz) or 1
    nx, nz = -dz / L, dx / L
    w = a[2] * 0.5 + 0.7
    poly = [P(a[0] + nx * w, a[1] + nz * w), P(b[0] + nx * w, b[1] + nz * w), P(b[0] - nx * w, b[1] - nz * w), P(a[0] - nx * w, a[1] - nz * w)]
    dr.polygon(poly, fill=(178, 176, 170))
for i in range(len(rua) - 1):
    a, b = rua[i], rua[i + 1]
    dx, dz = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dz) or 1
    nx, nz = -dz / L, dx / L
    w = a[2] * 0.5
    poly = [P(a[0] + nx * w, a[1] + nz * w), P(b[0] + nx * w, b[1] + nz * w), P(b[0] - nx * w, b[1] - nz * w), P(a[0] - nx * w, a[1] - nz * w)]
    dr.polygon(poly, fill=(150, 148, 142))
dr.line([P(p[0], p[1]) for p in rua], fill=(255, 255, 255), width=1)
for i, p in enumerate(rua):
    s = i * 2
    if s % 50 == 0:
        dr.ellipse([P(p[0] - 0.6, p[1] - 0.6), P(p[0] + 0.6, p[1] + 0.6)], fill=(255, 255, 255))
        dr.text(P(p[0] + 0.8, p[1] - 0.8), "s=%d" % s, fill=(255, 255, 255), font=F)

CORES = {"Adornos": (150, 95, 50), "Props": (200, 110, 40), "Coletaveis": (230, 40, 160), "Iluminacao": (250, 210, 40), "Nichos": (120, 60, 160),
         "PropsEncosta": (90, 120, 70), "MurosDasCurvas": (110, 110, 105), "Adro": (170, 150, 120), "Ponte": (70, 130, 190), "Ratos": (60, 60, 60),
         "Becos": (70, 110, 200), "MurosEQuintais": (120, 160, 90), "Interiores": None}
cont = {}
for o in d["objetos"]:
    g = o["grupo"]
    cont[g] = cont.get(g, 0) + 1
    cor = CORES.get(g)
    if cor is None or o["nome"].split("_")[0] in ("Pecas", "FiosDeLuz", "Varais", "Lampadas", "Detalhes", "Muros", "MuroCurva"):
        continue                       # peças agrupadas (bancos, fios, varais) têm caixa do tamanho da rua: ficam fora do desenho
    a, b = P(o["caixa_xz"][0], o["caixa_xz"][1]), P(o["caixa_xz"][2], o["caixa_xz"][3])
    if abs(b[0] - a[0]) < 3 and abs(b[1] - a[1]) < 3:
        dr.ellipse([a[0] - 3, a[1] - 3, a[0] + 3, a[1] + 3], fill=cor)
    else:
        area_m2 = abs(o["caixa_xz"][2] - o["caixa_xz"][0]) * abs(o["caixa_xz"][3] - o["caixa_xz"][1])
        grande = area_m2 > 12.0
        dr.rectangle([min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1])], outline=cor, width=2, fill=None if grande else cor)

# casas
for h in d["casas"]:
    poly = [P(c[0], c[1]) for c in h["cantos"]]
    cor = (232, 175, 40) if h["visitavel"] else ((200, 120, 90) if h["andares"] == 1 else (175, 95, 70))
    dr.polygon(poly, fill=cor, outline=(40, 30, 25))
    dr.line([poly[0], poly[3]], fill=(20, 20, 20), width=4)            # frente (fachada)
    px, py = P(h["porta_xyz"][0], h["porta_xyz"][2])
    dr.ellipse([px - 4, py - 4, px + 4, py + 4], fill=(30, 200, 255))  # porta
    cx = sum(p[0] for p in poly) / 4
    cy = sum(p[1] for p in poly) / 4
    rot = h["numero"] or "-"
    txt = rot + ("\n" + h["sala"] if h["visitavel"] else "")
    dr.multiline_text((cx - 10, cy - 10), txt, fill=(0, 0, 0), font=F)

leg = [("rua (com calçada)", (150, 148, 142)), ("casa térrea", (200, 120, 90)), ("sobrado", (175, 95, 70)), ("casa visitável", (232, 175, 40)),
       ("porta", (30, 200, 255)), ("becos", CORES["Becos"]), ("quintais/muros", CORES["MurosEQuintais"]), ("muros das curvas", CORES["MurosDasCurvas"]),
       ("barris/caixotes", CORES["Adornos"]), ("objetos de rua", CORES["Props"]), ("itens (óleo, medalha, bilhete)", CORES["Coletaveis"]),
       ("lampiões/postes", CORES["Iluminacao"]), ("oratórios", CORES["Nichos"]), ("encostas", CORES["PropsEncosta"]), ("ponte/riacho", CORES["Ponte"]), ("adro/igreja", CORES["Adro"])]
dr.text((20, 15), "BRADADOR - planta do jogo (vista de cima, escala 1 m = %d px, grade de 10 m). Gerada da cena real (scenes/vila.scn)." % S, fill=(0, 0, 0), font=FB)
dr.text((20, 50), "Casas: %d (visitáveis %d) | objetos cadastrados: %d | problemas nos módulos: %d" % (len(d["casas"]), sum(1 for h in d["casas"] if h["visitavel"]), len(d["objetos"]), len(d["problemas"])), fill=(0, 0, 0), font=F)
xl = 20
for i, (t, c) in enumerate(leg):
    x = 20 + (i % 6) * 330
    y = 85 + (i // 6) * 30
    dr.rectangle([x, y, x + 22, y + 18], fill=c, outline=(0, 0, 0))
    dr.text((x + 30, y), t, fill=(0, 0, 0), font=F)
im.save(os.path.join(outdir, "planta_do_jogo.png"))
im.resize((W // 3, H // 3)).save(os.path.join(outdir, "planta_do_jogo_pequena.png"))

# ------------------------------------------------------------------ documento
md = []
md.append("# Planta do jogo (gerada da cena real)\n")
md.append("Gerada por `tools/planta_jogo.gd` (lê `scenes/vila.scn`) e `tools/planta_jogo.py`. Imagem: `docs/planta/planta_do_jogo.png` (1 m = %d px). Dados completos (todas as posições): `docs/planta/planta.json`.\n" % S)
md.append("Coordenadas em metros: x para leste, z para sul, y altura. `s` = metros ao longo da rua, da entrada (s=0) até a igreja. Lado -1/+1 = esquerda/direita de quem sobe.\n")
md.append("\n## Catálogo dos módulos das casas (tamanho padrão medido do modelo)\n")
md.append("| Módulo | Largura (m) | Altura (m) | Saliência da parede (m) | Usos na vila |")
md.append("|---|---|---|---|---|")
usos = {}
for h in d["casas"]:
    for k, v in h["modulos_contagem"].items():
        usos[k] = usos.get(k, 0) + v
for k, v in sorted(d["modulos"].items()):
    md.append("| %s | %.2f | %.2f | %.2f | %d |" % (k, v["largura"], v["altura"], v["saliencia"], usos.get(k, 0)))
md.append("\nRegras de encaixe: cunhal e embasamento em módulos de 1 m; cunhal a 0,26 m da quina; embasamento pula o vão da porta (1,3 m); sacada de ferro só sobre porta-balcão do 2º andar; janela/porta nos vãos da fachada; cornija e cachorros no topo da parede; beiral de telhas a cada 1 m.\n")
md.append("\n## Casas (ficha)\n")
md.append("| Nº | Casa | s (m) | Lado | Largura × fundo (m) | Andares | Altura (m) | Porta (x, y, z) | Visitável | Módulos |")
md.append("|---|---|---|---|---|---|---|---|---|---|")
for h in sorted(d["casas"], key=lambda h: (h["lado"], h["s"])):
    mods = ", ".join("%s×%d" % (k.replace("_1m", ""), v) for k, v in sorted(h["modulos_contagem"].items()))
    md.append("| %s | %s | %.1f | %+d | %.2f × %.2f | %d | %.2f | (%.2f, %.2f, %.2f) | %s | %s |" % (h["numero"] or "-", h["casa"], h["s"], h["lado"], h["largura"], h["fundo"], h["andares"], h["altura"], h["porta_xyz"][0], h["porta_xyz"][1], h["porta_xyz"][2], h["sala"] or "", mods))
md.append("\n## Objetos em cena (resumo por grupo; posições exatas no planta.json)\n")
md.append("| Grupo | Quantidade |")
md.append("|---|---|")
for g, n in sorted(cont.items()):
    md.append("| %s | %d |" % (g, n))
md.append("\n## Conferência dos módulos\n")
if d["problemas"]:
    for p in d["problemas"]:
        md.append("- " + p)
else:
    md.append("Nenhum problema: todos os módulos dentro da parede, nenhum cobrindo janela/porta, nenhum atravessando outro, toda sacada com porta-balcão.")
open("docs/29-planta-do-jogo.md", "w").write("\n".join(md) + "\n")
print("planta ok", W, H)
