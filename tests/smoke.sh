#!/usr/bin/env bash
# Regressões locais sem rede, privilégios ou alterações no HOME real.
set -euo pipefail
DIR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 -B -m unittest discover -s "$DIR_ROOT/tests" -p 'test_*.py' -v
