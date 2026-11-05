# BRADADOR: novidades desta versão (v24) e avisos

## O que mudou
**Jogabilidade**
- Pulinho com **Espaço** (30 cm; faz barulho no chão de pedra; não pula agachado).
- Ratos de rua que fogem quando você chega perto (mais cedo se estiver correndo).

**História (lore)**
- Fio emocional: Tomé volta porque a mãe pediu; o pai morreu na Galeria Três (1958); a Companhia abafou tudo; a mãe aceitou o envelope para pagar o estudo dele.
- 10 documentos novos (telegrama da Companhia, rascunho do Dr. Anselmo, confissão do Seu Zé, ata da Irmandade, papel atrás do retrato, diário de Eulália Vaz, encomenda dos 31 caixões...).
- O **Diário de Tomé** agora aparece em capítulos na subida (antes a 1ª página nunca aparecia).
- O **final muda** conforme os documentos lidos (tecla J reabre o que já leu).

**Mundo**
- Igreja nova no estilo São Francisco de Assis (Ouro Preto): torres com agulha, medalhão, porta verde, cantaria ocre. Praça com pilastras, bancos, vasos de barro.
- Altar da igreja barroco (retábulo dourado, colunas torças, grade, castiçais).
- 3 tipos de altar de rua (aedícula com santa, cruz, alminhas), com velas de cera real.
- Interiores com lambri, sanca, cortinas, peitoril, tapetes e móveis novos; sondas de reflexo em cada sala.
- Mariposas em volta dos lampiões.
- Lampiões e postes nunca ficam a menos de 6,5 m um do outro.

**Som (tudo sintetizado por código, sem gravações)**
- Passos leves em pedra (duas batidas, grãos, roupa), em madeira dentro das casas e abafados agachado; 8 variações; passo nunca repete seguido.
- Grito com voz mais humana (formantes), sino de bronze, vento com rajadas, grilos naturais, coruja.

**Gráficos e peso**
- Texturas 3D com **compressão BC7 e mipmaps**: ~3 a 4x menos memória de vídeo e sem tremer de longe.
- Halos de luz por shader (sem quadrados), velas com chama, flores com folhagem.

**Refinamento final (v24)**
- Objetos feitos por código mais redondos (mais lados em cilindros, esferas e arcos).
- Reboco com grão de estuque, pinceladas e rachaduras em fio de cabelo.
- Quadros pretos viraram retratos a óleo; bilhetes com brilho suave (sem quadrado branco).
- Frascos de querosene dentro das casas não flutuam mais: ficam sobre móvel ou sobre um banquinho.
- Cadeiras afastadas da mesa do Casarão, capacho em cada porta, frontão da igreja mais suave.
- Auditorias novas: `tools/auditoria_moveis.gd` (flutuando/enterrado/se atravessando) e `tools/auditoria_texturas.gd`.

**Modelos novos (Poly Haven, CC0 a confirmar)**: 27 modelos (castiçais, lamparina, vaso, cadeiras, mesas, estante, malas, rato, bússola, isqueiro...) e casca de árvore real. Veja `assets/CREDITOS.md`.

## Avisos importantes
1. **Na primeira abertura no Godot**, ele vai reimportar as texturas (BC7). Pode levar alguns minutos. É normal e só acontece uma vez.
2. O visual **Cinematográfico** é o padrão. Se pesar na sua placa, use "Alta" ou baixe o slider FSR nas Opções.
3. Os testes e fotos foram feitos em renderização por software; **o FPS na placa de vídeo real não foi medido**.
4. A licença da cera da vela (pacote de texturas enviado) e dos braços estão marcadas "CONFIRMAR" em `assets/CREDITOS.md`.

## Ferramentas novas
`tools/auditoria_texturas.gd` (texturas e materiais), `tools/auditoria_luzes.gd` (lâmpadas coladas), `tools/audio_export.gd` (exporta os sons para análise), `tools/blender/build_props3.py` (converte .blend novos).
