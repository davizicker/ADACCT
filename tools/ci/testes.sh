#!/bin/bash
# Bateria completa: auditorias + todos os autotestes do jogo. Resumo no fim; log em $SAIDA/testes.log
source "$(dirname "$0")/comum.sh"
L="$SAIDA/testes.log"; : > "$L"
J="$(dirname "$0")/jogo.sh"
run() { echo "=== $*" >> "$L"; bash "$J" "$@" >> "$L" 2>&1; }
gx --script res://tools/auditoria_casas.gd 2>&1 | grep -E "^\[casas-aud|SCRIPT" >> "$L"
gx --script res://tools/auditoria_rua.gd 2>&1 | grep -E "^\[rua-resumo|SCRIPT" >> "$L"
gx --script res://tools/planta_mestra.gd 2>&1 | grep -E "^\[planta-mestra\] \{|SCRIPT" >> "$L"
TAIL=40 run --selftest-walk --walk-offset=1.5
TAIL=5 run --selftest-walk
TAIL=5 run --selftest-walk --walk-offset=-1.5
TAIL=40 run --selftest-becos
TAIL=6 run --selftest-escape
TAIL=25 run --selftest-casas
TAIL=8 run --selftest-itens
TAIL=6 run --selftest-mula=rua
TAIL=6 run --selftest-mula=refugio
TAIL=12 run --selftest-esconder
TAIL=6 run --selftest-save
TAIL=15 run --selftest-errante
grep -E "casas-aud|rua-resumo|planta-mestra|WIN|TIMEOUT|testados|RESULTADO|escape\]|mula-teste\] fim|save\]|SCRIPT|TRAVOU|FALHOU" "$L" | cut -c1-200
echo TESTES_FIM
