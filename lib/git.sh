#!/usr/bin/env bash
# ==============================================================================
# meu-setup: lib/git.sh
# Módulo de configuração guiada do Git, GitHub CLI e chaves SSH.
# Suporta modo interativo e modo não-interativo com variáveis de ambiente.
# ==============================================================================

# ------------------------------------------------------------------------------
# 8. Configuração do Git, GitHub CLI e SSH
# ------------------------------------------------------------------------------
configurar_git() {
    log_secao "8. Configuração do Git e GitHub"

    # Nome e Email
    local current_name
    local current_email
    current_name=$(git config --global user.name || true)
    current_email=$(git config --global user.email || true)

    if [ -n "$current_name" ] && [ -n "$current_email" ]; then
        log_pulado "Git já configurado para: $current_name <$current_email>"
    else
        local git_nome="${GIT_USER_NAME:-}"
        local git_email="${GIT_USER_EMAIL:-}"

        if [ -z "$git_nome" ] && [ "${SETUP_NON_INTERACTIVE:-false}" != "true" ] && [ -t 0 ]; then
            echo -e "${YELLOW}Identidade Git não configurada.${NC}"
            read -rp "Digite seu Nome completo para o Git: " git_nome
            read -rp "Digite seu E-mail para o Git: " git_email
        fi

        if [ -n "$git_nome" ]; then
            git config --global user.name "$git_nome"
        fi
        if [ -n "$git_email" ]; then
            git config --global user.email "$git_email"
        fi

        if [ -n "$git_nome" ] || [ -n "$git_email" ]; then
            log_sucesso "Identidade Git configurada com sucesso!"
        else
            log_aviso "Identidade Git não preenchida nesta etapa (pode ser configurada com 'git config --global')."
        fi
    fi

    # Branch padrão main
    local default_branch
    default_branch=$(git config --global init.defaultBranch || true)
    if [ "$default_branch" != "main" ]; then
        git config --global init.defaultBranch main
        log_sucesso "Branch padrão do Git definida como 'main'."
    else
        log_pulado "Branch padrão já é 'main'."
    fi

    # Global gitignore
    mkdir -p "$HOME/.config/git"
    if [ -f "$DIR_SETUP/configs/gitignore_global" ]; then
        cp "$DIR_SETUP/configs/gitignore_global" "$HOME/.config/git/ignore"
        git config --global core.excludesFile "$HOME/.config/git/ignore"
        log_sucesso "Gitignore global instalado em ~/.config/git/ignore"
    fi

    # Chave SSH (Ed25519)
    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        log_pulado "Chave SSH id_ed25519 já existe em ~/.ssh/"
    else
        local gerar_ssh="N"
        if [ "${SETUP_GENERATE_SSH:-}" = "true" ]; then
            gerar_ssh="S"
        elif [ "${SETUP_NON_INTERACTIVE:-false}" != "true" ] && [ -t 0 ]; then
            echo -e "\n${YELLOW}Deseja gerar uma chave SSH (Ed25519) para conectar com GitHub/GitLab? [S/n]${NC}"
            read -rp "> " resp_ssh
            gerar_ssh="${resp_ssh:-S}"
        fi

        if [[ "$gerar_ssh" =~ ^[Ss]$ ]]; then
            mkdir -p "$HOME/.ssh"
            chmod 700 "$HOME/.ssh"
            local ssh_email
            ssh_email=$(git config --global user.email || echo "${USER:-user}@wsl")
            ssh-keygen -t ed25519 -C "$ssh_email" -f "$HOME/.ssh/id_ed25519" -N "" >/dev/null 2>&1
            log_sucesso "Chave SSH gerada com sucesso!"
            if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
                echo -e "${CYAN}Sua chave pública (copie para o GitHub -> Settings -> SSH Keys):${NC}"
                cat "$HOME/.ssh/id_ed25519.pub"
                echo ""
            fi
        else
            log_info "Geração de chave SSH pulada."
        fi
    fi

    # GitHub CLI (gh)
    if command -v gh >/dev/null 2>&1; then
        log_pulado "GitHub CLI (gh) já instalado."
    else
        if dpkg -s gh >/dev/null 2>&1; then
            log_pulado "GitHub CLI (gh) já instalado via apt."
        else
            log_info "Instalando GitHub CLI (gh)..."
            local sudo_cmd=""
            [ "$EUID" -ne 0 ] && sudo_cmd="sudo"
            $sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y gh 2>/dev/null || {
                type -p curl >/dev/null || $sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install curl -y
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | $sudo_cmd dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null || true
                $sudo_cmd chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null || true
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | $sudo_cmd tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                $sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get update -y && $sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y gh 2>/dev/null || true
            }
            if command -v gh >/dev/null 2>&1; then
                log_sucesso "GitHub CLI (gh) instalado!"
            fi
        fi
    fi
}
