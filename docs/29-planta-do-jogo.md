# Planta do jogo (gerada da cena real)

Gerada por `tools/planta_jogo.gd` (lê `scenes/vila.scn`) e `tools/planta_jogo.py`. Imagem: `docs/planta/planta_do_jogo.png` (1 m = 16 px). Dados completos (todas as posições): `docs/planta/planta.json`.

Coordenadas em metros: x para leste, z para sul, y altura. `s` = metros ao longo da rua, da entrada (s=0) até a igreja. Lado -1/+1 = esquerda/direita de quem sobe.


## Catálogo dos módulos das casas (tamanho padrão medido do modelo)

| Módulo | Largura (m) | Altura (m) | Saliência da parede (m) | Usos na vila |
|---|---|---|---|---|
| beiral_telhas | 1.06 | 0.15 | 0.45 | 254 |
| cachorro_beiral | 0.11 | 0.16 | 0.92 | 409 |
| chamine | 1.00 | 2.11 | 0.50 | 21 |
| cornija_1m | 1.00 | 0.23 | 0.15 | 410 |
| cunhal_1m | 0.53 | 0.98 | 0.14 | 392 |
| embasamento_1m | 1.00 | 0.96 | 0.14 | 162 |
| grade_janela | 1.00 | 1.56 | 0.22 | 26 |
| janela_colonial | 1.46 | 1.86 | 0.27 | 26 |
| janela_guilhotina | 1.52 | 2.15 | 0.26 | 73 |
| porta_balcao | 1.52 | 2.72 | 0.18 | 16 |
| porta_bandeira | 1.60 | 3.14 | 0.42 | 5 |
| porta_dupla | 2.30 | 2.99 | 0.58 | 15 |
| sacada_1m | 1.00 | 1.44 | 1.20 | 13 |
| sacada_ferro | 1.66 | 1.56 | 0.76 | 42 |
| veneziana | 0.52 | 1.56 | 0.04 | 0 |
| veneziana_e | 0.52 | 1.56 | 0.04 | 0 |

Regras de encaixe: cunhal e embasamento em módulos de 1 m; cunhal a 0,26 m da quina; embasamento pula o vão da porta (1,3 m); sacada de ferro só sobre porta-balcão do 2º andar; janela/porta nos vãos da fachada; cornija e cachorros no topo da parede; beiral de telhas a cada 1 m.


## Casas (ficha)

