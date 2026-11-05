#!/usr/bin/env bash
configurar_git() {
    setup_native git || { log_erro 'Git não está disponível.'; return 1; }
    if [ "${SETUP_CONFIG_ONLY:-false}" = false ] && ! setup_native gh; then
        executar_apt_update
        setup_admin env DEBIAN_FRONTEND=noninteractive apt-get install -y gh
    fi
    local config="${GIT_CONFIG_GLOBAL:-$SETUP_USER_HOME/.gitconfig}" value
    if [ ! -e "$config" ] && [ -f "${XDG_CONFIG_HOME:-$SETUP_USER_HOME/.config}/git/config" ]; then
        config="${XDG_CONFIG_HOME:-$SETUP_USER_HOME/.config}/git/config"
    fi
    if [ -L "$config" ]; then
        log_aviso 'Git global é um link personalizado. Configurações preservadas; revise preferências manualmente.'
        return 0
    fi
    value=$(git config --global user.name || true)
    if [ -z "$value" ] && [ -n "${GIT_USER_NAME:-}" ]; then
        setup_backup "$config" >/dev/null; git config --global user.name "$GIT_USER_NAME"
    fi
    value=$(git config --global user.email || true)
    if [ -z "$value" ] && [ -n "${GIT_USER_EMAIL:-}" ]; then
        setup_backup "$config" >/dev/null; git config --global user.email "$GIT_USER_EMAIL"
    fi
    if ! git config --global init.defaultBranch >/dev/null; then
        setup_backup "$config" >/dev/null; git config --global init.defaultBranch main
    fi
    value=$(git config --global core.excludesFile || true)
    if [ -z "$value" ]; then
        setup_backup "$config" >/dev/null; git config --global core.excludesFile "$SETUP_USER_HOME/.config/git/ignore"
    elif [ "$value" != "$SETUP_USER_HOME/.config/git/ignore" ]; then
        log_aviso 'Seu ignore global Git personalizado foi preservado. Os padrões do setup estão em ~/.config/git/ignore.'
    fi
    if [ "${SETUP_GENERATE_SSH:-false}" = true ] && [ ! -e "$SETUP_USER_HOME/.ssh/id_ed25519" ]; then
        mkdir -p "$SETUP_USER_HOME/.ssh"; chmod 700 "$SETUP_USER_HOME/.ssh"
        ssh-keygen -t ed25519 -C "${GIT_USER_EMAIL:-estudante@local}" -f "$SETUP_USER_HOME/.ssh/id_ed25519"
    fi
}
