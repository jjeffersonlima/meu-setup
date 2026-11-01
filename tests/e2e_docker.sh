#!/usr/bin/env bash
# ==============================================================================
# meu-setup: tests/e2e_docker.sh
# Runner do teste End-to-End determinístico em container Docker isolado.
# ==============================================================================

set -euo pipefail

DIR_TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR_ROOT="$(cd "$DIR_TESTS/.." && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Erro: Docker não está ativo. O teste E2E necessita do Docker para isolamento seguro.${NC}"
    exit 1
fi

echo -e "${BLUE}▶ [1/2] Construindo imagem Docker isolada (Ubuntu 24.04 limpo com usuário WSL)...${NC}"
docker build -t meu-setup-test:e2e -f "$DIR_TESTS/Dockerfile.test" "$DIR_TESTS"

echo -e "\n${BLUE}▶ [2/2] Executando suíte E2E determinística dentro do container...${NC}"

# Passa GITHUB_TOKEN caso esteja presente no host para evitar rate limits
ENV_ARGS=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    ENV_ARGS+=(-e "GITHUB_TOKEN=$GITHUB_TOKEN")
fi

docker run --rm \
    "${ENV_ARGS[@]}" \
    -v "$DIR_ROOT:/home/dev/meu-setup" \
    meu-setup-test:e2e \
    /home/dev/meu-setup/tests/e2e_inner_test.sh

echo -e "${GREEN}✔ Teste End-to-End no Docker finalizado com sucesso!${NC}"
