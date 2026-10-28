# Editar e modelar o jogo pelo próprio Godot

**Resposta curta: dá.** O projeto abre normalmente no Godot 4.7 (`project.godot`) e você pode mover, apagar e adicionar coisas com o mouse.
Só precisa entender **o que é gerado por código e o que é seu**.

## O que é gerado por código (e vai ser sobrescrito)
A vila inteira (rua, casas, becos, árvores, props) é criada por `tools/bake.gd` e gravada em `scenes/vila.scn`. Se você mexer
nesse arquivo no editor e depois rodar o bake de novo (`bash rebuild`), **suas mudanças nele somem**. Por isso existe uma camada só sua:

## Camada manual: `scenes/ajustes.tscn` (nunca é apagada)
1. No Godot, abra `scenes/ajustes.tscn` (duplo clique no FileSystem).
2. Arraste qualquer `.glb` de `assets/models/` (poly, containers, arms, gerados/ da Fábrica 3D...) para a janela 3D. Ele vira filho de "Ajustes".
3. Posicione com **W** (mover), **E** (girar), **R** (escalar); para encostar no chão use *Snap* (Y) ou digite a posição no Inspetor.
4. **Ctrl+S**. Aperte **F5** para jogar (ou F6 para rodar a cena atual).
Como achar o lugar certo: rode o jogo, ande até o ponto e veja o `s` na tela de depuração (F3), ou abra `scenes/main.tscn`
— a vila aparece lá dentro como "Vila" (você vê o mundo e pode andar a câmera, mas edite só o "Ajustes").

### Apagar um objeto gerado (barril, planta, lampião, caixote...)
Dentro de "Ajustes" adicione um nó **ZonaLimpa** (Add Node → procure *ZonaLimpa*). Ele é uma caixa vermelha: ajuste *Tamanho* e posição para envolver
o objeto. Ao iniciar o jogo, tudo que for **instância individual** gerada ali dentro é removido.
**Não funciona** para o que foi fundido numa malha única para dar desempenho (paredes, telhados, calçamento, janelas): isso se muda no código (`tools/vila_builder.gd`).

## Modelar de verdade
O Godot não é um programa de modelagem completo. O fluxo que funciona:
- **Blender** (grátis): modele, exporte `.glb`, solte em `assets/models/` — o Godot importa sozinho.
- **Fábrica 3D** do projeto (`docs/15`, `docs/16`): gera modelos a partir de imagem.
- Dentro do Godot: *CSGBox/CSGCylinder* (blocos rápidos, bom para protótipo), *GridMap* (peças em grade) e `MeshInstance3D` com malhas importadas.
  Para blocos permanentes, converta CSG em malha (*CSG → Create MeshInstance*) e salve em `Ajustes`.

## Se você quiser que uma mudança vire parte do mundo gerado
Peça aqui, ou edite `tools/vila_builder.gd` / `tools/detalhes.gd` / `tools/interiores.gd`, depois rode `bash rebuild` e os testes (`docs/14`, seção 10).
Mudanças no **jogador** (`scenes/jogador.tscn`, `scripts/player.gd`), **menus**, **sons** e **scripts** podem ser feitas direto no editor: nada disso é regerado
(exceto `jogador.tscn`, `bradador.tscn`, `mula.tscn`, `casa.tscn`, `poste.tscn`, que o bake também recria — copie para outra cena antes de editar).

## Atalhos úteis do editor
F5 jogar · F6 cena atual · botão direito do mouse + WASD voa na vista 3D (Shift acelera) · F foca o objeto selecionado.
