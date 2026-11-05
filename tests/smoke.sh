#!/usr/bin/env bash
# Regressões locais sem rede, privilégios ou alterações no HOME real.
set -euo pipefail
DIR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 -B "$DIR_ROOT/tests/test_setup.py"
