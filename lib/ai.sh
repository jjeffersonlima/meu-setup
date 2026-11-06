#!/usr/bin/env bash
# Ferramentas globais por usuário. Não altera configurações de login.
setup_ai_state() { python3 -B "$DIR_SETUP/lib/ai_config.py" "$@"; }

setup_ai_command() {
    case "$1" in antigravity) echo agy ;; *) echo "$1" ;; esac
}

setup_ai_script() {
    local url="$1" script status=0
    shift
    script=$(mktemp "${TMPDIR:-/tmp}/meu-setup-ai.XXXXXXXX.sh") || return
    if setup_download "$url" "$script" && bash -n "$script"; then
        # Instaladores nativos podem consultar o terminal mesmo sem perguntas.
        # --foreground evita suspensão por SIGTTIN/SIGTTOU em um TTY real.
        timeout --foreground 600 bash "$script" "$@" || status=$?
    else status=1; fi
    rm -f "$script"
    return "$status"
}

setup_ai_npm() {
    local component="$1" version="$2" package prefix
    prefix="$SETUP_USER_HOME/.local/share/meu-setup/npm"
    case "$component" in skills) package=skills ;; *) return 2 ;; esac
    if ! setup_native npm || ! setup_node_compatible; then
        log_erro 'Repare o Node Linux antes de instalar IA.'; return 1
    fi
    # Prefixo explícito: não altera npmrc nem depende do diretório de uma versão fnm.
    timeout --foreground 300 npm install --global --prefix "$prefix" "$package@$version" --fetch-retries=2 --fetch-timeout=30000 || return
    setup_ai_state npm-launcher "$component" || return
    hash -r
    setup_native "$component" || return 1
}

setup_ai_install() {
    local component="$1" command path
    command=$(setup_ai_command "$component")
    if [ "$component" = codex ] && setup_ai_state legacy-codex; then
        setup_backup "$DIR_LOCAL_BIN/codex" >/dev/null || return
        setup_ai_codex_install || return
    fi
    if setup_native "$command"; then
        log_pulado "$command Linux preservado."
        return 0
    fi
    # Um arquivo desconhecido ou instalação inválida exige revisão, não substituição.
    path=$(command -v "$command" || true)
    if [ -n "$path" ] || [ -e "$DIR_LOCAL_BIN/$command" ] || [ -L "$DIR_LOCAL_BIN/$command" ]; then
        log_erro "$command existente não executou como ferramenta Linux; revise seu PATH/instalação."
        return 1
    fi
    case "$component" in
        codex) setup_ai_codex_install || return ;;
        skills) setup_ai_npm skills "$SKILLS_VERSION" || return ;;
        claude) setup_ai_script https://claude.ai/install.sh stable || return ;;
        opencode) setup_ai_script https://opencode.ai/install --no-modify-path || return ;;
        antigravity) setup_ai_script https://antigravity.google/cli/install.sh --dir "$DIR_LOCAL_BIN" || return ;;
        ai-memory)
            setup_ai_memory_install || return ;;
    esac
    hash -r
    setup_native "$command" || { log_erro "$command não ficou disponível no Linux."; return 1; }
}

setup_ai_codex_install() {
    # Mesmo instalador standalone oficial, fixado ao tag de referência. Inclui
    # os auxiliares do Codex; não exige npm nem Node e não inicia uma sessão.
    CODEX_NON_INTERACTIVE=true CODEX_INSTALL_DIR="$DIR_LOCAL_BIN" \
        setup_ai_script "https://raw.githubusercontent.com/openai/codex/rust-v$CODEX_VERSION/scripts/install/install.sh" --release "$CODEX_VERSION"
}

setup_ai_memory_install() {
    local stage status=0 base
    stage=$(mktemp -d "${TMPDIR:-/tmp}/meu-setup-memory.XXXXXXXX") || return
    base="https://github.com/akitaonrails/ai-memory/releases/download/v$AI_MEMORY_VERSION"
    if setup_download "$base/install.sh" "$stage/install.sh" && setup_download "$base/install.sh.sha256" "$stage/install.sh.sha256"; then
        # Leitura estrita do checksum; não aceita nomes de arquivo vindos da rede.
        if python3 - "$stage" <<'PY'
import hashlib, pathlib, re, sys
p = pathlib.Path(sys.argv[1])
match = re.fullmatch(r'([a-fA-F0-9]{64})\s+\*?(?:\./)?install\.sh\s*', (p/'install.sh.sha256').read_text())
sys.exit(0 if match and hashlib.sha256((p/'install.sh').read_bytes()).hexdigest() == match[1].lower() else 1)
PY
        then
            bash -n "$stage/install.sh" && AI_MEMORY_VERSION="$AI_MEMORY_VERSION" timeout --foreground 600 bash "$stage/install.sh" || status=$?
        else status=1; fi
    else status=1; fi
    rm -rf "$stage"
    return "$status"
}

instalar_ferramentas_ia() {
    local component failures=0
    for component in codex claude opencode antigravity skills ai-memory; do
        setup_selected "$component" || continue
        if [ "$SETUP_USER_HOME" != "$HOME" ]; then
            log_erro 'Instaladores de IA exigem SETUP_HOME igual ao HOME do usuário atual.'
            return 1
        fi
        # As funções propagam falhas explicitamente para o resumo.
        if ! (set -e; setup_ai_install "$component"); then
            log_erro "Falha ao instalar $component."; failures=$((failures + 1))
        fi
    done
    [ "$failures" -eq 0 ] || { log_erro "$failures ferramenta(s) de IA com falha; execute novamente após corrigir."; return 1; }
}

configurar_memoria_ia() {
    setup_selected ai-memory || return 0
    if ! setup_native ai-memory; then
        log_erro 'ai-memory ausente; --config-only não instala ferramentas.'; return 1
    fi
    local component agent
    local -a agents=()
    for component in codex claude opencode antigravity; do
        setup_selected "$component" || continue
        case "$component" in claude) agent=claude-code ;; antigravity) agent=antigravity-cli ;; *) agent="$component" ;; esac
        agents+=(--agent "$agent")
    done
    if [ "${#agents[@]}" -eq 0 ]; then
        log_erro 'Selecione pelo menos uma CLI com ai-memory; a configuração não detectará outros agentes automaticamente.'
        return 1
    fi
    setup_ai_state prepare-memory || return
    if ! timeout 10 systemctl --user show-environment >/dev/null 2>&1; then
        log_aviso 'PENDENTE: serviço de usuário indisponível. Após habilitar systemd/reiniciar o WSL, escolha Reparar no menu para concluir ai-memory.'
        return 0
    fi
    # O instalador oficial preserva entradas alheias e instala skills globais.
    timeout --foreground 300 ai-memory setup --yes "${agents[@]}" || return
    timeout 30 ai-memory status || return
    log_info 'Reinicie os agentes. No Codex, confira /hooks e conceda a confiança solicitada. Login e confiança permanecem ações do usuário.'
}
