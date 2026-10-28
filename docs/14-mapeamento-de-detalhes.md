# Mapeamento de detalhes do jogo (o que existe, quanto, e o que falta)

Cada linha: **detalhe**, **quantidade/onde** hoje, **status** (✅ feito · 🟡 parcial · ⬜ falta) e **como melhorar**.
Os números vêm do bake (`[vila] detalhes:`) e das ferramentas de teste; se mudarem, rode o bake e atualize.

## 1. Casas (fachadas)
| Detalhe | Hoje | Status | Como melhorar |
|---|---|---|---|
| Reboco com variação de cor (8 tintas) | todas | ✅ | texturas fotográficas de reboco (ambientCG `Plaster*`) |
| Embasamento de pedra real (Poly Haven) | todas | ✅ | pedra com alturas irregulares e musgo |
| Janelas com moldura de pedra, peitoril, vidro de luz/noite, caixilho | todas | ✅ | modelos de janela com almofadas e vidro refletivo |
| **Venezianas de madeira abertas em ângulo** (novo) | ~55% das janelas | ✅ | animar com vento; fechar à noite |
| **Jardineiras e vasos com flores** (novo) | ~30% das janelas | ✅ | variar plantas (samambaia, avenca) |
| Portas (duas folhas, painéis), soleira, **degrau, número, aldrava** (novo) | todas | ✅ | portas modeladas que abrem |
| Portas de arco de cantaria | ~50% | ✅ | folhas curvas modeladas |
| Sacadas com guarda-corpo de ferro/madeira, mísulas, vasos | casas com 2 andares | ✅ | ferro forjado trabalhado |
| Beiral com cachorros, calha e tubo de queda | todas | ✅ | calhas amassadas e ferrugem |
| Telhado com telha por UV, cumeeira, forro | todas | ✅ | telhas individuais (MultiMesh) perto da câmera; telhas quebradas e musgo |
| Chaminé de pedra com tampa | ~40% | ✅ | fumaça animada em algumas |
| Placas de comércio com emblema (pão, bota, ferradura...) | ~22% | ✅ | letras em relevo, ferro forjado |
| **Decalque de sujeira (pé da parede) e umidade** | todas / ~60% | ✅ | normal map de rachaduras |
| **Decalque de reboco caído (mostra tijolo e pedra)** (novo) | ~50% das casas, 1 a 2 pontos | ✅ | variar tijolo/pau a pique |
| Lampião de parede aceso na porta das casas visitáveis | 6 | ✅ | — |
| Hera na parede de quintais | quintais | ✅ | hera 3D com folhas individuais |
| Cabos elétricos, caixa de luz, relógio de energia (1961) | 0 | ⬜ | poste e fios modelados |
| Cortinas e vultos nas janelas acesas | janelas acesas | 🟡 | cortina animada pelo vento |
| Gato no telhado/janela, pombos, morcegos | 0 | ⬜ | modelos animais + som |
| Varal com roupa | trechos | ✅ | roupa balançando |

## 2. Rua e calçamento
| Detalhe | Hoje | Status | Como melhorar |
|---|---|---|---|
| Pé-de-moleque (pedras arredondadas, juntas com musgo, cor por vértice) | toda a rua | ✅ | pedras individuais modeladas perto do jogador (displacement) |
| Meio-fio com chanfro e sarjeta | toda | ✅ | — |
| **Folhas secas** (novo) | 4.802 | ✅ | acumulam nas sarjetas; vento as move |
| **Seixos** (novo) | 1.281 | ✅ | cascalho nos becos |
| **Poças reflexivas** (novo) | 29 | ✅ | ondulação com chuva; reflexo da lanterna |
| Bueiros de ferro | 7 | ✅ | vapor/água escorrendo |
| Lixo (papel, latas, caixotes, cacos) | caixotes | 🟡 | decalques e props pequenos |
| Pegadas e marcas de roda | 0 | ⬜ | decalques |
| Degraus de pedra nos becos (36 degraus, 14 becos) | ✅ | ✅ | musgo e desgaste nas bordas |
| Esgoto/água escorrendo no meio da rua | 0 | ⬜ | filete de água em shader |

