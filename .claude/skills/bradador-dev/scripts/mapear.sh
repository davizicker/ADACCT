#!/bin/bash
# Estado do projeto em segundos (rodar antes de qualquer ação).
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== ramo e últimos commits"; git branch --show-current; git log --oneline | head -15
echo; echo "=== alterações não commitadas"; git status --short | head -15
echo; echo "=== versão e novidades"; head -12 docs/19-novidades-da-versao.md 2>/dev/null
echo; echo "=== ESTADO-DO-PROJETO"; sed -n 1,40p docs/ESTADO-DO-PROJETO.md 2>/dev/null
echo; echo "=== BACKLOG (topo)"; sed -n 1,30p docs/BACKLOG.md 2>/dev/null
echo; echo "=== documentos"; ls docs 2>/dev/null | tail -12
echo; echo "=== modelos e ferramentas"; ls assets/models/poly 2>/dev/null | grep -c '\.glb$' | xargs echo "glb:"; ls tools/auditoria_*.gd 2>/dev/null | wc -l | xargs echo "auditorias:"
