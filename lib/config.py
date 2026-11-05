#!/usr/bin/env python3
"""Migrações de configuração e backups, usando somente a biblioteca padrão."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parent.parent
HOME_DIR = Path(os.environ.get('SETUP_HOME', Path.home())).absolute()
STATE = Path(os.environ.get('SETUP_STATE_DIR', HOME_DIR / '.local/state/meu-setup'))
START = '# >>> meu-setup >>>'
END = '# <<< meu-setup <<<'
COMPONENTS = ('starship', 'node', 'python', 'docker', 'lazydocker', 'portainer',
              'lazygit', 'zoxide', 'bat', 'eza', 'git')
COMMANDS = {'node': 'node', 'python': 'uv', 'git': 'git'}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def atomic(path, data, mode=0o600):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.' + path.name + '-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(name, mode)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def load(path, default):
    return json.loads(path.read_text()) if path.exists() else default


def json_write(path, value):
    atomic(path, (json.dumps(value, indent=2, ensure_ascii=False) + '\n').encode())


def backup(path):
    """Backup deduplicado por conteúdo, registrado ANTES de qualquer alteração."""
    path = Path(path).absolute()
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(STATE, 0o700)
    if path.is_symlink():
        entry = {'kind': 'symlink', 'target': os.readlink(path)}
    elif path.exists():
        if not path.is_file():
            raise ValueError(f'Não vou substituir um diretório: {path}')
        data = path.read_bytes()
        object_path = STATE / 'backups/objects' / digest(data)
        if not object_path.exists():
            atomic(object_path, data)
        if object_path.read_bytes() != data:
            raise ValueError(f'Falha ao verificar backup: {path}')
        entry = {'kind': 'file', 'object': str(object_path),
                 'sha256': digest(data), 'mode': stat.S_IMODE(path.stat().st_mode)}
    else:
        entry = {'kind': 'absent'}
    # Um histórico por caminho permite recuperação inclusive após instalação parcial.
    index_path = STATE / 'backups/index.json'
    index = load(index_path, {})
    entries = index.setdefault(str(path), [])
    if not entries or entries[-1] != entry:
        entries.append(entry)
        json_write(index_path, index)
    return entry


def write_managed(path, data, mode=0o644):
    path = Path(path)
    if path.is_symlink():
        raise ValueError(f'Configuração é um link personalizado; revise antes: {path}')
    if path.exists() and path.read_bytes() == data:
        return False
    old_mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else mode
    backup(path)
    atomic(path, data, old_mode)
    print(f'REPARADO: {path}')
    return True


def shell_text(text):
    """Remove somente blocos balanceados. Nunca apaga até EOF por marcador aberto."""
    output, block, depth = [], [], 0
    for line in text.splitlines(keepends=True):
        marker = line.strip()
        if marker == START:
            if depth:
                raise ValueError('Blocos meu-setup aninhados no .bashrc; revisão necessária.')
            depth = 1
            block = []
        elif marker == END:
            if not depth:
                raise ValueError('Marcador de fechamento sem abertura no .bashrc; revisão necessária.')
            depth = 0
        elif depth:
            block.append(line)
        else:
            output.append(line)
    if depth:
        raise ValueError('Bloco meu-setup incompleto no .bashrc. Conteúdo preservado; revise o marcador.')
    # Não reescrever aliases pessoais fora dos marcadores.
    outside = ''.join(output)
    conflict = re.search(r'^\s*(?:alias\s+(?:code|open|novo|novo-python)|(?:code|open)\s*\(\))', outside, re.M)
    if conflict:
        print('AVISO: atalhos pessoais fora do bloco foram preservados; confira conflitos no .bashrc.', file=sys.stderr)
    return outside.rstrip('\n') + '\n\n' + START + '\n' + (
        '[ -r "$HOME/.config/meu-setup/shell.bash" ] && source "$HOME/.config/meu-setup/shell.bash"\n'
    ) + END + '\n'


def ini_text(text, updates):
    """Consolida seções e chaves repetidas; preserva valores e comentários pessoais."""
    # Arquivos já corretos permanecem byte a byte iguais, inclusive sua formatação.
    seen_sections, seen_keys, effective = set(), set(), {}
    current, needs_change = '', False
    for line in text.splitlines():
        section_match = re.match(r'^\s*\[([^]]+)\]\s*(?:[#;].*)?$', line)
        if section_match:
            current = section_match[1].strip().lower()
            needs_change |= current in seen_sections
            seen_sections.add(current)
        else:
            key_match = re.match(r'^\s*([^#;=\s]+)\s*=(.*)$', line)
            if key_match:
                identity = (current, key_match[1].lower())
                needs_change |= identity in seen_keys
                seen_keys.add(identity)
                effective[identity] = key_match[2].split('#', 1)[0].split(';', 1)[0].strip()
    for section, changes in updates.items():
        for key, (value, replace) in changes.items():
            identity = (section, key)
            needs_change |= identity not in effective or replace and effective.get(identity) != value
    if not needs_change:
        return text
    sections = {'': []}
    current = ''
    for line in text.splitlines():
        match = re.match(r'^\s*\[([^]]+)\]\s*(?:[#;].*)?$', line)
        if match:
            current = match[1].strip().lower()
            sections.setdefault(current, [])
        else:
            sections[current].append(line)
    for section, changes in updates.items():
        lines = sections.setdefault(section, [])
        # Último valor efetivo é preservado para chaves que não administramos.
        last = {}
        for i, line in enumerate(lines):
            match = re.match(r'^\s*([^#;=\s]+)\s*=', line)
            if match:
                last[match[1].lower()] = i
        clean = []
        for i, line in enumerate(lines):
            match = re.match(r'^\s*([^#;=\s]+)\s*=', line)
            key = match[1].lower() if match else None
            if key and last[key] != i:
                continue
            if key in changes:
                value, replace = changes[key]
                clean.append(f'{key}={value}' if replace else line)
            else:
                clean.append(line)
        for key, (value, _) in changes.items():
            if key not in last:
                clean.append(f'{key}={value}')
        sections[section] = clean
    # Consolidar também chaves duplicadas em seções não alteradas.
    result = []
    for section, lines in sections.items():
        last = {}
        for i, line in enumerate(lines):
            match = re.match(r'^\s*([^#;=\s]+)\s*=', line)
            if match:
                last[match[1].lower()] = i
        filtered = []
        for i, line in enumerate(lines):
            match = re.match(r'^\s*([^#;=\s]+)\s*=', line)
            if not match or last[match[1].lower()] == i:
                filtered.append(line)
        if section:
            result.append(f'[{section}]')
        result.extend(filtered)
    return '\n'.join(result).strip() + '\n'


def parse_components(value):
    result = list(dict.fromkeys(filter(None, value.split(','))))
    unknown = set(result) - set(COMPONENTS)
    if unknown:
        raise ValueError('Componentes desconhecidos: ' + ', '.join(sorted(unknown)))
    return result


def infer_components():
    saved = load(STATE / 'state.json', {})
    if 'components' in saved:
        return saved['components']
    found = []
    for name in COMPONENTS:
        command = COMMANDS.get(name, name)
        candidates = [HOME_DIR / '.local/bin' / command]
        if name == 'node':
            candidates.append(HOME_DIR / '.local/share/fnm/fnm')
        if name == 'python':
            candidates.append(HOME_DIR / '.cargo/bin/uv')
        detected = shutil.which(command)
        if any(p.exists() for p in candidates) or (detected and not detected.startswith('/mnt/')):
            found.append(name)
    existing = (HOME_DIR / '.bashrc').exists() and START in (HOME_DIR / '.bashrc').read_text()
    return found if existing or saved else list(COMPONENTS)


def native_version(command):
    path = shutil.which(command)
    if path:
        path = os.path.realpath(path)
    if not path or path.startswith('/mnt/'):
        return {'path': path, 'working': False}
    try:
        result = subprocess.run([path, '--version'], capture_output=True, text=True, timeout=5)
        return {'path': path, 'working': result.returncode == 0,
                'version': result.stdout.splitlines()[:2]}
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {'path': path, 'working': False, 'error': str(exc)}


def inventory():
    return {'schema': 1, 'home': str(HOME_DIR), 'repository': str(REPO),
            'components': infer_components(),
            'tools': {name: native_version(name) for name in
                      ('git', 'node', 'pnpm', 'uv', 'docker', 'starship', 'fnm')},
            'managed_files': [str(HOME_DIR / p) for p in ('.bashrc', '.config/meu-setup/shell.bash',
                '.config/starship.toml', '.config/git/ignore')],
            'old_bashrc_backups': [str(p) for p in HOME_DIR.glob('.bashrc.backup.*')]}


def known_utility(path, name):
    if path.is_symlink():
        target = Path(os.path.abspath(path.parent / os.readlink(path)))
        return target == REPO / 'bin' / name or target.name == name and target.parent.name == 'bin' and (
            target.parent.parent.name == 'meu-setup' or target.exists() and 'meu-setup:' in target.read_text())
    if path.is_file():
        content = path.read_text(errors='replace')
        if 'meu-setup:' in content[:500]:
            return True
        # Assinaturas distribuídas com o setup: funciona também em clones rasos e cópias.
        signatures = load(REPO / 'configs/legacy-utilities.json', {})
        return digest(path.read_bytes()) in signatures.get(name, [])
    return False


def migrate(components):
    bashrc = HOME_DIR / '.bashrc'
    before = bashrc.read_text() if bashrc.exists() else ''
    new_bashrc = shell_text(before)  # Pré-validar antes de alterar qualquer configuração.
    utilities = ('novo-projeto', 'atualizar', 'diagnostico', 'portainer')
    for name in utilities:
        target = HOME_DIR / '.local/bin' / name
        if (target.exists() or target.is_symlink()) and not known_utility(target, name):
            raise ValueError(f'Arquivo pessoal ocupa o comando {name}: {target}. Nenhum reparo aplicado.')
    write_managed(HOME_DIR / '.config/meu-setup/shell.bash', (REPO / 'configs/shell.bash').read_bytes())
    write_managed(bashrc, new_bashrc.encode())
    for name in utilities:
        target = HOME_DIR / '.local/bin' / name
        source = REPO / 'bin' / name
        if target.is_symlink() and os.readlink(target) == str(source):
            continue
        backup(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        temp = target.with_name('.' + name + '-meu-setup')
        if temp.exists() or temp.is_symlink():
            temp.unlink()
        temp.symlink_to(source)
        os.replace(temp, target)
        print(f'REPARADO: {target}')
    if 'starship' in components:
        target = HOME_DIR / '.config/starship.toml'
        if not target.exists():
            write_managed(target, (REPO / 'configs/starship.toml').read_bytes())
        elif target.is_symlink():
            print(f'PRESERVADO: prompt personalizado em {target}')
    if 'git' in components:
        target = HOME_DIR / '.config/git/ignore'
        # Acrescentar padrões ausentes preservando todos os padrões existentes.
        old = target.read_text() if target.exists() else ''
        patterns = [line for line in (REPO / 'configs/gitignore_global').read_text().splitlines()
                    if line and not line.startswith('#') and line not in old.splitlines()]
        if patterns:
            write_managed(target, (old.rstrip() + '\n\n# Padrões do meu-setup\n' + '\n'.join(patterns) + '\n').lstrip().encode())


def restore(path, revision):
    target = Path(path).absolute()
    index = load(STATE / 'backups/index.json', {})
    if str(target) not in index:
        raise ValueError(f'Nenhum backup registrado para {target}')
    entry = index[str(target)][revision]
    if entry['kind'] == 'file':
        data = Path(entry['object']).read_bytes()
        if digest(data) != entry['sha256']:
            raise ValueError('Backup corrompido. Restauração cancelada.')
        atomic(target, data, entry['mode'])
    elif entry['kind'] == 'symlink':
        temp = target.with_name('.' + target.name + '-restore')
        temp.symlink_to(entry['target'])
        os.replace(temp, target)
    elif target.is_file() or target.is_symlink():
        target.unlink()
    print(f'RESTAURADO: {target}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['inventory', 'components', 'migrate', 'backup', 'restore', 'ini', 'finalize'])
    parser.add_argument('path', nargs='?')
    parser.add_argument('--components')
    parser.add_argument('--output')
    parser.add_argument('--kind', choices=['wsl', 'windows'])
    parser.add_argument('--revision', type=int, default=0)
    args = parser.parse_args()
    if args.action == 'inventory':
        print(json.dumps(inventory(), indent=2, ensure_ascii=False))
    elif args.action == 'components':
        print(','.join(infer_components()))
    elif args.action == 'migrate':
        migrate(parse_components(args.components) if args.components is not None else infer_components())
    elif args.action == 'backup':
        print(json.dumps(backup(args.path), ensure_ascii=False))
    elif args.action == 'restore':
        restore(args.path, args.revision)
    elif args.action == 'ini':
        source = Path(args.path)
        text = source.read_text() if source.exists() else ''
        updates = {'boot': {'systemd': ('true', True)}} if args.kind == 'wsl' else {
            'experimental': {'automemoryreclaim': ('gradual', False)}}
        # Corrigir também os comentários imprecisos distribuídos pela versão anterior.
        result = ini_text(text, updates).replace('automemoryreclaim=', 'autoMemoryReclaim=')
        if args.kind == 'windows':
            result = result.replace('Otimizações de Performance do WSL (WSL 2 e WSL 3) - meu-setup', 'Configuração do WSL 2 - meu-setup')
            result = result.replace('# Modo de rede espelhada de alto desempenho (latência mínima e loopback nativo)', '# Modo de rede existente preservado pelo reparo')
            result = result.replace('# Resolução de DNS tunelada para compatibilidade perfeita com VPNs', '# Resolução de DNS tunelada')
            result = result.replace('# Compacta automaticamente o disco virtual ext4.vhdx após limpezas (Docker/npm/uv)', '# Usa discos esparsos para VHDs novos; não compacta retroativamente o disco atual')
        atomic(Path(args.output), result.encode(), 0o600)
    elif args.action == 'finalize':
        components = parse_components(args.components) if args.components is not None else infer_components()
        json_write(STATE / 'state.json', {'schema': 2, 'components': components,
                   'repository': str(REPO), 'configuration': 2})


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f'ERRO: {error}', file=sys.stderr)
        sys.exit(1)
