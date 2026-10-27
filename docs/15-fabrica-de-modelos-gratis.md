# Como fazer modelos 3D de graça com um prompt (o melhor caminho possível hoje)

**Verdade primeiro:** não existe ferramenta 100% grátis que receba um texto e entregue um modelo **completo** (malha limpa + textura PBR + esqueleto + animação) pronto para o jogo. Existe uma **linha de montagem** grátis em 4 etapas; a IA faz a forma, e a limpeza e a animação são etapas separadas (eu automatizo a limpeza).

## A linha de montagem
| Etapa | Ferramenta grátis | O que sai |
|---|---|---|
| 1. Prompt → imagem | gerador de imagens grátis (Stable Diffusion/FLUX local pelo ComfyUI, ou os planos grátis online: Bing Image Creator, Leonardo, Google AI Studio; confira limites e licença) | Imagem do objeto, de frente, fundo liso |
| 2. Imagem → 3D | **TripoSR** local (MIT, 6 GB) ou **Hunyuan3D-2** (local, ou demo grátis no Hugging Face Spaces, com fila) | Malha com textura (rascunho) |
| 3. Limpeza | `tools/ia3d/pos_processar.py` (eu fiz, testado) + Blender | .glb enxuto, no chão, na escala certa |
| 4. Rig e animação (só personagens) | **Mixamo** (grátis, conta Adobe) | Bradador/Mula andando, correndo, gritando |
| 5. Jogo | me mandar o .glb ou colocar em `assets/models/` | Entra no jogo; eu integro e testo |

## "Um prompt só": ComfyUI
O **ComfyUI** (grátis, roda no PC) permite montar texto → imagem → 3D num só fluxo, com nós da comunidade para TripoSR e Hunyuan3D-2. É o mais perto de "digito e recebo". Exige instalar e baixar modelos grandes (dezenas de GB); com 6 GB de VRAM vai devagar. Procure "ComfyUI Hunyuan3D" ou "ComfyUI TripoSR".

## Alternativas online (grátis com limite)
- Hugging Face Spaces de TripoSR / Hunyuan3D-2 / TRELLIS: sem pagar, com fila e limites; o download costuma ser liberado.
- Meshy/Tripo: créditos grátis limitados; baixar formatos úteis costuma ser pago (como você viu).
Verifique sempre a licença: para jogo comercial, algumas exigem pagamento ou proíbem território/uso.

## O que funciona bem e o que não
- **Bom:** objetos soltos (barril, estátua, móveis), criaturas e vultos (Bradador, Mula) como base.
- **Ruim:** casas e igrejas inteiras (detalhes retos), peças que precisam de medida exata, rostos e mãos.
- Sempre conte com **limpar e às vezes refazer** a textura.

## Meu papel nesse fluxo
Você gera → me manda o arquivo → eu rodo a limpeza, encaixo no jogo, ajusto escala/materiais/colisão, testo e entrego o zip. Se algum passo der erro no seu PC, cole a mensagem aqui.
