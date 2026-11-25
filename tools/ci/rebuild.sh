#!/bin/bash
# Recria a vila do zero: texturas -> importar -> bake -> importar. Log em $SAIDA/bake.log
source "$(dirname "$0")/comum.sh"
{
gh_ --script res://tools/gen_textures.gd
gh_ --import
gx --script res://tools/bake.gd
gh_ --import
} > "$SAIDA/bake.log" 2>&1
grep -E "SCRIPT ERROR|Parse Error|\[bake\] pronto|piscam|planta-mestra|alcances|assentar" "$SAIDA/bake.log" | head -40
git checkout scenes/bradador.tscn scenes/casa.tscn scenes/jogador.tscn scenes/main.tscn scenes/mula.tscn scenes/poste.tscn 2>/dev/null
