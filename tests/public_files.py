"""Verifica apenas conteúdo publicável e fornece a seleção usada nos testes isolados."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
LOCAL_DOCUMENTS = {'PLANO-DE-CORRECAO.md', 'docs/IMPLANTACAO.md'}
PRIVATE_DIRECTORIES = {'.local', '.aws', '.ssh', '.codex', '.agents', 'backups', 'logs', 'notes', 'scratch', '__pycache__'}
PRIVATE_SUFFIXES = {'.pem', '.key', '.p12', '.pfx', '.pyc'}


def is_private(name):
    path = Path(name)
    return (name in LOCAL_DOCUMENTS or bool(set(path.parts) & PRIVATE_DIRECTORIES)
            or path.suffix in PRIVATE_SUFFIXES
            or path.name == '.env' or path.name.startswith('.env.') and path.name != '.env.example'
            or path.name.startswith(('id_rsa', 'id_ed25519')) or path.suffix == '.log')


def source_files():
    result = subprocess.run(['git', '-C', str(ROOT), 'ls-files', '--cached', '--others', '--exclude-standard', '-z'],
                            capture_output=True, check=True)
    files = sorted(set(name.decode() for name in result.stdout.split(b'\0') if name))
    return [name for name in files if (ROOT / name).exists() or (ROOT / name).is_symlink()]


def public_files():
    files = source_files()
    for name in files:
        if is_private(name):
            raise ValueError(f'Arquivo local/privado selecionado para publicação: {name}')
        source = ROOT / name
        if source.is_symlink() and not source.resolve().is_relative_to(ROOT):
            raise ValueError(f'Link aponta para fora do projeto: {name}')
    return files


if __name__ == '__main__':
    try:
        files = public_files()
        print(f'Conteúdo público: {len(files)} arquivos verificados.')
    except (ValueError, subprocess.SubprocessError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
