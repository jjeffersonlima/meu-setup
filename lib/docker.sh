#!/usr/bin/env bash
# ==============================================================================
# meu-setup: lib/docker.sh
# Módulo de instalação do Docker Engine nativo, Docker Compose e Portainer CE.
# ==============================================================================

# ------------------------------------------------------------------------------
# 6. Docker Nativo (Docker Engine + Compose via systemd)
# ------------------------------------------------------------------------------
instalar_docker() {
    log_secao "6. Docker Engine Nativo & Docker Compose"

    local sudo_cmd=""
    [ "$EUID" -ne 0 ] && sudo_cmd="sudo"

    if command -v docker >/dev/null 2>&1; then
        log_pulado "Docker já está instalado ($(docker --version))"
    else
        log_info "Instalando Docker Engine nativo no WSL..."
        $sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get update -y
        # No repositório oficial do Ubuntu o plugin se chama docker-compose-v2; no repo externo se chama docker-compose-plugin
        if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
            $sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-v2
        elif apt-cache show docker-compose-plugin >/dev/null 2>&1; then
            $sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-plugin
        else
            $sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io
        fi
        log_sucesso "Docker Engine instalado!"
    fi

    # Adicionar usuário atual ao grupo docker (para não precisar usar 'sudo docker')
    if groups "${USER:-$(whoami)}" 2>/dev/null | grep -q "\bdocker\b"; then
        log_pulado "Usuário '${USER:-$(whoami)}' já está no grupo 'docker'."
    else
        log_info "Adicionando o usuário '${USER:-$(whoami)}' ao grupo docker..."
        $sudo_cmd usermod -aG docker "${USER:-$(whoami)}" 2>/dev/null || true
        log_sucesso "Usuário adicionado ao grupo docker! (Faça logout/login ou use 'newgrp docker')"
    fi

    # Habilitar e iniciar serviço docker via systemd se disponível
    if command -v systemctl >/dev/null 2>&1; then
        if $sudo_cmd systemctl is-active --quiet docker 2>/dev/null; then
            log_pulado "Serviço Docker já está em execução."
        else
            log_info "Iniciando e habilitando serviço Docker no systemd..."
            $sudo_cmd systemctl enable --now docker 2>/dev/null || true
            # Aguarda a inicialização do socket do Docker (até 5 segundos)
            for _ in {1..5}; do
                if $sudo_cmd docker info >/dev/null 2>&1; then
                    break
                fi
                sleep 1
            done
            if $sudo_cmd docker info >/dev/null 2>&1; then
                log_sucesso "Serviço Docker iniciado!"
            else
                log_aviso "Docker instalado. Se o daemon não iniciou, certifique-se de que o systemd está ativo."
            fi
        fi
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

    if command -v docker >/dev/null 2>&1 && docker images --format '{{.Repository}}' 2>/dev/null | grep -Eq "portainer/portainer-ce"; then
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
