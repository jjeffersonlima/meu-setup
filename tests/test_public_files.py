"""Proteção dos arquivos publicados, sem depender de dados de uma instalação."""
import unittest
from public_files import is_private, public_files


class PublicationTest(unittest.TestCase):
    def test_current_sources_are_public(self):
        self.assertTrue(public_files())

    def test_local_records_and_credentials_are_rejected(self):
        for name in ('PLANO-DE-CORRECAO.md', 'docs/IMPLANTACAO.md', '.local/notes/relatorio.md',
                     '.aws/credentials', 'logs/install.log', 'backups/bashrc', '.env', '.env.local', 'key.pem', 'id_ed25519'):
            with self.subTest(name=name):
                self.assertTrue(is_private(name))

    def test_general_instructions_examples_and_tests_are_allowed(self):
        for name in ('README.md', 'CONTRIBUTING.md', 'AGENTS.md', '.github/workflows/ci.yml',
                     'templates/.env.example', 'tests/test_setup.py'):
            with self.subTest(name=name):
                self.assertFalse(is_private(name))


if __name__ == '__main__':
    unittest.main(verbosity=2)
