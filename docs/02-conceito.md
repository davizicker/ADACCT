# Conceito (rascunho v0.1): "SINAL FRACO" (título provisório)

## Pitch
Você é o locutor da madrugada de uma rádio comunitária numa cidade pequena do interior do Brasil.
Ouvintes ligam, pedem músicas, mandam recados. Aos poucos, algumas vozes ao telefone conhecem
coisas demais, e algo lá fora usa a voz de gente que você conhece para fazer você abrir a porta.

**Uma frase:** *"Atenda, converse, sobreviva até o amanhecer — e desconfie de quem sabe seu nome."*

## Pilares
1. **Áudio é o jogo.** Voz, estática e silêncio são as armas do monstro e as suas.
2. **Vulnerabilidade total.** Sem combate. Você só tem a cabine, o painel e o telefone.
3. **Folclore real, tratado com respeito e estranheza.** Entidade inspirada em lendas do interior.
4. **Noites curtas, regras que se descobrem.** Cada noite ~15–25 min.

## Loop principal (por noite)
1. **Programar a rádio:** escolher músicas/avisos (mantém a "audiência" e a entidade distraída/atraída).
2. **Atender ligações:** ouvinte real ou imitação? Perguntas de verificação (apelido, o que comeu hoje, nome do cachorro — dados que você coletou nas noites anteriores).
3. **Vigiar a cabine:** janela, porta dos fundos, luz do corredor, câmera do estacionamento (monitor granulado).
4. **Gerenciar o transmissor:** estática sobe, sinal cai; ajustar antena/frequência com ruído crescente.
5. **Sobreviver até o amanhecer:** erro = a entidade entra, ou você é atraído para fora.

## O monstro
- **"A Voz"**: entidade que aprende vozes (gravadas por você mesmo no ar).
- Só entra se você o convida (ou abre a porta). Regras ocultas por noite.
- Fica mais perigosa conforme você grava e reutiliza falas (o jogador é cúmplice).
- Aparições visuais raras, parciais, na câmera/janela. Nunca em corpo inteiro até o clímax.

## Sistemas únicos (diferenciais)
- **Imitação de voz do jogador:** o jogo grava (opcional, com consentimento) trechos do microfone e os devolve distorcidos. Alternativa sem microfone: banco de falas gravadas.
- **Livro de registro:** você anota o que cada ouvinte disse; contradições entre noites revelam a impostora.
- **Rádio ao vivo diegético:** a música que você escolhe altera a atmosfera (e as regras).

## Estética
- PS1/VHS, baixa poligonagem, granulado, 4:3 opcional. Baratíssimo de produzir, forte identidade.
- Cabine única + 2–3 cenários externos curtos (estacionamento, corredor, mato) = escopo controlado.

## Escopo MVP (vertical slice)
- 1 cabine, 1 noite completa (~15 min).
- 4 ligações roteirizadas (2 verdadeiras, 2 imitações).
- 1 comportamento da entidade (aproximação por estágios).
- Painel: rádio, telefone, livro, câmera.
- Áudio dinâmico (camadas de estática/medo).
- Final: amanhecer + revelação parcial.

## Estrutura de campanha (futuro)
- 5 noites: 1 tutorial, 3 de escalada, 1 clímax. Rejogável por finais ligados ao livro de registro.

## Riscos
- Reconhecimento de voz/ML = complexidade → começar com falas pré-gravadas.
- Escrever diálogo crível e assustador é o trabalho central; precisa de atores de voz.
- Monetização: Steam + itch.io, preço ~R$ 25–40, demo no Steam Next Fest.

## Decisões em aberto (precisamos escolher juntos)
1. **Engine/ambiente:** Godot 4 (leve, grátis, ótimo para PS1) ou Unity/Unreal?
2. **Perspectiva:** 1ª pessoa fixa na cabine vs. exploração livre.
3. **Solo ou co-op:** recomendo solo no MVP.
4. **Idioma:** PT-BR nativo + legendas em inglês desde o início.
5. **Onde mora o projeto:** este repositório (ADACCT) é uma ferramenta Python não relacionada; sugiro um repositório novo para o jogo.
