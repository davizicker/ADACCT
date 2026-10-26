# Aprendendo a desenvolver este jogo (100% grátis)

Este guia usa o próprio projeto como aula. Faça na ordem; cada exercício leva 5–20 minutos.
Tudo aqui usa só ferramentas gratuitas: Godot (jogo), Blender (modelos, opcional) e
texturas/modelos de licença livre.

> **Antes de tudo:** abra o Godot → **Importar** → escolha o `project.godot` da **raiz** deste
> repositório. Não crie um projeto novo copiando arquivos (o microfone e a configuração do
> renderizador ficam no `project.godot` do repositório).

## O que é cada coisa no editor
| Painel | Para quê |
|---|---|
| **Cena** (alto esquerda) | Árvore de objetos ("nós") da cena aberta |
| **Sistema de Arquivos** (baixo esquerda) | Seus arquivos: `scenes/`, `scripts/`, `assets/` |
| **Visualização 3D** (centro) | Onde você vê e mexe no mundo |
| **Inspetor** (direita) | Propriedades do objeto selecionado (cor, tamanho, luz…) |
| **Saída** (embaixo) | Mensagens e erros quando o jogo roda |

**Ideia central do Godot:** tudo é uma *cena* feita de *nós*. A casa é uma cena, a vila é uma
cena que contém casas, o jogo é uma cena que contém a vila. Mexeu numa cena, mexeu em todo
lugar onde ela é usada.

**Atalhos na janela 3D:** segure o botão direito do mouse + **WASD** para voar; roda do mouse
para zoom; **W** mover, **E** girar, **R** escalar o objeto selecionado; **Ctrl+D** duplicar;
**Ctrl+Z** desfazer; **Ctrl+S** salvar.

## Como o mundo é organizado (leia antes dos exercícios)
Abra `scenes/vila.scn` e veja a árvore **Cena**:

| Nó | O que é |
|---|---|
| `Ambiente`, `Lua` | Céu, névoa, brilho, luz da lua (**Environment** e **Light**) |
| `Terreno` | Os morros, em ladrilhos (`Trecho_000`…). Gerados por código: não se esculpe aqui |
| `Rua` | O calçamento e as calçadas, em trechos de 30 m, com colisão |
| `Casas` | As casas da rua, uma por nó (`Casa_00`…). Cada casa tem `Corpo`, `Telhado`, `Detalhes` |
| `MurosEQuintais` | Muros de pedra, quintais e arrimos com plantas |
| `Becos` | Escadarias que sobem entre as casas |
| `Iluminacao` | Lampiões, postes e o `FiosDeLuz` |
| `Adornos`, `Nichos`, `Coletaveis` | Barris, bancos, carroça, varais; oratórios com vela; frascos de óleo e bilhetes |
| `Ponte` | A ponte de pedra com o riacho (shader de água em `assets/shaders/agua.gdshader`) |
| `Adro` | A igreja, as muretas e o cruzeiro (a porta da vitória é `Adro/Igreja/Porta`) |
| `Morros` | Casas das encostas (fundidas em blocos), `Arvores`, `Mata`, `Capim`, luzes distantes |
| `Serra` | A silhueta das montanhas ao fundo |
| `RotaReferencia` | Uma linha que mostra por onde a rua passa (só referência) |

**Por que `Detalhes` é um nó só?** Cada casa tem ~60 peças pequenas (molduras, janelas, grades…).
Se fossem 60 nós, o jogo teria milhares de objetos e ficaria pesado. Elas foram **fundidas** numa malha por casa.
Para mudar um detalhe, edite o **material** dele (assets/materials) ou apague o `Detalhes` e ponha o seu modelo.

**A forma da rua** (curvas, subidas, larguras) vem de `scripts/route.gd` (listas de pontos no começo do arquivo).
Mudar a rua exige recriar o mundo com `tools/bake.gd`, o que **apaga suas edições** (veja o aviso abaixo).
Para experimentar sem medo: faça uma cópia do projeto antes.

## Onde mexer em cada coisa do jogo (cola rápida)
| Quero mudar... | Onde |
|---|---|
| Tempo para responder ao grito, quantos gritos | `scripts/scream_system.gd` (constantes no topo) |
| Quando a Mula e o apagão acontecem | `scripts/event_director.gd` (`_t_mula`, `_t_blackout`) |
| Velocidade da Mula | `scripts/mula.gd` (`SPEED`) |
| Velocidade de andar/correr, fôlego | `scripts/player.gd` (constantes no topo) |
| Textos dos bilhetes | `scripts/notas.gd` |
| Sons (grito, passos, sino...) | `scripts/synth.gd` (ou troque por arquivos .wav/.ogg: veja abaixo) |
| Volumes e eventos de áudio | `scripts/audio_director.gd` |
| Efeitos de câmera (vinheta, granulado, medo) | `assets/shaders/efeitos.gdshader` |
| Cor do céu, nuvens e estrelas | `assets/materials/ceu.tres` (Inspetor → Shader Parameters) |
| Água do riacho | `assets/materials/agua.tres` |
| Menu e opções | `scripts/menu.gd` |
| Salvar opções | `scripts/config.gd` (arquivo salvo em `user://bradador.cfg`) |

