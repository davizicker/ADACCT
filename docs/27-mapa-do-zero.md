# Mapa do zero: plano (v30)

Pedido do dono: refazer o mapa inteiro do zero, com rua em zigue-zague até a igreja, mais caminhos alternativos
(becos que ligam as ruas), e **nenhuma colisão** entre casas, becos, ruas e objetos, desde o princípio.

## Por que refazer
O mapa antigo era uma rua em curva livre (spline) e as casas eram caixas postas uma depois da outra. Nas curvas as caixas giravam
umas contra as outras; o código "encolhia" a casa depois, por tentativa. Becos e atalhos eram desenhados por cima disso.
Resultado: paredes atravessando salas, beiral dentro de beco, beco que leva ao vazio, porta desalinhada.

## Regra nova (colisão impossível por construção)
1. **Traçado em peças retas e curvas de raio fixo.** A rua é feita de pernas retas (alinhadas aos eixos) ligadas por curvas de 180° (grampos)
   e de 90°. Em reta, todo lote é um retângulo alinhado: não há giro entre vizinhas.
2. **Plano antes da obra.** Um gerador (`tools/plano_vila.gd`) calcula TUDO no papel: rua, lotes, casas, becos, praças, quintais.
   Cada coisa é um retângulo registrado num **cadastro**. Nada entra se tocar em algo já cadastrado (teste exato de retângulos).
3. **Reserva por prioridade.** Primeiro: rua e calçadas. Depois: becos que ligam as pernas (corredor inteiro, de uma rua até a outra).
   Depois: casas visitáveis (tamanho exato da sala). Por último: casas comuns e quintais, que se ajustam ao que sobrou.
4. **Curvas sem casas.** No lado de fora dos grampos: muro de arrimo, lampiões e árvores. No miolo do grampo: largo com capela,
   chafariz ou jardim. Nenhuma caixa de casa em curva.
5. **Prova antes de construir.** O gerador escreve `docs/plano_vila.json` e uma planta em imagem (vista de cima, tudo colorido).
   O cadastro tem de dar **0 sobreposições**. Só então a vila 3D é construída a partir do plano.

## Traçado
- Entrada: subida reta (rua da estação) até a primeira curva de 90°.
- **Quatro pernas em zigue-zague** (≈ 60 m cada, 34 m de uma para a outra), ligadas por três grampos de 180°.
- Última curva de 90° até o **adro da igreja**, no alto.
- **Caminhos alternativos:** dois becos-escada em cada quarteirão entre pernas (seis atalhos no total), alinhados com os lotes,
  retos, com parede dos dois lados e chão contínuo. Mais becos sem saída curtos para as casas dos becos (ferraria, pensão...).
- Ponte sobre o córrego na primeira perna; chafariz num largo de grampo.

## Etapas
1. Gerador do plano + planta em imagem + cadastro com 0 sobreposições. (esta rodada)
2. Rota nova (`scripts/route.gd`) a partir do plano; terreno; calçamento; muros de arrimo.
3. Casas, casas visitáveis com as salas, becos-escada, becos sem saída; testes de caminhar e de becos.
4. Igreja e adro, ponte, chafariz, lampiões, altares, props, itens e bilhetes redistribuídos.
5. Bateria completa, fotos de cada canto, zip.
