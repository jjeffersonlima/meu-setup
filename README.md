# meu-setup

Ambiente pessoal de desenvolvimento para estudar e criar automações Python, sites Astro e aplicações Node/TypeScript no WSL com Ubuntu/Debian.

O instalador prepara as ferramentas, corrige configurações antigas reconhecidas e entrega atalhos para o dia a dia. Projetos, bancos, chaves SSH e preferências pessoais são preservados.

## Instalar ou reparar

Dentro da pasta do projeto:

```bash
./install.sh
```

O instalador reconhece a instalação anterior e reaproveita suas escolhas. Você pode executá-lo novamente para reparar os atalhos e a configuração. No primeiro uso, a seleção recomendada inclui as ferramentas da tabela abaixo.

| Finalidade | Ferramentas |
| --- | --- |
| Sites e aplicativos | fnm, Node.js e pnpm |
| Automações | Python e uv |
| Bancos e containers | Docker Engine, Compose e Lazydocker |
| Painel Docker no navegador | Portainer sob demanda |
| Git e GitHub | Git, GitHub CLI e Lazygit |
| Terminal e navegação | Starship, Zoxide, Bat e Eza |

Para escolher as ferramentas:

```bash
./install.sh --custom
```

Exemplo de seleção direta para estudar sites e Python:

```bash
./install.sh --components node,python,git,starship,zoxide
```

Uma ferramenta não escolhida não aparece como defeito no diagnóstico. Mudar a seleção não desinstala ferramentas nem apaga projetos.

