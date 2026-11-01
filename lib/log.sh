#!/usr/bin/env bash
# ==============================================================================
# meu-setup: lib/log.sh
# Módulo de formatação de mensagens, cores e banners do terminal.
# ==============================================================================

# Paleta de cores para mensagens
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

mostrar_banner() {
    # Limpa apenas se estiver em terminal interativo
    if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
        clear 2>/dev/null || true
    fi
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
