# Protocolo de verificação (nada é entregue sem isto)

1. **Reconstrução em duas passagens:** gerar texturas, importar, rodar `tools/bake.gd`, importar; rodar `tools/interior_cubes.gd` (fotografa as 14 salas); rodar o bake de novo. Conferir "peças soltas = 0".
2. **Cópia de teste** com texturas sem compressão. Copiar também materiais, malhas, fontes, shaders, texturas e modelos novos.
3. **Tour fotográfico das salas:** `tools/foto_salas.gd -- <pasta>` (uma carga do jogo, 4 ângulos por sala). Gerar folhas de contato e **abrir cada folha**. Anotar defeitos por sala.
4. **Fotos de perto:** portas, altares, becos, igreja (6 lados), adro (4 lados), vista aérea com `tools/foto_pos.gd ... mapa`.
5. **Relatório de medidas** `docs/23-medidas-dos-moveis.md`: peças de modelo com giro múltiplo de 90° e folga de poucos mm até a parede, salvo as intencionais.
6. **Auditorias:** `tools/auditoria_moveis.gd`, `_luzes`, `_portas`, `_geom`, `_pecas`, `_lugar`, `_itens`, `_texturas`.
7. **Testes** (um de cada vez): `--selftest-pulo`, `-casas`, `-itens`, `-esconder`, `-mula=refugio`, `-mula=rua`, `-save`, `-escape`, `-becos`, `-walk` (centro, +1,5 e -1,5).
8. Entregar só com todas as folhas abertas, testes verdes e as listas de "não verificado" escritas. Gerar o zip com `zip -qr` excluindo `.git`, `.godot`, `tools/ia3d`, e mandar com fotos.
