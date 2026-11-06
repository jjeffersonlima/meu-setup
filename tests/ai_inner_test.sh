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
instalar_ferramentas_ia
first=$(cat "$SETUP_STATE_DIR/ai-tools.json")
instalar_ferramentas_ia
[ "$first" = "$(cat "$SETUP_STATE_DIR/ai-tools.json")" ]
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
# Exercita os mecanismos reais de manutenção sem iniciar agentes autenticados.
setup_ai_update codex
setup_ai_update skills
setup_ai_update opencode
# O fornecedor recusa autoatualização nativa dentro de container. Comprova
# backup anterior e a recusa, sem contornar a proteção oficial.
if setup_ai_update ai-memory > "$work/memory-update.log" 2>&1; then
    echo 'ai-memory atualizado pelo mecanismo oficial.'
else
    python3 - "$work/memory-update.log" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text()
if 'refusing to self-upgrade inside a container' not in text:
    raise SystemExit(text)
print('ai-memory: backup criado; recusa oficial de autoatualização em container confirmada.')
PY
fi
find "$SETUP_STATE_DIR/ai-backups" -name '*.tar.gz' -size +0c | python3 -c 'import sys; assert sys.stdin.read().strip()'
ai-memory backup --to "$work/backup.tar.gz"
test -s "$work/backup.tar.gz"
test -s "$HOME/.agents/skills/ai-memory-retrieval/SKILL.md"
setup_ai_state check-memory
echo 'Integração IA aprovada: instalação global, repetição, servidor, MCP/hooks/skills e backup. Login, WSL e Codex App precisam de validação real.'