| Nº | Casa | s (m) | Lado | Largura × fundo (m) | Andares | Altura (m) | Porta (x, y, z) | Visitável | Módulos |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Casa_271 | 4.0 | -1 | 5.30 × 11.00 | 2 | 7.40 | (-2.90, 0.44, 9.84) |  | beiral_telhas×5, cachorro_beiral×5, cornija×6, cunhal×14, embasamento×2, janela_guilhotina×1, sacada_ferro×2 |
| 3 | Casa_255 | 11.0 | -1 | 9.62 × 8.37 | 1 | 4.15 | (-2.90, 1.00, 3.19) | benedita | beiral_telhas×9, cachorro_beiral×10, chamine×1, cornija×10, cunhal×8, embasamento×5, janela_guilhotina×2, porta_dupla×1 |
| 5 | Casa_272 | 19.0 | -1 | 4.70 × 11.00 | 1 | 4.00 | (-2.90, 1.64, -5.01) |  | cachorro_beiral×5, chamine×1, cornija×5, janela_colonial×1 |
| 7 | Casa_299 | 56.5 | -1 | 5.81 × 11.00 | 1 | 4.00 | (30.55, 3.61, -18.90) |  | cachorro_beiral×6, chamine×1, cornija×6, janela_colonial×1 |
| 9 | Casa_300 | 80.5 | -1 | 7.60 × 11.00 | 2 | 7.40 | (54.23, 4.69, -18.90) |  | cachorro_beiral×8, cornija×8, janela_colonial×2 |
| 11 | Casa_301 | 88.5 | -1 | 8.04 × 5.00 | 2 | 7.40 | (62.20, 5.05, -18.90) |  | beiral_telhas×8, cachorro_beiral×8, chamine×1, cornija×9, cunhal×14, embasamento×5, grade_janela×1, janela_guilhotina×2, sacada_ferro×3 |
| 13 | Casa_328 | 153.0 | -1 | 6.86 × 5.00 | 2 | 7.40 | (58.70, 10.89, -47.10) |  | cachorro_beiral×7, chamine×1, cornija×7, janela_colonial×2, sacada×4 |
| 15 | Casa_260 | 158.5 | -1 | 8.37 × 7.12 | 1 | 4.15 | (52.82, 11.13, -47.10) | barbearia | beiral_telhas×8, cachorro_beiral×9, cornija×9, cunhal×8, embasamento×4, janela_guilhotina×2, porta_dupla×1 |
| 17 | Casa_329 | 181.0 | -1 | 5.87 × 11.00 | 2 | 7.40 | (30.36, 12.15, -47.10) |  | beiral_telhas×5, cachorro_beiral×6, cornija×6, cunhal×14, embasamento×2, janela_guilhotina×1, sacada_ferro×2 |
| 19 | Casa_330 | 195.0 | -1 | 7.04 × 11.00 | 2 | 7.40 | (16.31, 12.78, -47.10) |  | cachorro_beiral×7, chamine×1, cornija×8, janela_colonial×2 |
| 21 | Casa_331 | 198.5 | -1 | 8.22 × 11.00 | 1 | 4.00 | (12.94, 12.93, -47.10) |  | cachorro_beiral×9, chamine×1, cornija×9, janela_colonial×2, porta_dupla×1 |
| 23 | Casa_350 | 263.0 | -1 | 5.08 × 11.00 | 2 | 7.40 | (10.00, 18.77, -86.90) |  | beiral_telhas×5, cachorro_beiral×5, cornija×6, cunhal×14, embasamento×2, grade_janela×1, janela_guilhotina×1, sacada_ferro×2 |
| 25 | Casa_351 | 273.0 | -1 | 6.87 × 11.00 | 2 | 7.40 | (20.02, 19.22, -86.90) |  | cachorro_beiral×7, cornija×7, janela_colonial×2, sacada×4 |
| 27 | Casa_352 | 283.0 | -1 | 7.91 × 11.00 | 1 | 4.00 | (30.18, 19.67, -86.90) |  | beiral_telhas×7, cachorro_beiral×8, chamine×1, cornija×8, cunhal×8, embasamento×4, grade_janela×1, janela_guilhotina×2 |
| 29 | Casa_353 | 293.0 | -1 | 5.18 × 11.00 | 1 | 4.00 | (39.93, 20.12, -86.90) |  | beiral_telhas×5, cachorro_beiral×5, chamine×1, cornija×6, cunhal×8, embasamento×2, grade_janela×1, janela_guilhotina×1, porta_bandeira×1 |
| 31 | Casa_354 | 301.0 | -1 | 6.86 × 11.00 | 2 | 7.40 | (48.10, 20.48, -86.90) |  | beiral_telhas×6, cachorro_beiral×7, chamine×1, cornija×7, cunhal×14, embasamento×3, janela_guilhotina×2, sacada_ferro×1 |
| 33 | Casa_355 | 315.0 | -1 | 5.60 × 11.00 | 2 | 7.40 | (62.29, 21.11, -86.90) |  | cachorro_beiral×6, chamine×1, cornija×6, janela_colonial×1, porta_bandeira×1, porta_dupla×2, sacada×5 |
| 35 | Casa_261 | 381.0 | -1 | 13.37 × 10.87 | 1 | 9.90 | (57.32, 27.02, -115.10) | casarao | beiral_telhas×13, cachorro_beiral×14, chamine×1, cornija×14, cunhal×18, embasamento×10, janela_guilhotina×4, porta_dupla×1 |
| 37 | Casa_386 | 400.5 | -1 | 6.92 × 11.00 | 2 | 7.40 | (38.04, 27.90, -115.10) |  | beiral_telhas×6, cachorro_beiral×7, cornija×7, cunhal×14, embasamento×3, grade_janela×1, janela_guilhotina×2, sacada_ferro×1 |
| 39 | Casa_387 | 405.5 | -1 | 6.38 × 11.00 | 1 | 4.00 | (32.67, 28.12, -115.10) |  | cachorro_beiral×7, cornija×7, janela_colonial×1, porta_dupla×1 |
| - | Casa_401 | 436.5 | -1 | 6.78 × 11.00 | 1 | 4.00 | (-3.20, 29.67, -130.89) |  | beiral_telhas×6, cachorro_beiral×7, cornija×7, cunhal×8, embasamento×3, grade_janela×1, janela_guilhotina×2, porta_bandeira×1 |
| 41 | Casa_402 | 446.0 | -1 | 10.17 × 11.00 | 2 | 7.40 | (-3.20, 29.95, -140.49) |  | beiral_telhas×10, cachorro_beiral×11, cornija×11, cunhal×14, embasamento×7, grade_janela×1, janela_guilhotina×4, porta_balcao×3, porta_dupla×1, sacada_ferro×3 |
| 43 | Casa_403 | 459.0 | -1 | 10.60 × 11.00 | 2 | 7.40 | (-3.20, 30.34, -153.27) |  | beiral_telhas×10, cachorro_beiral×11, cornija×11, cunhal×14, embasamento×7, grade_janela×2, janela_guilhotina×4, porta_balcao×3, porta_dupla×1, sacada_ferro×3 |
| 45 | Casa_404 | 462.5 | -1 | 8.44 × 11.00 | 3 | 10.80 | (-3.20, 30.45, -156.88) |  | beiral_telhas×8, cachorro_beiral×9, cornija×9, cunhal×20, embasamento×6, grade_janela×2, janela_guilhotina×2, sacada_ferro×1 |
| 47 | Casa_405 | 473.0 | -1 | 10.07 × 11.00 | 2 | 7.40 | (-3.20, 30.76, -167.43) |  | beiral_telhas×10, cachorro_beiral×11, chamine×1, cornija×11, cunhal×14, embasamento×8, grade_janela×2, janela_guilhotina×3, sacada_ferro×2 |
| 2 | Casa_257 | 7.5 | +1 | 10.87 × 8.87 | 1 | 4.28 | (2.90, 0.72, 6.57) | padaria | beiral_telhas×10, cachorro_beiral×12, chamine×1, cornija×11, cunhal×8, embasamento×7, janela_guilhotina×2 |
| 4 | Casa_270 | 17.0 | +1 | 6.00 × 11.00 | 2 | 7.40 | (2.90, 1.48, -3.19) |  | beiral_telhas×6, cachorro_beiral×6, cornija×6, cunhal×14, embasamento×4, janela_guilhotina×1, sacada_ferro×2 |
| 6 | Casa_273 | 43.0 | +1 | 9.81 × 7.50 | 2 | 7.40 | (16.98, 3.00, -13.10) |  | beiral_telhas×9, cachorro_beiral×10, cornija×10, cunhal×14, embasamento×7, grade_janela×1, janela_guilhotina×3, sacada_ferro×2 |
| 8 | Casa_256 | 53.0 | +1 | 10.87 × 8.37 | 1 | 4.40 | (26.93, 3.45, -13.10) | carpintaria | beiral_telhas×10, cachorro_beiral×12, chamine×1, cornija×11, cunhal×8, embasamento×7, janela_guilhotina×2 |
| 10 | Casa_258 | 74.0 | +1 | 10.87 × 8.37 | 1 | 4.28 | (47.94, 4.39, -13.10) | venda | cachorro_beiral×12, cornija×11, janela_colonial×1, porta_dupla×1 |
| 12 | Casa_274 | 83.5 | +1 | 9.48 × 11.00 | 1 | 4.00 | (57.52, 4.82, -13.10) |  | cachorro_beiral×10, cornija×10, janela_colonial×3 |
| 14 | Casa_302 | 147.5 | +1 | 4.98 × 11.00 | 2 | 7.40 | (63.95, 10.64, -52.90) |  | beiral_telhas×5, cachorro_beiral×5, chamine×1, cornija×5, cunhal×14, embasamento×2, grade_janela×1, janela_guilhotina×1, porta_balcao×2, porta_bandeira×1, sacada_ferro×2 |
| 16 | Casa_312 | 168.0 | +1 | 9.65 × 11.00 | 2 | 7.40 | (43.75, 11.56, -52.90) |  | beiral_telhas×9, cachorro_beiral×10, cornija×10, cunhal×14, embasamento×5, grade_janela×2, janela_guilhotina×5, porta_balcao×2, porta_dupla×1, sacada_ferro×2 |
| 18 | Casa_319 | 185.5 | +1 | 8.21 × 11.00 | 1 | 4.00 | (26.27, 12.35, -52.90) |  | cachorro_beiral×9, cornija×9, janela_colonial×2, porta_dupla×1 |
| 20 | Casa_320 | 199.0 | +1 | 6.81 × 11.00 | 2 | 7.40 | (12.41, 12.96, -52.90) |  | beiral_telhas×6, cachorro_beiral×7, cornija×7, cunhal×14, embasamento×3, grade_janela×1, janela_guilhotina×2, sacada_ferro×2 |
| 22 | Casa_332 | 263.0 | +1 | 8.81 × 11.00 | 2 | 7.40 | (9.88, 18.77, -81.10) |  | beiral_telhas×8, cachorro_beiral×9, chamine×1, cornija×9, cunhal×14, embasamento×5, janela_guilhotina×3, porta_balcao×2, porta_dupla×1, sacada_ferro×2 |
| 24 | Casa_259 | 282.0 | +1 | 13.37 × 10.87 | 1 | 4.65 | (29.18, 19.63, -81.10) | escola | cachorro_beiral×14, cornija×14, janela_colonial×2, porta_dupla×1 |
| 26 | Casa_333 | 294.0 | +1 | 9.13 × 11.00 | 2 | 7.40 | (40.88, 20.17, -81.10) |  | cachorro_beiral×10, chamine×1, cornija×10, janela_colonial×2 |
| 28 | Casa_341 | 307.0 | +1 | 9.66 × 11.00 | 2 | 7.40 | (54.12, 20.75, -81.10) |  | beiral_telhas×9, cachorro_beiral×10, chamine×1, cornija×10, cunhal×14, embasamento×7, grade_janela×2, janela_guilhotina×3, sacada_ferro×2 |
| 30 | Casa_262 | 380.5 | +1 | 8.37 × 7.12 | 1 | 4.03 | (57.82, 27.00, -120.90) | sineiro | beiral_telhas×8, cachorro_beiral×9, cornija×9, cunhal×8, embasamento×6, janela_guilhotina×2 |
| 32 | Casa_366 | 389.0 | +1 | 10.75 × 11.00 | 2 | 7.40 | (49.31, 27.38, -120.90) |  | beiral_telhas×10, cachorro_beiral×11, chamine×1, cornija×11, cunhal×14, embasamento×7, grade_janela×2, janela_guilhotina×3, sacada_ferro×2 |
| 34 | Casa_367 | 399.5 | +1 | 8.15 × 11.00 | 1 | 4.00 | (38.68, 27.85, -120.90) |  | beiral_telhas×8, cachorro_beiral×9, cornija×9, cunhal×8, embasamento×6, janela_guilhotina×2 |
| 36 | Casa_368 | 405.5 | +1 | 8.75 × 11.00 | 1 | 4.00 | (32.73, 28.12, -120.90) |  | beiral_telhas×8, cachorro_beiral×9, cornija×9, cunhal×8, embasamento×6, janela_guilhotina×2 |
| 38 | Casa_397 | 447.0 | +1 | 10.81 × 11.00 | 2 | 7.40 | (25.20, 29.98, -141.49) |  | beiral_telhas×10, cachorro_beiral×12, cornija×11, cunhal×14, embasamento×6, grade_janela×1, janela_guilhotina×3, porta_balcao×4, porta_bandeira×1, sacada_ferro×4 |
| 40 | Casa_398 | 455.0 | +1 | 8.18 × 11.00 | 1 | 4.00 | (25.20, 30.22, -149.71) |  | beiral_telhas×8, cachorro_beiral×9, cornija×9, cunhal×8, embasamento×5, grade_janela×1, janela_guilhotina×2, porta_dupla×1 |
| 42 | Casa_399 | 461.5 | +1 | 9.21 × 11.00 | 2 | 7.40 | (25.20, 30.42, -156.10) |  | beiral_telhas×9, cachorro_beiral×10, chamine×1, cornija×10, cunhal×14, embasamento×6, grade_janela×2, janela_guilhotina×2, sacada_ferro×2 |
| 44 | Casa_400 | 470.5 | +1 | 8.43 × 11.00 | 1 | 4.00 | (25.20, 30.69, -164.92) |  | cachorro_beiral×9, cornija×9, janela_colonial×2 |

## Objetos em cena (resumo por grupo; posições exatas no planta.json)

| Grupo | Quantidade |
|---|---|
| Adornos | 46 |
| Adro | 65 |
| Becos | 11 |
| Coletaveis | 29 |
| Iluminacao | 18 |
| Interiores | 6 |
| MurosDasCurvas | 282 |
| MurosEQuintais | 17 |
| Nichos | 6 |
| Ponte | 66 |
| Props | 22 |
| PropsEncosta | 155 |
| Ratos | 8 |

## Conferência dos módulos

Nenhum problema: todos os módulos dentro da parede, nenhum cobrindo janela/porta, nenhum atravessando outro, toda sacada com porta-balcão.
