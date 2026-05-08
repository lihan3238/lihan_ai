# Plan

## Approach
Implement a read-only shell advisor that queries PostgreSQL through Docker Compose and summarizes channel health for a committed profile. Keep user-facing health in Uptime Kuma, documented as a manual setup to avoid storing tokens in git.

## Files
- Create `config/ops-profiles/glm-standard-health.example.json`, `ops/channel-health-advisor.sh`, `tests/channel-health-advisor.test.sh`, `docs/kuma-status-runbook.md`, and `Caddyfile.status.example`.
- Modify README, operations runbook, wrapper tests, production gate, and repository verification.

## Compatibility
No public API, New API source, database schema, or Docker runtime behavior changes are required. The active `Caddyfile` remains unchanged; status-domain publishing is opt-in through the example file.

## Rollback
Remove the advisor script, health profile, status runbook/example, tests, and documentation references. Runtime containers and PostgreSQL state are unaffected.

## Verification
Run the planned shell tests, preflight, PowerShell repository verification, compose config validation, and `git diff --check`.
