#!/usr/bin/env bash
set -euo pipefail
DIR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR_ROOT"
files=(bootstrap.sh install.sh bin/* lib/*.sh configs/shell.bash tests/*.sh)
for file in "${files[@]}"; do bash -n "$file"; done
python3 -B - <<'PY'
import ast
from pathlib import Path
for root in ('lib', 'tests', 'templates'):
    for path in Path(root).rglob('*.py'):
        ast.parse(path.read_text(), filename=str(path))
print('Sintaxe Bash e Python: aprovada.')
PY
python3 -B "$DIR_ROOT/tests/public_files.py"
checker="${SHELLCHECK_BIN:-shellcheck}"
if command -v "$checker" >/dev/null 2>&1; then
    "$checker" -x "${files[@]}"
    echo 'ShellCheck: aprovado.'
else
    echo 'NÃO EXECUTADO: ShellCheck indisponível. Instale com sudo apt install shellcheck.' >&2
    if [ "${CI:-false}" = true ] || [ "${REQUIRE_SHELLCHECK:-0}" = 1 ]; then exit 1; fi
fi
