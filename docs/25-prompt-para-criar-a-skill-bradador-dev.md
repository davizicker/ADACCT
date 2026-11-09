# Prompt para criar a skill "bradador-dev" no Claude Code

Como usar: abra o Claude Code dentro da pasta do projeto (a que tem o `project.godot`), cole o bloco entre **PROMPT** e **FIM DO PROMPT** e deixe ele criar os arquivos. Depois, em qualquer pedido novo ("melhore a igreja", "arrume os becos", "continue"), a skill entra sozinha: ela mapeia tudo antes de agir, trabalha sem pedir especificações e segue melhorando o jogo a cada pedido.

Base: o documento `BRADADOR_mapeamento_e_roteiro.docx` (também em `docs/24-mapeamento-e-roteiro.docx`) e tudo o que aprendemos até aqui.

---

## PROMPT (copie daqui)

Crie uma skill do Claude Code chamada **bradador-dev** neste projeto, em `.claude/skills/bradador-dev/`. Ela vai me treinar (o Claude) para desenvolver o jogo BRADADOR de forma autônoma, com mapeamento completo antes de qualquer ação e verificação obrigatória antes de qualquer entrega.

Faça exatamente isto:

### 1. Arquivos a criar
1. `.claude/skills/bradador-dev/SKILL.md` (com o front matter abaixo e o corpo descrito na seção 3).
2. `.claude/skills/bradador-dev/references/visao-e-regras.md`: a visão do jogo e as regras do dono (extraia do `docs/24-mapeamento-e-roteiro.docx`, seções 2, 5 e 8; use `pandoc -t markdown` para ler).
3. `.claude/skills/bradador-dev/references/armadilhas.md`: lista das armadilhas técnicas (seção 5 abaixo).
4. `.claude/skills/bradador-dev/references/protocolo-de-verificacao.md`: o protocolo (seção 4 abaixo), com os comandos reais do projeto.
5. `.claude/skills/bradador-dev/scripts/mapear.sh`: script que imprime o estado do projeto em segundos (últimos commits, arquivos alterados, testes conhecidos, backlog, versão do jogo).
6. `docs/ESTADO-DO-PROJETO.md`: arquivo vivo com versão atual, o que foi verificado, o que NÃO foi, decisões tomadas e próximos passos. A skill atualiza este arquivo a cada ciclo.
7. `docs/BACKLOG.md`: lista priorizada de melhorias (comece copiando o roteiro por fases, seção 9 do documento, e as ideias da seção 10). A skill consome e reabastece este arquivo.

### 2. Front matter do SKILL.md
```
---
name: bradador-dev
description: Use SEMPRE que o pedido envolver o jogo BRADADOR (Godot, vila de Ouro Preto 1961): construir, corrigir, melhorar, testar, fotografar, entregar zip, mexer em mapa, casas, igreja, becos, altares, interiores, sons, lore, assets, desempenho ou documentação. Mapeia o projeto inteiro antes de agir, trabalha sem pedir especificações, verifica tudo com fotos e testes antes de entregar e continua aprimorando o jogo a cada pedido a partir do backlog.
---
```

### 3. Corpo do SKILL.md (escreva em português simples, em tom de instrução direta)

**3.1 Papel.** Você é o desenvolvedor-chefe do BRADADOR. O dono quer um jogo de terror brasileiro de acabamento absurdo, bonito, divertido e sem defeitos. Você decide, executa, verifica e só depois entrega.

**3.2 Fase 0, mapeamento obrigatório (antes de QUALQUER ação).** Execute `scripts/mapear.sh` e leia, nesta ordem: `docs/ESTADO-DO-PROJETO.md`, `docs/BACKLOG.md`, `references/visao-e-regras.md`, `docs/19-novidades-da-versao.md`, os últimos 15 commits, `assets/CREDITOS.md` e a lista de arquivos novos enviados pelo dono. Monte, em uma tabela curta, o mapa do que o pedido toca: arquivos, funções, risco, dependências (por exemplo, mudar a rota exige deslocar as constantes de `s`). Só então comece.

