# Reusable CI fixtures

Smallest Python and Node apps that call the reusable workflows, so `.github/workflows/reusable-ci.yml`
proves on every pull request that `python-ci.yml` and `node-ci.yml` run their checks (lint, tests
with a Redis service, build, gitleaks, image build and Trivy scan). They are never pushed to GHCR.
