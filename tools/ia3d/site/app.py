#!/usr/bin/env python3
"""Seu "Meshy" pessoal: site local para gerar modelos 3D a partir de texto ou imagem, ver no navegador, baixar
e mandar para o jogo. Usa tools/ia3d/fabrica3d.py por baixo.

  pip install flask
  python tools/ia3d/site/app.py            # abre http://127.0.0.1:5000
  python tools/ia3d/site/app.py --demo arquivo.glb   # MODO DEMONSTRAÇÃO (sem IA): usa esse .glb como resultado

O site só escuta no seu computador (127.0.0.1). A prévia 3D usa o componente <model-viewer> do Google, carregado de um CDN
(precisa de internet só para a prévia)."""
import argparse, json, os, re, shutil, subprocess, sys, threading, time, uuid
from flask import Flask, request, jsonify, send_from_directory, render_template_string, abort

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", "..", ".."))
FAB = os.path.join(AQUI, "..", "fabrica3d.py")
SAIDA = os.path.join(RAIZ, "tools", "ia3d", "saida")
DEST_JOGO = os.path.join(RAIZ, "assets", "models", "gerados")
os.makedirs(SAIDA, exist_ok=True)

app = Flask(__name__)
JOBS = {}
DEMO = {"glb": ""}
LOCK = threading.Lock()


def nome_seguro(s):
    s = re.sub(r"[^a-zA-Z0-9_-]+", "_", s.strip().lower())[:40].strip("_")
    return s or "modelo"


def rodar_job(jid, args, nome):
    job = JOBS[jid]
    job["estado"] = "rodando"
    destino = os.path.join(SAIDA, nome + ".glb")
    cmd = [sys.executable, FAB] + args + ["--nome", nome, "--destino", destino]
    if DEMO["glb"]:
        cmd += ["--simular", DEMO["glb"]]
    job["log"] += "$ " + " ".join(cmd) + "\n"
    try:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for linha in p.stdout:
            job["log"] += linha
        p.wait()
        if p.returncode == 0 and os.path.exists(destino):
            job["estado"] = "pronto"
            job["modelo"] = nome
        else:
            job["estado"] = "erro"
    except Exception as e:
        job["log"] += "ERRO: %s\n" % e
        job["estado"] = "erro"


@app.post("/api/gerar")
def gerar():
    prompt = request.form.get("prompt", "").strip()
    nome = nome_seguro(request.form.get("nome") or prompt)
    altura = request.form.get("altura", "0") or "0"
    tris = request.form.get("tris", "30000") or "30000"
    args = ["--altura", str(float(altura)), "--tris", str(int(tris))]
    arq = request.files.get("imagem")
    if arq and arq.filename:
        pasta = os.path.join(SAIDA, nome)
        os.makedirs(pasta, exist_ok=True)
        caminho = os.path.join(pasta, "enviada.png")
        arq.save(caminho)
        args += ["--imagem", caminho]
    elif prompt:
        args = [prompt] + args
    elif not DEMO["glb"]:
        return jsonify(erro="Escreva um prompt ou envie uma imagem"), 400
    jid = uuid.uuid4().hex[:8]
    JOBS[jid] = {"estado": "fila", "log": "", "modelo": "", "nome": nome, "inicio": time.time()}
    threading.Thread(target=rodar_job, args=(jid, args, nome), daemon=True).start()
    return jsonify(id=jid)


@app.get("/api/job/<jid>")
def job(jid):
    j = JOBS.get(jid)
    if not j:
        abort(404)
    return jsonify(estado=j["estado"], log=j["log"][-4000:], modelo=j["modelo"])


