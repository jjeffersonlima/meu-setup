#!/usr/bin/env bash
# meu-setup: instalar e reparar um ambiente pessoal de desenvolvimento.
set -Eeuo pipefail
DIR_SETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$DIR_SETUP/lib/common.sh"
# shellcheck source=lib/log.sh
source "$DIR_SETUP/lib/log.sh"

mostrar_ajuda() {
    cat <<'EOF'
Uso: ./install.sh
Abre o menu: instalar tudo (padrão), escolher componentes, reparar ou sair.
  -y, --yes          Sem menu: mantém a seleção salva; no primeiro uso instala tudo
  --repair           Repara usando a seleção salva
  --help             Mostra esta ajuda
Para opções de automação e diagnóstico: ./install.sh --help-advanced
EOF
}

main() {
    local inventory=false components_set=false ai=false
    SETUP_ACTION=menu
    export SETUP_CONFIG_ONLY=false SETUP_USER_ONLY=false SETUP_NON_INTERACTIVE=false SETUP_UPDATE_TO_REFERENCE=false SETUP_DOCKER_BOOT=keep
    SETUP_COMPONENTS=""
    while (($#)); do
        case "$1" in
            -h|--help) mostrar_ajuda; return 0 ;;
            --help-advanced)
                mostrar_ajuda
                cat <<'ADVANCED'
Opções avançadas (não são necessárias no uso normal):
  --full              Seleciona todos os componentes, inclusive IA
  --components LISTA  Seleção explícita separada por vírgulas
  --config-only       Repara somente configuração, sem instalar ferramentas
  --user-only         Preserva arquivos WSL/Windows e containers existentes
  --inventory         Somente leitura: mostra o inventário
  --update-tools      Aplica versões de referência das ferramentas básicas
  --docker-boot MODO  keep (padrão), on ou off
Compatibilidade: --ai acrescenta IA; --custom abre a escolha por grupos.
ADVANCED
                return 0 ;;
            -y|--yes|--non-interactive) SETUP_NON_INTERACTIVE=true ;;
            --repair) SETUP_ACTION=repair ;;
            --full) SETUP_ACTION=full ;;
            --ai) ai=true; SETUP_ACTION=selected ;;
            --update-tools) export SETUP_UPDATE_TO_REFERENCE=true; SETUP_ACTION=selected ;;
            -c|--custom) SETUP_ACTION=custom ;;
            --config-only) SETUP_CONFIG_ONLY=true; SETUP_ACTION=selected ;;
            --user-only) SETUP_USER_ONLY=true ;;
            --inventory) inventory=true ;;
            --docker-boot)
                [ "$#" -ge 2 ] || { log_erro 'Informe keep, on ou off após --docker-boot.'; return 2; }
                case "$2" in keep|on|off) export SETUP_DOCKER_BOOT="$2" ;; *) log_erro 'Modo Docker inválido.'; return 2 ;; esac
                shift ;;
            --components)
                if [ "$#" -lt 2 ] || [[ "$2" == -* ]]; then log_erro 'Informe a lista após --components.'; return 2; fi
                SETUP_COMPONENTS="$2"; components_set=true; SETUP_ACTION=selected; shift ;;
            *) log_erro "Opção desconhecida: $1"; return 2 ;;
        esac
        shift
    done
    # O menu vem antes de Python, sudo, locks e logs: sair não altera arquivos.
    if [ "$inventory" = false ]; then
        if [ "$SETUP_ACTION" = custom ] || { [ "$SETUP_ACTION" = menu ] && [ "$SETUP_NON_INTERACTIVE" = false ]; }; then
            # shellcheck source=lib/menu.sh
            source "$DIR_SETUP/lib/menu.sh"
            setup_install_menu
            [ "$SETUP_ACTION" != exit ] || return 0
        fi
        if [ "$SETUP_ACTION" = repair ] && [ ! -f "$SETUP_STATE_DIR/state.json" ]; then
            log_erro 'Não há seleção salva. Execute ./install.sh para instalar.'; return 2
        fi
    fi
    if ! command -v python3 >/dev/null; then
        if [ "$inventory" = true ] || [ "$SETUP_CONFIG_ONLY" = true ]; then
            log_erro 'Python3 ausente. Execute a instalação completa para preparar o reparo.'; return 1
        fi
        log_info 'Preparando Python3 do sistema para a instalação...'
        setup_admin env DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=2 -o Acquire::http::Timeout=30 update
        setup_admin env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python3
        export SETUP_APT_UPDATED=true
    fi
    setup_environment
    if [ "$inventory" = true ]; then setup_python inventory; return; fi
    if [ "$SETUP_ACTION" = full ]; then
        SETUP_COMPONENTS=$(setup_python all-components)
    elif [ "$SETUP_ACTION" != custom ] && [ "$components_set" = false ]; then
        SETUP_COMPONENTS=$(setup_python components)
    fi
    if [ "$ai" = true ]; then
        SETUP_COMPONENTS="${SETUP_COMPONENTS:+$SETUP_COMPONENTS,}codex,claude,opencode,antigravity,skills,ai-memory"
    fi
    for component in ${SETUP_COMPONENTS//,/ }; do
        case "$component" in starship|node|python|docker|lazydocker|portainer|lazygit|zoxide|bat|eza|git|codex|claude|opencode|antigravity|skills|ai-memory) ;; *) log_erro "Componente desconhecido: $component"; return 2 ;; esac
    done
    if setup_selected lazydocker || setup_selected portainer; then
        setup_selected docker || SETUP_COMPONENTS="${SETUP_COMPONENTS:+$SETUP_COMPONENTS,}docker"
    fi
    if setup_selected skills; then
        setup_selected node || SETUP_COMPONENTS="${SETUP_COMPONENTS:+$SETUP_COMPONENTS,}node"
    fi
    SETUP_COMPONENTS=$(setup_python normalize --components "$SETUP_COMPONENTS")
    export SETUP_COMPONENTS
    setup_lock
    umask 077
    mkdir -p "$SETUP_STATE_DIR/logs"
    LOG_FILE="$SETUP_STATE_DIR/logs/install_$(date +%Y%m%d_%H%M%S)_$$.log"
    export LOG_FILE
    exec > >(tee "$LOG_FILE") 2>&1
    ln -sfn "$(basename "$LOG_FILE")" "$SETUP_STATE_DIR/logs/install_latest.log"
    # Mantém os 20 logs mais recentes; backups de recuperação não são removidos.
    setup_python inventory > "$SETUP_STATE_DIR/inventory.json"
    python3 - "$SETUP_STATE_DIR/logs" <<'PYLOG'
