# Mapa: tudo que pode ser adicionado para o jogo ficar "perfeito"

Legenda de status: ✅ feito e testado · 🟡 feito, mas só em versão básica/placeholder · ⬜ ainda não · ❌ não recomendo agora.
Custo para **você**: 🆓 grátis · ⏱️ só tempo · 👥 precisa de pessoas · 💰 pagaria algo.
Prioridade: **P1** fazer antes de mostrar a alguém · **P2** deixa o jogo muito melhor · **P3** polimento / depois.

> Honestidade: "perfeito" não existe. O que existe é um jogo **terminado e coerente**. Esta lista é o mapa para chegar lá,
> em ordem de impacto. A coluna "Status" diz o que realmente existe hoje.

---

## 1. Gameplay e medo (o que faz o jogador sentir)

| Item | Status | Prioridade | Observação |
|---|---|---|---|
| Grito e resposta (microfone ou tecla R) | 🟡 | P1 | Funciona nos testes; **falta testar com microfone real e ajustar o ritmo jogando** |
| Bradador: estágios, olhar proibido, passos ouvidos | ✅ | P1 | Correr enquanto ele grita o aproxima |
| Mula-sem-cabeça (regra: apague a luz e entre num beco) | ✅ | P1 | Testado nos 3 casos (rua, refúgio apagado, refúgio aceso) |
| Corpo-seco perseguindo (lento, não pisa em chão benzido) | ⬜ | P2 | A IA de perseguição que aprende; o maior "salto" de medo |
| Pisadeira (paralisia do sono entre noites) | ⬜ | P3 | |
| Lobisomem (caça pelo cheiro, noites de lua) | ⬜ | P3 | |
| Apagão em onda dos lampiões | ✅ | P2 | |
| Janela assombrada (vulto que some) | ✅ | P2 | Até 6 casas |
| Frascos de óleo e bilhetes (lore) | ✅ | P2 | 7 frascos, 6 bilhetes |
| Correr, agachar e fôlego | ✅ | P2 | |
| Esconder-se em lugares (armário, barril, sob a ponte) | ⬜ | P2 | Hoje só os becos servem de refúgio |
| Sistema de noites (5 noites, dificuldade crescente) | ⬜ | P1 | Hoje é uma noite só |
| Sistema de salvar/continuar (checkpoint na ponte) | ⬜ | P1 | |
| Jumpscares "virais" extras (de 4 desenhados, 1 feito: eco atrás) | 🟡 | P1 | Faltam: reflexo, Mula parando no portal, ... (ver docs/03) |
| Modo streamer (webcam + marcar clipes) | ⬜ | P3 | Muito bom para divulgação |
| Finais diferentes (conforme bilhetes lidos / escolhas) | ⬜ | P2 | |
| Tutorial/primeira noite guiada | 🟡 | P1 | Há dicas na tela; falta uma noite 1 de ensino |
| Acessibilidade (legendas de áudio, daltonismo, sem microfone) | 🟡 | P1 | Já dá pra jogar sem microfone; faltam legendas dos sons ("[galope distante]") |

## 2. Cenário e arte

