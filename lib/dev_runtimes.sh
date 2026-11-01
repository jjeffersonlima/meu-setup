#!/usr/bin/env bash
# ==============================================================================
# meu-setup: lib/dev_runtimes.sh
# Módulo de instalação dos ambientes de execução: Node.js (fnm/pnpm) e Python (uv).
# ==============================================================================

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
        elif command -v npm >/dev/null 2>&1; then
            npm install -g pnpm
        else
            log_aviso "npm não disponível para instalar pnpm diretamente nesta etapa."
        fi
        if command -v pnpm >/dev/null 2>&1; then
            log_sucesso "pnpm instalado com sucesso!"
        fi
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
        local sudo_cmd=""
        [ "$EUID" -ne 0 ] && sudo_cmd="sudo"
        $sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y python3-venv python3-pip
    else
        log_pulado "python3-venv já está instalado no sistema."
    fi

    # Instalar uv (ferramenta moderna em Rust da Astral, substitui pip/pyenv com 100x mais velocidade)
    if command -v uv >/dev/null 2>&1 || [ -f "$HOME/.cargo/bin/uv" ] || [ -f "$DIR_LOCAL_BIN/uv" ]; then
        log_pulado "uv já está instalado ($("$DIR_LOCAL_BIN/uv" --version 2>/dev/null || uv --version 2>/dev/null || echo 'uv'))"
    else
        log_info "Instalando uv (o gerenciador de Python e pacotes mais rápido do mundo)..."
        mkdir -p "$DIR_LOCAL_BIN"
        curl -LsSf https://astral.sh/uv/install.sh | env CARGO_HOME="" UV_INSTALL_DIR="$DIR_LOCAL_BIN" sh
        log_sucesso "uv instalado em $DIR_LOCAL_BIN/uv!"
    fi
}
