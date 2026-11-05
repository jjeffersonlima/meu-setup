#!/usr/bin/env bash
# ==============================================================================
# meu-setup: install.sh
# Automação de ambiente de desenvolvimento moderna, leve e idempotente para WSL.
# Focado em: Automações, Sites (Astro), Aplicações e Sistemas.
# ==============================================================================

set -uo pipefail

DIR_SETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR_LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$DIR_LOCAL_BIN"

# Sistema de Logs de Instalação (Audit Trail)
LOG_DIR="$HOME/.local/state/meu-setup/logs"
mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR" 2>/dev/null || true
LOG_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/install_${LOG_TIMESTAMP}.log"
LOG_LATEST="$LOG_DIR/install_latest.log"

# Dual Logging: toda a saída é exibida no terminal e salva no log simultaneamente
if [ -z "${SETUP_LOGGING_ACTIVE:-}" ]; then
    export SETUP_LOGGING_ACTIVE=true
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE" 2>/dev/null || true
    exec > >(tee -a "$LOG_FILE") 2>&1
    ln -sf "$LOG_FILE" "$LOG_LATEST" 2>/dev/null || true
fi

# Carrega módulos da pasta lib/
for modulo in "$DIR_SETUP/lib/"*.sh; do
    if [ -f "$modulo" ]; then
        # shellcheck source=/dev/null
        source "$modulo"
    fi
done

mostrar_ajuda() {
    echo "Uso: ./install.sh [OPÇÕES]"
    echo ""
    echo "Opções:"
    echo "  -y, --yes, --non-interactive  Executa a instalação completa sem prompts interativos"
    echo "  -c, --custom                  Executa o modo de instalação personalizada [S/n]"
    echo "  -h, --help                    Exibe esta mensagem de ajuda"
    echo ""
    echo "Variáveis de Ambiente Úteis:"
    echo "  GIT_USER_NAME                 Nome para configuração global do Git"
    echo "  GIT_USER_EMAIL                E-mail para configuração global do Git"
    echo "  SETUP_GENERATE_SSH=true|false Controla geração automática de chave SSH Ed25519"
    echo "  GITHUB_TOKEN                  Token pessoal para contornar rate-limit da API do GitHub"
}

executar_instalacao_completa() {
    checar_sudo
    configurar_wsl_conf
    otimizar_wslconfig
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
}

executar_instalacao_personalizada() {
    checar_sudo
    
    local r_wsl r_wslcfg r_cli r_star r_node r_py r_dock r_lazy r_port r_lg r_zox r_bat r_eza r_git

    read -rp "Otimizar /etc/wsl.conf com systemd e interop? [S/n]: " r_wsl
    [[ "${r_wsl:-S}" =~ ^[Ss]$ ]] && configurar_wsl_conf

    read -rp "Otimizar Hipervisor WSL (.wslconfig no Windows para auto-liberação de RAM e disco)? [S/n]: " r_wslcfg
    [[ "${r_wslcfg:-S}" =~ ^[Ss]$ ]] && otimizar_wslconfig

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
}

main() {
    local modo=""

    # Processamento de argumentos de linha de comando
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes|--non-interactive)
                export SETUP_NON_INTERACTIVE=true
                modo="completo"
                shift
                ;;
            -c|--custom)
                modo="personalizado"
                shift
                ;;
            -h|--help)
                mostrar_ajuda
                exit 0
                ;;
            *)
                echo -e "${RED}Opção desconhecida: $1${NC}"
                mostrar_ajuda
                exit 1
                ;;
        esac
    done

    # Se estiver rodando sem terminal ou se a variável de ambiente pedir não-interativo
    if [ "${CI:-}" = "true" ] || [ "${DEBIAN_FRONTEND:-}" = "noninteractive" ] || [ ! -t 0 ]; then
        export SETUP_NON_INTERACTIVE=true
        [ -z "$modo" ] && modo="completo"
    fi

    mostrar_banner
    verificar_wsl

    if [ "$modo" = "completo" ]; then
        executar_instalacao_completa
        exit 0
    elif [ "$modo" = "personalizado" ]; then
        executar_instalacao_personalizada
        exit 0
    fi

    # Menu interativo padrão caso nenhum argumento tenha sido fornecido
    echo -e "Como você gostaria de prosseguir?\n"
    echo -e "  ${YELLOW}1)${NC} ${BOLD}Instalação Completa Recomendada${NC} (Instala tudo de forma rápida e segura)"
    echo -e "  ${YELLOW}2)${NC} ${BOLD}Instalação Personalizada${NC} (Pergunta ferramenta por ferramenta [S/n])"
    echo -e "  ${YELLOW}3)${NC} Sair\n"

    read -rp "Escolha uma opção [1-3]: " modo_instalacao
    modo_instalacao=${modo_instalacao:-1}

    case "$modo_instalacao" in
        1)
            executar_instalacao_completa
            ;;
        2)
            executar_instalacao_personalizada
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
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
