#!/usr/bin/env bash
# Smoke tests for the local stack, through the gateway only (what the browser sees).
# Usage: bash scripts/smoke-test.sh   (BASE_URL overrides http://localhost:$GATEWAY_PORT)
set -uo pipefail

if [[ -z "${GATEWAY_PORT:-}" && -f .env ]]; then
  GATEWAY_PORT="$(sed -n 's/^GATEWAY_PORT=//p' .env)"
fi
BASE_URL="${BASE_URL:-http://localhost:${GATEWAY_PORT:-8080}}"
body="$(mktemp)"
trap 'rm -f "$body"' EXIT
fails=0

check() { # name expected_status method path [contains]
  local name=$1 expected=$2 method=$3 path=$4 contains=${5:-}
  local status
  status=$(curl -s -o "$body" -w '%{http_code}' -X "$method" "$BASE_URL$path" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    ${SMOKE_DATA:+--data "$SMOKE_DATA"})
  if [[ "$status" != "$expected" ]]; then
    echo "FAIL $name: $method $path -> $status (expected $expected)"; fails=$((fails + 1)); return
  fi
  if [[ -n "$contains" ]] && ! grep -q -- "$contains" "$body"; then
    echo "FAIL $name: response does not contain '$contains'"; fails=$((fails + 1)); return
  fi
  echo "ok   $name"
}

echo "Smoke tests against $BASE_URL"
check "api liveness through /api"       200 GET  /api/health '"ok"'
check "api readiness (MongoDB + Redis)"  200 GET  /api/health/ready '"mongodb":"ok"'
check "prefix stripped (no /api/api)"    404 GET  /api/api/health
check "metrics exposed"                  200 GET  /api/metrics 'python_info'
check "protected route needs a token"    401 GET  /api/auth/me
SMOKE_DATA='username=nobody%40horizon.test&password=wrong-password' \
check "login rejects unknown user"       401 POST /api/auth/login

if docker compose ps --services --status running 2>/dev/null | grep -qx web; then
  check "web redirects / to sign-in"     307 GET  /
  check "web serves the sign-in page"    200 GET  /login 'Sign in'
  check "web serves the register page"   200 GET  /register 'Create account'
else
  echo "skip web served on / (web profile not running; S1-10)"
fi

if (( fails > 0 )); then
  echo "$fails smoke test(s) failed"; exit 1
fi
echo "All smoke tests passed"