Ao terminar, **abra um terminal novo**. Se houver orientação para reiniciar o WSL, salve seu trabalho e execute `wsl --shutdown` no PowerShell do Windows; isso encerra todas as distribuições WSL em execução. O instalador não fecha suas sessões automaticamente. [Configuração do WSL](https://learn.microsoft.com/en-us/windows/wsl/wsl-config).

Outras opções:

```bash
./install.sh --inventory                  # Somente leitura; mostra o estado atual
./install.sh --repair --yes               # Instala/repara usando a seleção anterior
./install.sh --repair --config-only       # Corrige configuração; não instala ferramentas
./install.sh --repair --config-only --user-only  # Corrige somente arquivos do usuário
./install.sh --help
```

A primeira instalação pode solicitar sua senha do Linux para instalar pacotes. Em modo `--yes`, o sudo precisa estar autenticado ou configurado sem senha: use `sudo -v` antes se necessário. Esse modo não autoriza apagar dados.

## Criar e executar um projeto

Digite `novo` para abrir o menu, ou use os exemplos:

| O que criar | Comando | Depois de entrar na pasta |
| --- | --- | --- |
| Automação Python | `novo-projeto python meu-bot` | `uv run main.py` |
| Site Astro | `novo-projeto astro meu-site` | `pnpm dev` |
| Node/TypeScript | `novo-projeto node minha-api` | `pnpm dev` |
| PostgreSQL + Redis | `novo-projeto docker meu-banco` | `docker compose up -d` |

Exemplo completo:

```bash
novo-projeto python meu-bot
cd meu-bot
uv run main.py
uv add requests
```

O gerador recusa um nome já existente, inclusive links. Se uma instalação de dependências falhar, a pasta recém-criada permanece para inspeção e a mensagem informa que ela ainda não está pronta. Escolha outro nome ou revise essa pasta antes de tentar novamente.

O projeto Node oferece `pnpm check` para verificar TypeScript. O projeto Astro oferece `pnpm build` para gerar o site. As versões de referência ficam em [configs/versions.env](configs/versions.env); os projetos gerados mantêm seus próprios arquivos de dependências.

O template Python usa `main.py` explicitamente. Os templates Node/Astro permitem os scripts necessários de `esbuild` e, no Astro, `sharp`, em `pnpm-workspace.yaml`. [Configuração de builds do pnpm](https://github.com/pnpm/pnpm.io/blob/main/docs/settings/build.md).

No Docker, cada projeto ganha sua senha PostgreSQL no arquivo `.env`, que não entra no Git. Se uma porta estiver ocupada, altere `POSTGRES_PORT` ou `REDIS_PORT` nesse arquivo. Não há nomes globais fixos de containers. Use `docker compose down` para parar os serviços; os dados PostgreSQL permanecem no volume do projeto.

## Atalhos do dia a dia

| Comando | Função |
| --- | --- |
| `doctor` ou `diagnostico` | Verifica as ferramentas escolhidas e aponta a próxima ação |
| `code .` | Abre a pasta no VS Code, quando o comando `code` está instalado |
| `open .` | Abre a pasta no Explorer do Windows |
| `novo-python meu-bot` | Cria diretamente uma automação Python |
| `novo-astro meu-site` | Cria diretamente um site Astro |
| `lg` | Abre o Lazygit |
| `ld` | Abre o Lazydocker |
| `ll` | Lista arquivos com detalhes |
| `tree` | Mostra a árvore de arquivos |
| `bat arquivo` | Mostra o arquivo com destaque de sintaxe |
| `z nome` | Navega para uma pasta conhecida pelo Zoxide |
| `ports` | Mostra portas em uso |
| `atualizar` | Atualiza o setup e repara a instalação |

## Portainer sob demanda

```bash
portainer             # Inicia em http://localhost:9000
portainer token       # Mostra o token de primeiro acesso, quando aplicável
portainer status      # Mostra estado e portas sem iniciar o serviço Docker
portainer stop        # Para o painel; preserva os dados
portainer repair      # Corrige configuração antiga mantendo o estado ligado/parado
portainer reset       # Recria o container; preserva volume, contas e stacks
portainer --lan       # Expõe o painel na rede local
```

O primeiro acesso mantém a proteção do setup token. O modo padrão limita as portas a `127.0.0.1`. O container usa `--restart=no`. O serviço Docker mantém sua configuração de boot existente; você pode escolher `./install.sh --docker-boot on` ou `./install.sh --docker-boot off`. A reinstalação não remove volumes. Quando o Docker está acessível, corrige configurações antigas reconhecidas do painel, mantendo-o parado se já estava parado. Um painel em execução pode ser recriado brevemente para aplicar o reparo. [Setup token do Portainer](https://docs.portainer.io/faqs/installing/setup-token).

O reset reutiliza a imagem do container existente, evitando mudar a versão da base de dados durante um reparo. Uma instalação nova usa a imagem definida em `configs/versions.env`. Atualizações de versão do Portainer exigem avaliar a compatibilidade da base de dados.

`portainer stop-all` para **todos** os containers, inclusive os de outros projetos. O serviço Docker e o WSL podem continuar consumindo recursos depois disso; o comando não promete devolver toda a memória ao Windows.

## Atualizar sem perder trabalho

```bash
atualizar                    # Busca a branch atual e repara o ambiente
atualizar --yes               # Mesmo fluxo, sem prompts; sem limpeza automática
atualizar --system            # Também atualiza os pacotes APT
atualizar --no-repo           # Mantém o checkout atual; não busca pela rede
```

Alterações locais são preservadas: nesse caso, a atualização remota é pulada com uma mensagem. Uma branch sem upstream também é preservada. O atualizador usa somente avanço direto da branch atual, sem trocar para `main` ou tentar um merge alternativo.

Ferramentas anteriores às versões de referência são atualizadas; versões mais novas e funcionais são preservadas. A reinstalação comum reaproveita ferramentas saudáveis. Node/Python de projetos existentes não são removidos. Um padrão Node incompatível com os novos templates pode ser atualizado, mantendo a versão antiga instalada para os seus projetos.

Limpeza de containers/caches é uma ação separada:

```bash
atualizar --clean-docker
```

Esse comando mostra o que está em uso e exige digitar `LIMPAR` no terminal. `--yes` não substitui essa confirmação. Containers parados e cache de build podem conter trabalho útil. [Docker system prune](https://docs.docker.com/reference/cli/docker/system/prune/).

## O que o reparo faz com instalações antigas

O setup reconhece os blocos históricos no `.bashrc`, cópias antigas dos seus utilitários e links antigos ou quebrados. Eles são migrados para um único bloco que carrega `~/.config/meu-setup/shell.bash` e para os links do checkout atual.

As assinaturas históricas são distribuídas em `configs/legacy-utilities.json`, permitindo reparar também clones sem o histórico Git completo. Blocos incompletos e arquivos desconhecidos não são apagados: o reparo informa a pendência e interrompe a etapa antes de substituir esses arquivos.

O reparo edita as entradas necessárias do WSL, preservando memória, CPU, swap, rede e outras preferências. Não escolhe um perfil Windows por aproximação. Se a integração não conseguir identificá-lo, o arquivo Windows é preservado e a mensagem explica o motivo.

Personalizações do prompt e a identidade Git são preservadas. Os padrões do ignore global são acrescentados ao arquivo do setup; se você usa outro ignore global, sua escolha continua ativa.

Arquivos pessoais que uma instalação antiga já apagou só podem ser recuperados quando existe uma cópia. Backups antigos não são restaurados automaticamente, pois poderiam trazer os erros de volta.

## Logs e recuperação

Os registros ficam em:

```text
~/.local/state/meu-setup/
  inventory.json       inventário da última instalação
  state.json           seleção e versão da configuração concluída
  logs/                até 20 logs de instalação
  backups/index.json   origem e versões dos backups
  backups/objects/     conteúdo verificado dos arquivos anteriores
```

Somente o usuário tem acesso ao diretório de estado. Backups são deduplicados por conteúdo e só são criados antes de alterações. Uma repetição saudável não acumula novos backups de configuração. Eles não são carregados pelo terminal e não são apagados automaticamente.

Para restaurar a primeira configuração preservada do Bash, dentro do repositório:

```bash
python3 -B lib/config.py restore "$HOME/.bashrc"
```

Use `--revision N` para escolher outra versão listada no índice, começando em zero. A restauração verifica o conteúdo do backup. Após restaurar, abra uma nova sessão. Restaurar uma configuração antiga pode também restaurar seus problemas; o reparo continua disponível depois disso.

## Testes

```bash
make test-fast       # Sintaxe, ShellCheck quando disponível, regressões sem rede/sudo
make e2e             # Instalação e templates reais em Ubuntu descartável; usa rede e Docker
make test-services   # PostgreSQL e Portainer em recursos exclusivos de teste
make test            # Testes locais e integração da instalação
```

A CI exige ShellCheck. Localmente, sua ausência aparece como `NÃO EXECUTADO`. Os testes rápidos não baixam dependências de projetos. A integração inclui instalação, repetição, execução Python/Node, build Astro e validação Compose. Os serviços são testados separadamente, em containers e volume próprios do teste.

Um container comum não comprova systemd, integração Windows ou reinício do WSL. Essas verificações precisam ser feitas na máquina real. O diagnóstico não usa sudo, não repara arquivos e não inicia serviços. Ele distingue falhas, componentes não escolhidos e pendências da sessão.

## Duas máquinas

Aplique primeiro em uma máquina, confira seus projetos e rode o instalador novamente para verificar estabilidade. Depois use a mesma revisão na segunda, com inventário e backups próprios. Cada máquina mantém sua seleção, limites de recursos e dados.

O roteiro e o registro da implantação ficam em [docs/IMPLANTACAO.md](docs/IMPLANTACAO.md). O plano original está em [PLANO-DE-CORRECAO.md](PLANO-DE-CORRECAO.md).
