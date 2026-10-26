"""Monta folhas de contato 2x2 (1280x720) a partir das fotos. Uso: python3 -I contact.py <pasta> <prefixo> <saida_prefixo>"""
import sys, glob, os
from PIL import Image, ImageDraw
folder, prefix, out = sys.argv[1], sys.argv[2], sys.argv[3]
files = sorted(glob.glob(os.path.join(folder, prefix + "*.png")))
W, H = 640, 360
for k in range(0, len(files), 4):
    sheet = Image.new("RGB", (W * 2, H * 2), (20, 20, 20))
    for j, f in enumerate(files[k:k + 4]):
        im = Image.open(f).convert("RGB").resize((W, H), Image.LANCZOS)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, 250, 16], fill=(0, 0, 0))
        d.text((4, 2), os.path.basename(f)[:-4], fill=(255, 255, 0))
        sheet.paste(im, ((j % 2) * W, (j // 2) * H))
    sheet.save("%s_%02d.png" % (out, k // 4))
print(len(files), "fotos ->", (len(files) + 3) // 4, "folhas")
