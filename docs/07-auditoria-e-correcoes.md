# Auditoria técnica e visual (v5): o que estava feio, o que estava quebrado, o que foi feito

Método: (1) **47 fotos** da vila por ângulos fixos (`tools/foto_tour.gd`), revisadas uma a uma; (2) testes automáticos novos
que exercitam o que nenhum teste anterior cobria (`--selftest-becos`, `--selftest-itens`, `--walk-offset`, `tools/auditoria_geom.gd`);
(3) correção; (4) **mesmo tour de fotos de novo** para comparar; (5) bateria completa de testes na **Godot 4.7.2**.

## 1. BUGS REAIS no jogo (corrigidos)

| # | Bug | Como foi achado | Causa | Correção | Prova |
|---|---|---|---|---|---|
| 1 | **Buracos na rua**: o jogador atravessava o chão e caía do mundo; faixas escuras no largo | Teste dos becos: um beco acusou queda de −1.432 m | O perfil da rua mudava de nº de pontos quando a largura mudava, e o código **pulava** a faixa entre os quadros: 1 m sem chão a cada mudança | Perfil com nº **fixo** de pontos (e `assert` se mudar) | `auditoria_geom.gd` varre 4.802 pontos do chão: com o bug reintroduzido de propósito acusa **761 buracos**; hoje **0** |
| 2 | **Jogador preso andando pela borda da rua** em s≈228 | `--walk-offset=1.5`: TIMEOUT | A parede invisível dos becos começava **1 m antes** da fachada e, nas curvas, avançava para dentro da pista | A parede agora começa na linha da fachada | Anda pela borda esquerda e direita da rua inteira até a igreja |
| 3 | **Becos apertados/bloqueados nas curvas** (2 de 7 travavam) | Teste dos becos | As casas vizinhas são giradas pela curva e invadiam o vão da escada | Becos de 3,0 → 3,6 m e casas vizinhas mais rasas | **7/7 becos sobem inteiros** (16 m de comprimento, +6,5 m de altura) |

Desses, o nº 1 e o nº 2 foram **introduzidos por mim** em edições desta sessão (o perfil de rua novo e a parede de beco anterior),
e só apareceram porque criei testes que antes não existiam. Também errei no meio do caminho e corrigi antes de entregar: troquei o telhado por
uma casca **sem forro** (as fotos mostraram o céu por baixo do beiral).

## 1b. Falsos alarmes (erro do meu teste, não do jogo)
- **"Frascos e bilhetes não funcionam" (13/13 falhas):** o teste mexia numa lista que encolhia durante o loop. Reescrito, **7/7 frascos recarregam o óleo e somem; 6/6 bilhetes abrem, congelam o jogador e fecham com E**. Ficou como teste de regressão.
- **"Itens dentro de casas":** a checagem usava caixas alinhadas aos eixos, que exageram nas casas giradas. Com caixas orientadas: 0 problemas.

## 2. O que estava FEIO (e como ficou)

| Problema visual | Antes | Depois |
|---|---|---|
| **Calçamento** | Rachaduras escuras sobre fundo marrom ("terra seca"); pedras em formato de colmeia | Pedras individuais **arredondadas**, juntas finas com musgo, cores variadas (ocre, cinza, rosado, esverdeado), brilho de pedra molhada só nas pedras; cor por vértice com **sujeira e musgo junto ao meio-fio** e manchas de umidade. Textura nova **sem emenda visível** (Voronoi periódico próprio) |
| **Meio-fio** | Quina vertical de 12 cm (travava o jogador) | Chanfro de 45° + sarjeta + coroa levemente abaulada |
| **Janelas** | Quadrados pretos ou amarelo chapado | Vidro de **sala acesa** (cortinas com dobras e amarração, lâmpada) e vidro de **noite** (reflexo diagonal do céu); em arco quando a casa tem arco |
| **Lampiões** | Caixa amarela espetada num poste | Poste de ferro com base, colar e braço; lampião de parede com **gaiola, escora e topo piramidal**; **halo** de luz difusa que some junto com a luz no apagão |
| **Placas de loja** | Retângulo preto com texto | Braço de ferro com escora e voluta, correntes, placa colorida com **moldura dourada**, letras com contorno e sombreado, **emblema** (pão, pilão, poste de barbeiro, bota, ferradura, anel, tesoura) |
| **Telhados** | Prisma liso, vermelho uniforme | Telhas **no sentido do caimento** (UV), cumeeira de capa, tábuas de beiral, forro, inclinação diferente em cada casa |
| **Paredes** | Manchas grandes e marrons ("sujas") | Reboco limpo com **escorrimentos de chuva**, descascado só em poucos pontos |
| **Nichos** | Caixa com vela | Oratório com mísula, arco de pedra, imagem de santo, frontão com cruz, grade com velas e halo |
| **Chafariz** | Blocos empilhados | Paredão com pilastras, cornija, frontão, nicho em arco com carranca, tanque de pedra com água (shader), fio de água, degraus, bancos, lampião |
| **Igreja** | Caixas e cones | Portal **em arco** com folhas de madeira e leque de luz, óculo com raios, pilastras, frontão com volutas e pináculos, **torres com pilastras e sineira** de aberturas |
| **Ponte** | Parapeito inclinado e torto | Pilares verticais nas pontas (os muros acompanham a subida) |
| **Varais** | Triângulos lisos | Panos com dobras (malha 8×3), prendedores de madeira, cores variadas |
| **Frasco de óleo** | Amarelo vivo (parecia desenho animado) | Vidro âmbar escuro com brilho suave |
| **Céu** | Nuvem escura de borda dura | Nuvens macias e translúcidas, estrelas, e uma **lua** real (disco com "mares" e halo) na direção da luz |
| **Sombra da lua** | Preto chapado | Sombra 78% (deixa luz) |
| **Aberração cromática** | Franjas coloridas nas bordas | Reduzida (0,0006) |

