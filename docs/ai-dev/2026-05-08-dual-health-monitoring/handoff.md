# Handoff

## Current State
Dual health monitoring is implemented as wrapper-only tooling. Internal health is a read-only SQL advisor; public health is Uptime Kuma documentation and optional Caddy example.

## Important Context
The advisor must not print secrets or call real upstream completions. The active Caddyfile remains unchanged so missing `STATUS_DOMAIN` cannot break existing deployments.

## Verification
Initial red test failed because `ops/channel-health-advisor.sh` did not exist.

Passed:

```bash
bash tests/channel-health-advisor.test.sh
bash tests/wrapper-infra.test.sh
bash ops/ai-dev-check.sh docs/ai-dev/2026-05-08-dual-health-monitoring
bash -n ops/channel-health-advisor.sh tests/channel-health-advisor.test.sh
bash tests/spec-kit-init.test.sh
bash tests/e2e-api-billing.test.sh
bash tests/ops-profile.test.sh
bash tests/ai-dev-check.test.sh
bash ops/preflight.sh
./scripts/verify-repo.ps1
docker compose --env-file .env.example config
git diff --check
```

Real read-only local check initially ran:

```bash
bash ops/channel-health-advisor.sh config/ops-profiles/glm-standard-health.example.json
```

It returned `FAIL enabled channels` because the local database had no enabled `standard` + `glm-5.1` channel ability at that moment. After channel groups were updated, the advisor found `cpa_glm` under `standard`.

Health algorithm was then relaxed for setup-stage noise:

- `mode: development` tolerates absolute error count and latency breaches as warnings.
- `mode: production` still fails on absolute error count and latency breaches.
- Error rate only fails when sample size and minimum error-count gates are satisfied.

## Remaining Work
Use `mode: development` while wiring channels and clients. Create a stricter production profile before paid public traffic.

## Risks
Full production gate is expected to require real `NEW_API_TEST_TOKEN` and `CONFIG_SNAPSHOT_GPG_RECIPIENT`; this feature's local tests avoid those dependencies. The Uptime Kuma public status page is not exposed until the status Caddy example is manually merged into the production Caddyfile.
