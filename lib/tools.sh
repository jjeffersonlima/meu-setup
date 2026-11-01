#!/usr/bin/env bash
# ==============================================================================
# meu-setup: lib/tools.sh
# Módulo de instalação de ferramentas modernas de CLI e terminal em Rust/Go.
# Inclui versões estáveis de fallback para garantir determinismo e contornar rate-limits.
# ==============================================================================

# Versões estáveis de fallback
FALLBACK_LAZYDOCKER_VERSION="v0.24.1"
FALLBACK_LAZYGIT_VERSION="v0.44.1"
FALLBACK_ZOXIDE_VERSION="v0.9.6"
FALLBACK_BAT_VERSION="v0.24.0"
FALLBACK_EZA_VERSION="v0.20.18"

# ------------------------------------------------------------------------------
# Helper para consultar última tag do GitHub com suporte a token e fallback
# ------------------------------------------------------------------------------
obter_tag_github() {
    local repo="$1"
    local fallback="$2"
    local tag=""
    local auth_header=()

    if [ -n "${GITHUB_TOKEN:-}" ]; then
        auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi

    tag=$(curl -s "${auth_header[@]}" "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
        | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)

    if [ -n "$tag" ]; then
        echo "$tag"
    else
        log_info "API do GitHub não respondeu ou atingiu rate-limit. Usando versão estável de fallback: ${fallback}" >&2
        echo "$fallback"
    fi
}

# ------------------------------------------------------------------------------
# 3. Prompt Starship & Customização do Terminal
# ------------------------------------------------------------------------------
instalar_starship() {
    log_secao "3. Prompt Moderno: Starship"

    if command -v starship >/dev/null 2>&1 || [ -f "$DIR_LOCAL_BIN/starship" ]; then
        log_pulado "Starship prompt já está instalado ($("$DIR_LOCAL_BIN/starship" --version 2>/dev/null || starship --version 2>/dev/null | head -n 1))"
    else
        log_info "Instalando o Starship (prompt ultra-rápido em Rust)..."
        mkdir -p "$DIR_LOCAL_BIN"
        if curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$DIR_LOCAL_BIN" >/dev/null 2>&1; then
            log_sucesso "Starship instalado em $DIR_LOCAL_BIN/starship!"
        else
            log_aviso "Falha ao instalar o Starship via script oficial. Tentando fallback ou ignorando."
        fi
    fi

    # Configuração do starship.toml
    mkdir -p "$HOME/.config"
    if [ -f "$DIR_SETUP/configs/starship.toml" ]; then
        cp "$DIR_SETUP/configs/starship.toml" "$HOME/.config/starship.toml"
        log_sucesso "Configuração do Starship copiada para ~/.config/starship.toml"
    fi
}

# ------------------------------------------------------------------------------
# 7. Lazydocker (Docker Visual no Terminal)
# ------------------------------------------------------------------------------
instalar_lazydocker() {
    log_secao "7. Lazydocker (Interface Visual Leve para Docker)"

    mkdir -p "$DIR_LOCAL_BIN"

    if command -v lazydocker >/dev/null 2>&1 || [ -f "$DIR_LOCAL_BIN/lazydocker" ]; then
        log_pulado "Lazydocker já está instalado em $DIR_LOCAL_BIN/lazydocker"
        return
    fi

    log_info "Instalando Lazydocker (painel visual do Docker no terminal)..."
    local arch
    arch="$(uname -m)"
    local lazy_arch=""
    case "$arch" in
        x86_64) lazy_arch="x86_64" ;;
        aarch64|arm64) lazy_arch="arm64" ;;
        *) lazy_arch="" ;;
    esac

    if [ -z "$lazy_arch" ]; then
        log_aviso "Arquitetura '$arch' não suportada automaticamente para Lazydocker. Pulando."
        return
    fi

    local tag
    tag=$(obter_tag_github "jesseduffield/lazydocker" "$FALLBACK_LAZYDOCKER_VERSION")

    local tar_file="lazydocker_${tag#v}_Linux_${lazy_arch}.tar.gz"
    local download_url="https://github.com/jesseduffield/lazydocker/releases/download/${tag}/${tar_file}"
    local temp_dir
    temp_dir=$(mktemp -d)

    if curl -fsSL "$download_url" -o "$temp_dir/$tar_file" 2>/dev/null; then
        tar -xzf "$temp_dir/$tar_file" -C "$temp_dir" lazydocker 2>/dev/null || true
        if [ -f "$temp_dir/lazydocker" ]; then
            mv "$temp_dir/lazydocker" "$DIR_LOCAL_BIN/lazydocker"
            chmod +x "$DIR_LOCAL_BIN/lazydocker"
        fi
    fi
    rm -rf "$temp_dir"

    if [ -f "$DIR_LOCAL_BIN/lazydocker" ]; then
        chmod +x "$DIR_LOCAL_BIN/lazydocker"
        log_sucesso "Lazydocker instalado com sucesso em $DIR_LOCAL_BIN/lazydocker!"
    else
        log_aviso "Não foi possível baixar o Lazydocker automaticamente."
    fi
}

