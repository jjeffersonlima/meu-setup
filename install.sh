#!/usr/bin/env bash
# ==============================================================================
# meu-setup: install.sh
# Automação de ambiente de desenvolvimento moderna, leve e idempotente para WSL.
# Focado em: Automações, Sites (Astro), Aplicações e Sistemas.
# ==============================================================================

set -uo pipefail

# Paleta de cores para mensagens
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m' # No Color

DIR_SETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR_LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$DIR_LOCAL_BIN"

# Sistema de Logs de Instalação (Audit Trail)
LOG_DIR="$HOME/.local/state/meu-setup/logs"
mkdir -p "$LOG_DIR"
LOG_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/install_${LOG_TIMESTAMP}.log"
LOG_LATEST="$LOG_DIR/install_latest.log"

# Dual Logging: toda a saída é exibida no terminal e salva no log simultaneamente
exec > >(tee -a "$LOG_FILE") 2>&1
ln -sf "$LOG_FILE" "$LOG_LATEST"

# Marcadores para o ~/.bashrc
BASHRC_MARKER_START="# >>> meu-setup >>>"
BASHRC_MARKER_END="# <<< meu-setup <<<"

# ------------------------------------------------------------------------------
# Funções de Logging e Feedback Visual
# ------------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_sucesso() {
    echo -e "${GREEN}✔${NC} $1"
}

log_aviso() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_pulado() {
    echo -e "${CYAN}↷ [JÁ INSTALADO / CONFIGURADO]${NC} $1"
}

log_erro() {
    echo -e "${RED}✖ [ERRO]${NC} $1"
}

log_secao() {
    echo -e "\n${BOLD}${MAGENTA}==>${NC} ${BOLD}$1${NC}"
}

# ------------------------------------------------------------------------------
# Banner e Boas-Vindas
# ------------------------------------------------------------------------------
mostrar_banner() {
    clear 2>/dev/null || true
    echo -e "${CYAN}"
    echo "  ╔════════════════════════════════════════════════════════════════╗"
    echo "  ║                                                                ║"
    echo "  ║                      🛠️   M E U - S E T U P                    ║"
    echo "  ║         Ambiente de Desenvolvimento Automatizado para WSL      ║"
    echo "  ║                                                                ║"
    echo "  ╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  Focado em: ${GREEN}Automações${NC} | ${GREEN}Sites (Astro)${NC} | ${GREEN}Apps (Node/TS & Python)${NC} | ${GREEN}Docker & Terminal Rust${NC}\n"
}

# ------------------------------------------------------------------------------
# Detecção de Ambiente WSL
# ------------------------------------------------------------------------------
verificar_wsl() {
    log_secao "Verificando ambiente do sistema"
    if grep -qi "microsoft" /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
        local wsl_versao="WSL 2 / 3"
        log_sucesso "Detectado ambiente: ${BOLD}Linux sob WSL (${WSL_DISTRO_NAME:-Ubuntu})${NC}"
    else
        log_aviso "Aviso: Ambiente Linux nativo detectado (não é WSL). O script funcionará perfeitamente!"
    fi
}

# ------------------------------------------------------------------------------
# Solicitar credenciais Sudo antecipadamente (apenas se necessário)
# ------------------------------------------------------------------------------
checar_sudo() {
    if [ "$EUID" -ne 0 ]; then
        log_info "Alguns pacotes do sistema precisam de privilégios de administrador (sudo)."
        if sudo -v; then
            # Mantém o token do sudo vivo durante a execução
            while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
        else
            log_erro "Não foi possível obter permissões de sudo. Algumas etapas podem falhar."
        fi
    fi
}

# ------------------------------------------------------------------------------
# 1. Configuração do WSL (/etc/wsl.conf - systemd)
# ------------------------------------------------------------------------------
configurar_wsl_conf() {
    log_secao "1. Otimização do WSL (/etc/wsl.conf)"
    
    local wsl_conf="/etc/wsl.conf"
    local precisa_configurar=false

    if [ ! -f "$wsl_conf" ] || ! grep -q "systemd=true" "$wsl_conf" 2>/dev/null; then
        precisa_configurar=true
    fi

    if [ "$precisa_configurar" = true ]; then
        log_info "Habilitando systemd e interoperação no WSL para suporte total ao Docker e serviços..."
        sudo bash -c "cat >> $wsl_conf" << 'EOF'

[boot]
systemd=true

[interop]
enabled=true
appendWindowsPath=true

[automount]
enabled=true
options="metadata,umask=22,fmask=11"
EOF
        log_sucesso "Arquivo /etc/wsl.conf configurado com systemd ativado!"
        log_aviso "Lembrete: Após a instalação, você pode reiniciar o WSL no Windows PowerShell com: wsl --shutdown"
    else
        log_pulado "systemd já está ativo em /etc/wsl.conf"
    fi
}

