#!/usr/bin/env bash
# ==============================================================================
# meu-setup: tests/lint.sh
# Validação de sintaxe bash e análise estática via ShellCheck.
# ==============================================================================

set -euo pipefail

DIR_TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR_ROOT="$(cd "$DIR_TESTS/.." && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}▶ [1/2] Verificando sintaxe com bash -n...${NC}"

FILES=("$DIR_ROOT/install.sh")
for f in "$DIR_ROOT/bin/"* "$DIR_ROOT/lib/"*.sh; do
    [ -f "$f" ] && FILES+=("$f")
done

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        bash -n "$file"
        echo -e "  ${GREEN}✔${NC} Sintaxe OK: $(basename "$file")"
    fi
done

echo -e "\n${BLUE}▶ [2/2] Verificando análise estática com ShellCheck...${NC}"

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -x "${FILES[@]}"
    echo -e "${GREEN}✔ ShellCheck aprovado com zero erros!${NC}"
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo -e "${YELLOW}ShellCheck local não encontrado. Executando via container oficial (koalaman/shellcheck)...${NC}"
    REL_FILES=()
    for f in "${FILES[@]}"; do
        REL_FILES+=("${f#$DIR_ROOT/}")
    done
    docker run --rm -v "$DIR_ROOT:/mnt:ro" koalaman/shellcheck:stable "${REL_FILES[@]}"
    echo -e "${GREEN}✔ ShellCheck em container aprovado com zero erros!${NC}"
else
    echo -e "${YELLOW}⚠ ShellCheck não instalado (instale com: sudo apt install -y shellcheck).${NC}"
    echo -e "${GREEN}✔ Sintaxe validada com sucesso via bash -n!${NC}"
fi

echo -e "\n${GREEN}=== Linting concluído com sucesso! ===${NC}"
