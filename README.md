# meu-setup

Ambiente de desenvolvimento para quem está começando a criar automações Python, sites Astro e aplicações Node/TypeScript no WSL. Criado para uso pessoal e disponível para quem quiser preparar seu próprio ambiente.

O instalador prepara as ferramentas, corrige configurações antigas reconhecidas e entrega atalhos para o dia a dia. Projetos, bancos, chaves SSH e preferências pessoais são preservados.

## Instalação com um comando

Abra o terminal do **Ubuntu no WSL**, depois de criar seu usuário e sua senha do Linux, e cole:

```bash
bash -c 'set -e; if ! command -v curl >/dev/null || [ ! -s /etc/ssl/certs/ca-certificates.crt ]; then sudo apt-get update; sudo apt-get install -y curl ca-certificates; fi; script=$(curl -fsSL --connect-timeout 10 --max-time 60 --retry 2 https://raw.githubusercontent.com/jjeffersonlima/meu-setup/main/bootstrap.sh); bash -c "$script" -- "$@"'
```

O comando prepara o download mesmo se o `curl` estiver ausente. A entrada [bootstrap.sh](bootstrap.sh) instala os pré-requisitos necessários, obtém o código e abre o menu de instalação. A senha solicitada é a **senha do Linux**. Não é necessário clonar o repositório manualmente.

Antes do menu, pode ser necessário baixar os pré-requisitos e o código. A instalação das ferramentas começa depois da sua escolha.

O código fica em `~/.local/share/meu-setup`. Se você já usa o projeto em outro local registrado, essa instalação é reaproveitada. A pasta permanece no disco porque os atalhos e as atualizações dependem dela. Arquivos pessoais e repositórios com alterações locais não são substituídos.

**Requisitos:** conexão com a internet, Bash (padrão do Ubuntu), usuário Linux com acesso ao `sudo` e distribuição com APT. O ambiente validado é Ubuntu 24.04/26.04 no WSL 2, em x86_64. Os downloads também têm opções ARM64, mas essa arquitetura e outras distribuições APT ainda não foram validadas integralmente.

