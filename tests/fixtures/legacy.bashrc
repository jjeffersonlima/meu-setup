# >>> meu-setup >>>
# Caminho para utilitários locais do usuário
export PATH="$HOME/.local/bin:$PATH"

# fnm (Fast Node Manager)
if [ -d "$HOME/.local/share/fnm" ]; then
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env --use-on-cd 2>/dev/null)"
fi

# uv (Python package manager)
if [ -d "$HOME/.local/bin" ] && [ -f "$HOME/.local/bin/uv" ]; then
    eval "$(uv generate-shell-completion bash 2>/dev/null)"
fi

# Starship Prompt
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

# Aliases úteis para o dia a dia
alias ll='ls -lah --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias update='sudo apt update && sudo apt upgrade -y'
alias ports='netstat -tulanp 2>/dev/null || ss -tulanp'
alias myip='hostname -I | awk "{print \$1}"'
alias open='explorer.exe 2>/dev/null || xdg-open'
alias code='code 2>/dev/null || true'

# Aliases para projetos e sites
alias novo='novo-projeto'
alias novo-astro='pnpm create astro@latest'
alias novo-python='novo-projeto'
# <<< meu-setup <<<
