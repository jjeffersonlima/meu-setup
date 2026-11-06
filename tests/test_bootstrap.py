"""Entrada de instalação: clones locais reais e programas isolados, sem rede/sudo."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

from pty_runner import run_terminal

ROOT = Path(__file__).resolve().parent.parent


class BootstrapTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='meu-setup-bootstrap-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home, self.mock, self.repository = (self.root / name for name in ('home', 'mock', 'repository'))
        self.home.mkdir()
        self.mock.mkdir()
        self.repository.mkdir()
        self.env = os.environ.copy()
        self.env.pop('MEU_SETUP_DIR', None)
        self.env.update(HOME=str(self.home), SETUP_HOME=str(self.home),
                        SETUP_STATE_DIR=str(self.home / '.local/state/meu-setup'),
                        MEU_SETUP_REPOSITORY=str(self.repository),
                        GIT_CONFIG_GLOBAL=str(self.home / '.gitconfig'), GIT_CONFIG_SYSTEM='/dev/null',
                        PATH=f'{self.mock}:/usr/bin:/bin', MOCK_BOOTSTRAP=str(ROOT / 'bootstrap.sh'))
        self.run_command(['git', 'init', '-q', '-b', 'main', self.repository])
        for name in ('lib/common.sh', 'lib/config.py', 'configs/versions.env'):
            path = self.repository / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('# fixture\n')
        (self.repository / 'install.sh').write_text('''#!/usr/bin/env bash
printf '%s\\n' "$@" > "$SETUP_HOME/received-arguments"
exit "${MOCK_INSTALL_STATUS:-0}"
''')
        self.commit()

    def run_command(self, command, ok=True, **kwargs):
        result = subprocess.run([str(arg) for arg in command], cwd=kwargs.pop('cwd', self.root),
                                env=kwargs.pop('env', self.env), capture_output=True, text=True, timeout=20, **kwargs)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def commit(self):
        self.run_command(['git', '-C', self.repository, 'add', '.'])
        self.run_command(['git', '-C', self.repository, '-c', 'user.name=Teste', '-c', 'user.email=teste@local',
                          'commit', '-q', '-m', 'fixture'])

    def bootstrap(self, *args, ok=True):
        return self.run_command(['bash', ROOT / 'bootstrap.sh', '--config-only', '--user-only', *args], ok=ok)

    def destination(self):
        return self.home / '.local/share/meu-setup'

    def stub(self, name, body):
        path = self.mock / name
        path.write_text('#!/bin/bash\n' + body + '\n')
        path.chmod(0o755)
        return path

    def seed_command(self):
        text = (ROOT / 'README.md').read_text()
        return re.search(r'```bash\n(bash -c [^\n]+)\n```', text).group(1)

    def test_help_does_not_create_state_or_clone(self):
        self.run_command(['bash', ROOT / 'bootstrap.sh', '--help'])
        self.assertEqual(list(self.home.iterdir()), [])

    def test_first_install_keeps_persistent_source_and_forwards_arguments(self):
        self.bootstrap('--components', 'python,git')
        self.assertTrue((self.destination() / '.git').is_dir())
        self.assertEqual((self.home / 'received-arguments').read_text().splitlines(),
                         ['--config-only', '--user-only', '--components', 'python,git'])
        self.assertEqual(list(self.destination().parent.glob('.meu-setup-download.*')), [])

    def test_single_command_preserves_terminal_and_choice(self):
        installer = self.repository / 'install.sh'
        installer.write_text('''#!/bin/bash
[ -t 0 ] || exit 9
read -rp 'Escolha [1]: ' answer
printf '%s' "$answer" > "$SETUP_HOME/terminal-choice"
printf '%s\\n' "$@" > "$SETUP_HOME/received-arguments"
''')
        self.commit()
        self.stub('curl', 'cat "$MOCK_BOOTSTRAP"')
        result = run_terminal(['bash', '-c', self.seed_command()], '3\n',
                              env=self.env, cwd=self.root)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.home / 'terminal-choice').read_text(), '3')
        self.assertNotIn('--yes', (self.home / 'received-arguments').read_text())

    def test_repeat_preserves_existing_revision(self):
        self.bootstrap()
        (self.repository / 'new-version').write_text('nova versão')
        self.commit()
        self.bootstrap()
        self.assertFalse((self.destination() / 'new-version').exists())

    def test_registered_existing_installation_is_reused(self):
        destination = self.home / 'projetos/outro-caminho'
        self.bootstrap('--dir', destination)
        state = self.home / '.local/state/meu-setup/state.json'
        state.write_text(json.dumps({'repository': str(destination)}))
        self.bootstrap()
        self.assertFalse(self.destination().exists())
        self.assertTrue((destination / '.git').exists())

    def test_personal_directory_is_not_replaced(self):
        self.destination().mkdir(parents=True)
        personal = self.destination() / 'meus-dados'
        personal.write_text('preservar')
        self.bootstrap(ok=False)
        self.assertEqual(personal.read_text(), 'preservar')

    def test_dirty_clone_and_other_branch_are_preserved(self):
        self.bootstrap()
        personal = self.destination() / 'meu-rascunho'
        personal.write_text('preservar')
        self.bootstrap()
        self.assertEqual(personal.read_text(), 'preservar')
        personal.unlink()
        self.run_command(['git', '-C', self.destination(), 'checkout', '-q', '-b', 'estudos'])
        self.bootstrap()
        branch = self.run_command(['git', '-C', self.destination(), 'branch', '--show-current']).stdout.strip()
        self.assertEqual(branch, 'estudos')

    def test_different_origin_is_not_updated(self):
        self.bootstrap()
        self.run_command(['git', '-C', self.destination(), 'remote', 'set-url', 'origin', '/outro-repositorio'])
        self.bootstrap(ok=False)
        origin = self.run_command(['git', '-C', self.destination(), 'remote', 'get-url', 'origin']).stdout.strip()
        self.assertEqual(origin, '/outro-repositorio')

    def test_failed_download_cleans_staging_and_allows_retry(self):
        self.env['MEU_SETUP_REPOSITORY'] = str(self.root / 'not-found')
        self.bootstrap(ok=False)
        self.assertFalse(self.destination().exists())
        self.assertEqual(list(self.destination().parent.glob('.meu-setup-download.*')), [])
        self.env['MEU_SETUP_REPOSITORY'] = str(self.repository)
        self.bootstrap()

    def test_installer_error_is_propagated_and_source_remains_for_retry(self):
        self.env['MOCK_INSTALL_STATUS'] = '42'
        result = self.bootstrap(ok=False)
        self.assertEqual(result.returncode, 42)
        self.assertTrue((self.destination() / 'install.sh').exists())
        self.env.pop('MOCK_INSTALL_STATUS')
        self.bootstrap()

    def test_active_installer_prevents_source_update(self):
        state_dir = Path(self.env['SETUP_STATE_DIR'])
        state_dir.mkdir(parents=True)
        import fcntl
        with open(state_dir / 'install.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.bootstrap(ok=False)
        self.assertFalse(self.destination().exists())

    def test_documented_command_stops_when_http_download_fails(self):
        self.stub('curl', 'exit 22')
        result = self.run_command(['bash', '-c', self.seed_command()], ok=False)
        self.assertEqual(result.returncode, 22)
        self.assertFalse(self.destination().exists())

    def test_documented_command_prepares_curl_when_missing(self):
        # Apenas utilitários base e Git/Python existem; curl será preparado pelo APT simulado.
        for name in ('bash', 'cat', 'chmod', 'uname', 'env', 'mkdir', 'mktemp', 'readlink', 'mv', 'rm',
                     'flock', 'timeout', 'git', 'python3', 'dirname'):
            (self.mock / name).symlink_to('/usr/bin/' + name)
        self.env['PATH'] = str(self.mock)
        self.env['MOCK_TOOLS'] = str(self.mock)
        self.env['MOCK_APT_LOG'] = str(self.root / 'apt.log')
        self.stub('sudo', 'if [ "${1:-}" = -n ]; then shift; fi; if [ "${1:-}" = -v ]; then exit 0; fi; exec "$@"')
        self.stub('apt-get', '''printf '%s\\n' "$*" >> "$MOCK_APT_LOG"
case " $* " in
 *" install "*)
  printf '#!/bin/bash\\ncat "$MOCK_BOOTSTRAP"\\n' > "$MOCK_TOOLS/curl"
  chmod +x "$MOCK_TOOLS/curl"
  ;;
esac
''')
        self.run_command(['bash', '-c', self.seed_command()])
        self.assertTrue((self.destination() / '.git').exists())
        apt_log = Path(self.env['MOCK_APT_LOG']).read_text()
        self.assertIn('update', apt_log)
        self.assertIn('curl ca-certificates', apt_log)


if __name__ == '__main__':
    unittest.main(verbosity=2)
