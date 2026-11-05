#!/usr/bin/env bash
# Rotinas compartilhadas. Carregar este arquivo não altera o sistema.
SETUP_USER_HOME="${SETUP_HOME:-$HOME}"
SETUP_STATE_DIR="${SETUP_STATE_DIR:-$SETUP_USER_HOME/.local/state/meu-setup}"
DIR_LOCAL_BIN="$SETUP_USER_HOME/.local/bin"

setup_python() { python3 -B "$DIR_SETUP/lib/config.py" "$@"; }
setup_admin() {
    if [ "$EUID" -eq 0 ]; then "$@"; elif [ "${SETUP_NON_INTERACTIVE:-false}" = true ]; then sudo -n "$@"; else sudo "$@"; fi
}
setup_native() {
    local path
    path=$(command -v "$1") || return 1
    path=$(readlink -f "$path") || return 1
    [[ "$path" == /* && "$path" != /mnt/* && "$path" != *.exe ]] || return 1
    timeout 10 "$path" "${2:---version}" >/dev/null 2>&1
}
setup_environment() {
    export FNM_DIR="$SETUP_USER_HOME/.local/share/fnm"
    export PATH="$DIR_LOCAL_BIN:$SETUP_USER_HOME/.local/share/fnm:$PATH"
    # Reaproveita o Node padrão sem executar hooks interativos ou trocar versões.
    local node_bin="$SETUP_USER_HOME/.local/share/fnm/aliases/default/bin"
    if [ -x "$node_bin/node" ]; then export PATH="$node_bin:$PATH"; fi
}
setup_download() {
    curl --fail --location --show-error --silent --connect-timeout 10 \
        --max-time 180 --retry 2 --retry-max-time 240 "$1" -o "$2"
}
setup_selected() { [[ ",${SETUP_COMPONENTS:-}," == *",$1,"* ]]; }
setup_backup() { setup_python backup "$1"; }
setup_lock() {
    mkdir -p "$SETUP_STATE_DIR" || return
    chmod 700 "$SETUP_STATE_DIR" || return
    exec {SETUP_LOCK_FD}>"$SETUP_STATE_DIR/install.lock" || return
    flock -n "$SETUP_LOCK_FD" || { echo 'Outra instalação/atualização está em andamento.' >&2; return 1; }
}

# O atualizador avança apenas versões anteriores à referência; nunca faz downgrade.
setup_reuse_tool() {
    setup_native "$1" || return 1
    [ "${SETUP_UPDATE_TO_REFERENCE:-false}" = true ] || return 0
    local installed
    installed=$("$1" --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    [ -n "$installed" ] && dpkg --compare-versions "$installed" ge "$2"
}

setup_node_compatible() {
    local version
    version=$(node --version) || return 1
    dpkg --compare-versions "${version#v}" ge "${NODE_MIN_VERSION:-22.23.4}"
}
