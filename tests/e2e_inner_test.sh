#!/usr/bin/env bash
# Integração em Linux limpo. Não representa a inicialização real do WSL/systemd.
set -Eeuo pipefail
DIR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR_ROOT"
export GIT_USER_NAME='Teste de integração' GIT_USER_EMAIL=teste@local SETUP_GENERATE_SSH=false
./install.sh --yes --user-only
# shellcheck source=lib/common.sh
source "$DIR_ROOT/lib/common.sh"
setup_environment
./bin/diagnostico
before=$(sha256sum "$HOME/.bashrc" "$HOME/.config/meu-setup/shell.bash" "$HOME/.config/git/ignore")
./install.sh --yes --user-only
./install.sh --yes --user-only
after=$(sha256sum "$HOME/.bashrc" "$HOME/.config/meu-setup/shell.bash" "$HOME/.config/git/ignore")
[ "$before" = "$after" ]
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
"$DIR_ROOT/bin/novo-projeto" python teste-python
(cd teste-python && uv run main.py)
"$DIR_ROOT/bin/novo-projeto" node teste-node
(cd teste-node && pnpm check && pnpm start)
"$DIR_ROOT/bin/novo-projeto" astro teste-astro
(cd teste-astro && pnpm build)
"$DIR_ROOT/bin/novo-projeto" docker teste-docker
(cd teste-docker && docker compose config --quiet)
echo 'Integração aprovada: instalação, reexecução e execução dos templates Python, Node e Astro; Compose validado.'
