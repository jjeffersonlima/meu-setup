#!/usr/bin/env python3
"""Perfil local de memória e launchers do setup; nunca lê credenciais."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys

import config


def memory_dir():
    return Path(os.environ.get('AI_MEMORY_DATA_DIR',
                str(Path(os.environ.get('XDG_DATA_HOME', config.HOME_DIR / '.local/share')) / 'ai-memory')))


def check_memory(path):
    try:
        import tomllib
    except ImportError as error:
        raise ValueError('O perfil ai-memory requer Python 3.11 ou mais recente.') from error
    # Evita herdar endpoints/provedores não contemplados por este perfil.
    allowed_env = {'AI_MEMORY_DATA_DIR'}
    if any(k.startswith('AI_MEMORY_') and v and k not in allowed_env for k, v in os.environ.items()):
        raise ValueError('Há overrides AI_MEMORY_* ativos. Revise-os antes de aplicar o perfil de memória local.')
    data = tomllib.loads(path.read_text()) if path.exists() else {}
    if data.get('llm_provider') or data.get('llm_fallbacks') or data.get('llm'):
        raise ValueError('Provedor LLM existente preservado. Migre explicitamente para consolidação pelo agente antes de continuar.')
    if data.get('embedding_provider', 'local') != 'local':
        raise ValueError('Embeddings existentes preservados. Se desejar, configure embedding_provider = "local" no ai-memory.')
    bind = data.get('bind', '127.0.0.1:49374')
    if not bind.startswith('127.0.0.1:') or data.get('server_url') not in (None, '', 'http://' + bind):
        raise ValueError('Servidor ai-memory personalizado preservado. Este perfil exige servidor local em loopback.')
    return data


def prepare_memory():
    path = memory_dir() / 'config.toml'
    check_memory(path)
    if path.is_symlink():
        raise ValueError('Configuração ai-memory em link preservada; revise manualmente.')
    if not path.exists():
        # Não toma a porta de outro serviço; o operador pode escolher outra no TOML.
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 49374))
        # init deve criar o token antes de existir um TOML; setup preserva a
        # postura de autenticação de configurações preexistentes.
        result = subprocess.run(['ai-memory', 'init'], capture_output=True, timeout=60)
        if result.returncode or not path.is_file():
            raise ValueError('ai-memory init falhou; execute ai-memory init para ver o diagnóstico oficial.')
        data = check_memory(path)
        if 'embedding_provider' not in data:
            config.write_managed(path, b'embedding_provider = "local"\n' + path.read_bytes(), 0o600)
    else:
        config.backup(path)


def npm_launcher(name):
    if name != 'skills':
        raise ValueError('CLI npm desconhecida')
    path = config.HOME_DIR / '.local/bin' / name
    marker = '# meu-setup: CLI npm de IA'
    if path.is_symlink() or path.exists() and marker not in path.read_text():
        raise ValueError(f'Launcher personalizado preservado: {path}')
    script = f'''#!/usr/bin/env bash
{marker}
set -euo pipefail
runtime="$HOME/.local/share/fnm/aliases/default/bin/node"
if [ ! -x "$runtime" ]; then runtime=$(command -v node); fi
exec "$runtime" "$HOME/.local/share/meu-setup/npm/bin/{name}" "$@"
'''
    config.write_managed(path, script.encode(), 0o755)


def main():
    action = sys.argv[1]
    if action == 'prepare-memory':
        prepare_memory()
    elif action == 'check-memory':
        check_memory(memory_dir() / 'config.toml')
    elif action == 'npm-launcher':
        npm_launcher(sys.argv[2])
    elif action == 'legacy-codex':
        path = config.HOME_DIR / '.local/bin/codex'
        if not path.is_file() or path.is_symlink():
            return 1
        with path.open('rb') as stream:
            header = stream.read(1024)
        return 0 if (b'# meu-setup: CLI npm de IA' in header
                     and b'/.local/share/meu-setup/npm/bin/codex' in header) else 1
    else:
        raise ValueError('Ação desconhecida')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, json.JSONDecodeError) as error:
        print(f'IA: {error}', file=sys.stderr)
        sys.exit(1)
