# Uptime Kuma Public Status Runbook

This project uses Uptime Kuma for the user-facing status page and keeps detailed channel diagnostics in wrapper scripts. The public page should be simple and should not expose upstream provider names, channel IDs, costs, balances, API keys, token names, or internal error messages.

## Public Components

Create a public status page in Uptime Kuma with these components:

- API Gateway
- GLM Standard
- Account & Billing
- Maintenance Notice

Use short incident messages. Good public text says "GLM Standard is degraded" or "API Gateway is recovering". Do not mention the failing upstream channel, supplier account, balance, quota source, or internal stack trace.

## Recommended Monitors

Configure monitors manually in Uptime Kuma first. Keep any test API token inside the Kuma volume, not in git.

- `API Gateway`: HTTP keyword monitor for `http://new-api:3000/api/status`, keyword `"success":true`.
- `GLM Standard`: HTTP monitor for `http://new-api:3000/v1/models` with a low-quota test token, checking that `glm-5.1` is visible.
- `Account & Billing`: manual monitor or maintenance note until paid-user billing is validated enough for automated checks.
- `Maintenance Notice`: manual status entry for planned maintenance.

Only add a real chat-completion probe if you accept small recurring token cost. Keep the prompt short and the token quota low.

## Internal Ops Monitors

Create a separate internal status page group for production operations. This group is meant for operators, not for the public status page:

- `Runtime`: Push monitor receiving `MONITOR_PUSH_RUNTIME_URL`.
- `Backup`: Push monitor receiving `MONITOR_PUSH_BACKUP_URL`.
- `Offsite`: Push monitor receiving `MONITOR_PUSH_OFFSITE_URL`.
- `Audit`: Push monitor receiving `MONITOR_PUSH_AUDIT_URL`.
- `Restore Drill`: Push monitor receiving `MONITOR_PUSH_RESTORE_DRILL_URL`.

Store the Push URLs only in `.env.production` or inside Kuma. The monitor wrapper sends `status=up|down`, a short `msg`, and a `ping` duration; it must not include API tokens, restic passwords, webhook URLs, provider names, or backup filenames.

New API can continue to read the Uptime Kuma status page group through its existing dashboard integration for high-level red/green state. Detailed backup inventory, restore-drill age, disk pressure, container health, and cron freshness live in the local Ops Dashboard generated under `logs/ops-health/`.

## Publishing With Caddy

The base `Caddyfile` does not publish Kuma by default. To expose a status subdomain:

1. Add `STATUS_DOMAIN=status.example.com` to `.env` on the server.
2. Copy the status block from `Caddyfile.status.example` into the production `Caddyfile`, or replace the active Caddyfile with a merged version containing both the API domain and the status domain.
3. Point the status domain DNS record to the VPS.
4. Restart Caddy:

```bash
docker compose --env-file .env up -d caddy
```

5. Open `https://$STATUS_DOMAIN` and set the public entry page in Uptime Kuma to the status page, not the admin dashboard, if you do not want the dashboard to be the first page visitors see.

## Operator Diagnostics

Before changing channels or posting a public incident, run:

```bash
bash ops/channel-health-advisor.sh config/ops-profiles/glm-standard-health.example.json
```

Use the advisor output for internal decisions. Translate it into a short user-facing status update.

## Local Port

Use local host port `3011` for Kuma on this workstation because `3001` may already be used by other Docker projects.

On production, temporarily open the admin UI only on the server loopback interface:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/kuma-ui.sh open
ENV_FILE=.env.production bash ops/kuma-ui.sh ps
```

From your local machine, forward the loopback port:

```bash
ssh -L 3011:127.0.0.1:3011 <deploy-user>@<origin-host>
```

Open `http://127.0.0.1:3011`. When finished, close the temporary UI binding:

```bash
ENV_FILE=.env.production bash ops/kuma-ui.sh close
```

`ops/kuma-ui.sh` uses `docker-compose.kuma.ui.yml`, binds only `127.0.0.1:${KUMA_PORT:-3011}`, recreates only `uptime-kuma`, and does not use `--remove-orphans`.

For local workstation testing without the helper:

```powershell
$env:KUMA_PORT="3011"
docker compose --env-file .env -f docker-compose.yml up -d uptime-kuma
```
