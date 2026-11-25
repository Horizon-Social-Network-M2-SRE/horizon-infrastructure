# horizon-infrastructure

Local stack, CI workflows, Helm chart, observability and SLOs for **Horizon Social Network**.

## Local stack (Docker Compose, S1-09)

One command starts the gateway, the api, MongoDB and Redis (and the web app once it exists).

```bash
make up          # pull images from GHCR, start, wait until healthy
make up-local    # build api/web from ../horizon-backend and ../horizon-web instead
make test        # smoke tests through the gateway
make logs | make ps | make down
make clean       # also deletes the MongoDB/Redis volumes of this stack
```

No `make` (e.g. Windows)? Every target works with `bash scripts/stack.sh <target>` (Git Bash).

The first run creates `.env` from `.env.example` with a random `JWT_SECRET`. `.env` is git-ignored.

| URL | Goes to |
| --- | --- |
| http://localhost:8080/ | web (Next.js), profile `web` |
| http://localhost:8080/api/... | api, with `/api` stripped (`/api/health` → `/health`) |
| http://localhost:8080/ws | api WebSocket (S3) |

Only the gateway publishes a port. **If 8080 is already used** (Jenkins, another proxy...), set
`GATEWAY_PORT=8081` (or any free port) in `.env`, then `make down && make up`: otherwise the
gateway cannot bind and `make test` stops with "gateway container is not running". Debug the data
stores with `docker compose exec mongo mongosh` or `docker compose exec redis redis-cli`.

The gateway is Traefik with the same routes as the Kubernetes Ingress, so the refresh cookie
path (`/api/auth`) and same-origin calls behave like in the cluster.

### Using a local build of one service

```bash
# .env
BACKEND_DIR=../horizon-backend   # any checkout or branch
COMPOSE_PROFILES=web             # once horizon-web has a Dockerfile (S1-10)
```

then `make up-local`. Until the S1-02 workflows publish images to GHCR, use `make up-local`.

### Smoke tests

`scripts/smoke-test.sh` checks, through the gateway: api liveness and readiness (MongoDB + Redis),
prefix stripping, `/metrics`, a protected route returning 401, login rejecting an unknown user,
and `/` once the web app runs. It refuses to run if this stack's `gateway` container is not up
(set `BASE_URL` to test another gateway).

## CI

`.github/workflows/compose.yml` validates the Compose files and scripts, then starts the stack
from `horizon-backend` `main` and runs the smoke tests. The job fails if the backend has no Dockerfile.