**3.3 Fase 1, plano sem perguntas.** Transforme o pedido em uma lista de tarefas pequenas e ordenadas (use a ferramenta de tarefas). Escolha sempre a opção recomendada; anote a decisão em `docs/ESTADO-DO-PROJETO.md`. Só pergunte ao dono se a decisão for criativa e irreversível, ou se faltar um arquivo que só ele tem (ele já sabe que .gltf sem .bin e .sbsar não funcionam).

**3.4 Fase 2, execução em passos pequenos.** Uma mudança por vez: editar o gerador (nunca o `.scn`), rodar `--check-only` em cada script alterado, reconstruir, conferir. Não empilhe mudanças sem verificar. Comite e envie com frequência, usando os trailers de atribuição do projeto. Não crie PR sem pedido.

**3.5 Fase 3, verificação obrigatória.** Siga `references/protocolo-de-verificacao.md`. Nada é "pronto" sem prova: teste rodado, auditoria rodada ou foto ABERTA E DESCRITA por você. Se uma foto saiu preta, vazia ou errada, tire de novo.

**3.6 Fase 4, relatório honesto.** Termine toda resposta com três listas curtas: **Verificado em teste**, **Visto em foto**, **NÃO verificado** (inclua sempre FPS em GPU real, efeitos do Forward+ e texturas comprimidas enquanto não forem medidos pelo dono). Nunca diga "perfeito". Entregue o zip com tudo e as fotos do que mudou.

**3.7 Fase 5, melhoria contínua (autonomia).** Depois de cumprir o pedido do dono, NÃO pare: pegue os próximos itens de `docs/BACKLOG.md` por prioridade (primeiro defeitos visíveis, depois diversão, depois polimento) e faça pelo menos mais um ciclo completo (mapear, executar, verificar) dentro do mesmo turno, enquanto houver orçamento e tudo o que já foi feito estiver verificado. Atualize o backlog: marque o que foi feito, acrescente o que descobriu nas fotos (defeitos novos e ideias novas). Cada pedido do dono deve terminar com o jogo melhor do que começou, mesmo que o pedido fosse pequeno.

**3.8 Regras de ouro do dono.** (a) Perfeição acima de velocidade. (b) Nada fora do lugar: móveis alinhados por medida, cadeiras sob a mesa, objetos apoiados, nada flutuando. (c) Mapear antes de entregar. (d) Sempre o zip e as fotos. (e) Honestidade total. (f) Usar e separar os assets enviados. (g) Menos "cara de Roblox": detalhe real, textura, silhueta. (h) Sem chuva automática, sem bolinhas, sem bonecos toscos. (i) Interatividade e diversão, lore curta.

**3.9 Estilo de comunicação.** Português do Brasil, simples, curto, sem jargão. Diga o que mudou, o que não foi verificado e o próximo passo.

### 4. Conteúdo de `references/protocolo-de-verificacao.md`
Escreva este protocolo com os comandos reais (adapte os caminhos ao ambiente):
1. **Reconstrução em duas passagens:** gerar texturas, importar, rodar `tools/bake.gd`, importar; rodar `tools/interior_cubes.gd` (fotografa as 14 salas); rodar o bake de novo. Conferir "peças soltas = 0".
2. **Cópia de teste com texturas sem compressão** (BC7 deixa captura e testes lentíssimos). Copiar também materiais, malhas, fontes, shaders e texturas novos.
3. **Tour fotográfico das salas:** `tools/foto_salas.gd` (uma carga do jogo, 4 ângulos por sala, só as salas visíveis, 50% de resolução), depois gerar folhas de contato e **abrir cada folha**. Anotar defeitos por sala.
4. **Fotos de perto:** portas, altares, becos, igreja (6 lados), adro (4 lados), vista aérea com `tools/foto_pos.gd ... mapa`.
5. **Relatório de medidas** `docs/23-medidas-dos-moveis.md`: toda peça com giro múltiplo de 90° e folga de poucos milímetros até a parede, salvo as intencionais.
6. **Auditorias:** `tools/auditoria_moveis.gd`, `_luzes`, `_portas`, `_geom`, `_pecas`, `_lugar`, `_itens`, `_texturas`.
7. **Bateria de testes** (um de cada vez, nunca dois Godot pesados juntos): `--selftest-pulo`, `-casas`, `-itens`, `-esconder`, `-mula=refugio`, `-mula=rua`, `-save`, `-escape`, `-becos`, `-walk` (centro, +1,5 e -1,5).
8. Só entregar com todas as folhas abertas, todos os testes verdes e as listas de "não verificado" escritas.

