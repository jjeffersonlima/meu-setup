"""Regressões de reparo e preservação de dados. Sem rede, sudo ou daemon Docker."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('setup_config', REPO / 'lib/config.py')
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


class SetupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='meu-setup-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home'
        self.home.mkdir()
        self.mock = self.root / 'mock'
        self.mock.mkdir()
        self.env = os.environ.copy()
        # HOME é definido somente no subprocesso isolado; nunca altera o shell do usuário.
        self.env.update(HOME=str(self.home), SETUP_HOME=str(self.home),
                        SETUP_STATE_DIR=str(self.home / '.local/state/meu-setup'),
                        GIT_CONFIG_GLOBAL=str(self.home / '.gitconfig'), GIT_CONFIG_SYSTEM='/dev/null',
                        PATH=f'{self.mock}:/usr/bin:/bin', CI='true', UV_OFFLINE='true',
                        XDG_CACHE_HOME=str(self.root / 'cache'), XDG_RUNTIME_DIR=str(self.root / 'runtime'))
        self.original_home, self.original_state = config.HOME_DIR, config.STATE
        config.HOME_DIR = self.home
        config.STATE = Path(self.env['SETUP_STATE_DIR'])
        self.addCleanup(self.restore_globals)

    def restore_globals(self):
        config.HOME_DIR, config.STATE = self.original_home, self.original_state

    def command(self, args, ok=True, **kwargs):
        result = subprocess.run([str(a) for a in args], cwd=kwargs.pop('cwd', self.root),
                                env=kwargs.pop('env', self.env), capture_output=True,
                                text=True, timeout=15, **kwargs)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def stub(self, name, body):
        path = self.mock / name
        path.write_text('#!/usr/bin/env bash\n' + body + '\n')
        path.chmod(0o755)
        return path

    def install(self, *args, ok=True):
        return self.command([REPO / 'install.sh', '--yes', '--config-only', '--user-only',
                             '--components', 'git', *args], ok=ok)

    def snapshot(self):
        return {str(p.relative_to(self.home)): (os.readlink(p) if p.is_symlink() else p.read_bytes())
                for p in self.home.rglob('*') if (p.is_file() or p.is_symlink()) and '/logs/' not in str(p)
                and p.name not in ('inventory.json', 'install.lock')}

    def test_help_and_inventory_have_no_writes(self):
        before = self.snapshot()
        for script in ('install.sh', 'bin/novo-projeto', 'bin/atualizar', 'bin/portainer', 'bin/diagnostico'):
            self.command([REPO / script, '--help'])
        self.command([REPO / 'install.sh', '--inventory'])
        self.assertEqual(before, self.snapshot())

    def test_fresh_configuration_and_three_runs_stable(self):
        self.install()
        first = self.snapshot()
        self.install()
        self.install()
        self.assertEqual(first, self.snapshot())
        self.command([REPO / 'bin/diagnostico', '--config-only'])
        state = json.loads((config.STATE / 'state.json').read_text())
        self.assertEqual(state['components'], ['git'])

    def test_all_historical_bash_blocks_and_copied_utility(self):
        block = (REPO / 'tests/fixtures/legacy.bashrc').read_text().rstrip('\n')
        bashrc = self.home / '.bashrc'
        personal = '# Preferência pessoal\nexport EDITOR=nano\n'
        bashrc.write_text(personal + block + '\n' + block + '\n')
        local_bin = self.home / '.local/bin'
        local_bin.mkdir(parents=True)
        historical = (REPO / 'tests/fixtures/legacy-novo-projeto.txt').read_bytes()
        (local_bin / 'novo-projeto').write_bytes(historical)
        (local_bin / 'atualizar').symlink_to('/antigo/meu-setup/bin/atualizar')
        self.install()
        text = bashrc.read_text()
        self.assertIn(personal, text)
        self.assertEqual(text.count(config.START), 1)
        self.assertNotIn('generate-shell-completion', text)
        self.assertTrue((local_bin / 'novo-projeto').is_symlink())
        self.assertEqual((local_bin / 'atualizar').resolve(), REPO / 'bin/atualizar')
        self.command(['python3', REPO / 'lib/config.py', 'restore', bashrc])
        self.assertEqual(bashrc.read_text(), personal + block + '\n' + block + '\n')

    def test_unbalanced_marker_does_not_erase_personal_content(self):
        bashrc = self.home / '.bashrc'
        original = '# pessoal\n' + config.START + '\nalias favorito="echo importante"\n'
        bashrc.write_text(original)
        self.install(ok=False)
        self.assertEqual(bashrc.read_text(), original)
        self.assertFalse((self.home / '.config/meu-setup/shell.bash').exists())
        self.assertFalse((config.STATE / 'state.json').exists())

    def test_unknown_command_is_not_replaced(self):
        command = self.home / '.local/bin/novo-projeto'
        command.parent.mkdir(parents=True)
        command.write_text('#!/bin/bash\necho meu_programa_pessoal\n')
        self.install(ok=False)
        self.assertIn('meu_programa_pessoal', command.read_text())
        self.assertFalse((self.home / '.bashrc').exists())

    def test_backup_failure_leaves_original(self):
        target = self.home / 'personal'
        target.write_text('original')
        with patch.object(config, 'atomic', side_effect=OSError('disco cheio')):
            with self.assertRaises(OSError):
                config.write_managed(target, b'new')
        self.assertEqual(target.read_text(), 'original')

    def test_corrupt_backup_cannot_be_restored(self):
        target = self.home / 'personal'
        target.write_text('original')
        entry = config.backup(target)
        target.write_text('new')
        Path(entry['object']).write_text('corrompido')
        with self.assertRaises(ValueError):
            config.restore(target, 0)
        self.assertEqual(target.read_text(), 'new')

    def test_ini_merge_keeps_limits_network_and_user(self):
        old = '# pessoal\n[wsl2]\nmemory=4GB\nprocessors=2\nnetworkingMode=nat\n[wsl2]\nswap=0\n[experimental]\nautoMemoryReclaim=disabled\n'
        changes = {'experimental': {'automemoryreclaim': ('gradual', False)}}
        result = config.ini_text(old, changes)
        for value in ('memory=4GB', 'processors=2', 'networkingMode=nat', 'swap=0', 'autoMemoryReclaim=disabled'):
            self.assertIn(value, result)
        self.assertEqual(result.count('[wsl2]'), 1)
        self.assertEqual(config.ini_text(result, changes), result)
        wsl = config.ini_text('[boot]\nsystemd=false\n[user]\ndefault=estudante\n[boot]\nsystemd=false\n',
                               {'boot': {'systemd': ('true', True)}})
        self.assertEqual(wsl.count('[boot]'), 1)
        self.assertEqual(wsl.count('systemd=true'), 1)
        self.assertIn('default=estudante', wsl)

    def test_correct_wsl_file_is_not_reformatted(self):
        original = '\n# pessoal\n[boot]\nsystemd=true\n\n[user]\ndefault=aluno\n'
        result = config.ini_text(original, {'boot': {'systemd': ('true', True)}})
        self.assertEqual(original, result)


    def test_personal_prompt_git_identity_and_ignore_survive(self):
        (self.home / '.config/git').mkdir(parents=True)
        prompt = self.home / '.config/starship.toml'
        prompt.write_text('add_newline=false\n')
        ignore = self.home / '.config/git/ignore'
        ignore.write_text('meu-arquivo-especial\n')
        gitconfig = self.home / '.gitconfig'
        gitconfig.write_text('[user]\n name = Estudante\n email = aluno@local\n')
        self.install('--components', 'git,starship')
        self.assertEqual(prompt.read_text(), 'add_newline=false\n')
        self.assertIn('meu-arquivo-especial', ignore.read_text())
        self.assertIn('Estudante', gitconfig.read_text())

    def test_empty_profile_is_saved_without_enabling_tools(self):
        self.install('--components', '')
        state = json.loads((config.STATE / 'state.json').read_text())
        self.assertEqual(state['components'], [])
        result = self.command([REPO / 'bin/diagnostico'])
        self.assertNotIn('FALHOU', result.stdout)
        self.assertIn('NÃO ESCOLHIDO', result.stdout)

    def test_partial_migration_can_be_resumed(self):
        original = config.write_managed
        calls = 0
        def interrupted(*args, **kwargs):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError('interrupção simulada')
            return original(*args, **kwargs)
        with patch.object(config, 'write_managed', side_effect=interrupted):
            with self.assertRaises(OSError):
                config.migrate(['git'])
        self.assertFalse((config.STATE / 'state.json').exists())
        self.install()
        self.command([REPO / 'bin/diagnostico', '--config-only'])

    def test_healthy_reinstallation_does_not_request_sudo(self):
        self.stub('dpkg-query', 'printf installed')
        self.stub('sudo', 'echo SUDO_INDEVIDO >&2; exit 99')
        self.command([REPO / 'install.sh', '--yes', '--user-only', '--components', ''])


    def test_installer_propagates_package_failure(self):
        self.stub('dpkg-query', 'exit 1')
        self.stub('apt-get', 'exit 42')
        self.stub('sudo', 'if [ "${1:-}" = -n ]; then shift; fi; if [ "${1:-}" = -v ]; then exit 0; fi; exec "$@"')
        result = self.command([REPO / 'install.sh', '--yes', '--user-only', '--components', 'git'], ok=False)
        self.assertEqual(result.returncode, 42)
        self.assertFalse((config.STATE / 'state.json').exists())
        self.assertFalse((self.home / '.bashrc').exists())


    def test_apt_failure_is_not_cached(self):
        script = f'''source '{REPO}/lib/common.sh'
source '{REPO}/lib/log.sh'
source '{REPO}/lib/system.sh'
setup_admin() {{ return 42; }}
executar_apt_update
status=$?
echo "status=$status updated=${{SETUP_APT_UPDATED:-false}}"
'''
        result = self.command(['bash', '-c', script])
        self.assertIn('status=42 updated=false', result.stdout)

    def test_aliases_forward_arguments_and_python_shortcut(self):
        log = self.root / 'args.log'
        self.env['MOCK_LOG'] = str(log)
        for name in ('code', 'xdg-open', 'novo-projeto'):
            self.stub(name, 'printf "%s\\n" "$0:$*" >> "$MOCK_LOG"')
        self.command(['bash', '-c', f'''source '{REPO}/configs/shell.bash'
code "./pasta com espaço"
open "./pasta com espaço"
novo-python meu-bot
'''])
        lines = log.read_text()
        self.assertIn('code:./pasta com espaço', lines)
        self.assertIn('xdg-open:./pasta com espaço', lines)
        self.assertIn('novo-projeto:python meu-bot', lines)

    def test_existing_projects_and_path_traversal_preserved(self):
        target = self.root / 'existing'
        target.mkdir()
        sentinel = target / 'docker-compose.yml'
        sentinel.write_text('pessoal')
        self.command([REPO / 'bin/novo-projeto', 'docker', 'existing'], ok=False)
        self.assertEqual(sentinel.read_text(), 'pessoal')
        self.command([REPO / 'bin/novo-projeto', 'docker', '../escape'], ok=False)
        self.command([REPO / 'bin/novo-projeto', '--type'], ok=False)

    def test_docker_projects_have_distinct_credentials_and_no_global_names(self):
        for name in ('stack-a', 'stack-b'):
            self.command([REPO / 'bin/novo-projeto', 'docker', name])
        self.assertNotEqual((self.root / 'stack-a/.env').read_text(), (self.root / 'stack-b/.env').read_text())
        self.assertNotIn('container_name:', (self.root / 'stack-a/docker-compose.yml').read_text())
        self.assertIn('.env\n', (self.root / 'stack-a/.gitignore').read_text())

    def test_python_template_executes_and_prints_correct_instruction(self):
        self.stub('uv', '''if [ "$1" = --version ]; then echo 'uv 0.13.6'; exit; fi
[ "$1" = init ] || exit 9
printf '[project]\\nname="example"\\nversion="0.1.0"\\n' > pyproject.toml
''')
        result = self.command([REPO / 'bin/novo-projeto', 'python', 'meu-bot'])
        self.assertIn('uv run main.py', result.stdout)
        self.assertIn('Tudo pronto', self.command(['python3', self.root / 'meu-bot/main.py']).stdout)

    def test_node_dependency_failure_is_not_reported_ready(self):
        self.stub('node', 'echo v26.13.0')
        self.stub('pnpm', 'if [ "$1" = --version ]; then echo 12.16.1; else exit 42; fi')
        result = self.command([REPO / 'bin/novo-projeto', 'node', 'meu-node'], ok=False)
        self.assertEqual(result.returncode, 42)
        self.assertNotIn('Projeto meu-node pronto', result.stdout)
        self.assertIn('não está pronta', result.stderr)

    def test_missing_tools_do_not_create_project(self):
        self.command([REPO / 'bin/novo-projeto', 'node', 'sem-node'], ok=False)
        self.assertFalse((self.root / 'sem-node').exists())

    def docker_mock(self):
        state = self.root / 'docker-state.json'
        state.write_text(json.dumps({'exists': True, 'image': 'sha256:existing', 'data': 'contas-e-stacks'}))
        self.env['MOCK_DOCKER_STATE'] = str(state)
        self.env['MOCK_DOCKER_LOG'] = str(self.root / 'docker-calls.log')
        docker = self.mock / 'docker'
        docker.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
state=pathlib.Path(os.environ['MOCK_DOCKER_STATE'])
s=json.loads(state.read_text())
a=sys.argv[1:]
with open(os.environ['MOCK_DOCKER_LOG'],'a') as f: f.write(json.dumps(a)+'\\n')
if a==['--version']: print('Docker version 29.0.0')
elif a[:2]==['container','inspect']: sys.exit(0 if s['exists'] else 1)
elif a[:2]==['image','inspect']: pass
elif a[0]=='inspect':
 fmt=a[-1]
 if '.Config.Image' in fmt: print('portainer/portainer-ce:latest')
 elif '.Image' in fmt: print(s['image'])
 elif 'HostIp' in fmt: print('127.0.0.1')
 elif '.State.Running' in fmt: print('false')
 elif '.Config.Cmd' in fmt: print('["--no-setup-token"]')
 elif '.Mounts' in fmt: print('portainer_data')
 else: print(json.dumps(s))
elif a[0]=='rm': s['exists']=False
elif a[0] in ('run','create'): s['exists']=True
elif a[0]=='logs': print('setup_token=test-token-123')
state.write_text(json.dumps(s))
''')
        docker.chmod(0o755)
        self.stub('curl', 'exit 0')
        return state

    def test_portainer_reset_preserves_data_and_removes_token_bypass(self):
        state = self.docker_mock()
        self.command([REPO / 'bin/portainer', 'reset', '--lan'])
        self.assertEqual(json.loads(state.read_text())['data'], 'contas-e-stacks')
        calls = [json.loads(line) for line in Path(self.env['MOCK_DOCKER_LOG']).read_text().splitlines()]
        self.assertNotIn(['volume', 'rm', 'portainer_data'], calls)
        run = next(call for call in calls if call[0] == 'create')
        self.assertNotIn('--no-setup-token', run)
        self.assertIn('sha256:existing', run)
        self.assertIn('0.0.0.0:9000:9000', run)

    def test_portainer_repair_keeps_a_stopped_panel_stopped(self):
        self.docker_mock()
        self.command([REPO / 'bin/portainer', 'repair'])
        calls = [json.loads(line) for line in Path(self.env['MOCK_DOCKER_LOG']).read_text().splitlines()]
        self.assertTrue(any(call[0] == 'create' for call in calls))
        self.assertFalse(any(call[0] in ('start', 'run') for call in calls))


    def test_portainer_repair_checks_https_binding_too(self):
        self.docker_mock()
        program = self.mock / 'docker'
        text = program.read_text().replace("print('[\"--no-setup-token\"]')", "print('[]')")
        text = text.replace("elif 'HostIp' in fmt: print('127.0.0.1')", "elif 'HostIp' in fmt: print('0.0.0.0' if '9443/tcp' in fmt else '127.0.0.1')")
        program.write_text(text)
        self.command([REPO / 'bin/portainer', 'repair'])
        calls = [json.loads(line) for line in Path(self.env['MOCK_DOCKER_LOG']).read_text().splitlines()]
        self.assertTrue(any(call[0] == 'create' for call in calls))


    def test_portainer_custom_storage_is_not_removed(self):
        self.docker_mock()
        program = self.mock / 'docker'
        program.write_text(program.read_text().replace("print('portainer_data')", "print('meu_volume_pessoal')"))
        result = self.command([REPO / 'bin/portainer', 'reset'], ok=False)
        self.assertIn('armazenamento personalizado', result.stderr)
        calls = [json.loads(line) for line in Path(self.env['MOCK_DOCKER_LOG']).read_text().splitlines()]
        self.assertFalse(any(call[0] in ('rm', 'run', 'create') for call in calls))


    def test_portainer_status_does_not_start_or_remove(self):
        self.docker_mock()
        self.command([REPO / 'bin/portainer', 'status'])
        calls = [json.loads(line) for line in Path(self.env['MOCK_DOCKER_LOG']).read_text().splitlines()]
        self.assertFalse(any(c[0] in ('run', 'create', 'rm', 'start', 'stop', 'pull') for c in calls))

    def test_update_guide_preserves_configuration(self):
        self.install()
        first = self.snapshot()
        self.command([REPO / 'bin/atualizar', '--yes', '--no-repo', '--config-only', '--user-only'])
        self.assertEqual(first, self.snapshot())


    def test_update_yes_does_not_authorize_cleanup(self):
        self.docker_mock()
        self.command([REPO / 'bin/atualizar', '--yes', '--clean-docker'])
        self.assertFalse(Path(self.env['MOCK_DOCKER_LOG']).exists())

    def test_doctor_does_not_invent_versions(self):
        self.install('--components', 'bat')
        self.stub('bat', 'exit 42')
        result = self.command([REPO / 'bin/diagnostico'], ok=False)
        self.assertIn('FALHOU', result.stdout)
        self.assertNotIn('0.26.1', result.stdout)

    def test_concurrent_install_is_refused(self):
        config.STATE.mkdir(parents=True)
        with open(config.STATE / 'install.lock', 'w') as lock:
            import fcntl
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.install(ok=False)
        self.assertIn('Outra instalação', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)
