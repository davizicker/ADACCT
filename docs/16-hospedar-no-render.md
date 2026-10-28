# Fábrica 3D na nuvem (Render + GitHub)

**Como funciona (leia, é importante):** o Render grátis **não tem placa de vídeo**, então a IA não roda nele. O desenho é este:

| Parte | Onde roda | Custo |
|---|---|---|
| Site, limpeza da malha, esqueleto e animações (Blender/`bpy`) | **Render** (CPU) | grátis (ou US$ 7/mês se faltar memória) |
| IA imagem → 3D (TripoSR) | **GPU grátis do Hugging Face** (Space `stabilityai/TripoSR`) | grátis, com fila e limite diário |
| IA texto → imagem (opcional) | API do Hugging Face (FLUX.1-schnell) | grátis com token, com limite |

## O que foi testado e o que não foi
- ✅ **Testado:** o site em modo nuvem com `gunicorn` (senha, `/healthz`, várias versões por pedido, bloqueio de "enviar ao jogo", limpeza de modelos antigos), limpeza/suavização da malha, mocap com ajuste ao chão.
- ❌ **Não testado (sem acesso à internet aberta aqui):** a chamada real ao Hugging Face, o `docker build` e o deploy no Render. Se algum desses falhar, cole o erro aqui.
- ⚠️ O Space do Hugging Face pode mudar a API ou ficar com fila longa. O código usa `/preprocess` e `/generate` (nomes do Space oficial do TripoSR); se mudarem, ajuste `imagem_para_3d_hf` em `fabrica3d.py` ou aponte `HF_SPACE` para outro Space.

## Passo a passo
1. **Hugging Face:** crie conta grátis → Settings → Access Tokens → "New token" tipo **Read** → copie (`hf_...`). Sem token também funciona com imagem, mas a cota anônima é menor.
2. **GitHub:** o código já está no seu repositório (`davizicker/adacct`, branch `claude/vibrant-cray-k8ki0j`). Faça o merge dessa branch na `main` ou escolha a branch no Render.
3. **Render** (render.com, entre com o GitHub): **New → Blueprint** → escolha o repositório → ele lê o `render.yaml`. Preencha as duas variáveis:
   - `SENHA`: a senha do site (inventada por você; evita estranhos gastarem sua cota);
   - `HF_TOKEN`: o token do passo 1.
4. Espere o build (uns 10 min). Abra a URL `https://fabrica-3d-xxxx.onrender.com`, usuário qualquer, senha = `SENHA`.
5. Envie uma imagem (objeto inteiro, de frente, fundo liso), escolha **2 ou 3 versões**, altura e gere. Baixe o `.glb` e ponha em `assets/models/`.

## Limites do plano grátis do Render
- Dorme após 15 min parado; a primeira visita demora ~1 min para acordar.
- **512 MB de RAM**: modelos pequenos passam; uma malha enorme do TripoSR pode estourar a memória na limpeza (erro "Out of memory"). Se acontecer, mude `plan: free` para `plan: starter` no `render.yaml`.
- O disco é apagado a cada reinício: **baixe o modelo assim que ficar pronto**. O botão "Enviar ao jogo" não existe na nuvem (só no site local).
- Um trabalho por vez (para não estourar a memória).

## Rodar no seu PC sem placa NVIDIA
Dê dois cliques em `iniciar_fabrica3d.bat`: ele instala tudo numa pasta própria e abre o site local já usando a GPU do Hugging Face.

## O que foi feito para reduzir os problemas da IA
| Problema | O que o sistema faz agora | Ainda sobra |
|---|---|---|
| Malha "derretida"/ruidosa | suavização automática (`--suavizar`) antes de reduzir triângulos | detalhes finos (dedos, rosto) continuam ruins |
| Furos e faces viradas | fecha buracos e recalcula normais | furos grandes ficam |
| Pedaços soltos | remove ilhas pequenas | — |
| Resultado ruim por azar | **2 ou 3 versões** por pedido (outro enquadramento/resolução) e você escolhe | custa mais fila |
| Pé flutuando ou afundado na animação | altura do quadril ajustada a cada quadro (pé no chão) | os pés ainda deslizam um pouco (não há IK) |
| Pedir "só mande a imagem" | o Space remove o fundo sozinho | foto bagunçada gera lixo |

Nada disso transforma a IA grátis em modelagem profissional: o resultado é um **bom rascunho** que, para personagens principais e casas, ainda pede um retoque no Blender.
