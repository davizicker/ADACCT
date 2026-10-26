# Como jogar (protótipo)

Vertical slice v0: suba a ladeira de uma vila colonial fictícia até a igreja,
enquanto o Bradador grita na névoa. O mundo é feito de cenas editáveis (`scenes/`);
texturas são procedurais e os sons são sintetizados (placeholders).

## Como rodar
1. Instale o [Godot 4](https://godotengine.org/download) (versão padrão, não .NET).
2. **Importar** → `project.godot` na raiz deste repositório → **Importar e Editar**.
3. **F5**.

## Controles
| Tecla | Ação |
|---|---|
| WASD / mouse | andar / olhar |
| Shift | correr (gasta fôlego e **faz barulho**) |
| Ctrl ou C | agachar (silencioso) |
| F | acender/apagar o lampião (o óleo acaba) |
| E | pegar frasco de óleo / ler bilhete |
| R (segurar) | gritar sem microfone |
| `[` / `]` | diminuir/aumentar o limiar do microfone |
| Esc | pausa e opções |
| Enter | recomeçar (depois de morrer ou vencer) |

## Regras do jogo
- **Objetivo:** subir até a porta da igreja antes que algo te alcance.
- **O Bradador grita de longe.** Quando o grito acabar, você tem 3 s para **parar de andar e gritar** (microfone ou R) por ~0,5 s.
  Respondeu certo: ele recua. Silêncio, andar durante a janela, ou **correr enquanto ele grita**: ele avança.
- **Nunca olhe para ele** (silhueta na névoa): olhar por ~1,6 s o aproxima.
- **A Mula-sem-cabeça** vem galopando pela rua (você ouve o galope e vê a luz do fogo). Ela corre atrás da **luz**:
  **apague o lampião [F] e entre num beco** (escadaria entre as casas). Na rua, ela te mata. Num beco com a luz acesa, te entrega ao Bradador.
- **Apagão:** os lampiões à frente se apagam em onda. Fique atento.
- **Janelas assombradas:** uma janela acesa com um vulto. Ao chegar perto, a luz se apaga.
- **Frascos de óleo** (brilho âmbar) recarregam o lampião; **bilhetes** (brilho de papel) contam a história.
- Estágio final do Bradador = ele te alcança. Porta da igreja = vitória.

## Microfone
Mede só o **volume** (RMS) do microfone, sem reconhecimento de fala. A barra `mic |||`
na tela mostra o nível; ajuste o limiar com `[` e `]` até gritar passar e falar normal não.
Se o sistema não der acesso ao microfone, use R.

## Testes automáticos (sem janela)
```
godot --headless --path . --import
godot --headless --path . --quit-after 3000 -- --selftest        # respostas certas/erradas até a morte
godot --headless --path . --quit-after 40000 -- --selftest-walk  # anda a rua toda até a igreja
godot --headless --path . --quit-after 40000 -- --selftest-escape # tenta sair da vila pelos lados (não pode)
godot --headless --path . --quit-after 20000 -- --selftest-mula=rua            # deve morrer
godot --headless --path . --quit-after 20000 -- --selftest-mula=refugio        # lampião apagado no beco: salvo
godot --headless --path . --quit-after 20000 -- --selftest-mula=refugio_aceso  # lampião aceso no beco: penalidade
godot --headless --path . --quit-after 60000 -- --selftest-auto   # partida automática com eventos
godot --headless --path . --script res://tools/audio_check.gd     # confere os sons (pico, clipping)
```
Os avisos `mesh_get_surface_count` no modo headless vêm do renderizador "dummy" e são inofensivos.

Print de teste (precisa de display; com xvfb): `-- --shot=/caminho/img.png --shot-z=-120 --shot-stage=2`

## Estado e limitações conhecidas
- **Verificado (Godot 4.3, renderizador Compatibilidade):** compila; regra de estágios, morte e eco;
  o robô percorre os 343 m de rua curva até a porta da igreja; teste de fuga lateral sem vazamentos
  (15 pontos × 2 lados); capturas de tela de vários pontos.
- **Não verificado:** captura real do microfone (sem dispositivo de áudio no ambiente de
  desenvolvimento), desempenho em hardware fraco e o "feeling" de jogo. Precisa de playtest com fones.
  Testado no 4.3; deve funcionar em 4.4+, mas não foi testado no 4.7.
- **Desempenho medido (software, só como referência):** ~0,25–0,9 milhão de triângulos e ~800–1.800
  chamadas de desenho por quadro. Se travar: desligue sombras (Lua e Lampião) e reduza `Mata`.
- Mula-sem-cabeça, Corpo-seco em perseguição, Pisadeira e Lobisomem ainda não existem.
- O Bradador é feito de formas simples; falta modelo e animação.
- Áudio sintetizado (placeholder). O grito final deve ser gravado por atores.
- Texturas são procedurais; troque por texturas CC0 reais (veja APRENDER.md).

## Estrutura
`scenes/` main, vila (`vila.scn`), jogador, bradador, casa, poste, `veg/` (plantas) ·
`scripts/` regras do jogo (`route.gd` define a rua) · `assets/` materiais, texturas, malhas, shader do céu ·
`tools/` geradores (só use se souber o que faz) · `docs/`.