## 3. Números (Godot 4.7.2, renderização por software: só referência)
- Chamadas de desenho por quadro (começo da rua / meio / largo): antes ~1.800 / ~1.400 / ~1.400 → agora ~2.200 / ~1.800 / ~1.800.
  O visual ficou bem mais rico e o custo **subiu uns 25%** (mesmo depois de cortar detalhes pequenos por distância: -14%).
  Se o seu computador sofrer, use Qualidade **Baixa/Média** (menu) ou desligue sombras (APRENDER.md).
  Próxima otimização possível (não feita): fundir os "Detalhes" de todas as casas de um trecho de rua num único nó por material.
- 63 luzes, ~920 malhas (1.990 superfícies), 7 MultiMesh.

## 4. O que AINDA está feio ou falta (sem enrolação)
1. **As formas das casas continuam simples** (caixas com detalhes). Uma casa vista de perto ainda não é uma casa modelada à mão. Modelos reais (Sketchfab/Poly Haven/artista) são o próximo salto: ver docs/06.
2. **Texturas das paredes, telha e muro ainda são procedurais.** Faltam texturas fotográficas (você já mandou 5: casca, 2 madeiras, 2 chãos). Faltam: reboco, telha, muro de pedra, cantaria.
3. **Sem chuva, poças com reflexo, neblina volumétrica** no modo padrão (só em Forward+/Qualidade Alta).
4. **Vegetação em cartões**: de perto as folhas são achatadas. Árvores modeladas resolveriam.
5. **O Bradador e a Mula ainda são formas simples** (modelo `.glb` pendente: docs/06).
6. **Sem pessoas nem animais** no cenário (nem gatos nos telhados).
7. **Interior da igreja não existe** (a vitória é na porta).
8. **Desempenho em PC real não medido**.

## 5. Como rodar a auditoria você mesmo
```
godot --path . --rendering-driver opengl3 --script res://tools/foto_tour.gd -- <pasta> tudo      # 47 fotos (precisa de janela)
python3 tools/contact.py <pasta> tudo <pasta>/folha                                               # folhas de contato 2x2
godot --headless --path . --script res://tools/auditoria_geom.gd                                  # buracos, itens, árvores dentro de casas
godot --headless --path . --quit-after 60000 -- --selftest-becos
godot --headless --path . --quit-after 60000 -- --selftest-itens
godot --headless --path . --quit-after 60000 -- --selftest-walk --walk-offset=1.5                 # (e -1.5) anda pela borda da rua
```

## 6. Atualização: assets reais (v6)
- 15 modelos 3D do Poly Haven e 10 texturas CC0 (ambientCG e Poly Haven) integrados: postes e lampiões de parede, lanterna na mão, TV com tela animada, carros cobertos, estátua, porta de beco, barris, banquinhos, baldes, árvores mortas, arbustos, bola, aros de roda, diário. Créditos em `assets/CREDITOS.md`; contexto em `docs/08-ambientacao-1961.md`.
- Regressão na Godot 4.7.2 depois da integração: selftest, walk (centro, +1,5 e -1,5), escape, Mula (3 casos), becos 7/7, itens, auditoria: **0 buracos, 0 problemas**.

## 7. Limpeza geral (v7): "objetos voando e madeiras entrando umas nas outras"
| Problema | Causa | Correção |
|---|---|---|
| Quadradinhos azuis/brancos "voando" no céu | **Estrelas do shader do céu** eram células quadradas que crescem para o zênite | Estrelas redondas, pequenas e do mesmo tamanho em qualquer direção |
| Pontos de luz amarelos flutuando sobre os morros | 900 "luzes distantes" aleatórias no ar | Removidas: só ficam as luzes das janelas das casas dos morros |
| Laje branca flutuando ao lado de chaminés | Tampa da chaminé em z diferente do corpo | Corpo e tampa no mesmo z; o corpo entra no telhado |
| Capitel solto acima dos pilares do portão dos quintais | Tampa 0,3 m acima do pilar | Tampa encostada |
| Paredão de 400 m nas bordas do terreno | Elevação quadrática sem limite | Elevação limitada (130 m) |
| Frasco de querosene dentro do carro coberto | Posição sobreposta | Frasco movido |
| Luz forte demais para 1961 | Lampiões 1,5–1,7, lua 0,42, ambiente 0,5 | Lampiões ~0,9, alcance 8 m, lua 0,30, ambiente 0,38 |

