# Research

## Sources

- Capistrano-style release layout: `releases/`, `current` symlink, and `shared/` runtime state.
- Git worktree behavior: one repository object store can materialize multiple detached checkouts.
- Existing repository deployment scripts: `ops/deploy-prod.sh`, `ops/drill-restore-stack.sh`, `ops/check-production-runtime.sh`, and backup scripts.

## Common Practice

Small production services often separate deployment code from runtime state. A release directory is prepared and tested first, then a symlink is switched during promotion. Runtime secrets, uploads, logs, and backups live in a shared directory so rollback can change code without deleting state.

Git worktrees fit this project because the server can fetch once into `repo.git` and create detached release directories for exact commits. This avoids running production directly from a mutable Git checkout.

## Risks

- Symlink promotion is not zero-downtime; Compose restarts containers.
- Rollback does not undo database writes made by a bad release.
- Candidate smoke tests need a recent PostgreSQL dump; without one, smoke must fail clearly.
- Compose project names must stay fixed, otherwise release directory names can create new Docker networks and volumes.
- CPA management UI must remain opt-in and loopback-only.

## Decision

Use a Capistrano-style `/opt/lihan_ai_deploy` root with `repo.git`, `releases/`, `current`, `previous`, and `shared/`. Use Git worktree for release materialization, keep Docker Compose project name fixed as `lihan_ai`, and implement deploy, promote, rollback, list, current, and cleanup in `ops/deploy-release.sh`.

PM2 and Paru are not core dependencies. Their deploy/revert ideas are useful, but adding a Node or package-manager control plane would make the current Docker operations surface heavier than necessary.
