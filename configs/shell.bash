# Configuração gerenciada pelo meu-setup. Personalizações ficam no ~/.bashrc.
# Evita inicialização duplicada quando o arquivo for carregado novamente.
if [ "${MEU_SETUP_SHELL_LOADED:-}" = 2 ]; then return 0; fi
MEU_SETUP_SHELL_LOADED=2

# Limpa somente repetições destes caminhos administrados pelo setup.
_meu_setup_path() {
    local item rebuilt="" target="$1"
    local -a entries
    IFS=: read -r -a entries <<< "$PATH"
    for item in "${entries[@]}"; do
        [ "$item" = "$target" ] || rebuilt="${rebuilt:+$rebuilt:}$item"
    done
    export PATH="$target${rebuilt:+:$rebuilt}"
}
_meu_setup_path "$HOME/.local/bin"
if [ -x "$HOME/.local/share/fnm/fnm" ]; then _meu_setup_path "$HOME/.local/share/fnm"; fi
if command -v fnm >/dev/null 2>&1; then eval "$(fnm env --use-on-cd)"; fi
unset -f _meu_setup_path

if [ -s "$HOME/.local/share/bash-completion/completions/uv" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.local/share/bash-completion/completions/uv"
fi
if command -v zoxide >/dev/null 2>&1; then eval "$(zoxide init bash)"; fi
if command -v starship >/dev/null 2>&1; then eval "$(starship init bash)"; fi

# Remove aliases históricos antes de definir funções que recebem argumentos.
unalias ll tree open code ports bat novo-python 2>/dev/null || true
ll() { if command -v eza >/dev/null 2>&1; then command eza -la --icons --git --group-directories-first "$@"; else command ls -lah --color=auto "$@"; fi; }
tree() { if command -v eza >/dev/null 2>&1; then command eza --tree --icons "$@"; else command tree "$@"; fi; }
open() {
    if command -v explorer.exe >/dev/null 2>&1; then
        local target="${1:-.}"
        if command -v wslpath >/dev/null 2>&1 && [ -e "$target" ]; then target=$(wslpath -w "$(realpath "$target")"); fi
        command explorer.exe "$target"
    else command xdg-open "${1:-.}"; fi
}
code() { command code "$@"; }
ports() { command ss -tulanp "$@"; }
novo-python() { command novo-projeto python "$@"; }
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
    bat() { command batcat "$@"; }
fi
alias ..='cd ..'
alias ...='cd ../..'
alias myip='hostname -I'
alias update='atualizar'
alias doctor='diagnostico'
alias novo='novo-projeto'
alias novo-astro='novo-projeto astro'
alias lg='lazygit'
alias ld='lazydocker'
