# Contribuir

O repositório é público. As mudanças devem ajudar qualquer pessoa a preparar seu próprio ambiente, sem depender da instalação ou dos dados de um computador específico.

Antes de enviar uma alteração:

- Preserve projetos, configurações pessoais, identidades Git, chaves e dados persistentes.
- Use caminhos relativos ao usuário atual. Não inclua nomes de usuários, caminhos particulares, inventários ou resultados de uma máquina nos arquivos públicos.
- Guarde planos de trabalho, registros de implantação e relatórios individuais em `.local/notes/`, que é ignorado pelo Git.
- Publique instruções gerais, código e testes reproduzíveis. Exemplos devem usar dados fictícios.
- Execute `make test-fast` e confira `git diff --cached` antes do commit. Logs, credenciais, backups e configurações locais não devem entrar no Git, mesmo com `git add -f`.

A CI verifica os caminhos publicados e exige ShellCheck. Mudanças no bootstrap precisam de testes de instalação inicial, repetição e preservação de um clone existente. Os testes de integração Docker usam recursos temporários e não devem modificar containers ou volumes do usuário.

O teste `make test-bootstrap` executa a entrada de instalação em um Ubuntu descartável com usuário não root, sem Git, Python ou curl inicialmente. O sudo sem senha existe somente dentro desse container descartável para preparar os pacotes do teste.
