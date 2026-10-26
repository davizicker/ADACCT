# Gráficos realistas: como chegar no nível da imagem do Bradador

**Resumo honesto em 5 linhas**
1. O que eu construo **por código** (casas, ruas, plantas) tem boa composição e luz, mas é geometria simples. **Não chega ao realismo da sua imagem**, e nunca vai chegar só com código.
2. O realismo da imagem vem de **malhas esculpidas com milhões de detalhes + texturas PBR (fotos reais)**. Isso se faz com IA de imagem → 3D, Blender e texturas de fotos reais.
3. Eu **não gero imagens nem modelos 3D** neste ambiente. O que eu faço: preparar o jogo para receber esses arquivos, integrar, animar, iluminar, otimizar e testar.
4. Os sites de assets estão bloqueados no meu ambiente. **Você gera/baixa; eu integro.**
5. Tudo abaixo é **gratuito**, mas as ferramentas de IA mudam rápido e têm **regras de licença**: confira cada uma antes de vender o jogo.

---

## 1. Análise da imagem do Bradador

| O que a imagem tem | Bom para o jogo? | O que fazer |
|---|---|---|
| Humanoide esquelético, muito alto, braços longos | ✅ Silhueta **legível de longe na névoa** (importante: o jogador não pode olhar para ele) | Manter. Altura de jogo: ~2,7 m |
| Pele de casca de árvore/terra seca com musgo, costelas à mostra | ✅ É exatamente "o corpo que a terra rejeitou" (Corpo-seco) | Manter. Vira o material principal |
| Garras curvas em gancho, dedos longos | ✅ Assusta, mas **complica a animação** | Rigging com ossos extras nos dedos, ou animar só garras simples |
| Boca escancarada gritando, dentes | ✅ É o grito (o nome vem disso) | Boca aberta **fixa** na malha + som; uma animação de mandíbula é opcional |
| Olhos brancos brilhando | ✅ Visíveis na escuridão | Fazer **emissivos** (brilham sozinhos) |
| Cabelo longo e emaranhado | 🟡 Cabelo real em jogo = "cartões" (cards) | Pedir cabelo simplificado ou fazer cards no Blender |
| Pose em T/braços abertos, fundo cinza liso, corpo inteiro | ✅✅ **Perfeita para IA de imagem→3D e para rigging** | Usar essa mesma pose para todos os monstros |
| Iluminação "pintada" na textura | ⚠️ Sombras já aparecem na cor; no jogo a luz é do jogo | Pedir textura **sem sombra** (albedo "deluminado") |
| É uma imagem de **uma só vista** (frente) | ⚠️ A IA vai **inventar** costas e lados | Gerar **frente, lado e costas** (ver prompts) |

**Decisão de design importante:** pela regra do jogo (olhar = perigo), o rosto completo deve aparecer **raramente**. Na maior parte do tempo o jogador vê só a silhueta e os olhos brilhando na névoa. Isso economiza trabalho (o rosto detalhado só importa no clímax) e dá mais medo.

---

## 2. O caminho (pipeline) para modelos 3D de alto nível

```
Imagem conceito  →  Imagem 3 vistas  →  IA imagem→3D  →  Blender (limpar)  →  Texturas PBR  →  Rig + animação  →  Godot
  (você, IA)         (você, IA)          (ferramenta)       (você/eu guio)       (ferramenta)      (Mixamo/Blender)    (eu integro)
```

### Passo A. Conceito em 3 vistas
Gere a **mesma criatura** em frente, lado e costas, mesmo fundo, mesma luz. Vários geradores de imagem aceitam "imagem de referência" para manter o personagem igual. Veja os prompts na seção 4.

### Passo B. Imagem → 3D
Opções **gratuitas** (nomes e termos mudam; **confirme a versão atual e a licença**):
- **Hunyuan3D** e **TRELLIS**: código aberto, rodam no seu computador se você tiver uma placa de vídeo forte, ou em "Spaces" do Hugging Face (de graça, com fila). Geram malha + textura.
- **TripoSR / Stable Fast 3D**: modelos abertos, rápidos, mais simples.
- **Tripo** e **Meshy**: sites com **plano gratuito limitado** (créditos). Costumam dar texturas PBR e opção de rig automático. **Leia os termos de uso comercial do plano gratuito.**
- Prefira o que aceita **várias imagens** (frente/lado/costas): costas e lados saem muito melhores.

