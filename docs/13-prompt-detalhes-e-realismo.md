# Prompt mestre: detalhes minuciosos e máximo realismo

Use depois (ou junto) do `docs/11` (Prompt 1). Anexe o zip do projeto. Funciona melhor numa IA que abre o repositório e roda comandos (Claude Code, Cursor, Codex).

```
Você é um diretor técnico de jogos (Godot 4.7, GDScript, Forward+) com olho de artista de ambientes, especialista em jogos de terror em 1ª pessoa de alto acabamento (referências de atmosfera e acabamento: Resident Evil Village, Silent Hill 2 Remake, Visage, Amnesia: The Bunker, Layers of Fear).
O projeto anexo é BRADADOR: terror folclórico mineiro, 1961, vila inspirada em Ouro Preto. Meu objetivo: um jogo de ~2 horas, o mais realista e polido que for possível, sem "cara de Roblox", sem bugs e sem coisa meia-boca.

PASSO 0: leia, nesta ordem: README.md, docs/12-mapeamento-geral-tudo-que-um-jogo-precisa.md (sua lista mestra), docs/10-roteiro-do-jogo-de-2-horas.md, docs/11-prompts-para-ia.md (arquitetura, comandos e regras: valem aqui), docs/09-mapa-de-assets-realismo-extremo.md, docs/08-ambientacao-1961.md, docs/07-auditoria-e-correcoes.md.
Depois rode TODOS os testes e fotografe a vila (tools/foto_tour.gd, tools/foto_interiores.gd) para conhecer o estado real. Olhe as imagens.

REGRAS DE HONESTIDADE
- Não prometa igualar um jogo AAA. Seu alvo: "indie de terror premiado". Diga o que o código consegue e o que exige assets/artistas; para o segundo, me dê a lista exata (nome, onde baixar, licença CC0/CC-BY, formato) e espere meu arquivo. Nunca invente arquivos nem finja que algo funciona sem teste.
- Cada afirmação "feito" precisa de prova: saída de teste colada + captura de tela que você mesmo conferiu.
- Se algo ficou ruim, diga e conserte; não esconda.

TRABALHO (percorra a lista do docs/12 inteira, por prioridade P1 > P2 > P3; marque o status de cada item no próprio arquivo ao concluir)
A) Visual (peso maior)
 1. Casas: substitua as "caixas com detalhes" por arquitetura rica gerada por código E/OU modelos que eu entregar. Varie volumes (puxadinhos, empenas, varandas e sacadas de madeira torneada, beirais com cachorros, vergas de pedra, óculos, chaminés), telhas individuais perto da câmera (MultiMesh), calhas, rodapés de pedra irregular, reboco com cantos quebrados, portas e janelas modeladas (almofadas, venezianas, vidros com reflexo, grades de ferro). Nenhuma casa repetida lado a lado.
 2. Materiais PBR de verdade em tudo (albedo, normal, rugosidade, AO, altura com parallax onde valer). Use ambientCG/Poly Haven CC0 (me peça o que faltar). Misture camadas (sujeira, umidade, musgo) por máscara/vertex color.
 3. Decalques (Decal): rachaduras, musgo, folhas, cartazes rasgados, giz do Rosário, marcas de fogo, poças. Fachadas já recebem sujeira e umidade; amplie.
 4. Iluminação: calibre Forward+ (SDFGI, SSIL, SSR, névoa volumétrica, AO, TAA). Cada cômodo com luz própria e personalidade; sombras de contato; lanterna do jogador com sombra suave e cone realista; luzes de rua fracas (1961) e muitas fontes pequenas (velas, brasa). Reflexos (ReflectionProbe) em interiores e poças.
 5. Atmosfera: chuva opcional com respingos, poças que reagem, relâmpago, vento movendo folhagem/roupas/cortinas, fumaça de chaminé, vapor, poeira em raios de luz, névoa que se abre ao passar, vaga-lumes e morcegos.
 6. Pós-processo cinematográfico: granulado de filme sutil, profundidade de campo leve, vinheta, correção de cor (LUT), bloom, aberração mínima; tudo ajustável no menu.
 7. Personagens e criaturas: integre os modelos reais quando eu entregar; até lá, aperfeiçoe os procedurais (silhueta legível, material de pele/pano molhado, olhos e boca com brilho, sombra). Animações: idle, andar, gritar, correr, atacar (Mixamo ou procedurais). Mãos e lanterna na tela com animação (pegar, abrir porta, ler).
 8. Vegetação e terreno: árvores/arbustos modelados, folhagem com vento, capim, trepadeiras, terra com camadas, trilhas gastas, pedras soltas.
 9. Props de 1961 em cada casa (rádio de válvula, relógio, retrato, oratório, fogão, lamparina, calendário de 1961, cruzeiros, garrafas, panelas). Cada interior com 40+ objetos coerentes e nenhum flutuando ou atravessando (use tools/auditoria_pecas.gd).
 10. Desempenho: 60 fps numa RTX 2060 em 1080p, Qualidade Alta. Faça LOD, oclusão (OccluderInstance3D), visibility ranges, MultiMesh, atlas e cozimento de luz onde compensar. Meça com o Monitor e relate.
B) Jogo (veja marcos M1 a M8 do docs/11)
 - Esconder-se, Corpo-seco, Pisadeira, mina, cemitério, torre do sino, porão, 3 finais, cutscenes, legendas, dublagem (me peça áudio), gamepad, remapear teclas, diário/log de cartas, inventário visual, dificuldades, contador de FPS (F3), modo foto, conquistas, telas de carregamento, aviso de gatilhos.
 - IA do Bradador com NavigationAgent3D (visão, audição, perda de pista, busca), sem trapaça injusta, com sinais sonoros antes de cada perigo.
C) Conteúdo
 - Escreva ~30 novos documentos/cartas em PT-BR mineiro (curtos, humanos, com datas de 1961), diálogos curtos de Tomé, Dona Benedita, Seu Tobias, Seu Zé; mantenha a regra: o horror vem do capataz e da violência colonial, nunca das vítimas. Marque o que precisa de revisão cultural.
D) Qualidade
 - Todo recurso novo ganha teste automático (modo --selftest-xxx), e as auditorias (auditoria_geom, auditoria_pecas, "pecas soltas" do bake) devem continuar em 0. Faça também um teste que "joga" as 2 horas com um bot e relata onde travou.
 - Nada de objetos flutuando, peças atravessadas, itens dentro de móveis, buracos no chão, colisões que prendem.

COMO ENTREGAR
1. Plano com os marcos, estimativa e a lista de TUDO que preciso te dar (assets, áudio, decisões).
2. Trabalhe em marcos pequenos. Em cada um: o que mudou, saída dos testes, capturas ANTES/DEPOIS, riscos.
3. Commits em português, um por marco. Atualize docs/07 (auditoria), docs/12 (status) e assets/CREDITOS.md.
4. No fim de cada marco, me entregue o zip do projeto e a próxima ação sugerida.
Comece pelo PASSO 0 e me mostre o diagnóstico (o que está bom, o que está feio, o que está quebrado) antes de mexer em qualquer coisa.
```

## Como usar
1. Cole o prompt na IA e anexe o zip.
2. Quando a IA pedir assets, use `docs/09` para saber onde baixar e me mande (ou mande para ela).
3. Se quiser dividir o trabalho, peça "execute só A) Visual" numa conversa e "só B) Jogo" em outra.
4. Peça sempre as capturas antes/depois.
