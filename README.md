# 🛠️ meu-setup

> Ambiente de desenvolvimento moderno, leve e idempotente para **WSL (Windows Subsystem for Linux)**, projetado especificamente para quem quer construir **automações**, **sites (com Astro)**, **aplicativos** e **sistemas**.

---

## 🎯 Por que este setup?

- **Agnóstico e Limpo:** Funciona no WSL 2 e WSL 3 sobre distribuições baseadas em Ubuntu/Debian.
- **100% Idempotente:** Pode rodar o instalador quantas vezes quiser. O que já estiver instalado ou configurado é detectado e pulado sem duplicar nada nem quebrar seus arquivos.
- **Desempenho Máximo:** Usa ferramentas modernas escritas em Rust (`uv`, `fnm`, `starship`, `ripgrep`) em vez de ferramentas legadas lentas, garantindo que o terminal abra instantaneamente.
- **Docker Nativo:** Utiliza o Docker Engine via `systemd` dentro do WSL, sem a necessidade ou o consumo excessivo de memória do Docker Desktop no Windows.

---

## 📦 O que está incluído?

| Categoria | Ferramenta | Descrição |
| :--- | :--- | :--- |
| **Terminal / Prompt** | **[Starship](https://starship.rs/)** | Prompt ultra-rápido com indicação visual de Git, Node, Python e tempo de execução. |
| **Node.js & Web** | **[fnm](https://github.com/Schniz/fnm) + [pnpm](https://pnpm.io/)** | Gerenciador de versões de Node.js ultra-rápido + pnpm (padrão oficial recomendado para **Astro**). |
| **Python & Automações** | **[uv (Astral)](https://docs.astral.sh/uv/)** | Gerenciador de Python e pacotes 10-100x mais rápido que pip/pyenv. Cria ambientes virtuais instantaneamente. |
| **Containers & Bancos** | **Docker Engine + Compose** | Rodando nativamente com `systemd`, com permissão configurada para rodar sem `sudo`. |
| **Docker Visual** | **[Lazydocker](https://github.com/jesseduffield/lazydocker) (`ld`)** | Interface TUI ultraleve no terminal com suporte a mouse, logs em tempo real e monitoramento de CPU/RAM. |
| **Docker Web (Stacks)** | **[Portainer CE](https://www.portainer.io/)** | Painel web sob demanda em `http://localhost:9000` para subir e gerenciar Stacks completas. |
| **Git Visual** | **[Lazygit](https://github.com/jesseduffield/lazygit) (`lg`)** | Interface visual no terminal para commits, diffs e push sem precisar memorizar comandos complexos. |
| **Navegação Rápida** | **[Zoxide](https://github.com/ajeetdsouza/zoxide) (`z`)** | Navegação inteligente em Rust: pula para pastas de projetos digitando só parte do nome. |
| **Leitura de Código** | **[Bat](https://github.com/sharkdp/bat)** | Substituto do `cat` em Rust com destaque de sintaxe colorida e números de linha. |
| **Listagem Moderna** | **[Eza](https://github.com/eza-community/eza) (`ll`, `tree`)** | Substituto do `ls` em Rust com ícones, status do Git e visão em árvore. |
| **Controle de Versão** | **Git + GitHub CLI (`gh`)** | Branch padrão `main`, `.gitignore` global e geração opcional de chave SSH Ed25519. |
| **CLI Essentials** | `curl`, `git`, `jq`, `fzf`, `ripgrep`, `build-essential` | Utilitários fundamentais para inspecionar APIs, buscar código e compilar pacotes. |
| **Utilitário de Projetos**| **`novo-projeto`** (alias: `novo`) | Gerador interativo para criar novos sites em Astro, scripts de automação Python ou Docker Compose. |
| **Manutenção Contínua** | **`atualizar`** (ou `update`) | Atualiza sistema, uv, pnpm, starship, o repositório meu-setup e faz faxina segura de disco. |
| **Diagnóstico & Saúde** | **`diagnostico`** (ou `doctor`) | Varredura de integridade de todos os componentes com tabela visual e auditoria baseada em logs. |

---

## 🚀 Como Instalar

Abra o terminal do seu WSL e execute:

```bash
cd ~/projetos/meu-setup
./install.sh
```

O instalador apresentará um menu inicial:
1. **Instalação Completa Recomendada:** Executa todo o processo e instala todo o stack automaticamente.
2. **Instalação Personalizada:** Pergunta passo a passo `[S/n]` para cada componente.

Ao terminar, recarregue seu terminal:
```bash
source ~/.bashrc
```

---

## 📚 Cheatsheet: Comandos do Dia a Dia

### 1. Criar Novos Projetos Facilmente (`novo`)

Basta digitar `novo` no terminal e escolher:
```bash
novo
```
Ou usar os atalhos diretos:
- **Site com Astro:** `novo-astro` ou `pnpm create astro@latest meu-site`
- **Automação Python:** `novo-python`

---

### 2. Desenvolvendo Sites com Astro 🌐

Para criar e testar um site Astro:

```bash
# 1. Criar novo site
pnpm create astro@latest meu-site-astro

# 2. Entrar na pasta
cd meu-site-astro

# 3. Iniciar o servidor de desenvolvimento
pnpm dev

# 4. Abrir no navegador: http://localhost:4321
```

---

### 3. Criando Automações com Python & `uv` 🐍

O `uv` gerencia pacotes e ambientes virtuais de forma instantânea sem poluir seu sistema operacional:

```bash
# 1. Criar uma pasta de projeto
mkdir automacao-web && cd automacao-web

# 2. Inicializar o projeto
uv init

# 3. Adicionar bibliotecas que você precisa (ex: requests, beautifulsoup4, httpx)
uv add requests beautifulsoup4

# 4. Rodar seu script (o uv executa automaticamente dentro do ambiente virtual isolado!)
uv run main.py
```

---

### 4. Bancos de Dados e Docker 🐳

Com o Docker nativo configurado via systemd, você não precisa de `sudo docker`:

```bash
# Verificar status do docker
docker ps

# Subir um banco de dados PostgreSQL rápido:
docker run -d --name meu-postgres -e POSTGRES_PASSWORD=senha -p 5432:5432 postgres:16-alpine

# Ver containers rodando
docker ps

# Parar o container
docker stop meu-postgres
```

Se criar um projeto Docker via comando `novo`, basta rodar:
```bash
docker compose up -d    # Sobe banco e serviços em segundo plano
docker compose logs -f  # Acompanha os logs
docker compose down     # Para os serviços
```

---

### 5. Docker Visual no Terminal com Lazydocker (`ld`) 📊

Chega de memorizar comandos longos do Docker ou esperar o Docker Desktop abrir no Windows. Com o **Lazydocker**, você tem uma interface visual completa diretamente no terminal:

```bash
# Abrir o painel visual
ld
# ou
lazydocker
```

**Principais recursos:**
- **Navegação com Mouse:** Você pode clicar nos containers, abas e botões diretamente na tela do terminal.
- **Gráficos em Tempo Real:** Acompanhe o uso de CPU e Memória de cada container instantaneamente.
- **Logs ao Vivo:** Selecione qualquer container para rolar pelos logs com as setas do teclado ou mouse.
- **Ações Rápidas de Teclado:**
  - `d` -> Parar/remover container ou serviço
  - `s` -> Parar container
  - `r` -> Reiniciar container
  - `m` -> Ver logs completos
  - `e` -> Abrir o shell interativo (`sh`/`bash`) dentro do container
  - `q` -> Sair do Lazydocker

---

### 6. Docker Web com Portainer CE (Sob Demanda) 🌐

Se você prefere a praticidade de **subir Stacks colando arquivos Compose no navegador**, o setup inclui o **Portainer CE** configurado em modo **Sob Demanda** (zero consumo de memória em segundo plano quando não estiver em uso):

```bash
# Iniciar o Portainer e abrir no navegador do Windows automaticamente:
portainer

# Verificar status do Portainer e containers em execução:
portainer status

# Desligar o Portainer para liberar a memória RAM:
portainer stop

# Modo "Liberar Tudo": pausa o Portainer E todos os containers ativos (ideal antes de jogar):
portainer stop-all
```

**Principais recursos:**
- **URL Direta:** Abre em `http://localhost:9000` sem avisos de certificado SSL.
- **Persistência Segura:** Utiliza o volume permanente `portainer_data` para guardar senhas e stacks para sempre.
- **Sem Inicialização no Boot:** Criado com `--restart=no` para nunca ligar sozinho consumindo recursos do seu PC.
- **Stop Geral (`portainer stop-all`):** Um comando único que pausa todos os containers ativos e devolve 100% da RAM e CPU ao Windows.

---

### 7. Git Visual no Terminal com Lazygit (`lg`) 🌿

Assim como o Lazydocker cuida dos containers, o **Lazygit** permite gerenciar todo o fluxo do Git sem comandos complicados:

```bash
# Abrir o painel visual do Git
lg
# ou
lazygit
```

**Principais recursos:**
- **Navegação com Teclas ou Mouse:** Clique nos arquivos alterados para ver o diff em cores.
- **Stage e Unstage:** Pressione `Espaço` em cima de um arquivo (ou linha) para preparar para o commit.
- **Commit Rápido:** Pressione `c`, digite a mensagem e dê Enter.
- **Push para o GitHub:** Pressione `P` (Shift + P) para enviar seus commits.
- **Pull de Atualizações:** Pressione `p` (minúsculo) para baixar alterações.
- `q` -> Sair do Lazygit.

---

### 8. Navegação e Produtividade em Rust (`z`, `bat`, `ll`, `tree`) ⚡

Ferramentas modernas escritas em Rust, que rodam instantaneamente com **zero consumo de memória em segundo plano**:

#### 🏃‍♂️ Navegação Inteligente com Zoxide (`z`)
Esqueça comandos longos como `cd ~/projetos/automacoes/scripts`. O Zoxide aprende quais pastas você frequenta:
```bash
# Pular direto para a pasta do setup de qualquer lugar:
z setup
# Pular para um projeto de site:
z astro
# Abrir busca visual interativa com setas:
zi
```

#### 📖 Leitura Colorida de Código com Bat (`bat`)
Para visualizar arquivos de código ou configuração formatados e com números de linha diretamente no terminal:
```bash
bat package.json
bat install.sh
```

#### 📁 Listagem Moderna de Arquivos com Eza (`ll` e `tree`)
Substituto do `ls` com destaque de cores por tamanho, ícones e status de Git:
```bash
# Listagem detalhada com status do Git ao lado de cada arquivo:
ll

# Visualização de pastas e subpastas em formato de árvore:
tree
```

---

### 9. Manutenção & Atualização Contínua (`atualizar`) 🔄

Para manter todo o seu ecossistema de desenvolvimento sempre rápido, seguro e sem arquivos órfãos ocupando espaço no WSL, basta rodar um único comando:

```bash
atualizar
```

**O que o comando faz automaticamente:**
1. Atualiza e aplica patches no Ubuntu (`apt update && apt upgrade -y`).
2. Remove pacotes órfãos e limpa o cache do APT (`autoremove` e `clean`) para economizar espaço de disco do WSL.
3. Atualiza o gerenciador Python `uv` para a versão mais recente (`uv self update`).
4. Atualiza o gerenciador Node `pnpm` globalmente.
5. Atualiza o **Lazydocker**, **Lazygit**, **Zoxide**, **Bat**, **Eza** e verifica o **Starship**.
6. Executa `git pull` no seu repositório `meu-setup` para puxar novos utilitários e atualizações.
7. Atualiza a imagem do **Portainer CE** caso esteja presente.
8. Pergunta de forma segura se você deseja fazer uma faxina no Docker (`docker system prune`).
9. Mostra um relatório final com o espaço em disco liberado.

---

### 10. Diagnóstico de Saúde & Auditoria (`diagnostico` ou `doctor`) 🩺

Para garantir total transparência e nunca ficar em dúvida se alguma ferramenta falhou ao instalar ou parou de funcionar, o setup inclui um sistema de diagnóstico completo:

```bash
diagnostico
# ou
doctor
```

**O que o comando avalia:**
- **WSL Systemd:** Valida se o suporte a serviços nativos está ativo.
- **CLI Essentials:** Checa ferramentas fundamentais (`git`, `curl`, `jq`, `fzf`, `ripgrep`, `build-essential`).
- **Starship Prompt:** Valida presença e versão do prompt.
- **Node.js, pnpm & fnm:** Checa versões ativas do motor JavaScript.
- **Python & uv:** Valida a presença do ambiente moderno da Astral.
- **Docker Engine & Daemon:** Testa se o Docker está instalado, se o Compose v2 funciona e se o daemon está respondendo.
- **Permissões de Usuário:** Verifica se seu usuário está no grupo `docker` para rodar sem `sudo`.
- **Lazydocker & Lazygit:** Confirma a prontidão dos painéis visuais de terminal.
- **Portainer CE (Web):** Verifica se o gerenciador web sob demanda está disponível ou ativo.
- **Zoxide, Bat & Eza:** Valida os utilitários de alta performance em Rust.
- **Git & Chave SSH:** Verifica identidade global e presença de chave Ed25519.
- **Symlinks Locais:** Garante que todos os executáveis estão linkados em `~/.local/bin/`.

#### 📄 Logs Completos de Instalação (Audit Trail)
Todas as instalações geram um log detalhado gravado automaticamente em:
```bash
# Ver o último log de instalação executado:
cat ~/.local/state/meu-setup/logs/install_latest.log
```
Se qualquer pacote ou etapa falhar, o instalador aponta a falha na tabela final e indica exatamente onde no log você pode ver o erro retornado pelo sistema.

---

### 11. Atalhos Úteis no Terminal

| Atalho | O que faz |
| :--- | :--- |
| `portainer` | Inicia o Portainer CE e abre a interface web em `http://localhost:9000` |
| `portainer stop` | Desliga o Portainer e libera a memória RAM |
| `portainer stop-all`| Pausa **todos os containers ativos** para devolver 100% da RAM/CPU ao Windows |
| `portainer status` | Exibe o estado do Portainer e containers em execução |
| `ld` | Abre o painel visual do Docker (**Lazydocker**) no terminal |
| `lg` | Abre o painel visual do Git (**Lazygit**) no terminal |
| `z <pasta>` | Pula direto para uma pasta de projeto aprendida (ex: `z setup`, `z astro`) |
| `zi` | Abre a busca interativa de pastas com setas de teclado do Zoxide |
| `bat <arquivo>`| Exibe arquivos de código ou texto com destaque de sintaxe e paginação |
| `ll` | Listagem moderna de arquivos com status do Git e ícones (**Eza**) |
| `tree` | Visualiza árvore de pastas e arquivos no terminal |
| `novo` | Abre o assistente interativo para criar novos projetos (Astro, Python, Node, Docker) |
| `atualizar` / `update` | Atualização completa de APT, uv, pnpm, starship, ferramentas Rust/Go e repositório |
| `diagnostico` / `doctor`| Varredura completa da saúde e versões de todas as ferramentas do ambiente |
| `ports` | Mostra quais portas locais estão abertas (ex: 3000, 4321, 5432, 8080) |
| `myip` | Exibe o endereço IP interno da sua máquina WSL |
| `open .` | Abre a pasta atual do Linux diretamente no Windows Explorer |
| `code .` | Abre a pasta atual diretamente no VS Code conectado ao WSL |

---

### 12. Dicas Úteis do WSL

- **Acessar arquivos do Windows no WSL:** Estão localizados em `/mnt/c/Users/SeuUsuario/`.
- **Melhor desempenho de disco:** Mantenha sempre seus projetos dentro da home do Linux (ex: `~/projetos/`), e **não** dentro de `/mnt/c/`. O sistema de arquivos nativo do Linux no WSL é até 10x mais rápido!
- **Reiniciar o WSL (se necessário):** Abra o PowerShell do Windows e digite:
  ```powershell
  wsl --shutdown
  ```
  Depois abra o terminal do Ubuntu novamente.