@app.get("/api/modelos")
def modelos():
    itens = []
    for f in sorted(os.listdir(SAIDA), key=lambda x: -os.path.getmtime(os.path.join(SAIDA, x)) if os.path.exists(os.path.join(SAIDA, x)) else 0):
        if f.endswith(".glb"):
            n = f[:-4]
            itens.append({"nome": n, "kb": os.path.getsize(os.path.join(SAIDA, f)) // 1024, "no_jogo": os.path.exists(os.path.join(DEST_JOGO, f))})
    return jsonify(itens)


@app.get("/modelos/<nome>.glb")
def baixar(nome):
    return send_from_directory(SAIDA, nome_seguro(nome) + ".glb", as_attachment=request.args.get("baixar") == "1")


@app.post("/api/enviar/<nome>")
def enviar(nome):
    n = nome_seguro(nome)
    src = os.path.join(SAIDA, n + ".glb")
    if not os.path.exists(src):
        abort(404)
    os.makedirs(DEST_JOGO, exist_ok=True)
    shutil.copy(src, os.path.join(DEST_JOGO, n + ".glb"))
    return jsonify(ok=True, destino="assets/models/gerados/%s.glb" % n)


@app.delete("/api/modelos/<nome>")
def apagar(nome):
    n = nome_seguro(nome)
    p = os.path.join(SAIDA, n + ".glb")
    if os.path.exists(p):
        os.remove(p)
    return jsonify(ok=True)


@app.get("/")
def index():
    return render_template_string(PAGINA, demo=bool(DEMO["glb"]))


PAGINA = r"""<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Fábrica 3D</title>
<script type="module" src="https://unpkg.com/@google/model-viewer@3.5.0/dist/model-viewer.min.js"></script>
<style>
:root{--bg:#0e0f14;--card:#171923;--bd:#2a2e3d;--tx:#e8e6df;--mu:#9aa0b4;--ac:#e3a94a}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--tx);font:16px/1.5 system-ui,sans-serif}
header{padding:20px 24px;border-bottom:1px solid var(--bd)}h1{margin:0;font-size:22px}h1 span{color:var(--ac)}
main{display:grid;grid-template-columns:minmax(300px,380px) 1fr;gap:20px;padding:20px 24px;max-width:1300px;margin:auto}
@media(max-width:800px){main{grid-template-columns:1fr}}
.card{background:var(--card);border:1px solid var(--bd);border-radius:10px;padding:16px}
label{display:block;font-size:13px;color:var(--mu);margin:12px 0 4px}
textarea,input{width:100%;background:#0e0f14;color:var(--tx);border:1px solid var(--bd);border-radius:6px;padding:9px;font:inherit}
textarea{min-height:96px;resize:vertical}.row{display:flex;gap:10px}.row>div{flex:1}
button{background:var(--ac);color:#1b1408;border:0;border-radius:6px;padding:10px 14px;font:600 15px system-ui;cursor:pointer}
button.sec{background:#262a3a;color:var(--tx)}button:disabled{opacity:.5}
#log{white-space:pre-wrap;font:12px ui-monospace,monospace;background:#0b0c11;border-radius:6px;padding:8px;max-height:200px;overflow:auto;margin-top:10px;color:var(--mu)}
.grade{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:14px}
model-viewer{width:100%;height:220px;background:#0b0c11;border-radius:8px;--poster-color:transparent}
.nome{font-weight:600;margin:8px 0 2px}.pq{font-size:12px;color:var(--mu)}.acoes{display:flex;gap:6px;margin-top:8px;flex-wrap:wrap}
.acoes button,.acoes a{font-size:13px;padding:6px 9px}.acoes a{background:#262a3a;color:var(--tx);border-radius:6px;text-decoration:none}
.aviso{background:#2a2112;border:1px solid #5a4620;color:#e8c987;padding:8px 10px;border-radius:6px;font-size:13px;margin-bottom:10px}
</style></head><body>
<header><h1>Fábrica <span>3D</span></h1><div class="pq">Prompt ou imagem → modelo 3D pronto para o jogo. Tudo no seu computador.</div></header>
<main>
<section class="card">
 {% if demo %}<div class="aviso">MODO DEMONSTRAÇÃO: nenhuma IA roda; o resultado é sempre o arquivo de exemplo.</div>{% endif %}
 <form id="f">
  <label>Descreva o objeto</label>
  <textarea name="prompt" placeholder="ex.: barril de madeira velho com aros de ferro enferrujados"></textarea>
  <label>…ou envie uma imagem (fundo liso funciona melhor)</label>
  <input type="file" name="imagem" accept="image/*">
  <label>Nome do arquivo</label><input name="nome" placeholder="barril">
  <div class="row"><div><label>Altura (m)</label><input name="altura" type="number" step="0.01" value="1"></div>
  <div><label>Triângulos</label><input name="tris" type="number" step="1000" value="30000"></div></div>
  <div style="margin-top:14px"><button id="b" type="submit">Gerar modelo</button></div>
 </form>
 <div id="log" hidden></div>
</section>
<section><div class="grade" id="g"></div><p class="pq" id="vazio">Nenhum modelo ainda.</p></section>
</main>
<script>
const g=document.getElementById('g'),vz=document.getElementById('vazio'),log=document.getElementById('log'),b=document.getElementById('b');
async function lista(){const r=await fetch('/api/modelos');const m=await r.json();vz.hidden=m.length>0;g.innerHTML=m.map(x=>`
<div class="card"><model-viewer src="/modelos/${x.nome}.glb" camera-controls auto-rotate shadow-intensity="1" exposure="1"></model-viewer>
<div class="nome">${x.nome}</div><div class="pq">${x.kb} KB ${x.no_jogo?'· no jogo':''}</div>
<div class="acoes"><a href="/modelos/${x.nome}.glb?baixar=1">Baixar</a><button class="sec" onclick="enviar('${x.nome}')">Enviar ao jogo</button><button class="sec" onclick="apagar('${x.nome}')">Apagar</button></div></div>`).join('')}
async function enviar(n){const r=await fetch('/api/enviar/'+n,{method:'POST'});const j=await r.json();alert('Copiado para '+j.destino);lista()}
async function apagar(n){if(confirm('Apagar '+n+'?')){await fetch('/api/modelos/'+n,{method:'DELETE'});lista()}}
document.getElementById('f').onsubmit=async e=>{e.preventDefault();b.disabled=true;log.hidden=false;log.textContent='Enviando…';
 const r=await fetch('/api/gerar',{method:'POST',body:new FormData(e.target)});const j=await r.json();
 if(!r.ok){log.textContent=j.erro;b.disabled=false;return}
 const t=setInterval(async()=>{const s=await (await fetch('/api/job/'+j.id)).json();log.textContent='['+s.estado+']\n'+s.log;log.scrollTop=log.scrollHeight;
  if(s.estado==='pronto'||s.estado==='erro'){clearInterval(t);b.disabled=false;lista()}},1500)};
lista();
</script></body></html>"""

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--demo", help="MODO DEMONSTRAÇÃO: usa este .glb como resultado, sem IA")
    ap.add_argument("--porta", type=int, default=5000)
    a = ap.parse_args()
    if a.demo:
        DEMO["glb"] = os.path.abspath(a.demo)
    print("Abra http://127.0.0.1:%d" % a.porta)
    app.run(host="127.0.0.1", port=a.porta, debug=False)
