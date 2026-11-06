"""Instalação de releases com downloads locais; sem rede ou HOME real."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class HerdrTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='meu-setup-tools-')
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.home = self.root / 'home'
        self.home.mkdir()
        self.candidate = self.root / 'candidate'
        self.candidate.write_text('#!/bin/bash\necho "herdr 0.9.5"\n')
        self.metadata = self.root / 'release.json'
        self.metadata.write_text(json.dumps({'assets': [{
            'name': 'herdr-linux-x86_64',
            'digest': 'sha256:' + hashlib.sha256(self.candidate.read_bytes()).hexdigest()}]}))
        self.env = dict(os.environ, HOME=str(self.home), SETUP_HOME=str(self.home),
                        SETUP_STATE_DIR=str(self.home / '.local/state/meu-setup'),
                        PATH='/usr/bin:/bin', DIR_SETUP=str(ROOT),
                        TEST_CANDIDATE=str(self.candidate), TEST_METADATA=str(self.metadata))
        self.target = self.home / '.local/bin/herdr'

    def shell(self, script, ok=True):
        preamble = '''set -euo pipefail
source "$DIR_SETUP/lib/common.sh"
source "$DIR_SETUP/lib/log.sh"
source "$DIR_SETUP/lib/tools.sh"
setup_environment
setup_arch() { echo x86_64; }
setup_download() {
    case "$1" in
        https://github.com/herdrdev/herdr/releases/download/v0.9.5/herdr-linux-x86_64)
            cp "$TEST_CANDIDATE" "$2" ;;
        https://api.github.com/repos/herdrdev/herdr/releases/tags/v0.9.5)
            cp "$TEST_METADATA" "$2" ;;
        *) return 90 ;;
    esac
}
'''
        result = subprocess.run(['bash', '-c', preamble + script], env=self.env,
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return result

    def test_raw_binary_installs_and_reuses_without_download_or_config_change(self):
        personal = self.home / '.config/herdr/config.toml'
        personal.parent.mkdir(parents=True)
        personal.write_text('# Preferências pessoais\n')
        self.shell('instalar_herdr\nsetup_download() { return 91; }\ninstalar_herdr')
        self.assertEqual(self.target.read_bytes(), self.candidate.read_bytes())
        self.assertTrue(os.access(self.target, os.X_OK))
        self.assertEqual(personal.read_text(), '# Preferências pessoais\n')
        self.assertEqual(subprocess.check_output([self.target], text=True).strip(), 'herdr 0.9.5')

    def test_checksum_failure_preserves_existing_binary(self):
        self.target.parent.mkdir(parents=True)
        self.target.write_text('#!/bin/bash\nexit 1\n')
        self.target.chmod(0o755)
        original = self.target.read_bytes()
        self.candidate.write_text('#!/bin/bash\nexit 0\n')
        self.shell('instalar_herdr', ok=False)
        self.assertEqual(self.target.read_bytes(), original)

    def test_non_executable_candidate_does_not_replace_existing_binary(self):
        self.target.parent.mkdir(parents=True)
        self.target.write_text('Instalação existente\n')
        self.candidate.write_text('#!/bin/bash\nexit 42\n')
        self.metadata.write_text('{}')
        self.shell('instalar_herdr', ok=False)
        self.assertEqual(self.target.read_text(), 'Instalação existente\n')
