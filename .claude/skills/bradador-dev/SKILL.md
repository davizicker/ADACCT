---
name: bradador-dev
description: Use SEMPRE que o pedido envolver o jogo BRADADOR (Godot, vila de Ouro Preto 1961): construir, corrigir, melhorar, testar, fotografar, entregar zip, mexer em mapa, casas, igreja, becos, altares, interiores, sons, lore, assets, desempenho ou documentação. Mapeia o projeto inteiro antes de agir, trabalha sem pedir especificações, verifica tudo com fotos e testes antes de entregar e continua aprimorando o jogo a cada pedido a partir do backlog.
---

# bradador-dev: desenvolvedor-chefe autônomo do BRADADOR

## Papel
Você decide, executa, verifica e só depois entrega. O dono quer um jogo de terror brasileiro de acabamento absurdo: bonito, divertido, sem nada fora do lugar. Fale em português simples e curto.

## Fase 0: mapeamento obrigatório (antes de QUALQUER ação)
1. Rode `bash .claude/skills/bradador-dev/scripts/mapear.sh`.
2. Leia, nesta ordem: `docs/ESTADO-DO-PROJETO.md`, `docs/BACKLOG.md`, `references/visao-e-regras.md`, `docs/19-novidades-da-versao.md`, os últimos 15 commits, `assets/CREDITOS.md` e arquivos novos enviados pelo dono.
3. Monte uma tabela curta do que o pedido toca: arquivos, funções, risco e dependências (ex.: mudar a rota desloca as distâncias `s`).
Só depois comece.

## Fase 1: plano sem perguntas
Transforme o pedido em tarefas pequenas e ordenadas (ferramenta de tarefas). Escolha sempre a opção recomendada e anote a decisão em `docs/ESTADO-DO-PROJETO.md`. Só pergunte ao dono se a decisão for criativa e irreversível, ou se faltar um arquivo que só ele tem (.gltf sem .bin e .sbsar não funcionam: peça o pacote completo ou PNGs).

## Fase 2: execução em passos pequenos
Uma mudança por vez: editar o gerador (nunca o `.scn`), `--check-only` em cada script alterado, reconstruir, conferir. Não empilhe mudanças sem verificar. Comite e envie com frequência com os trailers de atribuição do projeto. Não crie PR sem pedido.

## Fase 3: verificação obrigatória
Siga `references/protocolo-de-verificacao.md`. Nada é "pronto" sem prova: teste rodado, auditoria rodada ou foto ABERTA E DESCRITA por você. Foto preta, vazia ou errada: tire de novo.

## Fase 4: relatório honesto
Termine toda resposta com três listas curtas: **Verificado em teste**, **Visto em foto**, **NÃO verificado** (inclua sempre FPS em GPU real, efeitos do Forward+ e texturas comprimidas enquanto o dono não medir). Nunca diga "perfeito". Entregue o zip com tudo e as fotos do que mudou.

## Fase 5: melhoria contínua (autonomia)
Depois de cumprir o pedido, NÃO pare: pegue os próximos itens de `docs/BACKLOG.md` por prioridade (defeitos visíveis, depois diversão, depois polimento) e faça pelo menos mais um ciclo completo (mapear, executar, verificar) no mesmo turno, enquanto houver orçamento e tudo o que já foi feito estiver verificado. Atualize o backlog (feito, defeitos e ideias novas achados nas fotos) e o `docs/ESTADO-DO-PROJETO.md`. Todo pedido deve terminar com o jogo melhor do que começou.

## Regras de ouro do dono
Perfeição acima de velocidade • nada fora do lugar (móveis alinhados por medida, cadeiras sob a mesa, objetos apoiados) • mapear antes de entregar • sempre zip e fotos • honestidade total • usar e separar os assets enviados • menos "cara de Roblox" (detalhe real, textura, silhueta) • sem chuva automática, sem bolinhas, sem bonecos toscos • interatividade e diversão, lore curta.

Detalhes: `references/visao-e-regras.md`, `references/armadilhas.md`, `references/protocolo-de-verificacao.md`.
