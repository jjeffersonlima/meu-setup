#!/usr/bin/env bash
# ==============================================================================
# meu-setup: lib/conclusao.sh
# Módulo de auditoria de encerramento, diagnóstico final e guia rápido.
# ==============================================================================

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
