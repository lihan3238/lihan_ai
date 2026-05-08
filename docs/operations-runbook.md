# Operations Runbook

## First Deployment

1. Work from WSL Ubuntu 24.04 or the Linux VPS shell.
2. Copy `.env.example` to `.env`.
3. Replace all `CHANGE_ME` values with generated secrets.
4. Set `DOMAIN` and `ACME_EMAIL`.
5. Run `bash ops/preflight.sh`.
6. Run `docker compose up -d`.
7. Open the site, create the admin user, and disable public self-serve access until invite rules are configured.

## WSL Network Proxy

If package downloads or image pulls require the local Windows proxy, set it only in the current WSL shell:

```bash
export host_ip="$(grep nameserver /etc/resolv.conf | awk '{print $2}')"
export http_proxy="http://$host_ip:10808"
export https_proxy="$http_proxy"
```

Do not put local proxy values into `.env`, `docker-compose.yml`, or committed config files.

## New User Flow

1. Issue an invite code to a known user.
2. User registers with email.
3. Admin confirms payment manually.
4. Admin grants the selected monthly quota package.
5. User creates an API key and selects standard or economy models.

## Channel Setup

Configure GLM, DeepSeek, GPT, and Claude channels in New API. Use `config/model-catalog.example.json` as the operating policy source. Keep standard and economy channels in separate groups. Never place unproven low-cost channels in the default group.

## Daily Checks

- New API health endpoint is up.
- PostgreSQL and Redis containers are healthy.
- Upstream provider balances are above alert thresholds.
- Error rate and failed relay count are not increasing.
- Economy channels are not leaking traffic into standard routes.
- Last database backup exists and is restorable.

## Incident Response

For suspected billing, payment, or provider failure incidents: disable the affected channel or payment path first, export the relevant logs, then reconcile user balances. Do not delete failed orders or usage logs; mark them with an administrative note.