# ------------------------------------------------------------------------------
# 8. Lazygit (Interface Visual de Git no Terminal)
# ------------------------------------------------------------------------------
instalar_lazygit() {
    log_secao "8. Lazygit (Interface Visual Leve para Git)"

    mkdir -p "$DIR_LOCAL_BIN"

    if command -v lazygit >/dev/null 2>&1 || [ -f "$DIR_LOCAL_BIN/lazygit" ]; then
        log_pulado "Lazygit já está instalado em $DIR_LOCAL_BIN/lazygit"
        return
    fi

    log_info "Instalando Lazygit (painel visual do Git no terminal)..."
    local arch
    arch="$(uname -m)"
    local lg_arch=""
    case "$arch" in
        x86_64) lg_arch="x86_64" ;;
        aarch64|arm64) lg_arch="arm64" ;;
        *) lg_arch="" ;;
    esac

    if [ -z "$lg_arch" ]; then
        log_aviso "Arquitetura '$arch' não suportada automaticamente para Lazygit. Pulando."
        return
    fi

    local tag
    tag=$(obter_tag_github "jesseduffield/lazygit" "$FALLBACK_LAZYGIT_VERSION")

    local tar_file="lazygit_${tag#v}_linux_${lg_arch}.tar.gz"
    local download_url="https://github.com/jesseduffield/lazygit/releases/download/${tag}/${tar_file}"
    local temp_dir
    temp_dir=$(mktemp -d)

    if curl -fsSL "$download_url" -o "$temp_dir/$tar_file" 2>/dev/null; then
        tar -xzf "$temp_dir/$tar_file" -C "$temp_dir" lazygit 2>/dev/null || true
        if [ -f "$temp_dir/lazygit" ]; then
            mv "$temp_dir/lazygit" "$DIR_LOCAL_BIN/lazygit"
            chmod +x "$DIR_LOCAL_BIN/lazygit"
        fi
    fi
    rm -rf "$temp_dir"

    if [ -f "$DIR_LOCAL_BIN/lazygit" ]; then
        chmod +x "$DIR_LOCAL_BIN/lazygit"
        log_sucesso "Lazygit instalado com sucesso em $DIR_LOCAL_BIN/lazygit!"
    else
        log_aviso "Não foi possível baixar o Lazygit automaticamente."
    fi
}

# ------------------------------------------------------------------------------
# 9. Zoxide (Navegação Inteligente entre Diretórios em Rust)
# ------------------------------------------------------------------------------
instalar_zoxide() {
    log_secao "9. Zoxide (Navegação Inteligente com comando 'z')"

    mkdir -p "$DIR_LOCAL_BIN"

    if command -v zoxide >/dev/null 2>&1 || [ -f "$DIR_LOCAL_BIN/zoxide" ]; then
        log_pulado "Zoxide já está instalado em $DIR_LOCAL_BIN/zoxide"
        return
    fi

    log_info "Instalando Zoxide (escrito em Rust, zero processos de fundo)..."
    local arch
    arch="$(uname -m)"
    local z_arch=""
    case "$arch" in
        x86_64) z_arch="x86_64" ;;
        aarch64|arm64) z_arch="aarch64" ;;
        *) z_arch="" ;;
    esac

    if [ -n "$z_arch" ]; then
        local tag
        tag=$(obter_tag_github "ajeetdsouza/zoxide" "$FALLBACK_ZOXIDE_VERSION")
        local tar_file="zoxide-${tag#v}-${z_arch}-unknown-linux-musl.tar.gz"
        local download_url="https://github.com/ajeetdsouza/zoxide/releases/download/${tag}/${tar_file}"
        local temp_dir
        temp_dir=$(mktemp -d)
        if curl -fsSL "$download_url" -o "$temp_dir/$tar_file" 2>/dev/null; then
            tar -xzf "$temp_dir/$tar_file" -C "$temp_dir" zoxide 2>/dev/null || true
            if [ -f "$temp_dir/zoxide" ]; then
                mv "$temp_dir/zoxide" "$DIR_LOCAL_BIN/zoxide"
                chmod +x "$DIR_LOCAL_BIN/zoxide"
            fi
        fi
        rm -rf "$temp_dir"
    fi

    # Fallback para o script oficial do zoxide se o release direto falhar
    if [ ! -f "$DIR_LOCAL_BIN/zoxide" ]; then
        log_info "Tentando instalador oficial do Zoxide..."
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | BIN_DIR="$DIR_LOCAL_BIN" sh >/dev/null 2>&1 || true
    fi

    if [ -f "$DIR_LOCAL_BIN/zoxide" ]; then
        chmod +x "$DIR_LOCAL_BIN/zoxide"
        log_sucesso "Zoxide instalado com sucesso em $DIR_LOCAL_BIN/zoxide!"
    else
        log_aviso "Não foi possível baixar o Zoxide automaticamente."
    fi
}

