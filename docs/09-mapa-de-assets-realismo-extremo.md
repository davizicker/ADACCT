# Mapa: o que falta para o BRADADOR ficar extremamente realista (1961, vila mineira)

Franqueza primeiro: o que ainda parece "amador" não é detalhe de luz ou textura. É que **as casas, a igreja, o Bradador e a Mula
são formas feitas por código** (caixas, prismas, tubos). Código não esculpe como um artista 3D. O que dá o salto de verdade é
**trazer modelos 3D prontos** (e deixar que eu integre, otimize e teste, como fiz com os 16 do Poly Haven).
Tudo abaixo é grátis, salvo indicação. Eu **não verifiquei a disponibilidade atual** de cada site: confira a licença na página antes de baixar (preciso de CC0 ou CC-BY; CC-BY eu credito).

Como me entregar: mesmo jeito de antes (.blend ou .glb/.fbx em zip). Eu converto, reduzo triângulos, ajusto escala/posição e testo.

---

## P1: o que mais muda a aparência (peça primeiro)

| # | O que | Por que importa | Onde procurar (grátis) | Termos de busca |
|---|---|---|---|---|
| 1 | **Bradador 3D** (o da sua imagem) | Hoje é um boneco procedural. Você quer a aparência da sua arte | Gerar a partir da sua imagem com IA image-to-3D (planos grátis: Tripo, Meshy, Hunyuan3D) e depois limpar no Blender; ou Sketchfab (CC) | "wraith", "hooded ghost", "screaming spirit" |
| 2 | **Rig e animação do Bradador** (parado, gritando, andando) | Sem animação ele só desliza | Mixamo (grátis, conta Adobe): sobe o modelo, escolhe animações, baixa .fbx/.glb | "Scream", "Zombie Idle", "Walk" |
| 3 | **Mula-sem-cabeça 3D** | A atual é só um cavalo de tubos | Sketchfab / OpenGameArt: cavalo realista ("horse") + eu removo a cabeça e ponho fogo; ou IA 3D a partir de imagem | "horse", "mule", "donkey" |
| 4 | **Casas coloniais modeladas** (sobrado com beiral, janelas, portas, sacadas de madeira) | As casas atuais são caixas com molduras: é o que mais denuncia o "amador" | Sketchfab (filtro CC0/CC-BY), Kenney, OpenGameArt, Blender Kit; pacotes "colonial / portuguese / baroque village" | "colonial house", "portuguese house", "baroque town", "sobrado" |
| 5 | **Igreja barroca mineira** (matriz com torres e frontão) | A igreja é a cena final | Sketchfab (várias de Ouro Preto/Tiradentes com CC) | "baroque church", "Sao Francisco de Assis Ouro Preto", "Brazilian church" |
| 6 | **Texturas fotográficas de parede** | Reboco e tinta ainda são procedurais | ambientCG / Poly Haven (CC0) | `Plaster`, `Stucco`, `Wall`, `Bricks`, `RoofingTiles`, `PaintedPlaster`, `Rock`, `PavingStones` |

## P2: detalhes que dão vida e "bagunça real"

