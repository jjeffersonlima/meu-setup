#!/usr/bin/env python3
"""Guia de atualização: somente lê a seleção e imprime instruções."""
import os
from pathlib import Path
import shlex
import shutil

import config


def show(label, *instructions):
    print(f'\n{label}')
    for line in instructions:
        print(f'  {line}')


def main():
    selected = os.environ.get('SETUP_COMPONENTS')
    components = config.infer_components() if selected is None else config.parse_components(selected)
    repo = shlex.quote(str(config.REPO))
    print('Guia de atualização — execute manualmente apenas os comandos que desejar.')
    print('Nenhuma atualização foi consultada ou executada. Não é uma lista de versões novas.')
    show('Pacotes do Ubuntu/Debian (inclui ferramentas instaladas pelo APT)',
         'sudo apt update', 'sudo apt upgrade')
    show('Código do meu-setup', f'git -C {repo} status',
         'Se não houver alterações locais e a branch tiver upstream:',
         f'git -C {repo} pull --ff-only',
         'Para reparar o ambiente, em uma ação separada:',
         f'bash {repo}/install.sh --repair')
    if 'node' in components:
        show('Node e pnpm', 'fnm list', 'fnm install --lts',
             'Escolha o padrão com: fnm default <VERSAO_INSTALADA>',
             'npm install --global pnpm@latest',
             'fnm: https://github.com/Schniz/fnm#installation')
    if 'python' in components:
        show('Python / uv', 'uv self update',
             'As versões Python e as dependências de cada projeto são mantidas pelo próprio projeto.')
    releases = {
        'starship': 'starship/starship', 'lazygit': 'jesseduffield/lazygit',
        'lazydocker': 'jesseduffield/lazydocker', 'zoxide': 'ajeetdsouza/zoxide',
        'bat': 'sharkdp/bat', 'eza': 'eza-community/eza',
    }
    for name, repository in releases.items():
        if name in components:
            show(name, 'Para instalações por binário, siga as instruções da release oficial:',
                 f'https://github.com/{repository}/releases/latest',
                 'Se instalou por outro gerenciador, use esse mesmo gerenciador.')
    if 'docker' in components:
        show('Docker e Compose', 'Instalados pelo APT: use os comandos de pacotes acima.',
             'Se usa Docker Desktop, utilize a atualização no aplicativo do Windows.')
    if 'portainer' in components:
        show('Portainer', 'portainer status',
             'Siga o procedimento compatível com sua versão e volume de dados:',
             'https://docs.portainer.io/start/upgrade')
    if 'codex' in components:
        show('Codex — instalação nativa, sem npm',
             'curl -fsSL https://chatgpt.com/codex/install.sh | sh',
             'Instalador oficial também disponível em:',
             'https://github.com/openai/codex/blob/main/scripts/install/install.sh')
    if 'claude' in components:
        show('Claude Code', 'A instalação nativa possui atualização automática.',
             'Para atualizar manualmente: claude update',
             'Se instalou por APT ou outro gerenciador, atualize por ele.')
    if 'opencode' in components:
        show('OpenCode', 'opencode upgrade')
    if 'antigravity' in components:
        show('Antigravity CLI', 'O instalador oficial habilita a atualização própria durante o uso.',
             'https://antigravity.google/docs/getting-started?tab=cli')
    if 'skills' in components:
        prefix = config.HOME_DIR / '.local/share/meu-setup/npm'
        executable = shutil.which('skills')
        launcher = config.HOME_DIR / '.local/bin/skills'
        managed = executable and (Path(executable).is_relative_to(prefix) or
                  Path(executable) == launcher and launcher.is_file() and
                  '# meu-setup: CLI npm de IA' in launcher.read_text(errors='replace'))
        if managed:
            show('Vercel Skills — gerenciador',
                 f'npm install --global --prefix {shlex.quote(str(prefix))} skills@latest')
        else:
            show('Vercel Skills — gerenciador', 'Use o gerenciador e o prefixo da sua instalação.',
                 'https://github.com/vercel-labs/skills')
        show('Skills instaladas (separadas do gerenciador)', 'skills check',
             'skills update --help', 'Selecione o escopo global desejado.',
             'As skills do ai-memory são mantidas pelo próprio ai-memory.')
    if 'ai-memory' in components:
        show('ai-memory', 'ai-memory upgrade',
             'Se o serviço nativo de usuário estiver ativo, reinicie-o após atualizar:',
             'systemctl --user restart ai-memory.service', 'ai-memory status',
             'Backup é opcional, para preservar a possibilidade de voltar de versão:',
             'ai-memory backup --to "$HOME/ai-memory-backup-$(date +%Y%m%d-%H%M%S).tar.gz"')
    print('\nInstalações externas: mantenha o gerenciador original. Login e configurações permanecem com cada ferramenta.')


if __name__ == '__main__':
    main()
