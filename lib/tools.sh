#!/usr/bin/env bash
# Releases explícitos; nenhum binário é substituído antes de ser executado com sucesso.
# shellcheck source=configs/versions.env
source "$DIR_SETUP/configs/versions.env"

setup_install_release() (
    set -euo pipefail
    local name="$1" repo="$2" asset="$4" tag="${5:-v$3}" temp candidate target staged
    temp=$(mktemp -d)
    trap 'rm -rf "$temp"; if [ -n "${staged:-}" ]; then rm -f "$staged"; fi' EXIT
    setup_download "https://github.com/$repo/releases/download/$tag/$asset" "$temp/archive"
    # Os digests de assets publicados pelo GitHub são consultados quando disponíveis.
    # Falha da API não vira falha do download HTTPS; nunca inventar uma validação.
    if setup_download "https://api.github.com/repos/$repo/releases/tags/$tag" "$temp/release.json"; then
        python3 - "$temp/release.json" "$asset" "$temp/archive" <<'PYHASH'
import hashlib, json, pathlib, sys
release, asset, archive = sys.argv[1:]
entry = next((a for a in json.loads(pathlib.Path(release).read_text()).get('assets', []) if a['name'] == asset), {})
digest = entry.get('digest') or ''
if digest.startswith('sha256:'):
    if hashlib.sha256(pathlib.Path(archive).read_bytes()).hexdigest() != digest.split(':', 1)[1]:
        raise SystemExit('Checksum do download não confere.')
else:
    print('AVISO: fornecedor não disponibilizou digest deste asset; download via HTTPS.', file=sys.stderr)
PYHASH
    else log_aviso "Metadados de checksum indisponíveis para $name; download via HTTPS."; fi
    mkdir "$temp/extract"
    if [[ "$asset" == *.zip ]]; then unzip -q "$temp/archive" -d "$temp/extract"
    else tar -xf "$temp/archive" -C "$temp/extract" --no-same-owner; fi
    candidate=$(find "$temp/extract" -type f -name "$name" -print -quit)
    [ -n "$candidate" ] || { log_erro "Release não contém $name."; exit 1; }
    chmod +x "$candidate"
    timeout 10 "$candidate" --version >/dev/null
    target="${6:-$DIR_LOCAL_BIN/$name}"
    setup_backup "$target" >/dev/null
    mkdir -p "$(dirname "$target")"
    staged=$(mktemp "$(dirname "$target")/.$name.XXXXXX")
    install -m 755 "$candidate" "$staged"
    mv -f "$staged" "$target"
    log_sucesso "$name instalado e executado com sucesso."
)
setup_arch() {
    case "$(uname -m)" in x86_64) echo x86_64 ;; aarch64|arm64) echo aarch64 ;; *) log_erro 'Arquitetura não suportada.' >&2; return 1 ;; esac
}
instalar_starship() {
    if setup_reuse_tool starship "$STARSHIP_VERSION"; then log_pulado 'Starship funcional.'; return; fi
    local arch; arch=$(setup_arch)
    setup_install_release starship starship/starship "$STARSHIP_VERSION" "starship-$arch-unknown-linux-musl.tar.gz"
}
instalar_lazydocker() {
    if setup_reuse_tool lazydocker "$LAZYDOCKER_VERSION"; then log_pulado 'Lazydocker funcional.'; return; fi
    local arch; arch=$(setup_arch); [ "$arch" != aarch64 ] || arch=arm64
    setup_install_release lazydocker jesseduffield/lazydocker "$LAZYDOCKER_VERSION" "lazydocker_${LAZYDOCKER_VERSION}_Linux_$arch.tar.gz"
}
instalar_lazygit() {
    if setup_reuse_tool lazygit "$LAZYGIT_VERSION"; then log_pulado 'Lazygit funcional.'; return; fi
    local arch; arch=$(setup_arch); [ "$arch" != aarch64 ] || arch=arm64
    setup_install_release lazygit jesseduffield/lazygit "$LAZYGIT_VERSION" "lazygit_${LAZYGIT_VERSION}_linux_$arch.tar.gz"
}
instalar_zoxide() {
    if setup_reuse_tool zoxide "$ZOXIDE_VERSION"; then log_pulado 'Zoxide funcional.'; return; fi
    local arch; arch=$(setup_arch)
    setup_install_release zoxide ajeetdsouza/zoxide "$ZOXIDE_VERSION" "zoxide-${ZOXIDE_VERSION}-$arch-unknown-linux-musl.tar.gz"
}
instalar_bat() {
    if setup_reuse_tool bat "$BAT_VERSION"; then log_pulado 'Bat funcional.'; return; fi
    local arch; arch=$(setup_arch)
    setup_install_release bat sharkdp/bat "$BAT_VERSION" "bat-v${BAT_VERSION}-$arch-unknown-linux-musl.tar.gz"
}
instalar_eza() {
    if setup_reuse_tool eza "$EZA_VERSION"; then log_pulado 'Eza funcional.'; return; fi
    local arch; arch=$(setup_arch)
    setup_install_release eza eza-community/eza "$EZA_VERSION" "eza_$arch-unknown-linux-gnu.tar.gz"
}
