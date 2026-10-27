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
