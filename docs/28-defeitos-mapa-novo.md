# Defeitos do mapa novo (mapeamento contínuo)

Lista viva: cada defeito visto nas fotos/vídeo do mapa novo, onde está e o que foi feito. Atualizada a cada rodada.
Status: **corrigido** (no código, entra no próximo bake) · **aberto** · **visto ok**.

| # | Onde (s = metros de rua) | Defeito | Status / correção |
|---|---|---|---|
| 1 | Entrada (s 0-15), fachadas | Pedra do térreo e dos muros em blocos gigantes (textura esticada: "cara de Minecraft") | corrigido: textura do material `muro` 1,8x menor (blocos de tamanho real) |
| 2 | Calçadas da vila toda | Mato e tufos demais na beira das fachadas (3.300 tufos): parece abandono exagerado e esconde a calçada | corrigido: reduzido para ~1.000 (calçada) e 250 (rua) |
| 3 | Entrada, casa fechada à esquerda | Tábuas em X da porta fechada grossas e passando da moldura | corrigido: tábuas do tamanho do vão, mais finas |
| 4 | Entrada | Placas de loja escuras e ilegíveis de longe | aberto |
| 5 | Fim da reta da entrada | Fundo da rua escuro e liso (paredão sem detalhe) | aberto: conferir no próximo quadro |
| 6 | Casarão/escola/padaria/carpintaria (interiores) | Ainda não fotografados no mapa novo | aberto |
| 7 | Curvas do zigue-zague | Lado de fora terminava no nada | corrigido: muro de arrimo com lampiões e árvores; mureta por dentro |
| 8 | Fachadas em geral | Falta relevo (janelas simples, cunhal liso, beiral reto) | corrigido: kit 2 (guilhotina, sacada de ferro em todo sobrado, grades, porta com bandeira, cunhais, embasamento, beiral de telhas) |
| 9 | 1ª curva de 90° (s ≈ 21) | Lado de fora da curva aberto: caixotes soltos e um vazio escuro até o morro | corrigido: muro de arrimo com lampiões e árvores em TODAS as curvas (90° e 180°) |
| 10 | 1ª curva, ao fundo à esquerda | Grande placa clara e lisa (encosta/terreno iluminado pela lua, sem textura de perto) | aberto: conferir de perto |
| 11 | Vila toda (encostas, quintais, curvas, ponte) | ~16 mil matos/musgos/folhas/cogumelos/galhos, arbustos, toras e árvores postos antes do terreno ser esculpido: boiando, dentro de casas ou sobre o vazio | corrigido: passada final do bake `tools/assentar.gd` encosta tudo no chão real e remove o que caiu dentro de casa/muro/água ou sobre o vazio; auditoria `tools/auditoria_flutuantes.gd` |
| 12 | Mato enterrado mais de 80 cm | A medição começava dentro do terreno e não via o chão | corrigido: o chão é procurado vindo de cima (camada só do terreno) |
| 13 | Riacho | Plantas da margem afundadas na água | corrigido: planta sobre a água é removida |
| 14 | Bar da TV (s ≈ 148) | TV afundada 34 cm no barril | corrigido: TV no tampo do barril |
| 15 | Rua s ≈ 146-174 | 3 bancos e a carroça em posições do mapa antigo: um em cima do carro coberto, outro no bar; sem colisão | corrigido: vagas livres na calçada do outro lado, com colisão |
| 16 | Igreja | Púlpito atravessando banco, altar lateral e santo; santos 50 cm no ar | corrigido: púlpito entre o altar e o arco; peanha e trono sob os santos |
| 17 | Esconderijo do 2º carro | Posição escondida não salva: jogador ia para o começo da rua | corrigido (`@export pos_oculto`) |
| 18 | Becos-escada | Barris tapando as bocas dos becos | corrigido: bocas reservadas |
| 19 | Fachadas | Paredes lisas demais | corrigido: escorridos de chuva, trincas, limo e salitre (decalques), azulejo com número, fiação em isoladores |
