# Gerar modelos 3D no seu PC, de graça (como o Meshy)

**Aviso honesto:** estes scripts eu **não consegui testar** (este ambiente não tem placa de vídeo NVIDIA). Os comandos vêm do README oficial de cada projeto; se der erro, cole a mensagem aqui que eu corrijo.
Vai precisar de: Windows com **placa NVIDIA** (sua RTX 2060 de 6 GB serve para o TripoSR), Python 3.10 e Git. Tudo é grátis e roda **sem internet** depois de baixar.

## Opção 1 (recomendada para sua placa): TripoSR (licença MIT, ~6 GB de VRAM)
Gera um modelo 3D a partir de **uma imagem** (sua arte do Bradador) em segundos. A qualidade é de rascunho bom: precisa de limpeza.
```
git clone https://github.com/VAST-AI-Research/TripoSR
cd TripoSR
python -m venv venv
venv\\Scripts\\activate
# instale o PyTorch com CUDA pelo comando do site pytorch.org (escolha Windows, Pip, sua versão de CUDA)
pip install --upgrade setuptools
pip install -r requirements.txt
python run.py minha_imagem.png --output-dir saida --bake-texture --texture-resolution 2048
```
Resultado em `saida/0/` (malha com textura). Dicas: use imagem com **fundo liso ou removido**, objeto inteiro, de frente, boa luz.
Se der erro com `torchmcubes`: `pip uninstall torchmcubes` e `pip install git+https://github.com/tatsy/torchmcubes.git`.

## Opção 2 (mais detalhe, exige mais): Hunyuan3D-2
Só a **forma** usa ~6 GB de VRAM (serve na sua placa, devagar); forma **+ textura** pede ~16 GB (não cabe na 2060). Veja a licença do projeto antes de usar em jogo comercial.
```
git clone https://github.com/Tencent-Hunyuan/Hunyuan3D-2
cd Hunyuan3D-2
pip install -r requirements.txt
pip install -e .
```
Gerar só a forma (Python):
```python
from hy3dgen.shapegen import Hunyuan3DDiTFlowMatchingPipeline
pipe = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained('tencent/Hunyuan3D-2')
mesh = pipe(image='minha_imagem.png')[0]
mesh.export('bradador_forma.glb')
```
A textura você pinta/gera depois (Blender, ou a versão online do Hunyuan3D).

## Depois de gerar (limpeza)
1. Abra o .glb/.obj no **Blender** (grátis). Apague pedaços soltos, feche buracos, simplifique (Modifier > Decimate até ~30 mil triângulos).
2. Para o Bradador e a Mula, suba no **Mixamo** (grátis) para rigging e animações (andar, correr, gritar). Baixe em .fbx/.glb.
3. Exporte em **.glb** e me mande aqui, ou coloque em `assets/models/bradador.glb` / `mula.glb`: o jogo troca sozinho (`scripts/modelos.gd`).

## Limites que você precisa saber
- Esses geradores erram **mãos, rosto e costas** e deixam a malha "derretida". É normal: limpe no Blender ou gere vários e escolha o melhor.
- Para **casas e igrejas** funciona pior (muitos detalhes retos). Casas continuam melhores vindo de modelos prontos (Fab/Sketchfab/Poly Haven).
- Respeite a licença de cada projeto para uso comercial.

## Limpeza automática (testada)
`tools/ia3d/pos_processar.py` faz a limpeza sozinho: junta malhas, remove pedaços soltos, reduz triângulos, põe os pés no chão, escala para a altura e exporta .glb. **Testei com um modelo do Poly Haven** (7.480 → 3.999 triângulos).
```
pip install bpy
python tools/ia3d/pos_processar.py saida/0/mesh.obj bradador.glb --tris 30000 --altura 2.7
```
Para modelos já limpos (como os do Poly Haven) use `--solto 0` para não remover peças pequenas de propósito.

## Fábrica 3D (um comando)
`tools/ia3d/fabrica3d.py` junta tudo: prompt → imagem → remover fundo → TripoSR → limpeza → .glb no projeto.
1. Copie `fabrica3d.exemplo.json` para `fabrica3d.json` e ajuste os caminhos.
2. `python tools/ia3d/fabrica3d.py "estátua gótica de pedra" --nome estatua --altura 1.7`
3. Ou com sua imagem: `python tools/ia3d/fabrica3d.py --imagem bradador.png --nome bradador --altura 2.7 --destino assets/models/bradador.glb`
**Testado:** a etapa de limpeza e a orquestração (`--simular arquivo.glb`). **Não testado:** texto→imagem, remover fundo e TripoSR (sem GPU aqui).

## Site pessoal (tipo Meshy)
```
pip install flask
python tools/ia3d/site/app.py            # depois abra http://127.0.0.1:5000
python tools/ia3d/site/app.py --demo assets/models/poly/GothicCabinet_01.glb   # teste sem IA
```
Tem campo de prompt, envio de imagem, nome/altura/triângulos, andamento ao vivo, galeria com prévia 3D girando, botão **Baixar** e **Enviar ao jogo** (copia para `assets/models/gerados/`).
**Testado:** o site e o fluxo completo em modo demonstração (gerar, acompanhar, listar, baixar, enviar). **Não testado:** a IA de verdade (precisa do TripoSR instalado e GPU). A prévia 3D usa um componente do Google carregado da internet.

## Rig e animação automáticos (o que o Mixamo faz)
`tools/ia3d/animar.py` cria o **esqueleto** pelas proporções do modelo, liga a malha com **pesos automáticos** e gera **animações em laço** por código:
- humanoide: `idle`, `walk`, `run`, `scream` (o grito do Bradador);
- quadrúpede: `idle`, `walk`, `gallop` (a Mula).
```
python tools/ia3d/animar.py modelo.glb modelo_animado.glb --tipo humanoide
python tools/ia3d/animar.py mula.glb mula_animada.glb --tipo quadrupede --anims idle,gallop
```
No site, cada modelo tem o botão **Rigar e animar**; a prévia mostra os botões das animações.
**Testado** com um humanoide e um quadrúpede de teste (esqueleto, pesos e animações exportados e tocando no Godot; arquivos de teste via `gerar_teste.py` e `tools/preview_anim.gd`).
**Limites:** supõe humanoide em pose T/A de pé ou quadrúpede de lado; pesos automáticos falham em malhas muito sujas; as animações são simples e cíclicas, não são captura de movimento. A biblioteca de milhares de animações do Mixamo não dá para replicar; o próximo passo é importar animações gratuitas (CMU Mocap, Quaternius CC0) e retargetar para o esqueleto.
