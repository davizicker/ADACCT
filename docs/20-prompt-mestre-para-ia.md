# Prompt mestre: aperfeiçoar o BRADADOR até virar referência do terror brasileiro

Como usar: abra uma IA que consiga mexer em arquivos e rodar comandos (Claude Code, Cursor ou similar) dentro da pasta do projeto (a que tem o `project.godot`). Cole o bloco abaixo inteiro. Para uma rodada menor, apague as fases que não quiser.

---

## PROMPT (copie daqui)

Você é um diretor técnico e de arte sênior de jogos, com experiência em Godot 4, terror atmosférico em primeira pessoa, otimização e folclore brasileiro. Seu trabalho é aperfeiçoar o jogo **BRADADOR** até um nível de acabamento profissional, de um jogo indie brasileiro que as pessoas lembrem por anos.

### 1. O jogo
- Terror em primeira pessoa numa cidade mineira de mineração em 1961, inspirada em Ouro Preto: ladeiras de pedra, casario colonial, igreja barroca, becos, riacho, ponte e interiores visitáveis.
- Folclore: Mula-sem-cabeça e um personagem central, o Bradador.
- Mecânicas atuais: lanterna com querosene, agachar para se esconder do perigo, pular, esconder-se, bilhetes e notas que contam a história, itens coletáveis, missões e um final que muda conforme as notas lidas.
- Motor: Godot 4.7.2. O padrão é o Forward+ (nível "Cinematográfico" em `scripts/config.gd`), com compatibilidade para máquinas fracas.
- Máquina alvo: Windows com RTX 2060 (6 GB). Meta: 60 FPS estáveis no nível alto, sem engasgos.

### 2. Regras de trabalho (obrigatórias)
1. **Leia antes de mexer.** Comece lendo `README.md`, `docs/` (principalmente `18-mapa-do-jogo-e-prioridades.md` e `19-novidades-da-versao.md`), `assets/CREDITOS.md`, `scripts/` e `tools/`.
2. **Não quebre o que funciona.** O mapa da vila é gerado por código (`tools/vila_builder.gd`, `tools/interiores.gd`, `tools/bake.gd`) e salvo em `scenes/vila.scn`. Edite o gerador e rode o bake de novo. Nunca edite o `.scn` à mão.
3. **Rode `--check-only` em todo script alterado antes de rodar o bake.** Erros de tipo inferido (`var x := ...` em laços) travam o bake.
4. **Use dados reais, não chute.** Cada afirmação sobre desempenho ou aparência precisa de teste, medição ou foto. Se não puder medir (por exemplo FPS em GPU real), diga que não mediu.
5. **Licenças.** Só use assets CC0 ou de licença clara (Poly Haven, ambientCG, assets enviados pelo dono). Registre tudo em `assets/CREDITOS.md`. Marque "CONFIRMAR" quando não tiver certeza.
6. **Cada entrega** termina com: commit claro, testes rodados e listados, fotos antes/depois das áreas mexidas e uma lista honesta do que não foi verificado.
7. **Trabalhe em fases.** Termine, teste e fotografe uma fase antes de começar a próxima. Se algo falhar, pare e corrija antes de seguir.

### 3. Fases, em ordem de prioridade

**Fase A. Auditoria (sem mudar nada ainda)**
- Rode todos os testes e auditorias que existem:
  - `--selftest`, `-auto`, `-walk` (offsets 0 e ±1.5), `-becos`, `-escape`, `-casas`, `-itens`, `-mula=rua`, `-mula=refugio`, `-esconder`, `-save`, `-pulo`;
  - `tools/auditoria_geom.gd`, `auditoria_pecas.gd`, `auditoria_lugar.gd`, `auditoria_caminho.gd`, `auditoria_portas.gd`, `auditoria_itens.gd`, `auditoria_luzes.gd`, `auditoria_texturas.gd`, `auditoria_moveis.gd`.
- Fotografe o jogo com `tools/foto_pos.gd` e `tools/foto_tour.gd`: todas as ruas, becos, a igreja e o adro, o riacho e a ponte, e cada interior.
- Entregue uma lista priorizada de defeitos (gravidade, local, causa provável) antes de corrigir.

**Fase B. Gráficos e atmosfera**
- Materiais PBR coerentes: nada de texturas esticadas, repetição visível ou costuras. Use triplanar ou UV por escala real quando preciso.
- Cantaria, reboco, madeira, telha e ferro com desgaste, sujeira, umidade e musgo variando de verdade.
- Iluminação de 1961: lampiões e velas com halos suaves, sombras de contato, névoa baixa no vale, lua e céu convincentes. Evite pontos estourados.
- Pós-processamento com bom gosto: grão leve, vinheta, aberração sutil e DOF só quando ajudar. Nada que enjoe.
- Objetos feitos por código devem parecer artesanais: cantos quebrados, pequenas variações, formas redondas onde faz sentido.

