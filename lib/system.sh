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
            # Mantém o token do sudo vivo durante a execução e registra PID para encerramento limpo
            ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null ) &
            SETUP_SUDO_PID=$!
            trap 'kill $SETUP_SUDO_PID 2>/dev/null || true' EXIT INT TERM
        else
            log_erro "Não foi possível obter permissões de sudo. Algumas etapas podem falhar."
        fi
    fi
}

# ------------------------------------------------------------------------------
# Executar apt-get update uma única vez de forma compartilhada
# ------------------------------------------------------------------------------
executar_apt_update() {
    if [ "${SETUP_APT_UPDATED:-false}" != "true" ]; then
        log_info "Atualizando catálogo de pacotes do sistema (APT)..."
        local sudo_cmd=""
        [ "$EUID" -ne 0 ] && sudo_cmd="sudo"
        $sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get update -y
        export SETUP_APT_UPDATED=true
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
# 1.1 Configuração do Hipervisor WSL (.wslconfig no Windows - WSL 2 e WSL 3)
# ------------------------------------------------------------------------------
otimizar_wslconfig() {
    log_secao "1.1 Otimização do Hipervisor WSL (.wslconfig no Windows)"

    local win_user_profile=""
    local wslconfig_path=""

    if command -v cmd.exe >/dev/null 2>&1; then
        local raw_profile
        raw_profile=$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r\n' || true)
        if [ -n "$raw_profile" ] && command -v wslpath >/dev/null 2>&1; then
            win_user_profile=$(wslpath "$raw_profile" 2>/dev/null || true)
        fi
    fi

    # Fallback caso wslpath ou cmd.exe não responda diretamente
    if [ -z "$win_user_profile" ] && [ -d "/mnt/c/Users" ]; then
        for u in /mnt/c/Users/*; do
            local base
            base="$(basename "$u")"
            if [ -d "$u" ] && [ "$base" != "Public" ] && [ "$base" != "Default" ] && [ "$base" != "All Users" ] && [ "$base" != "Default User" ]; then
                win_user_profile="$u"
                break
            fi
        done
    fi

    if [ -z "$win_user_profile" ] || [ ! -d "$win_user_profile" ]; then
        log_pulado "Perfil do Windows não detectado (ambiente Linux nativo ou container). Pulando .wslconfig."
        return 0
    fi

    wslconfig_path="$win_user_profile/.wslconfig"
    local precisa_atualizar=false

    if [ ! -f "$wslconfig_path" ]; then
        precisa_atualizar=true
    elif ! grep -qi "\[experimental\]" "$wslconfig_path" 2>/dev/null || ! grep -qi "autoMemoryReclaim" "$wslconfig_path" 2>/dev/null; then
        precisa_atualizar=true
    fi

    if [ "$precisa_atualizar" = true ]; then
        log_info "Configurando .wslconfig em $wslconfig_path para alta performance..."

        if [ -f "$wslconfig_path" ]; then
            local backup_file
            backup_file="${wslconfig_path}.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$wslconfig_path" "$backup_file" 2>/dev/null || true
            log_info "Backup do .wslconfig anterior criado em: $(basename "$backup_file")"
        fi

        cat << 'EOF' > "$wslconfig_path"
# ==============================================================================
# Otimizações de Performance do WSL (WSL 2 e WSL 3) - meu-setup
# Documentação: https://learn.microsoft.com/windows/wsl/wsl-config
# ==============================================================================

[wsl2]
# Modo de rede espelhada de alto desempenho (latência mínima e loopback nativo)
networkingMode=mirrored

# Resolução de DNS tunelada para compatibilidade perfeita com VPNs
dnsTunneling=true

# Compartilhamento transparente de proxy do Windows
autoProxy=true

[experimental]
# Libera automaticamente a memória RAM ociosa de volta para o Windows
autoMemoryReclaim=gradual

# Compacta automaticamente o disco virtual ext4.vhdx após limpezas (Docker/npm/uv)
sparseVhd=true
EOF
        log_sucesso "Arquivo .wslconfig configurado com autoMemoryReclaim, sparseVhd e mirrored networking!"
        log_aviso "Lembrete: Para aplicar no Windows, execute no PowerShell: wsl --shutdown"
    else
        log_pulado "Otimizações de performance (RAM reclaim e sparseVhd) já estão ativas em .wslconfig"
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
        executar_apt_update
        local sudo_cmd=""
        if [ "$EUID" -ne 0 ]; then
            sudo_cmd="sudo"
        fi
        $sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pacotes_faltando[@]}"
        log_sucesso "Ferramentas essenciais instaladas com sucesso!"
    fi
}