| Item | Status | Prioridade | Custo | Observação |
|---|---|---|---|---|
| Rua sinuosa com morros, casario, muros, becos em escada, chafariz, ponte, igreja | ✅ | P1 | 🆓 | |
| Vegetação, serra ao fundo, céu com nuvens e estrelas, milhares de luzes | ✅ | P1 | 🆓 | |
| Detalhes: placas, vasos, nichos com vela, varais, bandeirinhas, bueiros, barris, banco, carroça | ✅ | P2 | 🆓 | |
| **Texturas reais (CC0) no lugar das procedurais** | 🟡 | P1 | 🆓 ⏱️ | **5 de ~12 feitas** (ambientCG): casca, 2 madeiras, 2 chãos. Faltam: pedra da rua, reboco, telha, muro de pedra, cantaria, folhagem |
| **Modelos 3D reais** (casas, igreja, mobiliário) | ⬜ | P2 | 🆓/💰 | Sketchfab/Poly Haven (confira licença) ou artista. Guia em docs/06 |
| **Bradador e Mula em 3D realista** (`assets/models/*.glb`) | 🟡 | P1 | 🆓 ⏱️ | O jogo já troca sozinho o modelo simples pelo seu .glb (testado com modelo de teste). Falta o modelo real |
| Interior de uma casa e da igreja (cena final) | ⬜ | P2 | ⏱️ | Hoje a igreja é só fachada |
| Mais "ruas" (segunda ladeira, praça, cemitério, mina) | ⬜ | P2 | ⏱️ | Mina do Chico Rei é real: tratar com respeito e consultoria |
| Chuva e poças, neblina volumétrica, raios de luz, relâmpago | ⬜ | P2 | 🆓 | Neblina volumétrica e SDFGI exigem Forward+ (ver APRENDER.md) |
| Reflexos reais na água/pedra molhada (SSR), iluminação global, neblina volumétrica | 🟡 | P3 | 🆓 | Forward+ "Qualidade Alta": **ligado e testado em Vulkan por software**; falta medir em placa real |
| Animais (gato nos telhados, cachorro, morcegos, corujas) | ⬜ | P3 | ⏱️ | Olhos de gato brilhando: barato e eficaz |
| Pessoas (moradores fantasmagóricos nas janelas) | ⬜ | P3 | 👥 | Cuidado com representação: veja docs/03 |
| Troca de dia/noite, amanhecer como vitória | ⬜ | P2 | ⏱️ | A vitória hoje é só uma tela |
| Cutscenes (intro, mortes, final) | ⬜ | P2 | ⏱️ | |
| Estilo visual de assinatura (grão VHS/PS1 opcional, dither) | 🟡 | P3 | 🆓 | Há granulado e vinheta; falta um modo "retrô" |

## 3. Áudio (70% do medo)

| Item | Status | Prioridade | Custo | Observação |
|---|---|---|---|---|
| Ambiente em camadas: vento, grilos, riacho, sino, cães, zumbido grave | 🟡 | P1 | 🆓 | **Tudo sintetizado por código: serve de protótipo, soa artificial** |
| Passos no calçamento, respiração, batimento cardíaco que segue o medo | ✅ | P2 | 🆓 | |
| Reverb de rua de pedra | ✅ | P3 | 🆓 | |
| **Grito do Bradador gravado por atores** | ⬜ | P1 | 👥 | O som mais importante do jogo |
| **Gravações reais** (galope, vento, sino, grilos) | ⬜ | P1 | 🆓 | freesound.org (CC0/CC-BY) ou gravar você mesmo |
| Música (tema do menu, momentos de tensão) | ⬜ | P2 | 🆓/👥 | Pouca música, muito silêncio funciona melhor |
| Áudio espacial melhor (oclusão atrás de paredes) | ⬜ | P3 | ⏱️ | |
| Voz do próprio jogador devolvida (eco do microfone) | ⬜ | P2 | ⏱️ | O susto mais "viral" do conceito; o eco atual é o grito sintético |
| Dublagem de narrador/notas lidas em voz alta | ⬜ | P3 | 👥 | |

## 4. Interface, opções e qualidade de vida

| Item | Status | Prioridade |
|---|---|---|
| Menu inicial, pausa (Esc), opções salvas | ✅ | P1 |
| Qualidade gráfica baixa/média/alta, desligar efeitos de câmera | ✅ | P1 |
| Remapear teclas | ⬜ | P2 |
| Suporte a controle (gamepad) | ⬜ | P2 |
| Idiomas (PT-BR hoje; inglês depois) | ⬜ | P2 |
| Mapa/bússola? (❌ eu não recomendo: tira o medo) | ❌ | — |
| Conquistas (Steam) | ⬜ | P3 |
| Tela de carregamento | ⬜ | P3 |

## 5. Técnico, desempenho e qualidade do software

