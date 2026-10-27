# Mapeamento geral: tudo que um jogo de terror completo precisa

Lista mestra para você conferir (e para a IA do `docs/13` seguir). Status: ✅ feito e testado · 🟡 parcial/placeholder · ⬜ falta.
Prioridade: **P1** obrigatório para lançar · **P2** deixa o jogo muito melhor · **P3** polimento.

## 0. Sobre "mais realista que Resident Evil 8" (leia primeiro)
RE Village usa um motor próprio (RE Engine), **fotogrametria** (objetos escaneados do mundo real), personagens esculpidos por equipes de dezenas de artistas, captura de movimento e anos de produção. Nenhum código por si só chega lá. O caminho **grátis e real** para chegar o mais perto possível:
1. **Modelos e texturas fotorrealistas prontos** (Poly Haven, ambientCG, Quixel/Fab, Sketchfab CC): é o que mais pesa. Ver `docs/09`.
2. **Forward+ com iluminação global, neblina volumétrica, reflexos, AO** ✅ (já ligado). Falta: chuva, poças, relâmpago, raios de luz.
3. **Personagens de alta qualidade** (Bradador, Mula, moradores) esculpidos/escaneados + animação por captura (Mixamo) + rosto expressivo.
4. **Pós-processo cinematográfico** (granulado de filme, aberração sutil, profundidade de campo, correção de cor, bloom).
5. **Áudio espacial profissional** (gravado, com oclusão e reverb por ambiente).
6. Uma equipe pequena (artista 3D, animador, sonoplasta, dublagem). Sem isso, o teto é "muito bom para indie", não "igual a AAA".
Nenhuma promessa de igualar RE8; a meta honesta é **parecer um indie de terror premiado** (como "Visage", "Layers of Fear", "Silent Hill: The Short Message"), e isso é alcançável.

---

## 1. Núcleo de jogo (loop e sistemas)
| # | Item | Status | P |
|---|---|---|---|
| 1 | Movimento 1ª pessoa, correr, agachar, fôlego | ✅ | P1 |
| 2 | Lanterna com querosene que acaba e tremula | ✅ | P1 |
| 3 | Interação (E) com dica na tela | ✅ | P1 |
| 4 | Inventário visual (hoje só texto no canto) | 🟡 | P1 |
| 5 | Objetivo atual na tela | ✅ | P1 |
| 6 | Diário/log de notas lidas (tecla J reabre as cartas) | ✅ | P1 |
| 7 | Portas que abrem com animação (hoje teleporte com fade) | 🟡 | P2 |
| 8 | Portas trancadas e chaves ✅; cadeados/combinações | 🟡 | P2 |
| 9 | Salvar/continuar (autosave) | ✅ | P1 |
| 10 | Múltiplos slots de save, carregar do menu | ⬜ | P3 |
| 11 | Checkpoints por ato (autosave ao pegar item, entrar/sair de casa e a cada minuto; morrer volta ao último save) | 🟡 | P1 |
| 12 | Esconder-se (armário, baú, cama, barril) | ⬜ | P1 |
| 13 | Gerenciamento de recurso (querosene, giz, terço) | 🟡 | P2 |
| 14 | Puzzles (chaves ✅, sino, lápides, alavancas) | 🟡 | P1 |
| 15 | Dicas opcionais (sistema de ajuda) | ⬜ | P2 |
| 16 | Dificuldades (fácil, normal, difícil) | ⬜ | P2 |
| 17 | Tutorial integrado ao prólogo | 🟡 | P1 |
| 18 | Contador de FPS (F3) ✅ e opções de desempenho | 🟡 | P2 |
| 19 | Modo foto | ⬜ | P3 |
| 20 | Conquistas | ⬜ | P3 |
| 21 | Estatísticas e tela de resultados | ⬜ | P3 |
| 22 | Rejogabilidade (novo jogo+, finais) | ⬜ | P2 |

