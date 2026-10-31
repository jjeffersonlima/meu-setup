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
| **Controle de Versão** | **Git + GitHub CLI (`gh`)** | Branch padrão `main`, `.gitignore` global e geração opcional de chave SSH Ed25519. |
| **CLI Essentials** | `curl`, `git`, `jq`, `fzf`, `ripgrep`, `build-essential` | Utilitários fundamentais para inspecionar APIs, buscar código e compilar pacotes. |
| **Utilitário de Projetos**| **`novo-projeto`** (alias: `novo`) | Gerador interativo para criar novos sites em Astro, scripts de automação Python ou Docker Compose. |

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

### 5. Atalhos Úteis no Terminal

| Atalho | O que faz |
| :--- | :--- |
| `novo` | Abre o assistente interativo para criar novos projetos (Astro, Python, Node, Docker) |
| `ll` | Lista arquivos detalhadamente com permissões e tamanho formatado (`ls -lah`) |
| `update` | Atualiza a lista de pacotes e o sistema operacional Ubuntu (`apt update && upgrade`) |
| `ports` | Mostra quais portas locais estão abertas (ex: 3000, 4321, 5432, 8080) |
| `myip` | Exibe o endereço IP interno da sua máquina WSL |
| `open .` | Abre a pasta atual do Linux diretamente no Windows Explorer |
| `code .` | Abre a pasta atual diretamente no VS Code conectado ao WSL |

---

### 6. Dicas Úteis do WSL

- **Acessar arquivos do Windows no WSL:** Estão localizados em `/mnt/c/Users/SeuUsuario/`.
- **Melhor desempenho de disco:** Mantenha sempre seus projetos dentro da home do Linux (ex: `~/projetos/`), e **não** dentro de `/mnt/c/`. O sistema de arquivos nativo do Linux no WSL é até 10x mais rápido!
- **Reiniciar o WSL (se necessário):** Abra o PowerShell do Windows e digite:
  ```powershell
  wsl --shutdown
  ```
  Depois abra o terminal do Ubuntu novamente.