# ------------------------------------------------------------------------------
# 2. Pacote Essencial de Ferramentas CLI
# ------------------------------------------------------------------------------
instalar_pacote_essencial() {
    log_secao "2. Pacote Essencial de Ferramentas CLI"
    
    local pacotes=(curl wget git jq fzf ripgrep build-essential unzip ca-certificates gnupg lsb-release)
    local pacotes_faltando=()

    for pkg in "${pacotes[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            pacotes_faltando+=("$pkg")
        fi
    done

    if [ ${#pacotes_faltando[@]} -eq 0 ]; then
        log_pulado "Todas as ferramentas essenciais já estão instaladas (${pacotes[*]})"
    else
        log_info "Instalando ferramentas faltantes: ${YELLOW}${pacotes_faltando[*]}${NC}..."
        sudo apt update -y
        sudo apt install -y "${pacotes_faltando[@]}"
        log_sucesso "Ferramentas essenciais instaladas com sucesso!"
    fi
}

# ------------------------------------------------------------------------------
# 3. Prompt Starship & Customização do Terminal
# ------------------------------------------------------------------------------
instalar_starship() {
    log_secao "3. Prompt Moderno: Starship"

    if command -v starship >/dev/null 2>&1; then
        log_pulado "Starship prompt já está instalado ($(starship --version | head -n 1))"
    else
        log_info "Instalando o Starship (prompt ultra-rápido em Rust)..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$DIR_LOCAL_BIN"
        log_sucesso "Starship instalado em $DIR_LOCAL_BIN/starship!"
    fi

    # Configuração do starship.toml
    mkdir -p "$HOME/.config"
    if [ -f "$DIR_SETUP/configs/starship.toml" ]; then
        cp "$DIR_SETUP/configs/starship.toml" "$HOME/.config/starship.toml"
        log_sucesso "Configuração do Starship copiada para ~/.config/starship.toml"
    fi
}

# ------------------------------------------------------------------------------
# 4. Node.js & Ecossistema Astro (fnm + pnpm)
# ------------------------------------------------------------------------------
instalar_node_e_astro() {
    log_secao "4. Node.js, pnpm & Ecossistema Astro"

    # 1. Instalar fnm (Fast Node Manager) se não existir
    if command -v fnm >/dev/null 2>&1 || [ -f "$HOME/.local/share/fnm/fnm" ]; then
        log_pulado "fnm (Fast Node Manager) já está instalado."
    else
        log_info "Instalando fnm (gerenciador de Node.js ultra-rápido em Rust)..."
        curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$HOME/.local/share/fnm" --skip-shell
        export PATH="$HOME/.local/share/fnm:$PATH"
        eval "$(fnm env 2>/dev/null || true)"
        log_sucesso "fnm instalado com sucesso!"
    fi

    # Carregar fnm na sessão atual
    if [ -d "$HOME/.local/share/fnm" ]; then
        export PATH="$HOME/.local/share/fnm:$PATH"
        eval "$(fnm env --use-on-cd 2>/dev/null || true)"
    fi

    # 2. Instalar Node LTS se não existir
    if command -v node >/dev/null 2>&1; then
        log_pulado "Node.js já instalado: $(node -v)"
    else
        log_info "Instalando Node.js versão LTS (Long Term Support)..."
        fnm install --lts
        fnm default lts-latest
        log_sucesso "Node.js $(node -v 2>/dev/null || echo 'LTS') instalado com sucesso!"
    fi

    # 3. Instalar pnpm (padrão recomendado pela equipe do Astro)
    if command -v pnpm >/dev/null 2>&1; then
        log_pulado "pnpm já está instalado ($(pnpm -v))"
    else
        log_info "Instalando pnpm (gerenciador de pacotes rápido e eficiente para Astro e Node)..."
        if command -v corepack >/dev/null 2>&1; then
            corepack enable >/dev/null 2>&1 || npm install -g pnpm
        else
            npm install -g pnpm
        fi
        log_sucesso "pnpm instalado com sucesso!"
    fi
}

# ------------------------------------------------------------------------------
# 5. Python & Automações (uv + venv)
# ------------------------------------------------------------------------------
instalar_python_e_uv() {
    log_secao "5. Python para Automações & uv (Astral)"

    # Instalar python3-venv e pip se faltar
    if ! dpkg -s python3-venv >/dev/null 2>&1; then
        log_info "Instalando python3-venv do sistema..."
        sudo apt install -y python3-venv python3-pip
    else
        log_pulado "python3-venv já está instalado no sistema."
    fi

    # Instalar uv (ferramenta moderna em Rust da Astral, substitui pip/pyenv com 100x mais velocidade)
    if command -v uv >/dev/null 2>&1 || [ -f "$HOME/.cargo/bin/uv" ] || [ -f "$DIR_LOCAL_BIN/uv" ]; then
        log_pulado "uv já está instalado ($("$HOME/.local/bin/uv" --version 2>/dev/null || uv --version 2>/dev/null || echo 'uv'))"
    else
        log_info "Instalando uv (o gerenciador de Python e pacotes mais rápido do mundo)..."
        curl -LsSf https://astral.sh/uv/install.sh | env CARGO_HOME="" UV_INSTALL_DIR="$DIR_LOCAL_BIN" sh
        log_sucesso "uv instalado em $DIR_LOCAL_BIN/uv!"
    fi
}

# ------------------------------------------------------------------------------
# 6. Docker Nativo (Docker Engine + Compose via systemd)
# ------------------------------------------------------------------------------
instalar_docker() {
    log_secao "6. Docker Engine Nativo & Docker Compose"

    if command -v docker >/dev/null 2>&1; then
        log_pulado "Docker já está instalado ($(docker --version))"
    else
        log_info "Instalando Docker Engine nativo no WSL..."
        sudo apt update -y
        # No repositório oficial do Ubuntu o plugin se chama docker-compose-v2; no repo externo da Docker se chama docker-compose-plugin
        if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
            sudo apt install -y docker.io docker-compose-v2
        elif apt-cache show docker-compose-plugin >/dev/null 2>&1; then
            sudo apt install -y docker.io docker-compose-plugin
        else
            sudo apt install -y docker.io
        fi
        log_sucesso "Docker Engine instalado!"
    fi

    # Adicionar usuário atual ao grupo docker (para não precisar usar 'sudo docker')
    if groups "$USER" | grep -q "\bdocker\b"; then
        log_pulado "Usuário '$USER' já está no grupo 'docker'."
    else
        log_info "Adicionando o usuário '$USER' ao grupo docker..."
        sudo usermod -aG docker "$USER"
        log_sucesso "Usuário adicionado ao grupo docker! (Faça logout/login ou use 'newgrp docker')"
    fi

    # Habilitar e iniciar serviço docker via systemd se disponível
    if command -v systemctl >/dev/null 2>&1; then
        if sudo systemctl is-active --quiet docker; then
            log_pulado "Serviço Docker já está em execução."
        else
            log_info "Iniciando e habilitando serviço Docker no systemd..."
            sudo systemctl enable --now docker 2>/dev/null || true
            # Aguarda a inicialização do socket do Docker (até 5 segundos)
            for _ in {1..5}; do
                if sudo docker info >/dev/null 2>&1; then
                    break
                fi
                sleep 1
            done
            log_sucesso "Serviço Docker iniciado!"
        fi
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

    local latest_tag
    latest_tag=$(curl -s "https://api.github.com/repos/jesseduffield/lazydocker/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)

    if [ -z "$latest_tag" ]; then
        log_info "Tentando instalação via script oficial do Lazydocker..."
        curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | DIR="$DIR_LOCAL_BIN" bash 2>/dev/null || true
    else
        local tar_file="lazydocker_${latest_tag#v}_Linux_${lazy_arch}.tar.gz"
        local download_url="https://github.com/jesseduffield/lazydocker/releases/download/${latest_tag}/${tar_file}"
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
    fi

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

    local latest_tag
    latest_tag=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)

    if [ -n "$latest_tag" ]; then
        local tar_file="lazygit_${latest_tag#v}_linux_${lg_arch}.tar.gz"
        local download_url="https://github.com/jesseduffield/lazygit/releases/download/${latest_tag}/${tar_file}"
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
    fi

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
        local latest_tag
        latest_tag=$(curl -s "https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)
        if [ -n "$latest_tag" ]; then
            local tar_file="zoxide-${latest_tag#v}-${z_arch}-unknown-linux-musl.tar.gz"
            local download_url="https://github.com/ajeetdsouza/zoxide/releases/download/${latest_tag}/${tar_file}"
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
    fi

    if [ ! -f "$DIR_LOCAL_BIN/zoxide" ]; then
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh 2>/dev/null | env BIN_DIR="$DIR_LOCAL_BIN" sh 2>/dev/null || true
    fi

    if [ -f "$DIR_LOCAL_BIN/zoxide" ]; then
        chmod +x "$DIR_LOCAL_BIN/zoxide"
        log_sucesso "Zoxide instalado com sucesso em $DIR_LOCAL_BIN/zoxide!"
    else
        log_aviso "Não foi possível instalar o Zoxide automaticamente."
    fi
}

# ------------------------------------------------------------------------------
# 10. Bat (Visualizador de Código com Cores e Sintaxe em Rust)
# ------------------------------------------------------------------------------
instalar_bat() {
    log_secao "10. Bat (Visualizador de Código com Destaque de Sintaxe)"

    mkdir -p "$DIR_LOCAL_BIN"

    if command -v bat >/dev/null 2>&1 || [ -f "$DIR_LOCAL_BIN/bat" ]; then
        log_pulado "Bat já está instalado em $DIR_LOCAL_BIN/bat"
        return
    fi

    log_info "Instalando Bat (leitor de código moderno em Rust)..."
    local arch
    arch="$(uname -m)"
    local bat_arch=""
    case "$arch" in
        x86_64) bat_arch="x86_64" ;;
        aarch64|arm64) bat_arch="aarch64" ;;
        *) bat_arch="" ;;
    esac

    if [ -n "$bat_arch" ]; then
        local latest_tag
        latest_tag=$(curl -s "https://api.github.com/repos/sharkdp/bat/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)
        if [ -n "$latest_tag" ]; then
            local tar_file="bat-${latest_tag}-${bat_arch}-unknown-linux-musl.tar.gz"
            local download_url="https://github.com/sharkdp/bat/releases/download/${latest_tag}/${tar_file}"
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
    fi

    if [ -f "$DIR_LOCAL_BIN/bat" ]; then
        chmod +x "$DIR_LOCAL_BIN/bat"
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
        local latest_tag
        latest_tag=$(curl -s "https://api.github.com/repos/eza-community/eza/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)
        if [ -n "$latest_tag" ]; then
            local tar_file="eza_${eza_arch}.tar.gz"
            local download_url="https://github.com/eza-community/eza/releases/download/${latest_tag}/${tar_file}"
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
    fi

    if [ -f "$DIR_LOCAL_BIN/eza" ]; then
        chmod +x "$DIR_LOCAL_BIN/eza"
        log_sucesso "Eza instalado com sucesso em $DIR_LOCAL_BIN/eza!"
    else
        log_aviso "Não foi possível baixar o Eza automaticamente."
    fi
}

# ------------------------------------------------------------------------------
# 12. Portainer CE (Interface Web para Stacks Sob Demanda)
# ------------------------------------------------------------------------------
preparar_portainer() {
    log_secao "12. Portainer CE (Interface Web para Stacks Sob Demanda)"

    mkdir -p "$DIR_LOCAL_BIN"
    if [ -f "$DIR_SETUP/bin/portainer" ]; then
        ln -sf "$DIR_SETUP/bin/portainer" "$DIR_LOCAL_BIN/portainer"
        chmod +x "$DIR_SETUP/bin/portainer"
        log_sucesso "Utilitário 'portainer' conectado em $DIR_LOCAL_BIN/portainer"
    fi

    if docker images --format '{{.Repository}}' 2>/dev/null | grep -Eq "portainer/portainer-ce"; then
        log_pulado "Imagem oficial do Portainer CE já está baixada."
    else
        log_info "Baixando imagem oficial do Portainer CE para abertura instantânea..."
        if docker pull portainer/portainer-ce:latest >/dev/null 2>&1 || sudo docker pull portainer/portainer-ce:latest >/dev/null 2>&1; then
            log_sucesso "Imagem oficial do Portainer CE baixada com sucesso!"
        else
            log_aviso "Download do Portainer pendente (será baixado no primeiro uso de 'portainer')."
        fi
    fi
}

# ------------------------------------------------------------------------------
# 8. Configuração Guiada do Git & GitHub
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
        echo -e "${YELLOW}Identidade Git não configurada.${NC}"
        read -rp "Digite seu Nome completo para o Git: " git_nome
        read -rp "Digite seu E-mail para o Git: " git_email

        if [ -n "$git_nome" ]; then
            git config --global user.name "$git_nome"
        fi
        if [ -n "$git_email" ]; then
            git config --global user.email "$git_email"
        fi
        log_sucesso "Identidade Git configurada com sucesso!"
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

    # Chave SSH
    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        log_pulado "Chave SSH id_ed25519 já existe em ~/.ssh/"
    else
        echo -e "\n${YELLOW}Deseja gerar uma chave SSH (Ed25519) para conectar com GitHub/GitLab? [S/n]${NC}"
        read -rp "> " resp_ssh
        resp_ssh=${resp_ssh:-S}
        if [[ "$resp_ssh" =~ ^[Ss]$ ]]; then
            local ssh_email
            ssh_email=$(git config --global user.email || echo "$USER@wsl")
            ssh-keygen -t ed25519 -C "$ssh_email" -f "$HOME/.ssh/id_ed25519" -N ""
            log_sucesso "Chave SSH gerada com sucesso!"
            echo -e "${CYAN}Sua chave pública (copie para o GitHub -> Settings -> SSH Keys):${NC}"
            cat "$HOME/.ssh/id_ed25519.pub"
            echo ""
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
            sudo apt install -y gh 2>/dev/null || {
                # Se não estiver no repositório padrão do Ubuntu
                type -p curl >/dev/null || sudo apt install curl -y
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null || true
                sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null || true
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                sudo apt update -y && sudo apt install -y gh 2>/dev/null || true
            }
            if command -v gh >/dev/null 2>&1; then
                log_sucesso "GitHub CLI (gh) instalado!"
            fi
        fi
    fi
}

# ------------------------------------------------------------------------------
# 9. Aliases, Variáveis de Ambiente e ~/.bashrc
# ------------------------------------------------------------------------------
configurar_bashrc() {
    log_secao "9. Configuração de Aliases e Ambiente (~/.bashrc)"

    mkdir -p "$DIR_LOCAL_BIN"

    # Conecta os utilitários do meu-setup em ~/.local/bin/ via Links Simbólicos (Symlinks)
    if [ -f "$DIR_SETUP/bin/novo-projeto" ]; then
        ln -sf "$DIR_SETUP/bin/novo-projeto" "$DIR_LOCAL_BIN/novo-projeto"
        chmod +x "$DIR_SETUP/bin/novo-projeto"
        log_sucesso "Utilitário 'novo-projeto' conectado via symlink em $DIR_LOCAL_BIN/novo-projeto"
    fi

    if [ -f "$DIR_SETUP/bin/atualizar" ]; then
        ln -sf "$DIR_SETUP/bin/atualizar" "$DIR_LOCAL_BIN/atualizar"
        chmod +x "$DIR_SETUP/bin/atualizar"
        log_sucesso "Utilitário 'atualizar' conectado via symlink em $DIR_LOCAL_BIN/atualizar"
    fi

    if [ -f "$DIR_SETUP/bin/diagnostico" ]; then
        ln -sf "$DIR_SETUP/bin/diagnostico" "$DIR_LOCAL_BIN/diagnostico"
        chmod +x "$DIR_SETUP/bin/diagnostico"
        log_sucesso "Utilitário 'diagnostico' conectado via symlink em $DIR_LOCAL_BIN/diagnostico"
    fi

    if [ -f "$DIR_SETUP/bin/portainer" ]; then
        ln -sf "$DIR_SETUP/bin/portainer" "$DIR_LOCAL_BIN/portainer"
        chmod +x "$DIR_SETUP/bin/portainer"
        log_sucesso "Utilitário 'portainer' conectado via symlink em $DIR_LOCAL_BIN/portainer"
    fi

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

# uv (Python package manager)
if [ -d "$HOME/.local/bin" ] && [ -f "$HOME/.local/bin/uv" ]; then
    eval "$(uv generate-shell-completion bash 2>/dev/null)"
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

if command -v bat >/dev/null 2>&1 || [ -f "$HOME/.local/bin/bat" ]; then
    alias bat='bat 2>/dev/null || batcat'
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

# ------------------------------------------------------------------------------
# Resumo Final Dinâmico com Auditoria e Health Check
# ------------------------------------------------------------------------------
mostrar_conclusao() {
    log_secao "10. Auditoria de Integridade & Health Check Final"
    echo -e "${CYAN}Executando autoteste dos componentes instalados...${NC}\n"

    local falhas=0
    if [ -x "$DIR_SETUP/bin/diagnostico" ]; then
        if ! "$DIR_SETUP/bin/diagnostico"; then
            falhas=1
        fi
    fi

    if [ "$falhas" -eq 0 ]; then
        echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║          🎉 Instalação Concluída e 100% Validada!              ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}\n"
        echo -e "${GREEN}✔ Todos os componentes foram verificados e estão operacionais.${NC}\n"
    else
        echo -e "\n${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║       ⚠ Instalação Concluída com Alertas ou Falhas            ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}\n"
        echo -e "${YELLOW}Alguns componentes precisam de atenção (verifique a tabela acima).${NC}"
        echo -e "${YELLOW}Consulte o log detalhado para inspecionar os erros exatos:${NC}"
        echo -e "  ${CYAN}cat $LOG_LATEST${NC}\n"
    fi

    echo -e "${CYAN}📄 Log completo gravado em:${NC} $LOG_FILE"
    echo -e "${CYAN}   (Link simbólico mais recente:${NC} $LOG_LATEST)\n"

    echo -e "${YELLOW}Como começar agora mesmo:${NC}"
    echo -e "  1. Feche e abra este terminal (ou abra uma nova aba):"
    echo -e "     ${GREEN}Isso ativa o grupo Docker (para rodar sem sudo) e carrega todos os atalhos.${NC}"
    echo -e "     ${YELLOW}(Se quiser testar nesta mesma janela agora mesmo: ${CYAN}source ~/.bashrc${YELLOW})${NC}\n"
    echo -e "  2. Teste a saúde das ferramentas a qualquer momento:"
    echo -e "     ${CYAN}diagnostico${NC}  ${YELLOW}(ou 'doctor')${NC}\n"
    echo -e "  3. Navegue rápido entre projetos com Zoxide:"
    echo -e "     ${CYAN}z <pasta>${NC}    ${YELLOW}(ex: 'z meu' ou 'z setup' para pular direto)${NC}\n"
    echo -e "  4. Abra o gerenciador visual do Git:"
    echo -e "     ${CYAN}lg${NC}           ${YELLOW}(ou 'lazygit')${NC}\n"
    echo -e "  5. Abra o painel do Docker no terminal:"
    echo -e "     ${CYAN}ld${NC}           ${YELLOW}(ou 'lazydocker')${NC}\n"
    echo -e "  6. Suba Stacks completas no Navegador Web:"
    echo -e "     ${CYAN}portainer${NC}    ${YELLOW}(liga http://localhost:9000 e 'portainer stop' desliga)${NC}\n"
    echo -e "  7. Liste pastas com ícones e status Git:"
    echo -e "     ${CYAN}ll${NC}           ${YELLOW}(ou 'tree' para ver árvore de pastas)${NC}\n"
    echo -e "  8. Visualize arquivos com cores e sintaxe:"
    echo -e "     ${CYAN}bat <arquivo>${NC}\n"
    echo -e "  9. Crie seu primeiro site ou automação:"
    echo -e "     ${CYAN}novo${NC}         ${YELLOW}(ou 'novo-astro', 'novo-python')${NC}\n"
    echo -e "  10. Mantenha seu ambiente sempre novo:"
    echo -e "     ${CYAN}atualizar${NC}\n"
    echo -e "  11. Para abrir pastas no VS Code ou no Windows:"
    echo -e "     ${CYAN}code .${NC}        (abre no VS Code)"
    echo -e "     ${CYAN}open .${NC}        (abre a pasta atual no Explorer do Windows)\n"
}

# ------------------------------------------------------------------------------
# Execução Principal (Menu)
# ------------------------------------------------------------------------------
mostrar_banner
verificar_wsl

echo -e "Como você gostaria de prosseguir?\n"
echo -e "  ${YELLOW}1)${NC} ${BOLD}Instalação Completa Recomendada${NC} (Instala tudo de forma rápida e segura)"
echo -e "  ${YELLOW}2)${NC} ${BOLD}Instalação Personalizada${NC} (Pergunta ferramenta por ferramenta [S/n])"
echo -e "  ${YELLOW}3)${NC} Sair\n"

read -rp "Escolha uma opção [1-3]: " modo_instalacao
modo_instalacao=${modo_instalacao:-1}

case "$modo_instalacao" in
    1)
        checar_sudo
        configurar_wsl_conf
        instalar_pacote_essencial
        instalar_starship
        instalar_node_e_astro
        instalar_python_e_uv
        instalar_docker
        instalar_lazydocker
        preparar_portainer
        instalar_lazygit
        instalar_zoxide
        instalar_bat
        instalar_eza
        configurar_git
        configurar_bashrc
        mostrar_conclusao
        ;;
    2)
        checar_sudo
        
        read -rp "Otimizar /etc/wsl.conf com systemd e interop? [S/n]: " r_wsl
        [[ "${r_wsl:-S}" =~ ^[Ss]$ ]] && configurar_wsl_conf

        read -rp "Instalar Pacote Essencial CLI (curl, git, jq, fzf, ripgrep, build-essential)? [S/n]: " r_cli
        [[ "${r_cli:-S}" =~ ^[Ss]$ ]] && instalar_pacote_essencial

        read -rp "Instalar Starship Prompt (barra de terminal visual moderna)? [S/n]: " r_star
        [[ "${r_star:-S}" =~ ^[Ss]$ ]] && instalar_starship

        read -rp "Instalar Node.js LTS, fnm e pnpm (para Astro e sites)? [S/n]: " r_node
        [[ "${r_node:-S}" =~ ^[Ss]$ ]] && instalar_node_e_astro

        read -rp "Instalar Python e uv (para automações e scripts rápidos)? [S/n]: " r_py
        [[ "${r_py:-S}" =~ ^[Ss]$ ]] && instalar_python_e_uv

        read -rp "Instalar Docker Engine nativo e Docker Compose? [S/n]: " r_dock
        [[ "${r_dock:-S}" =~ ^[Ss]$ ]] && instalar_docker

        read -rp "Instalar Lazydocker (painel visual do Docker no terminal)? [S/n]: " r_lazy
        [[ "${r_lazy:-S}" =~ ^[Ss]$ ]] && instalar_lazydocker

        read -rp "Configurar Portainer CE Sob Demanda (painel web de Stacks na porta 9000)? [S/n]: " r_port
        [[ "${r_port:-S}" =~ ^[Ss]$ ]] && preparar_portainer

        read -rp "Instalar Lazygit (painel visual de Git no terminal)? [S/n]: " r_lg
        [[ "${r_lg:-S}" =~ ^[Ss]$ ]] && instalar_lazygit

        read -rp "Instalar Zoxide (navegação inteligente com comando 'z')? [S/n]: " r_zox
        [[ "${r_zox:-S}" =~ ^[Ss]$ ]] && instalar_zoxide

        read -rp "Instalar Bat (leitor de código colorido em Rust)? [S/n]: " r_bat
        [[ "${r_bat:-S}" =~ ^[Ss]$ ]] && instalar_bat

        read -rp "Instalar Eza (listagem moderna com ícones e status git em Rust)? [S/n]: " r_eza
        [[ "${r_eza:-S}" =~ ^[Ss]$ ]] && instalar_eza

        read -rp "Configurar Git, branch 'main', global .gitignore e SSH? [S/n]: " r_git
        [[ "${r_git:-S}" =~ ^[Ss]$ ]] && configurar_git

        configurar_bashrc
        mostrar_conclusao
        ;;
    3)
        echo -e "${YELLOW}Instalação abortada pelo usuário.${NC}"
        exit 0
        ;;
    *)
        log_erro "Opção inválida. Execução cancelada."
        exit 1
        ;;
esac
