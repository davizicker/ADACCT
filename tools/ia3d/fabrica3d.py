#!/usr/bin/env python3
"""FÁBRICA 3D: do prompt (ou imagem) até um .glb pronto para o jogo, tudo local e grátis.

  python tools/ia3d/fabrica3d.py "barril de madeira velho com aros de ferro" --nome barril --altura 0.9
  python tools/ia3d/fabrica3d.py --imagem bradador.png --nome bradador --altura 2.7 --tris 30000 --destino assets/models/bradador.glb

Etapas:  1) texto -> imagem (diffusers, opcional)   2) remover fundo (rembg)   3) imagem -> 3D (TripoSR)
         4) limpeza (pos_processar.py com bpy)       5) copiar para o projeto
Cada etapa roda separada e imprime o que falta se algo não estiver instalado. Configure caminhos em fabrica3d.json
(copie fabrica3d.exemplo.json). AVISO: as etapas 1 a 3 NÃO foram testadas (o ambiente de desenvolvimento não tem GPU NVIDIA);
a etapa 4 e o modo --simular foram testados."""
import argparse, json, os, shutil, subprocess, sys, glob

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
TEMPLATE = "{p}, single object, centered, full view, front view, plain white background, soft studio lighting, highly detailed, no shadow, no text"


def carregar_config():
    cfg = {"triposr_dir": "", "python_triposr": sys.executable, "python_bpy": sys.executable,
           "modelo_texto2img": "stabilityai/stable-diffusion-xl-base-1.0", "pasta_saida": os.path.join(RAIZ, "tools", "ia3d", "saida")}
    p = os.path.join(AQUI, "fabrica3d.json")
    if os.path.exists(p):
        cfg.update(json.load(open(p, encoding="utf-8")))
    return cfg


def passo(n, txt):
    print("\n[%d] %s" % (n, txt), flush=True)


def texto_para_imagem(prompt, cfg, saida):
    try:
        import torch
        from diffusers import AutoPipelineForText2Image
    except ImportError:
        sys.exit("Falta: pip install torch diffusers transformers accelerate  (PyTorch com CUDA: veja pytorch.org)\n"
                 "Ou gere a imagem em outro lugar e use --imagem arquivo.png")
    pipe = AutoPipelineForText2Image.from_pretrained(cfg["modelo_texto2img"], torch_dtype=torch.float16, variant="fp16")
    pipe.enable_model_cpu_offload()            # cabe em placas de 6 GB, mais devagar
    img = pipe(TEMPLATE.format(p=prompt), num_inference_steps=30, guidance_scale=6.5).images[0]
    img.save(saida)
    return saida


def remover_fundo(entrada, saida):
    try:
        from rembg import remove
        from PIL import Image
    except ImportError:
        print("  (rembg não instalado: pip install rembg pillow; seguindo sem remover o fundo)")
        shutil.copy(entrada, saida)
        return saida
    Image.open(entrada).convert("RGBA")
    remove(Image.open(entrada)).save(saida)
    return saida


def imagem_para_3d(imagem, cfg, pasta):
    d = cfg["triposr_dir"]
    if not d or not os.path.exists(os.path.join(d, "run.py")):
        sys.exit("Defina \"triposr_dir\" em tools/ia3d/fabrica3d.json (pasta do TripoSR com o run.py). Veja LEIA-ME.md")
    cmd = [cfg["python_triposr"], "run.py", os.path.abspath(imagem), "--output-dir", os.path.abspath(pasta), "--bake-texture", "--texture-resolution", "2048"]
    print("  " + " ".join(cmd))
    subprocess.run(cmd, cwd=d, check=True)
    achados = sorted(glob.glob(os.path.join(pasta, "**", "*.obj"), recursive=True) + glob.glob(os.path.join(pasta, "**", "*.glb"), recursive=True))
    if not achados:
        sys.exit("O TripoSR não gerou arquivo em " + pasta)
    return achados[0]


def limpar(malha, destino_glb, tris, altura, solto, cfg):
    cmd = [cfg["python_bpy"], os.path.join(AQUI, "pos_processar.py"), malha, destino_glb, "--tris", str(tris), "--altura", str(altura), "--solto", str(solto)]
    print("  " + " ".join(cmd))
    subprocess.run(cmd, check=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("prompt", nargs="?", default="")
    ap.add_argument("--imagem", help="usa esta imagem em vez de gerar uma")
    ap.add_argument("--nome", default="modelo")
    ap.add_argument("--altura", type=float, default=0.0, help="altura final em metros")
    ap.add_argument("--tris", type=int, default=30000)
    ap.add_argument("--solto", type=float, default=0.02)
    ap.add_argument("--destino", help="onde salvar o .glb final (padrão: assets/models/gerados/<nome>.glb)")
    ap.add_argument("--simular", help="TESTE: usa este .glb/.obj como se fosse a saída da IA (pula as etapas 1 a 3)")
    a = ap.parse_args()
    cfg = carregar_config()
    pasta = os.path.join(cfg["pasta_saida"], a.nome)
    os.makedirs(pasta, exist_ok=True)
    destino = a.destino or os.path.join(RAIZ, "assets", "models", "gerados", a.nome + ".glb")
    os.makedirs(os.path.dirname(destino), exist_ok=True)

    if a.simular:
        passo(1, "SIMULAÇÃO: pulando texto/imagem/3D, usando " + a.simular)
        malha = a.simular
    else:
        if a.imagem:
            img = a.imagem
        else:
            if not a.prompt:
                sys.exit("Dê um prompt ou --imagem")
            passo(1, "texto -> imagem")
            img = texto_para_imagem(a.prompt, cfg, os.path.join(pasta, "imagem.png"))
        passo(2, "remover fundo")
        img = remover_fundo(img, os.path.join(pasta, "imagem_sem_fundo.png"))
        passo(3, "imagem -> 3D (TripoSR)")
        malha = imagem_para_3d(img, cfg, os.path.join(pasta, "bruto"))
    passo(4, "limpeza e otimização")
    limpar(malha, destino, a.tris, a.altura, a.solto, cfg)
    passo(5, "pronto")
    print("  Modelo: " + destino)
    print("  Abra o Godot (ele importa sozinho) ou me mande o arquivo para eu encaixar no jogo.")


if __name__ == "__main__":
    main()
