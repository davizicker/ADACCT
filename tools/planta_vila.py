import json,sys
from PIL import Image, ImageDraw, ImageFont
d=json.load(open(sys.argv[1]))
S=7.0; ox=40; oz=180
W=int(140*S); H=int(200*S)
im=Image.new("RGB",(W,H),(235,230,215)); dr=ImageDraw.Draw(im)
def P(x,z): return ((x+ox)*S,(z+oz)*S)
cores={"rua":(150,150,150),"curva":(170,170,170),"casa":(200,120,90),"visitavel":(230,170,40),"beco":(80,120,200),"cego":(120,80,190),"quintal":(120,170,90),"largo":(200,200,140)}
for c in d["cadastro"]:
    x,z,w,h=c["x"],c["z"],c["w"],c["h"]
    a=P(x,z); b=P(x+w,z+h)
    dr.rectangle([a,b],fill=cores.get(c["tipo"],(255,0,255)),outline=(40,40,40))
    if c["tipo"] in ("visitavel","beco","cego"):
        dr.text((a[0]+2,a[1]+2),c["id"].replace("visita_",""),fill=(0,0,0))
pts=[P(p[0],p[1]) for p in d["eixo"]]
dr.line(pts,fill=(255,255,255),width=2)
dr.text((10,10),"Planta do plano (cinza=rua, laranja=casas, amarelo=visitaveis, azul=becos-escada, roxo=becos sem saida). Sobreposicoes: %d"%d["sobreposicoes"],fill=(0,0,0))
im.save(sys.argv[2])
