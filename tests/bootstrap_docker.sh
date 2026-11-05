#!/usr/bin/env bash
set -euo pipefail
DIR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
timeout 10 docker info >/dev/null
snapshot=$(mktemp -d)
trap 'rm -rf "$snapshot"' EXIT
python3 -B "$DIR_ROOT/tests/source_snapshot.py" "$snapshot"
# Snapshot público versionado para exercitar clone/fetch de verdade antes da publicação.
git -C "$snapshot" init -q -b main
git -C "$snapshot" add .
git -C "$snapshot" -c user.name=Teste -c user.email=teste@local commit -q -m 'Fixture público do bootstrap'
timeout 600 docker build -t meu-setup-test:bootstrap -f "$DIR_ROOT/tests/Dockerfile.bootstrap" "$DIR_ROOT/tests"
timeout 1200 docker run --rm -v "$snapshot:/source:ro" meu-setup-test:bootstrap /source/tests/bootstrap_inner_test.sh