Ferramentas novas (rodam sozinhas e acusam o problema):
- **No bake:** `MeshBatch.floating()` checa cada peça de casas e quintais: "pecas soltas (flutuando): 0".
- `godot --headless --path . --script res://tools/auditoria_pecas.gd`: props flutuando/afundados e atravessando outros props. Resultado: **44 itens, 0/0/0**.
- `tools/preview_criaturas.gd`: fotografa Bradador e Mula de perto.

Bradador e Mula foram refeitos (malhas por código: manto esfarrapado, rosto, braços longos e dedos; corpo, pescoço em brasa, pernas articuladas, cauda). Continuam **placeholders**: os modelos reais são o item 1 e 3 de `docs/09-mapa-de-assets-realismo-extremo.md`.

Casas que se atravessavam nas curvas (6 pares, com telhados cruzados): agora cada casa **encurta a profundidade** até a planta não invadir a vizinha (`_casa_atravessa`). `auditoria_geom.gd`: **0 casas se atravessando** (antes 6).

## 8. Casas, trama e gráficos (v8)
- **Mecânica do grito trocada:** agora, quando o grito acaba, é **agachar (C) e ficar parado**; mexer-se, correr ou olhar para ele aproxima o Bradador. Gritar/microfone continua como **opção** no menu.
- **14 becos** (antes 7), todos testados subindo inteiros. O teste achou um barril bloqueando um beco; agora portas, becos, barris e bancos reservam seu lugar (`_livre/_reservar`).
- **6 casas visitáveis + igreja por dentro**, com lampião aceso na porta; itens (chaves, livro, terço), cartas e querosene; objetivo e inventário na tela; o Casarão fica trancado até achar a chave; a igreja só abre com a chave e o livro. `--selftest-casas` entra em cada porta, confere o chão, pega os itens (nenhum dentro de móvel), sai, cumpre a trama e vence no altar.
- **Forward+ por padrão** (com fallback para OpenGL) e Qualidade Alta ligada: reflexos na pedra molhada, iluminação global, neblina volumétrica, oclusão ambiente. Decalques de sujeira/umidade nas fachadas. Estimativa em placa real não medida.
- Roteiro de 2 horas em `docs/10` e prompts prontos em `docs/11`.

## 9. Detalhes de casas, natureza e solo (v10)
- **Casas:** venezianas abertas em ângulo (~55% das janelas), jardineiras com flores, degrau, número e aldrava nas portas, decalques de reboco caído mostrando tijolo e pedra.
- **Natureza e solo:** 780 pedras facetadas nas encostas, 1.281 seixos na beira da rua, 467 tufos de flores, 4.802 folhas secas, 29 poças reflexivas, capim 3x mais denso (`tools/detalhes.gd`).
- O bake pegou 25 "peças soltas" (a plaquinha do número da casa estava afastada da parede): corrigido, 0. A auditoria de peças achou barris atravessando o carro coberto: agora o lugar dos carros é reservado. Tudo em 0.
- Catálogo completo: `docs/14-mapeamento-de-detalhes.md`.

## 10. Ruas, becos, assets novos, desempenho e jogabilidade (v11)
- **Rua** mais longa (343 → 392 m) e com mais curvas; as constantes de adro, igreja e larguras foram reescaladas. Raio mínimo 21 m na parte com casas.
- **17 becos** (12 sobem até a porta, 5 sem saída). O teste dos becos achou um bug real: uma casa vizinha invadia o beco (o jogador parava a 4,8 m). Corrigido (casas perto de becos ficam rasas e as casas seguintes respeitam a "pegada" do beco).
- **14 interiores**, 21 modelos novos integrados, plantas reais no solo, esconderijos (`--selftest-esconder`).
- **Desempenho (Forward+, Qualidade Média, mesmo ponto de vista no software):** chamadas de desenho **2.515 → 1.935** (-23%) e triângulos **3,6 M → 1,6 M**, por: oclusão por casa (OccluderInstance3D), alcances de visibilidade ajustados à neblina, detalhes sem sombra, FXAA no lugar de MSAA, GI/SSIL/SSR/TAA só na Alta, névoa volumétrica em resolução menor, resolução de renderização com FSR 2. **Padrão agora é Média**; F3 mostra FPS.

## 11. Kit de fachada modelado no Blender (v12)
- `tools/blender/kit_colonial.py` modela por script (bisel, ripas, balaústres torneados) 8 módulos em `assets/models/kit/`: janela com guarnição de pedra e caixilho de 6 vidros, veneziana (e espelhada), porta dupla com almofadas, sacada com balaústres, cornija com dentículos, cachorro de beiral e chaminé. O jogo os usa em todas as casas (`tools/kit.gd`, `MeshBatch.malha`).
- Telhado agora em "capa e canal" (superfície ondulada em 3 fiadas) em vez de plano liso.
- São modelos **procedurais**, melhores que caixas, mas não são fotogrametria como os do Poly Haven.
- Testes: caminhada (centro e bordas), 17 becos, casas, itens, fuga e auditorias, todos em 0 problemas.
