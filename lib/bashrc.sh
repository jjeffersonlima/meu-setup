#!/usr/bin/env bash
configurar_bashrc() {
    setup_python migrate --components "$SETUP_COMPONENTS"
    local target="$SETUP_USER_HOME/.local/share/bash-completion/completions/uv" version_file temp version
    version_file="$SETUP_STATE_DIR/uv-completion.version"
    if setup_native uv; then
        version=$(uv --version)
        if [ ! -s "$target" ] || [ ! -f "$version_file" ] || [ "$(cat "$version_file")" != "$version" ]; then
            mkdir -p "$(dirname "$target")"
            temp=$(mktemp "$(dirname "$target")/.uv.XXXXXX")
            if ! uv generate-shell-completion bash > "$temp" || [ ! -s "$temp" ] || ! bash -n "$temp"; then
                rm -f "$temp"; log_erro 'Falha ao gerar o autocompletar do uv.'; return 1
            fi
            setup_backup "$target" >/dev/null
            mv -f "$temp" "$target"
            printf '%s\n' "$version" > "$version_file"
        fi
    fi
}