**Realidade:** o resultado bruto costuma ter malha "suja" (triângulos demais e mal distribuídos), buracos e costas inventadas. **Sempre precisa de limpeza.**

### Passo C. Limpeza no Blender (grátis, blender.org)
1. Importar o .glb/.obj.
2. **Retopologia**: reduzir para ~25–40 mil triângulos (monstro principal). Modifier *Decimate* serve para começar; *Quad Remesher* é pago (opcional).
3. **Bake** dos detalhes finos (musgo, poros, costelas) da malha pesada para um **Normal Map** na malha leve. É isso que mantém a "cara de realista" com pouco custo.
4. Corrigir UVs (desdobramento), simetria e buracos.
5. Texturas: **Albedo** (cor sem sombra), **Normal**, **Roughness**, **AO**, **Emissivo** (olhos). 2K para o monstro (4K só no close).
6. Exportar **.glb** (glTF 2.0).

> Eu posso guiar cada clique no Blender. Mas o trabalho de retopo/bake é manual e leva horas na primeira vez.

### Passo D. Rig e animação
- **Mixamo** (grátis, conta Adobe): rig automático para humanoides e biblioteca de animações (andar, correr, gritar...). Garras e cabelo **não** serão animados automaticamente.
- Alternativa: **Rigify** no Blender (rig automático, grátis).
- Animações que o Bradador precisa: `idle` (parado, respirando), `scream` (grito), `walk` (andar lento), `run`, `attack`. Para o início, só `idle` já funciona (ele é uma silhueta na névoa).

### Passo E. Colocar no jogo (**já está pronto**)
1. Salve como `assets/models/bradador.glb` (arraste para o Godot).
2. O jogo **detecta sozinho** e troca o modelo simples. Ajustes em `scripts/modelos.gd` (altura, giro, nome da animação).
3. Se aparecer de costas: mude `yaw` de `180.0` para `0.0`.
4. Para a Mula: `assets/models/mula.glb` (o fogo e a luz continuam sendo do jogo).

**Verificado por mim:** com um modelo de teste, o jogo o escalou para a altura pedida (2,70 m), colocou os pés no chão, virou o rosto para o lado certo e escondeu o modelo simples. **Não verificado:** animações reais (não tenho um modelo animado aqui).

---

## 3. Cenário realista: casas, ruas de pedra, atmosfera

O cenário atual é feito de formas simples com texturas geradas por código. Para chegar ao "realista e rústico" da sua referência:

### 3.1 Texturas de fotos reais (o maior salto, grátis)
- **ambientCG** e **Poly Haven** (CC0: uso comercial livre, sem crédito obrigatório). Procure: `cobblestone`, `paving stones`, `plaster wall`, `old plaster`, `stone wall`, `roof tiles`, `wood planks`, `moss`, `dirt`.
- Baixe em **2K** (JPG/PNG). Mapas: `Color`, `NormalGL`, `Roughness`, `AO`, `Displacement`.
- No Godot, abra o material (ex.: `assets/materials/pedra_chao.tres`) e arraste os mapas (explicado em `docs/APRENDER.md`). Em **Heightmap**, ligue o *deep parallax* com o mapa `Displacement`: a pedra ganha **relevo real** sem custar geometria.
- Quixel Megascans (na loja Fab): **confira a licença atual para uso fora da Unreal Engine** antes de usar.

### 3.2 Modelos reais de casas e props
- **Poly Haven (modelos)**: CC0, realistas (barris, caixotes, lampiões, vasos).
- **Sketchfab** (filtro *Downloadable* + licença **CC-BY/CC0**): casarões coloniais, igrejas. **Leia a licença de cada um**; CC-BY exige crédito; "NonCommercial" **não pode** em jogo vendido.
- **Kit modular próprio**: em vez de modelar 100 casas, faça **10 peças** no Blender (parede, porta, janela, beiral, cantaria, sacada) e monte as casas como Lego. Eu posso reaproveitar o gerador atual (`tools/vila_builder.gd`) para montar com **as suas peças** no lugar das caixas.
- **Referências reais** (fotos de Ouro Preto/Mariana) são o seu melhor guia: junto com o prompt, anexe fotos de referência.