| Item | Status | Prioridade | Observação |
|---|---|---|---|
| Testes automáticos (lógica, andar a rua, fuga, Mula, partida completa, áudio) | ✅ | P1 | `docs/LEIAME-do-prototipo.md` |
| Desempenho medido | 🟡 | P1 | ~1.000–2.200 chamadas de desenho por quadro **em renderização por software**: **medir no seu PC** |
| Oclusão (não desenhar o que está atrás das casas) | ⬜ | P2 | Pode dobrar o desempenho |
| LOD (versões simples dos modelos distantes) | ⬜ | P2 | |
| Exportar o jogo (.exe) para Windows | ⬜ | P1 | Precisa dos templates de exportação do Godot |
| Teste em Godot 4.7 (você usa) | ✅ | P1 | Testado na **4.7.2** (importação, lógica, mula, fuga, imagem, Forward+) |
| Teste com microfone real | ⬜ | P1 | |
| Controle de versão e backup | ✅ | P1 | GitHub |

## 6. História, mundo e conteúdo (o que dá alma)

| Item | Status | Prioridade | Observação |
|---|---|---|---|
| Premissa, pilares, bestiário | ✅ | P1 | docs/02, 03 |
| Lore: 6 bilhetes | 🟡 | P1 | Rascunho meu; **precisa de revisão cultural** |
| **Consultoria** (historiador, pesquisador de cultura afro-brasileira e de Minas) | ⬜ | **P1** | Decisão de respeito: o horror vem da violência colonial, não das vítimas |
| Roteiro das 5 noites | ⬜ | P1 | |
| Personagem do jogador (quem é você? por que está ali?) | ⬜ | P1 | |
| Mais lendas verificadas em fonte séria (Saci, Cuca, Boitatá, etc.) | ⬜ | P2 | Eu só usei o que as fontes confirmaram |
| Final e revelação | ⬜ | P1 | Hoje o final é "Amanheceu. (por enquanto)" |

## 7. Lançamento (se for vender)

| Item | Status | Prioridade | Custo |
|---|---|---|---|
| Nome definitivo, logotipo, ícone | ⬜ | P2 | 🆓/💰 |
| Página na Steam / itch.io, trailer, capturas | ⬜ | P2 | Steam: **taxa de publicação** (💰) |
| Demo curta (Next Fest) | ⬜ | P2 | O vertical slice atual já é o começo |
| Licença do jogo (hoje: nenhuma) | ⬜ | P1 | Decida antes de publicar |
| Créditos de assets de terceiros (`assets/CREDITOS.md`) | 🟡 | P1 | Atualize sempre que adicionar algo de fora |
| Marketing: clipes de susto, comunidades de terror | ⬜ | P3 | |

---

## Ordem que eu recomendo (os 10 passos de maior retorno)
1. **Jogar e me contar** (ritmo dos gritos, microfone, se o desempenho aguenta). Sem isso, tudo abaixo é chute.
2. **Texturas reais (CC0)**: maior salto visual, grátis.
3. **Sons reais** no lugar dos sintéticos (freesound.org) e **gravar o grito** com alguém.
4. **Sistema de noites** + salvar: dá estrutura de jogo.
5. **Corpo-seco** perseguindo: o monstro que "aprende".
6. **Interior da igreja** + final de verdade (amanhecer).
7. **Consultoria** para revisar lore e personagens.
8. **Exportar o .exe** e testar em outro computador.
9. Chuva, neblina volumétrica e reflexos (se o seu PC suportar Forward+).
10. Gamepad, remapear teclas, legendas, idiomas.

## O que eu NÃO consigo fazer daqui (para ser claro)
- Ouvir o jogo, sentir se assusta, ou testar com microfone real.
- Baixar assets de sites bloqueados no meu ambiente (ambientCG, Poly Haven, Sketchfab, freesound). **Você baixa, eu integro.**
- Gravar voz de atores, fazer arte 3D autoral de alto nível, ou fazer a revisão cultural.
- Garantir desempenho no seu hardware: eu meço só em renderização por software.