## 3. Natureza
| Detalhe | Hoje | Status | Como melhorar |
|---|---|---|---|
| Árvores (cartões com folhagem, 3 espécies) | ~1.585 | 🟡 | árvores modeladas (Poly Haven/Sketchfab), tronco com casca ✅ |
| Palmeiras e bananeiras | 115+ | 🟡 | modelos com folhas 3D |
| **Capim em tufos** | 2.816 (antes 900) | ✅ | mais espécies, capim alto no vento |
| **Flores silvestres** (novo) | 467 tufos × 6 flores | ✅ | cores por estação; abelhas |
| **Pedras soltas facetadas** (novo) | 780 nas encostas | ✅ | rochas com musgo, afloramentos grandes |
| Arbustos de Poly Haven (rooibos) e troncos mortos | 26 + 7 | ✅ | mais variedade |
| Samambaias, hera, trepadeiras caindo | pouco | 🟡 | trepadeiras em muros e árvores |
| Raízes aparentes, tocos, galhos caídos | 0 | ⬜ | props pequenos |
| Cogumelos, líquen, musgo em pedras | musgo no calçamento | 🟡 | decalques e instâncias |
| Vaga-lumes, borboletas noturnas, morcegos | 0 | ⬜ | partículas |
| Vento em folhagem (shader) | 0 | ⬜ | vertex shader balançando |
| Chuva e relâmpago | chuva opcional ✅ | 🟡 | poças reagindo, relâmpago, névoa variável |

## 4. Solo e terreno
| Detalhe | Hoje | Status | Como melhorar |
|---|---|---|---|
| 4 camadas de textura (plano, íngreme, grama, barro) | encostas | ✅ | mais camadas (cascalho, folhas), mistura por altura |
| Barro vermelho de Minas no pé dos muros e quintais | ✅ | ✅ | trilhas gastas |
| Trilhas de pé (caminhos nas encostas) | 0 | ⬜ | decalque/camada de terra batida |
| Folhas e galhos sob árvores | 0 | ⬜ | camada de serapilheira em shader |
| Pedras e seixos no leito do riacho | pouco | 🟡 | seixos submersos, areia |
| Água do riacho (shader, queda) | ✅ | 🟡 | espuma, reflexo, som por trecho |
| Serra ao fundo | ✅ | ✅ | camadas de névoa, mais picos |

## 5. Adro, igreja e monumentos
| Detalhe | Hoje | Status | Como melhorar |
|---|---|---|---|
| Fachada barroca (portal, óculo, frontão, torres, sineiras) | ✅ | 🟡 | modelo escultural real |
| Cruzeiro, estátua em pedestal | ✅ | ✅ | musgo e desgaste |
| Interior da igreja (bancos, altar, retábulo, velas) | ✅ | 🟡 | retábulo esculpido, imagens, vitrais |
| Sino, torre, coro, sacristia | 0 | ⬜ | fase da torre |
| Cemitério da Irmandade | 0 | ⬜ | Ato III |

## 6. Interiores (7 salas)
| Detalhe | Hoje | Status | Como melhorar |
|---|---|---|---|
| Piso, teto com vigas, rodapé, janelas com luar | todas | ✅ | texturas fotográficas, frestas de luz |
| Móveis (cama, mesa, cadeiras, armário, balcão, fogão, forno) | por sala | ✅ | modelos com desgaste |
| Objetos pegáveis (querosene, cartas, chaves, livro, terço) | 20+ | ✅ | animação de pegar |
| Decoração de época (oratório, quadros, calendário 1961, rádio) | oratório, quadros | 🟡 | 40+ objetos por sala |
| Fotos de família, jornais, cartas na parede | 3 | 🟡 | decalques de papel |
| Comida, louça, panelas, garrafas | garrafas | 🟡 | props |
| Teias, poeira em raios de luz, mofo (casarão) | 0 | ⬜ | partículas e decalques |
| Portas internas, segundo andar, porão | 0 | ⬜ | M2 do roteiro |

## 7. Objetos de época (1961)
| Detalhe | Hoje | Status |
|---|---|---|
| TV ligada com estática (bar e venda) | 2 | ✅ |
| Carros cobertos com lona | 2 | ✅ |
| Postes e lampiões de ferro (Poly Haven) | dezenas | ✅ |
| Barris, banquinhos, baldes, aros de roda, bola | 40+ | ✅ |
| Rádio de válvula, relógio, máquina de costura | 0 | ⬜ |
| Fusca, Rural, Kombi, jipe (conferir época) | 0 | ⬜ |
| Cartazes e propagandas de época | 0 | ⬜ |

