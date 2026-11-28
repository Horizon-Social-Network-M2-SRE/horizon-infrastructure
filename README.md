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

`make up-local` expects the repositories **side by side**, in the same parent folder:

```text
horizon/
├── horizon-infrastructure/   ← you are here
├── horizon-backend/
└── horizon-web/
```

Elsewhere? Set `BACKEND_DIR` and `WEB_DIR` in `.env`. If `make up` fails with a 403 from GHCR, the
images are not public yet: use `make up-local`.

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

then `make up-local`. `make up` pulls the `:main` images that the reusable workflows (below) push
to GHCR once backend and web call them.

### Smoke tests

`scripts/smoke-test.sh` checks, through the gateway: api liveness and readiness (MongoDB + Redis),
prefix stripping, `/metrics`, a protected route returning 401, login rejecting an unknown user,
and `/` once the web app runs. It refuses to run if this stack's `gateway` container is not up
(set `BASE_URL` to test another gateway).

## CI

`.github/workflows/compose.yml` validates the Compose files and scripts, then starts the stack
from `horizon-backend` `main` and runs the smoke tests. The job fails if the backend has no Dockerfile.

`.github/workflows/reusable-ci.yml` runs actionlint on every workflow, then calls the reusable
workflows of the same commit against the apps in `tests/fixtures/` (they never push an image).

## Reusable CI workflows (S1-02)

Every code repository gets the same checks by calling one workflow instead of copying a pipeline.

| Workflow | Jobs (check names: `<caller job> / <job>`) |
| --- | --- |
| `python-ci.yml` | `lint` (ruff check + format), `test` (pytest, optional MongoDB/Redis), `secrets` (gitleaks), `image` |
| `node-ci.yml` | `lint`, `test`, `build` (npm scripts), `secrets` (gitleaks), `image` |

`image` builds the Dockerfile, scans it with Trivy and, **only on a push to the default branch and
after every other job passed**, pushes the scanned image as
`ghcr.io/horizon-social-network-m2-sre/<repo>:sha-<commit>` and `:main`. Pull requests build and
scan, never push. The workflow outputs `image`, `tag` and `digest` for later deployment steps.

### Calling them

```yaml
# horizon-backend/.github/workflows/ci.yml
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  ci:
    uses: Horizon-Social-Network-M2-SRE/horizon-infrastructure/.github/workflows/python-ci.yml@main
    permissions:
      contents: read
      packages: write   # always required: the image job asks for it, even when it does not push
    with:
      mongo-image: mongo:7
      redis-image: redis:7
```

```yaml
# horizon-web/.github/workflows/web-ci.yml (same on/permissions)
jobs:
  ci:
    uses: Horizon-Social-Network-M2-SRE/horizon-infrastructure/.github/workflows/node-ci.yml@main
    permissions:
      contents: read
      packages: write
```

### Inputs

| Input | Workflow | Default | Purpose |
| --- | --- | --- | --- |
| `working-directory` | both | `.` | Folder with `pyproject.toml`/`package.json` and the Dockerfile |
| `python-version` | python | `3.13` | |
| `install-command` | python | `pip install -e '.[dev]'` | Installs the project and pytest |
| `ruff-version` | python | `0.17.6` | ruff release; the rules come from the repository's `[tool.ruff]` |
| `ruff-format` | python | `true` | Also run `ruff format --check` |
| `pytest-args` | python | `-ra` | |
| `mongo-image`, `redis-image` | python | empty (no service) | Start the service and export `TEST_MONGODB_URI` (`mongodb://localhost:27017`), `TEST_REDIS_URL` (`redis://localhost:6379/15`) and `REQUIRE_SERVICES=1`. The image must ship `mongosh` / `redis-cli` for the health check |
| `node-version` | node | `22` | |
| `lint-script`, `build-script` | node | `lint`, `build` | npm scripts; must exist; empty skips the job |
| `test-script` | node | `test` | Warns instead of failing while the script does not exist |
| `image` | both | `true` | Build and scan an image |
| `image-name` | both | repository name | Under `ghcr.io/<owner>/` |
| `dockerfile` | both | `Dockerfile` | Relative to `working-directory` |
| `push` | both | `true` | Push on the default branch |
| `trivy-severity` | both | `CRITICAL,HIGH` | Fails on these when a fixed version exists |

### Security choices

- Trivy fails on fixable `CRITICAL`/`HIGH` vulnerabilities only. Accept one with a reason in a
  `.trivyignore` next to the Dockerfile; fix the rest (often by removing `npm`/`pip` from the
  runtime stage, which nothing uses at run time).
- gitleaks scans the whole history (a secret removed later is still leaked). Allow-list a false
  positive by fingerprint in `.gitleaksignore`; rotate a real one.
- Only `actions/*` actions are used. Trivy, gitleaks and actionlint run from images pinned by version
  and digest, and the image pushed is the image scanned (no rebuild).
- Callers pin `@main`: a change here reaches every repository at once, so it is tested by
  `reusable-ci.yml` first and reviewed like code.

### One-time setup (organisation owner)

- **Package visibility**: the first push creates the GHCR package as private. Make
  `horizon-backend` and `horizon-web` public (package settings) so `make up` can pull without logging in.
- **Required checks**: calling the workflow renames the checks. Update each `protect-main` ruleset
  in the same change as the caller, or every pull request waits for checks that no longer report:
  backend `test` becomes `ci / test` (keep `container`), web `Lint and type-check` becomes `ci / lint`
  (keep `Image builds and serves on port 3000`).
