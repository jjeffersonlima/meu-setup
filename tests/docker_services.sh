#!/usr/bin/env bash
# Integração real em recursos exclusivos do teste; não toca em containers do usuário.
set -Eeuo pipefail
DIR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work=$(mktemp -d)
export SETUP_HOME="$work/home" SETUP_STATE_DIR="$work/state" SETUP_NO_BROWSER=true
export SETUP_PORTAINER_NAME="meu-setup-test-$$" SETUP_PORTAINER_VOLUME="meu-setup-test-data-$$"
# Portas do teste não substituem o painel do usuário. O Docker detecta conflitos.
export SETUP_PORTAINER_HTTP_PORT=19090 SETUP_PORTAINER_HTTPS_PORT=19449
postgres="meu-setup-test-pg-$$"
cleanup() {
    docker rm -f "$SETUP_PORTAINER_NAME" "$postgres" >/dev/null 2>&1 || true
    docker volume rm "$SETUP_PORTAINER_VOLUME" >/dev/null 2>&1 || true
    rm -rf "$work"
}
trap cleanup EXIT
mkdir -p "$SETUP_HOME"
# Faz pull explícito para registrar falhas de rede antes de alterar recursos do teste.
timeout 300 docker pull postgres:16-alpine >/dev/null
docker run -d --name "$postgres" --label io.meu-setup.test=true -e POSTGRES_PASSWORD=senha_apenas_de_teste postgres:16-alpine >/dev/null
ready=false
for _ in {1..30}; do
    if docker exec "$postgres" pg_isready -U postgres >/dev/null 2>&1; then ready=true; break; fi
    sleep 1
done
[ "$ready" = true ]
"$DIR_ROOT/bin/portainer" start
printf 'dados persistentes de teste\n' > "$work/sentinel"
docker cp "$work/sentinel" "$SETUP_PORTAINER_NAME:/data/sentinel"
"$DIR_ROOT/bin/portainer" reset
docker cp "$SETUP_PORTAINER_NAME:/data/sentinel" "$work/restored"
cmp "$work/sentinel" "$work/restored"
"$DIR_ROOT/bin/portainer" status
"$DIR_ROOT/bin/portainer" stop
echo 'Integração de serviços aprovada: PostgreSQL respondeu e dados do Portainer sobreviveram ao reset.'