### 3.3 Iluminação e atmosfera (grátis, mas precisa de placa com Vulkan)
No Godot: **Projeto → Configurações → Renderização → Renderer → Forward+** (reinicie). O jogo já tem um perfil automático (`scripts/config.gd`, função `_apply_high_end`) que, em **Qualidade Alta**, liga:
- **SDFGI** (iluminação global: a luz dos lampiões "quica" nas paredes),
- **Neblina volumétrica** (raios de luz na neblina),
- **SSR** (reflexos na pedra molhada e na água), **SSAO/SSIL** (sombras de contato), **TAA**.

**Verificado (Godot 4.7.2, Vulkan por software):** o jogo abre e renderiza em Forward+, e o perfil "Qualidade Alta" liga a neblina volumétrica e a iluminação global sem erros (a imagem ganha névoa com luz e cor quicando nas paredes). **Não verificado:** o desempenho numa placa de vídeo real: em Alta o custo sobe bastante (~3 milhões de triângulos contra ~0,9 em Média nos meus testes). Se ficar lento, use Média ou volte para Compatibilidade. O código só liga esses efeitos se o renderizador for Forward+; em Compatibilidade (o padrão) não faz nada.

Ideias a mais (futuras): chuva + poças com reflexo, **decals** (manchas de umidade, musgo, rachaduras sobre as paredes), pedra molhada (roughness baixo), fumaça/vapor saindo da água, fogo de verdade com partículas melhores.

### 3.4 Orçamento de desempenho (para não travar)
| Tipo | Limite sugerido |
|---|---|
| Monstro principal (no jogo) | 25–40 mil triângulos, 1 material, texturas 2K |
| Mula | 15–25 mil triângulos |
| Peça modular (parede, janela) | 200–2.000 triângulos |
| Prop (barril, banco) | 300–3.000 triângulos |
| Casa completa visível | até ~15 mil triângulos |
| Texturas | 2K na rua e nas casas próximas; 1K nas distantes |

---

## 4. Pacote de prompts (copie e cole)

> Dicas: escreva em **inglês** (a maioria das ferramentas responde melhor). Use **sempre a mesma pose, o mesmo fundo e a mesma luz** para a IA manter o personagem. Se o gerador aceitar imagem de referência, anexe a sua imagem do Bradador.

### 4.1 Bradador: 3 vistas (referência para imagem→3D)
```
Character turnaround sheet of the same creature: front view, side view, and back view, A-pose / T-pose, full body, 
same proportions in all views, plain neutral gray background, flat even studio lighting, no shadows, no cast shadows on the ground.
A tall emaciated wandering undead from Brazilian folklore ("Bradador"), 2.7 meters tall, long thin limbs, 
skin like dried bark and mummified earth, patches of moss and lichen, exposed ribcage, long matted black hair, 
wide open screaming mouth with sharp teeth, glowing white eyes, long hooked black claws, bare taloned feet.
Hyper-realistic, photorealistic dark fantasy horror, physically based materials, highly detailed skin texture, 
8k, sharp focus.
Negative: cartoon, anime, text, watermark, extra limbs, extra fingers, blurry, dramatic lighting, colored background.
```

### 4.2 Bradador: textura "sem sombra" (albedo)
```
Seamless albedo texture of dried mummified bark-like skin with green moss and lichen patches, dark brown and ochre, 
flat lighting, no shadows, no highlights, no ambient occlusion baked in, top-down, 2048x2048, photorealistic, tileable.
```

### 4.3 Corpo-seco (variante para o futuro monstro que persegue)
```
Character turnaround sheet (front, side, back), full body, T-pose, neutral gray background, flat lighting, no shadows.
A mummified corpse rejected by the earth, "Corpo-seco" from Brazilian folklore: dry cracked leathery skin stretched over bones, 
roots and soil growing through the body, hollow eyes, slow and hunched, torn colonial-era clothing rotted by time (shirt and trousers, 18th century Minas Gerais), 
dirt and clay caked on the skin. Photorealistic dark horror, physically based materials, highly detailed, 8k.
Negative: cartoon, text, watermark, armor, weapons, bright colors.
```

### 4.4 Mula-sem-cabeça
```
Three views (front, side, back) of a headless mule, full body, plain neutral gray background, flat lighting, no shadows.
Black coat, muscular, dusty hooves with iron horseshoes, the neck ends in a charred stump with a column of orange fire, 
leather harness torn and burnt, ember glow. Photorealistic dark folklore horror, 8k, sharp focus, physically based materials.
Negative: cartoon, rider, saddle with person, text, watermark, extra heads.
```

