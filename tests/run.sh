#!/usr/bin/env bash
set -euo pipefail
DIR_TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:---all}"
case "$mode" in
    --help|-h) echo 'Uso: tests/run.sh [--fast|--lint-only|--smoke-only|--e2e-only|--all]'; exit ;;
    --fast|--lint-only|--smoke-only|--e2e-only|--all) ;;
    *) echo "Opção inválida: $mode" >&2; exit 2 ;;
esac
if [[ "$mode" == --all || "$mode" == --fast || "$mode" == --lint-only ]]; then "$DIR_TESTS/lint.sh"; fi
if [[ "$mode" == --all || "$mode" == --fast || "$mode" == --smoke-only ]]; then "$DIR_TESTS/smoke.sh"; fi
if [[ "$mode" == --all || "$mode" == --e2e-only ]]; then "$DIR_TESTS/e2e_docker.sh"; fi
echo 'Verificações executadas concluídas. Etapas indisponíveis são indicadas explicitamente acima.'