**Como trocar um som sintético por uma gravação real:** em `scripts/audio_director.gd`, onde aparece
`Synth.sino()`, `Synth.dog()`, etc., troque por `load("res://assets/audio/arquivo.ogg")` (coloque o arquivo em `assets/audio/`
e registre a origem em `assets/CREDITOS.md`).

## Exercícios (na ordem)

### 1. Jogar
**F5**. Se perguntar a cena, escolha `scenes/main.tscn`. Controles em `LEIAME-do-prototipo.md`.

### 2. Passear pela vila no editor
Abra `scenes/vila.scn` (duplo clique; `.scn` é o mesmo que `.tscn`, só que binário e mais leve). Voe pela rua (botão direito + WASD). Você está vendo
o mundo real do jogo, sem precisar apertar F5.

### 3. Mover uma casa
Na árvore **Cena**, abra `Casas` e clique em `Casa_00`. Aperte **W** e arraste uma seta.
Gire com **E**. Aperte **F5** para ver. (Dica: **Ctrl+Z** desfaz qualquer coisa.)

### 4. Mudar a cor de uma parede
No Sistema de Arquivos: `assets/materials/reboco_ocre.tres` (duplo clique). No Inspetor,
mude **Albedo → Color**. Todas as casas ocres mudam de uma vez. É assim que se trabalha com
materiais.

### 5. Mudar uma luz
`Iluminacao → LampiaoParede_02 → Luz`. No Inspetor, **Light → Energy** (força) e **Color**. Teste
`Shadow → Enabled` ligado e desligado: sombras deixam mais realista, mas custam desempenho.
Os lampiões de parede alternam os lados da rua; os postes só ficam nos largos.

### 6. Mudar a neblina e o clima
`Ambiente` → no Inspetor, clique em **Environment**. Mexa em **Fog → Density**, em
**Ambient Light** e em **Glow**. Mudar a densidade da neblina muda totalmente o medo do jogo.

### 7. Criar uma casa nova
Arraste `scenes/casa.tscn` do Sistema de Arquivos para dentro do nó `Casas`. Posicione com
**W**. Para mudar o tamanho, abra `scenes/casa.tscn` e edite `Corpo`, `Telhado` etc.

### 8. Modelar com formas básicas (CSG)
Com a vila aberta: **+** (adicionar nó) → procure `CSGBox3D`. Dimensione e posicione.
CSG serve para "blocar" ideias rápido (muros, escadas, becos). Para um beco novo: duas
caixas altas lado a lado. Para um buraco numa parede, ponha outro CSG com **Operation = Subtraction**.

### 9. Mexer nas regras do jogo (primeiro código)
Abra `scripts/scream_system.gd` (aba **Script** no topo). No começo estão constantes:
`WINDOW_SECONDS` (tempo para responder), `SHOUT_NEEDED`, `GAZE_SECONDS`. Mude
`WINDOW_SECONDS` de 3.0 para 5.0 e jogue. Depois mude `interval_range` (intervalo entre gritos).
É assim que se "balanceia" um jogo: mudar números e testar.

### 9b. Faça a Mula mais rápida (e mais assustadora)
Em `scripts/mula.gd`, mude `SPEED` de 15.0 para 22.0. Em `scripts/event_director.gd`, mude `_t_mula := 110.0` para `30.0` para ela aparecer cedo.
Jogue: dá tempo de apagar a luz e achar um beco? Esse é o equilíbrio que você ajusta jogando.

### 10. Seu primeiro objeto novo
Duplique `Iluminacao/LampiaoParede_02` (Ctrl+D), mova para uma esquina e mude a cor da luz para vermelho-escuro.
Você acabou de fazer level design.

> **Aviso importante:** `tools/bake.gd` recria TODAS as cenas do zero e **apaga suas edições**.
> Não rode depois que começar a editar a vila no editor. Ele existe só como gerador inicial.
> (Ele também precisa de um renderizador real: não rode em modo `--headless`, que descarta os dados de MultiMesh.)

## Se o jogo ficar pesado
Nesta ordem: (1) em `Lua`, desligue **Shadow → Enabled**; (2) em `Morros → Mata`, apague alguns dos 4 nós
(menos árvores); (3) em `Morros → Capim`, desligue (ícone do olho); (4) em `Ambiente → Environment`, desligue **Glow**.
Em `scenes/jogador.tscn`, `Camera/Lampiao → Shadow → Enabled` liga a sombra do lampião (bonita, mas pesada).

