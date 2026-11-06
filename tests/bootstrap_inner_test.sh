#!/usr/bin/env bash
# Instalação inicial real: não usa a instalação do host nem um clone prévio no HOME.
set -euo pipefail
for command in git python3 curl; do
    if command -v "$command" >/dev/null; then echo "Fixture inválido: $command já estava instalado." >&2; exit 1; fi
done
export MEU_SETUP_REPOSITORY=/source
# O fixture é um repositório controlado, somente leitura, pertencente ao usuário do host.
cat > "$HOME/.gitconfig" <<'GITCONFIG'
[safe]
    directory = /source
    directory = /source/.git
GITCONFIG
bash /source/bootstrap.sh --yes --user-only
source_dir="$HOME/.local/share/meu-setup"
[ -d "$source_dir/.git" ]
[ "$(readlink "$HOME/.local/bin/novo-projeto")" = "$source_dir/bin/novo-projeto" ]
"$source_dir/bin/diagnostico"
before=$(sha256sum "$HOME/.bashrc" "$HOME/.config/meu-setup/shell.bash")
bash /source/bootstrap.sh --yes --config-only --user-only
after=$(sha256sum "$HOME/.bashrc" "$HOME/.config/meu-setup/shell.bash")
[ "$before" = "$after" ]
# Executa a cadeia real do README com HTTP local servindo a mesma revisão do bootstrap.
# Assim é possível validar antes da publicação no GitHub, sem código remoto diferente.
python3 -m http.server 18887 --bind 127.0.0.1 --directory /source > /tmp/meu-setup-bootstrap-http.log 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
for _ in {1..20}; do
    if curl -fsS http://127.0.0.1:18887/bootstrap.sh >/dev/null 2>&1; then break; fi
    sleep 0.1
done
seed=""
while IFS= read -r line; do
    if [[ "$line" == 'bash -c '* ]]; then seed="$line"; break; fi
done < /source/README.md
[ -n "$seed" ]
seed="${seed/https:\/\/raw.githubusercontent.com\/jjeffersonlima\/meu-setup\/main\/bootstrap.sh/http:\/\/127.0.0.1:18887\/bootstrap.sh}"
python3 - "$seed" <<'PYMENU'
import os, sys
sys.path.insert(0, '/source/tests')
from pty_runner import run_terminal
result = run_terminal(['bash', '-c', sys.argv[1]], '3\n', env=os.environ.copy(), cwd=os.getcwd(), timeout=120)
print(result.stdout)
print(result.stderr, file=sys.stderr)
assert 'Reparar a instalação existente' in result.stdout
assert result.returncode == 0
PYMENU
"$source_dir/bin/diagnostico" --config-only
echo 'Bootstrap aprovado: pré-requisitos ausentes preparados, clone persistente, reparo repetido e comando do README executado.'
