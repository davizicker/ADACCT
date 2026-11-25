#!/bin/bash
# Configuração comum dos scripts de build e teste. GODOT = binário do Godot 4.7.2 (padrão: o baixado na pasta de rascunho).
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
GODOT=${GODOT:-/tmp/claude-0/-home-user-ADACCT/2069ff54-70fc-54f6-bd84-6b9c6be53006/scratchpad/godot47/Godot_v4.7.2-stable_linux.x86_64}
SAIDA=${SAIDA:-/tmp/claude-0/-home-user-ADACCT/2069ff54-70fc-54f6-bd84-6b9c6be53006/scratchpad}
mkdir -p "$SAIDA"
# Godot com renderizador de verdade (Compatibility) numa tela virtual
gx() { timeout ${TEMPO:-1800} xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy "$@"; }
gh_() { timeout ${TEMPO:-1800} "$GODOT" --headless --path . "$@"; }