## 2. Inimigos e IA
| # | Item | Status | P |
|---|---|---|---|
| 23 | Bradador: estágios, gritos, olhar proibido, passos | ✅ | P1 |
| 24 | Bradador com modelo realista e animações (andar, gritar, correr) | 🟡 | P1 |
| 25 | Bradador com IA de perseguição real (NavigationAgent3D) | ⬜ | P1 |
| 26 | Mula-sem-cabeça (regra da luz) ✅ com modelo realista | 🟡 | P1 |
| 27 | Corpo-seco (lento, sente passos, não pisa em chão benzido) | ⬜ | P1 |
| 28 | Pisadeira (paralisia do sono) | ⬜ | P2 |
| 29 | Lobisomem / Saci / Cuca (opcionais, com fonte séria) | ⬜ | P3 |
| 30 | Vultos nas janelas ✅ | ✅ | P2 |
| 31 | Sistema de audição e visão da IA (cone de visão, ruído) | 🟡 | P1 |
| 32 | Direção de IA (ritmo de tensão e alívio) | 🟡 | P2 |
| 33 | Sustos "virais" roteirizados (eco, espelho, TV) | 🟡 | P1 |

## 3. Mundo e níveis
| # | Item | Status | P |
|---|---|---|---|
| 34 | Rua Direita, 14 becos, ponte, largo, adro | ✅ | P1 |
| 35 | 7 interiores ✅; faltam ~10+ | 🟡 | P1 |
| 36 | 2º andar e porão nas casas | ⬜ | P2 |
| 37 | Mina do Capataz (fase nova) | ⬜ | P1 |
| 38 | Cemitério e capela do Rosário | ⬜ | P1 |
| 39 | 2ª ladeira / ruas altas | ⬜ | P2 |
| 40 | Igreja: sacristia, torre do sino, coro | ⬜ | P1 |
| 41 | Rio e ponte com água realista (reflexo, espuma) | 🟡 | P2 |
| 42 | Vegetação realista (árvores modeladas, folhas 3D) | 🟡 | P1 |
| 43 | Animais ambientais (gatos, cães, morcegos, corujas, galinhas) | ⬜ | P2 |
| 44 | Moradores como silhuetas/vultos respeitosos | ⬜ | P2 |
| 45 | Mortos/ossadas sem estereótipo (cena do cemitério) | ⬜ | P3 |
| 46 | Ciclo de tempo (anoitecer, amanhecer final) | ⬜ | P2 |
| 47 | Clima: chuva ✅ (opção no menu); falta neblina variável, relâmpago, vento em folhas | 🟡 | P1 |
| 48 | Cenário vivo (roupa no varal balançando, fumaça de chaminé, cortinas) | 🟡 | P2 |

## 4. Arte (visual)
| # | Item | Status | P |
|---|---|---|---|
| 49 | Forward+: GI, névoa volumétrica, SSR, AO, TAA | ✅ | P1 |
| 50 | Decalques de sujeira/umidade nas fachadas | ✅ | P2 |
| 51 | Decalques de rachaduras, musgo, cartazes, grafites antigos, folhas no chão | ⬜ | P2 |
| 52 | **Casas modeladas por artista** (hoje: caixas com detalhes) | ⬜ | **P1** |
| 53 | **Igreja barroca modelada** | ⬜ | **P1** |
| 54 | **Bradador, Mula e moradores modelados** | ⬜ | **P1** |
| 55 | Texturas fotográficas PBR em tudo (reboco, telha, madeira, pedra, ferro) | 🟡 | P1 |
| 56 | Telhas individuais, beirais, calhas, chaminés reais | ⬜ | P2 |
| 57 | Portas e janelas modeladas com vidro, ferragens, almofadas | ⬜ | P1 |
| 58 | Postes de madeira, fios elétricos, isoladores (1961) | ⬜ | P2 |
| 59 | Veículos de época (Fusca, Rural, Kombi, jipe) | 🟡 | P2 |
| 60 | Objetos de época (rádio de válvula, lampiões, máquinas de costura) | 🟡 | P2 |
| 61 | Letreiros e cartazes de época (propagandas, jornais) | 🟡 | P3 |
| 62 | Iluminação de interiores por cômodo (cada casa com personalidade) | 🟡 | P1 |
| 63 | Lightmaps cozidos / probes de reflexo (VoxelGI/LightmapGI) | ⬜ | P2 |
| 64 | Oclusão e LOD de todos os modelos | ⬜ | P1 |
| 65 | Pós-processo cinematográfico (DoF, granulado de filme, LUT, bloom) | 🟡 | P2 |
| 66 | Estilo de câmera: leve respiração, mãos do personagem, lanterna física | 🟡 | P2 |
| 67 | Mãos/braços do jogador animados | ⬜ | P1 |
| 68 | Sombras suaves e de contato nas lanternas | 🟡 | P2 |