## Trocar texturas por texturas profissionais (grátis)
As texturas atuais são geradas por código (boas para começar). Para algo mais realista:

1. Baixe de **[ambientCG](https://ambientcg.com)** ou **[Poly Haven](https://polyhaven.com)**
   (ambos **CC0**: uso livre, inclusive comercial, sem obrigação de crédito). Baixe a versão
   **1K ou 2K**, formato JPG/PNG. Cada textura vem com vários mapas:
   `Color` (albedo), `NormalGL` (normal), `Roughness`, às vezes `AO` e `Displacement`.
2. Arraste os arquivos para `assets/textures/` no Godot.
3. Abra o material (ex.: `assets/materials/pedra_chao.tres`) e arraste:
   `Color` → **Albedo → Texture**; `NormalGL` → **Normal Map → Texture** (ligue Normal Map);
   `Roughness` → **Roughness → Texture**; `AO` → **Ambient Occlusion → Texture**.
   Use o mapa **NormalGL** (o Godot usa o padrão OpenGL).
4. Ajuste o tamanho do padrão em **UV1 → Scale**. (Os materiais já usam *triplanar*, então
   não precisa mexer em UV.)

Boas ideias de busca: "cobblestone", "plaster wall", "roof tiles", "old wood planks", "moss".

## Modelos 3D profissionais (grátis)
O Godot importa **`.glb` / `.gltf`**. Arraste o arquivo para o Sistema de Arquivos, dê duplo
clique, escolha **Nova Cena Herdada**, e salve em `scenes/`. Depois arraste a cena para o mundo.

Fontes gratuitas:
- **[Poly Haven](https://polyhaven.com/models)** (CC0): objetos e props realistas.
- **[Quaternius](https://quaternius.com)**, **[Kenney](https://kenney.nl)** (CC0): kits de cenário
  (estilo mais "limpo").
- **[Sketchfab](https://sketchfab.com)** com filtro *Downloadable* e licença: **leia a licença**
  de cada modelo. CC-BY exige crédito; "NonCommercial" não pode ser usado em jogo vendido.
- **[Mixamo](https://mixamo.com)** (conta Adobe gratuita): personagens e animações humanas.

**Sempre registre** o que usar em `assets/CREDITOS.md`.

## Criar seus próprios modelos: Blender (grátis)
[blender.org](https://blender.org). Exporte como **glTF 2.0 (.glb)** e arraste para o Godot.
Boa trilha: modele primeiro objetos simples (poste, barril, cruz) antes do monstro.
O Bradador é seu projeto de modelagem mais interessante: alto, magro, sem rosto definido.

## Deixar ainda mais realista (opcional, precisa de placa de vídeo com Vulkan)
O projeto usa o renderizador **Compatibilidade** (roda em qualquer PC). Para ganhar sombras
suaves, oclusão ambiental (SSAO), névoa volumétrica e iluminação global:
**Projeto → Configurações do Projeto → Renderização → Renderer → Forward+**, reinicie e em
`Ambiente → Environment` ligue **Volumetric Fog** e **SDFGI**. O SSAO já está configurado.
*(Não testei o Forward+ neste projeto; se ficar lento ou estranho, volte para Compatibilidade.)*

## Onde aprender (gratuito)
- **Primeiro jogo 3D oficial:** documentação do Godot, tutorial *"Your first 3D game"*
  ([docs.godotengine.org](https://docs.godotengine.org), há seletor de idioma).
- **GDScript do zero, interativo:** [gdquest.github.io/learn-gdscript](https://gdquest.github.io/learn-gdscript/).
- **Blender:** o tutorial da rosquinha (*Blender Donut*) do Blender Guru no YouTube.
- **Terror e áudio:** estude jogos como *Amnesia*, *Alien: Isolation*, *Signalis* jogando com
  fones e anotando o que dá medo e por quê.

## Roteiro sugerido (4 semanas, ~1 h/dia)
1. **Semana 1:** exercícios 1–6. Entender o editor, cenas, materiais e luz.
2. **Semana 2:** exercícios 7–10 + trocar as texturas por CC0 reais.
3. **Semana 3:** tutorial oficial *Your first 3D game* + GDScript do zero. Ler `scripts/player.gd`.
4. **Semana 4:** modelar um objeto no Blender e colocá-lo na vila; mudar uma regra no
   `scream_system.gd`.

## Guardar seu trabalho
Use o **GitHub Desktop** (grátis) para salvar versões. Faça um *commit* antes de experimentos
grandes: se estragar algo, volta ao ponto anterior.