# ------------------------------------------------------------------------------
# 10. Bat (Leitor de Arquivos com Sintaxe Colorida em Rust)
# ------------------------------------------------------------------------------
instalar_bat() {
    log_secao "10. Bat (Substituto Moderno do 'cat' em Rust)"

    mkdir -p "$DIR_LOCAL_BIN"

    if command -v bat >/dev/null 2>&1 || [ -f "$DIR_LOCAL_BIN/bat" ]; then
        log_pulado "Bat já está instalado em $DIR_LOCAL_BIN/bat"
        return
    fi

    log_info "Instalando Bat (visualizador de arquivos com realce de sintaxe)..."
    local arch
    arch="$(uname -m)"
    local bat_arch=""
    case "$arch" in
        x86_64) bat_arch="x86_64" ;;
        aarch64|arm64) bat_arch="aarch64" ;;
        *) bat_arch="" ;;
    esac

    if [ -n "$bat_arch" ]; then
        local tag
        tag=$(obter_tag_github "sharkdp/bat" "$FALLBACK_BAT_VERSION")
        local tar_file="bat-${tag}-${bat_arch}-unknown-linux-musl.tar.gz"
        local download_url="https://github.com/sharkdp/bat/releases/download/${tag}/${tar_file}"
        local temp_dir
        temp_dir=$(mktemp -d)
        if curl -fsSL "$download_url" -o "$temp_dir/$tar_file" 2>/dev/null; then
            tar -xzf "$temp_dir/$tar_file" -C "$temp_dir" 2>/dev/null || true
            local bin_found
            bin_found=$(find "$temp_dir" -type f -name "bat" | head -n 1)
            if [ -n "$bin_found" ] && [ -f "$bin_found" ]; then
                mv "$bin_found" "$DIR_LOCAL_BIN/bat"
                chmod +x "$DIR_LOCAL_BIN/bat"
            fi
        fi
        rm -rf "$temp_dir"
    fi

    # Fallback via apt se o download direto não instalou
    if [ ! -f "$DIR_LOCAL_BIN/bat" ]; then
        if ! dpkg -s bat >/dev/null 2>&1; then
            local sudo_cmd=""
            [ "$EUID" -ne 0 ] && sudo_cmd="sudo"
            $sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y bat >/dev/null 2>&1 || true
        fi
        if command -v batcat >/dev/null 2>&1; then
            ln -sf "$(command -v batcat)" "$DIR_LOCAL_BIN/bat"
        fi
    fi

    if [ -f "$DIR_LOCAL_BIN/bat" ] || command -v bat >/dev/null 2>&1; then
        log_sucesso "Bat instalado com sucesso em $DIR_LOCAL_BIN/bat!"
    else
        log_aviso "Não foi possível baixar o Bat automaticamente."
    fi
}

# ------------------------------------------------------------------------------
# 11. Eza (Listagem de Pastas com Suporte a Git e Árvore em Rust)
# ------------------------------------------------------------------------------
instalar_eza() {
    log_secao "11. Eza (Substituto Moderno do 'ls' em Rust com Git)"

    mkdir -p "$DIR_LOCAL_BIN"

    if command -v eza >/dev/null 2>&1 || [ -f "$DIR_LOCAL_BIN/eza" ]; then
        log_pulado "Eza já está instalado em $DIR_LOCAL_BIN/eza"
        return
    fi

    log_info "Instalando Eza (listagem rápida com ícones e status de Git)..."
    local arch
    arch="$(uname -m)"
    local eza_arch=""
    case "$arch" in
        x86_64) eza_arch="x86_64-unknown-linux-gnu" ;;
        aarch64|arm64) eza_arch="aarch64-unknown-linux-gnu" ;;
        *) eza_arch="" ;;
    esac

    if [ -n "$eza_arch" ]; then
        local tag
        tag=$(obter_tag_github "eza-community/eza" "$FALLBACK_EZA_VERSION")
        local tar_file="eza_${eza_arch}.tar.gz"
        local download_url="https://github.com/eza-community/eza/releases/download/${tag}/${tar_file}"
        local temp_dir
        temp_dir=$(mktemp -d)
        if curl -fsSL "$download_url" -o "$temp_dir/$tar_file" 2>/dev/null; then
            tar -xzf "$temp_dir/$tar_file" -C "$temp_dir" 2>/dev/null || true
            local bin_found
            bin_found=$(find "$temp_dir" -type f -name "eza" | head -n 1)
            if [ -n "$bin_found" ] && [ -f "$bin_found" ]; then
                mv "$bin_found" "$DIR_LOCAL_BIN/eza"
                chmod +x "$DIR_LOCAL_BIN/eza"
            fi
        fi
        rm -rf "$temp_dir"
    fi

    if [ -f "$DIR_LOCAL_BIN/eza" ]; then
        chmod +x "$DIR_LOCAL_BIN/eza"
        log_sucesso "Eza instalado com sucesso em $DIR_LOCAL_BIN/eza!"
    else
        log_aviso "Não foi possível baixar o Eza automaticamente."
    fi
}
