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
3. Copy `.env.example` to `.env`.
4. Replace every `CHANGE_ME` value and set `DOMAIN` to the production hostname.
5. Point the domain A/AAAA record to the VPS.
6. Run the preflight check:

```bash
bash ops/preflight.sh
```

7. Start the stack:

```bash
docker compose up -d
```

8. Open `https://$DOMAIN`, create the first admin user, then immediately configure invite-only registration, model groups, channel pools, model ratios, and manual top-up workflow.

## Repository Layout

- `docker-compose.yml`: New API, PostgreSQL, Redis, Caddy, and Uptime Kuma.
- `.env.example`: deployment variables and operating policy flags.
- `config/`: example model catalog and monthly package definitions.
- `docs/`: requirements, runbook, payment safety, and cache observability notes.
- `ops/`: preflight, backup, and restore scripts.
- `scripts/verify-repo.ps1`: local repository verification.

## Useful Commands

```bash
docker compose ps
docker compose logs -f new-api
bash ops/backup-postgres.sh
```

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
