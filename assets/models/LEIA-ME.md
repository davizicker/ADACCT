# Modelos 3D (.glb) — coloque aqui

Arraste o arquivo para esta pasta no Godot (janela "Sistema de Arquivos"). Nomes que o jogo procura sozinho:

| Arquivo | Substitui | Ajustes (altura, giro, animações) |
|---|---|---|
| `bradador.glb` | o Bradador de formas simples | `scripts/modelos.gd` → `BRADADOR` |
| `mula.glb` | o corpo da Mula-sem-cabeça (o fogo e a luz continuam) | `scripts/modelos.gd` → `MULA` |

Se o arquivo não existir, o jogo usa o modelo simples. Se o modelo aparecer **de costas**, mude `yaw` (0 ou 180).
Registre a origem e a licença de cada modelo em `assets/CREDITOS.md`.
