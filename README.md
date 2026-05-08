# AI API Relay V1

This repository is a deployable starter for a small, paid AI API relay built on New API. It targets invite-only users, monthly quota packages, balance-based token billing, standard/economy channel pools, manual payment confirmation, and upstream prompt-cache observability.

## Boundaries

- Use official APIs, authorized aggregators, or explicitly resale-allowed capacity only.
- Do not use subscription account pools, OAuth bridges, reverse-engineered clients, or shared personal plans as upstream supply.
- Keep unstable low-cost supply in the `economy` pool. Do not silently route standard users to it.
- Phase one payments are manually confirmed. Automatic payment webhooks require the controls in `docs/payment-safety.md`.

## Quick Start

1. Use WSL Ubuntu 24.04 or a Linux VPS shell.
2. Install Docker and Docker Compose on the VPS.
3. Initialize the New API source submodule if it is not already present:

```bash
git submodule update --init --recursive
```

4. Copy `.env.example` to `.env`.
5. Replace every `CHANGE_ME` value and set `DOMAIN` to the production hostname.
6. Point the domain A/AAAA record to the VPS.
7. Run the preflight check:

```bash
bash ops/preflight.sh
```

8. Start the stack:

```bash
docker compose up -d
```

9. Open `https://$DOMAIN`, create the first admin user, then immediately configure invite-only registration, model groups, channel pools, model ratios, and manual top-up workflow.

## Repository Layout

- `docker-compose.yml`: New API, PostgreSQL, Redis, Caddy, and Uptime Kuma.
- `.env.example`: deployment variables and operating policy flags.
- `config/`: example model catalog and monthly package definitions.
- `docs/`: requirements, runbook, payment safety, and cache observability notes.
- `docs/server-buying-guide.md`: VPS sizing and purchase checklist.
- `ops/`: preflight, backup, and restore scripts.
- `scripts/verify-repo.ps1`: local repository verification.
- `vendor/new-api`: upstream New API source as a git submodule for audit and future customization.

## Useful Commands

```bash
docker compose ps
docker compose logs -f new-api
bash ops/backup-postgres.sh
```

## Local Development

Development still runs New API through Docker, but exposes the app directly on localhost so you can inspect it without a public domain:

```bash
cp .env.example .env
# replace CHANGE_ME values first
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d new-api
```

Open `http://localhost:3000`. For production, use the base `docker-compose.yml` and access through Caddy on `https://$DOMAIN`.

On Windows, run repository verification from PowerShell:

```powershell
./scripts/verify-repo.ps1
```

If WSL needs outbound network proxying during setup, use the Windows host proxy on port `10808` temporarily:

```bash
export host_ip="$(grep nameserver /etc/resolv.conf | awk '{print $2}')"
export http_proxy="http://$host_ip:10808"
export https_proxy="$http_proxy"
```

Do not commit local proxy variables into `.env`.
