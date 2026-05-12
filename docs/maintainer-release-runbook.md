# Maintainer Release Runbook

This runbook is the stable operating path for a formal release. It keeps GitHub Actions as a no-secret validation layer and leaves production promotion to the operator.

## Daily Operations

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/relayctl.sh status
```

For routine maintenance:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/relayctl.sh maintain
```

`maintain` runs verified backup, storage pruning, and runtime health checks.

## Local Release Check

Run from the development machine before opening or merging a release PR:

```bash
bash ops/relayctl.sh release-check
```

This runs the no-secret repository gates, scans for tracked runtime artifacts and sensitive patterns, verifies ignored local AI notes, and runs local New API E2E.

If the local restored New API stack is intentionally unavailable:

```bash
SKIP_LOCAL_E2E=1 bash ops/release-readiness.sh
```

Only skip local E2E with a written reason in the PR or release handoff.

## Deploy

```bash
git fetch origin
git switch main
git pull --ff-only origin main

DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/relayctl.sh deploy-prepare
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/relayctl.sh deploy-smoke
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/relayctl.sh deploy-promote
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/relayctl.sh deploy-status
```

After promotion, check production runtime:

```bash
cd /opt/lihan_ai_deploy/current
COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

## Recovery

If SSH drops during promotion:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/relayctl.sh deploy-status
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/relayctl.sh recover
```

If a promoted release must be rolled back:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/relayctl.sh rollback <release-id>
```

## Release Rules

- `main` is production.
- GitHub Actions must not SSH to production or read production secrets.
- Production `promote` is manual.
- Backups are local server files and must not be committed.
- `docs/ai-dev/` is local working context and must remain ignored.
- Use official `calciumion/new-api:latest` by default; patched local images are temporary rollback paths only.
