# Conceito v0.2: Vila colonial + Bradador (título provisório: "BRADADOR")

Substitui a direção da rádio (v0.1). A cabine de rádio pode voltar como hub ou como
interlúdio (ver "Aproveitamento do v0.1").

## Pitch
Noite fechada numa vila mineira colonial de ruas de pedra, ladeiras e casarões, inspirada
em Ouro Preto. Lampiões amarelos, neblina baixa, sinos distantes. Algo grita nas
encostas, e quem não responde direito não amanhece. Você precisa atravessar a vila
até a igreja antes do raiar do dia, e cada figura do folclore tem uma regra diferente.

## A lenda-base: o Bradador
Segundo as fontes que consultei (blogs e páginas culturais, não estudos acadêmicos; os
detalhes variam conforme quem conta):
- É uma alma errante, muitas vezes ligada ao **Corpo-seco** (o corpo que a terra rejeita).
- O nome vem do **grito**; costuma andar em campos e trilhas depois da meia-noite, em sextas.
- Alguns relatos dizem que **olhar para ele traz a morte**.
- Um relato diz que, se você ouvir o grito, deve **gritar de volta**, ou ele te toma por intruso.
- Alguns dizem que ele se liberta se encontrar uma moça chamada Maria sete vezes.

Isso encaixa quase de graça num jogo: **o grito é a mecânica central.**

## Contexto histórico e tratamento
A vila colonial mineradora é inseparável da escravidão. Decisões de design:
1. **O horror nasce da violência colonial, não das vítimas.** As almas dos escravizados
   não são monstros. Os monstros são o que o ouro e a crueldade deixaram para trás
   (o Corpo-seco, por exemplo, pode ser um capataz ou senhor que a terra recusou).
2. **Dignidade e voz.** Personagens negros com agência, nome e história, não decoração.
3. **Consultoria** com historiadores e pesquisadores de cultura afro-brasileira e de
   Minas antes de fechar roteiro e lore.
4. **Fontes reais.** Verificar cada lenda em fonte folclórica séria antes de usar.
   Lendas locais como a "missa dos mortos" de Ouro Preto aparecem em fontes de
   turismo/blogs; não confirmei o enredo e não vou inventar.
5. Sem personagens ou lugares reais identificáveis. Vila fictícia.

## Bestiário (folclore mais pavoroso, com função de jogo)
| Entidade | Fonte | Regra de sobrevivência (função de jogo) |
|---|---|---|
| **Bradador** | Lenda de MG/SC/PR/SP | Grito ao longe. Responder no timing certo. Nunca encarar. |
| **Corpo-seco** | Ligado ao Bradador | Perseguidor lento e persistente; a terra o rejeita, então não pisa em solo consagrado. |
| **Mula-sem-cabeça** | Folclore nacional | Galope ouvido no calçamento; fogo no pescoço. Esconder-se em portal escuro, sem luz. |
| **Pisadeira** | Folclore do Sudeste | Sequência de "paralisia do sono" (mecânica de dormir/acordar). |
| **Lobisomem** | Folclore ibérico/brasileiro | Pico de tensão nas noites de lua: caça pelo cheiro, esconder-se em lugares fechados. |

Escopo: **começar com Bradador + Mula-sem-cabeça + Corpo-seco** e testar. As demais entram
como expansões ou noites extras.

## Mecânicas (as boas)
1. **Grito e resposta (assinatura do jogo).**
   - O Bradador grita de longe. Você precisa responder gritando no momento certo.
   - Com microfone: detecção de volume (não reconhecimento de fala), sem ML.
   - Sem microfone: botão de segurar/soltar com tempo (acessível).
   - Resposta cedo, tarde ou fraca demais atrai o Bradador; silêncio total também.
   - Grito = momento viral: o jogador grita de verdade, o amigo reage.
2. **Lampião de óleo.** Luz limitada. Algumas entidades se afastam da luz, outras são atraídas.
3. **Ouvir as pedras.** Passos, galope e arrastar no calçamento dão direção; fones são essenciais.
4. **Neblina como sentido.** Densidade muda por região; sinos e latidos orientam.
5. **Locais seguros que deixam de ser.** Igreja, casarão, mina: segurança é recurso.
6. **Regras que se descobrem.** Cada entidade tem 1 regra clara e justa, aprendida por observação.
7. **Mapa vertical.** Ladeiras, becos, escadarias, igreja no alto, mina no fundo.

## Jumpscares que viralizam (projetados, não aleatórios)
Princípios:
- **Construir e soltar.** Tensão longa, silêncio, depois o susto. O susto sem build-up é barato.
- **Quebra de regra do próprio jogo.** Ensine uma regra, confie nela, quebre-a uma vez.
- **Susto causado pelo jogador.** Exemplo: você grita para responder e o que vem não é o Bradador.
- **Frequência baixa e alvos claros:** no máximo 1 grande a cada ~10 min de jogo.
- **Telegráfico para o áudio.** O som avisa meio segundo antes; o jogador sente que "deveria ter sabido".
- **Clipável.** Câmera, enquadramento e silêncio pensados para uma reação de 5 s que sobe bem em Shorts/TikTok.
- **Modo streamer:** opção que mostra reação do jogador (webcam) e marca automaticamente clipes de susto.
- **Rejogabilidade:** pequenas variações de timing e posição para o susto não ser decorado.

Candidatos a momentos virais (para testar):
1. Resposta ao grito: você grita, o silêncio cai, e a resposta vem **da sua própria voz**, vindo de trás.
2. Lampião apaga numa ladeira; o Corpo-seco já estava a dois passos.
3. Galope da Mula parando exatamente atrás do portal onde você se escondeu.
4. Espelho/janela de casarão mostra o Bradador no reflexo (nunca de frente).

## Estética
Low poly PS1/HD-2D (a decidir), muito grão, 4:3 opcional. Paleta: preto azulado, âmbar dos
lampiões, branco da neblina. Casarios coloniais, igrejas barrocas, calçamento de pedra,
casas coladas, ladeiras. Áudio com reverb de pedra e eco de montanha.

## Aproveitamento do v0.1 (rádio)
- A cabine pode ser o **hub entre noites**: ouvir os chamados da vila e anotar pistas.
- Ou ser o **segundo jogo/modo**. Decisão em aberto.

## Escopo MVP (vertical slice)
- 1 trecho de vila (3–4 ruas + 1 igreja), 1 noite de ~15 min.
- Bradador (grito/resposta) + 1 outra entidade (Mula-sem-cabeça).
- Lampião, neblina, áudio posicional.
- 2 momentos de susto projetados.
- Final: amanhecer na igreja, com revelação parcial.

## Decisões em aberto
1. Engine: Godot 4 (recomendado) vs. Unity/Unreal.
2. Visual: PS1 puro vs. HD-2D vs. realismo estilizado.
3. Cabine de rádio: hub, segundo modo, ou descartada.
4. Microfone: obrigatório, opcional (recomendado) ou só botão.
5. Vila fictícia vs. inspirada em cidade real (recomendo fictícia).
