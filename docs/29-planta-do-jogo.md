# Planta do jogo (gerada da cena real)

Gerada por `tools/planta_jogo.gd` (lê `scenes/vila.scn`) e `tools/planta_jogo.py`. Imagem: `docs/planta/planta_do_jogo.png` (1 m = 16 px). Dados completos (todas as posições): `docs/planta/planta.json`.

Coordenadas em metros: x para leste, z para sul, y altura. `s` = metros ao longo da rua, da entrada (s=0) até a igreja. Lado -1/+1 = esquerda/direita de quem sobe.


## Catálogo dos módulos das casas (tamanho padrão medido do modelo)

| Módulo | Largura (m) | Altura (m) | Saliência da parede (m) | Usos na vila |
|---|---|---|---|---|
| beiral_telhas | 1.06 | 0.15 | 0.45 | 275 |
| cachorro_beiral | 0.11 | 0.16 | 0.92 | 409 |
| chamine | 1.00 | 2.11 | 0.50 | 23 |
| cornija_1m | 1.00 | 0.23 | 0.15 | 410 |
| cunhal_1m | 0.53 | 0.98 | 0.14 | 422 |
| embasamento_1m | 1.00 | 0.96 | 0.14 | 174 |
| grade_janela | 1.00 | 1.56 | 0.22 | 28 |
| janela_colonial | 1.46 | 1.86 | 0.27 | 33 |
| janela_guilhotina | 1.52 | 2.15 | 0.26 | 77 |
| porta_balcao | 1.52 | 2.72 | 0.18 | 25 |
| porta_bandeira | 1.60 | 3.14 | 0.42 | 11 |
| porta_dupla | 2.30 | 2.99 | 0.58 | 20 |
| sacada_1m | 1.00 | 1.44 | 1.20 | 24 |
| sacada_ferro | 1.66 | 1.56 | 0.76 | 41 |
| veneziana | 0.52 | 1.56 | 0.04 | 57 |
| veneziana_e | 0.52 | 1.56 | 0.04 | 57 |

Regras de encaixe: cunhal e embasamento em módulos de 1 m; cunhal a 0,26 m da quina; embasamento pula o vão da porta (1,3 m); sacada de ferro só sobre porta-balcão do 2º andar; janela/porta nos vãos da fachada; cornija e cachorros no topo da parede; beiral de telhas a cada 1 m.


## Casas (ficha)

