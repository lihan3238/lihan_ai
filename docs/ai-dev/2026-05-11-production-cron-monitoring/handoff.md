# Handoff

Production cron monitoring is implemented as wrapper-only tooling. Operators should install crontab entries manually on the origin server and keep webhook URLs in `.env.production` or shell-managed secrets, not in git.

## Commands

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/production-monitor.sh runtime
ENV_FILE=.env.production bash ops/production-monitor.sh backup
ENV_FILE=.env.production bash ops/production-monitor.sh offsite
```

## Notes

- Runtime checks inherit the existing CPA and Cloudflare Tunnel topology from `.env.production`.
- Backup mode creates and verifies a local PostgreSQL dump.
- Offsite mode runs the existing restic wrapper and fails if restic credentials are missing.
- Edge monitoring and automatic Uptime Kuma configuration remain separate future work.
