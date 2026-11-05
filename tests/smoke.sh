#!/usr/bin/env bash
# ==============================================================================
# meu-setup: tests/smoke.sh
# Smoke tests rápidos: validação de flags CLI, módulos lib/ e geração de templates.
# Execução local rápida (~2 segundos) sem necessidade de container.
# ==============================================================================

set -euo pipefail

DIR_TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR_ROOT="$(cd "$DIR_TESTS/.." && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

falhas=0

asserir() {
    local condicao="$1"
    local mensagem="$2"
    if eval "$condicao"; then
        echo -e "  ${GREEN}✔${NC} $mensagem"
    else
        echo -e "  ${RED}✖ [FALHA]${NC} $mensagem"
        falhas=$((falhas + 1))
    fi
}

echo -e "${BLUE}▶ [1/4] Testando flags de ajuda (--help) de todos os utilitários...${NC}"

# install.sh --help
out_install=$("$DIR_ROOT/install.sh" --help)
asserir '[[ "$out_install" == *"Uso: ./install.sh"* ]]' "install.sh --help exibe guia de uso correto"

# bin/novo-projeto --help
out_novo=$("$DIR_ROOT/bin/novo-projeto" --help)
asserir '[[ "$out_novo" == *"Uso: novo-projeto"* ]]' "novo-projeto --help exibe guia de uso correto"

# bin/atualizar --help
out_update=$("$DIR_ROOT/bin/atualizar" --help)
asserir '[[ "$out_update" == *"Uso: atualizar"* ]]' "atualizar --help exibe guia de uso correto"

# bin/portainer help
out_portainer=$("$DIR_ROOT/bin/portainer" help 2>&1 || true)
asserir 'echo "$out_portainer" | grep -Eqi "portainer.*\[comando\]"' "portainer help exibe guia de uso correto"

echo -e "\n${BLUE}▶ [2/4] Testando isolamento e carregamento de cada módulo em lib/...${NC}"

# Define variáveis necessárias para sourcing isolado
export DIR_SETUP="$DIR_ROOT"
export DIR_LOCAL_BIN="$HOME/.local/bin"
export LOG_DIR="/tmp/meu-setup-test-logs"
export LOG_FILE="$LOG_DIR/test.log"
export LOG_LATEST="$LOG_DIR/latest.log"

for modulo in "$DIR_ROOT/lib/"*.sh; do
    nome_mod=$(basename "$modulo")
    # shellcheck source=/dev/null
    if bash -c "source '$DIR_ROOT/lib/log.sh' && source '$modulo'"; then
        echo -e "  ${GREEN}✔${NC} Módulo carregado com sucesso: $nome_mod"
    else
        echo -e "  ${RED}✖ [FALHA]${NC} Falha ao carregar módulo isolado: $nome_mod"
        falhas=$((falhas + 1))
    fi
done

echo -e "\n${BLUE}▶ [3/4] Testando integridade das funções exportadas...${NC}"

funcoes=(
    "mostrar_banner" "log_info" "log_sucesso" "log_aviso" "log_pulado" "log_erro" "log_secao"
    "verificar_wsl" "checar_sudo" "configurar_wsl_conf" "otimizar_wslconfig" "executar_apt_update" "instalar_pacote_essencial"
    "instalar_starship" "instalar_lazydocker" "instalar_lazygit" "instalar_zoxide" "instalar_bat" "instalar_eza"
    "instalar_node_e_astro" "instalar_python_e_uv"
    "instalar_docker" "preparar_portainer"
    "configurar_git"
    "configurar_bashrc"
    "mostrar_conclusao"
)

# shellcheck source=/dev/null
for f in "$DIR_ROOT/lib/"*.sh; do source "$f"; done

for func in "${funcoes[@]}"; do
    if declare -F "$func" >/dev/null; then
        echo -e "  ${GREEN}✔${NC} Função disponível: $func()"
    else
        echo -e "  ${RED}✖ [FALHA]${NC} Função ausente: $func()"
        falhas=$((falhas + 1))
    fi
done

echo -e "\n${BLUE}▶ [4/4] Testando geração não-interativa de projetos (bin/novo-projeto)...${NC}"

TMP_DIR=$(mktemp -d /tmp/meu-setup-smoke-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

# Teste: Projeto Python
cd "$TMP_DIR"
"$DIR_ROOT/bin/novo-projeto" python test-python-proj >/dev/null 2>&1
asserir '[ -d "$TMP_DIR/test-python-proj" ]' "Diretório do projeto Python foi criado"
asserir '[ -f "$TMP_DIR/test-python-proj/.gitignore" ]' "Arquivo .gitignore do Python foi gerado"
asserir '[ -f "$TMP_DIR/test-python-proj/.env.example" ]' "Arquivo .env.example do Python foi gerado"
asserir '[ -f "$TMP_DIR/test-python-proj/main.py" ] || [ -f "$TMP_DIR/test-python-proj/pyproject.toml" ]' "Código base do projeto Python foi gerado"

# Teste: Projeto Docker Compose
cd "$TMP_DIR"
"$DIR_ROOT/bin/novo-projeto" docker test-docker-stack >/dev/null 2>&1
asserir '[ -d "$TMP_DIR/test-docker-stack" ]' "Diretório do Docker Compose foi criado"
asserir '[ -f "$TMP_DIR/test-docker-stack/docker-compose.yml" ]' "docker-compose.yml com PostgreSQL e Redis foi gerado"
asserir 'grep -q "postgres:16-alpine" "$TMP_DIR/test-docker-stack/docker-compose.yml"' "Serviço Postgres configurado no docker-compose.yml"
asserir 'grep -q "127.0.0.1:5432:5432" "$TMP_DIR/test-docker-stack/docker-compose.yml"' "Serviço Postgres isolado em 127.0.0.1 (Modo Seguro)"
asserir 'grep -q "127.0.0.1:6379:6379" "$TMP_DIR/test-docker-stack/docker-compose.yml"' "Serviço Redis isolado em 127.0.0.1 (Modo Seguro)"

# Teste: Bloqueio de Path Traversal
asserir '! "$DIR_ROOT/bin/novo-projeto" python "../malicioso" >/dev/null 2>&1' "novo-projeto bloqueia nomes com ../ (Path Traversal seguro)"

# Teste: Projeto Node
cd "$TMP_DIR"
"$DIR_ROOT/bin/novo-projeto" node test-node-proj >/dev/null 2>&1
asserir '[ -d "$TMP_DIR/test-node-proj" ]' "Diretório do Node.js foi criado"
asserir '[ -f "$TMP_DIR/test-node-proj/src/index.ts" ]' "Arquivo src/index.ts do Node.js foi gerado"

echo ""
if [ "$falhas" -eq 0 ]; then
    echo -e "${GREEN}=== Todos os Smoke Tests passaram com 100% de sucesso! ===${NC}"
    exit 0
else
    echo -e "${RED}=== $falhas teste(s) falharam no Smoke Test! ===${NC}"
    exit 1
fi
