"""Contratos de instalação e preservação de IA, sem rede, contas ou HOME real."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parent.parent


class AITest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='meu-setup-ai-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home'
        self.home.mkdir()
        self.mock = self.root / 'mock'
        self.mock.mkdir()
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(('AI_MEMORY_', 'SETUP_', 'XDG_', 'CODEX_', 'CLAUDE_'))}
        self.env.update(HOME=str(self.home), SETUP_HOME=str(self.home),
                        SETUP_STATE_DIR=str(self.home / '.local/state/meu-setup'),
                        PATH=f'{self.mock}:/usr/bin:/bin')
        self.bootstrap = f'''set -euo pipefail
DIR_SETUP='{REPO}'
source "$DIR_SETUP/lib/common.sh"
source "$DIR_SETUP/lib/log.sh"
source "$DIR_SETUP/configs/versions.env"
source "$DIR_SETUP/lib/ai.sh"
setup_environment
'''

    def stub(self, name, body):
        path = self.mock / name
        path.write_text('#!/bin/bash\nset -eu\n' + body + '\n')
        path.chmod(0o755)

    def shell(self, script, ok=True):
        result = subprocess.run(['bash', '-c', self.bootstrap + script], env=self.env,
                                cwd=self.root, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return result

    def test_new_default_includes_ai_and_normalize_accepts_individual_components(self):
        result = self.shell('setup_python components')
        self.assertIn('codex', result.stdout)
        result = self.shell('setup_python normalize --components codex,codex,antigravity,ai-memory')
        self.assertEqual(result.stdout.strip(), 'codex,antigravity,ai-memory')

    def test_native_existing_install_is_not_adopted(self):
        self.stub('codex', 'echo "codex 1.0.0"')
        self.shell('setup_ai_install codex')
        self.assertFalse((self.home / '.local/state/meu-setup/ai-tools.json').exists())

    def test_broken_existing_install_is_not_overwritten(self):
        self.stub('claude', 'exit 1')
        before = (self.mock / 'claude').read_bytes()
        self.shell('setup_ai_install claude', ok=False)
        self.assertEqual(before, (self.mock / 'claude').read_bytes())

    def test_update_guide_never_executes_tools_or_creates_state(self):
        for tool in ('git', 'sudo', 'apt-get', 'npm', 'curl', 'docker', 'systemctl',
                     'codex', 'claude', 'opencode', 'agy', 'skills', 'ai-memory'):
            self.stub(tool, 'echo executed >> "$HOME/unexpected"; exit 99')
        self.env['SETUP_COMPONENTS'] = 'codex,claude,opencode,antigravity,skills,ai-memory,node,python,docker'
        result = subprocess.run([str(REPO / 'bin/atualizar'), '--yes', '--system', '--clean-docker'],
                                env=self.env, cwd=self.root, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('ai-memory upgrade', result.stdout)
        self.assertIn('opencode upgrade', result.stdout)
        self.assertIn('https://chatgpt.com/codex/install.sh', result.stdout)
        self.assertNotIn('npm install --global @openai/codex', result.stdout)
        self.assertFalse(any(self.home.iterdir()))

    def test_update_guide_uses_managed_skills_prefix(self):
        self.stub('node', 'exit 99')
        self.shell('setup_ai_state npm-launcher skills')
        self.env['SETUP_COMPONENTS'] = 'skills'
        result = self.shell('"$DIR_SETUP/bin/atualizar"')
        self.assertIn('npm install --global --prefix', result.stdout)
        self.assertIn(str(self.home / '.local/share/meu-setup/npm'), result.stdout)

    def test_native_codex_install_does_not_use_node_or_npm(self):
        self.stub('node', 'echo unexpected > "$HOME/node-called"; exit 99')
        self.stub('npm', 'echo unexpected > "$HOME/npm-called"; exit 99')
        self.shell('''setup_ai_script() {
    [ "$1" = "https://raw.githubusercontent.com/openai/codex/rust-v$CODEX_VERSION/scripts/install/install.sh" ]
    [ "$2" = --release ]
    [ "$CODEX_NON_INTERACTIVE" = true ]
    mkdir -p "$DIR_LOCAL_BIN"
    printf '#!/bin/bash\\necho native-codex\\n' > "$DIR_LOCAL_BIN/codex"
    chmod +x "$DIR_LOCAL_BIN/codex"
}
setup_ai_install codex''')
        self.assertFalse((self.home / 'node-called').exists())
        self.assertFalse((self.home / 'npm-called').exists())

    def test_legacy_managed_codex_is_migrated_and_config_preserved(self):
        launcher = self.home / '.local/bin/codex'
        launcher.parent.mkdir(parents=True)
        launcher.write_text('#!/bin/bash\n# meu-setup: CLI npm de IA\nexec node "$HOME/.local/share/meu-setup/npm/bin/codex" "$@"\n')
        launcher.chmod(0o755)
        auth = self.home / '.codex/auth.json'
        auth.parent.mkdir()
        auth.write_text('{"fixture":"preserved"}')
        self.shell('''setup_ai_codex_install() {
    printf '#!/bin/bash\\necho native-codex\\n' > "$DIR_LOCAL_BIN/codex"
    chmod +x "$DIR_LOCAL_BIN/codex"
}
setup_ai_install codex''')
        self.assertEqual(auth.read_text(), '{"fixture":"preserved"}')
        self.assertIn('native-codex', launcher.read_text())
        self.assertTrue((self.home / '.local/state/meu-setup/backups/index.json').is_file())

    def test_npm_prefix_is_stable_and_npmrc_preserved(self):
        self.stub('node', 'echo v26.13.0')
        self.stub('npm', '''if [ "$1" = --version ]; then echo 11.0.0; exit; fi
[ "$1" = install ] && [ "$2" = --global ] && [ "$3" = --prefix ]
mkdir -p "$4/bin"
printf '#!/bin/bash\\necho 1.7.6\\n' > "$4/bin/skills"
chmod +x "$4/bin/skills"''')
        npmrc = self.home / '.npmrc'
        npmrc.write_text('prefix=/personal/prefix\n')
        self.shell('setup_ai_install skills')
        self.assertEqual(npmrc.read_text(), 'prefix=/personal/prefix\n')
        self.assertTrue((self.home / '.local/share/meu-setup/npm/bin/skills').is_file())
        self.shell('cd /tmp; skills --version')
        # A CLI mantém o runtime padrão mesmo num projeto com Node antigo ativo.
        stable_node = self.home / '.local/share/fnm/aliases/default/bin/node'
        stable_node.parent.mkdir(parents=True)
        stable_node.write_text('#!/bin/bash\necho stable-runtime\n')
        stable_node.chmod(0o755)
        self.stub('node', 'exit 99')
        result = self.shell('skills --version')
        self.assertIn('stable-runtime', result.stdout)

    def test_failed_download_is_not_executed(self):
        self.shell('setup_download() { echo "touch \\"$HOME/executed\\"" > "$2"; return 1; }; setup_ai_script https://invalid', ok=False)
        self.assertFalse((self.home / 'executed').exists())

    def test_memory_checksum_failure_never_runs_installer(self):
        self.shell('setup_download() { echo invalid > "$2"; }; setup_ai_memory_install', ok=False)

    def test_memory_existing_remote_provider_is_preserved(self):
        path = self.home / '.local/share/ai-memory/config.toml'
        path.parent.mkdir(parents=True)
        content = 'llm_provider = "codex"\nembedding_provider = "local"\n'
        path.write_text(content)
        self.shell('setup_ai_state prepare-memory', ok=False)
        self.assertEqual(path.read_text(), content)

    def test_memory_rejects_per_workload_provider_and_env_override(self):
        path = self.home / '.local/share/ai-memory/config.toml'
        path.parent.mkdir(parents=True)
        path.write_text('[llm.consolidation]\nprovider = "openai"\n')
        self.shell('setup_ai_state check-memory', ok=False)
        path.write_text('embedding_provider = "local"\n')
        self.shell('export AI_MEMORY_LLM_PROVIDER=codex; setup_ai_state check-memory', ok=False)

    def test_memory_without_agent_does_not_autodetect_omp(self):
        self.stub('ai-memory', 'echo called >> "$HOME/memory-calls"')
        self.shell('SETUP_COMPONENTS=ai-memory; configurar_memoria_ia', ok=False)
        self.assertEqual((self.home / 'memory-calls').read_text().strip(), 'called')  # --version only

    def test_memory_setup_names_only_selected_agents(self):
        self.stub('ai-memory', '''if [ "$1" = setup ]; then printf '%s\\n' "$*" > "$HOME/setup-args"; fi''')
        self.stub('systemctl', 'exit 0')
        path = self.home / '.local/share/ai-memory/config.toml'
        path.parent.mkdir(parents=True)
        path.write_text('embedding_provider = "local"\n')
        self.shell('SETUP_COMPONENTS=claude,codex,ai-memory; configurar_memoria_ia')
        self.assertEqual((self.home / 'setup-args').read_text().strip(), 'setup --yes --agent codex --agent claude-code')

    def test_config_only_never_downloads_ai_tools(self):
        result = subprocess.run([str(REPO / 'install.sh'), '--yes', '--config-only', '--user-only',
                                 '--components', 'codex,skills'], cwd=self.root, env=self.env,
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        saved = json.loads((self.home / '.local/state/meu-setup/state.json').read_text())
        self.assertEqual(saved['components'], ['codex', 'skills', 'node'])
        self.assertFalse((self.home / '.local/share/meu-setup/npm').exists())

    def test_codex_alone_does_not_add_node_dependency(self):
        result = subprocess.run([str(REPO / 'install.sh'), '--yes', '--config-only', '--user-only',
                                 '--components', 'codex'], cwd=self.root, env=self.env,
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        saved = json.loads((self.home / '.local/state/meu-setup/state.json').read_text())
        self.assertEqual(saved['components'], ['codex'])

    def test_missing_user_service_leaves_memory_pending_without_failing_install(self):
        self.stub('ai-memory', 'exit 0')
        self.stub('systemctl', 'exit 1')
        path = self.home / '.local/share/ai-memory/config.toml'
        path.parent.mkdir(parents=True)
        path.write_text('embedding_provider = "local"\n')
        result = self.shell('SETUP_COMPONENTS=codex,ai-memory; configurar_memoria_ia')
        self.assertIn('PENDENTE', result.stdout)
