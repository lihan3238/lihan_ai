# Phase 1 New API Validation Runbook

This runbook validates the first paid API relay milestone using upstream New API only. Do not fork relay, billing, auth, or payment code during this phase.

## Goal

Run a local WSL/Docker New API instance at `http://localhost:3100` and prove the core business loop:

- Admin setup and persistent login configuration.
- One GPT channel in a `standard` pool.
- One test user and one API token.
- Manual balance or package crediting.
- Non-stream and stream OpenAI-compatible requests.
- Usage logs, quota deduction, and failed-request refund behavior.
- PostgreSQL backup before and after configuration.

Claude remains a second-priority channel after GPT is validated. Automatic payment remains out of scope.

## Preconditions

Run commands from WSL or a Linux shell at the repository root.

```bash
git status --short
git submodule status --recursive
bash ops/preflight.sh
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml ps
curl -fsS http://localhost:3100/api/status
```

Expected baseline:

- Git status is clean except for intentional local edits.
- `vendor/new-api` is pinned to the expected upstream commit.
- `new-api`, `postgres`, and `redis` are healthy.
- `/api/status` returns JSON with `"success":true`.

If `bash ops/preflight.sh` reports `CHANGE_ME`, replace every placeholder value in `.env`. Comments containing `CHANGE_ME` do not count as placeholders.

## Backup Before Configuration

Create and verify a PostgreSQL backup before changing admin settings:

```bash
bash ops/backup-postgres.sh
bash ops/verify-postgres-backup.sh backups/postgres/<backup>.dump
```

Keep `.env` with the backup. PostgreSQL contains users, tokens, channels, settings, logs, wallet records, and subscriptions; `.env` contains the secrets required to reuse that state.

## Admin Initialization

Open `http://localhost:3100`.

If New API asks for initialization, follow the upstream prompt and create the root/admin user. This is safe in local development. The account and configuration are stored in PostgreSQL and survive container restarts and normal container deletion.

Safe restart commands:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml restart new-api
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml down
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml up -d new-api
```

Do not run:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml down -v
```

`down -v` deletes the PostgreSQL and Redis Docker volumes and erases local New API state.

## Security Settings Checklist

In the New API admin console, configure the local test instance for small-scope operation:

- Registration: disabled, invitation-only, or admin-created users. Do not leave open public registration for paid testing.
- Email/OAuth: leave disabled unless you are actively testing that login path.
- Tokens: require explicit model limits for test users.
- Sensitive key display: keep upstream secure verification behavior enabled.
- User status: verify disabled users cannot call APIs.
- Payment: keep automatic payment disabled in Phase 1.

Record any setting that is missing or unclear in a gap list before proposing code changes.

## GPT Standard Pool

Create one GPT channel using official OpenAI API or an explicitly authorized aggregator.

Recommended first configuration:

- Group: `standard`.
- Models: start with one low-cost GPT model, for example `gpt-4o-mini`, then add higher-cost models only after billing is verified.
- Channel priority/weight: keep simple with one active standard channel.
- Model mapping: use upstream defaults unless the provider requires mapping.
- Group/model ratio: set deliberately and document the intended sell price.

Run the New API channel test from the admin console. Do not add an `economy` pool until a second, lower-cost, authorized source exists. Economic supply must not be silently mixed into `standard`.

## User, Token, And Manual Credit

Create a normal test user and one API token.

For the token:

- Assign group `standard`.
- Limit allowed models to the GPT model under test.
- Set an expiration date if the console supports it.
- Keep IP allowlist empty for local testing unless you are explicitly testing IP restrictions.

Credit the user manually from the admin console. Use wallet/top-up or subscription/package features only through New API's built-in UI. If the native subscription flow cannot exactly represent a 30-day expiring quota package, write that down as a Phase 1 gap instead of adding custom tables.

## API Smoke Test

After creating a token, run:

```bash
export NEW_API_TEST_TOKEN="sk-..."
export NEW_API_TEST_MODEL="gpt-4o-mini"
bash ops/phase1-smoke-test.sh
```

The script always checks `/api/status`. With `NEW_API_TEST_TOKEN`, it also checks:

- `GET /v1/models`.
- Non-stream `POST /v1/chat/completions`.
- Stream `POST /v1/chat/completions`.