## 5. Animação e cinemática
| # | Item | Status | P |
|---|---|---|---|
| 69 | Animação do Bradador/Mula (idle, andar, gritar, atacar) | ⬜ | P1 |
| 70 | Animação de portas, gavetas, sino, cortinas | ⬜ | P2 |
| 71 | Cutscenes (abertura, mortes, final) | ⬜ | P1 |
| 72 | Câmera de morte (jumpscare final) refinada | 🟡 | P2 |
| 73 | Legendas sincronizadas | ⬜ | P1 |

## 6. Áudio
| # | Item | Status | P |
|---|---|---|---|
| 74 | Ambiente em camadas, medo, batimento | 🟡 (sintetizado) | P1 |
| 75 | **Sons reais** (vento, grilos, sino, passos, portas, fogo, rádio) | ⬜ | **P1** |
| 76 | **Grito do Bradador gravado** | ⬜ | **P1** |
| 77 | Dublagem PT-BR mineira (Tomé, Benedita, Tobias, Zé) | ⬜ | P1 |
| 78 | Reverb e oclusão por ambiente (rua, casa, igreja, mina) | 🟡 | P1 |
| 79 | Passos por superfície (pedra, madeira, terra, água) | 🟡 | P2 |
| 80 | Mixagem final e masterização | ⬜ | P2 |
| 81 | Música mínima e adaptativa | ⬜ | P2 |
| 82 | Áudio 3D com HRTF/fones | 🟡 | P2 |

## 7. Interface e acessibilidade
| # | Item | Status | P |
|---|---|---|---|
| 83 | Menu inicial/pausa/opções/continuar | ✅ | P1 |
| 84 | Remapear teclas | ⬜ | P1 |
| 85 | Gamepad completo | ⬜ | P1 |
| 86 | Legendas e descrição de sons ("[galope distante]") | ⬜ | P1 |
| 87 | Modo daltônico, tamanho de fonte, contraste | ⬜ | P2 |
| 88 | Aviso de gatilhos/sensibilidade (escravidão, violência) | ⬜ | P1 |
| 89 | Idiomas (PT-BR, EN, ES) | ⬜ | P2 |
| 90 | Tela de carregamento e logo | ⬜ | P2 |
| 91 | HUD diegético (lanterna no mundo; sem barras) | 🟡 | P2 |
| 92 | Mapa/diário descritivo (sem minimapa) | ⬜ | P2 |

## 8. Técnico e qualidade
| # | Item | Status | P |
|---|---|---|---|
| 93 | Testes automáticos (rua, becos, casas, itens, Mula, save, auditorias) | ✅ | P1 |
| 94 | Teste de 2 horas completo com bot | ⬜ | P1 |
| 95 | Desempenho medido em PC real (60 fps na RTX 2060) | ⬜ | P1 |
| 96 | Exportar .exe (Windows) e testar em outro PC | ⬜ | P1 |
| 97 | Perfis de qualidade (Baixa/Média/Alta/Ultra) | 🟡 | P1 |
| 98 | Streaming de áreas (carregar mina/cemitério sob demanda) | ⬜ | P2 |
| 99 | Tratamento de erros e log de crash | ⬜ | P2 |
| 100 | Controle de versão (GitHub) | ✅ | P1 |
| 101 | Integração contínua (rodar testes a cada commit) | ⬜ | P3 |
| 102 | Teste com jogadores reais e telemetria (opcional, com consentimento) | ⬜ | P2 |

