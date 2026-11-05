#!/usr/bin/env python3
"""Diagnóstico de leitura: executa verificações limitadas, sem sudo nem reparos."""
import argparse
import os
from pathlib import Path
import shutil
import re
import subprocess
import sys
import config


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config-only', action='store_true')
    parser.add_argument('--inventory', action='store_true')
    args = parser.parse_args()
    if args.inventory:
        import json
        print(json.dumps(config.inventory(), indent=2, ensure_ascii=False))
        return 0
    selected = os.environ.get('SETUP_COMPONENTS')
    components = config.infer_components() if selected is None else selected.split(',')
    failures, warnings = [], []
    docker_daemon_ready = False

    def row(name, status, detail):
        print(f'{name:<23} {status:<18} {detail}')
        if status == 'FALHOU':
            failures.append(name)
        if status == 'PENDENTE':
            warnings.append(name)

    print('Diagnóstico do meu-setup — nenhuma alteração será feita\n')
    bashrc = config.HOME_DIR / '.bashrc'
    text = bashrc.read_text() if bashrc.exists() else ''
    markers = [line.strip() for line in text.splitlines()]
    shell = config.HOME_DIR / '.config/meu-setup/shell.bash'
    if markers.count(config.START) == 1 and markers.count(config.END) == 1 and shell.is_file():
        try:
            config.shell_text(text)
            results = [subprocess.run(['bash', '-n', str(path)], capture_output=True, timeout=5) for path in (bashrc, shell)]
            if any(result.returncode for result in results):
                row('Configuração Bash', 'FALHOU', 'Sintaxe inválida; execute ./install.sh --repair.')
            elif shell.read_bytes() != (config.REPO / 'configs/shell.bash').read_bytes():
                row('Configuração Bash', 'FALHOU', 'Configuração antiga; execute ./install.sh --repair.')
            else:
                row('Configuração Bash', 'PRONTO', 'Um bloco ativo; configuração atual.')
        except (ValueError, subprocess.TimeoutExpired) as error:
            row('Configuração Bash', 'FALHOU', str(error))
    else:
        row('Configuração Bash', 'FALHOU', 'Execute ./install.sh --repair para corrigir blocos/arquivo gerenciado.')
    for name in ('novo-projeto', 'atualizar', 'diagnostico', 'portainer'):
        path = config.HOME_DIR / '.local/bin' / name
        expected = config.REPO / 'bin' / name
        if path.is_symlink() and path.resolve() == expected and os.access(path, os.X_OK):
            row(name, 'PRONTO', 'Atalho conectado ao repositório atual.')
        else:
            row(name, 'FALHOU', 'Atalho antigo/ausente; execute ./install.sh --repair.')
    if args.config_only:
        print(f'\nConfiguração: {len(failures)} falha(s). Ferramentas não verificadas neste modo.')
        return bool(failures)
    version_file = Path('/proc/version')
    is_wsl = not Path('/.dockerenv').exists() and not Path('/run/.containerenv').exists() and (
        bool(os.environ.get('WSL_DISTRO_NAME')) or version_file.exists() and 'microsoft' in version_file.read_text().lower())
    if is_wsl:
        init_name = Path('/proc/1/comm').read_text().strip()
        if init_name == 'systemd':
            row('WSL / systemd', 'PRONTO', 'Gerenciador de serviços em execução.')
        else:
            row('WSL / systemd', 'PENDENTE', 'Se já executou o reparo, salve o trabalho e rode wsl --shutdown no PowerShell; depois abra o WSL novamente.')
    for component in config.COMPONENTS:
        if component not in components:
            row(component, 'NÃO ESCOLHIDO', 'Opcional; não é uma falha.')
            continue
        commands = {'node': ('fnm', 'node', 'pnpm'), 'python': ('python3', 'uv'),
                    'git': ('git', 'gh'), 'portainer': ()}.get(component, (component,))
        if not commands:
            continue
        for command in commands:
            result = config.native_version(command)
            if result['working']:
                row(command, 'PRONTO', ' | '.join(result.get('version', [])))
            else:
                row(command, 'FALHOU', 'Não executou como ferramenta Linux. Execute ./install.sh --repair.')
    if 'docker' in components and shutil.which('docker'):
        compose = subprocess.run(['timeout', '10', 'docker', 'compose', 'version'], capture_output=True)
        row('Docker Compose', 'PRONTO' if compose.returncode == 0 else 'FALHOU',
            'Plugin v2 disponível.' if compose.returncode == 0 else 'Execute o reparo para instalar o Compose.')
        daemon = subprocess.run(['timeout', '10', 'docker', 'info'], capture_output=True)
        docker_daemon_ready = daemon.returncode == 0
        row('Serviço Docker', 'PRONTO' if daemon.returncode == 0 else 'PENDENTE',
            'Acessível nesta sessão.' if daemon.returncode == 0 else
            'Abra nova sessão se alterou o grupo; confira sudo systemctl start docker no WSL.')
    if 'portainer' in components:
        if docker_daemon_ready:
            import json
            result = subprocess.run(['timeout', '10', 'docker', 'inspect', 'portainer'], capture_output=True, text=True)
            if result.returncode:
                row('Painel Portainer', 'SOB DEMANDA', 'Será criado no primeiro uso: portainer.')
            else:
                try:
                    container = json.loads(result.stdout)[0]
                    args = container['Config'].get('Cmd') or []
                    data_mount = next((mount for mount in container.get('Mounts', []) if mount.get('Destination') == '/data'), {})
                    if data_mount.get('Name') != 'portainer_data':
                        row('Painel Portainer', 'PENDENTE', 'Armazenamento personalizado preservado; revise antes de reparar o painel.')
                    elif '--no-setup-token' in args:
                        row('Painel Portainer', 'PENDENTE', 'Configuração antiga; execute ./install.sh --repair para corrigir preservando dados.')
                    else:
                        state = 'em execução' if container['State']['Running'] else 'parado, sem iniciar no boot'
                        row('Painel Portainer', 'PRONTO', state + '; volume persistente conectado.')
                except (ValueError, KeyError, IndexError, TypeError):
                    row('Painel Portainer', 'PENDENTE', 'Não foi possível interpretar a configuração do container.')
        else:
            row('Painel Portainer', 'SOB DEMANDA', 'Script disponível; container não verificado enquanto o Docker estiver inacessível.')
    if 'node' in components and shutil.which('node'):
        result = config.native_version('node')
        match = re.search(r'(\d+)\.(\d+)\.(\d+)', ' '.join(result.get('version', [])))
        settings = dict(line.split('=', 1) for line in (config.REPO / 'configs/versions.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
        minimum = settings['NODE_MIN_VERSION']
        if not match or tuple(map(int, match.groups())) < tuple(map(int, minimum.split('.'))):
            row('Versão Node', 'FALHOU', f'Repare o Node; os templates requerem versão {minimum} ou mais recente.')
    if 'python' in components:
        completion = config.HOME_DIR / '.local/share/bash-completion/completions/uv'
        if not completion.is_file() or not completion.stat().st_size:
            row('Autocompletar uv', 'PENDENTE', 'Execute o reparo para gerar o arquivo.')
    print(f'\nResultado: {len(failures)} falha(s), {len(warnings)} pendência(s).')
    if warnings:
        print('As pendências acima precisam de atenção; não foram marcadas como sucesso.')
    return bool(failures)


if __name__ == '__main__':
    sys.exit(main())
