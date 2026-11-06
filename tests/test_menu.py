"""Menu real via PTY. Instalações param no APT simulado, sem sudo/rede reais."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from pty_runner import run_terminal

ROOT = Path(__file__).resolve().parent.parent
ALL = {'starship', 'node', 'python', 'docker', 'lazydocker', 'portainer', 'lazygit',
       'zoxide', 'bat', 'eza', 'git', 'codex', 'claude', 'opencode', 'antigravity', 'skills', 'ai-memory'}


class MenuTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='meu-setup-menu-')
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.home = self.root / 'home'
        self.mock = self.root / 'mock'
        self.home.mkdir()
        self.mock.mkdir()
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(('SETUP_', 'AI_MEMORY_', 'XDG_'))}
        self.env.update(HOME=str(self.home), SETUP_HOME=str(self.home),
                        SETUP_STATE_DIR=str(self.home / '.local/state/meu-setup'),
                        PATH=f'{self.mock}:/usr/bin:/bin')
        self.stub('dpkg-query', 'exit 1')
        self.stub('apt-get', 'printf "%s" "$SETUP_COMPONENTS" > "$HOME/selected"; exit 42')
        self.stub('sudo', 'if [ "${1:-}" = -n ]; then shift; fi; if [ "${1:-}" = -v ]; then exit 0; fi; exec "$@"')

    def stub(self, name, body):
        path = self.mock / name
        path.write_text('#!/bin/bash\n' + body + '\n')
        path.chmod(0o755)

    def run_menu(self, answers):
        return run_terminal([ROOT / 'install.sh', '--user-only'], answers,
                            env=self.env, cwd=self.root)

    def selected(self):
        return set((self.home / 'selected').read_text().split(','))

    def test_enter_selects_all_including_ai(self):
        result = self.run_menu('\n')
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertEqual(self.selected(), ALL)

    def test_custom_groups_validate_input_and_resolve_dependencies(self):
        result = self.run_menu('2\n99\n6,4,6\n')
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertIn('somente os números', result.stdout)
        self.assertEqual(self.selected(), {'codex', 'claude', 'opencode', 'antigravity', 'skills', 'ai-memory', 'python', 'node'})

    def test_repair_uses_saved_selection(self):
        state = Path(self.env['SETUP_STATE_DIR']) / 'state.json'
        state.parent.mkdir(parents=True)
        state.write_text(json.dumps({'components': ['git', 'python']}))
        result = self.run_menu('3\n')
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertEqual(self.selected(), {'git', 'python'})

    def test_full_choice_overrides_saved_partial_selection(self):
        state = Path(self.env['SETUP_STATE_DIR']) / 'state.json'
        state.parent.mkdir(parents=True)
        state.write_text(json.dumps({'components': ['git']}))
        result = self.run_menu('1\n')
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertEqual(self.selected(), ALL)

    def test_repair_without_state_returns_to_menu_without_changes(self):
        result = self.run_menu('3\n0\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Não há seleção salva', result.stdout)
        self.assertFalse(any(self.home.iterdir()))

    def test_invalid_choice_back_and_exit_do_not_create_files(self):
        result = self.run_menu('99\n2\n0\n0\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Escolha 1, 2, 3 ou 0.', result.stdout)
        self.assertFalse(any(self.home.iterdir()))

    def test_eof_cancels_instead_of_selecting_full(self):
        result = self.run_menu('\x04')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(self.home.iterdir()))

    def test_no_terminal_requires_explicit_action_without_writes(self):
        result = subprocess.run([str(ROOT / 'install.sh')], env=self.env, cwd=self.root,
                                capture_output=True, text=True, input='', timeout=10)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse(any(self.home.iterdir()))
