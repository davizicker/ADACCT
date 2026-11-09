# Armadilhas técnicas aprendidas

- Nunca editar `scenes/vila.scn` à mão: editar o gerador (`tools/vila_builder.gd`, `interiores.gd`, `bake.gd`) e reconstruir.
- Sempre `--check-only` antes do bake; erros de tipo inferido (`var x := ...` em laços e com `Variant`) travam o bake.
- Classes novas (`class_name`) só valem depois de `--import`.
- Mudar a rota desloca todas as distâncias `s` (ponte, fonte, igreja, notas, lojas): usar `Route.SHIFT` e revisar literais.
- Nunca `pkill -f` com texto que aparece no próprio comando (derruba o shell): matar por PID.
- Peças em lotes grandes de malha podem sumir (portas): usar nó separado.
- Halo com textura em neblina vira quadrado: usar o shader próprio.
- Modelos do Poly Haven às vezes são "folhas de catálogo": separar por nome de malha (`PropKit.make_filtrado`). Medir a frente de cada modelo antes de girar (cadeira painted_wooden_chair_02 olha para +X; os demais olham para +Z).
- Reposicionar cada móvel separadamente desalinha grupos (mesa e cadeiras): ampliar a sala inteira por escala uniforme, ou posicionar relativo a uma âncora.
- Foto com a vila inteira carregada é lenta: esconder tudo menos as salas; `scaling_3d_scale = 0.5`.
- Nunca dois processos pesados do Godot ao mesmo tempo; confirmar que o processo ainda existe antes de dizer que um teste acabou.
- Aviso de auditoria nem sempre é defeito: investigar antes de "corrigir".
- Decalques, neblina volumétrica, SSAO, SSR e sombras suaves só existem no Forward+: não aparecem nas fotos em compatibilidade; declarar como não verificados.
- `.gltf` sem `.bin`/texturas e `.sbsar` não podem ser usados: pedir pacote completo ou PNGs.
- Texturas BC7 deixam captura e testes lentíssimos: usar cópia de teste com texturas sem compressão (copiar também materiais, malhas, fontes, shaders e texturas novos).
- Nada que não existisse em 1961 (o micro-ondas foi convertido e não usado).
