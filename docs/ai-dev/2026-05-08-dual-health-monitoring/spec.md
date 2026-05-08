# Spec

## Goal
Provide dual health monitoring: detailed operator diagnostics for GLM standard-pool channels and a simple Uptime Kuma public status-page workflow for users.

## Success Criteria
- `bash ops/channel-health-advisor.sh config/ops-profiles/glm-standard-health.example.json` gives clear `PASS/WARN/FAIL` output without mutating New API state.
- The advisor reports enabled channel capacity, disabled channels, recent sample size, error rate, recent errors, per-channel latency, channel-test age, usage samples, and recommendations.
- Uptime Kuma runbook explains how to publish a simple status page without committing secrets or exposing provider/channel internals.
- Repository verification includes the new script, profile, test, and runbook.

## Scope
In scope: wrapper script, health profile, shell tests, docs, optional production gate wiring, and Caddy status example.

Out of scope: New API source changes, database schema changes, automatic channel disable/enable, automatic Kuma monitor creation, and real token-consuming probes by default.

## Interfaces
- `bash ops/channel-health-advisor.sh config/ops-profiles/glm-standard-health.example.json`
- `OPS_HEALTH_PROFILE_FILE=<profile> bash ops/production-gate.sh`
- `Caddyfile.status.example` for optional `STATUS_DOMAIN` status-page publishing.

## Data
The advisor reads `.env`, profile JSON, PostgreSQL `channels`, `abilities`, and `logs`. It writes no New API data. Kuma monitor configuration is stored in the existing `uptime_kuma` Docker volume when configured manually in the UI.

## Failure Modes
Missing profile, invalid JSON, missing required fields, missing env file, missing `jq`, or non-JSON database output fail fast. Insufficient log samples are a warning. Missing enabled channel capacity or unhealthy error thresholds fail.
