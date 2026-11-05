# Instruções do projeto

Este repositório é público e serve a usuários diferentes, incluindo iniciantes no WSL.

- Consulte CONTRIBUTING.md antes de preparar commits ou publicações.
- Planos de correção, registros de implantação, inventários, logs e dados de uma máquina devem ficar em .local/notes/ ou no diretório de estado do usuário, nunca no conteúdo publicado.
- Preserve dados e configurações existentes; não use limpeza geral ou git reset para reparar uma instalação.
- Instalação e testes devem usar o usuário atual e diretórios temporários próprios, sem caminhos particulares fixos.
- Mantenha o fluxo padrão simples. Execute make test-fast e os testes de integração afetados antes de concluir.
