#!/usr/bin/env bash
# ==============================================================================
# meu-setup: lib/bashrc.sh
# Módulo de configuração de aliases, variáveis de ambiente e symlinks no ~/.bashrc.
# Totalmente idempotente: limpa blocos legados e injeta marcadores seguros.
# ==============================================================================

# Marcadores para o ~/.bashrc
BASHRC_MARKER_START="# >>> meu-setup >>>"
BASHRC_MARKER_END="# <<< meu-setup <<<"

# ------------------------------------------------------------------------------
# 9. Aliases, Variáveis de Ambiente e ~/.bashrc
# ------------------------------------------------------------------------------
configurar_bashrc() {
    log_secao "9. Configuração de Aliases e Ambiente (~/.bashrc)"

    mkdir -p "$DIR_LOCAL_BIN"

    # Conecta os utilitários do meu-setup em ~/.local/bin/ via Links Simbólicos (Symlinks)
    local utilitarios=("novo-projeto" "atualizar" "diagnostico" "portainer")
    for util in "${utilitarios[@]}"; do
        if [ -f "$DIR_SETUP/bin/$util" ]; then
            ln -sf "$DIR_SETUP/bin/$util" "$DIR_LOCAL_BIN/$util"
            chmod +x "$DIR_SETUP/bin/$util"
            log_sucesso "Utilitário '$util' conectado via symlink em $DIR_LOCAL_BIN/$util"
        fi
    done

    # Prepara diretório padrão de bash-completion e gera cache estático do uv para boot instantâneo
    local dir_completions="$HOME/.local/share/bash-completion/completions"
    mkdir -p "$dir_completions"
    local uv_bin=""
    if [ -x "$DIR_LOCAL_BIN/uv" ]; then
        uv_bin="$DIR_LOCAL_BIN/uv"
    elif command -v uv >/dev/null 2>&1; then
        uv_bin="uv"
    fi
    if [ -n "$uv_bin" ]; then
        "$uv_bin" generate-shell-completion bash > "$dir_completions/uv" 2>/dev/null || true
        log_sucesso "Cache de autocompletar do uv gerado em $dir_completions/uv"
    fi

    # Garante que ~/.bashrc exista
    touch "$HOME/.bashrc"

    # Garante backup do ~/.bashrc
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    cp "$HOME/.bashrc" "$HOME/.bashrc.backup.$timestamp" 2>/dev/null || true

    # Remove bloco anterior se existir para garantir atualização limpa sem duplicar
    if grep -q "$BASHRC_MARKER_START" "$HOME/.bashrc" 2>/dev/null; then
        log_info "Atualizando bloco existente de configurações em ~/.bashrc..."
        sed -i "/$BASHRC_MARKER_START/,/$BASHRC_MARKER_END/d" "$HOME/.bashrc"
    fi

    # Escreve o bloco limpo
    cat << 'EOF' >> "$HOME/.bashrc"

# >>> meu-setup >>>
# Caminho para utilitários locais do usuário
export PATH="$HOME/.local/bin:$PATH"

# fnm (Fast Node Manager)
if [ -d "$HOME/.local/share/fnm" ]; then
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env --use-on-cd 2>/dev/null)"
fi

# uv (Python package manager - autocompletar via cache estático)
if [ -f "$HOME/.local/share/bash-completion/completions/uv" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.local/share/bash-completion/completions/uv" 2>/dev/null
fi

# Zoxide (Navegação Inteligente entre Diretórios - comando 'z')
if command -v zoxide >/dev/null 2>&1 || [ -f "$HOME/.local/bin/zoxide" ]; then
    eval "$(zoxide init bash)"
fi

# Starship Prompt
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

# Aliases de Navegação e Arquivos (Eza / Bat)
if command -v eza >/dev/null 2>&1 || [ -f "$HOME/.local/bin/eza" ]; then
    alias ll='eza -la --icons --git --group-directories-first 2>/dev/null || ls -lah --color=auto'
    alias tree='eza --tree --icons 2>/dev/null || tree'
else
    alias ll='ls -lah --color=auto'
fi

if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    alias bat='batcat'
fi

# Aliases úteis para o dia a dia
alias ..='cd ..'
alias ...='cd ../..'
alias ports='netstat -tulanp 2>/dev/null || ss -tulanp'
alias myip='hostname -I | awk "{print \$1}"'
alias open='explorer.exe 2>/dev/null || xdg-open'
alias code='code 2>/dev/null || true'

# Manutenção e Atualização Contínua
alias atualizar='atualizar'
alias update='atualizar'

# Diagnóstico e Saúde do Sistema
alias diagnostico='diagnostico'
alias doctor='diagnostico'

# Utilitários de Projetos e Sites
alias novo='novo-projeto'
alias novo-astro='pnpm create astro@latest'
alias novo-python='novo-projeto'

# Ferramentas Visuais de Terminal (Lazydocker & Lazygit)
alias ld='lazydocker'
alias lg='lazygit'

# Portainer CE Sob Demanda (Web na porta 9000)
alias portainer='portainer'
# <<< meu-setup <<<
EOF

    log_sucesso "Configurações e aliases injetados no ~/.bashrc sem duplicatas!"
}
