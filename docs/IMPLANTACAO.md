# Correção e validação da instalação pessoal

Data: 5 de novembro de 2026.

## Resultado nesta máquina

A correção foi implementada e o reparo aplicado ao ambiente existente. A segunda máquina ficou fora desta execução por decisão do usuário; poderá receber a mesma versão manualmente.

| Etapa | Situação |
| --- | --- |
| Inventário e recuperação | Inventário registrado; backups anteriores verificados por conteúdo; restauração exercitada nos testes. |
| Proteção de dados e erros | Falhas propagadas; gerador recusa destinos existentes; atualização não apaga containers/caches automaticamente. |
| Migração de versões anteriores | Bloco Bash substituído por carregamento único; utilitários e configuração verificados; assinaturas de cópias históricas distribuídas. |
| Uso para estudo | Atalhos corrigidos; templates Python, Node e Astro executados; Compose validado. |
| Rapidez e manutenção | Ferramentas existentes reaproveitadas; versões de referência fixadas; downloads limitados; caches úteis preservados. |
| Validação | Sintaxe, ShellCheck, regressões locais, instalação completa em Ubuntu descartável, serviços isolados e uso real nesta máquina. |
| Aplicação local | Reparo realizado e repetido; arquivos e índice de backups permaneceram estáveis na reexecução. |

O diagnóstico final desta máquina retornou **zero falhas e zero pendências**. O fluxo completo de reinstalação também foi executado com sucesso, reaproveitando os componentes existentes. systemd e Docker estavam ativos. O Node e os gerenciadores necessários aos templates funcionaram sem alterar versões dos projetos existentes.

## Verificações realizadas

- 30 testes locais de regressão, sem rede, sudo ou daemon Docker.
- Sintaxe Bash e Python e análise estática com ShellCheck 0.11.0.
- Instalação completa em Ubuntu 24.04 descartável, sem modificar a instalação do host.
- Reexecução do instalador no container, com comparação das configurações.
- Execução Python e Node/TypeScript, build Astro e validação Compose no container.
- PostgreSQL respondendo em container exclusivo do teste.
- Dados de teste do Portainer preservados após recriação do container.
- Criação e execução de projetos temporários Python e Node, build Astro e validação Compose nesta máquina WSL com Ubuntu 26.04.1.
- Nova execução do reparo local sem mudanças nos arquivos corrigidos nem no índice de backups.
- Shell gerenciado carregado em processos novos; `code` e `novo-python` definidos como funções que recebem argumentos.

O carregamento do bloco gerenciado do Bash levou aproximadamente **55 ms** de mediana em dez execuções nesta máquina. Esse valor não representa a abertura inteira do Windows Terminal ou a inicialização do WSL.

Os testes locais incluem falha de APT, falha ao criar backup, backup corrompido, interrupção e retomada, marcadores incompletos, cópias históricas de utilitários, preservação de arquivos pessoais, destinos existentes, dependências Node com erro, atualização e proteção do armazenamento do Portainer.

O ShellCheck foi extraído em uma pasta temporária para a validação; não foi instalado via APT nesta máquina. A CI instala e exige a ferramenta. Uma execução local futura sem ShellCheck indicará a etapa como não executada.

## Portainer existente

A inspeção encontrou o painel parado, com portas publicadas em todas as interfaces e a opção antiga `--no-setup-token`.

Antes da correção, foi feita uma cópia dos dados em:

```text
~/.local/state/meu-setup/backups/portainer-pilot-before-repair/
```

O reparo manteve a **mesma imagem e o mesmo volume**, removeu a desativação do token e vinculou as portas 9000 e 9443 a `127.0.0.1`. O painel permaneceu **parado**, com `restart=no`.

Os oito arquivos de dados foram comparados com o backup e permaneceram iguais. Repetir o instalador depois da correção manteve o mesmo container, sem recriá-lo novamente.

## Recuperação

Os backups de configuração e seu índice ficam em:

```text
~/.local/state/meu-setup/backups/
```

O índice registra os caminhos originais, o conteúdo anterior ou o alvo do link, as permissões e o checksum dos arquivos. Conteúdos iguais são reaproveitados. Os backups ficam fora dos caminhos carregados pelo terminal.

Para restaurar a primeira versão preservada do Bash, dentro do repositório:

```bash
python3 -B lib/config.py restore "$HOME/.bashrc"
```

Essa operação pode reintroduzir a configuração anterior. Use o índice para escolher outra revisão com `--revision N`. A restauração não substitui os dados dos seus projetos nem desfaz atualizações de pacotes do sistema.

## Uso imediato

Abra um terminal novo e execute:

```bash
doctor
novo
```

Exemplos:

```bash
novo-python meu-bot
cd meu-bot
uv run main.py
```

```bash
novo-astro meu-site
cd meu-site
pnpm dev
```

Para usar o painel Docker:

```bash
portainer
```

O Portainer continua sob demanda. Não é necessário iniciá-lo para usar Python, Node ou Astro.

## Aplicar depois na outra máquina

Atualize o clone existente pelo GitHub. Como alternativa, transfira a versão corrigida completa para a pasta do projeto, preservando o diretório `.git` existente. O pacote de transferência preparado nesta execução contém somente o código, configurações, templates, testes e documentação; não contém backups, credenciais ou dados desta máquina.

Na outra máquina:

```bash
cd ~/projetos/meu-setup
git pull --ff-only
./install.sh --inventory
./install.sh --repair
```

Abra um terminal novo e confira:

```bash
doctor
./install.sh --repair --config-only
```

A segunda execução deve manter a configuração estável. Caso apareça uma pendência ou falha, resolva a indicação antes de considerar a migração concluída. Cada máquina terá seus próprios backups e seleção de componentes.

Enquanto houver alterações locais, `atualizar` preservará essas alterações e informará que a atualização remota foi ignorada. Resolva essas alterações antes de atualizar o clone manualmente.

## Limites desta validação

Foram validados Ubuntu 24.04 em container e Ubuntu 26.04.1 no WSL desta máquina. Outras versões e distribuições não foram exercitadas nesta execução. A identificação correta do perfil Windows e a inicialização via systemd foram conferidas localmente; o container não é apresentado como prova dessas funções.

Uma instalação antiga que já apagou um arquivo pessoal só pode ter esse conteúdo recuperado se houver backup. Arquivos desconhecidos e configurações pessoais ambíguas são preservados e apresentados para revisão. Os arquivos de recuperação mantidos no disco não são configurações ativas nem processos em segundo plano.
