#!/bin/bash
# Gera as plantas: planta do jogo (docs/29) e planta mestra (docs/31), com imagens em docs/planta/.
source "$(dirname "${BASH_SOURCE[0]}")/comum.sh"
gx --script res://tools/planta_jogo.gd 2>&1 | grep -E "^\[planta\] casas|SCRIPT"
python3 tools/planta_jogo.py docs/planta/planta.json docs/planta/
gx --script res://tools/planta_mestra.gd 2>&1 | grep -E "^\[planta-mestra\]|SCRIPT"
python3 tools/planta_mestra.py
