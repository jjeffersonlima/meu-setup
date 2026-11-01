#!/usr/bin/env bash
# ==============================================================================
# meu-setup: lib/system.sh
# Módulo de verificação do sistema WSL, permissões sudo e pacotes básicos.
# ==============================================================================

# ------------------------------------------------------------------------------
# Detecção de Ambiente WSL
# ------------------------------------------------------------------------------
verificar_wsl() {
    log_secao "Verificando ambiente do sistema"
    if grep -qi "microsoft" /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
        log_sucesso "Detectado ambiente: ${BOLD}Linux sob WSL (${WSL_DISTRO_NAME:-Ubuntu})${NC}"
    else
        log_aviso "Aviso: Ambiente Linux nativo ou container detectado. O script funcionará normalmente!"
    fi
}

# ------------------------------------------------------------------------------
# Solicitar credenciais Sudo antecipadamente (apenas se necessário)
# ------------------------------------------------------------------------------
checar_sudo() {
    if [ "$EUID" -ne 0 ]; then
        log_info "Alguns pacotes do sistema precisam de privilégios de administrador (sudo)."
        if sudo -v 2>/dev/null; then
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
        local sudo_cmd=""
        if [ "$EUID" -ne 0 ]; then
            sudo_cmd="sudo"
        fi

        $sudo_cmd bash -c "cat >> $wsl_conf" << 'EOF'

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
        local sudo_cmd=""
        if [ "$EUID" -ne 0 ]; then
            sudo_cmd="sudo"
        fi
        $sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get update -y
        $sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pacotes_faltando[@]}"
        log_sucesso "Ferramentas essenciais instaladas com sucesso!"
    fi
}
