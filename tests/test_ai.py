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

    def test_new_default_excludes_ai_and_normalize_accepts_individual_components(self):
        result = self.shell('setup_python components')
        self.assertNotIn('codex', result.stdout)
        result = self.shell('setup_python normalize --components codex,codex,antigravity,ai-memory')
        self.assertEqual(result.stdout.strip(), 'codex,antigravity,ai-memory')

    def test_native_existing_install_is_not_adopted(self):
        self.stub('codex', 'echo "codex 1.0.0"')
        self.shell('setup_ai_install codex; setup_ai_update codex')
        self.assertFalse((self.home / '.local/state/meu-setup/ai-tools.json').exists())

    def test_broken_existing_install_is_not_overwritten(self):
        self.stub('claude', 'exit 1')
        before = (self.mock / 'claude').read_bytes()
        self.shell('setup_ai_install claude', ok=False)
        self.assertEqual(before, (self.mock / 'claude').read_bytes())

    def test_native_updaters_are_not_run(self):
        self.stub('claude', 'exit 99')
        self.stub('agy', 'exit 99')
        self.shell('setup_ai_update claude; setup_ai_update antigravity')

    def test_managed_opencode_uses_native_upgrade(self):
        self.stub('opencode', 'if [ "$1" = --version ]; then echo 1.2.3; else echo "$*" > "$HOME/upgrade"; fi')
        self.shell('setup_ai_state record opencode "$(command -v opencode)"; setup_ai_update opencode')
        self.assertEqual((self.home / 'upgrade').read_text().strip(), 'upgrade')

    def test_update_does_not_touch_replacement_install(self):
        self.stub('codex', 'echo 1.0.0')
        self.shell('setup_ai_state record codex /old/location; setup_ai_update codex')
        self.assertIn('/old/location', (self.home / '.local/state/meu-setup/ai-tools.json').read_text())

    def test_npm_prefix_is_stable_and_npmrc_preserved(self):
        self.stub('node', 'echo v26.13.0')
        self.stub('npm', '''if [ "$1" = --version ]; then echo 11.0.0; exit; fi
[ "$1" = install ] && [ "$2" = --global ] && [ "$3" = --prefix ]
mkdir -p "$4/bin"
printf '#!/bin/bash\\necho 1.7.6\\n' > "$4/bin/skills"
chmod +x "$4/bin/skills"''')
        npmrc = self.home / '.npmrc'
        npmrc.write_text('prefix=/personal/prefix\n')
        self.shell('setup_ai_install skills; setup_ai_state owned skills "$(command -v skills)"')
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

    def test_failed_update_is_reported_and_other_tools_continue(self):
        self.stub('codex', 'echo 1.0.0')
        self.stub('skills', 'echo 1.0.0')
        result = self.shell('''SETUP_COMPONENTS=codex,skills
SETUP_UPDATE_AI=true
setup_ai_update() { echo "attempt:$1"; [ "$1" != codex ]; }
instalar_ferramentas_ia''', ok=False)
        self.assertIn('attempt:skills', result.stdout)

    def test_config_only_never_downloads_ai_tools(self):
        result = subprocess.run([str(REPO / 'install.sh'), '--yes', '--config-only', '--user-only',
                                 '--components', 'codex,skills'], cwd=self.root, env=self.env,
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        saved = json.loads((self.home / '.local/state/meu-setup/state.json').read_text())
        self.assertEqual(saved['components'], ['codex', 'skills', 'node'])
        self.assertFalse((self.home / '.local/share/meu-setup/npm').exists())
