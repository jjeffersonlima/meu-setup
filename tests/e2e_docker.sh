#!/usr/bin/env bash
set -euo pipefail
DIR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! timeout 10 docker info >/dev/null 2>&1; then
    echo 'NÃO EXECUTADO: integração exige acesso ao Docker.' >&2
    exit 1
fi
image="meu-setup-test:e2e"
timeout 600 docker build -t "$image" -f "$DIR_ROOT/tests/Dockerfile.test" "$DIR_ROOT/tests"
# Snapshot estável: alterações no checkout durante a execução não mudam o teste.
snapshot=$(mktemp -d)
trap 'rm -rf "$snapshot"' EXIT
tar -C "$DIR_ROOT" --exclude=.git --exclude=__pycache__ -cf - . | tar -C "$snapshot" -xf -
# Código montado somente para leitura. Configurações e pacotes ficam no container descartável.
timeout 1200 docker run --rm -v "$snapshot:/home/dev/meu-setup:ro" "$image" /home/dev/meu-setup/tests/e2e_inner_test.sh
