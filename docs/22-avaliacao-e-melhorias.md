# Avaliação do jogo: pontos negativos, pesquisa e o que melhorar

## 1. Como foi feita a avaliação
- Fotos do jogo em posições-alvo (portas, altares, becos, adro, igreja), auditorias automáticas (`tools/auditoria_*.gd`) e a bateria de testes de jogo.
- Pesquisa na internet sobre o que costuma dar errado em jogos de terror em primeira pessoa sem combate (os chamados "walking simulators") e o que funciona em jogos de referência (Alien: Isolation, Amnesia, Gone Home).
- Ressalva honesta: as fontes abaixo são, em sua maioria, ensaios, resenhas e blogs de desenvolvedores, não manuais oficiais. Servem como ideias, não como regras.

## 2. O que a pesquisa diz (resumo)
- **Ritmo, orientação e história são os três riscos** de jogos sem combate: longos trechos de caminhada sem nada para ver, o jogador sem saber para onde ir, e pouca história contada pelo cenário ([Entalto Studios](https://entaltostudios.com/what-makes-a-great-walking-simulator/), [Walking Simulator Research](https://oss.adm.ntu.edu.sg/kchin005/interactive-environments-walking-simulator-research/)).
- **Gravações/bilhetes demais viram preguiça de design.** Contar a história só por texto lido deixa o jogador como "turista". Melhor: o cenário contar a história e o jogador ter o que fazer com as mãos ([The Genius of Gone Home](https://mechanicsofmagic.com/2021/04/28/the-genius-of-gone-home/)).
- **Explorar fora do caminho tem que ser recompensado**: cantos escondidos devem revelar história, não só parecer abertos ([Critical Play: Walking Simulators](https://mechanicsofmagic.com/2026/04/23/critical-play-walking-simulators-dear-esther-4/)).
- **Som é a base do terror.** Um crítico atribui a Remothered o sucesso ao som, apesar de roteiro mais fraco ([Horror game clichés](https://www.pcgamer.com/horror-game-clichs-that-need-to-stop) e resenhas).
- **Imprevisibilidade e morte justa** (Alien: Isolation): o medo vem de uma ameaça que reage, e a morte nunca parece injusta ([Game Developer](https://www.gamedeveloper.com/design/fear-in-unpredictability-i-alien-isolation-i-s-brand-of-survival-horror), [Frictional Games](https://frictionalgames.blogspot.com/2019/10/9-years-9-lessons-on-horror.html)).
- **Clichês de susto cansam** (cano rangendo, vulto na janela repetido). Prefira o susto que a história justifica.

## 3. Pontos negativos do BRADADOR (nossa avaliação)
| # | Problema | Gravidade | O que foi feito nesta rodada |
|---|----------|-----------|------------------------------|
| 1 | O jogador só caminha e lê bilhetes: poucas ações com as mãos | Alta | Objetos para **examinar** nas casas (cada um conta um pedaço da história) e **velas para acender** nos altares |
| 2 | Altares de rua sem função, só enfeite | Média | Acender a vela acalma o jogador e faz o Bradador **recuar um passo** (uma vez por altar) |
| 3 | O Bradador era só um grito distante, sem presença sonora | Alta | **Passos pesados e arrastados** vindos dele, **arranhões** nas paredes e **rosnado** quando está perto |
| 4 | Ler bilhetes ao ar livre era seguro demais | Média | Ler fora de casa agora é **arriscado**: depois de poucos segundos ele se aproxima (em casa ou escondido é seguro) |
| 5 | Portas em arco viravam um buraco preto | Média | Portas coloridas, com tábuas e cintas de ferro, e bandeira em arco com vidro aceso |
| 6 | Letras das placas dependiam da fonte do computador | Média | Fonte **Playfair Display SC** (licença livre) vai junto no projeto |
| 7 | Vasos de flor feitos por código, feios | Média | Vasos de barro do modelo enviado (`planter_pot_clay`) nos peitoris e sacadas |
| 8 | Alguns modelos eram "folhas de catálogo" (lápis empilhados, latas lado a lado, malas coladas) | Média | Cada peça agora é usada **separada**: lápis, canetas, borracha, copo, latas, castiçais e malas |
| 9 | Sombras serrilhadas e duras | Média | Sombra da lua em 2 cascatas, borda macia, mapa 4096 e filtro suave |
| 10 | Rua principal reta e sobe o morro sem variar | Média | Curva grande no começo (rua 25 m mais longa) |
| 11 | Adro e igreja sem elementos ao redor | Média | Coreto, ciprestes, lajedo, chafariz, velas, quadro de avisos; igreja com portal em pedra-sabão, laterais e capela-mor |

## 4. O que ainda falta (próximas melhorias, em ordem)
1. **Mais objetos examináveis**: hoje há 10 em 4 casas. Meta: 3 em cada uma das 14 casas, cada um ligado à história principal.
2. **Quebra-cabeças simples ligados ao cenário**: por exemplo, acender as velas dos 7 altares na ordem do bilhete da Irmandade abre a sacristia.
3. **Mais variedade de susto**: portas que se abrem sozinhas, rádio que sintoniza uma voz, sombras que cruzam janelas, mas sempre com motivo na história.
4. **Missão por ambiente**: um objetivo claro por trecho da rua para evitar "longas caminhadas vazias".
5. **Recompensa por explorar becos**: um bilhete ou item em cada beco sem saída.
6. **Casas vistas por trás do muro**: acabamento nas laterais (janelas, quintais, varais, chaminés).
7. **Ruas falsas** (ruas laterais que parecem continuar e terminam em portão ou barricada).
8. **Testar na sua máquina**: FPS na RTX 2060, neblina volumétrica e sombras novas; enviar prints.

## 5. Como ler esta lista
Tudo na tabela da seção 3 está implementado **no código**. Parte foi vista em fotos; o que não foi visto está marcado nas notas de entrega. Nada aqui foi medido em placa de vídeo real.
