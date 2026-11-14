# 30 — PC com GTX 1080: opções novas, qualidade automática e jogabilidade

## Qualidade automática (`scripts/qualidade_auto.gd`)
- Liga sozinha no Forward+ (padrão). Mede o FPS de verdade, numa média de 4 s, durante o jogo.
  Não mede no menu, na pausa nem com o jogo terminado.
- Se a média ficar abaixo de **50 FPS**, alivia um passo. Depois de cada ajuste espera 6 s (compilação de shaders).

| Passo | O que muda |
|---|---|
| 0 | tudo no máximo (Cinematográfico) |
| 1 | resolução interna 85% com FSR 2 |
| 2 | resolução 77% |
| 3 | sem bancos de névoa, névoa volumétrica 64 |
| 4 | preset Alto (sombras 4K, GI mais leve) |
| 5 | resolução 67% |
| 6 | preset Médio |

- O passo fica salvo em `user://bradador.cfg` (`qualidade_passo`), e o próximo jogo já começa nele.
- Escolher outra qualidade no menu zera o passo. Dá para desligar em Opções → "Qualidade automática".
- Teste sem placa: `-- --testar-qualidade --fps-falso=30` (3D desligado; finge 30 FPS). Ele desceu 0→1→2→3→4 e salvou 4.
  Com `--fps-falso=90` começou no 4 e ficou no 4.

## Opções novas no menu
- **Campo de visão (FOV)**: de 60 a 100 graus (padrão 75).
- **VSync**: ligado por padrão (sem rasgos na imagem).
- **Limite de FPS**: sem limite, 60, 120 ou 144.
- A lista de opções agora rola: cabe em qualquer resolução.

## Jogabilidade
- **Aceleração suave**: o personagem chega na velocidade em ~0,15 s e freia em ~0,12 s (antes era instantâneo).
  No ar quase não dá para mudar de direção.
- **Sobe degraus sozinho**: meio-fio, soleira e degrau de até 22 cm, com a câmera subindo suave.
  Paredes, móveis altos e as muretas contra o vazio (colisão de 3,2 m) continuam bloqueando.

## Cenário
- Caixote que ficava dentro de um oratório de rua (Nicho_310): agora a montagem tira o adorno da frente do oratório.
- Os oratórios entram 8–12 cm na parede de propósito (sem fresta); a auditoria da rua não conta mais isso como erro.

## Desempenho: alcance de visibilidade (`scripts/alcances.gd`)
- ~1300 peças não tinham alcance e eram desenhadas da vila inteira. Isso incluía o interior da igreja a 400 m e as salas do outro lado do mapa.
- Agora todas têm alcance: interiores 45 m (igreja 80 m), objetos pequenos 70 m, corpo das casas 260 m, o resto 160 m.
  Torres da igreja, capela do morro, serra e fundo da rua continuam vistos de longe.
- A passada roda no bake e de novo ao abrir o jogo, porque peças de modelos .glb perdem o ajuste salvo.
- Medição (`tools/perf_vila.gd`), em s=60: 3806 → 3098 objetos ao alcance (−19%), 5,5 → 4,5 milhões de triângulos.
- Não verificado: o ganho real de FPS na GTX 1080. O renderizador do contêiner (sem placa) não roda o Forward+ da vila inteira.
