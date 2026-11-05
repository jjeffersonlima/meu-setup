#!/usr/bin/env bash
# Sistema e configurações WSL. Falhas de instalação são propagadas.
verificar_wsl() {
    if setup_is_wsl; then
        log_info "WSL detectado: ${WSL_DISTRO_NAME:-Linux}."
    else log_info 'Linux/container: configurações exclusivas do WSL serão ignoradas.'; fi
}
checar_sudo() {
    command -v apt-get >/dev/null || { log_erro 'Este instalador suporta distribuições Ubuntu/Debian com APT.'; return 1; }
    if [ "$EUID" -ne 0 ]; then
        if [ "${SETUP_NON_INTERACTIVE:-false}" = true ]; then sudo -n -v; else sudo -v; fi
    fi
}
executar_apt_update() {
    if [ "${SETUP_APT_UPDATED:-false}" != true ]; then
        setup_admin env DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=2 -o Acquire::http::Timeout=30 update || return $?
        SETUP_APT_UPDATED=true
    fi
}
instalar_pacote_essencial() {
    local pkg missing=()
    for pkg in curl git jq fzf ripgrep build-essential unzip ca-certificates python3 python3-venv; do
        if ! dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null | grep -qx installed; then missing+=("$pkg"); fi
    done
    if ((${#missing[@]})); then
        checar_sudo
        executar_apt_update
        setup_admin env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
    fi
}
setup_is_wsl() {
    [ ! -e /.dockerenv ] && [ ! -e /run/.containerenv ] && { grep -qi microsoft /proc/version || [ -n "${WSL_DISTRO_NAME:-}" ]; }
}
configurar_wsl_conf() {
    setup_is_wsl || return 0
    local target="${SETUP_WSL_CONF:-/etc/wsl.conf}" temp
    temp=$(mktemp)
    if ! setup_python ini "$target" --kind wsl --output "$temp"; then rm -f "$temp"; return 1; fi
    if ! cmp -s "$temp" "$target"; then
        setup_backup "$target" >/dev/null
        local staged
        staged=$(setup_admin mktemp "$(dirname "$target")/.meu-setup-wsl.XXXXXX")
        if ! setup_admin install -m 644 "$temp" "$staged" || ! setup_admin mv -f "$staged" "$target"; then
            setup_admin rm -f "$staged"; rm -f "$temp"; return 1
        fi
        log_aviso 'systemd configurado. Aplique reiniciando o WSL pelo Windows quando terminar seu trabalho.'
    fi
    rm -f "$temp"
}
otimizar_wslconfig() {
    setup_is_wsl || return 0
    local profile="${SETUP_WINDOWS_PROFILE:-}" raw temp target
    if [ -z "$profile" ] && command -v cmd.exe >/dev/null && command -v wslpath >/dev/null; then
        raw=$(timeout 10 cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r\n') || raw=""
        if [[ "$raw" =~ ^[A-Za-z]:\\ ]]; then profile=$(wslpath "$raw"); fi
    fi
    if [ -z "$profile" ] || [ ! -d "$profile" ]; then
        log_aviso 'Perfil Windows não identificado com segurança. .wslconfig preservado; configure SETUP_WINDOWS_PROFILE se necessário.'
        return 0
    fi
    target="$profile/.wslconfig"
    temp=$(mktemp)
    if ! setup_python ini "$target" --kind windows --output "$temp"; then rm -f "$temp"; return 1; fi
    if ! cmp -s "$temp" "$target"; then
        setup_backup "$target" >/dev/null
        # Gravação e substituição no mesmo filesystem do destino.
        if ! python3 - "$temp" "$target" <<'PYCONF'
import os, pathlib, sys, tempfile
source, target = map(pathlib.Path, sys.argv[1:])
fd, name = tempfile.mkstemp(prefix='.meu-setup-', dir=target.parent)
try:
    with os.fdopen(fd, 'wb') as stream:
        stream.write(source.read_bytes())
        stream.flush()
        os.fsync(stream.fileno())
    os.chmod(name, target.stat().st_mode & 0o777 if target.exists() else 0o600)
    os.replace(name, target)
finally:
    if os.path.exists(name): os.unlink(name)
PYCONF
        then rm -f "$temp"; return 1; fi
        log_aviso '.wslconfig reparado preservando seus limites e rede. Reinicie o WSL quando terminar.'
    fi
    rm -f "$temp"
}
