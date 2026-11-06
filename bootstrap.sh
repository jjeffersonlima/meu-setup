#!/usr/bin/env bash
# Entrada independente para preparar uma instalação sem clone manual.
set -Eeuo pipefail

bootstrap_error() { printf 'Erro: %s\n' "$*" >&2; }
bootstrap_help() {
    cat <<'HELP'
Uso: bootstrap.sh [--dir CAMINHO] [opções do install.sh]
Prepara os pré-requisitos, obtém o código e instala/repara o ambiente.
  --dir CAMINHO  Escolhe onde manter o código (padrão: instalação anterior ou ~/.local/share/meu-setup)
  --help         Mostra esta ajuda sem alterar o sistema
Sem opções, abre o mesmo menu do install.sh. Use --yes somente para automação.
O código permanece na pasta de instalação para manter os atalhos e as atualizações.
HELP
}
bootstrap_authenticate() {
    [ "$EUID" -ne 0 ] || return 0
    command -v sudo >/dev/null || { bootstrap_error 'Use uma conta Linux com acesso ao sudo.'; return 1; }
    if sudo -n -v 2>/dev/null; then return 0; fi
    if ( : </dev/tty ) 2>/dev/null; then
        echo 'Digite sua senha do Linux quando solicitado para preparar o ambiente.'
        sudo -v
    else
        bootstrap_error 'É necessário autenticar o sudo. Execute o comando no terminal do WSL ou rode sudo -v antes.'
        return 1
    fi
}
bootstrap_admin() {
    if [ "$EUID" -eq 0 ]; then "$@"; else sudo -n "$@"; fi
}
bootstrap_normalize_repository() {
    local value="${1%/}"
    value="${value%.git}"
    value="${value/#git@github.com:/https://github.com/}"
    printf '%s\n' "$value"
}
bootstrap_validate_tree() {
    local directory="$1" file
    for file in install.sh lib/common.sh lib/config.py configs/versions.env; do
        [ -f "$directory/$file" ] || { bootstrap_error "Código incompleto: falta $file em $directory."; return 1; }
    done
    bash -n "$directory/install.sh"
}
bootstrap_main() {
    local user_home="${SETUP_HOME:-$HOME}" directory="${MEU_SETUP_DIR:-}"
    local repository="${MEU_SETUP_REPOSITORY:-https://github.com/jjeffersonlima/meu-setup.git}"
    local current_origin recorded
    local -a installer_args=() packages=()
    while (($#)); do
        case "$1" in
            -h|--help) bootstrap_help; return 0 ;;
            --dir)
                if [ "$#" -lt 2 ] || [ -z "$2" ] || [[ "$2" == -* ]]; then bootstrap_error 'Informe o caminho após --dir.'; return 2; fi
                directory="$2"; shift 2 ;;
            --) shift; installer_args+=("$@"); break ;;
            *) installer_args+=("$1"); shift ;;
        esac
    done
    if [ "$(uname -s)" != Linux ] || ! command -v apt-get >/dev/null; then
        bootstrap_error 'Execute dentro do Ubuntu/WSL ou de uma distribuição Linux com APT.'; return 1
    fi
    # Dependências desta entrada; o restante é preparado pelo instalador principal.
    command -v git >/dev/null || packages+=(git)
    command -v curl >/dev/null || packages+=(curl)
    command -v python3 >/dev/null || packages+=(python3)
    command -v flock >/dev/null || packages+=(util-linux)
    [ -s /etc/ssl/certs/ca-certificates.crt ] || packages+=(ca-certificates)
    if ((${#packages[@]})); then
        bootstrap_authenticate
        bootstrap_admin env DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=2 -o Acquire::http::Timeout=30 update
        bootstrap_admin env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
    fi
    local state_dir="${SETUP_STATE_DIR:-$user_home/.local/state/meu-setup}"
    mkdir -p "$state_dir"
    chmod 700 "$state_dir"
    local bootstrap_lock install_lock
    exec {bootstrap_lock}>"$state_dir/bootstrap.lock"
    flock -n "$bootstrap_lock" || { bootstrap_error 'Outra instalação pelo comando único está em andamento.'; return 1; }
    exec {install_lock}>"$state_dir/install.lock"
    flock -n "$install_lock" || { bootstrap_error 'Outro instalador/atualizador está em andamento.'; return 1; }
    if [ -z "$directory" ] && [ -f "$state_dir/state.json" ]; then
        recorded=$(python3 - "$state_dir/state.json" <<'PY'
import json, sys
try:
    value = json.load(open(sys.argv[1])).get('repository', '')
    if not isinstance(value, str):
        raise ValueError('caminho inválido')
    print(value)
except (OSError, ValueError, AttributeError):
    raise SystemExit('Registro da instalação inválido. Revise state.json antes de continuar.')
PY
        )
        if [ -n "$recorded" ] && [ -d "$recorded" ]; then directory="$recorded"; fi
    fi
    # Reaproveita também clones anteriores à existência do registro de instalação.
    if [ -z "$directory" ] && [ -d "$user_home/projetos/meu-setup/.git" ]; then directory="$user_home/projetos/meu-setup"; fi
    directory=$(readlink -m -- "${directory:-$user_home/.local/share/meu-setup}")
    export GIT_TERMINAL_PROMPT=0
    if [ -e "$directory" ] || [ -L "$directory" ]; then
        if [ ! -d "$directory" ] || [ "$(git -C "$directory" rev-parse --show-toplevel 2>/dev/null)" != "$directory" ]; then
            bootstrap_error "O destino $directory não é um clone do projeto. Nenhum arquivo foi substituído."; return 1;
        fi
        current_origin=$(git -C "$directory" remote get-url origin)
        [ "$(bootstrap_normalize_repository "$current_origin")" = "$(bootstrap_normalize_repository "$repository")" ] || {
            bootstrap_error 'O destino pertence a outro repositório. Escolha outro caminho com --dir.'; return 1;
        }
        # Reparo reaproveita o código local, inclusive personalizações. Atualização
        # do clone é uma escolha separada, documentada pelo comando atualizar.
        bootstrap_validate_tree "$directory"
    else
        mkdir -p "$(dirname "$directory")"
        BOOTSTRAP_STAGE=$(mktemp -d "$(dirname "$directory")/.meu-setup-download.XXXXXX")
        timeout 180 git clone --depth 1 --branch main -- "$repository" "$BOOTSTRAP_STAGE"
        bootstrap_validate_tree "$BOOTSTRAP_STAGE"
        mv -T --no-clobber "$BOOTSTRAP_STAGE" "$directory"
        [ ! -d "$BOOTSTRAP_STAGE" ] || { bootstrap_error 'O destino apareceu durante o download; arquivos existentes preservados.'; return 1; }
        BOOTSTRAP_STAGE=""
    fi
    echo "Código do meu-setup disponível em: $directory"
    flock -u "$install_lock"
    exec {install_lock}>&-
    # O pai mantém o lock do bootstrap; os processos do instalador não o herdam.
    (
        exec {bootstrap_lock}>&-
        bash "$directory/install.sh" "${installer_args[@]}"
    )
}
BOOTSTRAP_STAGE=""
bootstrap_cleanup() {
    local status=$?
    trap - EXIT
    if [ -n "$BOOTSTRAP_STAGE" ]; then rm -rf -- "$BOOTSTRAP_STAGE"; fi
    exit "$status"
}
trap bootstrap_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
bootstrap_main "$@"
