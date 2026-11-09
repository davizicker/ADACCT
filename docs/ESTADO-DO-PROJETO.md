# Estado do projeto (arquivo vivo: a skill bradador-dev atualiza a cada ciclo)

**Versão do jogo:** v27 em verificação (data: 9 de novembro de 2026)

## Verificado em teste
- v25: pulo, 13 casas, 22 itens, esconder, Mula (rua/refúgio), salvar, fuga, becos e caminhada (centro, +1,5, -1,5). Auditorias zeradas.
- Desde a v25 a bateria NÃO foi rodada de novo (rua mais longa, interiores ampliados, novas mecânicas).

## Visto em foto
- Adro, fachada da igreja, placa com nova fonte, beco com arcos, altar, porta, vista aérea, interior da casa de Dona Benedita (versão anterior ao alinhamento por medida).

## NÃO verificado
- FPS em GPU real; efeitos do Forward+ (neblina volumétrica, SSAO, SSR, decalques, sombras suaves); texturas comprimidas BC7 em placa real.
- No código mas sem foto na versão atual: segundo andar do Casarão, igreja exuberante por dentro, medalhas, comida, portas que abrem, placas de entrada/tábuas, alinhamento milimétrico dos móveis, térreo de pedra, chaminés.

## Decisões tomadas
- Salas ampliadas por escala uniforme (1,25x) para não desalinhar móveis.
- Chuva só por opção do menu.
- Micro-ondas convertido e não usado (anacronismo).

## Pendências com o dono
- Cama gótica: falta o pacote com .bin e texturas.
- Telha Substance: exportar BaseColor/Normal/Roughness/AO em PNG.
- Animações Human Basic Motions: decidir uso.

## Próximos passos
1. Terminar o tour das 14 salas e corrigir tudo fora do lugar. 2. Rodar a bateria completa. 3. Mapa fora de linha. 4. Entregar v27 com as três listas.
