#!/bin/bash
# Roda o jogo num modo de teste: tools/ci/jogo.sh --selftest-walk   (mostra as últimas $TAIL linhas relevantes)
source "$(dirname "$0")/comum.sh"
gx -- "$@" 2>&1 | grep -E "^\[|SCRIPT|Parse|TRAVOU" | grep -v "never freed" | tail -${TAIL:-25}