## 8. Efeitos, luz e atmosfera
| Detalhe | Hoje | Status |
|---|---|---|
| Névoa volumétrica, GI, SSR, AO, TAA (Forward+) | ✅ | ✅ |
| Lua, estrelas redondas, nuvens | ✅ | ✅ |
| Halos de luz, lanterna com chama e vacilo | ✅ | ✅ |
| Chuva com som | opcional | 🟡 |
| Relâmpago, vento visível, fumaça, vapor | 0 | ⬜ |
| Poeira e insetos nas luzes | 0 | ⬜ |
| Gotas na tela, lente suja | 0 | ⬜ |

## 9. Densidade alvo (regra de bolso)
- **A cada 10 m de rua:** 8 a 12 detalhes pequenos visíveis (folhas, seixos, flores, um objeto de época, uma mancha, uma planta).
- **A cada casa:** pelo menos 6 detalhes únicos (veneziana, jardineira, decalque, número, objeto na porta, planta).
- **Nada se repete lado a lado** (rodar, espelhar, variar cor e escala).
- Orçamento: manter **≤ 3,5 M de triângulos** e **≤ 3.000 chamadas de desenho** na pior vista (`F3` mostra).

## 10. Como adicionar um detalhe novo
1. Em `tools/detalhes.gd`: crie a malha e o espalhamento (use `_mmi`, `_ponto`, `b.terrain_h`, `b._livre`).
2. Material em `tools/bake.gd`; textura (se precisar) em `tools/gen_textures.gd`.
3. Rode `bash rebuild` (gen_textures → import → bake → import), depois `--selftest-walk`, `auditoria_geom`, `auditoria_pecas` e fotografe.

## 11. Atualização v11 (ruas, becos, assets novos)
| Detalhe | Hoje | Status |
|---|---|---|
| Rua mais longa e curva (392 m, raio mínimo ~21 m, subida até 11° no máx.) | ✅ | ✅ |
| 17 becos: 12 que sobem até a porta do alto + **5 becos sem saída** (portão de ferro trancado, casa com porta na lateral, querosene, esconderijo) | ✅ | ✅ |
| 13 casas visitáveis + igreja (14 interiores): carpintaria, escola, ferraria, casa abandonada, pensão, costureira, depósito, e as 7 antigas ampliadas | ✅ | ✅ |
| Móveis reais nos interiores: armário gótico, mesa de centro, divã, mesa redonda, cama velha, estante de metal, lousa | ✅ | ✅ |
| Ferramentas e utilidades reais: escadas encostadas, machados, regadores, serrote, plaina, binóculo, cigarros, latas, papelaria | ✅ | ✅ |
| Plantas reais: 7 variantes (vinca, erva, tufos de capim) em ~4.300 instâncias | ✅ | ✅ |
| Portão de ferro nos quintais (50%) | ✅ | ✅ |
| Esconderijos: 2 carros + 5 becos sem saída | ✅ | ✅ |
| Musgo (moss_01) | recebido, falta método (fios finos) | ⬜ |

## 12. Atualização v13 (ladeira da igreja em zigue-zague e becos de atalho)
| Detalhe | Hoje | Status |
|---|---|---|
| Ladeira da igreja em **zigue-zague**: duas curvas de ~180° (raio ~13 m) entre três "pernas" ~22 m afastadas (rota de 458 m; igreja em s=445) | ✅ | ✅ |
| **2 becos de atalho** (`PASSAGENS` em `tools/vila_builder.gd`): corredores de pedra com escada e patamares, arcos nas duas bocas e lampiões, ligando uma perna da ladeira à de cima. *Atalho do Sino*: 80 m de rua viram ~21 m de escada (sobe ~8 m). *Atalho da Fonte*: ~66 m viram ~20 m (sobe ~2 m) | ✅ | ✅ |
| Descida também funciona (o teste `--selftest-becos` sobe e desce cada atalho) | ✅ | ✅ |
| Terreno entalhado sob o corredor; casas/quintais/árvores/morro não invadem o vão | ✅ | ✅ |
| Nas curvas fechadas, lote em que a casa não cabe vira quintal murado | ✅ | ✅ |
| Mais atalhos (rota alternativa para fugir do Bradador, atalhos que abrem só com item/chave) | | ⬜ |

