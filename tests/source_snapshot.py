"""Copia somente fontes públicas para um diretório de teste vazio."""
from pathlib import Path
import shutil
import sys
from public_files import ROOT, public_files


def snapshot(destination):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    destination.chmod(0o755)  # Somente código público; o usuário do container precisa ler a raiz.
    if any(destination.iterdir()):
        raise ValueError('O destino do snapshot precisa estar vazio.')
    for name in public_files():
        source, target = ROOT / name, destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target, follow_symlinks=False)


if __name__ == '__main__':
    snapshot(sys.argv[1])