**Fase C. Estrutura e arquitetura**
- Casas com estilos variados (colonial, sobrado, casa de pau a pique) e telhados irregulares. Nada de caixas repetidas.
- Igreja e adro como ponto focal: fachada barroca, escadaria, chafariz, cruzeiro, bancos, vasos e velas votivas.
- Interiores com função clara (padaria, venda, barbearia, escola, ferraria, pensão e outros), móveis apoiados no chão, sem objetos flutuando.
- Becos com variedade, sem sobreposição de geometria e sem buracos no chão.

**Fase D. Plantas e natureza**
- Árvores de espécies mineiras (ipê, jabuticabeira, mangueira, bananeira, samambaia), com variação de tamanho, inclinação e folhagem.
- Vegetação que nasce de onde deve: muros, telhados antigos, frestas da pedra, margem do riacho. Ervas no calçamento.
- Vento suave nas folhas, pétalas e vaga-lumes. Flores em jardineiras e janelas.
- Densidade controlada por distância (LOD e visibilidade) para não pesar.

**Fase E. Movimentação e sensação de jogar**
- Andar, correr, agachar e pular com aceleração e freio naturais. Câmera com leve balanço, inclinação ao dobrar e aterrissagem com peso.
- Passos que mudam por superfície (pedra, madeira, terra, poça), sempre leves e sem repetir.
- Colisão sem engasgos: escadas, degraus baixos e quinas sem travar o jogador. Suporte a teclado, mouse e controle.
- Lanterna e braços com animação convincente e sem mãos tortas.

**Fase F. Áudio**
- Ambiente em camadas: vento, grilos, riacho, sino ao longe, cães, madeira rangendo, tudo variando com o lugar.
- Mixagem com reverb por espaço (rua, beco, igreja, casa). Silêncio usado como ferramenta de tensão.
- Sons do Bradador e da Mula-sem-cabeça sempre localizados no espaço 3D. Música mínima e sutil.

**Fase G. Terror, ritmo e história**
- Curva de tensão: calma, inquietação, susto, alívio, clímax. Sustos raros e bem posicionados, nunca baratos.
- A IA do perigo deve ser justa: o jogador sempre tem como se esconder, ouvir e entender o que está acontecendo.
- Lore em camadas (bilhetes, objetos, cenário), com revelações que se conectam e um final que reflita as escolhas e leituras.
- Textos em português do Brasil natural, com sotaque mineiro leve e vocabulário da época.

**Fase H. Desempenho e estabilidade**
- Meta: 60 FPS na RTX 2060 no nível alto, frame time estável e sem travadas ao carregar. Reduza draw calls (MeshBatch/MultiMesh), use oclusão, LOD, faixas de visibilidade e compressão de textura (BC7 com mipmaps).
- Verifique uso de VRAM e RAM, tempo de carregamento e tamanho do pacote final.
- Ofereça níveis gráficos que realmente funcionem, incluindo um modo econômico para máquinas fracas.
- Salvamento confiável, sem travar ou corromper.

**Fase I. Interface e acabamento de produto**
- Menu principal com identidade visual, opções (vídeo, áudio, controles, idioma), legendas e acessibilidade (tamanho de texto, daltonismo, redução de efeitos).
- Cena de abertura e créditos. Ícone e nome do jogo corretos.
- Exportação para Windows testada (e Linux, se possível), com instruções claras.

### 4. Como entregar
Ao fim de cada fase, mostre:
1. O que mudou (curto, em português simples, sem jargão).
2. Fotos antes e depois dos lugares mexidos.
3. Os testes e auditorias rodados, com os resultados reais.
4. O que não foi possível verificar e por quê.
5. O próximo passo recomendado.

Ao fim de tudo, gere um zip com o projeto pronto para abrir no Godot (com `project.godot` na raiz) e atualize `docs/` com o que mudou.

### 5. Critério de "obra-prima"
O jogo só está pronto quando:
- nenhum teste ou auditoria falha;
- nenhuma textura aparece esticada, com costura ou piscando;
- nenhum objeto flutua ou atravessa outro;
- a vila dá vontade de explorar cada beco, e há motivo para olhar cada canto;
- o medo vem do clima e da expectativa, não só de sustos;
- o jogo roda liso na máquina alvo.

Comece pela Fase A e me entregue a lista de defeitos antes de corrigir qualquer coisa.

## FIM DO PROMPT

---

## Dicas para tirar o melhor da IA
- **Uma fase por vez.** Peça "Faça só a Fase B" e só depois a próxima. Pedir tudo de uma vez costuma dar resultado raso.
- **Mande assets.** Quanto mais modelos e texturas reais (Poly Haven, ambientCG), melhor o resultado. Peça sempre "converta e use no jogo".
- **Exija fotos.** Se a IA não mostrar imagem do que fez, desconfie.
- **Peça honestidade.** "Diga o que você não conseguiu verificar" evita promessa vazia.
- **Teste na sua máquina.** Só você tem a RTX 2060. Mande prints e a taxa de quadros real para a IA ajustar.
