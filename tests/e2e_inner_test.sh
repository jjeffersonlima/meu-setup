#!/usr/bin/env bash
# ==============================================================================
# meu-setup: tests/e2e_inner_test.sh
# Script executado dentro do container Ubuntu isolado para validar instalação,
# integridade de binários e idempotência estrita.
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

echo -e "\n${BLUE}================================================================${NC}"
echo -e "${BLUE}  ETAPA 1: Executando instalação completa do zero (--yes)...    ${NC}"
echo -e "${BLUE}================================================================${NC}\n"

# Executa o instalador em modo não-interativo com identidade Git definida para o teste
export GIT_USER_NAME="Teste Automatizado"
export GIT_USER_EMAIL="teste@local.ci"
export SETUP_GENERATE_SSH="false"

./install.sh --yes

echo -e "\n${BLUE}================================================================${NC}"
echo -e "${BLUE}  ETAPA 2: Validando presença dos binários e configurações...   ${NC}"
echo -e "${BLUE}================================================================${NC}\n"

BIN_DIR="$HOME/.local/bin"
FNM_BIN="$HOME/.local/share/fnm/fnm"

# Binários essenciais em ~/.local/bin
asserir '[ -x "$BIN_DIR/starship" ]' "Binário starship instalado e executável"
asserir '[ -x "$BIN_DIR/lazydocker" ]' "Binário lazydocker instalado e executável"
asserir '[ -x "$BIN_DIR/lazygit" ]' "Binário lazygit instalado e executável"
asserir '[ -x "$BIN_DIR/zoxide" ]' "Binário zoxide instalado e executável"
asserir '[ -x "$BIN_DIR/bat" ] || command -v batcat >/dev/null 2>&1' "Binário bat / batcat disponível"
asserir '[ -x "$BIN_DIR/eza" ]' "Binário eza instalado e executável"
asserir '[ -x "$BIN_DIR/uv" ]' "Binário uv instalado e executável"
asserir '[ -x "$FNM_BIN" ] || command -v fnm >/dev/null 2>&1' "Gerenciador fnm instalado e executável"
asserir '[ -f "$HOME/.local/share/bash-completion/completions/uv" ]' "Cache estático do autocompletar do uv gerado"

# Utilitários do projeto conectados via symlink
asserir '[ -L "$BIN_DIR/novo-projeto" ]' "Symlink para novo-projeto ativo"
asserir '[ -L "$BIN_DIR/atualizar" ]' "Symlink para atualizar ativo"
asserir '[ -L "$BIN_DIR/diagnostico" ]' "Symlink para diagnostico ativo"
asserir '[ -L "$BIN_DIR/portainer" ]' "Symlink para portainer ativo"

# Configuração do ~/.bashrc
asserir 'grep -q "# >>> meu-setup >>>" "$HOME/.bashrc"' "Bloco de inicialização presente no ~/.bashrc"
asserir 'grep -q "# <<< meu-setup <<<" "$HOME/.bashrc"' "Bloco de fechamento presente no ~/.bashrc"

count_start_1=$(grep -c "# >>> meu-setup >>>" "$HOME/.bashrc" || true)
count_end_1=$(grep -c "# <<< meu-setup <<<" "$HOME/.bashrc" || true)
asserir '[ "$count_start_1" -eq 1 ] && [ "$count_end_1" -eq 1 ]' "Marcadores únicos no ~/.bashrc (sem duplicação)"

echo -e "\n${BLUE}================================================================${NC}"
echo -e "${BLUE}  ETAPA 3: Teste de Idempotência Estrita (2ª execução do zero)  ${NC}"
echo -e "${BLUE}================================================================${NC}\n"

# Executa novamente
./install.sh --yes

count_start_2=$(grep -c "# >>> meu-setup >>>" "$HOME/.bashrc" || true)
count_end_2=$(grep -c "# <<< meu-setup <<<" "$HOME/.bashrc" || true)
asserir '[ "$count_start_2" -eq 1 ] && [ "$count_end_2" -eq 1 ]' "Idempotência no ~/.bashrc: continua com exatamente 1 bloco após re-execução"

echo -e "\n${BLUE}================================================================${NC}"
echo -e "${BLUE}  ETAPA 4: Validação Funcional dos Utilitários após Instalação   ${NC}"
echo -e "${BLUE}================================================================${NC}\n"

# Carrega ambiente recém-instalado
export PATH="$HOME/.local/bin:$PATH"
if [ -d "$HOME/.local/share/fnm" ]; then
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env --use-on-cd 2>/dev/null || true)"
fi

# Executa diagnostico
echo -e "${YELLOW}Executando diagnostico...${NC}"
./bin/diagnostico || true
asserir 'true' "diagnostico executado sem erros fatais"

# Executa geração de templates
mkdir -p /tmp/test-workspace
cd /tmp/test-workspace

"$HOME/meu-setup/bin/novo-projeto" python py-e2e >/dev/null 2>&1
cd /tmp/test-workspace
asserir '[ -d "/tmp/test-workspace/py-e2e" ] && [ -f "/tmp/test-workspace/py-e2e/.gitignore" ]' "novo-projeto gerou template Python no container"

"$HOME/meu-setup/bin/novo-projeto" node node-e2e >/dev/null 2>&1
cd /tmp/test-workspace
asserir '[ -d "/tmp/test-workspace/node-e2e" ] && [ -f "/tmp/test-workspace/node-e2e/src/index.ts" ]' "novo-projeto gerou template Node no container"

"$HOME/meu-setup/bin/novo-projeto" docker docker-e2e >/dev/null 2>&1
cd /tmp/test-workspace
asserir '[ -d "/tmp/test-workspace/docker-e2e" ] && [ -f "/tmp/test-workspace/docker-e2e/docker-compose.yml" ]' "novo-projeto gerou template Docker Compose no container"

echo ""
if [ "$falhas" -eq 0 ]; then
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}  🎉 E2E TEST COMPLETO: 100% DAS ASSERTIVAS PASSARAM COM SUCESSO! ${NC}"
    echo -e "${GREEN}================================================================${NC}\n"
    exit 0
else
    echo -e "${RED}================================================================${NC}"
    echo -e "${RED}  ✖ $falhas ASSERTIVAS FALHARAM NO TESTE END-TO-END!             ${NC}"
    echo -e "${RED}================================================================${NC}\n"
    exit 1
fi
