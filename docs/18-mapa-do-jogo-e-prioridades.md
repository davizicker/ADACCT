# Mapa do jogo inteiro: sistemas, testes e prioridades de bug (v18)

Este documento mapeia o BRADADOR de ponta a ponta, diz **como cada parte é testada** e lista o que foi achado,
corrigido e o que ainda está aberto, em ordem de prioridade.

## 1. O jogo em uma página

Uma noite de 1961 numa vila mineira inspirada em Ouro Preto. O jogador sobe uma ladeira em zigue-zague (cerca de
458 m de rua, 2 retornos em "U") até a igreja, enquanto o Bradador grita nas encostas.

| Sistema | Arquivo | O que faz |
|---|---|---|
| Jogador | `scripts/player.gd` | andar, correr (fôlego), agachar, lanterna com querosene, interação (E), braços em 1ª pessoa |
| Rota | `scripts/route.gd` | eixo da rua (posição, altura, largura, tangente por distância `s`) |
| Grito / Bradador | `scripts/scream_system.gd` | grito → janela de 3 s para agachar e ficar parado → estágios de proximidade → morte |
| Eventos | `scripts/event_director.gd`, `scripts/mula.gd` | Mula-sem-cabeça (apague a luz e entre num beco), apagão de lampiões, janela assombrada |
| Missão | `scripts/missao.gd` | entrar nas casas, itens, chave da igreja, livro, terço, igreja trancada |
| Esconderijos | `scripts/esconderijo.gd` | E atrás de carros e nos becos sem saída: o Bradador não vê nem ouve |
| Interface | `scripts/hud.gd`, `scripts/menu.gd`, `scripts/ajustes.gd` | medo, fôlego, bilhetes, menu, opções |
| Áudio | `scripts/audio_director.gd`, `scripts/synth.gd` | trilha e sons gerados por código; medo muda o som |
| Salvar | `scripts/save_game.gd` | continua do último ponto depois de morrer |
| Mundo | `tools/vila_builder.gd` (+ `bake.gd`) | gera `scenes/vila.scn`: casas, becos, ponte, rio, morros, plantas |

## 2. Como cada parte é testada (todos rodam sem jogador)

`godot --path . -- --selftest-XXX` (veja `scripts/main.gd`) e `godot --headless --script res://tools/auditoria_XXX.gd`.

| Teste | O que prova |
|---|---|
| `--selftest` | o grito evolui por estágios e termina em morte |
| `--selftest-auto` | responder certo a todos os gritos não mata (só a Mula mata se o jogador não se esconder) |
| `--selftest-walk` (centro, `--walk-offset=±1.5`) | dá para andar a rua inteira até a igreja |
| `--selftest-becos` | todos os becos e atalhos sobem e descem sem travar |
| `--selftest-escape` | o jogador não vaza para fora do mapa |
| `--selftest-casas` | entrar, andar e sair das 13 casas; trama completa (livro + chave) e igreja |
| `--selftest-itens` | pegar todos os 22 itens (querosene e bilhetes) |
| `--selftest-mula=rua` / `refugio` | a Mula mata na rua e não mata no refúgio escuro |
| `--selftest-esconder` | esconder-se não é penalizado e sai ao lugar |
| `--selftest-save` | salvar e continuar |
| `auditoria_geom.gd` | casas se atravessando, buracos no chão da rua |
| `auditoria_pecas.gd` | objetos flutuando, afundados ou se atravessando |
| `auditoria_caminho.gd` | o que bloqueia o corredor central de 2,6 m da rua (cápsula do tamanho do jogador) |
| `auditoria_portas.gd` | objetos na frente de cada porta |
| `auditoria_itens.gd` | colisões que se atravessam |
| `foto_tour.gd`, `foto_todas_portas.gd` | fotos da rua toda e da porta de cada casa |

## 3. Bugs de prioridade ALTA achados e corrigidos

1. **Casas sem porta** (várias): a porta era perdida na malha de detalhes do lote. Agora cada casa tem a porta como nó próprio (`Porta`). Verificado com foto das 64 portas.
2. **Casas "de papelão"**: o teste de colisão entre casas encurtava quase todas para 2,4 m de fundo. Agora só conta sobreposição real (a maioria tem 5,6 a 12 m).
3. **A Mula matava o jogador dentro de uma casa** (o interior fica a milhares de metros do eixo da rua, e o "ponto mais próximo da rua" desse lugar podia coincidir com a passagem da Mula). Agora, dentro de casa, a Mula não o julga.
4. **O Bradador reposicionava ou penalizava o jogador dentro de uma casa** (mesmo motivo). Agora a casa conta como esconderijo para o grito, os passos e o olhar, e o Bradador não é teletransportado enquanto o jogador está lá dentro.
5. **Sem resgate de queda**: um buraco no terreno travava a partida. Agora cair 14 m abaixo do último chão firme volta ao último ponto seguro.
6. **Escada de mão e quadro-negro bloqueavam o corredor** em ruas estreitas; **barril escondia o querosene** perto da ponte. Corrigidos; o corredor central só é bloqueado pela igreja (esperado).
7. **Mão esquerda com os dedos dobrando para trás**: agora dobra para a palma (`curvatura_dedos_esq`).
8. **O querosene no alto dos becos não aparecia para pegar**: a zona invisível de refúgio interceptava o raio da tecla E. Agora ela só detecta o jogador.
9. **O teste da Mula nunca julgava o jogador em quadros lentos** (ela "pulava" por cima dele): agora também conta ter cruzado a posição dele, o que vale no jogo real em quedas de FPS. Resultado do teste agora real: na rua morre, no refúgio escuro sobrevive.
10. **Beco_02 travava o jogador** (parede da casa vizinha entrava na escada): a casa logo antes de um beco agora encurta para não invadi-lo. Todos os becos passam no teste.
11. **4 portas com a quina da parede do beco na frente** (Casa_58, 82, 136, 175): a parede começa 0,4 m dentro da fachada. Auditoria de portas: 0 bloqueadas.
12. **Paredes dos becos em 4 degraus grandes (cara de Minecraft)**: agora são 14 degraus baixos.
13. Gatilho do esconderijo de carro girado com a rua, raio de interação (E) que ignora o corpo do próprio carro e visual "Cinematográfico" como padrão (SDFGI, SSIL, SSR, neblina volumétrica, foco, correção de cor).

## 4. Aberto (em ordem de prioridade)

1. Desempenho em GPU real **não foi medido** (os testes rodam em renderização por software). Prioridade para a primeira partida no PC do jogador: F3 mostra FPS.
2. Áudio e menus foram verificados por código, não por escuta/olho: vale uma passada humana (volume do grito, legibilidade do menu).
3. Algumas casas ainda ficam rasas (2,4 a 4,1 m) onde a ladeira em zigue-zague aperta o espaço.
4. Margens do rio ficam serrilhadas (o terreno é calculado de 4 em 4 m).
5. Licença dos braços (`assets/models/arms`) marcada como "CONFIRMAR" em `assets/CREDITOS.md`.
6. Árvores, palmeira e bananeira são modelos procedurais próprios, não escaneados.
7. A igreja ao fim da rua bloqueia o corredor central (é o destino; não é bug).
