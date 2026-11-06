#!/usr/bin/env bash
mostrar_conclusao() {
    if [ "${SETUP_CONFIG_ONLY:-false}" = true ]; then
        "$DIR_SETUP/bin/diagnostico" --config-only
        log_sucesso 'Configurações reparadas. Ferramentas e pacotes não foram instalados nesta execução.'
    else
        "$DIR_SETUP/bin/diagnostico"
        log_sucesso 'Instalação/reparo concluído; verificações selecionadas executadas.'
    fi
    echo "Log: $LOG_FILE"
    echo "Backups e inventário: $SETUP_STATE_DIR"
    echo 'Abra um terminal novo para carregar os atalhos corrigidos.'
    echo 'Comece com novo; verifique o ambiente com doctor; consulte os comandos de manutenção com atualizar.'
}