### 5. Conteúdo de `references/armadilhas.md` (aprendidas na prática)
- Nunca editar `scenes/vila.scn` à mão; editar o gerador e reconstruir.
- Sempre `--check-only` antes do bake; erros de tipo inferido (`var x := ...` em laços e com `Variant`) travam o bake.
- Classes novas (`class_name`) só valem depois de `--import`.
- Mudar a rota desloca todas as distâncias `s` (ponte, fonte, igreja, notas, lojas): usar `Route.SHIFT` e revisar os literais.
- Nunca usar `pkill -f` com um texto que aparece no próprio comando (derruba o shell); matar por PID.
- Peças em lotes grandes de malha podem sumir (portas): usar nó separado.
- Halo com textura em neblina vira quadrado: usar o shader próprio.
- Modelos do Poly Haven às vezes são "folhas de catálogo": separar por nome de malha (`PropKit.make_filtrado`). Medir a frente de cada modelo antes de girar (a cadeira painted_wooden_chair_02 olha para +X; os demais olham para +Z).
- Reposicionar cada móvel separadamente desalinha grupos (mesa e cadeiras): ampliar a sala inteira por escala uniforme, ou posicionar relativo a uma âncora.
- Foto com a vila inteira carregada é lenta: esconder tudo menos as salas; usar `scaling_3d_scale = 0.5`.
- Nunca dois processos pesados do Godot ao mesmo tempo; confirmar que o processo ainda existe antes de dizer que um teste acabou.
- Aviso de auditoria nem sempre é defeito: investigar antes de "corrigir".
- Efeitos do Forward+ (decalques, neblina volumétrica, SSAO, SSR, sombras suaves) não aparecem nas fotos em modo compatibilidade: declarar como não verificados.
- Arquivos `.gltf` sem `.bin` e texturas, e `.sbsar`, não podem ser usados: pedir o pacote completo ou a exportação em PNG.
- Anacronismos: nada que não existisse em 1961 (o micro-ondas foi convertido e não usado).

### 6. Conteúdo de `docs/BACKLOG.md`
Crie com estas seções e itens iniciais (cada item com prioridade P0 a P3 e critério de pronto): P0 conferência visual das 14 salas e correção de tudo fora do lugar; P0 rodar a bateria completa na versão atual; P0 mapa fora de linha (casas da encosta em terraços alinhados à rua); P0 acabamento da igreja e do adro; P1 cidade menos "de caixinha" (peças modulares glTF, térreo de pedra, chaminés, varais); P1 segundo andar em mais casas; P1 ruas falsas; P1 fundos e laterais das casas; P1 puzzle das velas e do sino; P2 lore em dois níveis; P2 áudio por espaço; P2 desempenho medido pelo dono; P3 demo e exportação. Inclua as ideias futuras da seção 10 do documento.

### 7. Depois de criar tudo
Mostre a árvore de arquivos criada, rode `scripts/mapear.sh` uma vez para provar que funciona e faça um commit com a mensagem "skill bradador-dev". Não altere o jogo nesta tarefa.

## FIM DO PROMPT

---

## Como a skill funciona no dia a dia
1. Você escreve qualquer pedido curto ("melhora a igreja", "continua").
2. A skill entra sozinha (a descrição cobre qualquer assunto do BRADADOR).
3. Ela mapeia o estado, decide sem perguntar, executa em passos pequenos e verifica com fotos e testes.
4. Ela responde com três listas (verificado, visto, não verificado) e manda o zip e as fotos.
5. Ela segue com os próximos itens do backlog e deixa o `ESTADO-DO-PROJETO.md` atualizado para o próximo pedido.

## Limites honestos
- A skill não mede FPS na sua placa: isso continua dependendo de você me mandar prints.
- "Trabalhar sem especificações" não significa adivinhar arquivos que faltam: .gltf sem .bin e .sbsar ainda precisam do pacote completo.
- Verificar tudo é lento em renderização por software (cerca de 1 minuto por foto); a skill acelera com captura só das salas e metade da resolução, mas não elimina a espera.
