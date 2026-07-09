# Backup Strategy

Back up two kinds of state:

- PostgreSQL data from `relay-postgres`.
- Host-side config files: `.env.production`, CPA config, and cloudflared config.

Run:

```bash
ENV_FILE=.env.production ops/backup-postgres.sh
ENV_FILE=.env.production ops/backup-config.sh
```

Database restores are explicit and guarded:

```bash
CONFIRM_RESTORE=yes ENV_FILE=.env.production \
  ops/restore-postgres.sh /path/to/newapi-YYYYmmddTHHMMSSZ.sql
```

Do not delete Docker volumes during normal backup or restore drills.