Se ainda não instalou o WSL, siga a [instalação oficial da Microsoft](https://learn.microsoft.com/en-us/windows/wsl/install). O comando acima deve ser executado no terminal Linux, depois dessa preparação.

## Alternativa: usar um clone

```bash
git clone https://github.com/jjeffersonlima/meu-setup.git
cd meu-setup
./install.sh
```

As duas entradas abrem o mesmo menu:

```text
1. Instalar tudo — padrão
2. Escolher o que instalar
3. Reparar a instalação existente
0. Sair

Escolha [1]:
```

Pressione Enter para instalar todos os componentes da tabela abaixo. A opção 2
permite selecionar grupos por finalidade, digitando seus números separados por
espaço. A opção 3 usa a seleção salva para corrigir a instalação, sem acrescentar
componentes. Sem uma seleção salva, o menu orienta fazer a instalação primeiro.

| Finalidade | Ferramentas |
| --- | --- |
| Sites e aplicativos | fnm, Node.js e pnpm |
| Automações | Python e uv |
| Bancos e containers | Docker Engine, Compose e Lazydocker |
| Painel Docker no navegador | Portainer sob demanda |
| Git e GitHub | Git, GitHub CLI e Lazygit |
| Terminal e navegação | Herdr, Starship, Zoxide, Bat e Eza |
| Agentes de IA e memória | Codex nativo, Claude Code, OpenCode, Antigravity CLI, Vercel Skills e ai-memory |

O reparo reaproveita o código existente, inclusive alterações locais e a branch
atual; não faz fetch nem troca de branch. Use `atualizar` para consultar como
atualizar o clone quando desejar. Uma ferramenta não escolhida não aparece como
defeito no diagnóstico. Mudar a seleção não desinstala ferramentas nem apaga projetos.

Ao terminar, **abra um terminal novo**. Se houver orientação para reiniciar o WSL, salve seu trabalho e execute `wsl --shutdown` no PowerShell do Windows; isso encerra todas as distribuições WSL em execução. O instalador não fecha suas sessões automaticamente. [Configuração do WSL](https://learn.microsoft.com/en-us/windows/wsl/wsl-config).

Os comandos com `./install.sh` pressupõem que você está na pasta indicada ao final da instalação. Em uma instalação nova pelo comando único, use `cd ~/.local/share/meu-setup`.

<details>
<summary>Automação e opções avançadas</summary>

No uso normal, basta abrir o menu. Para scripts e diagnóstico:

```bash
./install.sh --yes                         # Mantém seleção salva; no primeiro uso instala tudo
./install.sh --components node,python,git   # Seleção individual explícita, sem menu
./install.sh --repair --yes                # Repara a seleção salva, sem menu
./install.sh --config-only --user-only     # Somente configurações do usuário
./install.sh --inventory                   # Inventário, sem alterações
./install.sh --help-advanced
```

Sem um terminal, informe uma ação explícita; o instalador não escolhe uma
instalação completa por falta de entrada. Em modo `--yes`, autentique o sudo
antes com `sudo -v`, se necessário. Nenhuma dessas opções autoriza apagar dados.

</details>

## Herdr: terminais e agentes no mesmo lugar

O Herdr faz parte da instalação padrão e do grupo **Terminal e navegação**.
Abra um terminal novo, entre na pasta do projeto e execute:

```bash
herdr
```

Ele organiza projetos em espaços de trabalho (workspaces), com abas e painéis.
Em cada painel, execute seus comandos habituais, como `claude`, `opencode`,
`pnpm dev` ou `git status`. A barra lateral acompanha o estado dos agentes
compatíveis: trabalhando, aguardando intervenção, concluídos ou ociosos.
Clique nos painéis para alternar, arraste as divisórias para redimensionar e
use o botão direito para abrir o menu de ações.
[Primeiros passos oficiais](https://herdr.dev/tui/docs/quick-start/).

### Atalhos básicos

Nos atalhos abaixo, pressione **Ctrl+B**, solte as teclas e depois pressione a
tecla indicada. Por exemplo, para criar uma aba: Ctrl+B, solte, depois `c`.

| Depois de Ctrl+B | Ação |
| --- | --- |
| `c` | Criar aba |
| `v` | Dividir à direita |
| `-` | Dividir abaixo |
| `h`, `j`, `k`, `l` | Mover para esquerda, baixo, cima ou direita |
| `n` / `p` | Próxima aba / aba anterior |
| `w` | Navegar entre espaços de trabalho |
| `Shift+N` | Criar espaço de trabalho |
| `z` | Ampliar o painel atual ou voltar à divisão |
| `[` | Abrir modo de cópia pelo teclado |
| `?` | Mostrar os atalhos ativos |
| `q` | Desconectar e deixar os programas rodando |
| `x` | Fechar o painel atual e encerrar seus processos |

Os atalhos podem ser personalizados; consulte a ajuda dentro do Herdr e a
[documentação de teclado](https://herdr.dev/tui/docs/keyboard/).

### Voltar à sessão e encerrar

**Fechar a janela ou a aba do terminal apenas desconecta do Herdr.** O servidor,
os painéis e os programas continuam em segundo plano, enquanto o WSL estiver
em execução. Isso já é o comportamento padrão do Herdr; não exige configuração
adicional. Vale para comandos iniciados **dentro dos painéis do Herdr**.
[Persistência ao fechar o terminal](https://herdr.dev/tui/docs/quick-start/#detach-and-come-back).

Abra outro terminal e execute `herdr` para voltar à mesma sessão.
**Ctrl+B, depois `q`, também apenas desconecta; não encerra nada.**
Para fechar deliberadamente um painel e seus processos, use **Ctrl+B, depois
`x`**. Os demais painéis continuam rodando. Comandos como `exit`, interrupções
do próprio programa e ações de encerramento pelo menu também podem finalizar
um painel ou seu trabalho; a persistência não bloqueia essas ações.
Para encerrar a sessão padrão e seus processos, salve o trabalho e execute,
no terminal fora do Herdr:

```bash
herdr server stop
```

Essa continuidade depende de o WSL continuar em execução. Desligar o computador
ou executar `wsl --shutdown` encerra os processos Linux; desconectar do Herdr
não protege processos contra esse desligamento.

### Desempenho

O setup instala o Herdr sem iniciá-lo automaticamente ao abrir o Bash e sem
adicionar um serviço de inicialização. Antes do primeiro uso, ele ocupa espaço
em disco, sem acrescentar um processo ao terminal.

Durante o uso, há consumo de CPU e memória pelo cliente, pelo servidor e pelos
programas dos painéis. Muitos painéis, histórico acumulado e saída intensa
podem aumentar esse consumo. Depois de desconectar, o servidor e os programas
continuam usando recursos; encerrar a sessão libera os recursos desses processos.
Não há benchmark deste projeto que quantifique o impacto no WSL ou compare com
o tmux. Use `top` ou `htop`, se disponível, para observar seu próprio fluxo.

Para instalações existentes, adicionar somente o Herdr:

```bash
./install.sh --components herdr
```

Esse comando salva a seleção informada. Para manter todos os componentes do
padrão selecionados, use `./install.sh --full`. O reparo mantém a seleção salva
e não acrescenta componentes novos. Configurações pessoais do Herdr são
preservadas; o guia `atualizar` aponta as releases oficiais.

## Identidade Git para seus primeiros commits

Se ainda não configurou sua identidade, escolha o nome e o e-mail que quer associar aos seus commits:

```bash
git config --global user.name "Seu Nome"
git config --global user.email "voce@exemplo.com"
```

Uma identidade já existente é preservada pelo instalador.

## Agentes de IA, skills e memória entre sessões

A instalação completa inclui os agentes, o gerenciador de skills e a memória local.
Para selecionar outras finalidades, use a opção 2 do menu. Os componentes
individuais continuam disponíveis para automação nas opções avançadas.

O Codex usa o instalador standalone oficial da OpenAI, com executável nativo e
auxiliares, sem npm nem Node. O reparo migra o launcher npm criado pelas versões
anteriores deste setup, mantendo autenticação, configurações e o pacote antigo.
Instalações externas continuam preservadas; para migrá-las, siga o instalador
oficial e confira `command -v codex` antes de remover o pacote anterior.

Somente Vercel Skills inclui Node como dependência. Seu pacote global usa
`~/.local/share/meu-setup/npm`, sem mudar o `.npmrc`, e seu launcher usa o Node
padrão do fnm. As ferramentas ficam disponíveis de qualquer pasta para o usuário
Linux atual. Abra um terminal novo após instalar. OMP não é instalado nem configurado.

O primeiro uso de `codex`, `claude`, `opencode` e `agy` segue a autenticação oficial
de cada ferramenta. Instalar não inclui uma assinatura nem créditos de modelos.

### Atualizar

`atualizar` mostra um guia com os comandos e links oficiais das ferramentas
selecionadas. Ele não consulta versões pela rede e não executa atualizações,
reparos, backups, reinícios ou limpeza. Você escolhe quais comandos executar.
Os atualizadores automáticos próprios das ferramentas continuam funcionando.

Novas instalações de Codex, Skills e ai-memory usam as referências em
`configs/versions.env`. Atualizações são feitas pelo usuário com o mecanismo
oficial de cada ferramenta. No ai-memory, backup é opcional para quem precisa
preservar a possibilidade de voltar de versão após uma migração de dados.
[Guia oficial](https://github.com/akitaonrails/ai-memory/blob/main/docs/install.md).

### Skills globais

O [Vercel Skills](https://github.com/vercel-labs/skills) descobre e instala skills.
O setup instala o gerenciador; escolha as coleções que deseja usar:

```bash
skills find
skills add vercel-labs/agent-skills --global
skills list --global
```

No instalador de skills, selecione seus agentes. A atualização do gerenciador é
separada da atualização das skills: consulte `skills update --help` para selecionar
o escopo global. As skills gerenciadas pelo ai-memory acompanham a própria
integração; não as mantenha simultaneamente por outro gerenciador.

### Memória local

Na seleção individual avançada, inclua ao menos uma das quatro CLIs junto com ai-memory. A configuração usa o
instalador oficial para registrar MCP, hooks e skills globais somente nos agentes
selecionados. É necessário systemd de usuário funcionando no WSL. Se houver
pendência, salve o trabalho, siga a orientação do diagnóstico e execute o reparo
pela opção 3 (Reparar) após abrir uma sessão nova. A falta do serviço de usuário
deixa a memória pendente, sem desfazer as ferramentas já instaladas.

Este perfil requer Python 3.11 ou mais recente (incluído no Ubuntu 24.04/26.04).
O perfil usa embeddings locais `all-MiniLM-L6-v2`, em CPU, com download inicial de
aproximadamente 87 MB, sem API paga, GPU ou Ollama. A configuração nova exige o
modelo local; falha ao baixá-lo deve ser resolvida antes de considerar a busca
vetorial pronta. O modelo é voltado ao inglês; avalie a recuperação das suas notas
em português. [Embeddings locais](https://github.com/akitaonrails/ai-memory/blob/main/docs/local-embeddings.md).

O setup não configura LLM remoto no servidor. Você pode pedir ao agente ativo
para consolidar a sessão: ele lê as observações e grava as páginas usando seu
próprio modelo, consumindo os recursos da sessão. A consolidação autônoma por LLM
no servidor exige configuração separada e não é habilitada pelo setup. Configurações
existentes com provedor remoto são preservadas e precisam de migração explícita
para este perfil. Overrides `AI_MEMORY_*`, além de `AI_MEMORY_DATA_DIR`, precisam
ser revisados antes da configuração.

Reinicie os agentes para carregar as integrações. No Codex, confira `/hooks` e
conceda a confiança solicitada. Para acompanhar um trabalho entre CLIs, dentro do
mesmo projeto, use por exemplo:

```bash
ai-memory run claude
ai-memory run codex
ai-memory status
ai-memory doctor
```

Feche a primeira sessão antes de abrir a seguinte quando quiser passar o mesmo
trabalho de um agente para outro. A instalação é global; a memória continua
separada por projeto. Dados e tokens permanecem no diretório de dados do usuário,
fora do repositório público. O serviço fica em loopback; se a porta estiver ocupada,
revise o serviço existente ou escolha outra porta em `config.toml` e repita o reparo.

O Codex App precisa de validação própria: confirme em qual ambiente o agente
executa e se esse ambiente acessa o MCP do WSL. Configurar o CLI Linux não comprova
a integração do app no Windows. `diagnostico` informa pendências; não inicia serviços.

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
| `atualizar` | Mostra como atualizar cada ferramenta, sem executar alterações |

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

## Consultar os comandos de atualização

```bash
atualizar                    # Mostra instruções conforme a seleção de ferramentas
```

O guia apenas lê a seleção local e imprime os comandos. Ele não verifica se há
versões novas, não usa sudo e não modifica o repositório ou o ambiente. As opções
antigas, como `--yes`, `--system` e `--clean-docker`, mostram uma mensagem de
compatibilidade e também não executam ações.

Para atualizar o código do setup, confira as alterações locais com `git status` e,
se o clone estiver limpo e a branch tiver upstream, execute `git pull --ff-only`
dentro da pasta do projeto. Para reparar, execute `./install.sh` e escolha a opção 3.

A reinstalação comum reaproveita ferramentas saudáveis. Para aplicar as versões
de referência testadas, existe `./install.sh --update-tools`. Node/Python de
projetos existentes não são removidos. Um padrão Node incompatível com os templates
pode ser atualizado, mantendo a versão antiga instalada para seus projetos.

A limpeza Docker é feita pelo próprio Docker, quando desejada; `atualizar` não
remove containers, volumes ou caches. [Documentação Docker](https://docs.docker.com/reference/cli/docker/system/prune/).

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
make test-bootstrap  # Comando único em Ubuntu sem Git/Python/curl; usa rede e Docker
make test-ai         # CLIs reais, servidor e integrações em container, sem login
make e2e             # Instalação e templates reais em Ubuntu descartável; usa rede e Docker
make test-services   # PostgreSQL e Portainer em recursos exclusivos de teste
make test            # Testes locais e integração da instalação
```

A CI exige ShellCheck. Localmente, sua ausência aparece como `NÃO EXECUTADO`. Os testes rápidos não baixam dependências de projetos. A integração inclui instalação, repetição, execução Python/Node, build Astro e validação Compose. Os serviços são testados separadamente, em containers e volume próprios do teste.

Um container comum não comprova systemd, integração Windows ou reinício do WSL. Essas verificações precisam ser feitas na máquina real. O diagnóstico não usa sudo, não repara arquivos e não inicia serviços. Ele distingue falhas, componentes não escolhidos e pendências da sessão.

## Usar em outros computadores

Execute a instalação em cada computador. A seleção de ferramentas, os backups e os limites de recursos pertencem àquela instalação; não copie chaves, bancos ou o diretório de estado de outra pessoa.

Para contribuir, veja [CONTRIBUTING.md](CONTRIBUTING.md). Relatórios de máquinas, planos de trabalho, logs e inventários locais ficam fora do conteúdo publicado.