| # | O que | Onde / termos |
|---|---|---|
| 7 | Telhado colonial (telha capa-e-canal), beirais, calhas, chaminés reais | Poly Haven/Sketchfab "roof tiles", "chimney" |
| 8 | Portas e janelas coloniais (madeira com almofadas, vidro, venezianas, grades de ferro) | Sketchfab, Poly Haven: "wooden door", "window shutters", "iron grille" |
| 9 | Postes e fios elétricos de 1961 (poste de madeira/concreto, isoladores, fios, transformador) | Sketchfab "utility pole", "power line" |
| 10 | Veículos de época (Fusca, Rural Willys, Kombi, jipe, caminhão antigo). **Conferir quais circulavam em MG em 1961** | Sketchfab "vintage car 1950s", "VW Beetle", "Willys" |
| 11 | Pessoas de época (moradores como vultos/silhuetas, mineiros, capataz do passado) | Mixamo (personagens grátis) + roupas simples |
| 12 | Animais: burro, galinha, cachorro, gato, morcego, coruja, urubu | Sketchfab/Poly Haven "dog", "cat", "chicken", "owl" |
| 13 | Mobília e objetos de 1961 (rádio de válvula, fogão a lenha, lata de querosene, garrafas, cadeiras, mesas, caixotes, sacos) | Sketchfab, Poly Haven (props) |
| 14 | Cruzeiro, oratórios, chafariz de pedra, bicas d'água, sino, murais | Sketchfab "cross stone", "fountain", "bell" |
| 15 | Lixo e sujeira (papéis, latas, folhas, cacos) como decalques | ambientCG "Decals", Poly Haven |
| 16 | Plantas tropicais modeladas: bananeira, samambaia, hera, ipê, jabuticabeira, mangueira, capim-gordura, bambu | Poly Haven plants, Sketchfab "banana tree", "fern", "bamboo", "ivy" |
| 17 | Céu noturno HDRI (nuvens e lua reais) | Poly Haven HDRIs (categoria "night") |

## P3: áudio (70% do medo)

| # | O que | Onde |
|---|---|---|
| 18 | **Grito do Bradador** (gravado por pessoa: vários tons, perto/longe, eco) | Você ou ator: gravar. Posso preparar a lista de falas e o formato |
| 19 | Ambiente real: vento em vale, grilos/sapos de MG, riacho, sino da igreja, cachorros ao longe, coruja | freesound.org (CC0/CC-BY; filtre a licença) |
| 20 | Passos em pé-de-moleque (pedra), galope em calçamento, relincho, fogo, respiração, sussurros | freesound.org |
| 21 | Música: pouquíssima, drones graves; talvez uma modinha/viola caipira distante | freesound / Free Music Archive / itch.io (CC0) |

## O que **eu** posso fazer sem asset novo (e já fiz ou faço)
- Luz mais fraca de 1961, estrelas, auditoria de peças soltas, física, testes. (feito)
- Neblina volumétrica, chuva, relâmpago, poças e reflexos (precisa do renderizador Forward+, ver APRENDER.md). (posso fazer)
- Decalques (musgo, manchas, rachaduras) com texturas que você baixar. (posso fazer)
- Oclusão e LOD para o desempenho, empacotar o .exe. (posso fazer)
- Detalhes arquitetônicos extras por código: mais variedade de casas, empenas, beirais, sacadas. (posso, mas continuará sendo "caixa com detalhes"; o salto real é o item 4)

## O que não consigo
- Esculpir modelos 3D orgânicos de alto nível do zero (Bradador/Mula/casas): preciso do seu arquivo.
- Ouvir o jogo, sentir se assusta, testar com seu microfone e na sua placa de vídeo.
- Garantir que um fato de 1961 está certo sem fonte (veja `08-ambientacao-1961.md`).

## Ordem sugerida (para mandar aqui)
1. **Bradador** (modelo da sua arte, de preferência já rigado) e **Mula**.
2. **2 ou 3 casas coloniais modeladas** (eu repito/varío pela rua) + **igreja**.
3. **Texturas de reboco/telha/pedra** (ambientCG: Plaster, RoofingTiles, PavingStones).
4. **Sons** (grito, sino, vento).
5. Veículos, fios e postes de 1961, animais, pessoas.

## Como o jogo usa seus arquivos
- `assets/models/bradador.glb` e `mula.glb`: o jogo troca sozinho o modelo simples pelo seu (ajuste tamanho/giro em `scripts/modelos.gd`).
- Casas, igreja e props: eu conecto em `tools/vila_builder.gd` (via `tools/props.gd`).
- Créditos de tudo vão para `assets/CREDITOS.md`.
