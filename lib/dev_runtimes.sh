#!/usr/bin/env bash
instalar_node_e_astro() {
    if ! setup_reuse_tool fnm "$FNM_VERSION"; then
        local arch asset
        arch=$(setup_arch)
        case "$arch" in x86_64) asset=fnm-linux.zip ;; aarch64) asset=fnm-arm64.zip ;; esac
        # O fnm mantém sua pasta oficial; o instalador comum valida em staging.
        setup_install_release fnm Schniz/fnm "$FNM_VERSION" "$asset" "v$FNM_VERSION" "$SETUP_USER_HOME/.local/share/fnm/fnm"
    fi
    if ! setup_native node || ! setup_node_compatible; then
        timeout 300 fnm install "$NODE_VERSION"
        # Só definir padrão se não há um padrão funcional; versões de projetos são preservadas.
        local default_version
        default_version=$("$SETUP_USER_HOME/.local/share/fnm/aliases/default/bin/node" --version 2>/dev/null) || default_version=0
        if ! dpkg --compare-versions "${default_version#v}" ge "$NODE_MIN_VERSION"; then
            setup_backup "$SETUP_USER_HOME/.local/share/fnm/aliases/default" >/dev/null
            fnm default "$NODE_VERSION"
        fi
        export PATH="$SETUP_USER_HOME/.local/share/fnm/node-versions/v$NODE_VERSION/installation/bin:$PATH"
    fi
    setup_native node || { log_erro 'Node Linux não ficou disponível.'; return 1; }
    if ! setup_reuse_tool pnpm "$PNPM_VERSION"; then
        setup_native npm || { log_erro 'npm Linux ausente; repare o Node pelo fnm.'; return 1; }
        timeout 240 npm install -g "pnpm@$PNPM_VERSION" --fetch-retries=2 --fetch-timeout=30000
    fi
    setup_native pnpm
}
instalar_python_e_uv() {
    if setup_reuse_tool uv "$UV_VERSION"; then log_pulado 'uv funcional.'; return; fi
    local arch; arch=$(setup_arch)
    setup_install_release uv astral-sh/uv "$UV_VERSION" "uv-$arch-unknown-linux-gnu.tar.gz" "$UV_VERSION"
}