### 4.5 Textura: pedra da rua (colonial)
```
Seamless tileable photorealistic texture of irregular polygonal natural stone paving (quartzite), colonial Brazilian hillside street, 
worn smooth by centuries, dark gaps with soil and tiny moss, subtle wet sheen, top-down orthographic, flat lighting, 2048x2048.
```
Peça separadamente os mapas `normal`, `roughness` e `height` se o gerador permitir; senão, gere esses mapas a partir do albedo em ferramentas gratuitas (por exemplo, no próprio Blender ou em sites de "PBR map generator").

### 4.6 Textura: parede de casarão antigo
```
Seamless tileable photorealistic texture of aged whitewashed lime plaster wall, peeling in places revealing earth (taipa) and stone underneath, 
water stains, fine cracks, warm off-white, top-down, flat even lighting, 2048x2048, no shadows.
```

### 4.7 Fachada colonial (referência para eu e para o Blender)
```
Front elevation, orthographic view, no perspective, of a two-storey Brazilian colonial townhouse (sobrado) in Ouro Preto style: 
whitewashed facade, arched wooden windows with stone frames, wrought iron balcony, carved stone doorway, deep eaves with wooden brackets, 
curved clay roof tiles (capa-e-canal), stone base. Photorealistic, flat lighting, neutral background, high detail.
```

### 4.8 Props (use para cada item da lista)
```
Single isolated game asset, [barrel / wooden bench / hand cart / iron street lantern / clay pot with plants], 18th century colonial Brazil, 
weathered, realistic, centered, plain gray background, flat lighting, 3/4 front view, high detail, PBR-ready.
```

### 4.9 Para a ferramenta de imagem → 3D (configuração)
- Entrada: imagem **limpa**, 1 só objeto, fundo liso, sem sombras no chão.
- Peça **PBR** e **malha de quads** se a opção existir; **resolução de textura 2K**.
- Se aceitar **múltiplas vistas**: envie frente + lado + costas.
- Exporte **GLB**. Depois do Blender, o arquivo final vai para `assets/models/`.

---

## 5. O que fazer, na ordem (simples)

1. **Baixe e teste o jogo** (se ainda não fez) e me diga o desempenho. Sem isso, não sei quanto detalhe aguenta.
2. **Texturas reais**: baixe de ambientCG/Poly Haven 6 conjuntos (pedra da rua, reboco, telha, madeira, pedra de muro, terra). Arraste para `assets/textures/`. **Me avise** e eu ligo tudo nos materiais.
3. **Bradador**: gere as 3 vistas (prompt 4.1) → imagem→3D → Blender → `assets/models/bradador.glb`. Comece só com o `idle` (parado).
4. **Mula**: mesma coisa, depois do Bradador.
5. **Props**: peça 10–15 do Poly Haven (barril, caixote, banco, lampião, vaso).
6. **Casas**: as 10 peças modulares (ou use um pacote de casas coloniais com licença livre). Aí eu reconstruo a rua com as suas peças.
7. **Forward+** no seu computador (se a placa de vídeo aguentar) e teste "Qualidade: Alta".

## 6. Quanto tempo leva (estimativa realista para iniciante)
| Tarefa | Primeira vez |
|---|---|
| Texturas CC0 nos materiais | 1–2 horas |
| Bradador: imagens + IA→3D + limpeza básica | 1–3 dias |
| Bradador: retopo + bake + rig + animações boas | 1–2 semanas |
| 10 peças modulares de casa no Blender | 1–2 semanas |
| Rua inteira com realismo "de lançamento" | **meses** |

Ou seja: dá para ter um **bom vertical slice realista em semanas**, mas "nível de jogo AAA" em tudo é **meses de trabalho** (ou uma equipe/artista 3D).

## 7. Licenças e ética (importante antes de vender)
- **IA de imagem/3D:** cada ferramenta tem regras sobre **uso comercial** e sobre quem é dono do resultado. Confira a da que você usou para o Bradador (a imagem que você mandou). Guarde prints dos termos.
- **Assets de terceiros:** registre **tudo** em `assets/CREDITOS.md` (nome, autor, link, licença).
- **Respeito cultural:** o monstro é o **castigo de quem fez o mal** (capataz), não as vítimas da escravidão. Mantenha isso em toda arte (inclusive em roupas e símbolos). Considere consultoria cultural (ver docs/05).