If the script fails, inspect New API usage logs and container logs:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml logs --tail=200 new-api
```

## Relay Diagnostics

When a coding client or upstream adapter behaves differently from the basic smoke test, run the broader relay diagnostic:

```bash
export NEW_API_TEST_TOKEN="sk-..."
export NEW_API_TEST_MODEL="glm-5.1"
bash ops/relay-diagnostics.sh
```

Model names are case-sensitive. Use the exact model name shown in New API's channel and model list; for the current direct GLM channel this is `glm-5.1`, not `GLM-5.1`.

The diagnostic checks:

- New API `/api/status`.
- OpenAI-compatible `/v1/models`.
- OpenAI-compatible chat, non-stream and stream.
- Anthropic-compatible `/v1/messages`, non-stream and stream.
- Anthropic-compatible `/v1/messages?beta=true` stream, which is commonly used by Claude Code style clients.
- Anthropic token counting via `/v1/messages/count_tokens?beta=true`, reported as a warning if unsupported.

Use this before changing New API code. If OpenAI-compatible tests pass but Anthropic-compatible stream tests fail, the likely problem is protocol conversion or upstream streaming behavior. If all relay paths fail, inspect token, user quota, model routing, and channel status first.

## Billing And Log Reconciliation

After successful calls, verify in the admin console:

- User quota decreased by the expected amount.
- Token used quota increased.
- Channel used quota and request count increased.
- Usage log includes model, group, channel, prompt tokens, completion tokens, and charged quota.
- Failed requests are refunded or do not consume final quota.

For a failure-path test, temporarily use a token with insufficient quota or disable the channel, then call the API again. Re-enable the channel immediately after the test.

## API And Billing E2E

Before changing channel config, model names, client routing, or New API image versions, run the API plus billing E2E against a low-quota test token:

```bash
export NEW_API_TEST_TOKEN="sk-..."
export NEW_API_TEST_MODEL="glm-5.1"
bash ops/e2e-api-billing.sh
```

Defaults:

- `NEW_API_BASE_URL`: `http://localhost:${NEW_API_DEV_PORT:-3100}`.
- `NEW_API_TEST_MODEL`: `glm-5.1`.
- `NEW_API_TEST_MAX_TOKENS`: `24`.

The script calls real upstream APIs and can consume a small amount of quota. It checks OpenAI-compatible chat and Anthropic-compatible messages in non-stream and stream modes, then reconciles PostgreSQL `users`, `tokens`, `channels`, and `logs`.

Expected result is zero FAIL lines. A WARN for `failure db error log` is acceptable with current upstream New API behavior: route misses such as `No available channel for model ...` are written to the container log, but may not be persisted as database error logs. The E2E still requires the failed request to return an error and confirms user, token, and channel used quota do not increase.

If it fails, check:

- Token exists in New API and has enough quota.
- Model casing exactly matches the channel model, for example `glm-5.1`.
- Channel is enabled and includes the user's group.
- Stream failures reproduce in `bash ops/relay-diagnostics.sh`.
- Database accounting is not still settling from previous long-running stream requests.

## Cache And Cost Observation

For GPT first-pass validation, only observe upstream/New API fields. Do not rewrite prompts and do not build response caching.

Check whether logs expose:

- Cached prompt tokens.
- Cache read or cache creation fields.
- Cache ratio or tiered billing metadata.
- Actual charged quota after cache-aware pricing.

If GPT cache fields are not visible enough for business reporting, record that as a candidate Phase 1.5 customization.

## Backup After Configuration

After channel, user, token, and billing tests are configured, create another backup:

```bash
bash ops/backup-postgres.sh
```

Verify the newest dump:

```bash
bash ops/verify-postgres-backup.sh backups/postgres/<newest-backup>.dump
```

Do not test restore against the active paid-test database unless you intend to overwrite it. Restore drills should use a separate Docker project or temporary machine.

## Phase 1 Exit Criteria

Phase 1 is complete when all of these are true:

- Local New API stays initialized after restart.
- GPT standard channel works for non-stream and stream calls.
- A normal user's API token can call only allowed models.
- Manual crediting and quota deduction are visible and reconcilable.
- Failure paths do not silently consume quota.
- Usage logs expose enough data for manual cost/revenue review.
- A pre-configuration and post-configuration PostgreSQL backup exist and are readable.
- All upstream gaps are documented before any source-code customization is proposed.
