# Spec

## Goal
Make development handoffs precise about what was actually verified, especially for API billing, database accounting, browser UI, and local service ports.

## Success Criteria
- Developers can run one command to detect local New API and Uptime Kuma port conflicts before assuming a service is available.
- Developers can run live API/DB billing E2E by token name without printing the token.
- Project docs clearly distinguish static/unit checks, live API/DB E2E, interactive browser validation, and future Playwright automation.
- Every future final response and handoff records automatic verification, live E2E, browser validation, skipped checks, and manual Web testing steps.

## Scope
In scope: wrapper scripts, script tests, workflow docs, handoff template, README/runbook updates, and repo verification gates.

Out of scope: installing Playwright, changing New API source, changing `.env`, automating Uptime Kuma UI configuration, or running production deployment.

## Interfaces
- `bash ops/check-local-ports.sh`
- `bash ops/live-e2e-billing-from-db-token.sh <token-name>`
- `NEW_API_TEST_TOKEN_NAME=<token-name> bash ops/live-e2e-billing-from-db-token.sh`
- `NEW_API_ENV_FILE=<path>` for tests or non-default env files.
- `KUMA_PORT=3011` as the recommended local default when host port `3001` is already taken.

## Data
The scripts read `.env` and PostgreSQL through Docker Compose. They do not write database rows, config files, secrets, or New API settings. The live billing wrapper passes the token only to the child E2E process environment.

## Failure Modes
- Missing `.env` produces a clear failure.
- Occupied ports produce `FAIL` with the variable name and owner hint.
- Missing token name exits before querying the database.
- Unknown token name fails without printing any token-like value.
- Live E2E may spend a small amount of upstream quota and must remain explicit.
