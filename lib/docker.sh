#!/usr/bin/env bash
instalar_docker() {
    if ! setup_native docker; then
        executar_apt_update
        setup_admin env DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io
    fi
    # Compose é verificado independentemente da presença do Docker CLI.
    if ! timeout 10 docker compose version >/dev/null 2>&1; then
        executar_apt_update
        if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
            setup_admin env DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-v2
        elif apt-cache show docker-compose-plugin >/dev/null 2>&1; then
            setup_admin env DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin
        else log_erro 'Compose v2 não está disponível nos repositórios configurados.'; return 1; fi
    fi
    local user_name="${SUDO_USER:-${USER:-$(id -un)}}"
    if ! getent group docker >/dev/null; then setup_admin groupadd docker; fi
    if ! id -nG "$user_name" | tr ' ' '\n' | grep -qx docker; then
        setup_admin usermod -aG docker "$user_name"
        log_aviso 'Abra uma nova sessão para carregar o grupo docker.'
    fi
    if [ "$(ps -p 1 -o comm=)" = systemd ]; then
        # Mantém o padrão existente. Inicialização no boot é uma escolha do usuário.
        case "${SETUP_DOCKER_BOOT:-keep}" in
            on) setup_admin systemctl enable docker ;;
            off) setup_admin systemctl disable docker ;;
            keep) : ;;
        esac
        if ! systemctl is-active --quiet docker; then setup_admin systemctl start docker; fi
    else log_aviso 'Docker instalado; serviço não iniciado (systemd ausente nesta sessão).'; fi
    timeout 10 docker compose version >/dev/null
}
preparar_portainer() {
    # Não liga um painel parado nem baixa imagens durante a instalação.
    if [ "${SETUP_USER_ONLY:-false}" = false ] && setup_native docker && timeout 10 docker info >/dev/null 2>&1; then
        "$DIR_SETUP/bin/portainer" repair
    else
        log_info 'Portainer sob demanda. Configuração do container será verificada quando houver acesso ao Docker.'
    fi
}
