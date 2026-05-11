# Operations Runbook

## Current Operating Model

The production surface is intentionally small:

- New API
- PostgreSQL
- Redis
- Caddy in direct-origin mode, or Cloudflare Tunnel in tunnel mode
- Optional internal CPA
- Local PostgreSQL backup, verification, restore, restore drills, and migration scripts

This repository does not run a separate monitoring stack. Use New API's built-in admin views for application-level visibility and wrapper scripts for manual acceptance checks.

## Daily Quick Check

On the production server:

```bash
cd /opt/lihan_ai_deploy/current
docker compose -p lihan_ai --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  -f docker-compose.cloudflare-tunnel.yml \
  ps

COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh
curl -i https://api.lihan3238.com/api/status
```

When CPA is disabled or Cloudflare Tunnel is disabled, omit the matching compose overlay.

## Env Template Sync

Production env lives at:

```text
/opt/lihan_ai_deploy/shared/.env.production
```

Release `prepare` automatically calls `ops/sync-env-template.sh` before preflight. You can also run it manually from a release checkout:

```bash
cd /opt/lihan_ai_deploy/current
bash ops/sync-env-template.sh /opt/lihan_ai_deploy/shared/.env.production .env.production.example
```

Rules:

- A `.bak.<UTC>` backup is created first.
- Missing keys from `.env.production.example` are appended with default values.
- Existing values are never overwritten.
- Deprecated keys are reported but not removed.
- `ops/preflight.sh` still blocks `CHANGE_ME` placeholders.

## Backups

Manual backup:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-postgres.sh
```

Scheduled backup:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-cron.sh
```

Suggested crontab:

```cron
15 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/backup-cron.sh
```

Manual download:

```bash
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump .
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump.sha256 .
```

Restore drill:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<dump>.dump
```

## New API Groups

Keep only:

- `default`: normal friends/users.
- `vip`: manually granted higher-priority or discounted users.

The old `standard` group is not part of the current operating model. This repository does not rewrite production database rows. Use the New API admin console to move users, tokens, channel abilities, model permissions, and pricing from `standard` to `default`; grant `vip` only where intended.

Read-only validation:

```bash
bash ops/validate-ops-profile.sh config/ops-profiles/glm-default.example.json
bash ops/channel-health-advisor.sh config/ops-profiles/glm-default-health.example.json
```

## CPA

CPA stays internal. Do not expose port `8317` publicly.

Temporary UI session:

```bash
cd /opt/lihan_ai_deploy/current
ops/cpa-ui.sh open
ops/cpa-ui.sh ps
```

Local tunnel:

```bash
ssh -L 8317:127.0.0.1:8317 <deploy-user>@<origin-host>
```

Close after use:

```bash
ops/cpa-ui.sh close
```

New API channels should point to the Docker internal CPA address, not to the public domain.

## Deploy Acceptance

After every production promote:

```bash
cd /opt/lihan_ai_deploy/current
readlink -f /opt/lihan_ai_deploy/current
COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh
curl -i https://api.lihan3238.com/api/status
ENV_FILE=.env.production bash ops/backup-cron.sh
```

Then verify in New API:

- Home page opens on the public domain.
- Admin login works.
- `/api/status` returns success.
- A test token can call `/v1/models`.
- CPA channels still use the internal Docker address if CPA is enabled.

## Cleanup Safety

Before archiving old directories such as `/opt/lihan_ai` or `/opt/lihan_ai_runtime`:

- `readlink -f /opt/lihan_ai_deploy/current` points at the intended release.
- Runtime checks pass.
- Backup and restore drill pass.
- `docker inspect relay-cpa` shows no mount source under the old runtime directory.
- No crontab references old paths.

Archive first, delete later:

```bash
sudo mv /opt/lihan_ai /opt/lihan_ai.legacy-$(date +%Y%m%d)
sudo mv /opt/lihan_ai_runtime /opt/lihan_ai_runtime.legacy-$(date +%Y%m%d)
```

Never delete `/opt/containerd`, and never run `docker compose down -v` as cleanup.
