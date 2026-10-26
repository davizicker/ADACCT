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
