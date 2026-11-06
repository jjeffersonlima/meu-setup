#!/usr/bin/env bash
set -Eeuo pipefail
DIR_SETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work=$(mktemp -d)
server_pid=""
trap 'if [ -n "$server_pid" ]; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work"' EXIT
# HOME só é alterado neste processo de teste, dentro do container.
export HOME="$work/home" SETUP_HOME="$work/home" SETUP_STATE_DIR="$work/state"
mkdir -p "$HOME"
export SETUP_COMPONENTS=codex,claude,opencode,antigravity,skills,ai-memory
# shellcheck source=lib/common.sh
source "$DIR_SETUP/lib/common.sh"
# shellcheck source=lib/log.sh
source "$DIR_SETUP/lib/log.sh"
# shellcheck source=configs/versions.env
source "$DIR_SETUP/configs/versions.env"
# shellcheck source=lib/ai.sh
source "$DIR_SETUP/lib/ai.sh"
setup_environment
umask 077
# Migração real do launcher anterior, com node/npm indisponíveis neste passo.
mkdir -p "$DIR_LOCAL_BIN" "$HOME/.codex" "$work/no-node" "$HOME/.local/share/meu-setup/npm/bin"
# Variáveis devem ser expandidas apenas quando o launcher for executado.
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/bash' '# meu-setup: CLI npm de IA' 'exec node "$HOME/.local/share/meu-setup/npm/bin/codex" "$@"' > "$DIR_LOCAL_BIN/codex"
chmod +x "$DIR_LOCAL_BIN/codex"
printf '%s\n' 'old package preserved' > "$HOME/.local/share/meu-setup/npm/bin/codex"
printf '%s\n' 'model_reasoning_effort = "medium"' > "$HOME/.codex/config.toml"
for runtime in node npm; do
    # shellcheck disable=SC2016
    printf '%s\n' '#!/bin/sh' 'touch "$HOME/unexpected-runtime-call"; exit 99' > "$work/no-node/$runtime"
    chmod +x "$work/no-node/$runtime"
done
PATH="$work/no-node:$PATH" setup_ai_install codex
test ! -e "$HOME/unexpected-runtime-call"
python3 - <<'PY'
import os
from pathlib import Path
home = Path(os.environ['HOME'])
assert (home/'.codex/config.toml').read_text() == 'model_reasoning_effort = "medium"\n'
with (home/'.local/bin/codex').open('rb') as binary:
    assert binary.read(4) == b'\x7fELF'
assert (home/'.local/share/meu-setup/npm/bin/codex').read_text() == 'old package preserved\n'
PY
# Executa o instalador real do Claude com terminal controlador, como no WSL.
python3 -B - "$DIR_SETUP" <<'PYTTY'
import os, sys
sys.path.insert(0, sys.argv[1] + '/tests')
from pty_runner import run_terminal
script = '''set -euo pipefail
DIR_SETUP="$1"
source "$DIR_SETUP/lib/common.sh"
source "$DIR_SETUP/lib/log.sh"
source "$DIR_SETUP/lib/ai.sh"
setup_environment
setup_ai_install claude
'''
result = run_terminal(['bash', '-c', script, 'claude-tty-test', sys.argv[1]], '',
                      env=os.environ.copy(), cwd=os.getcwd(), timeout=660)
print(result.stdout)
print(result.stderr, file=sys.stderr)
assert result.returncode == 0, 'Instalador Claude falhou ou perdeu o terminal controlador'
PYTTY
instalar_ferramentas_ia
first=$(readlink -f "$(command -v codex)")
instalar_ferramentas_ia
[ "$first" = "$(readlink -f "$(command -v codex)")" ]
cd /tmp
for command in codex claude opencode agy skills ai-memory; do setup_native "$command"; done
setup_ai_state prepare-memory
test -s "$HOME/.local/share/ai-memory/auth-tokens/default"
# Container não simula systemd. Exercita servidor e integração oficiais em primeiro plano.
ai-memory serve --transport http > "$work/server.log" 2>&1 &
server_pid=$!
ready=false
for _ in {1..60}; do
    if curl -fsS http://127.0.0.1:49374/healthz >/dev/null 2>&1; then ready=true; break; fi
    sleep 1
done
[ "$ready" = true ]
mkdir -p "$HOME/.claude" "$HOME/.omp"
printf '%s\n' '{"env":{"MEU_SETUP_FIXTURE":"preserved"}}' > "$HOME/.claude/settings.json"
printf '%s\n' 'existing OMP data' > "$HOME/.omp/fixture"
ai-memory setup --yes --no-service --agent codex --agent claude-code --agent opencode --agent antigravity-cli
python3 - <<'PY'
import json, os
from pathlib import Path
home = Path(os.environ['HOME'])
assert json.loads((home/'.claude/settings.json').read_text())['env']['MEU_SETUP_FIXTURE'] == 'preserved'
assert (home/'.omp/fixture').read_text() == 'existing OMP data\n'
PY
ai-memory status
ai-memory write-page --workspace integration --project fixture-a --path concepts/fixture.md --body 'mcp-preservation-fixture: backups preserve existing project data.'
ai-memory write-page --workspace integration --project fixture-b --path concepts/other.md --body 'Isolated project without the first project knowledge.'
ai-memory embed --workspace integration --project fixture-a
test -s "$HOME/.local/share/ai-memory/models/all-MiniLM-L6-v2/model.safetensors"
python3 -B "$DIR_SETUP/tests/ai_mcp_check.py"
# O guia apenas imprime instruções, inclusive com as opções antigas.
"$DIR_SETUP/bin/atualizar" --yes --system --clean-docker > "$work/update-guide.txt"
[ ! -d "$SETUP_STATE_DIR/ai-backups" ]
# Codex é o executável standalone oficial, sem launcher npm.
[ -L "$HOME/.local/bin/codex" ]
test ! -e "$HOME/unexpected-runtime-call"
ai-memory backup --to "$work/backup.tar.gz"
test -s "$work/backup.tar.gz"
test -s "$HOME/.agents/skills/ai-memory-retrieval/SKILL.md"
setup_ai_state check-memory
echo 'Integração IA aprovada: instalação global, repetição, servidor, MCP/hooks/skills e backup. Login, WSL e Codex App precisam de validação real.'
