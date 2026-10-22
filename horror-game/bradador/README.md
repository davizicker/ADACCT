# BRADADOR — protótipo jogável (Godot 4.3)

Vertical slice v0: suba a ladeira de uma vila colonial fictícia até a igreja,
enquanto o Bradador grita na névoa. Tudo é gerado por código (sem assets);
sons e modelos são placeholders.

## Como rodar
1. Instale o [Godot 4.3](https://godotengine.org/download) (versão padrão, não .NET).
2. Abra esta pasta (`horror-game/bradador`) no Godot e aperte F5.
   Linha de comando: `godot --path horror-game/bradador`

## Controles
| Tecla | Ação |
|---|---|
| WASD / mouse | andar / olhar |
| F | acender/apagar o lampião (o óleo acaba) |
| R (segurar) | gritar sem microfone |
| `[` / `]` | diminuir/aumentar o limiar do microfone |
| Enter | recomeçar (depois de morrer ou vencer) |
| Esc | soltar o mouse |

## Regras do jogo
- De tempos em tempos o Bradador **grita**. Quando o grito acabar, você tem 3 s
  para **parar de andar e gritar** (microfone ou R) por ~0,5 s.
- Respondeu certo: ele recua um estágio. Silêncio, andar durante a janela: ele avança.
- **Não olhe para ele** (fica visível na névoa a partir do estágio 1): olhar por ~1,6 s o aproxima.
- Estágio final = ele te alcança. Chegar à porta da igreja = vitória.
- Evento de susto #1: depois da 2ª resposta certa, o grito volta **de trás de você** com o lampião apagando.

## Microfone
Mede só o **volume** (RMS) do microfone, sem reconhecimento de fala. A barra `mic |||`
na tela mostra o nível; ajuste o limiar com `[` e `]` até gritar passar e falar normal não.
Se o sistema não der acesso ao microfone, use R.

## Testes automáticos (sem janela)
```
godot --headless --path . --import
godot --headless --path . --quit-after 3000 -- --selftest        # respostas certas/erradas até a morte
godot --headless --path . --quit-after 20000 -- --selftest-walk  # anda a rua toda até a igreja
```
Os avisos `mesh_get_surface_count` no modo headless vêm do renderizador "dummy" e são inofensivos.

Print de teste (precisa de display; com xvfb): `-- --shot=/caminho/img.png --shot-z=-120 --shot-stage=2`

## Estado e limitações conhecidas
- Verificado: compila, a regra de estágios/morte, o evento de eco, a subida da ladeira, a vitória
  e a renderização (screenshots via xvfb).
- **Não verificado:** captura real do microfone (sem dispositivo de áudio no ambiente de
  desenvolvimento) e o "feeling" de jogo. Precisa de playtest com fones.
- Mula-sem-cabeça, Corpo-seco em perseguição, Pisadeira e Lobisomem ainda não estão implementados.
- Visual é caixa-de-areia: falta o estilo PS1/HD-2D, texturas, shader de grão/dither.
- Áudio é sintetizado (placeholder). O grito final deve ser gravado por atores.

## Estrutura
`main.gd` monta tudo · `world.gd` vila/rua/igreja · `player.gd` jogador e lampião ·
`scream_system.gd` regra do grito, microfone, Bradador, eventos · `hud.gd` interface · `synth.gd` sons.
