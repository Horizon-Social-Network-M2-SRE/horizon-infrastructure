#!/usr/bin/env bash
# Local stack helper (S1-09). Works without make (Git Bash on Windows, Linux, macOS, CI).
#   bash scripts/stack.sh env        create .env with a random JWT_SECRET (once)
#   bash scripts/stack.sh up         pull images from GHCR and start, wait until healthy
#   bash scripts/stack.sh up-local   build api/web from BACKEND_DIR/WEB_DIR and start
#   bash scripts/stack.sh test       smoke tests through the gateway
#   bash scripts/stack.sh down | logs | ps | clean
set -euo pipefail

cd "$(dirname "$0")/.."

compose() { docker compose "$@"; }
local_compose() { docker compose -f docker-compose.yml -f docker-compose.build.yml "$@"; }

new_secret() {
  if command -v openssl >/dev/null 2>&1; then openssl rand -hex 32
  else python3 -c 'import secrets; print(secrets.token_hex(32))'
  fi
}

cmd_env() {
  if [[ -f .env ]]; then
    echo ".env already exists (kept)"
    return
  fi
  local secret
  secret="$(new_secret)"
  sed "s|^JWT_SECRET=.*|JWT_SECRET=${secret}|" .env.example > .env
  echo ".env created with a random JWT_SECRET"
}

gateway_url() {
  local port="${GATEWAY_PORT:-}"
  [[ -z "$port" && -f .env ]] && port="$(sed -n 's/^GATEWAY_PORT=//p' .env)"
  echo "http://localhost:${port:-8080}"
}

case "${1:-help}" in
  env) cmd_env ;;
  up)
    cmd_env
    if ! compose pull --ignore-pull-failures; then
      echo "Pulling the images failed. If they are not public on GHCR yet (S1-02), use: bash scripts/stack.sh up-local" >&2
    fi
    if ! compose up -d --wait; then
      echo "Start failed. If the images are missing or private on GHCR, use: bash scripts/stack.sh up-local" >&2
      exit 1
    fi
    echo "Stack ready: $(gateway_url)  (api: /api/health)"
    ;;
  up-local)
    cmd_env
    local_compose up -d --build --wait
    echo "Stack ready (local build): $(gateway_url)"
    ;;
  test) bash scripts/smoke-test.sh ;;
  down) compose --profile "*" down ;;
  logs) compose logs -f --tail=100 ;;
  ps) compose ps ;;
  clean)
    # Removes the containers AND the MongoDB/Redis volumes of this stack only.
    compose --profile "*" down --volumes --remove-orphans
    ;;
  *)
    sed -n '2,8p' "$0"
    ;;
esac
