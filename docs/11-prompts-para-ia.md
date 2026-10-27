# Prompts prontos para colar em uma IA

Três prompts. Copie o bloco inteiro (entre as linhas de ```), cole numa IA (Claude, ChatGPT, Gemini...) e anexe o que está pedido em cada um.
Funcionam melhor em IA que abre o repositório (Claude Code, Cursor, Codex). Em chat comum, anexe o zip do projeto.

---

## PROMPT 1: terminar o jogo (código, mundo e trama)

Anexe: o zip do projeto + `docs/10-roteiro-do-jogo-de-2-horas.md` (já está no zip).

```
Você é um desenvolvedor sênior de jogos especialista em Godot 4.7 (GDScript) e em jogos de terror 1ª pessoa.
Vou te entregar um projeto Godot existente (zip) chamado BRADADOR: terror folclórico mineiro em 1ª pessoa, em 1961, numa vila inspirada em Ouro Preto.
Leia ANTES de tudo, nesta ordem: README.md, docs/10-roteiro-do-jogo-de-2-horas.md, docs/08-ambientacao-1961.md, docs/03-conceito-v0.2-vila-colonial.md, docs/07-auditoria-e-correcoes.md, docs/09-mapa-de-assets-realismo-extremo.md.
Meu objetivo: um jogo COMPLETO de ~2 horas, realista (nada de "estilo Roblox"), estável e sem bugs de colisão/objetos soltos.

## O que já existe (não reescreva; estenda)
- Godot 4.7, renderizador Forward+ (com fallback), 100% grátis e CC0/CC-BY (créditos em assets/CREDITOS.md).
- O mundo é GERADO POR CÓDIGO e "assado" em cenas: `tools/bake.gd` roda com um renderizador real (NUNCA com --headless) e salva scenes/*.tscn e vila.scn.
  Fluxo: godot --headless --path . --script res://tools/gen_textures.gd ; godot --headless --path . --import ; (xvfb-run) godot --path . --rendering-driver opengl3 --script res://tools/bake.gd ; godot --headless --path . --import
- `scripts/route.gd` (classe Route): rua Catmull-Rom de 343 m (pos(s), tangent(s), right(s), width(s), height(s), nearest_s(p)).
- `tools/vila_builder.gd` (VilaBuilder): terreno, rua, ~55 casas com lotes (frontage), 14 becos em escada, ponte, chafariz, adro e igreja, props reais do Poly Haven (tools/props.gd). ENTRADAS = casas visitáveis.
- `tools/interiores.gd` (Interiores): salas construídas longe do mapa (BASE=4000 m) e acessadas por teleporte com fade. Para criar uma sala: copiar uma função _sala_xxx, incluir em ORDEM e em VilaBuilder.ENTRADAS.
- `scripts/missao.gd` (Missao): objetivo, inventário, portas (porta.gd), itens (coletavel.gd tipo "item"), altar final.
- `scripts/scream_system.gd`: o Bradador grita; o jogador deve AGACHAR e ficar quieto (opção antiga: gritar). Estágios de distância, olhar proibido, ruído de passos.
- `scripts/event_director.gd` + `mula.gd`: a Mula-sem-cabeça (apagar a lanterna e entrar num beco).
- `scripts/audio_director.gd`, `synth.gd` (áudio sintetizado = placeholder), `hud.gd`, `menu.gd`, `config.gd`, `player.gd`.
- `tools/criaturas.gd`: Bradador e Mula procedurais (placeholders). Se existir assets/models/bradador.glb ou mula.glb, `scripts/modelos.gd` troca automaticamente.
- Testes automáticos (rode TODOS depois de cada mudança, e acrescente novos):
  godot --headless --path . --quit-after 90000 -- --selftest | --selftest-walk | --selftest-walk --walk-offset=1.5 | --walk-offset=-1.5 | --selftest-escape | --selftest-mula=rua|refugio|refugio_aceso | --selftest-becos | --selftest-itens | --selftest-casas
  godot --headless --path . --script res://tools/auditoria_geom.gd   (buracos no chão, casas atravessando)
  godot --headless --path . --script res://tools/auditoria_pecas.gd  (props flutuando/afundados/atravessados)
  fotos: tools/foto_tour.gd, tools/foto_interiores.gd, tools/preview_criaturas.gd (com xvfb-run).

## Regras que você DEVE seguir
1. Não quebre os testes. Toda função nova de jogo ganha um teste automático (modo --selftest-xxx em scripts/main.gd).
2. Nada de objetos flutuando, peças atravessadas ou itens dentro de móveis: use as auditorias e a função _livre()/_reservar() do VilaBuilder.
3. Cada tarefa termina com: testes passando, capturas de tela conferidas por você (olhe as imagens!), docs atualizados e commit em português.
4. Assets de terceiros só CC0/CC-BY, com registro em assets/CREDITOS.md. Se precisar de um modelo/textura/som que não tenho, ME PEÇA com o nome exato e o site onde baixar; não invente arquivo.
5. Sensibilidade cultural: o horror vem do capataz e da violência colonial, NUNCA das vítimas. Pessoas escravizadas aparecem com nome e dignidade. Sinalize tudo que precisa de revisão por historiador/consultor.
6. Fatos de 1961 não verificados devem ser marcados como "a verificar" em docs/08.
7. Desempenho: meta 60 fps numa RTX 2060 em 1080p (Qualidade Alta); Média deve rodar em PC fraco. Use LOD, visibility ranges, MultiMesh, oclusão.
8. Português do Brasil em todo texto do jogo (acentos corretos).

## O que construir (nesta ordem; entregue por marcos, rodando os testes a cada marco)
M1. Salvar/continuar (checkpoints na ponte e na igreja, arquivo user://), menu de pausa completo (continuar/opções/sair), legendas dos sons, remapear teclas, suporte a gamepad.
M2. Esconder-se (armário, baú, sob a cama, barril) com regras de IA; 10 interiores novos (ferraria, sapataria, botica, açougue, escola, cartório, hospedaria, lavadeira, quarto do barbeiro, casa vazia) e expandir o Casarão (2º andar, porão) e a igreja (sacristia, torre do sino).
M3. Integrar modelos reais quando eu os entregar (Bradador, Mula, casas, igreja): converter, otimizar, ajustar escala e testar. Enquanto não houver, melhore os procedurais.
M4. Fase da Mina (galerias, vagonetes, poço), Corpo-seco (lento, sente passos, não pisa em chão benzido: linhas de giz/sal), puzzle de alavancas, escuridão total com lanterna escassa.
M5. Cemitério da Irmandade e Capela do Rosário, 2ª ladeira, Pisadeira (paralisia do sono: minijogo de respiração), puzzle do sino e das lápides.
M6. Ato IV (resgatar a mãe no porão, perseguição lenta, sino com tempo limitado, 3 ondas de Mula), os 3 finais, cutscenes curtas (câmera fixa + voz), créditos.
M7. Áudio real no lugar do sintetizado (peça-me os sons), mixagem, reverb por ambiente (rua, interior, igreja), música mínima.
M8. Otimização, exportar .exe para Windows, tela de carregamento, teste de 2 horas completo (bot jogando) e relatório.

## Qualidade visual (Forward+)
- Use SSAO, SSIL, SSR, SDFGI, neblina volumétrica e TAA em "Alta", e comente o custo de cada um.
- Adicione Decals de sujeira, mofo, rachaduras e umidade nas fachadas; chuva opcional com poças e relâmpago; reflexos na pedra molhada; vento em folhagens; fumaça de chaminé; gatos/morcegos/corujas; roupa no varal balançando.
- Melhore as casas: variar volumes (puxadinhos, empenas, sacadas de madeira reais, beirais com cachorros, vergas, balcões de ferro), telhados com caimento variado e telhas individuais perto da câmera, janelas e portas com almofadas e venezianas, grades de ferro, chaminés.
- Nunca deixe peça solta: rode tools/auditoria_pecas.gd e o relatório "pecas soltas" do bake.

## Como você deve me responder
1. Primeiro: um plano curto com os marcos e o que vai precisar de mim (assets, decisões).
2. Depois de cada marco: o que mudou, saída dos testes (cole), capturas de tela e riscos.
3. No fim: zip do projeto, lista de assets pendentes e checklist de revisão cultural.
Comece pelo M1 agora.
```

---

## PROMPT 2: gerar os modelos 3D (Bradador, Mula, casas, igreja)

Anexe: a **sua imagem do Bradador** (a que você gerou) em cada ferramenta de "image-to-3D" (Tripo, Meshy, Hunyuan3D, Rodin...) ou use o texto abaixo em "text-to-3D".

```
Quero um modelo 3D para um jogo de terror realista em 1ª pessoa (Godot 4, Forward+, PBR).
PERSONAGEM: "O Bradador", alma errante do folclore mineiro (a alma do capataz que a terra recusou). Siga a imagem anexa.
Descrição: figura muito alta e magra (2,7 m), corcunda leve, manto preto longo, esfarrapado e molhado na barra, capuz fundo; rosto pálido e cadavérico, olhos fundos e escuros, boca escancarada num grito, pele acinzentada e translúcida; braços compridos até os joelhos, mãos ossudas com dedos longos; postura de quem avança devagar. Sem armas. Sem símbolos de marca. Estilo realista (não cartoon), iluminação neutra para textura.
Requisitos técnicos:
- pose "A" (braços ligeiramente afastados), pés no chão, escala real 2,7 m;
- malha limpa só com quadriláteros/triângulos, 25 a 40 mil triângulos, UV sem sobreposição;
- texturas PBR 2K: albedo, normal, rugosidade, metálico (0 no manto);
- esqueleto humanoide compatível com Mixamo (ou me diga para eu subir no Mixamo);
- exportar em .glb (ou .fbx) com texturas embutidas.
Entregue também 3 variações pequenas (manto mais rasgado, mais úmido, mais magro).
```

```
Mesma especificação técnica (PBR 2K, .glb, 20 a 35 mil triângulos), personagem: "A Mula-sem-cabeça" do folclore brasileiro.
Descrição: mula/cavalo preto-avermelhado, magro, realista, SEM CABEÇA: o pescoço termina num toco queimado e brasa viva com chamas (separe a chama como malha à parte para eu animar). Selas ou arreios de couro velho rotos, cascos de ferro enferrujados, pelos molhados e ossos marcados. Pose de galope e pose parada (2 arquivos). Esqueleto de quadrúpede com pernas separadas (frente esquerda/direita, trás esquerda/direita).
```

```
Modelo modular de CASA COLONIAL MINEIRA (inspiração Ouro Preto / Tiradentes), realista, PBR 2K, .glb, 8 a 15 mil triângulos por módulo:
Entregue como módulos que se encaixam em grade de 1 m: (1) fachada de sobrado de 2 andares com 3 vãos, janelas com vergas de pedra, venezianas de madeira, porta de duas folhas com almofadas e soleira de pedra, sacada de ferro com guarda-corpo, beiral com cachorros de madeira; (2) fachada térrea; (3) telhado de duas águas com telha capa-e-canal e cumeeira; (4) muro de pedra com portão; (5) empena lateral; (6) chaminé de pedra. Reboco antigo descascado, manchas de umidade, pedra de embasamento irregular. Sem texto/placas. Cores do reboco como textura separada (branco, ocre, azul, salmão, verde) para eu trocar.
```

```
Modelo realista de IGREJA BARROCA MINEIRA (matriz, inspirada em Ouro Preto), PBR 2K, .glb, até 60 mil triângulos: fachada branca com cantaria cinza, portal em arco com porta dupla de madeira escura, óculo, frontão com volutas e pináculos, duas torres cilíndricas com cúpulas e sineiras de arco, cruz de pedra no topo, escada de pedra de 5 degraus. Separe a porta como malha à parte. Sem pessoas.
```

---

## PROMPT 3: sons e voz (para IA de áudio ou para você gravar)

```
Preciso de efeitos sonoros realistas para um jogo de terror folclórico mineiro em 1961, em WAV 44,1 kHz estéreo, sem música, sem voz (exceto o item 1), em loop quando indicado:
1. GRITO do Bradador (5 variações, 4 a 8 s): voz humana rouca e longa, "ahhhh" que se transforma em lamento, com eco de vale; perto e distante.
2. Vento em vale com sino de igreja ao longe (loop 60 s).
3. Grilos e sapos de mata atlântica à noite (loop 60 s).
4. Galope de mula/cavalo em pé-de-moleque (calçamento de pedra) se aproximando (8 s), com fogo crepitando.
5. Passos humanos em pedra molhada: andar, correr, agachado (6 variações cada).
6. Sino de igreja grande: 1 badalada (10 s de cauda) e repique rápido.
7. Porta de madeira antiga abrindo e rangendo; fechadura de ferro; chave virando.
8. Rádio de válvula mudando de estação e chiado; TV preto-e-branco com estática (loop).
9. Fogão a lenha estalando (loop), vela e lamparina a querosene (chiado leve).
10. Respiração assustada (loop), batimento cardíaco (loop 60 e 120 bpm).
Entregue em pasta separada por item, nome em minúsculas sem acento.
```

Para a **dublagem**: peça à IA o texto das falas em `docs/10` (Tomé, Dona Benedita, Seu Tobias, Seu Zé, Bradador) e grave com atores brasileiros (sotaque mineiro). Não use voz de pessoa real sem autorização.