from pathlib import Path
import sys
for path in sorted(Path(sys.argv[1]).glob('install_[0-9]*.log'), key=lambda p: p.stat().st_mtime, reverse=True)[20:]:
    path.unlink()
PYLOG
    local status
    trap 'status=$?; trap - ERR; log_erro "Reparo interrompido (código $status). Consulte $LOG_FILE e execute novamente após corrigir a causa."; exit "$status"' ERR
    local module
    for module in system tools dev_runtimes docker git bashrc conclusao ai; do
        # shellcheck source=/dev/null
        source "$DIR_SETUP/lib/$module.sh"
    done
    mostrar_banner
    verificar_wsl
    if [ "$SETUP_CONFIG_ONLY" = false ]; then
        command -v apt-get >/dev/null || { log_erro 'A instalação de pacotes requer Ubuntu/Debian com APT.'; return 1; }
        instalar_pacote_essencial
        setup_selected starship && instalar_starship
        setup_selected node && instalar_node_e_astro
        setup_selected python && instalar_python_e_uv
        setup_selected docker && instalar_docker
        setup_selected lazydocker && instalar_lazydocker
        setup_selected lazygit && instalar_lazygit
        setup_selected zoxide && instalar_zoxide
        setup_selected bat && instalar_bat
        setup_selected eza && instalar_eza
        instalar_ferramentas_ia
    fi
    # As migrações rodam mesmo se todas as ferramentas já estiverem instaladas.
    configurar_bashrc
    setup_selected git && configurar_git
    if [ "$SETUP_USER_ONLY" = false ]; then configurar_wsl_conf; otimizar_wslconfig; fi
    configurar_memoria_ia
    setup_selected portainer && preparar_portainer
    mostrar_conclusao
    setup_python finalize --components "$SETUP_COMPONENTS"
    trap - ERR
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