## 9. História e conteúdo
| # | Item | Status | P |
|---|---|---|---|
| 103 | Premissa, pilares, personagens (docs/10) | ✅ | P1 |
| 104 | Roteiro completo com diálogos (4 atos) | ⬜ | P1 |
| 105 | 12 cartas/documentos ✅; faltam ~30 | 🟡 | P1 |
| 106 | Fotografias, jornais e objetos que contam história | ⬜ | P2 |
| 107 | 3 finais com cenas | ⬜ | P1 |
| 108 | Consultoria: historiador de MG + pesquisadores de cultura afro-brasileira | ⬜ | **P1** |
| 109 | Revisão de linguagem/ortografia e regionalismos mineiros | ⬜ | P2 |

## 10. Lançamento
| # | Item | Status | P |
|---|---|---|---|
| 110 | Nome final, logotipo, ícone | ⬜ | P2 |
| 111 | Trailer, capturas, página Steam/itch.io | ⬜ | P2 |
| 112 | Demo (Steam Next Fest) | ⬜ | P2 |
| 113 | Licença do jogo, EULA, créditos de assets (assets/CREDITOS.md ✅) | 🟡 | P1 |
| 114 | Classificação indicativa, aviso de conteúdo | ⬜ | P1 |
| 115 | Marketing: clipes de susto, comunidade | ⬜ | P3 |
| 116 | Imprensa/influenciadores de terror brasileiros | ⬜ | P3 |

---

## 11. Detalhes minuciosos que costumam faltar (cheque um por um)
**Imersão**
- Mãos do personagem e lanterna física com peso e sombra; ao correr a lanterna balança ✅ (parcial).
- Respiração e passos do jogador sincronizados com cansaço ✅ (parcial).
- Lanterna que ilumina com falhas quando o medo sobe ✅.
- Objetos pegáveis e arremessáveis (garrafas, pedras) para distrair o monstro.
- Objetos com física (cadeiras, baldes, portas que o Bradador derruba).
- Água que ondula quando passa, poças que refletem a lanterna.
- Respingos de chuva em superfícies, gotas na tela com a lanterna, névoa que se abre ao andar.
- Vento que move cortinas, roupas, folhas e a chama das velas.
- Portas que rangem diferente (madeira, ferro, vidro), gavetas com ruído.
- Papéis que flutuam quando uma porta se abre.
- Relógios, sinos e rádio com horário coerente (história no som).
- Diferença sonora de ambientes: dentro de casa abafado, na rua eco, na igreja reverb longo.
**Mundo coerente**
- Pegadas e rastros do que o jogador mexeu; portas que ficam abertas.
- Mensagens ambientais (grafite de giz, orações na parede, marcas do Rosário).
- Cada casa com vida: comida na mesa, cama desfeita, rádio ligado, fotos de família, santo no oratório.
- Placas e letreiros com nomes de época; calendários de 1961; moedas de cruzeiro.
- Objetos "fora do lugar" que avisam o perigo (cadeira virada, vela apagada).
**Jogabilidade polida**
- Zero travamentos em escada/curva (testes ✅), zero buracos ✅, zero peça solta ✅.
- Tempo de resposta do monstro justo e legível; dica sonora antes de cada perigo.
- Perda de progresso nunca maior que 5 minutos.
- Pausa que realmente congela áudio e IA.
- Aviso quando o jogador está sem querosene (lanterna apagando).
**Técnico**
- Texturas com mipmaps e compressão; modelos com LODs; sombras em cascata ajustadas.
- Perfis para PC fraco; resolução dinâmica (FSR) ✅ opção; Vsync e limite de FPS.
- Logs de erro e relatório automático dos testes.
**Ética e sensibilidade**
- Pessoas escravizadas com nome e dignidade; nunca como monstros; violência mostrada com respeito.
- Aviso de gatilhos no início; revisão externa; ficha de agradecimentos às consultorias.
