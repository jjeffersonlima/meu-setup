#!/usr/bin/env bash
# Instalações reais em HOME efêmero, sem login ou inferência de agentes.
set -euo pipefail
DIR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
timeout 10 docker info >/dev/null
snapshot=$(mktemp -d)
trap 'rm -rf "$snapshot"' EXIT
python3 -B "$DIR_ROOT/tests/source_snapshot.py" "$snapshot"
timeout 600 docker build -t meu-setup-test:ai -f "$DIR_ROOT/tests/Dockerfile.ai" "$DIR_ROOT/tests"
timeout 1200 docker run --rm --user "$(id -u):$(id -g)" -v "$snapshot:/source:ro" \
    meu-setup-test:ai /source/tests/ai_inner_test.sh
