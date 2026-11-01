#!/usr/bin/env bash
# ==============================================================================
# meu-setup: tests/run.sh
# Runner mestre da suíte de testes de qualidade do meu-setup.
# Executa linting, smoke tests e testes end-to-end em Docker.
# ==============================================================================

set -euo pipefail

DIR_TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

mostrar_ajuda() {
    echo "Uso: ./tests/run.sh [OPÇÕES]"
    echo ""
    echo "Opções:"
    echo "  --lint-only     Executa apenas a validação de sintaxe e ShellCheck"
    echo "  --smoke-only    Executa apenas os testes rápidos de CLI e módulos (~2s)"
    echo "  --fast          Executa lint + smoke (sem subir container Docker)"
    echo "  --e2e-only      Executa apenas o teste End-to-End no container Docker"
    echo "  -h, --help      Exibe esta mensagem de ajuda"
}

MODO="all"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lint-only)
            MODO="lint"
            shift
            ;;
        --smoke-only)
            MODO="smoke"
            shift
            ;;
        --fast)
            MODO="fast"
            shift
            ;;
        --e2e-only)
            MODO="e2e"
            shift
            ;;
        -h|--help)
            mostrar_ajuda
            exit 0
            ;;
        *)
            echo -e "${RED}Opção inválida: $1${NC}"
            mostrar_ajuda
            exit 1
            ;;
    esac
done

echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║       🧪 meu-setup: Suíte Automatizada de Testes & Qualidade   ║${NC}"
echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}\n"

if [ "$MODO" = "lint" ] || [ "$MODO" = "fast" ] || [ "$MODO" = "all" ]; then
    echo -e "${BOLD}▶ [CAMADA 1] Análise Estática & Linting${NC}"
    "$DIR_TESTS/lint.sh"
    echo ""
fi

if [ "$MODO" = "smoke" ] || [ "$MODO" = "fast" ] || [ "$MODO" = "all" ]; then
    echo -e "${BOLD}▶ [CAMADA 2] Smoke Tests & Validação CLI${NC}"
    "$DIR_TESTS/smoke.sh"
    echo ""
fi

if [ "$MODO" = "e2e" ] || [ "$MODO" = "all" ]; then
    echo -e "${BOLD}▶ [CAMADA 3] End-to-End (E2E) & Idempotência em Container Docker${NC}"
    "$DIR_TESTS/e2e_docker.sh"
    echo ""
fi

echo -e "${BOLD}${GREEN}✔ Todas as verificações da suíte de testes foram concluídas com sucesso!${NC}\n"