**Como criar mais atalhos:** acrescente em `PASSAGENS` `{"id": "...", "a": [s_baixo, lado], "b": [s_alto, lado]}` (lado -1 = esquerda de quem sobe, +1 = direita). Boa corda: 14 a 28 m, trecho de rua entre as bocas ≥ 2,5× a corda, subida ≤ 9 m. Evite lados internos de outros becos em escada (`ALLEYS`) e casas de `ENTRADAS` a menos de 12 m de uma boca. Rode `bash rebuild`, `--selftest-becos`, `--selftest-walk` e `auditoria_geom`.

## 13. Atualização v14 (matos reais, recipientes, braços, edição no Godot)
| Detalhe | Hoje | Status |
|---|---|---|
| **Matos reais** (Tiny Weeds 3, CC0) no lugar do capim de cartão: 3 modelos recortados, ~7.000 instâncias (encostas, pé das paredes, frestas da rua) | ✅ | ✅ |
| Plantas de lote (`arbusto`, `capim`, `samambaia` em quintais, becos, taludes) trocadas por mato/vinca/tufo **reais** (sem a moita de 16 mil triângulos) | ✅ | ✅ |
| **Hera real** (5 peças) no lugar dos cartões verdes dos muros | ✅ | ✅ |
| Árvores, palmeiras e bananeiras **ainda são cartões** (não há modelo real delas) | | ⬜ |
| **Medieval Containers** (CC0): barris, caixotes empilhados, cestos, jarros, sacos e baldes nas ruas (44 grupos) e nos interiores (depósito, venda, sacos) | ✅ | ✅ |
| **Braços em primeira pessoa** segurando a lanterna (IK de 2 ossos, dedos curvados); mão esquerda relaxada | ✅ | ✅ |
| Animações dos braços (abrir porta, pegar item, correr) | | ⬜ |
| Camada manual `scenes/ajustes.tscn` + `ZonaLimpa` para editar no Godot sem perder nada no bake (`docs/17`) | ✅ | ✅ |

## 14. Atualização v15 (modo de teste, texturas misturadas, mais realismo)
| Detalhe | Hoje | Status |
|---|---|---|
| **Modo de teste (imortal)**: Bradador e Mula não te matam, só avisam. Liga em Opções, com a tecla **F9** no jogo ou com `--modo-teste`. O modo normal é o padrão; os testes automáticos sempre usam o normal | ✅ | ✅ |
| **Paredes com textura mista** (shader `superficie_mista`): reboco novo + reboco velho em manchas, umidade em escorridos e variação de cor por parede, mapas de normal triplanares | ✅ | ✅ |
| **Pisos e portas**: madeira + poeira/barro seco; quintais: barro vermelho com tufos de grama e musgo (Ground054 + Ground037) | ✅ | ✅ |
| **Musgo em manchas** por cima de telhados, muros e cantaria (shader `sobreposicao`, mais nas faces voltadas para cima) | ✅ | ✅ |
| Todas as texturas ambientCG/Poly Haven enviadas estão em uso (Bark014, Ground028/037/054/108, Metal047B/053C, Wood028/035, stone_wall_04) | ✅ | ✅ |
| **Postes de madeira com cruzeta, isoladores, transformador e fios** (catenária) | ✅ | ✅ |
| **Fumaça de chaminé** (~40% das chaminés), **vaga-lumes** em volta do jogador, **morcegos** sobre o adro | ✅ | ✅ |
| **Cogumelos** (700) e **galhos caídos** (220, o tronco morto do Poly Haven em escala pequena) | ✅ | ✅ |
| Limpeza: pedras e plantas das encostas não nascem mais em cima da rua nas curvas fechadas (`tools/auditoria_lugar.gd`: 0 na rua, 0 flutuando) | ✅ | ✅ |
| Gato, cachorro, pombos, roupas animadas, cortinas ao vento | | ⬜ |