| Nº | Casa | s (m) | Lado | Largura × fundo (m) | Andares | Altura (m) | Porta (x, y, z) | Visitável | Módulos |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Casa_270 | 2.0 | -1 | 5.30 × 11.00 | 2 | 7.40 | (-2.90, 0.28, 11.87) |  | beiral_telhas×5, cachorro_beiral×5, cornija×6, cunhal×14, embasamento×2, grade_janela×1, janela_guilhotina×1, porta_balcao×2, porta_bandeira×1, sacada_ferro×2 |
| 3 | Casa_255 | 11.0 | -1 | 9.62 × 8.37 | 1 | 4.15 | (-2.90, 1.00, 3.19) | benedita | beiral_telhas×9, cachorro_beiral×10, cornija×10, cunhal×8, embasamento×7, janela_guilhotina×2, veneziana×2, veneziana_e×2 |
| 5 | Casa_271 | 17.5 | -1 | 4.70 × 11.00 | 2 | 7.40 | (-2.90, 1.52, -3.28) |  | beiral_telhas×4, cachorro_beiral×5, cornija×5, cunhal×14, embasamento×1, grade_janela×1, janela_guilhotina×1, porta_balcao×2, porta_bandeira×1, sacada_ferro×2, veneziana×1, veneziana_e×1 |
| 7 | Casa_297 | 56.5 | -1 | 5.81 × 11.00 | 1 | 4.00 | (30.55, 3.61, -18.90) |  | beiral_telhas×5, cachorro_beiral×6, chamine×1, cornija×6, cunhal×8, embasamento×2, janela_guilhotina×1, porta_dupla×1, veneziana×1, veneziana_e×1 |
| 9 | Casa_298 | 80.5 | -1 | 7.60 × 11.00 | 2 | 7.40 | (54.23, 4.69, -18.90) |  | beiral_telhas×7, cachorro_beiral×8, cornija×8, cunhal×14, embasamento×5, grade_janela×2, janela_guilhotina×2, sacada_ferro×1, veneziana×2, veneziana_e×2 |
| 11 | Casa_299 | 88.5 | -1 | 8.04 × 5.00 | 1 | 4.00 | (62.20, 5.05, -18.90) |  | cachorro_beiral×8, chamine×1, cornija×9, janela_colonial×2, veneziana×2, veneziana_e×2 |
| 13 | Casa_330 | 149.0 | -1 | 6.86 × 5.00 | 2 | 7.40 | (62.44, 10.71, -47.10) |  | beiral_telhas×6, cachorro_beiral×7, cornija×7, cunhal×14, embasamento×3, grade_janela×1, janela_guilhotina×3, porta_balcao×2, porta_bandeira×1, sacada_ferro×2 |
| 15 | Casa_260 | 158.5 | -1 | 8.37 × 7.12 | 1 | 4.15 | (52.82, 11.13, -47.10) | barbearia | beiral_telhas×8, cachorro_beiral×9, chamine×1, cornija×9, cunhal×8, embasamento×4, janela_guilhotina×2, porta_dupla×1 |
| 17 | Casa_331 | 183.5 | -1 | 5.87 × 11.00 | 2 | 7.40 | (28.05, 12.26, -47.10) |  | beiral_telhas×5, cachorro_beiral×6, cornija×6, cunhal×14, embasamento×3, janela_guilhotina×1, sacada_ferro×2, veneziana×1, veneziana_e×1 |
| 19 | Casa_332 | 193.5 | -1 | 7.04 × 11.00 | 2 | 7.40 | (18.25, 12.71, -47.10) |  | beiral_telhas×7, cachorro_beiral×7, chamine×1, cornija×8, cunhal×14, embasamento×4, grade_janela×1, janela_guilhotina×2, sacada_ferro×2 |
| 21 | Casa_333 | 201.0 | -1 | 8.22 × 11.00 | 1 | 4.00 | (10.61, 13.05, -47.10) |  | beiral_telhas×8, cachorro_beiral×9, cornija×9, cunhal×8, embasamento×6, grade_janela×1, janela_guilhotina×2, veneziana×1, veneziana_e×1 |
| 23 | Casa_355 | 261.0 | -1 | 5.08 × 11.00 | 2 | 7.40 | (8.08, 18.68, -86.90) |  | cachorro_beiral×5, chamine×1, cornija×6, janela_colonial×1, sacada×4, veneziana×1, veneziana_e×1 |
| 25 | Casa_356 | 275.0 | -1 | 6.87 × 11.00 | 1 | 4.00 | (21.89, 19.31, -86.90) |  | beiral_telhas×6, cachorro_beiral×7, cornija×7, cunhal×8, embasamento×4, grade_janela×1, janela_guilhotina×2 |
| 27 | Casa_357 | 285.5 | -1 | 7.91 × 11.00 | 2 | 7.40 | (32.41, 19.79, -86.90) |  | beiral_telhas×7, cachorro_beiral×8, cornija×8, cunhal×14, embasamento×3, grade_janela×1, janela_guilhotina×4, porta_balcao×1, porta_dupla×1, sacada_ferro×1, veneziana×2, veneziana_e×2 |
| 29 | Casa_358 | 293.0 | -1 | 5.18 × 11.00 | 2 | 7.40 | (39.93, 20.12, -86.90) |  | cachorro_beiral×5, chamine×1, cornija×6, janela_colonial×1, sacada×4, veneziana×1, veneziana_e×1 |
| - | Casa_359 | 303.0 | -1 | 6.86 × 11.00 | 1 | 4.00 | (49.97, 20.57, -86.90) |  | cachorro_beiral×7, cornija×7, janela_colonial×2, porta_dupla×1 |
| 31 | Casa_360 | 315.0 | -1 | 5.60 × 11.00 | 2 | 7.40 | (62.29, 21.11, -86.90) |  | beiral_telhas×5, cachorro_beiral×6, chamine×1, cornija×6, cunhal×14, embasamento×3, grade_janela×1, janela_guilhotina×1, porta_balcao×2, porta_bandeira×1, sacada_ferro×2 |
| 33 | Casa_261 | 381.0 | -1 | 13.37 × 10.87 | 1 | 9.90 | (57.32, 27.02, -115.10) | casarao | beiral_telhas×13, cachorro_beiral×14, cornija×14, cunhal×18, embasamento×10, janela_guilhotina×4, porta_dupla×1, veneziana×4, veneziana_e×4 |
| 35 | Casa_389 | 398.5 | -1 | 6.92 × 11.00 | 2 | 7.40 | (39.93, 27.81, -115.10) |  | beiral_telhas×6, cachorro_beiral×7, cornija×7, cunhal×14, embasamento×3, janela_guilhotina×3, porta_balcao×2, porta_bandeira×1, sacada_ferro×2, veneziana×3, veneziana_e×3 |
| 37 | Casa_390 | 408.5 | -1 | 6.38 × 11.00 | 2 | 7.40 | (30.10, 28.26, -115.10) |  | beiral_telhas×6, cachorro_beiral×7, chamine×1, cornija×7, cunhal×14, embasamento×3, grade_janela×1, janela_guilhotina×1, porta_balcao×2, porta_dupla×1, sacada_ferro×2 |
| - | Casa_402 | 436.5 | -1 | 6.78 × 11.00 | 1 | 4.00 | (-3.20, 29.67, -130.89) |  | beiral_telhas×6, cachorro_beiral×7, cornija×7, cunhal×8, embasamento×3, grade_janela×1, janela_guilhotina×2, porta_dupla×1 |
| 39 | Casa_403 | 444.0 | -1 | 10.17 × 11.00 | 3 | 10.80 | (-3.20, 29.89, -138.26) |  | cachorro_beiral×11, chamine×1, cornija×11, janela_colonial×3, veneziana×2, veneziana_e×2 |
| 41 | Casa_404 | 451.5 | -1 | 10.60 × 11.00 | 2 | 7.40 | (-3.20, 30.12, -146.25) |  | cachorro_beiral×11, chamine×1, cornija×11, janela_colonial×5, porta_dupla×3, sacada×5, veneziana×2, veneziana_e×2 |
| 43 | Casa_405 | 467.0 | -1 | 8.44 × 11.00 | 2 | 7.40 | (-3.20, 30.58, -161.68) |  | beiral_telhas×8, cachorro_beiral×9, cornija×9, cunhal×14, embasamento×5, janela_guilhotina×2, sacada_ferro×1, veneziana×1, veneziana_e×1 |
| 45 | Casa_406 | 477.5 | -1 | 10.07 × 11.00 | 1 | 4.00 | (-3.20, 30.90, -171.84) |  | beiral_telhas×10, cachorro_beiral×11, cornija×11, cunhal×8, embasamento×7, grade_janela×3, janela_guilhotina×3 |
| 2 | Casa_257 | 7.5 | +1 | 10.87 × 8.87 | 1 | 4.28 | (2.90, 0.72, 6.57) | padaria | beiral_telhas×10, cachorro_beiral×12, cornija×11, cunhal×8, embasamento×7, janela_guilhotina×2, porta_dupla×1 |
| 4 | Casa_269 | 17.0 | +1 | 6.00 × 11.00 | 2 | 7.40 | (2.90, 1.48, -3.19) |  | beiral_telhas×6, cachorro_beiral×6, cornija×6, cunhal×14, embasamento×4, janela_guilhotina×1, sacada_ferro×2 |
| 6 | Casa_272 | 45.5 | +1 | 9.81 × 7.50 | 2 | 7.40 | (19.12, 3.11, -13.10) |  | beiral_telhas×9, cachorro_beiral×10, chamine×1, cornija×10, cunhal×14, embasamento×6, grade_janela×1, janela_guilhotina×4, porta_balcao×3, porta_bandeira×1, sacada_ferro×3, veneziana×2, veneziana_e×2 |
| 8 | Casa_256 | 53.0 | +1 | 10.87 × 8.37 | 1 | 4.40 | (26.93, 3.45, -13.10) | carpintaria | beiral_telhas×10, cachorro_beiral×12, chamine×1, cornija×11, cunhal×8, embasamento×7, janela_guilhotina×2, veneziana×2, veneziana_e×2 |
| 10 | Casa_258 | 74.0 | +1 | 10.87 × 8.37 | 1 | 4.28 | (47.94, 4.39, -13.10) | venda | beiral_telhas×10, cachorro_beiral×12, chamine×1, cornija×11, cunhal×8, embasamento×7, janela_guilhotina×1 |
| 12 | Casa_273 | 88.0 | +1 | 9.48 × 11.00 | 2 | 7.40 | (61.64, 5.02, -13.10) |  | cachorro_beiral×10, cornija×10, janela_colonial×5, porta_bandeira×1, porta_dupla×2, veneziana×3, veneziana_e×3 |
| 14 | Casa_300 | 147.5 | +1 | 4.98 × 11.00 | 2 | 7.40 | (63.95, 10.64, -52.90) |  | cachorro_beiral×5, chamine×1, cornija×5, janela_colonial×1, sacada×4, veneziana×1, veneziana_e×1 |
| 16 | Casa_310 | 168.0 | +1 | 9.65 × 11.00 | 1 | 4.00 | (43.75, 11.56, -52.90) |  | beiral_telhas×9, cachorro_beiral×10, chamine×1, cornija×10, cunhal×8, embasamento×7, grade_janela×2, janela_guilhotina×3, veneziana×1, veneziana_e×1 |
| 18 | Casa_319 | 185.5 | +1 | 8.21 × 11.00 | 2 | 7.40 | (26.27, 12.35, -52.90) |  | beiral_telhas×8, cachorro_beiral×9, chamine×1, cornija×9, cunhal×14, embasamento×4, janela_guilhotina×3, porta_balcao×2, porta_bandeira×1, sacada_ferro×2, veneziana×2, veneziana_e×2 |
| 20 | Casa_320 | 195.5 | +1 | 6.81 × 11.00 | 2 | 7.40 | (16.12, 12.80, -52.90) |  | cachorro_beiral×7, chamine×1, cornija×7, janela_colonial×2, sacada×2 |
| 22 | Casa_334 | 268.0 | +1 | 8.81 × 11.00 | 2 | 7.40 | (14.93, 19.00, -81.10) |  | beiral_telhas×8, cachorro_beiral×9, chamine×1, cornija×9, cunhal×14, embasamento×6, grade_janela×1, janela_guilhotina×2, sacada_ferro×1, veneziana×2, veneziana_e×2 |
| 24 | Casa_259 | 282.0 | +1 | 13.37 × 10.87 | 1 | 4.65 | (29.18, 19.63, -81.10) | escola | beiral_telhas×13, cachorro_beiral×14, cornija×14, cunhal×8, embasamento×10, janela_guilhotina×2, porta_dupla×1, veneziana×1, veneziana_e×1 |
| 26 | Casa_335 | 291.0 | +1 | 9.13 × 11.00 | 2 | 7.40 | (38.25, 20.03, -81.10) |  | beiral_telhas×9, cachorro_beiral×10, cornija×10, cunhal×14, embasamento×5, grade_janela×2, janela_guilhotina×3, porta_balcao×2, porta_bandeira×1, sacada_ferro×2, veneziana×1, veneziana_e×1 |
| 28 | Casa_345 | 309.0 | +1 | 9.66 × 11.00 | 2 | 7.40 | (56.23, 20.84, -81.10) |  | cachorro_beiral×10, chamine×1, cornija×10, janela_colonial×5, porta_dupla×3, sacada×5, veneziana×2, veneziana_e×2 |
| 30 | Casa_262 | 380.5 | +1 | 8.37 × 7.12 | 1 | 4.03 | (57.82, 27.00, -120.90) | sineiro | beiral_telhas×8, cachorro_beiral×9, chamine×1, cornija×9, cunhal×8, embasamento×4, janela_guilhotina×2, porta_dupla×1, veneziana×2, veneziana_e×2 |
| 32 | Casa_370 | 386.5 | +1 | 10.75 × 11.00 | 2 | 7.40 | (51.69, 27.27, -120.90) |  | beiral_telhas×10, cachorro_beiral×11, cornija×11, cunhal×14, embasamento×8, janela_guilhotina×3, sacada_ferro×3, veneziana×2, veneziana_e×2 |
| 34 | Casa_371 | 397.5 | +1 | 8.15 × 11.00 | 2 | 7.40 | (40.98, 27.76, -120.90) |  | beiral_telhas×8, cachorro_beiral×9, cornija×9, cunhal×14, embasamento×5, grade_janela×1, janela_guilhotina×2, sacada_ferro×1, veneziana×2, veneziana_e×2 |
| 36 | Casa_372 | 405.5 | +1 | 8.75 × 11.00 | 1 | 4.00 | (32.73, 28.12, -120.90) |  | cachorro_beiral×9, chamine×1, cornija×9, janela_colonial×2, veneziana×1, veneziana_e×1 |
| 38 | Casa_398 | 442.0 | +1 | 10.81 × 11.00 | 3 | 10.80 | (25.20, 29.83, -136.71) |  | beiral_telhas×10, cachorro_beiral×12, chamine×1, cornija×11, cunhal×20, embasamento×7, grade_janela×3, janela_guilhotina×3, sacada_ferro×3, veneziana×3, veneziana_e×3 |
| 40 | Casa_399 | 453.0 | +1 | 8.18 × 11.00 | 2 | 7.40 | (25.20, 30.16, -147.40) |  | beiral_telhas×8, cachorro_beiral×9, cornija×9, cunhal×14, embasamento×4, grade_janela×1, janela_guilhotina×2, porta_balcao×3, porta_bandeira×1, sacada_ferro×3, veneziana×1, veneziana_e×1 |
| 42 | Casa_400 | 464.5 | +1 | 9.21 × 11.00 | 2 | 7.40 | (25.20, 30.51, -158.76) |  | cachorro_beiral×10, cornija×10, janela_colonial×4, porta_dupla×2, veneziana×2, veneziana_e×2 |
| 44 | Casa_401 | 470.5 | +1 | 8.43 × 11.00 | 2 | 7.40 | (25.20, 30.69, -164.92) |  | beiral_telhas×8, cachorro_beiral×9, chamine×1, cornija×9, cunhal×14, embasamento×5, grade_janela×2, janela_guilhotina×3, porta_balcao×2, porta_bandeira×1, sacada_ferro×2, veneziana×1, veneziana_e×1 |

## Objetos em cena (resumo por grupo; posições exatas no planta.json)

| Grupo | Quantidade |
|---|---|
| Adornos | 44 |
| Adro | 67 |
| Becos | 11 |
| Coletaveis | 29 |
| Iluminacao | 19 |
| Interiores | 6 |
| MurosDasCurvas | 282 |
| MurosEQuintais | 17 |
| Nichos | 6 |
| Ponte | 71 |
| Props | 23 |
| PropsEncosta | 154 |
| Ratos | 8 |

## Conferência dos módulos

Nenhum problema: todos os módulos dentro da parede, nenhum cobrindo janela/porta, nenhum atravessando outro, toda sacada com porta-balcão.
