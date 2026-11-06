#!/usr/bin/env bash
# Apenas escolhe a ação. Não instala dependências nem altera arquivos.
setup_custom_menu() {
    local reply group picked valid
    local -a groups
    while true; do
        cat <<'EOF'

Escolha por finalidade:
  1. Terminal e navegação (Starship, Zoxide, Bat, Eza)
  2. Git e GitHub (Git, GitHub CLI, Lazygit)
  3. Sites e aplicativos (Node, fnm, pnpm)
  4. Automações Python (Python, uv)
  5. Containers e painéis (Docker, Compose, Lazydocker, Portainer)
  6. Agentes de IA, skills e memória local
  0. Voltar

Digite os números separados por espaço. Enter seleciona todos.
EOF
        if ! read -rp 'Grupos [1 2 3 4 5 6]: ' reply; then SETUP_ACTION='exit'; return 0; fi
        reply="${reply:-1 2 3 4 5 6}"
        if [ "$reply" = 0 ]; then SETUP_ACTION=menu; return 0; fi
        IFS=' ,' read -r -a groups <<< "$reply"
        picked="" valid=true
        [ "${#groups[@]}" -gt 0 ] || valid=false
        for group in "${groups[@]}"; do
            case "$group" in
                1) picked+=',starship,zoxide,bat,eza' ;;
                2) picked+=',git,lazygit' ;;
                3) picked+=',node' ;;
                4) picked+=',python' ;;
                5) picked+=',docker,lazydocker,portainer' ;;
                6) picked+=',codex,claude,opencode,antigravity,skills,ai-memory' ;;
                *) valid=false ;;
            esac
        done
        if [ "$valid" = true ]; then
            export SETUP_COMPONENTS="${picked#,}"; SETUP_ACTION=custom; return 0
        fi
        echo 'Escolha somente os números de 1 a 6, ou 0 para voltar.'
    done
}

setup_install_menu() {
    local reply
    if [ ! -t 0 ]; then
        echo 'Abra um terminal para escolher. Para automação, use --yes ou --components LISTA.' >&2
        return 2
    fi
    while true; do
        if [ "$SETUP_ACTION" = custom ]; then
            setup_custom_menu
            [ "$SETUP_ACTION" = menu ] || return 0
        fi
        cat <<'EOF'

meu-setup
  1. Instalar tudo — padrão (inclui agentes de IA e memória local)
  2. Escolher o que instalar
  3. Reparar a instalação existente
  0. Sair

Instalação e reparo preservam projetos e dados pessoais.
EOF
        if ! read -rp 'Escolha [1]: ' reply; then SETUP_ACTION='exit'; return 0; fi
        case "${reply:-1}" in
            1) SETUP_ACTION=full; return 0 ;;
            2) SETUP_ACTION=custom ;;
            3)
                if [ -f "$SETUP_STATE_DIR/state.json" ]; then SETUP_ACTION=repair; return 0; fi
                echo 'Não há seleção salva para reparar. Escolha instalar tudo ou escolher os componentes.' ;;
            0) SETUP_ACTION='exit'; return 0 ;;
            *) echo 'Escolha 1, 2, 3 ou 0.' ;;
        esac
    done
}
